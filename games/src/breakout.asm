; ============================================================================
;  BREAKOUT  -  Fantasys32 Assembly
; ----------------------------------------------------------------------------
;  Clone clássico do Breakout (Atari, 1976).
;
;  Tela: 320x240. Origem (0,0) no canto superior esquerdo.
;
;  Elementos (todos desenhados com RECT, pois são retângulos):
;    - Raquete: retângulo na parte de baixo, move na horizontal.
;    - Bola:    retângulo pequeno, move em (dx,dy) inteiros por frame.
;    - Blocos:  grade 8 colunas x 5 fileiras = 40 blocos.
;               Cores por fileira (de cima p/ baixo): vermelho, laranja,
;               amarelo, verde, azul -> também codificam a pontuação.
;
;  Estado do jogo:
;    - 3 vidas, placar, velocidade da bola aumenta em marcos de pontos.
;
;  CONVENÇÃO DE REGISTRADORES (uso geral, dentro de cada rotina):
;    R0  = constante 0 (fixo pela arquitetura)
;    R1..R13 = registradores de trabalho (scratch)
;    R14 = SP (pilha, gerenciado pela VM)
;    R15 = PC (gerenciado pela VM)
;
;  O ESTADO PERSISTENTE (sobrevive entre frames) fica na MEMÓRIA, na seção
;  .data, e é lido com LOAD / escrito com STORE. Registradores são apenas
;  para cálculos curtos dentro de cada rotina.
;
;  IMPORTANTE sobre LOAD/STORE:
;    LOAD  rt, rs, imm  ->  rt = Mem[rs + imm*4]
;    STORE rt, rs, imm  ->  Mem[rs + imm*4] = rt
;    Vamos usar R0 como base (R0=0) e o endereço da variável como imm em
;    PALAVRAS. Como cada variável tem um label cujo endereço em BYTES é
;    múltiplo de 4, usamos (label/4) como deslocamento. Para manter simples
;    e legível, cada variável é carregada via MOVL/MOVH do endereço completo
;    em um registrador base e LOAD/STORE com deslocamento 0.
; ============================================================================

.data

; ---- Constantes de cor (ARGB: 0xAARRGGBB, AA=FF é opaco) -------------------
.equ COR_FUNDO,    0xFF101018   ; azul bem escuro (fundo)
.equ COR_RAQUETE,  0xFFE0E0E0   ; cinza claro
.equ COR_BOLA,     0xFFFFFFFF   ; branco
.equ COR_TEXTO,    0xFFFFFFFF   ; branco
.equ COR_VERMELHO, 0xFFE24B4A   ; fileira 0 (topo)  -> 7 pts
.equ COR_LARANJA,  0xFFEF9F27   ; fileira 1         -> 5 pts
.equ COR_AMARELO,  0xFFFCDE5A   ; fileira 2         -> 3 pts
.equ COR_VERDE,    0xFF97C459   ; fileira 3         -> 1 pt
.equ COR_AZUL,     0xFF378ADD   ; fileira 4         -> 1 pt

; ---- Pontos por fileira (índice = fileira) ---------------------------------
.equ PTS_F0, 7
.equ PTS_F1, 5
.equ PTS_F2, 3
.equ PTS_F3, 1
.equ PTS_F4, 1

; ---- Geometria da tela e dos objetos ---------------------------------------
.equ TELA_W,       320
.equ TELA_H,       240
.equ RAQ_W,        48          ; largura da raquete
.equ RAQ_H,        6           ; altura da raquete
.equ RAQ_Y,        220         ; Y fixo da raquete (perto da base)
.equ RAQ_VEL,      4           ; pixels por frame que a raquete anda
.equ BOLA_TAM,     5           ; bola é um quadrado BOLA_TAM x BOLA_TAM

; ---- Grade de blocos -------------------------------------------------------
.equ NUM_COLS,     8
.equ NUM_FILAS,    5
.equ NUM_BLOCOS,   40          ; NUM_COLS * NUM_FILAS
.equ BLOCO_W,      36          ; 8*36 = 288, margem de 16px cada lado
.equ BLOCO_H,      12
.equ BLOCO_GAP,    4           ; espaço desenhado entre blocos (visual)
.equ GRADE_X,      16          ; X inicial da grade
.equ GRADE_Y,      30          ; Y inicial da grade

; ---- Teclas (códigos da spec) ----------------------------------------------
.equ TECLA_ESQ,    0x00
.equ TECLA_DIR,    0x01
.equ TECLA_ESPACO, 0x04
.equ TECLA_ENTER,  0x05

; ---- Regras do jogo --------------------------------------------------------
.equ VIDAS_INI,    3
.equ MARCO_VEL,    50          ; a cada 50 pts a bola acelera (limitado)
.equ VEL_MAX,      5           ; velocidade máxima por eixo

; ---- Sons (frequências em Hz) ----------------------------------------------
.equ SOM_PAREDE,   220
.equ SOM_RAQUETE,  330
.equ SOM_BLOCO,    440
.equ SOM_PERDE,    110
.equ SOM_DUR,      40          ; duração curta em ms
.equ ONDA_QUAD,    0x01        ; forma de onda quadrada (estilo retrô)

