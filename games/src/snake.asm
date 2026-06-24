; =============================================================================
; JOGO SNAKE (A COBRINHA) PARA A ARQUITETURA FANTASYS32
; Grade Virtual: 40 colunas (0-39) x 30 linhas (0-29). Blocos de 8x8 pixels.
; =============================================================================

.data

; --- Constantes do Sistema (.equ) ---
.equ COR_PRETO,     0xFF000000  ; Fundo (Opaco) [cite: 121, 124]
.equ COR_VERDE,     0xFF00FF00  ; Cobra (Opaco) [cite: 121, 124]
.equ COR_VERMELHO,  0xFFFF0000  ; Maçã (Opaco) [cite: 34, 121]
.equ COR_BRANCO,    0xFFFFFFFF  ; Texto (Opaco) [cite: 121, 124]

.equ TECLA_ESQ,     0x00        ; Seta Esquerda [cite: 145]
.equ TECLA_DIR,     0x01        ; Seta Direita [cite: 145]
.equ TECLA_CIMA,    0x02        ; Seta Cima [cite: 145]
.equ TECLA_BAIXO,   0x03        ; Seta Baixo [cite: 145]
.equ TECLA_ENTER,   0x05        ; Tecla Enter [cite: 145]

.equ LARGURA_GRA,   40          ; Largura da grade virtual (320 / 8) [cite: 14, 16]
.equ ALTURA_GRA,    30          ; Altura da grade virtual (240 / 8) [cite: 14, 16]
.equ TAM_BLOCO,     8           ; Tamanho de cada bloco em pixels [cite: 16]
.equ MAX_CORPO,     128         ; Limite do Buffer Circular (Potência de 2)
.equ MASCARA_CIRC,  127         ; Máscara bit-a-bit para o Buffer Circular (128 - 1)

; --- Variáveis Globais (Alinhadas em Palavras de 4 Bytes) ---
DIRECAO:        .word 1         ; 0=Esq, 1=Dir, 2=Cima, 3=Baixo
MACA_X:         .word 15        ; Posição X inicial da maçã
MACA_Y:         .word 15        ; Posição Y inicial da maçã
COBRA_TAM:      .word 3         ; Tamanho atual da cobra
NEXT_TICK:      .word 0         ; Frame em que ocorrerá o próximo passo lógico
TAIL_PTR:       .word 0         ; Índice da cauda no buffer circular
HEAD_PTR:       .word 2         ; Índice da cabeça no buffer circular

; --- Arrays do Corpo (128 elementos de 4 bytes cada = 512 bytes) ---
COBRA_X:        .zero 512       ; Armazena coordenadas X do corpo
COBRA_Y:        .zero 512       ; Armazena coordenadas Y do corpo

; --- Strings de Texto ---
MSG_GAMEOVER:   .string "GAME OVER! Pressione ENTER para reiniciar."

; =============================================================================
.text
START:
    ; --- Inicialização do Estado Inicial do Jogo ---
    ; Configura Semente Aleatória baseada no relógio inicial da VM
    FRAMENUM R1                 ; R1 = número de frames 
    SRAND R1                    ; Inicializa o LCG [cite: 120, 147]

