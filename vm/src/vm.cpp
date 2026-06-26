#include "vm.h"
#include <cstdio>
#include <cctype>

// ---- Key mappings (matches game .equ definitions) --------------------------
// KEY_LEFT=0, KEY_RIGHT=1, KEY_UP=2, KEY_DOWN=3, SPACE=4, ENTER=5
static const SDL_Scancode KEY_MAP[] = {
    SDL_SCANCODE_LEFT,
    SDL_SCANCODE_RIGHT,
    SDL_SCANCODE_UP,
    SDL_SCANCODE_DOWN,
    SDL_SCANCODE_SPACE,
    SDL_SCANCODE_RETURN,
};
static const int KEY_MAP_SIZE = (int)(sizeof(KEY_MAP) / sizeof(KEY_MAP[0]));

// ---- Built-in 8x8 bitmap font (ASCII 32-126) --------------------------------
// Each character is 8 rows of 8 bits. Bit 0 (LSB) = leftmost pixel.
// Derived from the classic IBM CP437 / ZX Spectrum style 8x8 font.
static const uint8_t FONT8x8[95][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, // ' '
    {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00}, // '!'
    {0x36,0x36,0x00,0x00,0x00,0x00,0x00,0x00}, // '"'
    {0x36,0x36,0x7F,0x36,0x7F,0x36,0x36,0x00}, // '#'
    {0x0C,0x3E,0x03,0x1E,0x30,0x1F,0x0C,0x00}, // '$'
    {0x00,0x63,0x33,0x18,0x0C,0x66,0x63,0x00}, // '%'
    {0x1C,0x36,0x1C,0x6E,0x3B,0x33,0x6E,0x00}, // '&'
    {0x06,0x06,0x03,0x00,0x00,0x00,0x00,0x00}, // '\''
    {0x18,0x0C,0x06,0x06,0x06,0x0C,0x18,0x00}, // '('
    {0x06,0x0C,0x18,0x18,0x18,0x0C,0x06,0x00}, // ')'
    {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00}, // '*'
    {0x00,0x0C,0x0C,0x3F,0x0C,0x0C,0x00,0x00}, // '+'
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x06}, // ','
    {0x00,0x00,0x00,0x3F,0x00,0x00,0x00,0x00}, // '-'
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x00}, // '.'
    {0x60,0x30,0x18,0x0C,0x06,0x03,0x01,0x00}, // '/'
    {0x3E,0x63,0x73,0x7B,0x6F,0x67,0x3E,0x00}, // '0'
    {0x0C,0x0E,0x0C,0x0C,0x0C,0x0C,0x3F,0x00}, // '1'
    {0x1E,0x33,0x30,0x1C,0x06,0x33,0x3F,0x00}, // '2'
    {0x1E,0x33,0x30,0x1C,0x30,0x33,0x1E,0x00}, // '3'
    {0x38,0x3C,0x36,0x33,0x7F,0x30,0x78,0x00}, // '4'
    {0x3F,0x03,0x1F,0x30,0x30,0x33,0x1E,0x00}, // '5'
    {0x1C,0x06,0x03,0x1F,0x33,0x33,0x1E,0x00}, // '6'
    {0x3F,0x33,0x30,0x18,0x0C,0x0C,0x0C,0x00}, // '7'
    {0x1E,0x33,0x33,0x1E,0x33,0x33,0x1E,0x00}, // '8'
    {0x1E,0x33,0x33,0x3E,0x30,0x18,0x0E,0x00}, // '9'
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x00}, // ':'
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x06}, // ';'
    {0x18,0x0C,0x06,0x03,0x06,0x0C,0x18,0x00}, // '<'
    {0x00,0x00,0x3F,0x00,0x00,0x3F,0x00,0x00}, // '='
    {0x06,0x0C,0x18,0x30,0x18,0x0C,0x06,0x00}, // '>'
    {0x1E,0x33,0x30,0x18,0x0C,0x00,0x0C,0x00}, // '?'
    {0x3E,0x63,0x7B,0x7B,0x7B,0x03,0x1E,0x00}, // '@'
    {0x0C,0x1E,0x33,0x33,0x3F,0x33,0x33,0x00}, // 'A'
    {0x3F,0x66,0x66,0x3E,0x66,0x66,0x3F,0x00}, // 'B'
    {0x3C,0x66,0x03,0x03,0x03,0x66,0x3C,0x00}, // 'C'
    {0x1F,0x36,0x66,0x66,0x66,0x36,0x1F,0x00}, // 'D'
    {0x7F,0x46,0x16,0x1E,0x16,0x46,0x7F,0x00}, // 'E'
    {0x7F,0x46,0x16,0x1E,0x16,0x06,0x0F,0x00}, // 'F'
    {0x3C,0x66,0x03,0x03,0x73,0x66,0x7C,0x00}, // 'G'
    {0x33,0x33,0x33,0x3F,0x33,0x33,0x33,0x00}, // 'H'
    {0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, // 'I'
    {0x78,0x30,0x30,0x30,0x33,0x33,0x1E,0x00}, // 'J'
    {0x67,0x66,0x36,0x1E,0x36,0x66,0x67,0x00}, // 'K'
    {0x0F,0x06,0x06,0x06,0x46,0x66,0x7F,0x00}, // 'L'
    {0x63,0x77,0x7F,0x7F,0x6B,0x63,0x63,0x00}, // 'M'
    {0x63,0x67,0x6F,0x7B,0x73,0x63,0x63,0x00}, // 'N'
    {0x1C,0x36,0x63,0x63,0x63,0x36,0x1C,0x00}, // 'O'
    {0x3F,0x66,0x66,0x3E,0x06,0x06,0x0F,0x00}, // 'P'
    {0x1E,0x33,0x33,0x33,0x3B,0x1E,0x38,0x00}, // 'Q'
    {0x3F,0x66,0x66,0x3E,0x36,0x66,0x67,0x00}, // 'R'
    {0x1E,0x33,0x07,0x0E,0x38,0x33,0x1E,0x00}, // 'S'
    {0x3F,0x2D,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, // 'T'
    {0x33,0x33,0x33,0x33,0x33,0x33,0x3F,0x00}, // 'U'
    {0x33,0x33,0x33,0x33,0x33,0x1E,0x0C,0x00}, // 'V'
    {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00}, // 'W'
    {0x63,0x63,0x36,0x1C,0x1C,0x36,0x63,0x00}, // 'X'
    {0x33,0x33,0x33,0x1E,0x0C,0x0C,0x1E,0x00}, // 'Y'
    {0x7F,0x63,0x31,0x18,0x4C,0x66,0x7F,0x00}, // 'Z'
    {0x1E,0x06,0x06,0x06,0x06,0x06,0x1E,0x00}, // '['
    {0x03,0x06,0x0C,0x18,0x30,0x60,0x40,0x00}, // '\\'
    {0x1E,0x18,0x18,0x18,0x18,0x18,0x1E,0x00}, // ']'
    {0x08,0x1C,0x36,0x63,0x00,0x00,0x00,0x00}, // '^'
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF}, // '_'
    {0x0C,0x0C,0x18,0x00,0x00,0x00,0x00,0x00}, // '`'
    {0x00,0x00,0x1E,0x30,0x3E,0x33,0x6E,0x00}, // 'a'
    {0x07,0x06,0x06,0x3E,0x66,0x66,0x3B,0x00}, // 'b'
    {0x00,0x00,0x1E,0x33,0x03,0x33,0x1E,0x00}, // 'c'
    {0x38,0x30,0x30,0x3e,0x33,0x33,0x6E,0x00}, // 'd'
    {0x00,0x00,0x1E,0x33,0x3f,0x03,0x1E,0x00}, // 'e'
    {0x1C,0x36,0x06,0x0f,0x06,0x06,0x0F,0x00}, // 'f'
    {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x1F}, // 'g'
    {0x07,0x06,0x36,0x6E,0x66,0x66,0x67,0x00}, // 'h'
    {0x0C,0x00,0x0E,0x0C,0x0C,0x0C,0x1E,0x00}, // 'i'
    {0x30,0x00,0x30,0x30,0x30,0x33,0x33,0x1E}, // 'j'
    {0x07,0x06,0x66,0x36,0x1E,0x36,0x67,0x00}, // 'k'
    {0x0E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, // 'l'
    {0x00,0x00,0x33,0x7F,0x7F,0x6B,0x63,0x00}, // 'm'
    {0x00,0x00,0x1F,0x33,0x33,0x33,0x33,0x00}, // 'n'
    {0x00,0x00,0x1E,0x33,0x33,0x33,0x1E,0x00}, // 'o'
    {0x00,0x00,0x3B,0x66,0x66,0x3E,0x06,0x0F}, // 'p'
    {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x78}, // 'q'
    {0x00,0x00,0x3B,0x6E,0x66,0x06,0x0F,0x00}, // 'r'
    {0x00,0x00,0x3E,0x03,0x1E,0x30,0x1F,0x00}, // 's'
    {0x08,0x0C,0x3E,0x0C,0x0C,0x2C,0x18,0x00}, // 't'
    {0x00,0x00,0x33,0x33,0x33,0x33,0x6E,0x00}, // 'u'
    {0x00,0x00,0x33,0x33,0x33,0x1E,0x0C,0x00}, // 'v'
    {0x00,0x00,0x63,0x6B,0x7F,0x7F,0x36,0x00}, // 'w'
    {0x00,0x00,0x63,0x36,0x1C,0x36,0x63,0x00}, // 'x'
    {0x00,0x00,0x33,0x33,0x33,0x3E,0x30,0x1F}, // 'y'
    {0x00,0x00,0x3F,0x19,0x0C,0x26,0x3F,0x00}, // 'z'
    {0x38,0x0C,0x0C,0x07,0x0C,0x0C,0x38,0x00}, // '{'
    {0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00}, // '|'
    {0x07,0x0C,0x0C,0x38,0x0C,0x0C,0x07,0x00}, // '}'
    {0x6E,0x3B,0x00,0x00,0x00,0x00,0x00,0x00}, // '~'
};

// ============================================================================

VirtualMachine::VirtualMachine(const char* binFile, int flag) {
    this->flag = flag;

    uint size = (uint)TAM_MEM;
    mem = new uint8_t[size];
    memset(mem, 0, sizeof(uint8_t) * size);
    memset(regs, 0, sizeof(int32_t) * 16);

    // Bug fix #7: SP must start at top of memory, not 0.
    // With SP=0, the first PUSH decrements to -4 (invalid address).
    regs[SP] = TAM_MEM;

    if (binFile != nullptr)
        loadCode(binFile);
}

VirtualMachine::~VirtualMachine() {
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window)   SDL_DestroyWindow(window);
    SDL_Quit();
    delete[] mem;
}

