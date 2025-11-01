#!/bin/bash
set -e

echo "🏎️  codePrix - Car Compilation & Race Simulation"
echo "==============================================="

echo "🔨 Compiling contracts..."
forge build

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

echo "✅ Compilation successful!"

echo "📤 Extracting bytecode..."
node extract-bytecode.cjs

echo ""
echo "🏁 Running race simulation..."
echo "=============================="
forge script script/RunRace.s.sol -vvv

echo ""
echo "📋 Bytecode files generated in ./bytecode/ directory"
echo "📝 Your car is ready for submission!"
echo ""
echo "🎯 Next steps:"
echo "1. Review your car's performance above"
echo "2. Modify src/cars/ExampleCar.sol to improve strategy"
echo "3. Run ./compile.sh again to test changes"
echo "4. Submit bytecode when satisfied with performance"
echo ""
echo "🏁 Good luck in the races! 🏁"