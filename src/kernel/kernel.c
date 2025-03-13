/**
 * Laban Kernel
 * Hovedkjernekode for operativsystemet
 */

// Adresse for videominnet (VGA tekstmodus)
unsigned char* video_memory = (unsigned char*) 0xB8000;

// Størrelse på skjermen
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// Markørposisjon
int cursor_x = 0;
int cursor_y = 0;

// VGA farger
enum vga_color {
    VGA_COLOR_BLACK = 0,
    VGA_COLOR_BLUE = 1,
    VGA_COLOR_GREEN = 2,
    VGA_COLOR_CYAN = 3,
    VGA_COLOR_RED = 4,
    VGA_COLOR_MAGENTA = 5,
    VGA_COLOR_BROWN = 6,
    VGA_COLOR_LIGHT_GREY = 7,
    VGA_COLOR_DARK_GREY = 8,
    VGA_COLOR_LIGHT_BLUE = 9,
    VGA_COLOR_LIGHT_GREEN = 10,
    VGA_COLOR_LIGHT_CYAN = 11,
    VGA_COLOR_LIGHT_RED = 12,
    VGA_COLOR_LIGHT_MAGENTA = 13,
    VGA_COLOR_LIGHT_BROWN = 14,
    VGA_COLOR_WHITE = 15,
};

// Typer for lesbarhet
typedef unsigned int size_t;
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;

// Lager et 8-bit fargeattributt fra forgrunn og bakgrunn
static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg) {
    return fg | bg << 4;
}

// Lager en 16-bit VGA tekstmodus post
static inline uint16_t vga_entry(unsigned char c, uint8_t color) {
    return (uint16_t) c | (uint16_t) color << 8;
}

// Finner lengden på en null-terminert streng
size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len])
        len++;
    return len;
}

// I/O funksjoner
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// Oppdaterer hardware-markøren
void update_cursor() {
    uint16_t position = cursor_y * VGA_WIDTH + cursor_x;
    
    // Port 0x3D4 velger registeret, 0x3D5 setter verdien
    outb(0x3D4, 14);                  // Velg høy byte
    outb(0x3D5, (position >> 8) & 0xFF);
    outb(0x3D4, 15);                  // Velg lav byte 
    outb(0x3D5, position & 0xFF);
}

// Tømmer skjermen
void clear_screen() {
    uint8_t color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    uint16_t empty = vga_entry(' ', color);
    
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        ((uint16_t*)video_memory)[i] = empty;
    }
    
    cursor_x = 0;
    cursor_y = 0;
    update_cursor();
}

// Scroller skjermen opp en linje
void scroll() {
    uint8_t color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    uint16_t empty = vga_entry(' ', color);
    
    // Flytt innholdet en linje opp
    for (int i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++) {
        ((uint16_t*)video_memory)[i] = ((uint16_t*)video_memory)[i + VGA_WIDTH];
    }
    
    // Tøm nederste linje
    for (int i = (VGA_HEIGHT - 1) * VGA_WIDTH; i < VGA_HEIGHT * VGA_WIDTH; i++) {
        ((uint16_t*)video_memory)[i] = empty;
    }
    
    cursor_y--;
}

// Skriver ut et tegn på gjeldende markørposisjon
void putchar(char c, uint8_t color) {
    // Håndter spesialtegn
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
    } else if (c == '\r') {
        cursor_x = 0;
    } else if (c == '\b') {
        if (cursor_x > 0) {
            cursor_x--;
            ((uint16_t*)video_memory)[cursor_y * VGA_WIDTH + cursor_x] = vga_entry(' ', color);
        }
    } else if (c == '\t') {
        // Tab er 4 mellomrom
        cursor_x = (cursor_x + 4) & ~(4 - 1);
    } else {
        ((uint16_t*)video_memory)[cursor_y * VGA_WIDTH + cursor_x] = vga_entry(c, color);
        cursor_x++;
    }
    
    // Håndter linjeskift
    if (cursor_x >= VGA_WIDTH) {
        cursor_x = 0;
        cursor_y++;
    }
    
    // Scrolling hvis nødvendig
    if (cursor_y >= VGA_HEIGHT) {
        scroll();
    }
    
    update_cursor();
}

