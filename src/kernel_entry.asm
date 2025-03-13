[bits 32]
[extern main]     ; Deklarerer at 'main' er en ekstern funksjon (definert i C-koden)

section .text
    ; Multiboot header for GRUB (kan utvides senere)
    align 4
    dd 0x1BADB002            ; Magisk nummer
    dd 0x00                  ; Flagg
    dd -(0x1BADB002 + 0x00)  ; Sjekksum

global _start
_start:
    cli                      ; Skru av interrupts
    mov esp, stack_space     ; Sett opp stack 
    call main                ; Kall hovedfunksjonen i C
    hlt                      ; Stopp prosessoren

section .bss
    resb 8192               ; 8KB for stack
stack_space:
