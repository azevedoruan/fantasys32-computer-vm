#include "vm.h"

VirtualMachine::VirtualMachine(const char* binFile, int verbosity, int width, int height, int scale_factor) {
    this->verbosity = verbosity;
    this->width = width * scale_factor;
    this->height = height * scale_factor;

    // Initialize FrameBuffer
    buffer = new uint32_t[this->width * this->height];
    screenClean(0xFFFFFFFF);  // Set screen primarily white

    // Initialize VM memories
    uint size = (uint)TAM_MEM;  // setting 16MB to our mem size. The casts is for avoid the compiler warning.
    mem = new uint8_t[size];
    memset(mem, 0, sizeof(uint8_t) * size);
    memset(regs, 0, sizeof(int32_t) * 16);
    regs[SP] = STACK_END;                         // SP = 0x00FFFFFF

    if (binFile != nullptr)
        loadCode(binFile);
}

void VirtualMachine::printDebug(uint32_t instr, uint32_t opcode, const char* instrName) {
    if (this->verbosity > 0) {
        std::cout << instrName;

        if (this->verbosity > 1)
            std::cout << " - instruction value: 0x" << std::hex << std::setw(8) << instr << ", opcode: " << std::hex << std::setw(8) << opcode;

        std::cout << std::endl;
    }
}

void VirtualMachine::loadCode(const char* binFile) {
    FILE* bin = fopen(binFile, "rb");             // read the file in binary mode.
    fseek(bin, 0, SEEK_END);                      // go to the end of file.
    int sizeBin = ftell(bin) - sizeof(uint32_t);  // Get the size of code less the first instruction. (instructions size is 4 bytes normally)
    rewind(bin);                                  // Go to begin of file.

    uint32_t beginCode;
    fread(&beginCode, sizeof(uint32_t), 1, bin);  // Read the initial position of the first instruction.
    beginCode = __builtin_bswap32(beginCode);     // Make the swap the bits sequences from Big-Endian to Little-Endian.

    fread(mem, 1, sizeBin, bin);  // Load the rest of code file in the vm memory.
    regs[PC] = beginCode;         // Load the initial position of the first instructions in the VM registers.
}

uint32_t VirtualMachine::readInstructionFromRegister(uint32_t reg) {
    uint32_t data = (mem[reg] << 24);
    data |= (mem[reg + 1] << 16);
    data |= (mem[reg + 2] << 8);
    data |= (mem[reg + 3]);

    return data;
}

