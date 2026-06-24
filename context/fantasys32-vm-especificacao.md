# Workspace-en

## 1.1 - Programming and Memory Model

- **Architecture:**32-bit RISC, inspired by MIPS.
- **Endianness:Big-Endian**. In the binary file and in memory, the most significant byte of the word occupies the lowest address.
- **Registers:**16 32-bit registers (R0 through R15).
    - R0: Constant 0.
    - R14 (SP): Stack Pointer. Initialized by the VM to 0x00FFFFFF, it decrements down to 0x0FFEFFF (4 KB).
    - R15 (PC): Program Counter.
- **Memory:**16 MB addressable. Memory is organized into 32-bit words, and the address of each word is a multiple of 4. Memory space is divided into:
    - 0x00000000 to 0x00FB3FFF: General memory for code and data (~15 MB).
    - 0x00FB4000 to 0x00FFEFFF: Video memory (300 KB).
    - 0x00FFF000 to 0x00FFFFFF: Stack (4 KB).
- **Video:**320x240-pixel framebuffer, with each pixel represented by an RGB integer (0xAARRGGBB). The*framebuffer*is mapped to a specific memory segment, from 0x00FB4000 to 0x00FFEFFF (307,200 bytes). Video memory is organized as a*row-major* pixel array, where the pixel at position (x, y) is accessed via`Mem[0x00FB4000 + (y * 320 + x) * 4]`.
- **Alignment:**All memory accesses (instructions and data) must be multiples of 4. Attempts to access unaligned memory must result in a runtime error (*Alignment Error*), and the VM must abort execution.
- **Clock:**60 FPS; 10 instructions are executed per frame.
    
    4
    

## 1.2 - Instruction Formats (32-bit)

See the @instruction_format.csv file

**Note on Addressing:**Address immediate values (in`LOAD`,`STORE`,`JMP`,`CALL`, and branch instructions) represent**word offsets**. The VM must multiply the value by 4 to obtain the address in bytes.

## 1.3 - Instructions

**IMPORTANT:**In some instructions, not all register fields are used. In these cases, the unused fields must be filled with zeros by the assembler and ignored by the VM during execution.

### 1.3.1 - Arithmetic and Logic (R and I Types)

See the @tipo_R_I.csv file

### Details

The`0x1F`shift mask ensures that the shift value is always between 0 and 31, preventing undefined behavior.

*Overflow*and*underflow*in arithmetic operations must be treated as defined behavior; that is, the VM must simply store the result truncated to 32 bits without triggering errors.

All arithmetic operations are performed using signed arithmetic; that is, operands and results are interpreted as signed integers. Values are encoded in two’s complement, allowing arithmetic operations to correctly handle negative numbers.

Logical operations (`AND`,`OR`,`XOR`) and shift operations (`SHL`,`SHR`,`ROL`,`ROR`) must operate bit by bit, regardless of the sign of the operands.

### 1.3.2 - Shifts and Memory (Type I)

See file @type_I.csv

### Details

`imm16`is a 16-bit immediate value, with the least significant bits of the immediate field.

The`MOVL`instruction is used to load a 16-bit immediate value into a register, padding the upper bits with zeros. The`MOVH`instruction, on the other hand, is used to load a 16-bit immediate value into the high part of the register, preserving the lower bits. To construct a complete 32-bit value, the programmer can use a combination of`MOVL`and`MOVH`. This is more convenient than a sequence of move, shift, and OR instructions. Thus, the sequence can simply be:

```
; R1 = 0x12345678
MOVL R1, 0x5678
MOVH R1, 0x1234
```

In the`LOAD`and`STORE` instructions, the effective address is calculated as the sum of the base register value (`rs`) and the immediate offset (`imm18`multiplied by 4). The value loaded or stored is 32 bits. Thus, the immediate offset is interpreted as a number of words, and multiplying by 4 converts it to bytes, ensuring that memory access is always aligned to 4 bytes. However, it is possible to generate addresses larger than 16 MB by using a large offset, but the VM must verify that the final address falls within the range of`0x00000000`to`0x00FFFFFF`. If the calculated address is outside these limits, the VM must trigger an invalid address error and abort execution.

