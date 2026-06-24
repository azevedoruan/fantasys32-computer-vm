; Snake Game for FantasyS32 VM
;
; The classic Snake game:
;   - Use arrow keys to steer the snake
;   - Eat red food pellets to grow and score
;   - Avoid walls and your own tail
;   - Press SPACE to restart after game over
;
; Grid: 20 x 15 cells (each 16 x 16 pixels) on a 320 x 240 framebuffer
;
; Controls:
;   LEFT  (code 0)  - turn left
;   RIGHT (code 1)  - turn right
;   UP    (code 2)  - turn up
;   DOWN  (code 3)  - turn down
;   SPACE (code 4)  - restart after game over

.data
; ============================================================================
; Colour constants (ARGB: 0xAARRGGBB)
; ============================================================================
.equ BLACK,     0xFF000000
.equ GREEN,     0xFF00FF00
.equ DKGREEN,   0xFF006400
.equ RED,       0xFFFF0000
.equ WHITE,     0xFFFFFFFF

; ============================================================================
; Game constants
; ============================================================================
.equ G_W,       20          ; grid width  (cells)
.equ G_H,       15          ; grid height (cells)
.equ CSIZE,     16          ; cell size   (pixels)
.equ MAX_SNAKE, 300         ; max snake length (= G_W * G_H)
.equ TOTAL_CELLS, 300

; ============================================================================
; Direction constants
; ============================================================================
.equ RIGHT, 0
.equ DOWN,  1
.equ LEFT,  2
.equ UP,    3

; ============================================================================
; Key codes
; ============================================================================
.equ K_LEFT,  0
.equ K_RIGHT, 1
.equ K_UP,    2
.equ K_DOWN,  3
.equ K_SPACE, 4

; ============================================================================
; Snake body - circular buffer
; Initial snake: tail at (3,7), body at (4,7), head at (5,7), length 3
; ============================================================================
snake_x: .array 3, 4, 5
         .space 297
snake_y: .array 7, 7, 7
         .space 297

; ============================================================================
; Snake state
; ============================================================================
snake_len: .var 3
snake_dir: .var RIGHT
head_idx:  .var 2
tail_idx:  .var 0

; ============================================================================
; Food
; ============================================================================
food_x: .var 10
food_y: .var 7

; ============================================================================
; Score / game-over flag
; ============================================================================
score:      .var 0
game_over:  .var 0

; ============================================================================
; Occupancy grid  (20 x 15 = 300 words)
;   0 = empty, 1 = snake body, 2 = food
; ============================================================================
grid: .space 300

; ============================================================================
; Strings for on-screen text
; ============================================================================
str_score:    .string "SCORE: "
str_gameover: .string "GAME OVER"
str_restart:  .string "PRESS SPACE"

.text
; ============================================================================
; START - entry point
; ============================================================================
START:
    ; Load permanent base addresses into preserved registers
    MOVL R4, snake_x.l
    MOVH R4, snake_x.h               ; R4 = &snake_x

    MOVL R5, snake_y.l
    MOVH R5, snake_y.h               ; R5 = &snake_y

    MOVL R6, grid.l
    MOVH R6, grid.h                  ; R6 = &grid

    ; Initialise every game variable (for restart)
    JMP INIT_GAME


; ============================================================================
; INIT_GAME - reset all state to starting values
; ============================================================================
INIT_GAME:
    ; Clear the occupancy grid
    MOVL R1, 0                       ; i = 0
    MOVL R3, 2                       ; shift-by-2 constant