void VirtualMachine::initSDL(int scaleArg) {
    scale = scaleArg;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
        exit(1);
    }

    window = SDL_CreateWindow(
        "Fantasys32 VM",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        320 * scale, 240 * scale,
        SDL_WINDOW_SHOWN
    );
    if (!window) {
        std::cerr << "SDL_CreateWindow failed: " << SDL_GetError() << std::endl;
        exit(1);
    }

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    }
    if (!renderer) {
        std::cerr << "SDL_CreateRenderer failed: " << SDL_GetError() << std::endl;
        exit(1);
    }

    SDL_RenderSetScale(renderer, (float)scale, (float)scale);

    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
}

// ---- Memory word helpers ---------------------------------------------------

// Reads a 32-bit big-endian word from memory (same byte order as instructions).
uint32_t VirtualMachine::readInstructionFromRegister(uint32_t reg) {
    uint32_t data = ((uint32_t)mem[reg]     << 24);
    data         |= ((uint32_t)mem[reg + 1] << 16);
    data         |= ((uint32_t)mem[reg + 2] <<  8);
    data         |= ((uint32_t)mem[reg + 3]);
    return data;
}

// Writes a 32-bit value to memory in big-endian order.
void VirtualMachine::writeWord(uint32_t addr, uint32_t value) {
    mem[addr]     = (value >> 24) & 0xFF;
    mem[addr + 1] = (value >> 16) & 0xFF;
    mem[addr + 2] = (value >>  8) & 0xFF;
    mem[addr + 3] = (value)       & 0xFF;
}

