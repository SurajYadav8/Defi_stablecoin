// SPDX-License-Identifier: SEE LICENSE IN LICENSE

//Layout of Contract:
//version
//imports
//errors
//interfaces, libraries, contracts
//Type declarations
//state variables
//Events
//Modifiers
//Functions

//Layout of functions:
//constructor
//recieve function (if exists)
//fallback function (if exists)
//external functions
//public functions
//internal functions
//private functions
//view functions
//pure functions

pragma solidity 0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Suraj Yadav
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This is stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
 *
 * Our DSC system should always "overCollateralized". At no point, should the value of all collateral <= the $ backed value of all the DSC.
 *
 * @notice THis contract is the core of the DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & withdrwaing collateral.
 * @notice THis contract is VERY loosely based on the MakerDAO DSC (DAI) system
 */
contract DSCEngine is ReentrancyGuard {
    ////////////////////
    //   errors  //
    ///////////////////

    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine_BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();

    ////////////////////
    //   State variables //
    ///////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds; // token to pricefeeds
    mapping(address user => mapping(address token => uint256 amount)) s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////
    //   Events  //
    ///////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed user, uint256 indexed amount, address indexed token);

    ////////////////////
    //   Modifiers //
    ///////////////////
    modifier moreThanZero(
        uint256 amount
    ) {
        if (amount == 0) {
            revert DSCEngine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(
        address token
    ) {
        if (s_priceFeeds[token] == address(0)) {
            _;
        }
    }
    /*
     * 
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */

    ////////////////////
    //   functions //
    ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        //USD prcie feed
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////
    //   external functions //
    ///////////////////

     /*
      *@param tokenCollateralAddress The address of the token to deposit as collateral
      *@param amountCollateral The amount of collateral to deposit
      *@param amountDscToMint The amount of decentralized stablecoin to mint
      * @notice This function will deposit your collateral, and mint the DSC in one transaction.
     */
    function depositCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /*
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant 
    {

        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * @param tokenCollateralAddress The collateral address to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of DSC to burn
     * This function burns DSC and redeems underlying collateral in one transaction.
     */

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks health factor
    }

    // in order to redeem collateral:
    // 1. health factor must be over 1 After collateral pulled
    // DRY: Don't repeat yourself


    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public 
     moreThanZero(amountCollateral) 
     nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, amountCollateral, tokenCollateralAddress);
        // _calculateHealthFactor()
        bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertifHealthFactorIsBroken(msg.sender);
    }

    /* 
    * @notice follows CEI
    * @param amountDscToMint the amount of decentralized stablecoin to mint
    * @notice they must have more collateral value than minimum threshold
    */
    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_dscMinted[msg.sender] += amountDscToMint;
        //if they minted too much ($150 DSC, $100 ETH)
        _revertifHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        s_dscMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        //This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amount);
        _revertifHealthFactorIsBroken(msg.sender);  // I don't think this would ever hit.....
    }

    function liquidate() external {}

    function getHealthFactor() external view {}

    //////////////////////////////////
    //  Private & internal view functions //
    /////////////////////////////////

    function _getAccountInformation(
        address user
    ) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        // 1. Get the total DSC minted by the user
        totalDscMinted = s_dscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(
        address user
    ) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // 1000 ETH  * 50 = 50,000 / 100 = 500
        //$150 ETH / 100DSC = 1.5
        // 150 * 50 = 7500 / 100 = 75
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if they don't

    function _revertifHealthFactorIsBroken(
        address user
    ) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_BreakHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////////
    //  Public & external view functions //
    /////////////////////////////////
    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to
        // the price feed to get the value in USD
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $3500
        // The returned price is in 8 decimals, 3500 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
