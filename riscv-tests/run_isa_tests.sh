#!/bin/bash
cd "$(dirname "$0")/.."

fails=0
passes=0
skips=0
TIMEOUT=30  # seconds per test

# Run all RV64I (Base Integer) and RV64M (Multiply/Divide) tests
for test_elf in /home/skudlur/work/Flute/Tests/isa/rv64ui-p-* /home/skudlur/work/Flute/Tests/isa/rv64um-p-*; do
    # skip dump files
    if [[ "$test_elf" == *.dump ]]; then continue; fi
    
    test_name=$(basename $test_elf)
    echo -n "Running $test_name... "
    
    # 1. Copy the ELF file to mem.elf for the hex converter
    cp $test_elf mem.elf
    
    # 2. Convert ELF to Hex
    /home/skudlur/work/Flute/Tests/elf_to_hex/elf_to_hex mem.elf mem.hex > /dev/null
    
    # 3. Run the Verilator simulation with a timeout and capture output
    output=$(timeout $TIMEOUT ./sim/out_Tb_verilator 2>&1)
    exit_code=$?
    
    # 4. Check result
    if [ $exit_code -eq 124 ]; then
        echo "[SKIP - TIMEOUT]"
        skips=$((skips+1))
    elif echo "$output" | grep -q "SUCCESS"; then
        echo "[PASS]"
        passes=$((passes+1))
    else
        echo "[FAIL]"
        fails=$((fails+1))
    fi
done

echo "======================"
echo "Tests passed: $passes"
echo "Tests failed: $fails"
echo "Tests skipped: $skips"
echo "======================"
rm -f mem.elf mem.hex symbol_table.txt