; ============================================================================
;  VARIÁVEIS PERSISTENTES (uma palavra de 32 bits cada)
; ============================================================================
bola_x:   .var 158        ; posição X da bola (centro-ish)
bola_y:   .var 150        ; posição Y da bola
bola_dx:  .var 2          ; velocidade X (pode ser negativa)
bola_dy:  .var -2         ; velocidade Y (negativa = subindo)
raq_x:    .var 136        ; X da raquete (canto esquerdo) = (320-48)/2
vidas:    .var 3          ; vidas restantes
placar:   .var 0          ; pontuação
blocos_vivos: .var 40     ; quantos blocos restam (p/ detectar vitória)
estado:   .var 0          ; 0=jogando, 1=game over, 2=vitória
vel_base: .var 2          ; magnitude base da velocidade (cresce com placar)

; Grade de blocos: 40 palavras. Valor 0 = destruído; senão = cor do bloco.
; Inicializada em runtime pela rotina INIT_BLOCOS (mais flexível que .array).
grade:    .space 40

; Strings de mensagem
msg_go:   .string "GAME OVER"
msg_win:  .string "VOCE VENCEU!"
msg_vidas: .string "VIDAS:"
msg_pts:  .string "PONTOS:"

; ============================================================================
;  CÓDIGO
; ============================================================================
.text

; ----------------------------------------------------------------------------
;  PONTO DE ENTRADA
; ----------------------------------------------------------------------------
MAIN:
    ; Inicializa o gerador de números aleatórios com uma semente fixa.
    ; (Semente fixa -> jogo reproduzível, como a spec sugere.)
    MOVL R1, 12345
    SRAND R1

    ; Preenche a grade de blocos com as cores corretas por fileira.
    CALL INIT_BLOCOS

; ----------------------------------------------------------------------------
;  LAÇO PRINCIPAL DO JOGO  (executa uma vez por frame)
; ----------------------------------------------------------------------------
GAME_LOOP:
    ; --- Verifica o estado do jogo ---
    ; Se estado != 0 (game over ou vitória), pula para a tela final.
    MOVL R1, estado.l
    MOVH R1, estado.h
    LOAD R2, R1, 0            ; R2 = estado
    BNE R2, R0, FIM_DE_JOGO   ; se estado != 0 -> tela de fim

    ; --- 1. ENTRADA: lê teclado e move a raquete ---
    CALL ATUALIZA_RAQUETE

    ; --- 2/3. FÍSICA: move a bola e trata colisões ---
    CALL ATUALIZA_BOLA

    ; --- 4. Verifica condição de vitória ---
    MOVL R1, blocos_vivos.l
    MOVH R1, blocos_vivos.h
    LOAD R2, R1, 0           ; R2 = blocos vivos
    BNE R2, R0, PULA_VITORIA ; se ainda há blocos, segue
    ; venceu: estado = 2
    MOVL R3, 2
    MOVL R1, estado.l
    MOVH R1, estado.h
    STORE R3, R1, 0
PULA_VITORIA:

    ; --- 5. DESENHO ---
    CALL DESENHA_TUDO

    ; --- Sincroniza ~60 FPS: dorme ~16 ms ---
    MOVL R1, 16
    SLEEP R1

    ; volta ao início do laço
    JMP GAME_LOOP

; ----------------------------------------------------------------------------
;  INIT_BLOCOS: preenche grade[] com a cor de cada bloco conforme a fileira.
;  Índice i: fileira = i / NUM_COLS, coluna = i % NUM_COLS.
; ----------------------------------------------------------------------------
INIT_BLOCOS:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8

    ; R6 = endereço base da grade
    MOVL R6, grade.l
    MOVH R6, grade.h

    MOVL R1, 0               ; R1 = índice do bloco (0..39)
    MOVL R2, NUM_BLOCOS      ; R2 = limite (40)
IB_LOOP:
    BGE R1, R2, IB_FIM       ; se i >= 40, termina

    ; R3 = fileira = i / NUM_COLS
    MOVL R5, NUM_COLS
    DIV R3, R1, R5           ; R3 = i / 8

    ; Decide a cor conforme a fileira (R3). Cadeia de comparações.
    MOVL R7, COR_VERMELHO.l
    MOVH R7, COR_VERMELHO.h  ; R7 = cor padrão (fileira 0)
    MOVL R8, 0
    BEQ R3, R8, IB_TEM_COR
    MOVL R7, COR_LARANJA.l
    MOVH R7, COR_LARANJA.h
    MOVL R8, 1
    BEQ R3, R8, IB_TEM_COR
    MOVL R7, COR_AMARELO.l
    MOVH R7, COR_AMARELO.h
    MOVL R8, 2
    BEQ R3, R8, IB_TEM_COR
    MOVL R7, COR_VERDE.l
    MOVH R7, COR_VERDE.h
    MOVL R8, 3
    BEQ R3, R8, IB_TEM_COR
    MOVL R7, COR_AZUL.l
    MOVH R7, COR_AZUL.h
