# Makefile for Diablo BSV

BSC = bsc +RTS -K256M -RTS
BSC_FLAGS = -keep-fires -cross-info -u \
	-D RV64 \
	-D ISA_PRIV_M  -D ISA_PRIV_U  -D ISA_PRIV_S  \
	-D SV39  \
	-D ISA_I  -D ISA_M  -D ISA_A  -D ISA_C \
	-D ISA_F  -D ISA_D  -D INCLUDE_FDIV  -D INCLUDE_FSQRT \
	-D SHIFT_BARREL    \
	-D MULT_SYNTH    \
	-D Near_Mem_Caches    \
	-D FABRIC64    \
	-D WATCH_TOHOST

# External Dependencies
FLUTE_DIR = ../Flute
TOOOBA_DIR = ../Toooba

# Source directories
BSC_DIR_FLAGS = -p +:src:test:$(FLUTE_DIR)/src_Core/ISA:$(FLUTE_DIR)/src_Core/RegFiles:$(FLUTE_DIR)/src_Core/Core:$(FLUTE_DIR)/src_Core/CPU:$(FLUTE_DIR)/src_Core/Cache_Config:$(FLUTE_DIR)/src_Core/Near_Mem_VM_WT_L1:$(FLUTE_DIR)/src_Core/PLIC:$(FLUTE_DIR)/src_Core/Near_Mem_IO:$(FLUTE_DIR)/src_Core/Debug_Module:$(FLUTE_DIR)/src_Core/BSV_Additional_Libs:$(FLUTE_DIR)/src_Testbench/SoC:$(FLUTE_DIR)/src_Testbench/Fabrics/AXI4:$(TOOOBA_DIR)/src_Core/RISCY_OOO/procs/lib
# Build directories
BUILD_DIR = build
SIM_DIR = sim

all: build_verilator

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

# Verilator simulation target
build_verilator: $(BUILD_DIR) $(SIM_DIR)
	$(BSC) $(BSC_DIR_FLAGS) -vdir $(BUILD_DIR) -bdir $(BUILD_DIR) -info-dir $(BUILD_DIR) \
		$(BSC_FLAGS) -verilog -g mkTb test/Tb.bsv
	# python3 inject.py build/mkDiabloCore.v
	# python3 inject.py build/mkTb.v
	$(BSC) $(BSC_DIR_FLAGS) -vdir $(BUILD_DIR) -bdir $(BUILD_DIR) -info-dir $(BUILD_DIR) -simdir $(SIM_DIR) \
		$(BSC_FLAGS) -vsim verilator -e mkTb -o $(SIM_DIR)/out_Tb_verilator

run: build_verilator
	./$(SIM_DIR)/out_Tb_verilator

clean:
	rm -rf $(BUILD_DIR) $(SIM_DIR) test/*.bo test/*.ba test/*.cxx test/*.h test/*.o test/*.v

.PHONY: all build_verilator run clean
