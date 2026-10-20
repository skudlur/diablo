CC = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-gcc
LD = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-gcc
OBJCOPY = /home/skudlur/work/diablo/toolchain/bin/riscv-none-elf-objcopy

OFLAG = -O3
CFLAGS = $(OFLAG) -mcmodel=medany -mabi=lp64 -march=rv64im -ffreestanding -I../common -I.
CFLAGS += -DTIME -DNOENUM -Wno-implicit-int -Wno-implicit-function-declaration
LFLAGS = -T ../common/link.ld -nostartfiles -lc -lgcc

SRCS = dhrystone.c dhrystone_main.c ../common/syscalls.c ../common/crt0.S

all: dhrystone.hex

dhrystone.elf: $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) $(LFLAGS) -o $@

dhrystone.bin: dhrystone.elf
	$(OBJCOPY) -O binary $< $@

dhrystone.hex: dhrystone.elf dhrystone.bin
	/home/skudlur/work/Flute/Tests/elf_to_hex/elf_to_hex $< $@

clean:
	rm -f *.elf *.bin *.hex