IB_TEM_COR:
    ; grade[i] = cor  ->  Mem[base + i*4] = R7
    ; endereço efetivo = base + i palavras. Usamos R4 = base + i*4.
    MOVL R5, 4
    MUL R4, R1, R5           ; R4 = i*4 (offset em bytes)
    ADD R4, R6, R4           ; R4 = base + i*4
    STORE R7, R4, 0          ; grade[i] = cor

    INC R1                   ; i++
    JMP IB_LOOP
IB_FIM:
    POP R8
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  ATUALIZA_RAQUETE: lê setas e move a raquete, respeitando as bordas.
; ----------------------------------------------------------------------------
ATUALIZA_RAQUETE:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5

    ; Carrega raq_x atual
    MOVL R4, raq_x.l
    MOVH R4, raq_x.h
    LOAD R1, R4, 0           ; R1 = raq_x

    ; Tecla esquerda?
    MOVL R2, TECLA_ESQ
    GKEY R3, R2              ; R3 = 1 se esquerda pressionada
    BEQ R3, R0, AR_DIR       ; se não, testa direita
    MOVL R5, RAQ_VEL
    SUB R1, R1, R5           ; raq_x -= vel
AR_DIR:
    ; Tecla direita?
    MOVL R2, TECLA_DIR
    GKEY R3, R2
    BEQ R3, R0, AR_LIMITA
    MOVL R5, RAQ_VEL
    ADD R1, R1, R5           ; raq_x += vel
AR_LIMITA:
    ; Limita à esquerda: se raq_x < 0 -> raq_x = 0
    BGE R1, R0, AR_LIM_DIR
    MOVL R1, 0
AR_LIM_DIR:
    ; Limita à direita: se raq_x > (TELA_W - RAQ_W) -> grudа no máximo
    MOVL R5, TELA_W
    MOVL R2, RAQ_W
    SUB R5, R5, R2           ; R5 = 320 - 48 = 272 (X máximo)
    BLE R1, R5, AR_SALVA
    MOVL R1, TELA_W
    MOVL R2, RAQ_W
    SUB R1, R1, R2           ; raq_x = 272
AR_SALVA:
    STORE R1, R4, 0          ; salva raq_x

    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  ATUALIZA_BOLA: move a bola, trata colisões com paredes, raquete e blocos,
;  e a perda de vida quando a bola cai abaixo da tela.
; ----------------------------------------------------------------------------
ATUALIZA_BOLA:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8

    ; Carrega bola_x, bola_y, bola_dx, bola_dy
    MOVL R10, bola_x.l
    MOVH R10, bola_x.h
    LOAD R1, R10, 0          ; R1 = bola_x
    MOVL R11, bola_y.l
    MOVH R11, bola_y.h
    LOAD R2, R11, 0          ; R2 = bola_y
    MOVL R12, bola_dx.l
    MOVH R12, bola_dx.h
    LOAD R3, R12, 0          ; R3 = dx
    MOVL R13, bola_dy.l
    MOVH R13, bola_dy.h
    LOAD R4, R13, 0          ; R4 = dy

    ; --- Move a bola ---
    ADD R1, R1, R3           ; bola_x += dx
    ADD R2, R2, R4           ; bola_y += dy

    ; --- Colisão com parede esquerda (x < 0) ---
    BGE R1, R0, AB_DIR
    MOVL R1, 0
    MOVL R5, 0
    SUB R3, R5, R3           ; dx = -dx
    CALL TOCA_PAREDE
AB_DIR:
    ; --- Colisão com parede direita (x > TELA_W - BOLA_TAM) ---
    MOVL R5, TELA_W
    MOVL R6, BOLA_TAM
    SUB R5, R5, R6           ; R5 = 320 - 5 = 315
    BLE R1, R5, AB_TOPO
    MOVL R1, TELA_W
    MOVL R6, BOLA_TAM
    SUB R1, R1, R6           ; x = 315
    MOVL R5, 0
    SUB R3, R5, R3           ; dx = -dx
    CALL TOCA_PAREDE
AB_TOPO:
    ; --- Colisão com o topo (y < 0) ---
    BGE R2, R0, AB_RAQUETE
    MOVL R2, 0
    MOVL R5, 0
    SUB R4, R5, R4           ; dy = -dy
    CALL TOCA_PAREDE