### 1.3.3 - Flow Control (Type I and J)

See file @type_I_J.csv

### Details

Conditional branch instructions (`BEQ`,`BNE`,`BLT`,`BGT`,`BLE`,`BGE`) compare the values of the`rs`and`rt` registers. If the condition is true, the`PC`is updated to the destination address calculated as the current`PC`plus the immediate offset multiplied by 4. The offset is interpreted as a number of words, and multiplying by 4 converts it to bytes, ensuring that the jump is always to a 4-byte-aligned address. The`0xFFFF`mask is used to ensure that the offset is treated as a 16-bit value. Thus, with 16 bits, the offset is valid for a range from -32768 to 32767 words. The offset is encoded in two’s complement, allowing for both forward and backward jumps.

In summary,`imm18 & 0xFFFF`is the number of instructions to skip, and the destination address is relative to`the program counter (PC`) of the next instruction (`PC + 4`). For example, if the offset is set to the jump instruction itself, the offset would be -1, resulting in an infinite loop. If the offset is 0, the PC would advance to the next instruction as usual. If the condition is false, the`PC`simply advances to the next instruction (`PC + 4`).

Unconditional jump instructions (`JMP`and`CALL`) use an absolute address calculated as the value of the`addr26`field multiplied by 4. This means that the destination address is always 4-byte aligned. Before updating the PC to the destination address, the`CALL` instruction pushes the address of the next instruction (`PC + 4`) onto the stack, allowing the called function to return correctly using the`RET` instruction. It is important for the VM to verify that the calculated destination address falls within the range of`0x00000000`to`0x00FFFFFF`. If the address is outside these limits, the VM must trigger an invalid address error and abort execution.

### 1.3.4 - Unary Operations and the Stack (Type U - 1 Operand)

See the @type_U.csv file

### Details

The `PUSH` and `POP` instructions manipulate the stack by pushing and popping the contents of the `rd` register. The VM must verify that the push or pop operation does not exceed the stack limits. If a `PUSH` is executed when the `SP` is at 0x0FFEFFF, or a `POP` is executed when the `SP` is at 0x00FFFFFF, the VM must trigger a stack*overflow*or*stack underflow* error, respectively, and abort execution.

The `NOT` instruction performs a bit-by-bit negation operation on the `rd` register, inverting all bits of the stored value.

The `RET` instruction is used to return from a function. It ignores the `rd` field and simply pops the return address from the stack, updating the `PC` to that address.

### 1.3.5 - System and I/O (Type S)

See file @type_S.csv

### Details

The colors used in the`RECT`,`CLEAR`,`PSTR`, and`PINT`instructions and in sprite definitions are represented as an ARGB integer (`0xAARRGGBB`). `AA`represents the transparency channel,`RR`represents red,`GG`represents green, and`BB`represents blue. Each component is a hexadecimal value from`00`to`FF`(`0`to`255`in decimal). The transparency channel (alpha channel) determines the color’s opacity, where`00`is completely transparent and`FF`is completely opaque.

A transparent color is represented by`0x00000000`. In drawing operations, transparent pixels must not alter the contents of*the framebuffer*, allowing the background or other graphical elements to be visible through them. Text printing instructions (`PSTR`and`PINT`) must render characters using the specified color, but the background of the characters must be transparent; that is, the background pixels must not be altered by the text rendering.

The*framebuffer*can be accessed directly via`LOAD/STORE`, but drawing instructions (`RECT`,`DSPRITE`,`CLEAR`,`PSTR`,`PINT`) are the preferred method for manipulating the*framebuffer*. The*framebuffer*is automatically updated every frame, and changes made by these instructions will be reflected on the screen during the next update.