// Skriver ut en streng
void print(const char* str, uint8_t color) {
    for (size_t i = 0; i < strlen(str); i++) {
        putchar(str[i], color);
    }
}

// Skriver en streng på en bestemt posisjon på skjermen
void print_at(const char* str, int col, int row, uint8_t color) {
    // Lagre forrige markørposisjon
    int old_x = cursor_x;
    int old_y = cursor_y;
    
    // Sett ny markørposisjon
    cursor_x = col;
    cursor_y = row;
    
    // Skriv strengen
    print(str, color);
    
    // Gjenopprett markørposisjon
    cursor_x = old_x;
    cursor_y = old_y;
    update_cursor();
}

// Les tegn fra tastaturet
char get_key() {
    char c = 0;
    
    // Sjekk om det er data tilgjengelig
    if (inb(0x64) & 1) {
        c = inb(0x60);
    }
    
    // Enkelt tastaturkart for noen vanlige tegn
    switch (c) {
        case 0x1E: return 'a';
        case 0x30: return 'b';
        case 0x2E: return 'c';
        case 0x20: return 'd';
        case 0x12: return 'e';
        case 0x21: return 'f';
        case 0x22: return 'g';
        case 0x23: return 'h';
        case 0x17: return 'i';
        case 0x24: return 'j';
        case 0x25: return 'k';
        case 0x26: return 'l';
        case 0x32: return 'm';
        case 0x31: return 'n';
        case 0x18: return 'o';
        case 0x19: return 'p';
        case 0x10: return 'q';
        case 0x13: return 'r';
        case 0x1F: return 's';
        case 0x14: return 't';
        case 0x16: return 'u';
        case 0x2F: return 'v';
        case 0x11: return 'w';
        case 0x2D: return 'x';
        case 0x15: return 'y';
        case 0x2C: return 'z';
        case 0x39: return ' ';
        case 0x1C: return '\n'; // Enter
        case 0x01: return 0x1B; // Escape (ESC)
        default: return 0;
    }
}

// Enkel forsinkelse-funksjon
void sleep(int ticks) {
    for (int i = 0; i < ticks * 1000000; i++) {
        __asm__ volatile ("nop");
    }
}

// Tilfeldig generator
static unsigned int seed = 123456789;

unsigned int rand() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed;
}

// Enkel animasjons-effekt
void special_effect() {
    // Animere i toppen av skjermen
    for (int i = 0; i < VGA_WIDTH; i++) {
        uint8_t color = vga_entry_color((i % 15) + 1, VGA_COLOR_BLACK);
        ((uint16_t*)video_memory)[i] = vga_entry('=', color);
        ((uint16_t*)video_memory)[VGA_WIDTH * (VGA_HEIGHT-1) + i] = vga_entry('=', color);
    }
    
    // Kort pause mellom hver oppdatering
    sleep(1);
}

// Hovedfunksjonen - entry point fra bootloader
void main() {
    // Initialisering
    clear_screen();
    
    // Velkommen-meldinger
    uint8_t title_color = vga_entry_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
    uint8_t text_color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    uint8_t highlight_color = vga_entry_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK);
    
    print_at("**** Laban Kernel ****", 28, 2, title_color);
    print_at("Operativsystemet er na lastet og kjoerer!", 17, 5, text_color);
    print_at("Dette er et minimalt OS bygget fra bunnen av", 17, 7, text_color);
    print_at("Bootloaderen har lastet kjernen og kjorer i 32-bit protected mode", 10, 9, text_color);
    
    // Demonstrer tastehåndtering
    print_at("Trykk taster for a se dem her:", 25, 12, highlight_color);
    
    cursor_x = 0;
    cursor_y = 14;
    update_cursor();
    
    // Hovedløkke - sjekker etter tastetrykk
    while (1) {
        special_effect();
        
        char key = get_key();
        if (key != 0) {
            if (key == 0x1B) { // ESC
                print_at("Avslutter... (Ctrl+C for a stenge QEMU)", 20, 20, vga_entry_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK));
                return;
            }
            putchar(key, text_color);
        }
        
        // Kort pause
        sleep(0.01);
    }
}