CLR_GRID:
    SHL R2, R1, R3                   ; byte offset = i * 4
    ADD R2, R6, R2                   ; address = grid + offset
    STORE R0, R2, 0                  ; grid[i] = 0
    ADDI R1, R1, 1
    MOVL R2, TOTAL_CELLS
    BLT R1, R2, CLR_GRID

    ; Mark the three initial snake segments on the grid
    ; grid[7*20 + 3] = grid[143] = 1  (tail)
    MOVL R1, 143
    SHL R1, R1, R3
    ADD R1, R6, R1
    MOVL R2, 1
    STORE R2, R1, 0

    ; grid[7*20 + 4] = grid[144] = 1  (body)
    MOVL R1, 144
    SHL R1, R1, R3
    ADD R1, R6, R1
    STORE R2, R1, 0

    ; grid[7*20 + 5] = grid[145] = 1  (head)
    MOVL R1, 145
    SHL R1, R1, R3
    ADD R1, R6, R1
    STORE R2, R1, 0

    ; grid[7*20 + 10] = grid[150] = 2 (food)
    MOVL R1, 150
    SHL R1, R1, R3
    ADD R1, R6, R1
    MOVL R2, 2
    STORE R2, R1, 0

    ; Reset snake variables
    MOVL R1, 2
    MOVL R2, head_idx.l
    MOVH R2, head_idx.h
    STORE R1, R2, 0                  ; head_idx = 2

    MOVL R1, 0
    MOVL R2, tail_idx.l
    MOVH R2, tail_idx.h
    STORE R1, R2, 0                  ; tail_idx = 0

    MOVL R1, 3
    MOVL R2, snake_len.l
    MOVH R2, snake_len.h
    STORE R1, R2, 0                  ; snake_len = 3

    MOVL R1, RIGHT
    MOVL R2, snake_dir.l
    MOVH R2, snake_dir.h
    STORE R1, R2, 0                  ; snake_dir = RIGHT

    MOVL R1, 10
    MOVL R2, food_x.l
    MOVH R2, food_x.h
    STORE R1, R2, 0                  ; food_x = 10

    MOVL R1, 7
    MOVL R2, food_y.l
    MOVH R2, food_y.h
    STORE R1, R2, 0                  ; food_y = 7

    MOVL R1, 0
    MOVL R2, score.l
    MOVH R2, score.h
    STORE R1, R2, 0                  ; score = 0

    MOVL R2, game_over.l
    MOVH R2, game_over.h
    STORE R1, R2, 0                  ; game_over = FALSE

    ; Seed RNG with the current frame number
    FRAMENUM R1
    SRAND R1

    JMP GAME_LOOP


; ============================================================================
; MAIN GAME LOOP
; ============================================================================
GAME_LOOP:
    ; -------- 1.  Check whether we are in game-over state -----------------
    MOVL R1, game_over.l
    MOVH R1, game_over.h
    LOAD R1, R1, 0
    BNE R1, R0, GAME_OVER_SCREEN

    ; -------- 2.  Input - read arrow keys, update direction ---------------
    MOVL R1, snake_dir.l
    MOVH R1, snake_dir.h
    LOAD R1, R1, 0                   ; R1 = current direction

    ; LEFT arrow
    MOVL R2, K_LEFT
    GKEY R3, R2
    BEQ R3, R0, CHK_RIGHT
    MOVL R2, RIGHT
    BEQ R1, R2, CHK_RIGHT            ; ignore if currently going RIGHT
    MOVL R2, LEFT
    JMP SET_DIR

CHK_RIGHT:
    MOVL R2, K_RIGHT
    GKEY R3, R2
    BEQ R3, R0, CHK_UP
    MOVL R2, LEFT
    BEQ R1, R2, CHK_UP               ; ignore if currently going LEFT
    MOVL R2, RIGHT
    JMP SET_DIR

CHK_UP:
    MOVL R2, K_UP
    GKEY R3, R2
    BEQ R3, R0, CHK_DOWN
    MOVL R2, DOWN
    BEQ R1, R2, CHK_DOWN             ; ignore if currently going DOWN
    MOVL R2, UP
    JMP SET_DIR

CHK_DOWN:
    MOVL R2, K_DOWN
    GKEY R3, R2
    BEQ R3, R0, INPUT_DONE
    MOVL R2, UP
    BEQ R1, R2, INPUT_DONE           ; ignore if currently going UP
    MOVL R2, DOWN