REINICIAR_JOGO:
    ; Configura Direção Inicial = Direita (1)
    MOVL R1, DIRECAO.l          ; [cite: 181]
    MOVH R1, DIRECAO.h          ; [cite: 181]
    MOVL R2, 1                  ; 1 = Direita
    STORE R2, R1, 0             ; Salva DIRECAO [cite: 84]

    ; Configura Tamanho Inicial = 3
    MOVL R1, COBRA_TAM.l
    MOVH R1, COBRA_TAM.h
    MOVL R2, 3
    STORE R2, R1, 0             ; Salva COBRA_TAM [cite: 84]

    ; Configura Ponteiros do Buffer Circular (Tail=0, Head=2)
    MOVL R1, TAIL_PTR.l
    MOVH R1, TAIL_PTR.h
    MOVL R2, 0
    STORE R2, R1, 0             ; TAIL_PTR = 0

    MOVL R1, HEAD_PTR.l
    MOVH R1, HEAD_PTR.h
    MOVL R2, 2
    STORE R2, R1, 0             ; HEAD_PTR = 2

    ; Coordenadas Iniciais do Corpo (Segmentos horizontais no centro da tela)
    ; Cauda (Índice 0): X=10, Y=15
    ; Meio  (Índice 1): X=11, Y=15
    ; Cabeça(Índice 2): X=12, Y=15
    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    MOVL R2, 10
    STORE R2, R1, 0             ; COBRA_X[0] = 10
    MOVL R2, 11
    STORE R2, R1, 1             ; COBRA_X[1] = 11 (Deslocamento imediato 1 * 4 bytes interno) [cite: 90]
    MOVL R2, 12
    STORE R2, R1, 2             ; COBRA_X[2] = 12

    MOVL R1, COBRA_Y.l
    MOVH R1, COBRA_Y.h
    MOVL R2, 15
    STORE R2, R1, 0             ; COBRA_Y[0] = 15
    STORE R2, R1, 1             ; COBRA_Y[1] = 15
    STORE R2, R1, 2             ; COBRA_Y[2] = 15

    ; Coloca a primeira Maçã na posição (25, 15)
    MOVL R1, MACA_X.l
    MOVH R1, MACA_X.h
    MOVL R2, 25
    STORE R2, R1, 0             ; MACA_X = 25

    MOVL R1, MACA_Y.l
    MOVH R1, MACA_Y.h
    MOVL R2, 15
    STORE R2, R1, 0             ; MACA_Y = 15

    ; Inicializa o controle do tempo (Next Tick = Frame Atual + 6)
    FRAMENUM R1
    ADDI R1, R1, 6
    MOVL R2, NEXT_TICK.l
    MOVH R2, NEXT_TICK.h
    STORE R1, R2, 0

; -----------------------------------------------------------------------------
; LOOP PRINCIPAL DO JOGO (Executado continuamente a 60 FPS)
; -----------------------------------------------------------------------------
LOOP_PRINCIPAL:
    ; --- CAPTURA DE ENTRADAS (As sinaleiras não bloqueiam a execução) ---
    MOVL R1, DIRECAO.l
    MOVH R1, DIRECAO.h
    LOAD R2, R1, 0              ; R2 = Direção Atual [cite: 84]

    ; Testa Seta Esquerda
    MOVL R3, TECLA_ESQ
    GKEY R4, R3                 ; R4 = 1 se pressionada, 0 se não [cite: 119, 144]
    BEQ R4, R0, TESTA_DIR       ; Se não pressionada, testa próxima 
    MOVL R5, 1                  ; Evita virar para a esquerda se estiver indo para a direita
    BEQ R2, R5, TESTA_DIR
    MOVL R2, 0                  ; Nova direção = Esquerda
    STORE R2, R1, 0             ; Atualiza
    JMP VERIFICAR_TEMPO         ; Desvia para economizar instruções

TESTA_DIR:
    MOVL R3, TECLA_DIR
    GKEY R4, R3
    BEQ R4, R0, TESTA_CIMA
    MOVL R5, 0                  ; Evita virar para a direita se estiver indo para a esquerda
    BEQ R2, R5, TESTA_CIMA
    MOVL R2, 1                  ; Nova direção = Direita
    STORE R2, R1, 0
    JMP VERIFICAR_TEMPO

TESTA_CIMA:
    MOVL R3, TECLA_CIMA
    GKEY R4, R3
    BEQ R4, R0, TESTA_BAIXO
    MOVL R5, 3                  ; Evita virar para cima se estiver indo para baixo
    BEQ R2, R5, TESTA_BAIXO
    MOVL R2, 2                  ; Nova direção = Cima
    STORE R2, R1, 0
    JMP VERIFICAR_TEMPO

TESTA_BAIXO:
    MOVL R3, TECLA_BAIXO
    GKEY R4, R3
    BEQ R4, R0, VERIFICAR_TEMPO
    MOVL R5, 2                  ; Evita virar para baixo se estiver indo para cima
    BEQ R2, R5, VERIFICAR_TEMPO
    MOVL R2, 3                  ; Nova direção = Baixo
    STORE R2, R1, 0

VERIFICAR_TEMPO:
    ; --- CONTROLE DO PASSO LÓGICO (TICK) ---
    FRAMENUM R1                 ; R1 = Frame Atual
    MOVL R2, NEXT_TICK.l
    MOVH R2, NEXT_TICK.h
    LOAD R3, R2, 0              ; R3 = Frame Alvo

    BLT R1, R3, RENDERIZAR      ; Se frame atual < alvo, pula atualização física 

    ; Atualiza o alvo temporal (Frame Atual + 6 frames de espera)
    ADDI R3, R1, 6              ; Velocidade da cobra (~10 passos por segundo) [cite: 77]
    STORE R3, R2, 0             ; Salva novo alvo

    ; Executa a física do jogo
    CALL ATUALIZAR_LOGICA       ; Salta para a rotina de movimentação/colisões [cite: 95]

