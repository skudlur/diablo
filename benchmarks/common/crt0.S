.global _start
.section .text.init
_start:
    # Initialize global pointer (if needed)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # Set up stack (at 0x8020_0000, e.g. 2MB from start)
    li sp, 0x80200000

    # Clear BSS
    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, 2f
1:
    sd zero, 0(a0)
    addi a0, a0, 8
    bltu a0, a1, 1b
2:

    # Call main
    call main

    # Write exit code to tohost to finish simulation
    # Exit code is (main_ret << 1) | 1. If main returns 0, exit code is 1 (SUCCESS).
    # If main returns anything else, it's 2*ret + 1 (FAIL).
    slli a0, a0, 1
    ori a0, a0, 1
    la t0, tohost
    sd a0, 0(t0)

3:  j 3b # infinite loop until Verilator terminates us

.section .tohost,"aw",@progbits
.align 6
.global tohost
tohost: .dword 0
.global fromhost
fromhost: .dword 0
