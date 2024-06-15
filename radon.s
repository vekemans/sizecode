; radon transform sinogram of 200x100 rectangle
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

	mov  ebp, 1920 * 1080 * 4 ; screen size
	sub  esp, ebp             ; alloca
	fldz                      ; angle z=0
	fldz                      ; sum=0 (line integral)

main:
	; evaluation grid of 1920*224 (rectangle diagonal)
	mov ecx, (1920*1080 - 1920*428) ; pixel index

draw:
	mov ebx, 1920
	mov eax, ecx
	cdq
	div ebx ; edx = x-coord , eax = y-coord

	push eax

	; translate to center
	add edx, -960
	add eax, -540

	push edx
	push eax

	; rotate x,y: rx = x * cos + y * sin, ry = y * cos - x * sin
	fld     st0           ; [z z]
	fsincos               ; [cos sin z]
	fild    dword [esp  ] ; [y cos sin z]
	fild    dword [esp+4] ; [x y cos sin z]
	fld     st3           ; [sin x y cos sin z]
	fld     st3           ; [cos sin x y cos sin z]
	fmul    st0, st2      ; [x*cos sin x y cos sin z]
	fxch                  ; [sin x*cos x y cos sin z]
	fmul    st0, st3      ; [y*sin x*cos x y cos sin z]
	faddp                 ; [x*cos+y*sin x y cos sin z]
	fistp   dword [esp+4] ; [x y cos sin z]
	fxch    st2           ; [cos y x sin z]
	fmulp                 ; [y*cos x sin z]
	fxch    st2           ; [sin x y*cos z]
	fmulp                 ; [x*sin y*cos z]
	fsubp                 ; [y*cos-x*sin z]
	fistp   dword [esp  ] ; [z]

	pop edi ; rotated y
	pop edx ; rotated x

	push esi ; sum
	fld dword [esp] ; [sum, z]
	pop esi

	; indicator function of object: 200x100 rectangle, center at 0,0
	add  edx, 99
	cmp  edx, 199
	setb al
	add  edi, 49
	cmp  edi, 99
	setb bl
	and  al, bl

	push eax
	push 0xff

	; summation of indicator function outputs
	fiadd dword [esp+4]   ; [sum+f(rx,ry) z]
	fmul  dword [const+4] ; [0.005*(sum+f(rx,ry)) z]
	fld   st0
	fimul dword [esp]     ; [0xff*0.005*(sum+f(rx,ry)) 0.005*(sum+f(rx,ry)) z]

	pop   eax
	fistp dword [esp]    ; [sum z]
	pop   eax            ; color output
	pop   edi            ; original y
	imul  ebx, edi, 1920 ; y * 1920

	push esi
	fstp dword [esp] ; [z]
	pop esi ; sum

	push edx

	; scale z (z -> x mapping)
	fld   dword [const+8] ; [114.6 z]
	fmul  st0, st1        ; [114.6*z z]
	fistp dword [esp]     ; [z]

	pop edx
	add edx, ebx ; z + y * 1920

	add [esp+edx*4+2], al ; sinogram

	dec ecx
	cmp ecx, 1920*428
	ja  draw

	fadd dword [const] ; increment z

	; ssize_t pwrite64(int fd, const void *buf, size_t count, off_t offset)
	mov ecx, esp ; buffer ptr
	mov edx, ebp ; screen size
	xor esi, esi ; seek to beginning of screen
	xor edi, edi
	mov ebx, 3    ; fd of framebuffer
	mov eax, 0xb5 ; pwrite64
	int 0x80      ; syscall

	jmp main

const:
	; 1-zt*rot should be close to zero to minimize error when mapping z->x
	dd 0x3c0f0846 ; 0.00873, rotation of ~0.5 deg per frame
	dd 0x3b83126f ; 0.004, sum scaling
	dd 0x42e5199a ; 114.55, z scaling