RENDERIZAR:
    CALL ROTINA_RENDER          ; Redesenha os elementos na tela [cite: 95]
    JMP LOOP_PRINCIPAL          ; Fecha o ciclo infinito [cite: 95]

; -----------------------------------------------------------------------------
; SUB-ROTINA: ATUALIZAR_LOGICA
; -----------------------------------------------------------------------------
ATUALIZAR_LOGICA:
    ; Carrega Ponteiro da Cabeça Atual
    MOVL R1, HEAD_PTR.l
    MOVH R1, HEAD_PTR.h
    LOAD R2, R1, 0              ; R2 = Índice atual do Head (ex: 2)

    ; Busca coordenadas (X, Y) da cabeça atual
    MOVL R3, COBRA_X.l
    MOVH R3, COBRA_X.h
    SHL R12, R2, 2              ; R12 = Índice * 4 (Cálculo manual de offset de bytes) 
    ADD R3, R3, R12             ; R3 = Endereço absoluto de COBRA_X[Head] 
    LOAD R4, R3, 0              ; R4 = X Atual da Cabeça

    MOVL R5, COBRA_Y.l
    MOVH R5, COBRA_Y.h
    ADD R5, R5, R12             ; R5 = Endereço absoluto de COBRA_Y[Head]
    LOAD R6, R5, 0              ; R6 = Y Atual da Cabeça

    ; Carrega Direção para calcular o deslocamento
    MOVL R7, DIRECAO.l
    MOVH R7, DIRECAO.h
    LOAD R8, R7, 0              ; R8 = Código da direção

    ; Desvios de Direção
    MOVL R9, 0
    BEQ R8, R9, MOVER_ESQ
    MOVL R9, 1
    BEQ R8, R9, MOVER_DIR
    MOVL R9, 2
    BEQ R8, R9, MOVER_CIMA
    MOVL R9, 3
    BEQ R8, R9, MOVER_BAIXO
    JMP CALCULO_FIM

MOVER_ESQ:
    DEC R4                      ; X = X - 1 [cite: 111]
    JMP CALCULO_FIM
MOVER_DIR:
    INC R4                      ; X = X + 1 [cite: 111]
    JMP CALCULO_FIM
MOVER_CIMA:
    DEC R6                      ; Y = Y - 1
    JMP CALCULO_FIM
MOVER_BAIXO:
    INC R6                      ; Y = Y + 1

CALCULO_FIM:
    ; --- VERIFICAÇÃO DE COLISÃO COM AS BORDAS ---
    BLT R4, R0, TELA_GAMEOVER   ; Se X < 0 -> Game Over
    MOVL R10, LARGURA_GRA
    BGE R4, R10, TELA_GAMEOVER  ; Se X >= 40 -> Game Over
    BLT R6, R0, TELA_GAMEOVER   ; Se Y < 0 -> Game Over
    MOVL R10, ALTURA_GRA
    BGE R6, R10, TELA_GAMEOVER  ; Se Y >= 30 -> Game Over

    ; --- VERIFICAÇÃO DE AUTO-COLISÃO (CORPO) ---
    MOVL R7, TAIL_PTR.l
    MOVH R7, TAIL_PTR.h
    LOAD R10, R7, 0             ; R10 = Índice iterador (começa no Tail)
    MOVL R11, MASCARA_CIRC      ; Máscara de limite circular (127)

LOOP_COLISAO_CORPO:
    BEQ R10, R2, FIM_CHECAGEM   ; Se alcançou a cabeça antiga, terminou a varredura sem colisão

    ; Carrega X e Y do segmento [R10] para comparar com o novo (R4, R6)
    MOVL R7, COBRA_X.l
    MOVH R7, COBRA_X.h
    SHL R12, R10, 2             ; R12 = Iterador * 4
    ADD R7, R7, R12
    LOAD R13, R7, 0             ; R13 = COBRA_X[R10]

    MOVL R9, COBRA_Y.l
    MOVH R9, COBRA_Y.h
    ADD R9, R9, R12
    LOAD R14, R9, 0             ; R14 = COBRA_Y[R10]

    BNE R4, R13, PROXIMO_SEG    ; Se X não colide, pula
    BEQ R6, R14, TELA_GAMEOVER  ; Se X colide E Y colide -> Game Over

