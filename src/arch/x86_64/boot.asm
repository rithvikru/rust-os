global start

section .text
bits 32
start:
  ; init stack
  mov esp, stack_top

  ; checks
  call check_multiboot
  call check_cpuid
  call check_long_mode

  ; paging
  call set_up_page_tables
  call enable_paging

  ; print "OK" to screen
  mov dword [0xb8000], 0x2f4b2f4f
  hlt

check_multiboot:
  cmp eax, 0x36d76289
  jne .no_multiboot
  ret

.no_multiboot:
  mov al, "0"
  jmp error

check_cpuid:
  ; Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
  ; the FLAGS register. If we can flip it, CPUID is available.

  ; Copy FLAGS in to EAX via stack
  pushfd
  pop eax

  ; Copy to ECX as well for comparing later on
  mov ecx, eax

  ; Flip the ID bit
  xor eax, 1 << 21

  ; Copy EAX to FLAGS via the stack
  push eax
  popfd

  ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
  pushfd
  pop eax

  ; Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
  ; back if it was ever flipped).
  push ecx
  popfd

  ; Compare EAX and ECX. If they are equal then that means the bit wasn't
  ; flipped, and CPUID isn't supported.
  xor eax, ecx
  jz .no_cpuid
  ret

.no_cpuid:
  mov al, "1"
  jmp error

check_long_mode:
  mov eax, 0x80000000     ; Set the A-register to 0x80000000.
  cpuid                   ; CPU identification.
  cmp eax, 0x80000001     ; Compare the A-register with 0x80000001.
  jb .no_long_mode        ; It is less, there is no long mode.


  mov eax, 0x80000001     ; Set the A-register to 0x80000001.
  cpuid                   ; CPU identification.
  test edx, 1 << 29       ; Test if the LM-bit, which is bit 29, is set in the D-register.
  jz .no_long_mode        ; They aren't, there is no long mode.
  ret

.no_long_mode:
  mov al, "2"
  jmp error

set_up_page_tables:
  mov eax, p3_table       ; move p3 table to A register
  or eax, 0b11            ; present, writable
  mov [p4_table], eax     ; map p4 table to p3 table

  mov eax, p2_table       ; move p2 table to A register
  or eax, 0b11            ; present, writable
  mov [p3_table], eax     ; map p3 table to p2 table

  mov ecx, 0              ; counter var for mapping pages
  ret

.map_p2_table:
  ; map ecx-th p2 entry to 2MiB*ecx-th page
  mov eax, 0x200000       ; 2MiB
  mul ecx                 ; start at address of ecx-th page
  or eax, 0b10000011      ; present, writable, huge
  mov [p2_table + ecx * 8], eax ; map ecx-th entry

  inc ecx                 ; increment counter
  cmp ecx, 512            ; if ecx == 512 entire p2 table is mapped (8*512=4096)
  jne .map_p2_table       ; else if ecx != 512 map next entry

  ret                     ; now first gb (512*2MiB) of kernel is identity mapped

enable_paging:
  mov eax, p4_table       ; move p4 table to A regsiter
  mov cr3, eax            ; load p4 table to cr3 register (cpu uses this to access p4 table)

  mov eax, cr4            ; move cr4 to A register
  or eax, 1 << 5          ; enable PAE-flag in cr4
  mov cr4, eax            ; move enabled PAE-flag cr4 in A register back into cr4 register

  ; set the long mode bit in the EFER MSR (model specific register)
  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8          ; long mode bit
  wrmsr

  mov eax, cr0            ; move cr0 to A register
  or eax, 1 << 31         ; paging bit
  mov cr0, eax            ; move paging enabled cr0 in A regsiter back into cr0 register

  ret

error:
  mov dword [0xb8000], 0x4f524f45
  mov dword [0xb8004], 0x4f3a4f52
  mov dword [0xb8008], 0x4f204f20
  mov byte  [0xb800a], al
  hlt

section .bss
align 4096
p4_table:
  resb 4096
p3_table:
  resb 4096
p2_table:
  resb 4096
stack_bottom:
  resb 64
stack_top:
