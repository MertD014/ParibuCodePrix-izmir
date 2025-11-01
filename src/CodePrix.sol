// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/Car.sol";
import "./utils/SignedWadMath.sol";

import "solmate/utils/SafeCastLib.sol";

contract CodePrix {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TurnCompleted(
        uint256 indexed turn,
        CarData[] cars,
        uint256 acceleratePrice,
        uint256 shellPrice,
        uint256 shieldPrice
    );

    event Shelled(
        uint256 indexed turn,
        Car indexed attacker,
        Car indexed target,
        uint256 amount,
        uint256 cost
    );

    event Accelerated(
        uint256 indexed turn,
        Car indexed car,
        uint256 amount,
        uint256 cost
    );

    event Shielded(
        uint256 indexed turn,
        Car indexed car,
        uint256 amount,
        uint256 cost
    );

    event Registered(uint256 indexed turn, Car indexed car);

    event RaceWon(uint256 indexed turn, Car indexed winner);

    /*//////////////////////////////////////////////////////////////
                         MISCELLANEOUS CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint72 internal constant PLAYERS_REQUIRED = 5;

    uint32 internal constant POST_SHELL_SPEED = 1;

    uint32 internal constant STARTING_BALANCE = 15000;

    uint256 internal constant FINISH_DISTANCE = 1000;

    /*//////////////////////////////////////////////////////////////
                            PRICING CONSTANTS
    //////////////////////////////////////////////////////////////*/

    int256 internal constant SHELL_TARGET_PRICE = 200e18;
    int256 internal constant SHELL_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant SHELL_SELL_PER_TURN = 0.2e18;

    int256 internal constant ACCELERATE_TARGET_PRICE = 10e18;
    int256 internal constant ACCELERATE_PER_TURN_DECREASE = 0.2e18;
    int256 internal constant ACCELERATE_SELL_PER_TURN = 2e18;

    int256 internal constant SHIELD_TARGET_PRICE = 100e18;
    int256 internal constant SHIELD_PER_TURN_DECREASE = 0.33e18;
    int256 internal constant SHIELD_SELL_PER_TURN = 0.1e18;

    /*//////////////////////////////////////////////////////////////
                               GAME STATE
    //////////////////////////////////////////////////////////////*/

    enum State {
        WAITING,
        ACTIVE,
        DONE
    }

    State public state; // The current state of the game: pre-start, started, done.

    uint16 public turns = 1; // Number of turns played since the game started.

    uint72 public entropy; // Random data used to choose the next turn.

    Car public currentCar; // The car currently making a move.

    /*//////////////////////////////////////////////////////////////
                               SALES STATE
    //////////////////////////////////////////////////////////////*/

    enum ActionType {
        ACCELERATE,
        SHELL,
        SHIELD
    }

    mapping(ActionType => uint256) public getActionsSold;

    /*//////////////////////////////////////////////////////////////
                               CAR STORAGE
    //////////////////////////////////////////////////////////////*/

    struct CarData {
        uint32 balance; // Where 0 means the car has no money.
        uint32 speed; // Where 0 means the car isn't moving.
        uint32 y; // Where 0 means the car hasn't moved.
        uint32 shield; // Shield turns remaining (0 means no shield)
        Car car;
    }

    Car[] public cars;

    mapping(Car => CarData) public getCarData;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/

    function register(Car car) external {
        require(address(getCarData[car].car) == address(0), "DOUBLE_REGISTER");
        getCarData[car] = CarData({
            balance: STARTING_BALANCE,
            car: car,
            speed: 0,
            y: 0,
            shield: 0
        });

        cars.push(car);
        uint256 totalCars = cars.length;

        if (totalCars == PLAYERS_REQUIRED) {
            entropy = uint72(block.timestamp);
            state = State.ACTIVE;
        } else require(totalCars < PLAYERS_REQUIRED, "MAX_PLAYERS");

        emit Registered(0, car);
    }

    /*//////////////////////////////////////////////////////////////
                                CORE GAME
    //////////////////////////////////////////////////////////////*/

    function play(uint256 turnsToPlay) external onlyDuringActiveGame {
        unchecked {
            for (; turnsToPlay != 0; turnsToPlay--) {
                Car[] memory allCars = cars;
                uint256 currentTurn = turns;
                Car currentTurnCar = allCars[currentTurn % PLAYERS_REQUIRED];
                (
                    CarData[] memory allCarData,
                    uint256 yourCarIndex
                ) = getAllCarDataAndFindCar(currentTurnCar);

                currentCar = currentTurnCar;
                try
                    currentTurnCar.takeYourTurn{gas: 2_000_000}(
                        this,
                        allCarData,
                        yourCarIndex
                    )
                {} catch {}

                delete currentCar;
                for (uint256 i = 0; i < PLAYERS_REQUIRED; i++) {
                    Car car = allCars[i];
                    CarData storage carData = getCarData[car];

                    if (carData.shield > 0) {
                        carData.shield--;
                    }

                    if ((carData.y += carData.speed) >= FINISH_DISTANCE) {
                        emit RaceWon(currentTurn, car);
                        state = State.DONE;
                        return;
                    }
                }

                if (currentTurn % PLAYERS_REQUIRED == 0) {
                    for (uint256 j = 0; j < PLAYERS_REQUIRED; ++j) {
                        uint256 newEntropy = (entropy = uint72(
                            uint256(keccak256(abi.encode(entropy)))
                        ));
                        uint256 j2 = j + (newEntropy % (PLAYERS_REQUIRED - j));

                        Car temp = allCars[j];
                        allCars[j] = allCars[j2];
                        allCars[j2] = temp;
                    }

                    cars = allCars;
                }

                emit TurnCompleted(
                    turns = uint16(currentTurn + 1),
                    getAllCarData(),
                    getAccelerateCost(1),
                    getShellCost(1),
                    getShieldCost(1)
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 ACTIONS
    //////////////////////////////////////////////////////////////*/

    function buyAcceleration(
        uint256 amount
    ) external onlyDuringActiveGame onlyCurrentCar returns (uint256 cost) {
        cost = getAccelerateCost(amount);
        CarData storage car = getCarData[Car(msg.sender)];
        car.balance -= cost.safeCastTo32();

        unchecked {
            car.speed += uint32(amount);
            getActionsSold[ActionType.ACCELERATE] += amount;
        }

        emit Accelerated(turns, Car(msg.sender), amount, cost);
    }

    function buyShell(
        uint256 amount
    ) external onlyDuringActiveGame onlyCurrentCar returns (uint256 cost) {
        require(amount != 0, "YOU_CANT_BUY_ZERO_SHELLS");
        cost = getShellCost(amount);
        CarData storage car = getCarData[Car(msg.sender)];
        car.balance -= cost.safeCastTo32();
        uint256 y = car.y;

        unchecked {
            getActionsSold[ActionType.SHELL] += amount;

            Car closestCar;
            uint256 distanceFromClosestCar = type(uint256).max;

            for (uint256 i = 0; i < PLAYERS_REQUIRED; i++) {
                CarData memory nextCar = getCarData[cars[i]];

                if (nextCar.y <= y) continue;

                uint256 distanceFromNextCar = nextCar.y - y;

                if (distanceFromNextCar < distanceFromClosestCar) {
                    closestCar = nextCar.car;
                    distanceFromClosestCar = distanceFromNextCar;
                }
            }

            if (address(closestCar) != address(0)) {
                if (getCarData[closestCar].shield > 0) {
                    // Car is protected by shield
                } else {
                    if (getCarData[closestCar].speed > POST_SHELL_SPEED)
                        getCarData[closestCar].speed = POST_SHELL_SPEED;
                }
            }

            emit Shelled(turns, Car(msg.sender), closestCar, amount, cost);
        }
    }

    function buyShield(
        uint256 amount
    ) external onlyDuringActiveGame onlyCurrentCar returns (uint256 cost) {
        require(amount != 0, "YOU_CANT_BUY_ZERO_SHIELDS");
        cost = getShieldCost(amount);
        CarData storage car = getCarData[Car(msg.sender)];
        car.balance -= cost.safeCastTo32();

        unchecked {
            uint32 newShieldValue = car.shield + uint32(amount);
            car.shield = newShieldValue > 6 ? 6 : newShieldValue;
            getActionsSold[ActionType.SHIELD] += amount;
        }

        emit Shielded(turns, Car(msg.sender), amount, cost);
    }

    /*//////////////////////////////////////////////////////////////
                             ACTION PRICING
    //////////////////////////////////////////////////////////////*/

    function getAccelerateCost(
        uint256 amount
    ) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    ACCELERATE_TARGET_PRICE,
                    ACCELERATE_PER_TURN_DECREASE,
                    turns,
                    getActionsSold[ActionType.ACCELERATE] + i,
                    ACCELERATE_SELL_PER_TURN
                );
            }
        }
    }

    function getShellCost(uint256 amount) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    SHELL_TARGET_PRICE,
                    SHELL_PER_TURN_DECREASE,
                    turns,
                    getActionsSold[ActionType.SHELL] + i,
                    SHELL_SELL_PER_TURN
                );
            }
        }
    }

    function getShieldCost(uint256 amount) public view returns (uint256 sum) {
        unchecked {
            for (uint256 i = 0; i < amount; i++) {
                sum += computeActionPrice(
                    SHIELD_TARGET_PRICE,
                    SHIELD_PER_TURN_DECREASE,
                    turns,
                    getActionsSold[ActionType.SHIELD] + i,
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
            return
                uint256(
                    wadMul(
                        targetPrice,
                        wadExp(
                            unsafeWadMul(
                                wadLn(1e18 - perTurnPriceDecrease),
                                toWadUnsafe(turnsSinceStart - 1) -
                                    (
                                        wadDiv(
                                            toWadUnsafe(sold + 1),
                                            sellPerTurnWad
                                        )
                                    )
                            )
                        )
                    )
                ) / 1e18;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyDuringActiveGame() {
        require(state == State.ACTIVE, "GAME_NOT_ACTIVE");

        _;
    }

    modifier onlyCurrentCar() {
        require(Car(msg.sender) == currentCar, "NOT_CURRENT_CAR");

        _;
    }

    function getAllCarData() public view returns (CarData[] memory results) {
        results = new CarData[](PLAYERS_REQUIRED);
        Car[] memory sortedCars = getCarsSortedByY();

        unchecked {
            for (uint256 i = 0; i < PLAYERS_REQUIRED; i++)
                results[i] = getCarData[sortedCars[i]];
        }
    }

    function getAllCarDataAndFindCar(
        Car carToFind
    ) public view returns (CarData[] memory results, uint256 foundCarIndex) {
        results = new CarData[](PLAYERS_REQUIRED);
        Car[] memory sortedCars = getCarsSortedByY();

        unchecked {
            for (uint256 i = 0; i < PLAYERS_REQUIRED; i++) {
                Car car = sortedCars[i];

                if (car == carToFind) foundCarIndex = i;

                results[i] = getCarData[car];
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              SORTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function getCarsSortedByY()
        internal
        view
        returns (Car[] memory sortedCars)
    {
        unchecked {
            sortedCars = cars;

            for (uint256 i = 0; i < PLAYERS_REQUIRED; i++) {
                for (uint256 j = i + 1; j < PLAYERS_REQUIRED; j++) {
                    if (
                        getCarData[sortedCars[j]].y >
                        getCarData[sortedCars[i]].y
                    ) {
                        Car temp = sortedCars[i];
                        sortedCars[i] = sortedCars[j];
                        sortedCars[j] = temp;
                    }
                }
            }
        }
    }
}
