#!/bin/bash
# Build script for Laban - En operativsystem fra bunnen av

set -e  # Avslutt scriptet hvis en kommando feiler

# Farger for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Mapper for prosjektet
SRC_DIR="src"
BOOT_DIR="${SRC_DIR}/boot"
KERNEL_DIR="${SRC_DIR}/kernel"
BUILD_DIR="build"
BIN_DIR="${BUILD_DIR}/bin"
OBJ_DIR="${BUILD_DIR}/obj"

# Filbaner for output
BOOTSECT_BIN="${BIN_DIR}/bootsect.bin"
KERNEL_BIN="${BIN_DIR}/kernel.bin"
OS_IMAGE="${BUILD_DIR}/os-image.bin"

echo -e "${BLUE}Bygger Laban...${NC}"

# Variabler for nasm og gcc
NASM_VERSION="2.16.01"
NASM_TAR="nasm-${NASM_VERSION}.tar.gz"
NASM_URL="https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/${NASM_TAR}"
NASM_LOCAL="build/nasm"
NASM_BIN="${NASM_LOCAL}/nasm"

# Sjekk om nødvendige verktøy er installert
NASM_INSTALLED=true
if ! command -v nasm &> /dev/null; then
    NASM_INSTALLED=false
    echo -e "${YELLOW}NASM er ikke installert systemet.${NC}"
    
    # Sjekk om vi allerede har en lokal nasm installasjon
    if [ -f "${NASM_BIN}" ]; then
        echo -e "${GREEN}Bruker tidligere nedlastet NASM fra ${NASM_BIN}${NC}"
        NASM_CMD="${NASM_BIN}"
    else
        echo -e "${YELLOW}Prøver å laste ned og bygge NASM lokalt...${NC}"
        
        # Opprett build-mappen hvis den ikke eksisterer
        mkdir -p build
        
        # Nedlastingsalternativ for brukeren
        echo -e "${YELLOW}For å fortsette, du kan enten:${NC}"
        echo -e "1. Installere NASM systemet med: ${GREEN}sudo apt-get install nasm${NC}"
        echo -e "2. Last ned NASM manuelt fra: ${GREEN}${NASM_URL}${NC}"
        echo -e "   og lagre i ${GREEN}${NASM_LOCAL}${NC}-mappen"
        echo -e "${RED}Build-prosessen kan ikke fortsette uten NASM.${NC}"
        exit 1
    fi
else
    NASM_CMD="nasm"
    echo -e "${GREEN}NASM funnet: $(nasm --version)${NC}"
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo -e "${RED}QEMU er ikke installert. Installer med:${NC}"
    echo "sudo apt-get install qemu-system-x86"
    exit 1
fi

# Sjekk for GCC cross-compiler
if ! command -v i686-elf-gcc &> /dev/null; then
    echo -e "${YELLOW}i686-elf-gcc (cross-compiler) ikke funnet.${NC}"
    echo -e "${YELLOW}Bruker standard GCC med spesielle flagg for fristående kjerne...${NC}"
    GCC_CMD="gcc"
    LD_CMD="ld"
    
    # Flagg for standard GCC for å bygge en fristående kjerne
    GCC_FLAGS="-m32 -ffreestanding -fno-pie -fno-stack-protector -nostdlib -nostdinc -mno-red-zone"
    LD_FLAGS="-m elf_i386 -nostdlib --oformat binary -Ttext 0x1000"
else
    echo -e "${GREEN}i686-elf-gcc funnet!${NC}"
    GCC_CMD="i686-elf-gcc"
    LD_CMD="i686-elf-ld"
    
    # Flagg for cross-compiler
    GCC_FLAGS="-m32 -ffreestanding"
    LD_FLAGS="-m elf_i386 --oformat binary -Ttext 0x1000"
fi

# Opprett mappestruktur hvis den ikke eksisterer
mkdir -p ${BUILD_DIR} ${BIN_DIR} ${OBJ_DIR}

# Kompiler bootloaderen
echo -e "${GREEN}Kompilerer bootloader...${NC}"
${NASM_CMD} ${BOOT_DIR}/boot_sect.asm -f bin -o ${BOOTSECT_BIN}

# Kompiler kernel entry assembly kode
echo -e "${GREEN}Kompilerer kernel entry...${NC}"
${NASM_CMD} ${KERNEL_DIR}/kernel_entry.asm -f elf -o ${OBJ_DIR}/kernel_entry.o

# Kompiler C-kjernen
echo -e "${GREEN}Kompilerer C-kjernekode...${NC}"
${GCC_CMD} ${GCC_FLAGS} -c ${KERNEL_DIR}/kernel.c -o ${OBJ_DIR}/kernel.o -Wall -Wextra

# Linke kjernen
echo -e "${GREEN}Linker kjernen...${NC}"
${LD_CMD} -o ${KERNEL_BIN} ${LD_FLAGS} ${OBJ_DIR}/kernel_entry.o ${OBJ_DIR}/kernel.o

# Generer OS-image
echo -e "${GREEN}Genererer disk image...${NC}"
cat ${BOOTSECT_BIN} ${KERNEL_BIN} > ${OS_IMAGE}
# Pad to floppy disk size (1.44MB)
CURRENT_SIZE=$(stat -c %s ${OS_IMAGE})
MAX_SIZE=1474560  # 1.44MB
if [ ${CURRENT_SIZE} -lt ${MAX_SIZE} ]; then
    dd if=/dev/zero bs=1 count=$((${MAX_SIZE} - ${CURRENT_SIZE})) >> ${OS_IMAGE} 2>/dev/null
fi

echo -e "${BLUE}Bygging fullført!${NC}"
echo -e "${GREEN}OS image: ${OS_IMAGE}${NC}"
echo -e "${GREEN}For å kjøre i QEMU:${NC}"
echo "qemu-system-x86_64 -drive file=${OS_IMAGE},format=raw"
echo ""
echo -e "${YELLOW}For å avslutte OS i QEMU, bruk ESC-tasten eller lukk QEMU-vinduet.${NC}"

# Spør om brukeren vil kjøre OS-et nå
echo -e "${BLUE}Vil du kjøre Laban nå? (j/n)${NC}"
read -r svar
if [[ "$svar" =~ ^[Jj] ]]; then
    echo -e "${GREEN}Starter Laban i QEMU...${NC}"
    qemu-system-x86_64 -drive file=${OS_IMAGE},format=raw
fi
