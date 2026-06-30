# Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)

# Toolchain setup
CC = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-gcc
LD = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-gcc
AS = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-gcc
OBJCOPY = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-objcopy

# Flags
OFLAG = -O3
CFLAGS = $(OFLAG) -mcmodel=medany -mabi=lp64 -march=rv64im -ffreestanding -I$(PORT_DIR) -I../common -I.
LFLAGS = -T ../common/link.ld -nostartfiles -lc -lgcc

# Port source files
PORT_SRCS = $(PORT_DIR)/core_portme.c ../common/syscalls.c ../common/crt0.S

# Define flags string for output
# FLAGS_STR = "$(OFLAG) $(CFLAGS) $(LFLAGS)"
ifndef ITERATIONS
ITERATIONS=1
endif
CFLAGS += -DFLAGS_STR="\"$(OFLAG)\"" -DITERATIONS=$(ITERATIONS) $(LFLAGS)

# Output files
OUTFLAG = -o
OBJOUT  = -o
OEXT = .o
EXE = .elf

# How to build the target
$(OPATH)%.o: %.c
	$(CC) $(CFLAGS) -c $< $(OBJOUT)$@

# Link
$(OPATH)$(PORT_DIR)/%$(OEXT) : $(PORT_DIR)/%.c
	$(CC) $(CFLAGS) -c $< $(OBJOUT)$@

$(OPATH)%$(OEXT) : %.S
	$(AS) $(CFLAGS) -c $< $(OBJOUT)$@

# Target definition
.PHONY: port_prebuild port_postbuild port_preload port_postload port_postrun

port_preload:

port_prebuild:

port_postbuild:
	$(OBJCOPY) -O binary $(OUTFILE) coremark.bin
	/home/skudlur/work/Flute/Tests/elf_to_hex/elf_to_hex $(OUTFILE) coremark.hex

port_postload:

port_postrun:
