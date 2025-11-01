## Prerequisites

Before starting, make sure you have the following installed:
- **Git**: Download from [https://git-scm.com/](https://git-scm.com/)
- **VS Code** (recommended): Download from [https://code.visualstudio.com/](https://code.visualstudio.com/)
- **Node.js**: Download from [https://nodejs.org/](https://nodejs.org/) (for bytecode extraction)

## Quick Start

> **⚠️ Important for Windows Users:**
> If you're using Windows, you'll need to install and use **Git BASH** or **WSL** as your terminal, since Foundryup currently doesn't support PowerShell or Command Prompt (Cmd).

### 1. Project Setup
```bash
# Foundry installation
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install project dependencies
forge install
```

### 2. Develop Your Contract
Edit the `src/cars/ExampleCar.sol` file and code your own strategy.

### 3. Racing Simulation and Compilation
```bash
# Compile + race simulation + bytecode extraction
./compile.sh

# Compile only
forge build

# Race simulation only
forge script script/RunRace.s.sol -vvv
```

## Game Mechanics

### Basic Information
- **Starting money**: 15,000 units
- **Win condition**: First to reach 1000 units
- **Number of players**: 5 cars

### Actions
1. **buyAcceleration(amount)** - Increase speed (permanent)
2. **buyShell(amount)** - Hit the car in front (reduces their speed to 1)
3. **buyShield(amount)** - Buy protection (max 6 turns)

### Dynamic Pricing
- Actions become more expensive as they're used more
- Prices decrease as turns pass
- Early actions are expensive, late actions are cheap

## File Structure

```
├── src/
│   ├── CodePrix.sol                 # Main game contract
│   ├── interfaces/Car.sol         # Car interface
│   ├── utils/SignedWadMath.sol    # Mathematical helpers
│   └── cars/
│       ├── ExampleCar.sol         # Template car (edit this!)
│       ├── DefensiveCar.sol      # Defense-focused strategy
│       ├── gpt4Car.sol
│       └── ...
├── script/
│   └── RunRace.s.sol             # Advanced race script
├── extract-bytecode.js           # Bytecode extraction
└── compile.sh                    # Quick compilation script
```

## Strategy Development Tips

### 1. Position Analysis
```solidity
// Am I in the lead?
if (ourCarIndex == 0) {
    // Defense-focused strategy
}

// Am I at the back?
if (ourCarIndex == allCars.length - 1) {
    // Attack-focused strategy
}
```

### 2. Opponent Analysis
```solidity
// Is the car in front too fast?
if (ourCarIndex > 0 && allCars[ourCarIndex - 1].speed > ourCar.speed + 3) {
    // Fire shell
    codePrix.buyShell(1);
}
```

### 3. Money Management
```solidity
// Price control
uint256 accelCost = codePrix.getAccelerateCost(1);
if (ourCar.balance > accelCost * 10) {
    // Can spend comfortably
}
```

### 4. Game Phases
```solidity
// Early game: Build speed
if (codePrix.turns() < 20) {
    // Accelerate focus
}

// Late game: Act based on position
if (allCars[0].y > 800) {
    // End game tactics
}
```

## Race Simulations

```bash
# Quick simulation (ExampleCar vs ExampleCar x5)
./compile.sh

# Manual simulation run
forge script script/RunRace.s.sol -vvv
```

## Bytecode Submission

1. Run `./compile.sh`
2. Open `ExampleCar.bytecode` file from `bytecode/` folder
3. Copy the content and submit to platform

## Testing Your Race Locally

After running a race simulation:
1. Open the `out/gameLog.json` file generated from your race
2. Go to 'https://izmir.universitycodeprix.com/simulate'.
3. Paste the contents of `gameLog.json` into the text area
4. Click "Load Race Data" to visualize your race


## Example Strategies

The project includes 3 basic strategy examples:

### 🛡️ DefensiveCar.sol - Defense-Focused
- **Priority**: Shield protection and steady progress
- **Strategy**: Constantly buys shields, accelerates while protected
- **Advantage**: Strong against shell attacks
- **Disadvantage**: Slow start, expensive protection

### 🔥 AggressiveCar.sol - Attack-Focused
- **Priority**: Slowing opponents with shells
- **Strategy**: Constantly hits cars in front
- **Advantage**: Reduces opponent speeds to 1
- **Disadvantage**: Remains defenseless, high shell cost

### ⚖️ ExampleCar.sol - Balanced Approach
- **Priority**: Simple and balanced decision making
- **Strategy**: Shield → Accelerate → Shell sequence
- **Advantage**: Understandable and safe
- **Disadvantage**: Predictable

Also advanced examples:
- **gpt4Car.sol**: AI-generated

## Troubleshooting

### Compilation Error
```bash
# If dependencies are missing
forge install

# Clear cache
forge clean
forge build
```

### Race Script Error
```bash
# Verbose output
forge script script/RunRace.s.sol -vvvv
```

### Gas Limit
Your contract can use a maximum of 2M gas per turn.

## Support

- Understand game mechanics by examining CodePrix.sol contract
- Learn race script structure from RunRace.s.sol
- Get strategy ideas from existing car implementations
- Develop your strategy by watching race simulation

Good racing! 🏎️💨