The`RECT`instruction draws a filled rectangle on*the framebuffer*, where the coordinates`(x, y)`represent the top-left corner and`(w, h)`represent the width and height of the rectangle. Thus, to draw a single pixel, simply set`w`and`h`to 1. If the rectangle extends beyond the screen boundaries, the VM should draw only the visible portion without causing errors.

The`DSPRITE`instruction should draw a sprite on*the framebuffer*, with the coordinates`(x, y)`representing the upper-left corner. The width and height of the sprite are defined by`rc`and`rd`, respectively. The sprite’s address in``re``points to a memory block containing the sprite’s data, organized as an array of pixels (ARGB integers) in*row-major* format. If the sprite extends beyond the screen boundaries, the VM should draw only the visible portion without causing errors.

The`CLEAR`instruction must fill the entire screen with the specified color.

The`PSTR`instruction must print a string on the screen, with the top-left corner at position (x, y). The string is terminated by a null byte (0x00) and must be rendered using a simple monospaced font (16x16 pixels per character). The`PINT`instruction must print an integer on the screen, converting the value in`rc`to a decimal string and rendering it in the same way as PSTR.

The`SLEEP`instruction must pause program execution for a time specified by`ra`(in ms). During this period, the VM must continue processing events (such as keyboard input), updating the screen, and playing sound, but must not execute any other program instructions.

The`PLAY`instruction must play a sound at the frequency specified by``ra`` (in Hz) for the duration specified by ``rb`` (in ms). Program execution must not be blocked while the sound is playing. If the instruction is executed while another sound is playing, the new sound must replace the previous one. The waveform is determined by the value in`rc`. The waveform codes are:

| Waveform | Code | HEX |
| --- | --- | --- |
| SINE | 0 | 0x00 |
| SQUARE | 1 | 0x01 |
| TRIANGLE | 2 | 0x02 |
| NOISE | 3 | 0x03 |

The keyboard has 16 keys mapped to the values 0 through 15. The`GKEY`instruction returns 1 in`ra`if the key specified in`rb`is pressed, or 0 otherwise. The key codes are defined as follows:

| Key | Code | HEX |
| --- | --- | --- |
| LEFT ARROW | 0 | 0x00 |
| RIGHT ARROW | 1 | 0x01 |
| UP ARROW | 2 | 0x02 |
| DOWN ARROW | 3 | 0x03 |
| SPACE | 4 | 0x04 |
| ENTER | 5 | 0x05 |
| N | 6 | 0x06 |
| M | 7 | 0x07 |
| A | 8 | 0x08 |
| S | 9 | 0x09 |
| D | 10 | 0x0A |
| W | 11 | 0x0B |
| Q | 12 | 0x0C |
| E | 13 | 0x0D |
| C | 14 | 0x0E |
| V | 15 | 0x0F |

The`SRAND`instruction must initialize the random number generator with the seed specified in`ra`. The random number generator must be implemented using the Linear Congruential Generator (LCG) method. The`RAND`instruction must generate a random number between the values specified by`rb`(minimum) and`rc`(maximum), inclusive, and store the result in`ra`. The sequence of numbers generated by`RAND`must be the same for the same seed, allowing games to be reproduced consistently.

The`SYSCALL`instruction is reserved for future system extensions, allowing new features to be added without altering the base instruction set. The syscall code in ``ra``must be used to identify which operation should be performed, and the registers``rb``through``re``can be used to pass additional arguments. I suggest implementing syscalls to aid in game development, such as for:

- Printing a register to the terminal;
- Print a string from the program to the terminal;
- Print the state of the registers to the terminal;
- Pausing execution until a key is pressed.

The`FRAMENUM`instruction should return the number of frames rendered since the program began executing. This value can be used to create time-based animations, allowing games to be synchronized with the screen refresh rate (60 FPS).

The`HALT`instruction must cleanly terminate the VM’s execution, freeing any allocated resources and closing the graphics window.

## 2. Assembly Language and the Assembler