SET_DIR:
    MOVL R3, snake_dir.l
    MOVH R3, snake_dir.h
    STORE R2, R3, 0                  ; update direction
    ADD R1, R2, R0                   ; R1 = updated direction for this move

INPUT_DONE:
    ; R1 holds the direction to use for this tick

    ; -------- 3.  Move the snake ------------------------------------------
    ; Load indices
    MOVL R2, head_idx.l
    MOVH R2, head_idx.h
    LOAD R2, R2, 0                   ; R2 = head_idx

    MOVL R3, tail_idx.l
    MOVH R3, tail_idx.h
    LOAD R3, R3, 0                   ; R3 = tail_idx

    ; Get current head position (grid coordinates, not pixels)
    MOVL R8, 2                       ; shift-by-2 for word-offset calc
    SHL R7, R2, R8                   ; byte offset = head_idx * 4
    ADD R8, R4, R7                   ; &snake_x[head_idx]
    LOAD R9, R8, 0                   ; R9 = old_head_x (grid coord)
    ADD R8, R5, R7                   ; &snake_y[head_idx]
    LOAD R10, R8, 0                  ; R10 = old_head_y (grid coord)

    ; new_head_idx = (head_idx + 1) % MAX_SNAKE
    ADDI R2, R2, 1
    MOVL R7, MAX_SNAKE
    MOD R2, R2, R7                   ; R2 = new_head_idx

    ; Compute new head position (grid coords) based on direction in R1
    MOVL R13, RIGHT
    BEQ R1, R13, MOVE_RIGHT
    MOVL R13, DOWN
    BEQ R1, R13, MOVE_DOWN
    MOVL R13, LEFT
    BEQ R1, R13, MOVE_LEFT
    ; UP case
    ADD R11, R9, R0                  ; new_x = old_x
    ADD R12, R10, R0                 ; new_y = old_y
    ADDI R12, R12, -1                ; new_y = old_y - 1
    JMP MOVE_DONE

MOVE_RIGHT:
    ADD R11, R9, R0                  ; new_x = old_x
    ADDI R11, R11, 1                 ; new_x = old_x + 1
    ADD R12, R10, R0                 ; new_y = old_y
    JMP MOVE_DONE

MOVE_DOWN:
    ADD R11, R9, R0                  ; new_x = old_x
    ADD R12, R10, R0                 ; new_y = old_y
    ADDI R12, R12, 1                 ; new_y = old_y + 1
    JMP MOVE_DONE

MOVE_LEFT:
    ADD R11, R9, R0                  ; new_x = old_x
    ADDI R11, R11, -1                ; new_x = old_x - 1
    ADD R12, R10, R0                 ; new_y = old_y
    ; fall through