void VirtualMachine::executeInstruction(bool* running) {
    // Something happened outside this scope and must finish the loop
    if (*running == false) {
        return;
    }

    *running = true;
    uint32_t instr = readInstructionFromRegister(regs[PC]);
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
        i_rs = (instr >> 22) & 0xF;
        i_rt = (instr >> 18) & 0xF;
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
        i_re = (instr >> 6) & 0xF;
    }

    // Next instruction
    regs[PC] += 4;

    switch (opcode) {
        // Type R ==========================================
        case ADD:
            regs[i_rd] = regs[i_rs] + regs[i_rt];
            printDebug(instr, opcode, "ADD");
            break;
        case SUB:
            regs[i_rd] = regs[i_rs] - regs[i_rt];
            printDebug(instr, opcode, "SUB");
            break;
        case MUL:
            regs[i_rd] = regs[i_rs] * regs[i_rt];
            printDebug(instr, opcode, "MUL");
            break;
        case DIV:
            regs[i_rd] = regs[i_rs] / regs[i_rt];
            printDebug(instr, opcode, "DIV");
            break;
        case MOD:
            regs[i_rd] = regs[i_rs] % regs[i_rt];
            printDebug(instr, opcode, "MOD");
            break;
        case AND:
            regs[i_rd] = regs[i_rs] & regs[i_rt];
            printDebug(instr, opcode, "AND");
            break;
        case OR:
            regs[i_rd] = regs[i_rs] | regs[i_rt];
            printDebug(instr, opcode, "OR");
            break;
        case XOR:
            regs[i_rd] = regs[i_rs] ^ regs[i_rt];
            printDebug(instr, opcode, "XOR");
            break;
        case SHL:
            regs[i_rd] = regs[i_rs] << (regs[i_rt] & 0x1F);
            printDebug(instr, opcode, "SHL");
            break;
        case SHR:
            regs[i_rd] = regs[i_rs] >> (regs[i_rt] & 0x1F);
            printDebug(instr, opcode, "SHR");
            break;
        case ROL:
            regs[i_rd] = (regs[i_rs] << (regs[i_rt] & 0x1F)) | (regs[i_rs] >> (32 - (regs[i_rt] & 0x1F)));
            printDebug(instr, opcode, "ROL");
            break;
        case ROR:
            regs[i_rd] = (regs[i_rs] >> (regs[i_rt] & 0x1F)) | (regs[i_rs] << (32 - (regs[i_rt] & 0x1F)));
            printDebug(instr, opcode, "ROR");
            break;
        // Type I ==========================================
        case ADDI:
            regs[i_rt] = regs[i_rs] + i_imm18;
            printDebug(instr, opcode, "ADDI");
            break;
        case MOVL:
            regs[i_rt] = i_imm18 & 0xFFFF;
            printDebug(instr, opcode, "MOVL");
            break;
        case MOVH:
            regs[i_rt] = regs[i_rt] | (i_imm18 << 16);
            printDebug(instr, opcode, "MOVH");
            break;
        case LOAD: {
            uint32_t addr = regs[i_rs] + (i_imm18 * 4);
            if (addr & 3 || addr > STACK_END - 3) {
                std::cerr << "LOAD: invalid address 0x" << std::hex << addr << std::dec << std::endl;
                *running = false;
                break;
            }
            regs[i_rt] = ((uint32_t)mem[addr] << 24);
            regs[i_rt] |= ((uint32_t)mem[addr + 1] << 16);
            regs[i_rt] |= ((uint32_t)mem[addr + 2] << 8);
            regs[i_rt] |= mem[addr + 3];
            printDebug(instr, opcode, "LOAD");
            break;
        }
        case STORE: {
            uint32_t addr = regs[i_rs] + (i_imm18 * 4);
            if (addr & 3 || addr > STACK_END - 3) {
                std::cerr << "STORE: invalid address 0x" << std::hex << addr << std::dec << std::endl;
                *running = false;
                break;
            }
            uint32_t val = regs[i_rt];
            mem[addr] = (val >> 24) & 0xFF;
            mem[addr + 1] = (val >> 16) & 0xFF;
            mem[addr + 2] = (val >> 8) & 0xFF;
            mem[addr + 3] = val & 0xFF;
            printDebug(instr, opcode, "STORE");
            break;
        }
        case BEQ:
            if (regs[i_rs] == regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BEQ");
            break;
        case BNE:
            if (regs[i_rs] != regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BNE");
            break;
        case BLT:
            if (regs[i_rs] < regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BLT");
            break;
        case BGT:
            if (regs[i_rs] > regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BGT");
            break;
        case BLE:
            if (regs[i_rs] <= regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BLE");
            break;
        case BGE:
            if (regs[i_rs] >= regs[i_rt]) {
                regs[PC] = regs[PC] + ((int16_t)(i_imm18 & 0xFFFF) * 4);
            }
            printDebug(instr, opcode, "BGE");
            break;
        // Type J ==========================================
        case JMP: {
            uint32_t target = addr26 * 4;
            if (target & 3 || target > STACK_END) {
                std::cerr << "JMP: invalid target 0x" << std::hex << target << std::dec << std::endl;
                *running = false;
                break;
            }
            regs[PC] = target;
            printDebug(instr, opcode, "JMP");
            break;
        }
        case CALL: {
            uint32_t target = addr26 * 4;
            if (target & 3 || target > STACK_END) {
                std::cerr << "CALL: invalid target 0x" << std::hex << target << std::dec << std::endl;
                *running = false;
                break;
            }
            uint32_t addr = regs[SP] - 4;
            if (addr < STACK_START) {
                std::cerr << "CALL: stack overflow" << std::endl;
                *running = false;
                break;
            }
            regs[SP] = addr;
            uint32_t ret_addr = regs[PC];
            mem[addr]     = (ret_addr >> 24) & 0xFF;
            mem[addr + 1] = (ret_addr >> 16) & 0xFF;
            mem[addr + 2] = (ret_addr >> 8) & 0xFF;
            mem[addr + 3] = ret_addr & 0xFF;
            regs[PC] = target;
            printDebug(instr, opcode, "CALL");
            break;
        }
        // Type U ==========================================
        case PUSH: {
            uint32_t addr = regs[SP] - 4;
            if (addr < STACK_START) {
                std::cerr << "PUSH: stack overflow" << std::endl;
                *running = false;
                break;
            }
            regs[SP] = addr;
            uint32_t val = regs[i_rd];
            mem[addr] = (val >> 24) & 0xFF;
            mem[addr + 1] = (val >> 16) & 0xFF;
            mem[addr + 2] = (val >> 8) & 0xFF;
            mem[addr + 3] = val & 0xFF;
            printDebug(instr, opcode, "PUSH");
            break;
        }
        case POP: {
            uint32_t addr = regs[SP];
            if (addr > STACK_END - 3 || addr < STACK_START) {
                std::cerr << "POP: stack underflow" << std::endl;
                *running = false;
                break;
            }
            regs[i_rd] = ((uint32_t)mem[addr] << 24);
            regs[i_rd] |= ((uint32_t)mem[addr + 1] << 16);
            regs[i_rd] |= ((uint32_t)mem[addr + 2] << 8);
            regs[i_rd] |= mem[addr + 3];
            regs[SP] = addr + 4;
            printDebug(instr, opcode, "POP");
            break;
        }
        case INC:
            regs[i_rd] = regs[i_rd] + 1;
            printDebug(instr, opcode, "INC");
            break;
        case DEC:
            regs[i_rd] = regs[i_rd] - 1;
            printDebug(instr, opcode, "DEC");
            break;
        case NOT:
            regs[i_rd] = ~regs[i_rd];
            printDebug(instr, opcode, "NOT");
            break;
        case RET:
            regs[PC] = (mem[regs[SP]] << 24) | (mem[regs[SP] + 1] << 16) | (mem[regs[SP] + 2] << 8) | mem[regs[SP] + 3];
            regs[SP] = regs[SP] + 4;
            printDebug(instr, opcode, "RET");
            break;
        // Type S ==========================================
        case RECT:
            drawRect(regs[i_ra], regs[i_rb], regs[i_rc], regs[i_rd], regs[i_re]);
            printDebug(instr, opcode, "RECT");
            break;
        case DSPRITE:
            drawRect(regs[i_ra], regs[i_rb], regs[i_rc], regs[i_rd], regs[i_re]);
            printDebug(instr, opcode, "DSPRITE");
            break;
        case CLEAR:
            screenClean(regs[i_ra]);
            printDebug(instr, opcode, "CLEAR");
            break;
        case GKEY:
            if (input_state & (1 << (regs[i_rb] & 0xF))) {
                regs[i_ra] = 1;
            } else {
                regs[i_ra] = 0;
            }
            printDebug(instr, opcode, "GKEY");
            break;
        case PLAY:
            printDebug(instr, opcode, "PLAY todo...");
            break;
        case SLEEP:
            sleep_ms = regs[i_ra];
            printDebug(instr, opcode, "SLEEP");
            break;
        case PSTR:
            // Desenhar caracteres na mão no frameBuffer?
            printDebug(instr, opcode, "PSTR todo...");
            break;
        case PINT:
            // Desenhar caracteres na mão no frameBuffer?
            printDebug(instr, opcode, "PINT todo...");
            break;
        case SYSCALL:
            printDebug(instr, opcode, "SYSCALL todo...");
            break;
        case SRAND:
            srand(regs[i_ra]);
            printDebug(instr, opcode, "SRAND");
            break;
        case RAND: {
            int n = rand();
            if (n <= regs[i_rb]) {
                n = regs[i_rb];
            }
            if (n >= regs[i_rc]) {
                n = regs[i_rc];
            }
            regs[i_ra] = n;
            printDebug(instr, opcode, "RAND");
            break;
        }
        case FRAMENUM:
            regs[i_ra] = frame_count;
            printDebug(instr, opcode, "FRAMENUM");
            break;
        case HALT:
            *running = false;
            printDebug(instr, opcode, "HALT");
            break;
        default:
            std::cout << "Instrução não implementada: 0x" << std::hex << std::setw(8) << instr << ", opcode: 0x" << std::hex << std::setw(8) << opcode << std::endl;
            exit(1);
    }

    regs[0] = 0;
}

void VirtualMachine::drawRect(int x, int y, int w, int h, uint32_t color) {
    for (int line = y; line < y + h; line++) {
        for (int col = x; col < x + w; col++) {
            if (line >= 0 && line < height) {
                if (col >= 0 && col < width) {
                    setPixel(col, line, color);
                }
            }
        }
    }
}

void VirtualMachine::setPixel(int x, int y, uint32_t color) {
    buffer[x + (y * width)] = color;
}

void VirtualMachine::screenClean(uint32_t color) {
    for (int i = 0; i < width * height; i++) {
        buffer[i] = color;
    }
}

uint32_t* VirtualMachine::getBuffer() {
    return buffer;
}

VirtualMachine::~VirtualMachine() {
    frame_count = 0;
}