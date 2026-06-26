# Fantasys32 — A 32-bit Fantasy Computer

Fantasys32 is a custom 32-bit fantasy computer built as a university project. It consists of three main components: a custom assembler that translates assembly source files into binary programs, a virtual machine (VM) that executes those programs with a graphical display, and a set of games written in the custom assembly language.

---

## Project Structure

```
fantasys32-computer-vm/
├── assembler/          # Assembler source code and Makefile
│   ├── src/
│   └── Makefile
├── vm/                 # Virtual Machine source code and Makefile
│   ├── src/
│   └── Makefile
└── games/
    ├── src/            # Assembly source files (.asm)
    └── bin/            # Compiled binary files (.bin)
```

### Components

| Component | Description |
|-----------|-------------|
| **Assembler** | Translates `.asm` source files into `.bin` binaries loadable by the VM. Supports labels, constants (`.equ`), variables (`.var`), byte arrays (`.space`), strings (`.string`), and all ISA instruction types (R, I, J, U, S). |
| **Virtual Machine** | Executes `.bin` programs. Features a 16 MB memory space, 16 general-purpose 32-bit registers, an SDL2-based 320×240 graphical display, keyboard input, a built-in 8×8 bitmap font for text rendering, and a simple LCG random number generator. |
| **Snake** | Classic snake game. The snake grows each time it eats the apple, which relocates randomly. The game ends if the snake hits a wall, displaying a Game Over screen with the final score. |
| **Breakout** | Brick-breaker game with 5 rows of coloured bricks, a paddle, a ball, 3 lives, and a score system. Ball speed increases as more bricks are destroyed. Includes a win screen and a Game Over screen. |

---

## Dependencies

The following tools and libraries must be installed before building:

| Dependency | Minimum Version | Purpose |
|------------|-----------------|---------|
| `g++` | C++17 | Compiling the assembler and the VM |
| `make` | Any | Running the build scripts |
| `libSDL2-dev` | 2.0 | Graphics window and keyboard input for the VM |
| `argparse` (header-only) | — | CLI argument parsing for the VM (`/usr/include/argparse/argparse.hpp`) |

### Installing dependencies on Ubuntu/Debian

```bash
sudo apt update
sudo apt install build-essential libsdl2-dev
```

> `argparse` is a header-only library. If it is not already present at `/usr/include/argparse/argparse.hpp`, place the single header there manually or adjust the include path in `vm/src/main.cpp`.

---

## Compilation

### 1. Build the Assembler

```bash
make -C assembler
```

This produces the `assembler/assembler` executable.

### 2. Build the Virtual Machine

```bash
make -C vm
```

This produces the `vm/vm` executable.

---

## Usage

### Assembling a game

Convert an `.asm` source file into a `.bin` binary:

```bash
./assembler/assembler <input.asm> <output.bin>
```

**Examples:**

```bash
./assembler/assembler games/src/snake.asm    games/bin/snake.bin
./assembler/assembler games/src/breakout.asm games/bin/breakout.bin
```

### Running a game

```bash
./vm/vm <game.bin> <scale>
```

- `<game.bin>` — path to the compiled binary.
- `<scale>` — integer window scale factor. `1` = 320×240, `2` = 640×480, `3` = 960×720, etc.

**Examples:**

```bash
# Snake at native resolution
./vm/vm games/bin/snake.bin 1

# Breakout at 2x scale
./vm/vm games/bin/breakout.bin 2
```

### Optional VM flags

| Flag | Description |
|------|-------------|
| `-V` | Enable verbose/debug output (repeat for more detail: `-V -V`) |
| `--no-syscall` | Silently ignore `SYSCALL` instructions instead of executing them |

```bash
# Run Snake with debug logging
./vm/vm games/bin/snake.bin 1 -V
```

---

## ISA Overview

Fantasys32 uses a custom 32-bit RISC-like instruction set with five instruction formats:

| Type | Instructions | Description |
|------|-------------|-------------|
| **R** | `ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `AND`, `OR`, `XOR`, `SHL`, `SHR`, `ROL`, `ROR` | Register-to-register arithmetic and logic |
| **I** | `ADDI`, `MOVL`, `MOVH`, `LOAD`, `STORE`, `BEQ`, `BNE`, `BLT`, `BGT`, `BLE`, `BGE` | Immediate operations, memory access, and conditional branches |
| **J** | `JMP`, `CALL` | Unconditional jumps and subroutine calls |
| **U** | `PUSH`, `POP`, `INC`, `DEC`, `NOT`, `RET` | Stack and unary operations |
| **S** | `RECT`, `CLEAR`, `GKEY`, `SLEEP`, `PSTR`, `PINT`, `SRAND`, `RAND`, `HALT`, ... | System calls: graphics, input, timing, I/O |

The processor has 16 registers (`R0`–`R15`), where `R14` is the stack pointer (SP) and `R15` is the program counter (PC). `R0` is a general-purpose register (not hardwired to zero).

---

## Controls

### Snake

| Key | Action |
|-----|--------|
| Arrow keys | Change direction |
| Enter | Dismiss the Game Over screen |

### Breakout

| Key | Action |
|-----|--------|
| Left / Right arrow keys | Move paddle |
| Enter | Restart after Game Over or win screen |