MOVE_DONE:
    ; R11 = new_x, R12 = new_y, R2  = new_head_idx

    ; -------- 4.  Wall collision -----------------------------------------
    BLT R11, R0, COLLIDE_WALL        ; new_x < 0
    MOVL R1, G_W
    BGE R11, R1, COLLIDE_WALL        ; new_x >= 20
    BLT R12, R0, COLLIDE_WALL        ; new_y < 0
    MOVL R1, G_H
    BGE R12, R1, COLLIDE_WALL        ; new_y >= 15

    ; -------- 5.  Grid lookup --------------------------------------------
    ; grid_idx = new_y * G_W + new_x
    MOVL R1, G_W
    MUL R1, R12, R1                  ; R1 = new_y * 20
    ADD R1, R1, R11                  ; R1 = grid_idx

    MOVL R13, 2
    SHL R8, R1, R13                  ; byte offset
    ADD R8, R6, R8                   ; &grid[grid_idx]
    LOAD R9, R8, 0                   ; R9 = grid value

    ; -------- 6.  Self collision? -----------------------------------------
    MOVL R10, 1
    BEQ R9, R10, COLLIDE_SELF

    ; -------- 7.  Food collision? -----------------------------------------
    MOVL R10, 2
    BEQ R9, R10, ATE_FOOD

    ; -------- 8.  Normal move (no food) -----------------------------------
    ; Write new head position into arrays
    MOVL R7, 2
    SHL R13, R2, R7                  ; byte offset = new_head_idx * 4
    ADD R10, R4, R13
    STORE R11, R10, 0                ; snake_x[new_head_idx] = new_x
    ADD R10, R5, R13
    STORE R12, R10, 0                ; snake_y[new_head_idx] = new_y

    ; Mark new head on grid
    MOVL R10, 1
    STORE R10, R8, 0                 ; grid[grid_idx] = 1

    ; Remove tail from grid
    ; tail position = snake_x[tail_idx], snake_y[tail_idx]
    SHL R13, R3, R7                  ; byte offset = tail_idx * 4
    ADD R10, R4, R13
    LOAD R9, R10, 0                  ; R9 = tail_x
    ADD R10, R5, R13
    LOAD R10, R10, 0                 ; R10 = tail_y

    ; grid[tail_y * G_W + tail_x] = 0
    MOVL R7, G_W
    MUL R7, R10, R7
    ADD R7, R7, R9                   ; R7 = tail grid index
    MOVL R13, 2
    SHL R7, R7, R13
    ADD R7, R6, R7
    STORE R0, R7, 0                  ; clear tail on grid

    ; Advance tail_idx: (tail_idx + 1) % MAX_SNAKE
    ADDI R3, R3, 1
    MOVL R7, MAX_SNAKE
    MOD R3, R3, R7                   ; R3 = new tail_idx

    ; Store updated indices
    MOVL R7, head_idx.l
    MOVH R7, head_idx.h
    STORE R2, R7, 0                  ; head_idx = new_head_idx

    MOVL R7, tail_idx.l
    MOVH R7, tail_idx.h
    STORE R3, R7, 0                  ; tail_idx = new_tail_idx

    JMP AFTER_MOVE

    ; -------- 9.  Ate food -----------------------------------------------
ATE_FOOD:
    ; Write new head position
    MOVL R7, 2
    SHL R13, R2, R7
    ADD R10, R4, R13
    STORE R11, R10, 0                ; snake_x[new_head_idx] = new_x
    ADD R10, R5, R13
    STORE R12, R10, 0                ; snake_y[new_head_idx] = new_y

    ; Mark head on grid
    MOVL R10, 1
    STORE R10, R8, 0                 ; grid[grid_idx] = 1

    ; Update head_idx (tail_idx stays - snake grows)
    MOVL R7, head_idx.l
    MOVH R7, head_idx.h
    STORE R2, R7, 0                  ; head_idx = new_head_idx

    ; Increment snake length
    MOVL R7, snake_len.l
    MOVH R7, snake_len.h
    LOAD R10, R7, 0
    ADDI R10, R10, 1
    STORE R10, R7, 0                 ; snake_len++

    ; Add 10 points to score
    MOVL R7, score.l
    MOVH R7, score.h
    LOAD R10, R7, 0
    ADDI R10, R10, 10
    STORE R10, R7, 0                 ; score += 10

    ; Spawn a new food pellet
    CALL SPAWN_FOOD

    JMP AFTER_MOVE

    ; -------- 10. Collision - game over ----------------------------------
COLLIDE_WALL:
COLLIDE_SELF:
    MOVL R7, game_over.l
    MOVH R7, game_over.h
    MOVL R10, 1
    STORE R10, R7, 0                 ; game_over = TRUE
    ; fall through

AFTER_MOVE:
    ; -------- 11. Render frame -------------------------------------------
    ; Clear screen to black
    MOVL R1, BLACK.l
    MOVH R1, BLACK.h
    CLEAR R1

    ; Draw food
    CALL DRAW_FOOD

    ; Draw snake body
    CALL DRAW_SNAKE

    ; Draw score in top-left corner
    CALL DRAW_SCORE

    ; -------- 12. Speed control ------------------------------------------
    MOVL R1, 120
    SLEEP R1                         ; 120 ms pause

    JMP GAME_LOOP