PROXIMO_SEG:
    INC R10
    AND R10, R10, R11           ; Aplica comportamento circular no índice (R10 = (R10 + 1) & 127)
    JMP LOOP_COLISAO_CORPO

FIM_CHECAGEM:
    ; --- INSERÇÃO DA NOVA CABEÇA NO BUFFER ---
    INC R2                      ; Avança o ponteiro da cabeça
    MOVL R11, MASCARA_CIRC
    AND R2, R2, R11             ; Ajuste circular
    MOVL R1, HEAD_PTR.l
    MOVH R1, HEAD_PTR.h
    STORE R2, R1, 0             ; Atualiza HEAD_PTR na memória

    ; Escreve a nova coordenada na tabela indexada
    MOVL R3, COBRA_X.l
    MOVH R3, COBRA_X.h
    SHL R12, R2, 2              ; Índice * 4
    ADD R3, R3, R12
    STORE R4, R3, 0             ; Salva novo X na tabela

    MOVL R5, COBRA_Y.l
    MOVH R5, COBRA_Y.h
    ADD R5, R5, R12
    STORE R6, R5, 0             ; Salva novo Y na tabela

    ; --- VERIFICAÇÃO DE COLISÃO COM A MAÇÃ ---
    MOVL R7, MACA_X.l
    MOVH R7, MACA_X.h
    LOAD R8, R7, 0              ; R8 = MACA_X

    MOVL R9, MACA_Y.l
    MOVH R9, MACA_Y.h
    LOAD R10, R9, 0             ; R10 = MACA_Y

    BNE R4, R8, REMOVE_CAUDA    ; Se X_Cabeça != MACA_X, cobra não comeu
    BNE R6, R10, REMOVE_CAUDA   ; Se Y_Cabeça != MACA_Y, cobra não comeu

    ; --- CASO: COMEU A MAÇÃ ---
    ; 1. Toca Efeito Sonoro (Som Quadrado de 523Hz por 80ms)
    MOVL R1, 523                ; Nota Dó5 (Frequência em Hz) [cite: 119]
    MOVL R2, 80                 ; Duração de 80ms [cite: 119]
    MOVL R3, 1                  ; 1 = Onda Quadrada [cite: 119, 144]
    PLAY R1, R2, R3             ; Emite som assíncrono [cite: 119]

    ; 2. Incrementa Tamanho
    MOVL R1, COBRA_TAM.l
    MOVH R1, COBRA_TAM.h
    LOAD R2, R1, 0
    INC R2
    STORE R2, R1, 0

    ; 3. Gera Nova Maçã Aleatória via LCG NATIVO
    MOVL R11, 0                 ; Limite Mínimo
    MOVL R12, 39                ; Limite Máximo X
    RAND R8, R11, R12           ; R8 = Novo X Aleatório [cite: 120, 148]
    STORE R8, R7, 0             ; Salva novo MACA_X

    MOVL R12, 29                ; Limite Máximo Y
    RAND R10, R11, R12          ; R10 = Novo Y Aleatório
    STORE R10, R9, 0            ; Salva novo MACA_Y

    RET                         ; Retorna sem apagar a cauda (Cobra cresce) [cite: 111]

REMOVE_CAUDA:
    ; --- CASO: MOVIMENTO NORMAL ---
    ; Avança a Cauda para manter o tamanho fixo (Libera o último elemento)
    MOVL R1, TAIL_PTR.l
    MOVH R1, TAIL_PTR.h
    LOAD R2, R1, 0              ; R2 = TAIL_PTR atual
    INC R2                      ; Incrementa índice
    MOVL R3, MASCARA_CIRC
    AND R2, R2, R3              ; Ajuste circular do buffer
    STORE R2, R1, 0             ; Atualiza TAIL_PTR na memória
    RET                         ; Retorna da sub-rotina [cite: 111]