The assembler must process an .asm file and generate a .bin file containing the corresponding machine code.

The assembler will be provided by the instructor, but it is important to understand the format of .asm and .bin files to ensure that the assembly code is written correctly and that the generated binary file is loaded and executed correctly by the VM.

The .asm file is a text file containing Assembly code, which may include instructions, directives,*labels*, and comments. The assembler must be able to interpret directives to allocate data and organize the code, as well as resolve*label*addresses to generate the .bin file correctly.

The .bin file is a pure binary file, containing only the bytes of instructions and data, with a small header. Each Assembly instruction is converted to 4 bytes in the specified format, and data is allocated according to the directives used in the Assembly code. The Assembler must ensure that the resulting .bin file is compatible with the VM, adhering to 4-byte alignment and*big-endian* ordering.

### 2.1 Directives

### Data Section

The first section of the .asm file must be the data section, introduced by the`.data` directive. In this section, the programmer can define variables, constants, and strings that will be used by the program. The assembler must allocate the data in memory starting at address`0x00000000`, following the order in which they are defined in the code. The programmer can use*labels*to reference this data later in the code. The`.data`section is mandatory and must be present even if there is no need to define data. The directives available for the data section are:

- `.equ [name], [value]`: Defines a constant. The assembler must replace all occurrences of`name`in the code with the defined value, allowing the programmer to use meaningful names for constant values. This directive does not allocate memory space.
- `.var [val]`: Allocates a 32-bit word with the specified value. The assembler must store the value in big-endian format in the .bin file.
- `.array [val1, val2, ...]`: Allocates an array of 32-bit words with the specified values. The assembler must store each value in big-endian format in the .bin file, arranging the values in sequence.
- `.space [N]`: Reserves N words (padded with zeros). The assembler must allocate the necessary space in the .bin file, padding the bytes with zeros. The difference between`.space`and`.array`is that`.space`only reserves space by initializing it with zeros, while`.array`allocates space and initializes the values as specified.
- `.string "text"`: Allocates the string in 4-byte blocks. The assembler must ensure that the string is terminated with a null byte (`0x00`) and that the bytes are organized in big-endian format, padding the 4-byte blocks as necessary. If the string (including the null byte) is not a multiple of 4 bytes, the assembler must pad the remaining bytes of the last block with zeros. For simplicity, character encoding must be`ASCII`(7-bit), allowing strings containing printable characters from`0x20`to`0x7E`. Characters outside this range must be treated as invalid, and the assembler must trigger an error.

### Code Section

The code section begins with the`.text` directive. In this section, the programmer writes the assembly instructions that make up the program. The programmer can use*labels*to mark positions in the code and reference them in flow-control instructions. The programmer can also use*labels*from the data section to access variables and constants.

### 2.2 Writing Rules

### **Comments**

Comments are preceded by`;`. Everything after the`;`on the same line is ignored by the assembler. Comments can be used to explain the code, annotate sections, or provide any additional information that aids in understanding the program. The assembler should simply ignore comments during assembly, without affecting the generation of the .bin file.

### **Labels**

*Labels*are identifiers followed by a colon (e.g.,`START:`). Identifiers must start with a letter or an underscore, followed by letters, digits, or underscores.*Labels*are used to mark positions in the code and can be referenced in flow-control statements.

The assembler must resolve*label*addresses during assembly by replacing references with the correct offsets.*Labels*can also be used to mark data locations, allowing the code to access that data using load instructions. The assembler must ensure that*label*addresses are calculated correctly, taking into account the alignment and organization of the code and data in the .bin file.

The high-order (most significant) part of a data*label*can be referenced using`.h`, and the low-order part using`.l`. For example, if a*label*``msg`` is defined in the data section,``msg.h`` will reference the most significant 16 bits of the``msg`` address, while``msg.l`` will reference the least significant 16 bits. This allows a 32-bit address to be loaded into a register using a combination of`MOVL`and`MOVH`. For example:

