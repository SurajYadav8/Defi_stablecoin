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

contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}
    
    function redeemCollateral() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}