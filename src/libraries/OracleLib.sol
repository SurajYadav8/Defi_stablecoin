//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/* @title OracleLib
* @author Patrick Collins
* @notice This Library is used to check the Chainlink Oracle for stable data.
* If a price is state, the function will revert, and render the DSCEngine unusable - this is What we want the DSCEngine to freeze if prices become stable.
* So if the Chainlink network explodes and you have a lot of money locked in the Protocol....
*/

library OracleLib {
    error OracleLib_StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns(uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answerInRound
        ) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if(secondsSince > TIMEOUT) revert OracleLib_StalePrice();
        return(roundId, answer, startedAt, updatedAt, answerInRound);
    }
}