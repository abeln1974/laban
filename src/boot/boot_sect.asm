; MittOS Boot Sector
; ------------------------------
[org 0x7c00]        ; Bootloaderen lastes på denne adressen
[bits 16]           ; Vi starter i 16-bit real mode

KERNEL_OFFSET equ 0x1000  ; Minneadressen vi skal laste kjernen til

    ; Initialiser segmentregistre og stack
    cli                   ; Disable interrupts
    xor ax, ax            ; Nullstill AX
    mov ds, ax            ; Nullstill dataområdet
    mov es, ax            ; Nullstill ekstra segmentet
    mov ss, ax            ; Nullstill stack segmentet
    mov sp, 0x7c00        ; Sett stack pointer
    sti                   ; Enable interrupts
    
    ; Lagre boot drive
    mov [BOOT_DRIVE], dl
    
    ; Vis velkomstmelding
    mov si, MSG_WELCOME
    call print_string
    
    ; Last kjernen fra disk
    call load_kernel
    
    ; Vis melding om overgang til protected mode
    mov si, MSG_PROT_MODE
    call print_string
    
    ; Vent på en tast før vi fortsetter
    mov ah, 0
    int 0x16
    
    ; Bytt til 32-bit protected mode
    call switch_to_pm
    
    ; Vi kommer aldri hit, da switch_to_pm ikke returnerer
    jmp $

; ------------------------------
; 16-bit funksjoner
; ------------------------------

; Laster kjernen fra disk
load_kernel:
    push ax
    push bx
    push cx
    push dx
    
    mov si, MSG_LOAD_KERNEL
    call print_string
    
    ; Sett opp registre for disk-lesing
    mov ah, 0x02      ; BIOS disk read
    mov al, 15        ; Antall sektorer å lese (justere etter kjernens størrelse)
    mov ch, 0         ; Cylinder 0
    mov cl, 2         ; Start fra sektor 2 (sektor 1 er denne bootloaderen)
    mov dh, 0         ; Head 0
    mov dl, [BOOT_DRIVE] ; Disk-nummer
    mov bx, KERNEL_OFFSET ; Adresse å laste til
    
    ; Les fra disken
    int 0x13
    
    ; Sjekk for disklesefeil
    jc disk_error     ; Hopp hvis carry flag er satt
    
    ; Sjekk om vi leste riktig antall sektorer
    cmp al, 15        ; AL inneholder antall leste sektorer
    jne disk_error
    
    mov si, MSG_LOAD_SUCCESS
    call print_string
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
; Håndterer diskfeil
disk_error:
    mov si, MSG_DISK_ERROR
    call print_string
    jmp $             ; Hang forever
    
; Skriver ut en nullterminert streng
print_string:
    pusha
    mov ah, 0x0E      ; BIOS teletype output
    
.loop:
    lodsb             ; Last byte fra SI til AL
    or al, al         ; Test om vi har nådd slutten av strengen
    jz .done          ; Hvis AL er 0, er vi ferdige
    int 0x10          ; Skriv tegnet
    jmp .loop         ; Fortsett med neste tegn
    
.done:
    popa
    ret

; Forbereder GDT (Global Descriptor Table) for 32-bits mode
gdt_start:

gdt_null:             ; Null-deskriptor (kreves)
    dd 0x0            ; 4 nullbytes
    dd 0x0            ; 4 nullbytes

gdt_code:             ; Kode-segment deskriptor
    ; base=0x0, limit=0xfffff
    ; 1st flags: (present)1 (privilege)00 (descriptor type)1 -> 1001b
    ; type flags: (code)1 (conforming)0 (readable)1 (accessed)0 -> 1010b
    ; 2nd flags: (granularity)1 (32-bit default)1 (64-bit seg)0 (AVL)0 -> 1100b
    dw 0xffff         ; Segment limit (0-15)
    dw 0x0            ; Base (0-15)
    db 0x0            ; Base (16-23)
    db 10011010b      ; 1st flags, type flags
    db 11001111b      ; 2nd flags, limit (16-19)
    db 0x0            ; Base (24-31)

gdt_data:             ; Data-segment deskriptor
    ; Same as code segment except for the type flags:
    ; type flags: (code)0 (expand down)0 (writable)1 (accessed)0 -> 0010b
    dw 0xffff         ; Segment limit (0-15)
    dw 0x0            ; Base (0-15)
    db 0x0            ; Base (16-23)
    db 10010010b      ; 1st flags, type flags
    db 11001111b      ; 2nd flags, limit (16-19)
    db 0x0            ; Base (24-31)

gdt_end:              ; Brukes til å beregne størrelsen på GDT

; GDT descriptor
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Størrelse på GDT (alltid 1 mindre enn faktisk størrelse)
    dd gdt_start                 ; Adresse til GDT

; Segment offsets (skal lastes i segment registre)
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; ------------------------------
; 32-bit funksjoner
; ------------------------------

[bits 32]             ; All kode nedenfor er 32-bit

; Hopper til kjernen
BEGIN_PM:
    mov ax, DATA_SEG  ; Oppdater segment-registre
    mov ds, ax        ; med data-segmentet
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    mov ebp, 0x90000  ; Oppdater stack position
    mov esp, ebp
    
    ; Skriv ut en melding i protected mode
    mov ebx, MSG_PROT_MODE_LOADED
    call print_string_pm
    
    ; Hopp til kjernen
    call KERNEL_OFFSET
    
    ; Vi skal aldri komme hit, men hvis vi gjør det:
    jmp $

; Skriver ut en streng i 32-bit protected mode
print_string_pm:
    pusha
    mov edx, 0xb8000  ; Video memory adresse
    
.loop:
    mov al, [ebx]     ; Last tegn fra strengen
    mov ah, 0x0f      ; Attributt: hvit tekst på svart bakgrunn
    cmp al, 0         ; Sjekk om vi har nådd slutten av strengen
    je .done          ; Hvis ja, returner
    
    mov [edx], ax     ; Skriv tegn+attributt til videominnet
    add ebx, 1        ; Neste tegn i strengen
    add edx, 2        ; Neste posisjon i videominnet
    jmp .loop
    
.done:
    popa
    ret

; Bytter fra real mode til protected mode
switch_to_pm:
    cli               ; Slå av interrupts
    
    ; Last GDT-registeret
    lgdt [gdt_descriptor]
    
    ; Bytt til protected mode ved å sette bit 0 i cr0
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    
    ; Langt hopp til 32-bit kode
    ; Dette rengjør også pipelinen og laster CODE_SEG i CS
    jmp CODE_SEG:init_pm

[bits 32]
; Initialiserer registre og stack i protected mode
init_pm:
    call BEGIN_PM     ; Fullfør initialiseringen
    jmp $             ; Loop forever

; ------------------------------
; Data
; ------------------------------
BOOT_DRIVE db 0
MSG_WELCOME db 'MittOS Bootloader startet!', 13, 10, 0
MSG_LOAD_KERNEL db 'Laster kjerne fra disk...', 13, 10, 0
MSG_LOAD_SUCCESS db 'Kjerne lastet til minnet!', 13, 10, 0
MSG_DISK_ERROR db 'FEIL: Kunne ikke lese fra disk!', 13, 10, 0
MSG_PROT_MODE db 'Bytter til 32-bit protected mode...', 13, 10, 0
MSG_PROT_MODE_LOADED db 'Kjoerer naa i 32-bit protected mode!', 0

; Boot signatur
times 510-($-$$) db 0  ; Fyll resten av sektoren med nuller
dw 0xAA55               ; Boot signatur
