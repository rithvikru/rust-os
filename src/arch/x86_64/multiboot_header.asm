section .multiboot_header 
header_start:
  dd 0xE85250D6                 ; magic number (u32)
  dd 0                          ; architecture (u32)
  dd header_end - header_start  ; header length (u32)
  ; checksum (u32)
  dd 0x100000000 - (0xE85250D6 + 0 + header_end - header_start)

  ; end tag (type, flags, size)
  dw 0      ; endtag (u16)
  dw 0      ; endtag (u16)
  dw 8      ; endtag (u32)
header_end:
