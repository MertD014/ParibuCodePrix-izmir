// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/CodePrix.sol";
import "../src/interfaces/Car.sol";
import "../src/cars/ExampleCar.sol";
import "../src/cars/DefensiveCar.sol";
import "../src/cars/gpt4Car.sol";

uint256 constant CAR_LEN = 5;
uint256 constant ABILITY_LEN = 3;

struct GameTurn {
    address[CAR_LEN] cars;
    uint256[CAR_LEN] balance;
    uint256[3] totalExpenses;
    uint256[CAR_LEN] speed;
    uint256[CAR_LEN] y;
    uint256[CAR_LEN] shield;
    uint256[ABILITY_LEN] costs;
    uint256[ABILITY_LEN] bought;
    address currentCar;
    uint256[ABILITY_LEN] usedAbilities;
}

contract RunRace is Script {
    error CodePrixTest__getCarIndex_carNotFound(address car);
    error CodePrixTest__getAbilityCost_abilityNotFound(uint256 abilityIndex);
    int256 internal constant SHELL_TARGET_PRICE = 200e18;
    int256 internal constant SHELL_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant SHELL_SELL_PER_TURN = 0.2e18;

    int256 internal constant ACCELERATE_TARGET_PRICE = 10e18;
    int256 internal constant ACCELERATE_PER_TURN_DECREASE = 0.2e18;
    int256 internal constant ACCELERATE_SELL_PER_TURN = 2e18;

    int256 internal constant SHIELD_TARGET_PRICE = 100e18;
    int256 internal constant SHIELD_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant SHIELD_SELL_PER_TURN = 0.1e18;

    string private gamelogJsonData = "";

    CodePrix codePrix;

    Car w1;
    Car w2;
    Car w3;
    Car w4;
    Car w5;

    string carName1;
    string carName2;
    string carName3;
    string carName4;
    string carName5;

    address[CAR_LEN] cars;

    function setUp() public {
        codePrix = new CodePrix();
        w1 = new ExampleCar();
        w2 = new ExampleCar();
        w3 = new ExampleCar();
        w4 = new ExampleCar();
        w5 = new ExampleCar();

        carName1 = "defensivecar1";
        carName2 = "defensivecar2";
        carName3 = "examplecar3";
        carName4 = "defensivecar4";
        carName5 = "examplecar5";
    }

    function run() public {
        setUp();

        codePrix.register(w1);
        codePrix.register(w2);
        codePrix.register(w3);
        codePrix.register(w4);
        codePrix.register(w5);

        cars[0] = address(w1);
        cars[1] = address(w2);
        cars[2] = address(w3);
        cars[3] = address(w4);
        cars[4] = address(w5);

        // Create the game log json file
        appendToGamelogJson("{");
        appendToGamelogJson(encodeCars());
        appendToGamelogJson(',"turns":[');
        bool firstLine = true;

        uint256 maxTurns = 1000; // Max 1000 turns to prevent infinite loops
        uint256 turnCount = 0;

        while (
            codePrix.state() != CodePrix.State.DONE && turnCount < maxTurns
        ) {
            turnCount++;
            // Struct that will be added to the gameLog json
            GameTurn memory currentTurn;

            // set the current car
            currentTurn.currentCar = address(
                codePrix.cars(codePrix.turns() % CAR_LEN)
            );

            // cache the current # abilities sold BEFORE the turn
            for (
                uint256 abilityIdx = 0;
                abilityIdx <= uint256(CodePrix.ActionType.SHIELD);
                ++abilityIdx
            ) {
                currentTurn.usedAbilities[abilityIdx] = codePrix.getActionsSold(
                    CodePrix.ActionType(abilityIdx)
                );
            }

            // Get car states BEFORE the turn
            CodePrix.CarData[] memory allCarDataBefore = codePrix
                .getAllCarData();

            // Store cars array order
            for (uint256 i = 0; i < CAR_LEN; ++i) {
                currentTurn.cars[i] = address(codePrix.cars(i));
            }

            // Store costs BEFORE the turn (only once, not in the loop)
            for (
                uint256 abilityIdx = 0;
                abilityIdx <= uint256(CodePrix.ActionType.SHIELD);
                ++abilityIdx
            ) {
                currentTurn.costs[abilityIdx] = getAbilityCost(abilityIdx, 1);
            }

            // Execute the turn
            codePrix.play(1);

            // Compute the abilities used this turn
            for (
                uint256 abilityIdx = 0;
                abilityIdx <= uint256(CodePrix.ActionType.SHIELD);
                ++abilityIdx
            ) {
                uint256 prevUsedAbilities = currentTurn.usedAbilities[
                    abilityIdx
                ];

                currentTurn.usedAbilities[abilityIdx] =
                    codePrix.getActionsSold(CodePrix.ActionType(abilityIdx)) -
                    currentTurn.usedAbilities[abilityIdx];

                if (abilityIdx == 0) {
                    currentTurn.totalExpenses[
                        abilityIdx
                    ] = getHistoricalAccelerateCost(
                        currentTurn.usedAbilities[abilityIdx],
                        prevUsedAbilities,
                        currentTurn,
                        codePrix
                    );
                }

                if (abilityIdx == 1) {
                    currentTurn.totalExpenses[
                        abilityIdx
                    ] = getHistoricalShellCost(
                        currentTurn.usedAbilities[abilityIdx],
                        prevUsedAbilities,
                        currentTurn,
                        codePrix
                    );
                }

                if (abilityIdx == 2) {
                    currentTurn.totalExpenses[
                        abilityIdx
                    ] = getHistoricalShieldCost(
                        currentTurn.usedAbilities[abilityIdx],
                        prevUsedAbilities,
                        currentTurn,
                        codePrix
                    );
                }
            }

            // Get car states AFTER the turn
            CodePrix.CarData[] memory allCarData = codePrix.getAllCarData();

            // Store total abilities bought (after the turn, outside the car loop)
            for (
                uint256 abilityIdx = 0;
                abilityIdx <= uint256(CodePrix.ActionType.SHIELD);
                ++abilityIdx
            ) {
                currentTurn.bought[abilityIdx] = codePrix.getActionsSold(
                    CodePrix.ActionType(abilityIdx)
                );
            }

            for (uint256 i = 0; i < allCarData.length; i++) {
                CodePrix.CarData memory car = allCarData[i];

                // Add car data to the current turn (data AFTER the turn)
                uint256 carIndex = getCarIndex(address(car.car));
                currentTurn.balance[carIndex] = car.balance;
                currentTurn.speed[carIndex] = car.speed;
                currentTurn.y[carIndex] = car.y;
                currentTurn.shield[carIndex] = car.shield;
            }

            appendToGamelogJson(
                string.concat((firstLine) ? "" : ",", encodeJson(currentTurn))
            );

            firstLine = false;
        }

        // Max turn warning
        if (turnCount >= maxTurns) {
            console.log("Max turns reached (%d), ending race", maxTurns);
        }

        // Close the json file
        appendToGamelogJson("]}");
        vm.writeFile("logs/gameLog.json", gamelogJsonData);
        // emit log_named_uint("Number Of Turns", codePrix.turns());
    }

    function getHistoricalAccelerateCost(
        uint256 amount,
        uint256 usedAbilities,
        GameTurn memory currentTurn,
        CodePrix codePrix
    ) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    ACCELERATE_TARGET_PRICE,
                    ACCELERATE_PER_TURN_DECREASE,
                    codePrix.turns() - 1,
                    usedAbilities + i,
                    ACCELERATE_SELL_PER_TURN
                );
            }
        }
    }

    function getHistoricalShellCost(
        uint256 amount,
        uint256 usedAbilities,
        GameTurn memory currentTurn,
        CodePrix codePrix
    ) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    SHELL_TARGET_PRICE,
                    SHELL_PER_TURN_DECREASE,
                    codePrix.turns() - 1,
                    usedAbilities + i,
                    SHELL_SELL_PER_TURN
                );
            }
        }
    }

    function getHistoricalShieldCost(
        uint256 amount,
        uint256 usedAbilities,
        GameTurn memory currentTurn,
        CodePrix codePrix
    ) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    SHIELD_TARGET_PRICE,
                    SHIELD_PER_TURN_DECREASE,
                    codePrix.turns() - 1,
                    usedAbilities + i,
                    SHIELD_SELL_PER_TURN
                );
            }
        }
    }

    function computeActionPrice(
        int256 targetPrice,
        int256 perTurnPriceDecrease,
        uint256 turnsSinceStart,
        uint256 sold,
        int256 sellPerTurnWad
    ) internal pure returns (uint256) {
        unchecked {
            // prettier-ignore
            return uint256(
                wadMul(targetPrice, wadExp(unsafeWadMul(wadLn(1e18 - perTurnPriceDecrease),
                // Theoretically calling toWadUnsafe with turnsSinceStart and sold can overflow without
                // detection, but under any reasonable circumstance they will never be large enough.
                // Use sold + 1 as we need the number of the tokens that will be sold (inclusive).
                // Use turnsSinceStart - 1 since turns start at 1 but here the first turn should be 0.
                toWadUnsafe(turnsSinceStart - 1) - (wadDiv(toWadUnsafe(sold + 1), sellPerTurnWad))
            )))) / 1e18;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function encodeJson(
        GameTurn memory turn
    ) private view returns (string memory) {
        return
            string.concat(
                "{",
                '"currentCar":"',
                vm.toString(getCarIndex(turn.currentCar)),
                '",',
                encodeCars(turn),
                ",",
                // pack these together to avoid stack too deep
                encodeCarStats(turn),
                ",",
                encodeCosts(turn),
                ",",
                encodeBought(turn),
                ",",
                encodeUsedAbilities(turn),
                ",",
                encodeTotalExpenses(turn),
                "}"
            );
    }

    function encodeTotalExpenses(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"totalExpenses":[',
                vm.toString(turn.totalExpenses[0]),
                ",",
                vm.toString(turn.totalExpenses[1]),
                ",",
                vm.toString(turn.totalExpenses[2]),
                "]"
            );
    }

    function encodeCarStats(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                encodeBalance(turn),
                ",",
                encodeSpeed(turn),
                ",",
                encodeY(turn),
                ",",
                encodeShield(turn)
            );
    }

    function encodeBalance(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"balance":[',
                vm.toString(turn.balance[0]),
                ",",
                vm.toString(turn.balance[1]),
                ",",
                vm.toString(turn.balance[2]),
                ",",
                vm.toString(turn.balance[3]),
                ",",
                vm.toString(turn.balance[4]),
                "]"
            );
    }

    function encodeSpeed(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"speed":[',
                vm.toString(turn.speed[0]),
                ",",
                vm.toString(turn.speed[1]),
                ",",
                vm.toString(turn.speed[2]),
                ",",
                vm.toString(turn.speed[3]),
                ",",
                vm.toString(turn.speed[4]),
                "]"
            );
    }

    function encodeY(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"y":[',
                vm.toString(turn.y[0]),
                ",",
                vm.toString(turn.y[1]),
                ",",
                vm.toString(turn.y[2]),
                ",",
                vm.toString(turn.y[3]),
                ",",
                vm.toString(turn.y[4]),
                "]"
            );
    }

    function encodeShield(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"shield":[',
                vm.toString(turn.shield[0]),
                ",",
                vm.toString(turn.shield[1]),
                ",",
                vm.toString(turn.shield[2]),
                ",",
                vm.toString(turn.shield[3]),
                ",",
                vm.toString(turn.shield[4]),
                "]"
            );
    }

    function encodeCosts(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"costs":[',
                vm.toString(uint32(turn.costs[0])),
                ",",
                vm.toString(uint32(turn.costs[1])),
                ",",
                vm.toString(uint32(turn.costs[2])),
                "]"
            );
    }

    function encodeBought(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"bought":[',
                vm.toString(turn.bought[0]),
                ",",
                vm.toString(turn.bought[1]),
                ",",
                vm.toString(turn.bought[2]),
                "]"
            );
    }

    function encodeUsedAbilities(
        GameTurn memory turn
    ) private pure returns (string memory) {
        return
            string.concat(
                '"usedAbilities":[',
                vm.toString(turn.usedAbilities[0]),
                ",",
                vm.toString(turn.usedAbilities[1]),
                ",",
                vm.toString(turn.usedAbilities[2]),
                "]"
            );
    }

    function encodeCars() private view returns (string memory) {
        return
            string.concat(
                '"cars":["',
                carName1,
                '","',
                carName2,
                '","',
                carName3,
                '","',
                carName4,
                '","',
                carName5,
                '"]'
            );
    }

    function encodeCars(
        GameTurn memory turn
    ) private view returns (string memory) {
        return
            string.concat(
                '"cars":["',
                vm.toString(getCarIndex(turn.cars[0])),
                '","',
                vm.toString(getCarIndex(turn.cars[1])),
                '","',
                vm.toString(getCarIndex(turn.cars[2])),
                '","',
                vm.toString(getCarIndex(turn.cars[3])),
                '","',
                vm.toString(getCarIndex(turn.cars[4])),
                '"]'
            );
    }

    function getCarIndex(address car) private view returns (uint256) {
        for (uint256 i = 0; i < 5; ++i) {
            if (cars[i] == car) return i;
        }

        revert CodePrixTest__getCarIndex_carNotFound(car);
    }

    function getAbilityCost(
        uint256 abilityIdx,
        uint256 amount
    ) private view returns (uint256) {
        if (abilityIdx == 0) return codePrix.getAccelerateCost(amount);
        if (abilityIdx == 1) return codePrix.getShellCost(amount);
        if (abilityIdx == 2) return codePrix.getShieldCost(amount);

        revert CodePrixTest__getAbilityCost_abilityNotFound(abilityIdx);
    }

    function appendToGamelogJson(string memory data) public {
        gamelogJsonData = string.concat(gamelogJsonData, data);
    }
}
