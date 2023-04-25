

;--- define macros @setint0d and @restint0d
;--- these macros activate unreal mode

    align 8
gdt label qword
        dw -1,0,9200h,0CFh      ; 32-bit flat data descriptor
;       dw -1,0,9200h,0         ; 16-bit data descriptor

SEL_FLAT equ 8
;SEL_DATA16 equ 16

gdtr dw 3*8-1,0,0

;--- exception 0D: no need to check if it's a real exception,
;--- since interrupts were disabled.

int0d:
        push ds
        push eax
        lgdt fword ptr cs:[gdtr]
        mov eax,cr0
        inc ax
        mov cr0,eax
        jmp @F
@@:
        dec ax
        push SEL_FLAT
        pop ds
        mov cr0,eax
        pop eax
        pop ds
        iret

@setint0d macro
        pushf
        cli
        push ds
        push 0
        pop ds
        push ebx
        push cs
        push offset int0d
        mov  ebx,ds:[13*4]
        pop  dword ptr ds:[13*4]
endm
@restint0d macro
        mov ds:[13*4],ebx
        pop ebx
        pop ds
        popf
endm
