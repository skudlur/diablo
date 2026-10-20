#!/bin/bash
set -e

echo "Building Dhrystone..."
make -C benchmarks/dhrystone clean all
make -C benchmarks/dhrystone

echo "Copying hex file to root..."
cp benchmarks/dhrystone/dhrystone.hex mem.hex

echo "Building Simulator..."
make

echo "Running Simulator (this may take a minute)..."
./sim/out_Tb_verilator > trace.log

echo "Extracting UART output:"
grep "UART:" trace.log | sed 's/UART: //g' | tr -d '\n' | grep -o '.*'
# The tr command helps re-assemble the characters printed one by one
# A simpler way to view the output is to just grep and strip the "UART: " prefix:
echo -e "\n\nRaw UART Output Reassembled:"
grep "UART:" trace.log | sed 's/UART: //g' | tr -d '\n'
echo ""