```nasm
; Suponha que o msg esteja definido na seção de dados no endereço 0x12345678

; msg.l = 0x5678 (parte baixa)
MOVL R1, msg.l  ; Carrega a parte baixa do endereço de msg em R1
                ; zera os bits superiores, resultando em R1 = 0x00005678

; msg.h = 0x1234 (parte alta)
MOVH R1, msg.h  ; Carrega a parte alta do endereço de msg em R1,
                ; combinando com a parte baixa já carregada
                ; resultado final em R1 = 0x12345678
```

### **Numbering**

Numbers can be written in decimal (e.g., 10) and hexadecimal (e.g., 0x0A) notation.

### 2.3 .bin File Format

The .bin file is a pure binary file, containing a short header followed by bytes of instructions and data. The file format is as follows:

1. **Header**: The first 4 bytes of the`.bin`file must contain the starting address of the code, which is used by the VM to set the initial value of the PC. This value varies depending on the amount of allocated data memory and will be`0x00000000`if there is no data, or the address immediately following the allocated data. The assembler must calculate this address based on the amount of data defined in the data section and ensure that the code is properly aligned.
2. **Data**: The data defined in the data section is stored immediately after the header. The assembler must ensure that the data is organized according to the directives used, respecting 4-byte alignment and big-endian ordering. The address of each data item is determined by its position in the assembly code, and the assembler must calculate the addresses correctly to allow the code to access this data using load instructions.
3. **Instructions**: The instruction code is stored immediately after the data. Each assembly instruction is converted to 4 bytes in the specified format, following big-endian order.

### 2.4 Example of Assembly Code

```nasm
; Exemplo de programa que desenha um retângulo e
; espera pela tecla ESPAÇO ser pressionada para continuar

.data
.equ SPACE_KEYCODE, 0x04
.equ AZUL, 0xFF0000FF
.equ BRANCO, 0xFFFFFFFF
.equ PRETO, 0xFF000000
.equ RETANGULO_LARG, 8
.equ RETANGULO_ALT, 8
msg: .string "Pressione ESPACO para continuar..."

.text
START:
    ; Limpa a tela
    MOVL R1, PRETO.l         ; color = preto (parte baixa)
    MOVH R1, PRETO.h         ; color = preto (parte alta)
    CLEAR R1

    ; Desenha um retângulo azul no centro da tela
    MOVL R1, 160            ; x = 160
    MOVL R2, 120            ; y = 120
    MOVL R3, RETANGULO_LARG ; w = 8
    MOVL R4, RETANGULO_ALT  ; h = 8
    MOVL R5, AZUL.l         ; color = azul (parte baixa)
    MOVH R5, AZUL.h         ; color = azul (parte alta)
    RECT R1, R2, R3, R4, R5

    ; Imprime a mensagem
    MOVL R1, 160            ; x = 160
    MOVL R2, 120            ; y = 120
    MOVL R3, msg.l          ; endereço da string (parte baixa)
    MOVH R3, msg.h          ; endereço da string (parte alta)
    MOVL R4, BRANCO.l         ; color = branco (ARGB)
    MOVH R4, BRANCO.h         ; color = branco (ARGB)
    PSTR R1, R2, R3, R4

WAIT_KEY:
    ; Espera até que a tecla ESPAÇO seja pressionada
    MOVL R2, SPACE_KEYCODE  ; keyID = ESPAÇO
    GKEY R1, R2             ; R1 = 1 se ESPAÇO estiver pressionado,
                            ; 0 caso contrário
    BEQ R1, R0, WAIT_KEY    ; Se R1 == 0, continua esperando

    ; Limpa a tela com azul após a tecla ser pressionada
    MOVL R1, AZUL.l         ; color = azul (parte baixa)
    MOVH R1, AZUL.h         ; color = azul (parte alta)
    CLEAR R1                ; Limpa a tela com azul

END: ; Fica em loop infinito
    BEQ R0, R0, END
```
