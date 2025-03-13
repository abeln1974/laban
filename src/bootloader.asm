; Laban Bootloader
; Forbedret bootloader med disklesing og kjernelasting

[org 0x7c00]    ; Bootloader lastes på denne minneadressen
[bits 16]       ; Vi starter i 16-bit real mode

    ; Initialiser segmentregistre
    cli         ; Skru av interrupts midlertidig
    xor ax, ax  ; Nullstill AX
    mov ds, ax  ; Nullstill dataområdet
    mov es, ax  ; Nullstill ekstra segmentet
    mov ss, ax  ; Nullstill stack segmentet
    mov sp, 0x7c00  ; Sett stack pointer rett under bootloader
    sti         ; Skru på interrupts igjen
    
    ; Lagre boot drive nummer
    mov [boot_drive], dl
    
    ; Skriv en melding til skjermen
    mov si, velkomstmelding
    call skriv_streng
    
    ; Les noen sektorer fra disk til minnet (simulert kjernelasting)
    mov si, les_disk_melding
    call skriv_streng
    
    ; Call Les disk
    mov ah, 0x02    ; BIOS lesesektor-funksjon
    mov al, 1       ; Les 1 sektor
    mov ch, 0       ; Cylinder 0
    mov cl, 2       ; Sektor 2 (1-indeksert, sektor etter bootloaderen)
    mov dh, 0       ; Head 0
    mov dl, [boot_drive] ; Drive nummer
    mov bx, 0x9000  ; Buffer for lest data
    int 0x13        ; BIOS-interrupt for diskfunksjoner
    jc disk_error   ; Hopp hvis carry-flag satt (feil)
    
    ; Sjekk om vi leste riktig antall sektorer
    cmp al, 1       ; AL inneholder antall leste sektorer
    jne disk_error  ; Hvis ikke lik forventet antall

    ; Vis suksessmelding
    mov si, disk_suksess
    call skriv_streng
    
    ; Nå skal vi simulere at vi bytter til grafikkmodus
    mov si, mode_bytte
    call skriv_streng
    
    ; Vent på tastetrykk før vi fortsetter
    mov ah, 0x00    ; BIOS vent på tastetrykk
    int 0x16        ; Tastatur-interrupt
    
    ; Bytt til farget tekst-modus (80x25 16 farger)
    mov ah, 0x00    ; BIOS sett videomodus
    mov al, 0x03    ; 80x25 16 farger tekstmodus
    int 0x10
    
    ; Vis en fargerik beskjed
    mov ah, 0x09    ; BIOS skriv tegn og attributt
    mov bx, 0x0F    ; Høy intensitet hvit på svart
    mov cx, 20      ; Gjenta 20 ganger
    mov al, '*'     ; Tegnet vi vil skrive
    int 0x10
    
    ; Forbered for å simulere kall til kjernen
    mov si, kjerne_melding
    call skriv_streng
    
    ; Vent på en tast
    mov ah, 0x00
    int 0x16
    
    ; Simuler kall til kjernen
    jmp $           ; Loop for alltid (i en ekte OS ville vi hoppe til kjernen)
    
; Disk feilhåndtering
disk_error:
    mov si, disk_feil
    call skriv_streng
    jmp $           ; Loop for alltid
    
; Funksjon: skriv_streng
; Skriver ut en null-terminert streng
skriv_streng:
    pusha           ; Lagre alle registre
    mov ah, 0x0E    ; BIOS teletype funksjon
    mov bh, 0       ; Sidenummer
    mov bl, 0x07    ; Lys grå på svart
    
.neste_tegn:
    lodsb           ; Last neste tegn fra SI til AL
    or al, al       ; Test om AL er 0 (slutten av strengen)
    jz .ferdig      ; Hvis AL er 0, er vi ferdige
    int 0x10        ; Kall BIOS for å skrive tegnet
    jmp .neste_tegn ; Gjenta for neste tegn
    
.ferdig:
    popa            ; Gjenopprett registre
    ret

; Data
boot_drive     db 0
velkomstmelding db 'Laban Bootloader startet!', 13, 10, 0
les_disk_melding db 'Leser fra disk...', 13, 10, 0
disk_suksess   db 'Disk lest suksessfullt!', 13, 10, 0
disk_feil      db 'Feil ved lesing av disk!', 13, 10, 0
mode_bytte     db 'Bytter til fargemodus, trykk en tast...', 13, 10, 0
kjerne_melding db 'Klar til aa starte kjernen, trykk en tast...', 13, 10, 0

; Padding og boot signature
times 510-($-$$) db 0   ; Fyll opp til 510 bytes
dw 0xAA55               ; Boot signature på slutten
