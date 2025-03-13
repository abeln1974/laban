[bits 32]
[extern main]    ; Deklarerer at vi har en 'main' funksjon i en annen fil

; Kernel entry point som bootloaderen vil hoppe til
global _start
_start:
    call main    ; Kaller C-funksjon main() i kernel.c
    jmp $        ; Loop for alltid hvis main noensinne returnerer
