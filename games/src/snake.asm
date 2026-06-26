; ==========================================================
; SNAKE - FANTASYS32
; ==========================================================

.data
; Cores em ARGB (0xAARRGGBB)
.equ PRETO,    0xFF000000
.equ VERDE,    0xFF00FF00
.equ VERMELHO, 0xFFFF0000
.equ BRANCO,   0xFFFFFFFF

; Códigos do Teclado
.equ KEY_LEFT,  0
.equ KEY_RIGHT, 1
.equ KEY_UP,    2
.equ KEY_DOWN,  3
.equ KEY_ENTER, 4

; Dimensões
.equ TAM_BLOCO, 8
.equ TELA_W,    320
.equ TELA_H,    240

; Estado do Jogo
TAMANHO: .var 1          ; Tamanho inicial da cobra (1 segmento)
DIRECAO: .var 1          ; 0=Esq, 1=Dir, 2=Cima, 3=Baixo
SCORE:   .var 0          ; Pontuação

; Posição inicial da maçã
MACA_X: .var 80
MACA_Y: .var 40

; Arrays para os segmentos da cobra (capacidade máxima: 100)
COBRA_X: .space 100
COBRA_Y: .space 100

; Strings de mensagem
msg_go:    .string "GAME OVER"
msg_score: .string "SCORE:"

.text
START:
    ; Inicializar semente aleatória
    MOVL R1, 1234
    SRAND R1

    ; Posicionar cabeça no centro da tela
    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    MOVL R2, 160
    STORE R2, R1, 0      ; COBRA_X[0] = 160

    MOVL R1, COBRA_Y.l
    MOVH R1, COBRA_Y.h
    MOVL R2, 120
    STORE R2, R1, 0      ; COBRA_Y[0] = 120

GAME_LOOP:
    ; ----------------------------------------------------------
    ; 1. TIMING E LIMPEZA DE TELA
    ; ----------------------------------------------------------
    MOVL R1, 100
    SLEEP R1

    MOVL R1, PRETO.l
    MOVH R1, PRETO.h
    CLEAR R1

    ; ----------------------------------------------------------
    ; 2. ENTRADA DE TECLADO
    ; ----------------------------------------------------------
    MOVL R2, KEY_RIGHT
    GKEY R1, R2
    BEQ R1, R0, CHK_LEFT
    MOVL R3, 1
    JMP SAVE_DIR

CHK_LEFT:
    MOVL R2, KEY_LEFT
    GKEY R1, R2
    BEQ R1, R0, CHK_UP
    MOVL R3, 0
    JMP SAVE_DIR

CHK_UP:
    MOVL R2, KEY_UP
    GKEY R1, R2
    BEQ R1, R0, CHK_DOWN
    MOVL R3, 2
    JMP SAVE_DIR

CHK_DOWN:
    MOVL R2, KEY_DOWN
    GKEY R1, R2
    BEQ R1, R0, SKIP_INPUT
    MOVL R3, 3

SAVE_DIR:
    MOVL R1, DIRECAO.l
    MOVH R1, DIRECAO.h
    STORE R3, R1, 0

SKIP_INPUT:
    ; ----------------------------------------------------------
    ; 3. SHIFT DO CORPO: COBRA_X/Y[i] = COBRA_X/Y[i-1]
    ;    começa em i = TAMANHO-1 e vai até i = 1
    ; ----------------------------------------------------------
    MOVL R1, TAMANHO.l
    MOVH R1, TAMANHO.h
    LOAD R10, R1, 0       ; R10 = TAMANHO

    ADD R11, R10, R0      ; R11 = TAMANHO (cópia para iterador)
    DEC R11               ; R11 = TAMANHO - 1