// ---- Text rendering helper (built-in 8x8 bitmap font) ---------------------

void VirtualMachine::renderText(int x, int y, const char* text, uint32_t argb) {
    if (!renderer || !text) return;
    SDL_SetRenderDrawColor(renderer,
        (argb >> 16) & 0xFF,
        (argb >>  8) & 0xFF,
         argb        & 0xFF,
        255);
    int cx = x;
    for (int i = 0; text[i] != '\0'; i++) {
        unsigned char c = (unsigned char)text[i];
        if (c < 32 || c > 126) { cx += 8; continue; }
        const uint8_t* glyph = FONT8x8[c - 32];
        for (int row = 0; row < 8; row++) {
            uint8_t bits = glyph[row];
            for (int col = 0; col < 8; col++) {
                if (bits & (1 << col)) {
                    SDL_RenderDrawPoint(renderer, cx + col, y + row);
                }
            }
        }
        cx += 8;
    }
}

// ---- Debug logging ---------------------------------------------------------

void VirtualMachine::printFlags(uint32_t instr, uint32_t opcode, const char* instrName) {
    if (flag > 0) {
        std::cout << instrName;
        if (flag > 1)
            std::cout << " - instruction value: 0x" << std::hex << std::setw(8) << instr
                      << ", opcode: " << std::hex << std::setw(8) << opcode;
        std::cout << std::endl;
    }
}

