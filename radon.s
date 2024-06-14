; radon transform sinogram of 400x100 rectangle
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

section .data

constants:
	dd 0x3c0f0846 ; 0.00873, rotation of ~0.5 deg per frame

section .text

	mov  ebp, 1920 * 1080 * 4 ; screen size
	sub  esp, ebp             ; alloca
	fldz                      ; angle z=0

main:
	; evaluation grid of 1920*400
	mov ecx, 1420800 ; 1920*1080 - 1920*340

draw:
	mov ebx, 1920
	mov eax, ecx
	cdq
	div ebx ; edx = x-coord , eax = y-coord

	;; translate to center
	add edx, -960
	add eax, -540

	push edx
	push eax

	;; rotate x,y: x0 = x * cos + y * sin, y0 = y * cos - x * sin
	fld     st0           ; z z
	fsincos               ; cos sin z
	fild    dword [esp  ] ; y cos sin z
	fild    dword [esp+4] ; x y cos sin z
	fld     st3           ; sin x y cos sin z
	fld     st3           ; cos sin x y cos sin z
	fmul    st0, st2      ; x*cos sin x y cos sin z
	fxch                  ; sin x*cos x y cos sin z
	fmul    st0, st3      ; y*sin x*cos x y cos sin z
	faddp                 ; x*cos+y*sin x y cos sin z
	fistp   dword [esp+4] ; x y cos sin z
	fxch    st2           ; cos y x sin z
	fmulp                 ; y*cos x sin z
	fxch    st2           ; sin x y*cos z
	fmulp                 ; x*sin y*cos z
	fsubp                 ; y*cos-x*sin z
	fistp   dword [esp  ] ; z

	pop edi ; rotated y
	pop edx ; rotated x

	push eax ; y

	;; indicator function of object: 400x100 rectangle, center at 0,0
	add  edx, 99
	cmp  edx, 199
	setb al
	add  edi, 49
	cmp  edi, 99
	setb bl
	and  al, bl

	mov ebx, 0xff
	mul ebx

	pop ebx ; y note needed for sinogram

	mov [esp+ecx*4+2], al ; rotating object

	dec ecx
	cmp ecx, 1920*340
	ja  draw

	; ssize_t pwrite64(int fd, const void *buf, size_t count, off_t offset)
	mov ecx, esp ; buffer ptr
	mov edx, ebp ; screen size
	xor esi, esi ; seek to beginning of screen
	xor edi, edi
	mov ebx, 3    ; fd of framebuffer
	mov eax, 0xb5 ; pwrite64
	int 0x80      ; syscall

	fadd dword [constants] ; increment z
	jmp main
