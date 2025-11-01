// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../CodePrix.sol";

abstract contract Car {
    function takeYourTurn(
        CodePrix codePrix,
        CodePrix.CarData[] calldata allCars,
        uint256 yourCarIndex
    ) external virtual;
}
