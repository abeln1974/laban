/**
 * MittOS Kernel
 * En enkel kjerne som skriver ut tekst på skjermen og håndterer tastatur
 */

// Adresse for videominnet (VGA tekstmodus)
unsigned char* video_memory = (unsigned char*) 0xB8000;

// Definerer størrelsen på skjermen
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// Posisjon for markør
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

// Lager et 8-bit fargeattributt fra forgrunn og bakgrunn
static inline unsigned char vga_entry_color(enum vga_color fg, enum vga_color bg) {
    return fg | bg << 4;
}

// Lager en 16-bit VGA tekstmodus post
static inline unsigned short vga_entry(unsigned char c, unsigned char color) {
    return (unsigned short) c | (unsigned short) color << 8;
}

// Finner lengden på en null-terminert streng
size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len])
        len++;
    return len;
}

// Tømmer skjermen
void clear_screen() {
    unsigned char color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    unsigned short empty = vga_entry(' ', color);
    
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        ((unsigned short*)video_memory)[i] = empty;
    }
    
    cursor_x = 0;
    cursor_y = 0;
}

// Oppdaterer hardware-markøren
void update_cursor() {
    unsigned short position = cursor_y * VGA_WIDTH + cursor_x;
    
    // Disse porter er standard VGA-porter for markøren
    // Port 0x3D4 velger registeret
    // Port 0x3D5 setter verdien
    
    // Setter nedre 8 bit av markørposisjon
    __asm__ volatile ("outb %0, %1" : : "a"(14), "Nd"(0x3D4));
    __asm__ volatile ("outb %0, %1" : : "a"((position >> 8) & 0xFF), "Nd"(0x3D5));
    
    // Setter øvre 8 bit av markørposisjon
    __asm__ volatile ("outb %0, %1" : : "a"(15), "Nd"(0x3D4));
    __asm__ volatile ("outb %0, %1" : : "a"(position & 0xFF), "Nd"(0x3D5));
}

// Scroller skjermen opp en linje
void scroll() {
    unsigned char color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    unsigned short empty = vga_entry(' ', color);
    
    // Flytt innholdet en linje opp
    for (int i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++) {
        ((unsigned short*)video_memory)[i] = ((unsigned short*)video_memory)[i + VGA_WIDTH];
    }
    
    // Tøm nederste linje
    for (int i = (VGA_HEIGHT - 1) * VGA_WIDTH; i < VGA_HEIGHT * VGA_WIDTH; i++) {
        ((unsigned short*)video_memory)[i] = empty;
    }
    
    cursor_y--;
}

// Skriver ut et tegn på gjeldende markørposisjon
void putchar(char c, unsigned char color) {
    // Håndterer spesialtegn
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
    } else if (c == '\r') {
        cursor_x = 0;
    } else if (c == '\b') {
        if (cursor_x > 0) {
            cursor_x--;
            ((unsigned short*)video_memory)[cursor_y * VGA_WIDTH + cursor_x] = vga_entry(' ', color);
        }
    } else if (c == '\t') {
        // Tab er 4 mellomrom
        cursor_x = (cursor_x + 4) & ~(4 - 1);
    } else {
        ((unsigned short*)video_memory)[cursor_y * VGA_WIDTH + cursor_x] = vga_entry(c, color);
        cursor_x++;
    }
    
    // Håndterer linjeskift
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
void print(const char* str, unsigned char color) {
    for (size_t i = 0; i < strlen(str); i++) {
        putchar(str[i], color);
    }
}

// Skriver en streng på en bestemt posisjon på skjermen
void print_at(const char* str, int col, int row, unsigned char color) {
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

// Les tegn fra tastaturet (pollingbasert, ikke interrupt-drevet)
char get_key() {
    char c = 0;
    
    // 0x64 er statusport for tastaturet
    // 0x60 er dataport for tastaturet
    
    // Sjekk om det er data tilgjengelig
    if (__builtin_inb(0x64) & 1) {
        c = __builtin_inb(0x60);
    }
    
    // Enkelt tastaturkart for noen vanlige tegn
    // Dette er veldig forenklet, et ekte OS ville ha et full tastaturkart
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

// Tilfeldig generator basert på enkel lineær kongruent metode
static unsigned int seed = 123456789;

unsigned int rand() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed;
}

// Animerer en regnbue over skjermen
void rainbow_effect() {
    for (int i = 0; i < VGA_WIDTH; i++) {
        for (int j = 0; j < VGA_HEIGHT; j++) {
            // Lage en regnbue-effekt basert på posisjon
            int color_value = (i + j) % 15 + 1; // Unngå svart (0)
            unsigned char color = vga_entry_color(color_value, VGA_COLOR_BLACK);
            
            // Plasser et tilfeldig tegn
            char c = (rand() % 26) + 'A';
            ((unsigned short*)video_memory)[j * VGA_WIDTH + i] = vga_entry(c, color);
        }
    }
    sleep(1); // Kort forsinkelse
}

// Hovedfunksjonen for kjernen
void main() {
    // Tøm skjermen
    clear_screen();
    
    // Skriv ut en velkomstmelding med ulike farger
    print_at("Velkommen til MittOS - Et operativsystem fra bunnen!", 10, 5, 
             vga_entry_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK));
    
    print_at("Utviklet av Lars", 10, 7, 
             vga_entry_color(VGA_COLOR_LIGHT_BLUE, VGA_COLOR_BLACK));
    
    print_at("Dette er mitt eget operativsystem!", 10, 9, 
             vga_entry_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK));
    
    print_at("ESC for aa avslutte, andre taster for regnbue!", 10, 12, 
             vga_entry_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK));
    
    print_at("------------------", 10, 14, 
             vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK));
    
    cursor_x = 0;
    cursor_y = 16;
    update_cursor();
    
    // Enkelt tastaturinteraksjon
    while(1) {
        char key = get_key();
        
        if (key == 0x1B) { // ESC
            clear_screen();
            print_at("Avslutter MittOS... Trykk Ctrl+C i terminalen", 10, 10, 
                    vga_entry_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK));
            // I en virkelig implementasjon ville vi ha stoppet systemet her
            // men siden vi kjører i en emulator, så vil brukeren måtte
            // stoppe emulatoren manuelt
            return;
        } 
        else if (key != 0) {
            putchar(key, vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK));
            rainbow_effect(); // Kjør en liten regnbueanimasjon
        }
        
        // Kort forsinkelse for å unngå 100% CPU-bruk
        sleep(0.01);
    }
}