AB_RAQUETE:
    ; --- Colisão com a raquete ---
    ; A bola colide com a raquete se:
    ;   bola_y + BOLA_TAM >= RAQ_Y          (chegou na altura da raquete)
    ;   bola_y           <= RAQ_Y + RAQ_H   (ainda não passou totalmente)
    ;   bola_x + BOLA_TAM >= raq_x          (sobreposição horizontal)
    ;   bola_x           <= raq_x + RAQ_W
    ; e a bola está descendo (dy > 0).

    ; Só checa se dy > 0 (descendo)
    BLE R4, R0, AB_BLOCOS    ; se dy <= 0, pula raquete

    ; R5 = bola_y + BOLA_TAM
    MOVL R6, BOLA_TAM
    ADD R5, R2, R6
    MOVL R7, RAQ_Y
    BLT R5, R7, AB_BLOCOS    ; se (y+tam) < RAQ_Y, sem colisão vertical

    ; R5 = bola_y, comparar com RAQ_Y + RAQ_H
    MOVL R7, RAQ_Y
    MOVL R8, RAQ_H
    ADD R7, R7, R8           ; R7 = RAQ_Y + RAQ_H
    BGT R2, R7, AB_BLOCOS    ; se y > base da raquete, passou -> sem colisão

    ; Carrega raq_x para teste horizontal
    MOVL R9, raq_x.l
    MOVH R9, raq_x.h
    LOAD R8, R9, 0           ; R8 = raq_x

    ; bola_x + BOLA_TAM >= raq_x ?
    MOVL R6, BOLA_TAM
    ADD R5, R1, R6           ; R5 = bola_x + tam
    BLT R5, R8, AB_BLOCOS    ; se (x+tam) < raq_x, sem sobreposição

    ; bola_x <= raq_x + RAQ_W ?
    MOVL R6, RAQ_W
    ADD R7, R8, R6           ; R7 = raq_x + RAQ_W
    BGT R1, R7, AB_BLOCOS    ; se x > borda direita da raquete, sem colisão

    ; COLIDIU COM A RAQUETE:
    ; - inverte dy (sobe)
    ; - empurra a bola para cima da raquete p/ não "grudar"
    ; - ajusta dx conforme onde bateu (efeito de ângulo)
    MOVL R5, 0
    SUB R4, R5, R4           ; dy = -dy (agora sobe)

    ; reposiciona y logo acima da raquete
    MOVL R7, RAQ_Y
    MOVL R6, BOLA_TAM
    SUB R2, R7, R6           ; bola_y = RAQ_Y - BOLA_TAM

    ; Efeito de ângulo: compara o centro da bola com o centro da raquete.
    ; centro_bola = bola_x + BOLA_TAM/2 ; centro_raq = raq_x + RAQ_W/2
    ; Se bateu à esquerda do centro -> dx tende a negativo; à direita -> positivo.
    MOVL R6, BOLA_TAM
    MOVL R5, 2
    DIV R6, R6, R5           ; R6 = BOLA_TAM/2
    ADD R5, R1, R6           ; R5 = centro da bola

    MOVL R6, RAQ_W
    MOVL R7, 2
    DIV R6, R6, R7           ; R6 = RAQ_W/2
    ADD R6, R8, R6           ; R6 = centro da raquete

    ; Carrega magnitude base de velocidade
    MOVL R9, vel_base.l
    MOVH R9, vel_base.h
    LOAD R7, R9, 0           ; R7 = vel_base

    BLT R5, R6, AB_RAQ_ESQ   ; centro_bola < centro_raq -> bateu na esquerda
    ; bateu na direita (ou centro) -> dx = +vel_base
    ADD R3, R0, R7           ; dx = vel_base
    JMP AB_RAQ_SOM
AB_RAQ_ESQ:
    ; dx = -vel_base
    MOVL R6, 0
    SUB R3, R6, R7           ; dx = -vel_base
AB_RAQ_SOM:
    CALL TOCA_RAQUETE

AB_BLOCOS:
    ; --- Colisão com blocos ---
    ; Salva o estado atual da bola na memória antes de chamar COLIDE_BLOCOS,
    ; que lê a posição da bola e pode inverter dy.
    ; ATENÇÃO: COLIDE_BLOCOS e PERDE_VIDA usam R10-R13 como scratch e NÃO os
    ; preservam, então NÃO confiamos que R10-R13 sobrevivam ao CALL. Por isso,
    ; após cada CALL recarregamos os endereços-base com MOVL/MOVH.
    STORE R1, R10, 0         ; bola_x
    STORE R2, R11, 0         ; bola_y
    STORE R3, R12, 0         ; dx
    STORE R4, R13, 0         ; dy
    CALL COLIDE_BLOCOS

    ; Recarrega TODO o estado da bola a partir da memória (R10-R13 foram
    ; possivelmente destruídos pela sub-rotina).
    MOVL R10, bola_x.l
    MOVH R10, bola_x.h
    LOAD R1, R10, 0          ; R1 = bola_x
    MOVL R11, bola_y.l
    MOVH R11, bola_y.h
    LOAD R2, R11, 0          ; R2 = bola_y
    MOVL R12, bola_dx.l
    MOVH R12, bola_dx.h
    LOAD R3, R12, 0          ; R3 = dx
    MOVL R13, bola_dy.l
    MOVH R13, bola_dy.h
    LOAD R4, R13, 0          ; R4 = dy

    ; --- Bola caiu? (y > TELA_H) -> perde vida ---
    MOVL R5, TELA_H
    BLE R2, R5, AB_FIM       ; se y <= 240, ok
    ; PERDE_VIDA reseta a bola na memória; só precisamos chamar e depois sair.
    CALL PERDE_VIDA
    ; após PERDE_VIDA, a posição/velocidade da bola na MEMÓRIA já foi
    ; redefinida (reset). Não devemos sobrescrevê-la com R1-R4 antigos.
    ; Por isso pulamos os STOREs finais.
    JMP AB_RET