SHIFT_LOOP:
    BEQ R11, R0, MOVE_HEAD  ; Se i == 0 termina o shift

    MOVL R6, 4
    MUL R12, R11, R6         ; R12 = offset_dest = i * 4
    MOVL R13, 1
    SUB R13, R11, R13        ; R13 = i - 1
    MUL R13, R13, R6         ; R13 = offset_orig = (i-1) * 4

    ; COBRA_X[i] = COBRA_X[i-1]
    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    ADD R2, R1, R13
    LOAD R4, R2, 0           ; R4 = COBRA_X[i-1]
    ADD R3, R1, R12
    STORE R4, R3, 0          ; COBRA_X[i] = R4

    ; COBRA_Y[i] = COBRA_Y[i-1]
    MOVL R1, COBRA_Y.l
    MOVH R1, COBRA_Y.h
    ADD R2, R1, R13
    LOAD R4, R2, 0           ; R4 = COBRA_Y[i-1]
    ADD R3, R1, R12
    STORE R4, R3, 0          ; COBRA_Y[i] = R4

    DEC R11
    JMP SHIFT_LOOP

    ; ----------------------------------------------------------
    ; 4. MOVER A CABEÇA
    ; ----------------------------------------------------------
MOVE_HEAD:
    MOVL R1, DIRECAO.l
    MOVH R1, DIRECAO.h
    LOAD R3, R1, 0        ; R3 = direção atual

    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    LOAD R4, R1, 0        ; R4 = COBRA_X[0]

    MOVL R2, COBRA_Y.l
    MOVH R2, COBRA_Y.h
    LOAD R5, R2, 0        ; R5 = COBRA_Y[0]

    ; R1 e R2 guardam as bases de COBRA_X e COBRA_Y (índice 0)

    BEQ R3, R0, MOV_ESQ  ; direção 0 = Esquerda
    MOVL R6, 1
    BEQ R3, R6, MOV_DIR  ; direção 1 = Direita
    MOVL R6, 2
    BEQ R3, R6, MOV_CIM  ; direção 2 = Cima
    JMP MOV_BAI           ; caso contrário = Baixo

MOV_ESQ:
    MOVL R6, TAM_BLOCO
    SUB R4, R4, R6
    JMP SAVE_HEAD
MOV_DIR:
    MOVL R6, TAM_BLOCO
    ADD R4, R4, R6
    JMP SAVE_HEAD
MOV_CIM:
    MOVL R6, TAM_BLOCO
    SUB R5, R5, R6
    JMP SAVE_HEAD
MOV_BAI:
    MOVL R6, TAM_BLOCO
    ADD R5, R5, R6

SAVE_HEAD:
    STORE R4, R1, 0       ; COBRA_X[0] = novo X
    STORE R5, R2, 0       ; COBRA_Y[0] = novo Y

    ; ----------------------------------------------------------
    ; 5. COLISÃO COM PAREDES → GAME OVER
    ; ----------------------------------------------------------
    BLT R4, R0, GAME_OVER       ; head_x < 0
    MOVL R6, TELA_W
    BGE R4, R6, GAME_OVER       ; head_x >= 320
    BLT R5, R0, GAME_OVER       ; head_y < 0
    MOVL R6, TELA_H
    BGE R5, R6, GAME_OVER       ; head_y >= 240

    ; ----------------------------------------------------------
    ; 6. COLISÃO COM A MAÇÃ
    ; ----------------------------------------------------------
    MOVL R7, MACA_X.l
    MOVH R7, MACA_X.h
    LOAD R8, R7, 0               ; R8 = MACA_X
    MOVL R7, MACA_Y.l
    MOVH R7, MACA_Y.h
    LOAD R9, R7, 0               ; R9 = MACA_Y

    BNE R4, R8, DRAW_STAGE       ; head_x != maca_x → não comeu
    BNE R5, R9, DRAW_STAGE       ; head_y != maca_y → não comeu

    ; --- COMEU A MAÇÃ: crescer e pontuar ---
    MOVL R1, TAMANHO.l
    MOVH R1, TAMANHO.h
    LOAD R10, R1, 0
    INC R10
    STORE R10, R1, 0

    MOVL R1, SCORE.l
    MOVH R1, SCORE.h
    LOAD R10, R1, 0
    INC R10
    STORE R10, R1, 0

    ; --- Nova posição aleatória para a maçã ---
    ; X: (RAND % 40) * 8  →  valores: 0, 8, 16, ..., 312
    RAND R8, R0, R0
    MOVL R7, 40
    MOD R8, R8, R7
    MOVL R7, TAM_BLOCO
    MUL R8, R8, R7

    ; Y: (RAND % 30) * 8  →  valores: 0, 8, 16, ..., 232
    RAND R9, R0, R0
    MOVL R7, 30
    MOD R9, R9, R7
    MOVL R7, TAM_BLOCO
    MUL R9, R9, R7

    ; Salvar nova posição da maçã
    MOVL R1, MACA_X.l
    MOVH R1, MACA_X.h
    STORE R8, R1, 0
    MOVL R1, MACA_Y.l
    MOVH R1, MACA_Y.h
    STORE R9, R1, 0

    ; ----------------------------------------------------------
    ; 7. RENDERIZAÇÃO
    ; ----------------------------------------------------------
