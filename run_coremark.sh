#!/bin/bash
set -e

echo "Building CoreMark..."
make -C benchmarks/coremark PORT_DIR=baremetal clean
make -C benchmarks/coremark PORT_DIR=baremetal XCFLAGS="-DPERFORMANCE_RUN=1" coremark.elf

echo "Copying hex file to root..."
cp benchmarks/coremark/coremark.hex mem.hex

echo "Building Simulator..."
make

echo "Running Simulator (this may take a minute)..."
./sim/out_Tb_verilator > trace.log

echo "Extracting UART output:"
echo -e "\n\nRaw UART Output Reassembled:"
grep "UART:" trace.log | sed 's/UART: //g' | tr -d '\n'
echo ""