AB_FIM:
    ; Salva o estado final da bola (caso não tenha perdido vida)
    STORE R1, R10, 0
    STORE R2, R11, 0
    STORE R3, R12, 0
    STORE R4, R13, 0

AB_RET:
    POP R8
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  COLIDE_BLOCOS: percorre a grade; se a bola sobrepõe um bloco vivo,
;  destrói o bloco, soma pontos, inverte dy e toca som.
;  Trata no máximo 1 bloco por frame (suficiente p/ a velocidade do jogo).
;
;  Posição de cada bloco i:
;    coluna = i % NUM_COLS ; fileira = i / NUM_COLS
;    bx = GRADE_X + coluna * (BLOCO_W + BLOCO_GAP)
;    by = GRADE_Y + fileira * (BLOCO_H + BLOCO_GAP)
; ----------------------------------------------------------------------------
COLIDE_BLOCOS:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8
    PUSH R9

    ; Carrega bola_x, bola_y (não precisamos de dx aqui)
    MOVL R10, bola_x.l
    MOVH R10, bola_x.h
    LOAD R1, R10, 0          ; R1 = bola_x
    MOVL R11, bola_y.l
    MOVH R11, bola_y.h
    LOAD R2, R11, 0          ; R2 = bola_y

    MOVL R12, grade.l
    MOVH R12, grade.h        ; R12 = base da grade

    MOVL R3, 0               ; R3 = índice i
    MOVL R9, NUM_BLOCOS
CB_LOOP:
    BGE R3, R9, CB_FIM       ; i >= 40 -> fim

    ; Carrega grade[i]
    MOVL R5, 4
    MUL R4, R3, R5           ; R4 = i*4
    ADD R4, R12, R4          ; R4 = endereço de grade[i]
    LOAD R5, R4, 0           ; R5 = cor do bloco (0 = destruído)
    BEQ R5, R0, CB_NEXT      ; bloco morto -> próximo

    ; Calcula posição do bloco i
    ; coluna = i % NUM_COLS
    MOVL R7, NUM_COLS
    MOD R6, R3, R7           ; R6 = coluna
    ; fileira = i / NUM_COLS
    DIV R7, R3, R7           ; R7 = fileira

    ; bx = GRADE_X + coluna*(BLOCO_W+BLOCO_GAP)
    MOVL R8, BLOCO_W
    MOVL R13, BLOCO_GAP
    ADD R8, R8, R13          ; R8 = BLOCO_W + GAP (passo horizontal)
    MUL R6, R6, R8           ; R6 = coluna * passo
    MOVL R8, GRADE_X
    ADD R6, R6, R8           ; R6 = bx  (canto esquerdo do bloco)

    ; by = GRADE_Y + fileira*(BLOCO_H+BLOCO_GAP)
    MOVL R8, BLOCO_H
    MOVL R13, BLOCO_GAP
    ADD R8, R8, R13          ; R8 = BLOCO_H + GAP (passo vertical)
    MUL R7, R7, R8           ; R7 = fileira * passo
    MOVL R8, GRADE_Y
    ADD R7, R7, R8           ; R7 = by (canto superior do bloco)

    ; Teste de sobreposição AABB entre a bola e o bloco i:
    ;   bola_x + BOLA_TAM >= bx       (R1+tam >= R6)
    ;   bola_x            <= bx + BLOCO_W
    ;   bola_y + BOLA_TAM >= by
    ;   bola_y            <= by + BLOCO_H

    ; bola_x + BOLA_TAM >= bx ?
    MOVL R8, BOLA_TAM
    ADD R8, R1, R8           ; R8 = bola_x + tam
    BLT R8, R6, CB_NEXT      ; (x+tam) < bx -> sem colisão

    ; bola_x <= bx + BLOCO_W ?
    MOVL R8, BLOCO_W
    ADD R8, R6, R8           ; R8 = bx + BLOCO_W
    BGT R1, R8, CB_NEXT      ; x > borda direita -> sem colisão

    ; bola_y + BOLA_TAM >= by ?
    MOVL R8, BOLA_TAM
    ADD R8, R2, R8           ; R8 = bola_y + tam
    BLT R8, R7, CB_NEXT      ; (y+tam) < by -> sem colisão

    ; bola_y <= by + BLOCO_H ?
    MOVL R8, BLOCO_H
    ADD R8, R7, R8           ; R8 = by + BLOCO_H
    BGT R2, R8, CB_NEXT      ; y > borda inferior -> sem colisão

    ; ---- COLIDIU com o bloco i ----
    ; 1) destrói: grade[i] = 0
    STORE R0, R4, 0

    ; 2) decrementa blocos_vivos
    MOVL R8, blocos_vivos.l
    MOVH R8, blocos_vivos.h
    LOAD R13, R8, 0
    DEC R13
    STORE R13, R8, 0

    ; 3) soma pontos conforme a fileira (R7 ainda? não: R7 foi sobrescrito).
    ;    Recalcula a fileira a partir de i.
    MOVL R8, NUM_COLS
    DIV R7, R3, R8           ; R7 = fileira
    CALL PONTOS_DA_FILEIRA   ; entrada: R7=fileira ; saída: R8=pontos
    ; placar += R8
    MOVL R13, placar.l
    MOVH R13, placar.h
    LOAD R6, R13, 0          ; R6 = placar
    ADD R6, R6, R8           ; placar += pontos
    STORE R6, R13, 0

    ; 4) inverte dy da bola (rebate verticalmente)
    MOVL R13, bola_dy.l
    MOVH R13, bola_dy.h
    LOAD R8, R13, 0
    MOVL R6, 0
    SUB R8, R6, R8           ; dy = -dy
    STORE R8, R13, 0

    ; 5) toca som de bloco
    CALL TOCA_BLOCO

    ; 6) atualiza velocidade conforme o placar (aceleração clássica)
    CALL ATUALIZA_VELOCIDADE

    ; Trata só 1 bloco por frame -> encerra o laço
    JMP CB_FIM

