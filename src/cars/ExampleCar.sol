pragma solidity 0.8.13;

import "../interfaces/Car.sol";
import "../CodePrix.sol";

contract ExampleCar is Car {
    
    uint256 constant WIN_Y = 1000;
    uint256 constant END_GAME_Y_THRESHOLD = 500;
    uint256 constant BINARY_SEARCH_STEPS = 12;
    uint256 constant MAX_SEARCH_AMOUNT = 1000;

    uint256 private lastTurnIndex = 4;

    uint256 private canShield = 0;

    function takeYourTurn(
        CodePrix codePrix,
        CodePrix.CarData[] calldata allCars,
        uint256 ourCarIndex
    ) external override {
        CodePrix.CarData memory ourCar = allCars[ourCarIndex];
        CodePrix.CarData memory leaderCar = allCars[0];

        if(ourCar.balance>codePrix.getAccelerateCost(21)){
            codePrix.buyAcceleration(21);
        }
        else{
            uint256 amountToBuy = findMaxAffordable(codePrix, ourCar.balance-2000, codePrix.getAccelerateCost);
            if (amountToBuy > 2) {
                codePrix.buyAcceleration(amountToBuy-2);
            }
        } 

        if (ourCarIndex > lastTurnIndex) {
            uint256 shellCost = codePrix.getShellCost(1);
            if (ourCar.balance >= shellCost) {
                codePrix.buyShell(1);                
                lastTurnIndex = ourCarIndex;
                return;
            }
        }

        uint256 ourDistanceLeft = WIN_Y - ourCar.y;

        if (leaderCar.y >= END_GAME_Y_THRESHOLD) {
            runEndGame(codePrix, allCars, ourCar, ourCarIndex, ourDistanceLeft);
        } else {
            runMainGame(codePrix, leaderCar, ourCar, ourCarIndex, ourDistanceLeft);
        }

        lastTurnIndex = ourCarIndex;
    }

    function runEndGame(
        CodePrix codePrix,
        CodePrix.CarData[] calldata allCars,
        CodePrix.CarData memory ourCar,
        uint256 ourCarIndex,
        uint256 ourDistanceLeft
    ) internal {
        if (ourCarIndex == 0) {
            
            if (ourCar.balance >= codePrix.getShieldCost(getTurnsToFinish(ourDistanceLeft, ourCar.speed))){
                canShield = 1;
            }

            if(canShield>0 && ourCar.shield<4 && ourCar.balance>=codePrix.getShieldCost(4-ourCar.shield)){
                codePrix.buyShield(4-ourCar.shield);
            }
            

        } 
        else {
            if (ourCar.balance >= codePrix.getShellCost(1)) {
                CodePrix.CarData memory leader = allCars[0];
                
                uint256 ourTTF = getTurnsToFinish(ourDistanceLeft, ourCar.speed);
                uint256 leaderTTF = getTurnsToFinish(WIN_Y - leader.y, leader.speed);

                if (ourTTF > leaderTTF) {
                    uint256 ourY_AfterTurn = ourCar.y + ourCar.speed;
                    uint256 leaderY_AfterTurn = leader.y + leader.speed;

                    uint256 ourTTF_AfterShell = 1 + getTurnsToFinish(WIN_Y - ourY_AfterTurn, ourCar.speed);
                    uint256 leaderTTF_AfterShell = 1 + getTurnsToFinish(WIN_Y - leaderY_AfterTurn, 1);
                    
                    if (ourTTF_AfterShell < leaderTTF_AfterShell) {
                        codePrix.buyShell(1);
                        return;
                    }
                }
            }

            uint256 amountToBuy = findMaxAffordable(codePrix, ourCar.balance, codePrix.getAccelerateCost);
            if (amountToBuy > 2) {
                codePrix.buyAcceleration(amountToBuy);
            }
        }
    }

    function runMainGame(
        CodePrix codePrix,
        CodePrix.CarData memory leaderCar,
        CodePrix.CarData memory ourCar,
        uint256 ourCarIndex,
        uint256 ourDistanceLeft
    ) internal {
        if (ourCarIndex == 0) {
            if (ourCar.speed>5 && ourCar.balance >= codePrix.getShieldCost(4)){
                codePrix.buyShield(4);
            }
            return;
        }

        uint256 leaderDistanceLeft = WIN_Y - leaderCar.y;
        uint256 leaderTTF = getTurnsToFinish(leaderDistanceLeft, leaderCar.speed);
        if (leaderTTF == 0) { leaderTTF = 1; }

        uint256 targetSpeed = (ourDistanceLeft + leaderTTF - 1) / leaderTTF;

        if (ourCar.speed < targetSpeed) {
            uint256 speedToBuy = targetSpeed - ourCar.speed;
            uint256 cost = codePrix.getAccelerateCost(speedToBuy);

            if (ourCar.balance >= cost) {
                uint256 currentTTF = getTurnsToFinish(ourDistanceLeft, ourCar.speed);
                uint256 newTTF = getTurnsToFinish(ourDistanceLeft, targetSpeed);

                if (newTTF < currentTTF) {
                    codePrix.buyAcceleration(speedToBuy);
                }
            }
        }

        else{
            uint256 amountToBuy = findMaxAffordable(codePrix, ourCar.balance, codePrix.getAccelerateCost);
            if (amountToBuy > 2) {
                codePrix.buyAcceleration(amountToBuy);
            }
        }
    }

    function getTurnsToFinish(
        uint256 distanceLeft,
        uint256 speed
    ) internal pure returns (uint256) {
        if (speed == 0) {
            return 10000;
        }
        return (distanceLeft + speed - 1) / speed;
    }

    function findMaxAffordable(
        CodePrix codePrix,
        uint256 balance,
        function(uint256) external view returns (uint256) getCost
    ) internal view returns (uint256) {
        uint256 minAmount = 0;
        uint256 maxAmount = MAX_SEARCH_AMOUNT;
        uint256 maxAffordable = 0;

        for (uint256 i = 0; i < BINARY_SEARCH_STEPS; i++) {
            if (minAmount > maxAmount) {
                break;
            }

            uint256 midAmount = (minAmount + maxAmount + 1) / 2;
            if (midAmount == 0) {
                break;
            }

            uint256 cost = getCost(midAmount);

            if (cost <= balance) {
                maxAffordable = midAmount;
                minAmount = midAmount + 1;
            } else {
                maxAmount = midAmount - 1;
            }
        }
        return maxAffordable;
    }
}