DRAW_STAGE:
    ; Desenhar a maçã (vermelho)
    MOVL R1, MACA_X.l
    MOVH R1, MACA_X.h
    LOAD R1, R1, 0
    MOVL R2, MACA_Y.l
    MOVH R2, MACA_Y.h
    LOAD R2, R2, 0
    MOVL R3, TAM_BLOCO
    MOVL R4, TAM_BLOCO
    MOVL R5, VERMELHO.l
    MOVH R5, VERMELHO.h
    RECT R1, R2, R3, R4, R5

    ; Desenhar todos os segmentos da cobra (verde)
    MOVL R5, VERDE.l
    MOVH R5, VERDE.h
    MOVL R3, TAM_BLOCO
    MOVL R4, TAM_BLOCO

    MOVL R1, TAMANHO.l
    MOVH R1, TAMANHO.h
    LOAD R10, R1, 0       ; R10 = contador de segmentos restantes
    MOVL R11, 0           ; R11 = índice i = 0

DRAW_LOOP:
    BEQ R10, R0, DRAW_HUD

    MOVL R6, 4
    MUL R12, R11, R6      ; R12 = byte offset = i * 4

    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    ADD R1, R1, R12       ; R1 = endereço de COBRA_X[i]
    LOAD R1, R1, 0        ; R1 = COBRA_X[i]

    MOVL R2, COBRA_Y.l
    MOVH R2, COBRA_Y.h
    ADD R2, R2, R12       ; R2 = endereço de COBRA_Y[i]
    LOAD R2, R2, 0        ; R2 = COBRA_Y[i]

    RECT R1, R2, R3, R4, R5

    INC R11
    DEC R10
    JMP DRAW_LOOP

    ; ----------------------------------------------------------
    ; 8. HUD: exibir placar
    ; ----------------------------------------------------------
DRAW_HUD:
    ; "SCORE:" em (4, 4)
    MOVL R1, 4
    MOVL R2, 4
    MOVL R3, msg_score.l
    MOVH R3, msg_score.h
    MOVL R4, BRANCO.l
    MOVH R4, BRANCO.h
    PSTR R1, R2, R3, R4

    ; valor do score em (60, 4)
    MOVL R1, 60
    MOVL R2, 4
    MOVL R5, SCORE.l
    MOVH R5, SCORE.h
    LOAD R3, R5, 0
    MOVL R4, BRANCO.l
    MOVH R4, BRANCO.h
    PINT R1, R2, R3, R4

    JMP GAME_LOOP

    ; ----------------------------------------------------------
    ; TELA DE GAME OVER
    ; ----------------------------------------------------------
GAME_OVER:
    MOVL R1, PRETO.l
    MOVH R1, PRETO.h
    CLEAR R1

    ; "GAME OVER" centrado em (120, 110)
    MOVL R1, 120
    MOVL R2, 110
    MOVL R3, msg_go.l
    MOVH R3, msg_go.h
    MOVL R4, VERMELHO.l
    MOVH R4, VERMELHO.h
    PSTR R1, R2, R3, R4

    ; pontuação final em (120, 130)
    MOVL R1, 120
    MOVL R2, 130
    MOVL R5, SCORE.l
    MOVH R5, SCORE.h
    LOAD R3, R5, 0
    MOVL R4, BRANCO.l
    MOVH R4, BRANCO.h
    PINT R1, R2, R3, R4

    MOVL R1, 16
    SLEEP R1

    ; Aguarda ENTER para encerrar
    MOVL R2, KEY_ENTER
    GKEY R1, R2
    BEQ R1, R0, GAME_OVER   ; sem ENTER → fica na tela de game over

    HALT