// ---- Code loader -----------------------------------------------------------

void VirtualMachine::loadCode(const char* binFile) {
    FILE* bin = fopen(binFile, "rb");
    fseek(bin, 0, SEEK_END);
    int sizeBin = ftell(bin) - sizeof(uint32_t);
    rewind(bin);

    uint32_t beginCode;
    fread(&beginCode, sizeof(uint32_t), 1, bin);
    beginCode = __builtin_bswap32(beginCode);

    fread(mem, 1, sizeBin, bin);
    regs[PC] = beginCode;
    fclose(bin);
}

// ---- Main execution loop ---------------------------------------------------

void VirtualMachine::executeInstruction() {
    uint32_t instr  = readInstructionFromRegister(regs[PC]);
    uint32_t opcode = instr >> 26;

    uint32_t i_rs;
    uint32_t i_rt;
    uint32_t i_imm18;

    uint32_t i_ra;
    uint32_t i_rb;
    uint32_t i_rc;
    uint32_t i_rd;
    uint32_t i_re;

    uint32_t addr26;

    if (opcode >= ADD && opcode <= ROR) {  // Type R
        i_rs = (instr >> 22) & 0xF;
        i_rt = (instr >> 18) & 0xF;
        i_rd = (instr >> 14) & 0xF;
    }
    if (opcode >= ADDI && opcode <= BGE) {  // Type I
        i_rs    = (instr >> 22) & 0xF;
        i_rt    = (instr >> 18) & 0xF;
        i_imm18 = instr & 0x3FFFF;
    }
    if (opcode == JMP || opcode == CALL) {  // Type J
        addr26 = instr & 0x3FFFFFF;
    }
    if (opcode >= PUSH && opcode <= RET) {  // Type U
        i_rd = (instr >> 22) & 0xF;
    }
    if (opcode >= RECT && opcode <= HALT) {  // Type S
        i_ra = (instr >> 22) & 0xF;
        i_rb = (instr >> 18) & 0xF;
        i_rc = (instr >> 14) & 0xF;
        i_rd = (instr >> 10) & 0xF;
        i_re = (instr >>  6) & 0xF;
    }

    // Advance PC before execution (branches/jumps override this).
    regs[PC] += 4;

    switch (opcode) {
        // ---- Type R --------------------------------------------------------
        // Type R: assembler encodes dest→rs (bits 25-22), src1→rt (bits 21-18), src2→rd (bits 13-10)
        case ADD:
            regs[i_rs] = regs[i_rt] + regs[i_rd];
            printFlags(instr, opcode, "ADD");
            break;
        case SUB:
            regs[i_rs] = regs[i_rt] - regs[i_rd];
            printFlags(instr, opcode, "SUB");
            break;
        case MUL:
            regs[i_rs] = regs[i_rt] * regs[i_rd];
            printFlags(instr, opcode, "MUL");
            break;
        case DIV:
            regs[i_rs] = regs[i_rt] / regs[i_rd];
            printFlags(instr, opcode, "DIV");
            break;
        case MOD:
            regs[i_rs] = regs[i_rt] % regs[i_rd];
            printFlags(instr, opcode, "MOD");
            break;
        case AND:
            regs[i_rs] = regs[i_rt] & regs[i_rd];
            printFlags(instr, opcode, "AND");
            break;
        case OR:
            regs[i_rs] = regs[i_rt] | regs[i_rd];
            printFlags(instr, opcode, "OR");
            break;
        case XOR:
            regs[i_rs] = regs[i_rt] ^ regs[i_rd];
            printFlags(instr, opcode, "XOR");
            break;
        case SHL:
            regs[i_rs] = regs[i_rt] << (regs[i_rd] & 0x1F);
            printFlags(instr, opcode, "SHL");
            break;
        case SHR:
            regs[i_rs] = regs[i_rt] >> (regs[i_rd] & 0x1F);
            printFlags(instr, opcode, "SHR");
            break;
        case ROL:
            regs[i_rs] = (regs[i_rt] << (regs[i_rd] & 0x1F)) | (regs[i_rt] >> (32 - (regs[i_rd] & 0x1F)));
            printFlags(instr, opcode, "ROL");
            break;
        case ROR:
            regs[i_rs] = (regs[i_rt] >> (regs[i_rd] & 0x1F)) | (regs[i_rt] << (32 - (regs[i_rd] & 0x1F)));
            printFlags(instr, opcode, "ROR");
            break;

        // ---- Type I --------------------------------------------------------
        case ADDI:
            regs[i_rt] = regs[i_rs] + i_imm18;
            printFlags(instr, opcode, "ADDI");
            break;
        case MOVL:
            regs[i_rt] = i_imm18 & 0xFFFF;
            printFlags(instr, opcode, "MOVL");
            break;
        case MOVH:
            regs[i_rt] = regs[i_rt] | (i_imm18 << 16);
            printFlags(instr, opcode, "MOVH");
            break;

        // LOAD: dest→rs (bits 25-22), base→rt (bits 21-18)
        case LOAD: {
            uint32_t addr = (uint32_t)(regs[i_rt] + (int32_t)(i_imm18 * 4));
            regs[i_rs] = (int32_t)readInstructionFromRegister(addr);
            printFlags(instr, opcode, "LOAD");
            break;
        }

        // STORE: value→rs (bits 25-22), base→rt (bits 21-18)
        case STORE: {
            uint32_t addr = (uint32_t)(regs[i_rt] + (int32_t)(i_imm18 * 4));
            writeWord(addr, (uint32_t)regs[i_rs]);
            printFlags(instr, opcode, "STORE");
            break;
        }

        case BEQ:
            if (regs[i_rs] == regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BEQ");
            break;
        case BNE:
            if (regs[i_rs] != regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BNE");
            break;
        case BLT:
            if (regs[i_rs] < regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BLT");
            break;
        case BGT:
            if (regs[i_rs] > regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BGT");
            break;
        case BLE:
            if (regs[i_rs] <= regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BLE");
            break;
        case BGE:
            if (regs[i_rs] >= regs[i_rt])
                regs[PC] = regs[PC] + (int32_t)((int16_t)(i_imm18 & 0xFFFF)) * 4;
            printFlags(instr, opcode, "BGE");
            break;

        // ---- Type J --------------------------------------------------------
        case JMP:
            regs[PC] = addr26 * 4;
            printFlags(instr, opcode, "JMP");
            break;

        // Bug fix #6: CALL must push the return address and jump to target.
        case CALL:
            regs[SP] -= 4;
            writeWord((uint32_t)regs[SP], (uint32_t)regs[PC]);  // push return address
            regs[PC] = addr26 * 4;                               // jump to subroutine
            printFlags(instr, opcode, "CALL");
            break;

        // ---- Type U --------------------------------------------------------
        // Bug fix #3: PUSH must write a full 32-bit word.
        case PUSH:
            regs[SP] -= 4;
            writeWord((uint32_t)regs[SP], (uint32_t)regs[i_rd]);
            printFlags(instr, opcode, "PUSH");
            break;

        // Bug fix #4: POP must read a full 32-bit word.
        case POP:
            regs[i_rd] = (int32_t)readInstructionFromRegister((uint32_t)regs[SP]);
            regs[SP] += 4;
            printFlags(instr, opcode, "POP");
            break;

        case INC:
            regs[i_rd] = regs[i_rd] + 1;
            printFlags(instr, opcode, "INC");
            break;
        case DEC:
            regs[i_rd] = regs[i_rd] - 1;
            printFlags(instr, opcode, "DEC");
            break;
        case NOT:
            regs[i_rd] = ~regs[i_rd];
            printFlags(instr, opcode, "NOT");
            break;

        // Bug fix #5: RET must read a full 32-bit word from the stack.
        case RET:
            regs[PC] = (int32_t)readInstructionFromRegister((uint32_t)regs[SP]);
            regs[SP] += 4;
            printFlags(instr, opcode, "RET");
            break;

        // ---- Type S: Graphics / I/O / System --------------------------------

        // RECT ra, rb, rc, rd, re  ->  draw filled rect at (ra,rb) size (rc,rd) color re
        case RECT: {
            if (!renderer) break;
            int x = regs[i_ra];
            int y = regs[i_rb];
            int w = regs[i_rc];
            int h = regs[i_rd];
            uint32_t color = (uint32_t)regs[i_re];
            SDL_SetRenderDrawColor(renderer,
                (color >> 16) & 0xFF,
                (color >>  8) & 0xFF,
                 color        & 0xFF,
                255);
            SDL_Rect rect = {x, y, w, h};
            SDL_RenderFillRect(renderer, &rect);
            printFlags(instr, opcode, "RECT");
            break;
        }

        case DSPRITE:
            printFlags(instr, opcode, "DSPRITE");
            break;

        // CLEAR ra  ->  fill entire screen with color ra, then process SDL events.
        case CLEAR: {
            if (!renderer) break;
            uint32_t color = (uint32_t)regs[i_ra];
            SDL_SetRenderDrawColor(renderer,
                (color >> 16) & 0xFF,
                (color >>  8) & 0xFF,
                 color        & 0xFF,
                255);
            SDL_RenderClear(renderer);
            // Pump SDL events so the window stays responsive.
            SDL_Event e;
            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    SDL_Quit();
                    exit(0);
                }
            }
            printFlags(instr, opcode, "CLEAR");
            break;
        }

        // GKEY ra, rb  ->  ra = 1 if key rb is pressed, else 0.
        case GKEY: {
            SDL_PumpEvents();
            const uint8_t* keys = SDL_GetKeyboardState(nullptr);
            int key_code = regs[i_rb];
            int pressed = 0;
            if (key_code >= 0 && key_code < KEY_MAP_SIZE)
                pressed = keys[KEY_MAP[key_code]] ? 1 : 0;
            regs[i_ra] = pressed;
            printFlags(instr, opcode, "GKEY");
            break;
        }

        // PLAY ra, rb, rc  ->  play tone (freq=ra Hz, dur=rb ms, wave=rc). Stubbed.
        case PLAY:
            printFlags(instr, opcode, "PLAY");
            break;

        // SLEEP ra  ->  present the current frame, then wait ra milliseconds.
        case SLEEP: {
            if (renderer) SDL_RenderPresent(renderer);
            uint32_t ms = (uint32_t)regs[i_ra];
            SDL_Delay(ms);
            printFlags(instr, opcode, "SLEEP");
            break;
        }

        // PSTR ra, rb, rc, rd  ->  print null-terminated string at mem[rc] at (ra,rb) color rd.
        case PSTR: {
            int x = regs[i_ra];
            int y = regs[i_rb];
            uint32_t str_addr = (uint32_t)regs[i_rc];
            uint32_t color    = (uint32_t)regs[i_rd];
            // Read null-terminated string from VM memory.
            char text[256] = {};
            int  len = 0;
            while (len < 255 && mem[str_addr + len] != 0) {
                text[len] = (char)mem[str_addr + len];
                len++;
            }
            text[len] = '\0';
            renderText(x, y, text, color);
            printFlags(instr, opcode, "PSTR");
            break;
        }

        // PINT ra, rb, rc, rd  ->  print integer rc at (ra,rb) color rd.
        case PINT: {
            int x     = regs[i_ra];
            int y     = regs[i_rb];
            int value = regs[i_rc];
            uint32_t color = (uint32_t)regs[i_rd];
            char text[32];
            snprintf(text, sizeof(text), "%d", value);
            renderText(x, y, text, color);
            printFlags(instr, opcode, "PINT");
            break;
        }

        case SYSCALL:
            printFlags(instr, opcode, "SYSCALL");
            break;

        // SRAND ra  ->  seed the RNG with ra.
        case SRAND:
            srand((unsigned int)regs[i_ra]);
            printFlags(instr, opcode, "SRAND");
            break;

        // RAND ra  ->  ra = random integer.
        case RAND:
            regs[i_ra] = (int32_t)rand();
            printFlags(instr, opcode, "RAND");
            break;

        // FRAMENUM ra  ->  ra = current frame counter.
        case FRAMENUM:
            regs[i_ra] = (int32_t)frame_count++;
            printFlags(instr, opcode, "FRAMENUM");
            break;

        // HALT  ->  stop execution cleanly.
        case HALT:
            printFlags(instr, opcode, "HALT");
            if (renderer) SDL_RenderPresent(renderer);
            SDL_Quit();
            exit(0);
            break;

        default:
            std::cout << "Instrução não implementada: 0x" << std::hex << std::setw(8)
                      << instr << ", opcode: 0x" << std::hex << std::setw(8) << opcode << std::endl;
            exit(1);
    }
}