; ============================================================================
; GAME OVER SCREEN
; ============================================================================
GAME_OVER_SCREEN:
    ; Clear screen
    MOVL R1, BLACK.l
    MOVH R1, BLACK.h
    CLEAR R1

    ; Draw "GAME OVER" near centre
    MOVL R1, 80
    MOVL R2, 100
    MOVL R3, str_gameover.l
    MOVH R3, str_gameover.h
    MOVL R4, RED.l
    MOVH R4, RED.h
    PSTR R1, R2, R3, R4

    ; Draw the final score
    MOVL R1, 100
    MOVL R2, 130
    MOVL R3, score.l
    MOVH R3, score.h
    LOAD R3, R3, 0
    MOVL R4, WHITE.l
    MOVH R4, WHITE.h
    PINT R1, R2, R3, R4

    ; Draw "PRESS SPACE"
    MOVL R1, 80
    MOVL R2, 160
    MOVL R3, str_restart.l
    MOVH R3, str_restart.h
    MOVL R4, WHITE.l
    MOVH R4, WHITE.h
    PSTR R1, R2, R3, R4

    ; Wait until SPACE is pressed, then restart
GO_WAIT_KEY:
    MOVL R1, K_SPACE
    GKEY R2, R1
    BEQ R2, R0, GO_WAIT_KEY

    JMP START


; ============================================================================
; SUBROUTINE - DRAW_FOOD
; Draws a red 16x16 rectangle at (food_x * 16, food_y * 16)
; ============================================================================
DRAW_FOOD:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5

    ; Load food grid coordinates and convert to pixels
    MOVL R1, food_x.l
    MOVH R1, food_x.h
    LOAD R1, R1, 0
    MOVL R3, 4
    SHL R1, R1, R3                   ; pixel_x = food_x * 16

    MOVL R2, food_y.l
    MOVH R2, food_y.h
    LOAD R2, R2, 0
    SHL R2, R2, R3                   ; pixel_y = food_y * 16

    MOVL R3, CSIZE                   ; w = 16
    MOVL R4, CSIZE                   ; h = 16
    MOVL R5, RED.l
    MOVH R5, RED.h                   ; colour = RED

    RECT R1, R2, R3, R4, R5

    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET


; ============================================================================
; SUBROUTINE - DRAW_SNAKE
; Draws every snake segment as a green 16x16 rectangle.
; The head is drawn in dark green on top.
; ============================================================================
DRAW_SNAKE:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8
    PUSH R9
    PUSH R10
    PUSH R11
    PUSH R12
    PUSH R13

    ; Reload base addresses (might have been clobbered by caller)
    MOVL R4, snake_x.l
    MOVH R4, snake_x.h
    MOVL R5, snake_y.l
    MOVH R5, snake_y.h

    ; Load indices
    MOVL R6, tail_idx.l
    MOVH R6, tail_idx.h
    LOAD R6, R6, 0                   ; R6 = tail_idx (loop start)

    MOVL R7, snake_len.l
    MOVH R7, snake_len.h
    LOAD R7, R7, 0                   ; R7 = snake_len (loop count)

    MOVL R8, head_idx.l
    MOVH R8, head_idx.h
    LOAD R8, R8, 0                   ; R8 = head_idx

    MOVL R9, 0                       ; R9 = loop counter (i)

    ; Colour and cell-size constants
    MOVL R10, GREEN.l
    MOVH R10, GREEN.h                ; body colour = GREEN
    MOVL R11, CSIZE                  ; cell width & height = 16

    ; Register for shift-by-2 (word offset) and shift-by-4 (pixel *16)
    MOVL R13, 2
    MOVL R12, 4

