# MittOS - Et operativsystem fra bunnen av

MittOS er et minimalt operativsystem bygget fra bunnen av for å forstå grunnleggende OS-konsepter og lavnivåprogrammering.

## Prosjektstruktur

```
MittOS/
├── build/             # Kompilerte binærfiler og objektfiler
│   ├── bin/           # Binærfiler (bootloader.bin, kernel.bin)
│   ├── obj/           # Objektfiler (.o)
│   └── os-image.bin   # Ferdig OS-image (bootloader + kernel)
├── src/               # Kildekode
│   ├── boot/          # Bootloader-kode
│   │   └── boot_sect.asm  # Bootloader i assembly
│   └── kernel/        # Kjernekode
│       ├── kernel.c       # Hovedkjernekode i C
│       └── kernel_entry.asm # Entry-punkt for kjernen i assembly
└── build.sh           # Byggscript for å kompilere OS-et
```

## Funksjoner

- 16-bit real mode bootloader som laster kjernekoden
- Overgang fra 16-bit real mode til 32-bit protected mode
- Enkel tekstbasert skjermutskrift med VGA 
- Tastaturhåndtering
- Grafiske effekter for demonstration

## Avhengigheter

- NASM (Netwide Assembler) - for å kompilere assembly-kode
- GCC (GNU Compiler Collection) - for å kompilere C-kode (helst i686-elf-gcc cross-compiler)
- QEMU - for å emulere og teste OS-et

## Bygging og kjøring

Bygg og kjør OS-et med følgende kommando:

```bash
./build.sh
```

Scriptet vil:
1. Sjekke at nødvendige verktøy er installert
2. Kompilere bootloaderen
3. Kompilere kernel_entry.asm og kernel.c
4. Linke kjernen
5. Generere et bootbart disk-image
6. Spørre om du vil kjøre OS-et i QEMU

## Arkitektur

MittOS er primært bygget for x86-arkitekturen og bruker:
- 16-bit BIOS for oppstart
- GDT (Global Descriptor Table) for å definere minnesegmenter
- 32-bit protected mode for hovedkjøring av kjernen
- VGA tekstmodus for skjermvisning (80x25 tegn)

## Status

- [x] Fungerende bootloader
- [x] Laste kjerne fra disk
- [x] Bytte til 32-bit protected mode
- [x] Enkel skjermutskrift fra kjernen
- [x] Tastaturhåndtering
- [ ] Minne-management (paging)
- [ ] Filsystem
- [ ] Prosesshåndtering

## Fremtidige planer

- Implementere et filsystem (f.eks. FAT16)
- Legge til minne-management med paging
- Støtte for flere prosesser og fleroppgavekjøring
- Utvikle en kommandolinje (shell)
- Legge til støtte for flere arkitekturer
