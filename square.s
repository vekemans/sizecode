; renders 200x200 red square on the center of the screen (assumes 1920x1080 resolution)
bits 32
org 0x00010000
	; minimal ELF header (muppetlabs.com/~breadbox/software/tiny/teensy.html)
	db 0x7f,"ELF" ; e_ident
	dd 1          ; p_type
	dd 0          ; p_offset
	dd $$         ; p_vaddr
	dw 2          ; e_type, p_paddr
	dw 3          ; e_machine
	dd entry      ; e_version, p_filesz
	dd entry      ; e_entry, p_memsz
	dd 4          ; e_phoff, p_flags

fname:
	db "/dev/fb0", 0 ; e_shoff, p_align, e_flags, e_ehsize
entry:
	mov ebx, fname ; e_phentsize, e_phnum
	inc ecx        ; = 1 = O_WRONLY
	mov al, 5      ; 5 = open syscall
	int 0x80       ; open /dev/fb0 = 3

	mov ebp, 1920 * 1080 * 4 ; screen size
	sub esp, ebp ; alloca

main:
	mov ecx, ebp ; pixel index
	shr ecx, 2   ; 1920 * 1080

draw:
	mov ebx, 1920
	mov eax, ecx
	cdq
	div ebx ; edx = x-coord , eax = y-coord
	; check if pixel is inside square:
	; 860  = (1920 - 200) / 2
	; 1060 = 860 + 200
	; 440  = (1080 - 200) / 2
	; 640  = 440 + 200
	; x,y > 0 => (x - 861 < 199) && (y - 441 < 199)
	sub edx, 861
	mov ebx, 199
	cmp edx, ebx
	jae outside ; (x - 861 >= 199)
	sub eax, 441
	cmp eax, ebx
	jae outside ; (y - 441 >= 199)
	mov [esp+ecx*4+2], byte 0xff ; red (BGRA)
outside:
	loop draw

	; ssize_t pwrite64(int fd, const void *buf, size_t count, off_t offset)
	mov ecx, esp ; buffer ptr
	mov edx, ebp ; screen size
	xor esi, esi ; seek to beginning of screen
	xor edi, edi
	mov ebx, 3    ; fd of framebuffer
	mov eax, 0xb5 ; pwrite64
	int 0x80      ; syscall

	jmp main
