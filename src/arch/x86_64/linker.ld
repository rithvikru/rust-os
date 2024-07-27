ENTRY(start) /* entry point specified by boot.asm */

SECTIONS {
  . = 1M;
  .boot : {
    *(.multiboot_header)
  }
  .text : {
    *(.text)
  }
}
