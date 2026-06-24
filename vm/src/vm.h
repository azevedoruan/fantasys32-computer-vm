#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <iomanip>
#include <iostream>

#define TAM_MEM (16 * 1024 * 1024)
#define MEM_MASK    0x00FFFFFF
#define STACK_START 0x00FFF000
#define STACK_END   0x00FFFFFF

// Registers Types
// Type R - move and memory
#define ADD 0x00
#define SUB 0x01
#define MUL 0x02
#define DIV 0x03
#define MOD 0x04
#define AND 0x05
#define OR 0x06
#define XOR 0x07
#define SHL 0x08
#define SHR 0x09
#define ROL 0x0A
#define ROR 0x0B

// Type I - Flow control
#define ADDI 0x0C
#define MOVL 0x0D
#define MOVH 0x0E
#define LOAD 0x0F
#define STORE 0x10
#define BEQ 0x11
#define BNE 0x12
#define BLT 0x13
#define BGT 0x14
#define BLE 0x15
#define BGE 0x16

// Type J - Flow control
#define JMP 0x17
#define CALL 0x18

// Type U - Units and Heap
#define PUSH 0x19
#define POP 0x1A
#define INC 0x1B
#define DEC 0x1C
#define NOT 0x1D
#define RET 0x1E

// Type S - System and I/O
#define RECT 0x1F
#define DSPRITE 0x20
#define CLEAR 0x21
#define GKEY 0x22
#define PLAY 0x23
#define SLEEP 0x24
#define PSTR 0x25
#define PINT 0x26
#define SYSCALL 0x27
#define SRAND 0x28
#define RAND 0x29
#define FRAMENUM 0x2A
#define HALT 0x2B

class VirtualMachine {
   private:
    // To debug log (0 = no print, 1 = instr, 2 = instr and details)
    int verbosity = 0;
    const int32_t SP = 14;
    const int32_t PC = 15;

    /*
     * Each register has 4 byte.
     * regs[0] -> R0, regs[1] -> R1, regs[2] -> R2, etc...
     * The last register (regs[15]) has the address of the next instruction.
     * It's our PC.
     */
    int32_t regs[16];

    /*
     * The memory that is load the binary program (our games).
     * A game must have max size of 16MB.
     */
    uint8_t* mem;
    uint32_t* buffer;
    int width;
    int height;

    uint32_t readInstructionFromRegister(uint32_t reg);
    void printDebug(uint32_t instr, uint32_t opcode, const char* instrName);

    // Limpa a tela preenchendo todos os pixels com a cor especificada
    void screenClean(uint32_t color);

    // Define uma cor para o pixel posicionado na coordenada.
    void setPixel(int x, int y, uint32_t color);

    // Função para pintar um retângulo no framebuffer com a cor especificada
    // A função impede que o retângulo seja desenhado fora dos limites do framebuffer,
    //    garantindo que não haja acesso inválido.
    void drawRect(int x, int y, int w, int h, uint32_t color);

   public:
    uint32_t input_state = 0;
    uint32_t rng_state = 1;
    int frame_count = 0;
    int sleep_ms = 0;
    VirtualMachine(const char* binFile, int verbosity = 0, int width = 0, int height = 0, int scale_factor = 1);
    ~VirtualMachine();
    void loadCode(const char* binFile);
    void executeInstruction(bool* running);
    uint32_t* getBuffer();
};