# Makefile for Diablo BSV

BSC = bsc
BSC_FLAGS = -keep-fires -cross-info -u

# External Dependencies
FLUTE_DIR = ../Flute
TOOOBA_DIR = ../Toooba

# Source directories
BSC_DIR_FLAGS = -p +:src:$(FLUTE_DIR)/src_Core/ISA:$(FLUTE_DIR)/src_Core/RegFiles:$(FLUTE_DIR)/src_Core/Core:$(TOOOBA_DIR)/src_Core/RISCY_OOO/procs/lib
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
	$(BSC) $(BSC_DIR_FLAGS) -vdir $(BUILD_DIR) -bdir $(BUILD_DIR) -info-dir $(BUILD_DIR) -simdir $(SIM_DIR) \
		$(BSC_FLAGS) -vsim verilator -e mkTb -o $(SIM_DIR)/out_Tb_verilator

run: build_verilator
	./$(SIM_DIR)/out_Tb_verilator

clean:
	rm -rf $(BUILD_DIR) $(SIM_DIR) test/*.bo test/*.ba test/*.cxx test/*.h test/*.o test/*.v

.PHONY: all build_verilator run clean