CB_NEXT:
    INC R3                   ; i++
    JMP CB_LOOP
CB_FIM:
    POP R9
    POP R8
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  PONTOS_DA_FILEIRA: entrada R7 = fileira (0..4) ; saída R8 = pontos.
; ----------------------------------------------------------------------------
PONTOS_DA_FILEIRA:
    PUSH R1
    MOVL R8, PTS_F0          ; assume fileira 0
    MOVL R1, 0
    BEQ R7, R1, PF_FIM
    MOVL R8, PTS_F1
    MOVL R1, 1
    BEQ R7, R1, PF_FIM
    MOVL R8, PTS_F2
    MOVL R1, 2
    BEQ R7, R1, PF_FIM
    MOVL R8, PTS_F3
    MOVL R1, 3
    BEQ R7, R1, PF_FIM
    MOVL R8, PTS_F4          ; fileira 4
PF_FIM:
    POP R1
    RET

; ----------------------------------------------------------------------------
;  ATUALIZA_VELOCIDADE: vel_base = min(2 + placar/MARCO_VEL, VEL_MAX).
;  Reaplica o sinal de dx/dy preservando a direção atual.
; ----------------------------------------------------------------------------
ATUALIZA_VELOCIDADE:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5

    ; calcula nova vel_base
    MOVL R1, placar.l
    MOVH R1, placar.h
    LOAD R2, R1, 0           ; R2 = placar
    MOVL R3, MARCO_VEL
    DIV R2, R2, R3           ; R2 = placar / 50
    MOVL R3, 2
    ADD R2, R2, R3           ; R2 = 2 + placar/50
    ; limita em VEL_MAX
    MOVL R3, VEL_MAX
    BLE R2, R3, AV_OK
    MOVL R2, VEL_MAX
AV_OK:
    ; salva vel_base
    MOVL R1, vel_base.l
    MOVH R1, vel_base.h
    STORE R2, R1, 0

    ; Reaplica magnitude a dx preservando o sinal.
    MOVL R1, bola_dx.l
    MOVH R1, bola_dx.h
    LOAD R3, R1, 0           ; R3 = dx atual
    BGE R3, R0, AV_DX_POS
    ; dx negativo -> dx = -vel_base
    MOVL R4, 0
    SUB R3, R4, R2
    JMP AV_DX_SALVA
AV_DX_POS:
    ADD R3, R0, R2           ; dx = +vel_base
AV_DX_SALVA:
    STORE R3, R1, 0

    ; Reaplica magnitude a dy preservando o sinal.
    MOVL R1, bola_dy.l
    MOVH R1, bola_dy.h
    LOAD R3, R1, 0           ; R3 = dy atual
    BGE R3, R0, AV_DY_POS
    MOVL R4, 0
    SUB R3, R4, R2
    JMP AV_DY_SALVA
AV_DY_POS:
    ADD R3, R0, R2
AV_DY_SALVA:
    STORE R3, R1, 0

    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  PERDE_VIDA: decrementa vidas, reseta a bola no centro. Se vidas<=0,
;  estado = 1 (game over).
; ----------------------------------------------------------------------------
PERDE_VIDA:
    PUSH R1
    PUSH R2
    PUSH R3

    CALL TOCA_PERDE

    ; vidas--
    MOVL R1, vidas.l
    MOVH R1, vidas.h
    LOAD R2, R1, 0           ; R2 = vidas
    DEC R2
    STORE R2, R1, 0

    ; vidas <= 0 ?
    BGT R2, R0, PV_RESET
    ; game over: estado = 1
    MOVL R3, 1
    MOVL R1, estado.l
    MOVH R1, estado.h
    STORE R3, R1, 0
    JMP PV_FIM

