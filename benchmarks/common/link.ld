OUTPUT_ARCH( "riscv" )
ENTRY( _start )
SECTIONS
{
  . = 0x80000000;
  .text : {
    *(.text.init)
    *(.text .text.*)
  }
  . = 0x80100000;
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .data : { *(.data .data.*) }
  .sdata : { 
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*) 
  }
  . = ALIGN(8);
  __bss_start = .;
  .bss : { 
    *(.bss .bss.*) *(.sbss .sbss.*) 
  }
  . = ALIGN(8);
  __bss_end = .;
  _end = .;
}
