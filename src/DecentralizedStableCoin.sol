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

import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/*
 *@title Decentralized Stable Coin 
 *@autor: Suraj Yadav
 *Collateral: Exogenous (wETH & wBTC)
 *Minting: Algorithmic
 *Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stable coin system.
 */
contract DecentralizedStableCoin is ERC20Burnable {
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();
    address private _owner;

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    constructor() ERC20("DecentralizedStableCoin", "DSC") {
        _owner = msg.sender;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)) {
            revert DecentralizedStableCoin_NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}