PV_RESET:
    ; reseta a bola para o centro, descendo
    MOVL R3, 158
    MOVL R1, bola_x.l
    MOVH R1, bola_x.h
    STORE R3, R1, 0

    MOVL R3, 150
    MOVL R1, bola_y.l
    MOVH R1, bola_y.h
    STORE R3, R1, 0

    ; dx = +vel_base, dy = -vel_base (sobe ao reiniciar)
    MOVL R1, vel_base.l
    MOVH R1, vel_base.h
    LOAD R2, R1, 0           ; R2 = vel_base

    MOVL R1, bola_dx.l
    MOVH R1, bola_dx.h
    STORE R2, R1, 0          ; dx = +vel_base

    MOVL R3, 0
    SUB R3, R3, R2           ; R3 = -vel_base
    MOVL R1, bola_dy.l
    MOVH R1, bola_dy.h
    STORE R3, R1, 0          ; dy = -vel_base

PV_FIM:
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  DESENHA_TUDO: limpa a tela e redesenha blocos, raquete, bola e HUD.
; ----------------------------------------------------------------------------
DESENHA_TUDO:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5

    ; --- Limpa a tela com a cor de fundo ---
    MOVL R1, COR_FUNDO.l
    MOVH R1, COR_FUNDO.h
    CLEAR R1

    ; --- Desenha os blocos ---
    CALL DESENHA_BLOCOS

    ; --- Desenha a raquete ---
    MOVL R5, raq_x.l
    MOVH R5, raq_x.h
    LOAD R1, R5, 0           ; x = raq_x
    MOVL R2, RAQ_Y           ; y
    MOVL R3, RAQ_W           ; w
    MOVL R4, RAQ_H           ; h
    MOVL R5, COR_RAQUETE.l
    MOVH R5, COR_RAQUETE.h   ; cor
    RECT R1, R2, R3, R4, R5

    ; --- Desenha a bola ---
    MOVL R5, bola_x.l
    MOVH R5, bola_x.h
    LOAD R1, R5, 0           ; x = bola_x
    MOVL R5, bola_y.l
    MOVH R5, bola_y.h
    LOAD R2, R5, 0           ; y = bola_y
    MOVL R3, BOLA_TAM        ; w
    MOVL R4, BOLA_TAM        ; h
    MOVL R5, COR_BOLA.l
    MOVH R5, COR_BOLA.h      ; cor
    RECT R1, R2, R3, R4, R5

    ; --- HUD: placar e vidas ---
    CALL DESENHA_HUD

    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  DESENHA_BLOCOS: percorre a grade e desenha um RECT por bloco vivo.
; ----------------------------------------------------------------------------
DESENHA_BLOCOS:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8
    PUSH R9

    MOVL R12, grade.l
    MOVH R12, grade.h        ; base da grade

    MOVL R3, 0               ; i = 0
    MOVL R9, NUM_BLOCOS
DB_LOOP:
    BGE R3, R9, DB_FIM

    ; cor = grade[i]
    MOVL R5, 4
    MUL R4, R3, R5
    ADD R4, R12, R4          ; endereço de grade[i]
    LOAD R5, R4, 0           ; R5 = cor
    BEQ R5, R0, DB_NEXT      ; bloco morto -> não desenha

    ; coluna = i % NUM_COLS ; fileira = i / NUM_COLS
    MOVL R7, NUM_COLS
    MOD R6, R3, R7           ; R6 = coluna
    MOVL R7, NUM_COLS
    DIV R7, R3, R7           ; R7 = fileira

    ; bx = GRADE_X + coluna*(BLOCO_W+GAP)
    MOVL R8, BLOCO_W
    MOVL R13, BLOCO_GAP
    ADD R8, R8, R13
    MUL R6, R6, R8
    MOVL R8, GRADE_X
    ADD R1, R6, R8           ; R1 = bx (x do RECT)

    ; by = GRADE_Y + fileira*(BLOCO_H+GAP)
    MOVL R8, BLOCO_H
    MOVL R13, BLOCO_GAP
    ADD R8, R8, R13
    MUL R7, R7, R8
    MOVL R8, GRADE_Y
    ADD R2, R7, R8           ; R2 = by (y do RECT)

    ; desenha o bloco: x=R1, y=R2, w=BLOCO_W, h=BLOCO_H, cor=R5
    MOVL R8, BLOCO_W         ; w
    MOVL R13, BLOCO_H        ; h
    RECT R1, R2, R8, R13, R5

DB_NEXT:
    INC R3
    JMP DB_LOOP
DB_FIM:
    POP R9
    POP R8
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  DESENHA_HUD: imprime "PONTOS:" + placar e "VIDAS:" + vidas no topo.
; ----------------------------------------------------------------------------
DESENHA_HUD:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4

    ; "PONTOS:" em (4, 4)
    MOVL R1, 4
    MOVL R2, 4
    MOVL R3, msg_pts.l
    MOVH R3, msg_pts.h
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PSTR R1, R2, R3, R4

    ; valor do placar em (130, 4)
    MOVL R1, 130
    MOVL R2, 4
    MOVL R5, placar.l
    MOVH R5, placar.h
    LOAD R3, R5, 0           ; R3 = placar
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PINT R1, R2, R3, R4

    ; "VIDAS:" em (4, 14)... mantemos no topo direito
    MOVL R1, 210
    MOVL R2, 4
    MOVL R3, msg_vidas.l
    MOVH R3, msg_vidas.h
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PSTR R1, R2, R3, R4

    ; valor das vidas em (290, 4)
    MOVL R1, 290
    MOVL R2, 4
    MOVL R5, vidas.l
    MOVH R5, vidas.h
    LOAD R3, R5, 0
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PINT R1, R2, R3, R4

    POP R4
    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  FIM_DE_JOGO: tela final. Mostra mensagem conforme estado (1=GO, 2=win)
