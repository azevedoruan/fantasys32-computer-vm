# Fantasys32: A Fantasy Computer of 32-bits

The Fantasy Computer is a hypothetical machine designed to allow the implementation of a custom instruction set and simple video-games creation. This project is split into phases: the implementation of the VM and the creation of a simple game to be run by the VM. This is a project made for my university course.

## Estrutura do projeto

```
fantasys32-computer-vm/
├── assembler/        Montador (.asm -> .bin), fornecido pelo professor
│   ├── src/
│   └── bin/
├── vm/               Máquina virtual (C++ + SDL2)
│   ├── src/
│   └── bin/
└── games/            Jogos em Assembly
    ├── src/
    │   ├── prog1.asm     Exemplo da especificação
    │   └── breakout.asm  Jogo Breakout
    └── bin/
        └── breakout.bin  Binário gerado pelo montador
```

## Dependências

- Compilador C++ (`g++` ou `clang++`)
- `make`
- SDL2 (`libsdl2-dev` no Linux)

No Ubuntu/Debian:

```sh
sudo apt install build-essential libsdl2-dev
```

## Como compilar

### Montador (assembler)

```sh
cd assembler
make
```

### Máquina virtual (VM)

```sh
cd vm
make
```

## O jogo: Breakout

Clone clássico do Breakout. A bola desce, você rebate com a raquete e quebra
os blocos. Cada fileira de blocos tem uma cor e uma pontuação diferente.

### Gerar o binário do jogo

O arquivo-fonte é `games/src/breakout.asm`. Para gerar o `.bin` que a VM
executa, rode o montador sobre ele:

```sh
./assembler/assembler games/src/breakout.asm games/bin/breakout.bin
```

### Rodar o jogo

A VM recebe o caminho do `.bin` e algumas opções:

```sh
./vm/vm games/bin/breakout.bin
```

Para abrir a janela em escala maior (a tela nativa é 320x240):

```sh
./vm/vm --scale 2 games/bin/breakout.bin
```

### Opções de linha de comando da VM

- `--scale <fator>`: fator de escala da janela. `--scale 2` gera uma janela de
  640x480. Padrão: 1.
- `--no-syscall`: desativa a instrução `SYSCALL` (a VM a ignora). O jogo foi
  feito para funcionar normalmente com essa opção ligada, pois não depende de
  syscalls para a lógica principal.
- `--help`: mostra a ajuda.

## Controles

- Seta esquerda / direita: mover a raquete
- ENTER: reiniciar após o fim de jogo

## Objetivo

Quebre todos os blocos sem deixar a bola cair. Você tem 3 vidas. A pontuação
depende da cor da fileira (as fileiras de cima valem mais). A bola acelera
conforme você marca pontos.