; -----------------------------------------------------------------------------
; SUB-ROTINA: ROTINA_RENDER
; -----------------------------------------------------------------------------
ROTINA_RENDER:
    ; 1. Limpa a tela inteira preenchendo com a cor Preta
    MOVL R1, COR_PRETO.l
    MOVH R1, COR_PRETO.h
    CLEAR R1                    ; Limpa Tela [cite: 119, 135]

    ; 2. Renderiza a Maçã
    MOVL R1, MACA_X.l
    MOVH R1, MACA_X.h
    LOAD R2, R1, 0              ; R2 = X virtual
    SHL R2, R2, 3               ; R2 = X * 8 (Conversão para pixels reais da tela) 

    MOVL R1, MACA_Y.l
    MOVH R1, MACA_Y.h
    LOAD R3, R1, 0              ; R3 = Y virtual
    SHL R3, R3, 3               ; R3 = Y * 8

    MOVL R4, TAM_BLOCO          ; Largura = 8 [cite: 129]
    MOVL R5, TAM_BLOCO          ; Altura = 8 [cite: 129]
    MOVL R6, COR_VERMELHO.l
    MOVH R6, COR_VERMELHO.h     ; R6 = Vermelho
    RECT R2, R3, R4, R5, R6     ; Desenha a Maçã [cite: 119, 129]

    ; 3. Renderiza o Corpo da Cobra (Varredura do Tail ao Head)
    MOVL R1, TAIL_PTR.l
    MOVH R1, TAIL_PTR.h
    LOAD R7, R1, 0              ; R7 = Índice iterador (Começa no Tail)

    MOVL R1, HEAD_PTR.l
    MOVH R1, HEAD_PTR.h
    LOAD R8, R1, 0              ; R8 = Limite final (Head)
    INC R8                      ; Inclui a cabeça no loop
    MOVL R9, MASCARA_CIRC
    AND R8, R8, R9              ; Ajuste circular do limite

LOOP_DESENHA_COBRA:
    BEQ R7, R8, FIM_RENDER_COBRA ; Se percorreu todo o corpo, encerra o laço

    ; Carrega coordenadas do segmento atual [R7]
    MOVL R1, COBRA_X.l
    MOVH R1, COBRA_X.h
    SHL R12, R7, 2              ; Índice * 4 bytes
    ADD R1, R1, R12
    LOAD R2, R1, 0              ; R2 = X Virtual
    SHL R2, R2, 3               ; R2 = X * 8 Pixels

    MOVL R1, COBRA_Y.l
    MOVH R1, COBRA_Y.h
    ADD R1, R1, R12
    LOAD R3, R1, 0              ; R3 = Y Virtual
    SHL R3, R3, 3               ; R3 = Y * 8 Pixels

    MOVL R4, TAM_BLOCO          ; W = 8
    MOVL R5, TAM_BLOCO          ; H = 8
    MOVL R6, COR_VERDE.l
    MOVH R6, COR_VERDE.h        ; R6 = Verde Opaco
    RECT R2, R3, R4, R5, R6     ; Desenha o segmento quadrado [cite: 119, 129]

    ; Avança para o próximo segmento do corpo
    INC R7
    AND R7, R7, R9              ; R7 = (R7 + 1) & 127
    JMP LOOP_DESENHA_COBRA

FIM_RENDER_COBRA:
    RET

; -----------------------------------------------------------------------------
; TELA DE GAME OVER E REINICIALIZAÇÃO
; -----------------------------------------------------------------------------
TELA_GAMEOVER:
    ; Emite um som grave de erro (Onda Senoidal de 150Hz por 500ms)
    MOVL R1, 150
    MOVL R2, 500
    MOVL R3, 0                  ; 0 = Onda Senoidal [cite: 144]
    PLAY R1, R2, R3

    ; Desenha string de Game Over centralizada na tela
    MOVL R1, 20                 ; X = 20 pixels [cite: 136]
    MOVL R2, 110                ; Y = 110 pixels [cite: 136]
    MOVL R3, MSG_GAMEOVER.l
    MOVH R3, MSG_GAMEOVER.h     ; R3 = Endereço do texto [cite: 136]
    MOVL R4, COR_BRANCO.l
    MOVH R4, COR_BRANCO.h       ; R4 = Cor Branca [cite: 119]
    PSTR R1, R2, R3, R4         ; Imprime string na tela [cite: 119, 136]

LOOP_ESPERA_ENTER:
    ; Verifica continuamente se a tecla ENTER foi pressionada para reiniciar
    MOVL R1, TECLA_ENTER
    GKEY R2, R1                 ; R2 = 1 se pressionado
    BNE R2, R0, REINICIAR_JOGO  ; Se pressionou, reseta todo o mapa e variáveis
    JMP LOOP_ESPERA_ENTER       ; Mantém travado na tela de fim de jogo