;  e espera ENTER para reiniciar.
; ----------------------------------------------------------------------------
FIM_DE_JOGO:
    ; limpa a tela
    MOVL R1, COR_FUNDO.l
    MOVH R1, COR_FUNDO.h
    CLEAR R1

    ; escolhe a mensagem conforme o estado
    MOVL R1, estado.l
    MOVH R1, estado.h
    LOAD R2, R1, 0           ; R2 = estado
    MOVL R3, 2
    BEQ R2, R3, FJ_WIN

    ; GAME OVER
    MOVL R3, msg_go.l
    MOVH R3, msg_go.h
    JMP FJ_DESENHA
FJ_WIN:
    MOVL R3, msg_win.l
    MOVH R3, msg_win.h
FJ_DESENHA:
    MOVL R1, 120
    MOVL R2, 110
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PSTR R1, R2, R3, R4

    ; também mostra o placar final
    MOVL R1, 120
    MOVL R2, 140
    MOVL R5, placar.l
    MOVH R5, placar.h
    LOAD R3, R5, 0
    MOVL R4, COR_TEXTO.l
    MOVH R4, COR_TEXTO.h
    PINT R1, R2, R3, R4

    MOVL R1, 16
    SLEEP R1

    ; espera ENTER para reiniciar
    MOVL R2, TECLA_ENTER
    GKEY R1, R2
    BEQ R1, R0, FIM_DE_JOGO  ; sem ENTER -> continua na tela final

    ; ENTER pressionado -> reinicia o jogo
    CALL RESET_JOGO
    JMP GAME_LOOP

; ----------------------------------------------------------------------------
;  RESET_JOGO: restaura todas as variáveis ao estado inicial.
; ----------------------------------------------------------------------------
RESET_JOGO:
    PUSH R1
    PUSH R2
    PUSH R3

    MOVL R2, 158
    MOVL R1, bola_x.l
    MOVH R1, bola_x.h
    STORE R2, R1, 0

    MOVL R2, 150
    MOVL R1, bola_y.l
    MOVH R1, bola_y.h
    STORE R2, R1, 0

    MOVL R2, 2
    MOVL R1, bola_dx.l
    MOVH R1, bola_dx.h
    STORE R2, R1, 0

    MOVL R2, 0
    MOVL R3, 2
    SUB R2, R2, R3           ; -2
    MOVL R1, bola_dy.l
    MOVH R1, bola_dy.h
    STORE R2, R1, 0

    MOVL R2, 136
    MOVL R1, raq_x.l
    MOVH R1, raq_x.h
    STORE R2, R1, 0

    MOVL R2, VIDAS_INI
    MOVL R1, vidas.l
    MOVH R1, vidas.h
    STORE R2, R1, 0

    MOVL R2, 0
    MOVL R1, placar.l
    MOVH R1, placar.h
    STORE R2, R1, 0

    MOVL R2, NUM_BLOCOS
    MOVL R1, blocos_vivos.l
    MOVH R1, blocos_vivos.h
    STORE R2, R1, 0

    MOVL R2, 0
    MOVL R1, estado.l
    MOVH R1, estado.h
    STORE R2, R1, 0

    MOVL R2, 2
    MOVL R1, vel_base.l
    MOVH R1, vel_base.h
    STORE R2, R1, 0

    CALL INIT_BLOCOS

    POP R3
    POP R2
    POP R1
    RET

; ----------------------------------------------------------------------------
;  SONS: rotininhas curtas (PLAY é não-bloqueante)
; ----------------------------------------------------------------------------
TOCA_PAREDE:
    PUSH R1
    PUSH R2
    PUSH R3
    MOVL R1, SOM_PAREDE
    MOVL R2, SOM_DUR
    MOVL R3, ONDA_QUAD
    PLAY R1, R2, R3
    POP R3
    POP R2
    POP R1
    RET

TOCA_RAQUETE:
    PUSH R1
    PUSH R2
    PUSH R3
    MOVL R1, SOM_RAQUETE
    MOVL R2, SOM_DUR
    MOVL R3, ONDA_QUAD
    PLAY R1, R2, R3
    POP R3
    POP R2
    POP R1
    RET

TOCA_BLOCO:
    PUSH R1
    PUSH R2
    PUSH R3
    MOVL R1, SOM_BLOCO
    MOVL R2, SOM_DUR
    MOVL R3, ONDA_QUAD
    PLAY R1, R2, R3
    POP R3
    POP R2
    POP R1
    RET

TOCA_PERDE:
    PUSH R1
    PUSH R2
    PUSH R3
    MOVL R1, SOM_PERDE
    MOVL R2, SOM_DUR
    MOVL R3, ONDA_QUAD
    PLAY R1, R2, R3
    POP R3
    POP R2
    POP R1
    RET