DS_BODY_LOOP:
    ; Compute segment index: (tail_idx + i) % MAX_SNAKE
    ADD R1, R6, R9
    MOVL R2, MAX_SNAKE
    MOD R1, R1, R2                   ; R1 = array index of this segment

    ; Load grid coordinates and convert to pixels
    SHL R2, R1, R13                  ; byte offset = idx * 4
    ADD R3, R4, R2
    LOAD R3, R3, 0                   ; R3 = segment_x (grid)
    SHL R3, R3, R12                  ; R3 = pixel_x

    ADD R2, R5, R2
    LOAD R2, R2, 0                   ; R2 = segment_y (grid)
    SHL R2, R2, R12                  ; R2 = pixel_y

    ; Draw this segment
    RECT R3, R2, R11, R11, R10

    ADDI R9, R9, 1
    BLT R9, R7, DS_BODY_LOOP

    ; ---- Draw head on top in dark green ----
    SHL R1, R8, R13                  ; byte offset = head_idx * 4
    ADD R2, R4, R1
    LOAD R2, R2, 0
    SHL R2, R2, R12                  ; pixel_x

    ADD R1, R5, R1
    LOAD R1, R1, 0
    SHL R1, R1, R12                  ; pixel_y

    MOVL R3, DKGREEN.l
    MOVH R3, DKGREEN.h
    RECT R2, R1, R11, R11, R3

    POP R13
    POP R12
    POP R11
    POP R10
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


; ============================================================================
; SUBROUTINE - DRAW_SCORE
; Prints "SCORE: " then the score value at the top-left corner.
; ============================================================================
DRAW_SCORE:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4

    ; Print "SCORE: " string
    MOVL R1, 8
    MOVL R2, 8
    MOVL R3, str_score.l
    MOVH R3, str_score.h
    MOVL R4, WHITE.l
    MOVH R4, WHITE.h
    PSTR R1, R2, R3, R4

    ; Print the numeric score right after the label
    MOVL R1, 90
    MOVL R2, 8
    MOVL R3, score.l
    MOVH R3, score.h
    LOAD R3, R3, 0
    MOVL R4, WHITE.l
    MOVH R4, WHITE.h
    PINT R1, R2, R3, R4

    POP R4
    POP R3
    POP R2
    POP R1
    RET


; ============================================================================
; SUBROUTINE - SPAWN_FOOD
; Uses RAND to pick a random empty cell and places food there.
; Retries up to 300 times; if the grid is full, the existing food stays.
; ============================================================================
SPAWN_FOOD:
    PUSH R1
    PUSH R2
    PUSH R3
    PUSH R4
    PUSH R5
    PUSH R6
    PUSH R7
    PUSH R8

    ; Load grid base address
    MOVL R6, grid.l
    MOVH R6, grid.h

    MOVL R7, 0                       ; retry counter

SF_RETRY:
    ; Random x in [0, 19]
    MOVL R1, 0
    MOVL R2, 19
    RAND R4, R1, R2                  ; R4 = random x

    ; Random y in [0, 14]
    MOVL R1, 0
    MOVL R2, 14
    RAND R5, R1, R2                  ; R5 = random y

    ; grid index = y * G_W + x
    MOVL R1, G_W
    MUL R1, R5, R1
    ADD R1, R1, R4                   ; R1 = grid index

    ; Check whether this cell is empty
    MOVL R2, 2
    SHL R2, R1, R2                   ; byte offset
    ADD R2, R6, R2
    LOAD R3, R2, 0
    BEQ R3, R0, SF_FOUND             ; empty cell found

    ; Not empty - retry
    ADDI R7, R7, 1
    MOVL R2, TOTAL_CELLS
    BLT R7, R2, SF_RETRY             ; give up after 300 tries
    JMP SF_DONE

SF_FOUND:
    ; Store food position
    MOVL R2, food_x.l
    MOVH R2, food_x.h
    STORE R4, R2, 0                  ; food_x = R4

    MOVL R2, food_y.l
    MOVH R2, food_y.h
    STORE R5, R2, 0                  ; food_y = R5

    ; Mark cell as food on grid
    MOVL R2, 2
    SHL R1, R1, R2                   ; byte offset = index * 4
    ADD R2, R6, R1
    MOVL R3, 2
    STORE R3, R2, 0                  ; grid[index] = 2

SF_DONE:
    POP R8
    POP R7
    POP R6
    POP R5
    POP R4
    POP R3
    POP R2
    POP R1
    RET
