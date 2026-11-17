################################################################################
# CSC258 Assembly Project: Magical Drop
#
# Student 1: TODO Name, TODO Student Number
# Student 2: TODO Name, TODO Student Number (delete this line if working alone)
#
######################## Bitmap Display Configuration ##########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    512
# - Display height in pixels:   512
# - Base Address for Display:   0x10008000 ($gp)
#   (the display is therefore 64 x 64 units)
################################################################################
#
# Milestones reached: 1, 2, 3, 4, 5
#
# Easy features implemented (numbers refer to the project handout):
#   1. Row advancement on a timer (modes 1-3)
#   2. Row advancement gets faster after every new row
#   3. Easy / Medium / Hard selection before the game
#   4. Game Over screen drawn in pixels, with a retry option
#   5. Sound effects (grab, throw, blocked, match, chain, new row, game over)
#   6. Pause with the p key ("PAUSED" message, p again resumes)
#   7. Highest score so far is tracked and displayed
#   8. "Rows left" counter, game over screen when it reaches 0
#   9. Preview panel above the top row showing the next row of bubbles
#
# Hard features implemented:
#   2. Flood fill (horizontal + vertical) after the vertical match-3 trigger
#   3. Gravity: unsupported bubbles float upwards
#   4. New rows are checked so they never arrive already forming a match-3
#   5. Chain reactions: match / remove / gravity repeats until nothing matches
#   6. Flashing dotted aiming line in the character's column
#   7. Score displayed in pixels (difficulty x bubbles cleared x chain depth)
#   9. Animations (bubbles popping, cascading float-up, thrown bubble flying,
#      game over curtain)
#  10. Menu screen (difficulty selection + best score)
#
# How to play:
#   Menu:       1 = Easy, 2 = Medium, 3 = Hard,
#               4 = Keystroke mode (a new row every 10 keystrokes, Milestone 2c)
#   In game:    a / d = move left / right
#               s     = grab the bottom-most bubble(s) of the column above
#               w     = throw the held bubbles up into the column above
#               p     = pause / resume
#               q     = quit
#   Game over:  r = retry, m = back to the menu, q = quit
#
################################################################################
#
# Screen layout (in units, x to the right, y downwards):
#   x = 0 and x = 30      side walls of the playing field
#   y = 0, y = 4, y = 62  top wall, preview separator / timer bar, bottom wall
#   y = 1..3              preview panel (next row)
#   grid cell (r, c)      3 x 3 units with its top-left corner at
#                         x = 2 + 4*c,  y = 6 + 4*r      (r = 0..13, c = 0..6)
#   row 13                the character's row (bubbles here = game over)
#   x = 33..            HUD text (score, best, rows left, held bubbles, mode)
#
################################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display.
display_address:    .word 0x10008000
# The address of the keyboard.
keyboard_address:   .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################
# The playing field: 14 rows x 7 columns, one word per cell, row major order.
# 0 = empty, 1 = red, 2 = yellow, 3 = green, 4 = blue.
# grid[r][c] is stored at grid + 4 * (7 * r + c). Row 0 is the top row and
# row 13 is the character's row.
grid:           .space 392
# One word per cell: 1 when the cell is part of the match being removed.
mark:           .space 392
# Work stack for the flood fill (holds cell indices 0..97).
ff_stack:       .space 392
# The next row of bubbles (shown in the preview panel), one word per column.
next_row:       .space 28
# Number of entries currently on ff_stack.
ff_count:       .word 0

# The character and the bubbles it is holding.
player_col:     .word 3     # column of the character (0..6)
held_colour:    .word 0     # colour of the held bubbles (0 = none)
held_count:     .word 0     # how many bubbles are held

# Score keeping.
score:          .word 0
high_score:     .word 0     # survives retries
rows_left:      .word 0     # rows still to come before the game ends
cleared_total:  .word 0     # bubbles cleared in this game
chain_depth:    .word 0     # depth of the chain reaction being resolved

# Game settings and timers.
difficulty:     .word 1     # 1 = easy, 2 = medium, 3 = hard, 4 = keystroke mode
score_mult:     .word 1     # score multiplier of the current difficulty
row_timer:      .word 0     # frames since the last new row
row_interval:   .word 0     # frames between two new rows
key_count:      .word 0     # keystrokes since the last new row
frame_count:    .word 0     # frames since the game started
game_result:    .word 0     # 0 = lost, 1 = won (all rows survived)
hud_dirty:      .word 1     # 1 when the HUD numbers must be redrawn

##############################################################################
# Constant tables and sprites
##############################################################################
# Indexed by difficulty (index 0 is unused).
interval_table: .word 0, 540, 400, 280, 0       # frames between new rows
rows_table:     .word 0, 30, 40, 50, 30         # rows in one game
mult_table:     .word 0, 1, 2, 3, 1             # score multiplier

# Notes played when the player wins.
win_notes:      .word 72, 76, 79, 84

# Bubble palette: three shades (dark, base, light) per entry.
# A bubble is drawn as    dark  base  dark
#                         base  light base
#                         dark  base  dark
palette:
    .word 0x000000, 0x000000, 0x000000      # 0 empty cell
    .word 0x900000, 0xe02020, 0xff9090      # 1 red
    .word 0x907000, 0xf0d000, 0xffff90      # 2 yellow
    .word 0x006000, 0x10c030, 0x90ff90      # 3 green
    .word 0x001090, 0x2050f0, 0x90b0ff      # 4 blue
    .word 0x404040, 0x808080, 0xc0c0c0      # 5 grey (game over)
    .word 0xffffff, 0xffffff, 0xffffff      # 6 pop animation: white square
    .word 0x000000, 0xffffff, 0xffffff      # 7 pop animation: plus shape
    .word 0x000000, 0x000000, 0xffffff      # 8 pop animation: single dot

# The character, 3 x 3 units, row major order. The centre unit is replaced by
# the colour of the held bubbles while the character is holding something.
player_sprite:
    .word 0x000000, 0xffffff, 0x000000
    .word 0xc0c0c0, 0xff60c0, 0xc0c0c0
    .word 0xffffff, 0x000000, 0xffffff

# 3 x 5 font. One word per glyph; bit 14 is the top-left unit, bit 0 the
# bottom-right unit (row major order). Glyphs 0-9 are digits, 10-35 are A-Z.
font:
    .word 0x7b6f          # '0'  111 101 101 101 111
    .word 0x2c97          # '1'  010 110 010 010 111
    .word 0x73e7          # '2'  111 001 111 100 111
    .word 0x73cf          # '3'  111 001 111 001 111
    .word 0x5bc9          # '4'  101 101 111 001 001
    .word 0x79cf          # '5'  111 100 111 001 111
    .word 0x79ef          # '6'  111 100 111 101 111
    .word 0x7249          # '7'  111 001 001 001 001
    .word 0x7bef          # '8'  111 101 111 101 111
    .word 0x7bcf          # '9'  111 101 111 001 111
    .word 0x2bed          # 'A'  010 101 111 101 101
    .word 0x6bae          # 'B'  110 101 110 101 110
    .word 0x3923          # 'C'  011 100 100 100 011
    .word 0x6b6e          # 'D'  110 101 101 101 110
    .word 0x79a7          # 'E'  111 100 110 100 111
    .word 0x79a4          # 'F'  111 100 110 100 100
    .word 0x396b          # 'G'  011 100 101 101 011
    .word 0x5bed          # 'H'  101 101 111 101 101
    .word 0x7497          # 'I'  111 010 010 010 111
    .word 0x126a          # 'J'  001 001 001 101 010
    .word 0x5bad          # 'K'  101 101 110 101 101
    .word 0x4927          # 'L'  100 100 100 100 111
    .word 0x5fed          # 'M'  101 111 111 101 101
    .word 0x6b6d          # 'N'  110 101 101 101 101
    .word 0x2b6a          # 'O'  010 101 101 101 010
    .word 0x6ba4          # 'P'  110 101 110 100 100
    .word 0x2b7b          # 'Q'  010 101 101 111 011
    .word 0x6bad          # 'R'  110 101 110 101 101
    .word 0x388e          # 'S'  011 100 010 001 110
    .word 0x7492          # 'T'  111 010 010 010 010
    .word 0x5b6f          # 'U'  101 101 101 101 111
    .word 0x5b6a          # 'V'  101 101 101 101 010
    .word 0x5bfd          # 'W'  101 101 111 111 101
    .word 0x5aad          # 'X'  101 101 010 101 101
    .word 0x5a92          # 'Y'  101 101 010 010 010
    .word 0x72a7          # 'Z'  111 001 010 100 111

# Text shown on screen (kept last so the words above stay word aligned).
str_magical:    .asciiz "MAGICAL"
str_drop:       .asciiz "DROP"
str_opt1:       .asciiz "1 EASY"
str_opt2:       .asciiz "2 MEDIUM"
str_opt3:       .asciiz "3 HARD"
str_opt4:       .asciiz "4 KEYSTROKE"
str_score:      .asciiz "SCORE"
str_best:       .asciiz "BEST"
str_left:       .asciiz "LEFT"
str_hold:       .asciiz "HOLD"
str_easy:       .asciiz "EASY"
str_medium:     .asciiz "MEDIUM"
str_hard:       .asciiz "HARD"
str_keys:       .asciiz "KEYS"
str_paused:     .asciiz "PAUSED"
str_game_over:  .asciiz "GAME OVER"
str_you_win:    .asciiz "YOU WIN"
str_you_lose:   .asciiz "YOU LOSE"
str_retry:      .asciiz "R RETRY"
str_menu:       .asciiz "M MENU"
str_quit:       .asciiz "Q QUIT"

##############################################################################
# Code
##############################################################################
    .text
    .globl main

# Run the game.
main:

##############################################################################
# Menu screen: choose the difficulty (easy feature 3, hard feature 10).
##############################################################################
menu_screen:
    jal clear_screen
    li $a0, 18
    li $a1, 4
    la $a2, str_magical
    li $a3, 0xff60c0
    jal draw_string
    li $a0, 24
    li $a1, 11
    la $a2, str_drop
    li $a3, 0xff60c0
    jal draw_string

    # A row of seven decorative bubbles under the title.
    li $s0, 0
menu_bubbles:
    sll $a0, $s0, 2
    addi $a0, $a0, 18
    li $a1, 18
    andi $a2, $s0, 3
    addi $a2, $a2, 1
    jal draw_bubble
    addi $s0, $s0, 1
    li $t0, 7
    blt $s0, $t0, menu_bubbles

    # The four options.
    li $a0, 8
    li $a1, 25
    la $a2, str_opt1
    li $a3, 0x10c030
    jal draw_string
    li $a0, 8
    li $a1, 32
    la $a2, str_opt2
    li $a3, 0xf0d000
    jal draw_string
    li $a0, 8
    li $a1, 39
    la $a2, str_opt3
    li $a3, 0xe02020
    jal draw_string
    li $a0, 8
    li $a1, 46
    la $a2, str_opt4
    li $a3, 0x90b0ff
    jal draw_string

    # The best score so far.
    li $a0, 8
    li $a1, 56
    la $a2, str_best
    li $a3, 0xc0c0c0
    jal draw_string
    li $a0, 28
    li $a1, 56
    lw $a2, high_score
    li $a3, 6
    jal draw_number

menu_wait:
    lw $t0, keyboard_address
    lw $t1, 0($t0)                  # first word: 1 if a key was pressed
    andi $t1, $t1, 1
    beq $t1, $zero, menu_sleep
    lw $t2, 4($t0)                  # second word: ASCII code of the key
    ori $t2, $t2, 0x20              # treat upper case like lower case
    beq $t2, 0x71, exit_game        # q
    addi $t2, $t2, -48              # '1'..'4' -> 1..4
    li $t3, 1
    blt $t2, $t3, menu_sleep
    li $t3, 4
    bgt $t2, $t3, menu_sleep
    sw $t2, difficulty
    li $a0, 72
    li $a1, 120
    li $a2, 12
    jal play_sound
    j new_game
menu_sleep:
    li $a0, 30
    jal sleep_ms
    j menu_wait

##############################################################################
# Start a brand new game with the selected difficulty.
# Nothing is kept from the previous game except the high score.
##############################################################################
new_game:
    la $a0, grid
    li $a1, 98
    jal clear_words
    la $a0, mark
    li $a1, 98
    jal clear_words

    li $t0, 3
    sw $t0, player_col
    sw $zero, held_colour
    sw $zero, held_count
    sw $zero, score
    sw $zero, cleared_total
    sw $zero, chain_depth
    sw $zero, row_timer
    sw $zero, key_count
    sw $zero, frame_count
    sw $zero, game_result
    sw $zero, ff_count

    # Settings that depend on the difficulty.
    lw $t0, difficulty
    sll $t0, $t0, 2
    la $t1, interval_table
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    sw $t2, row_interval
    la $t1, rows_table
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    sw $t2, rows_left
    la $t1, mult_table
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    sw $t2, score_mult

    # Populate the field with five rows of random bubbles.
    jal gen_next_row
    li $s0, 5
ng_rows:
    jal push_row
    addi $s0, $s0, -1
    bgtz $s0, ng_rows

    jal draw_static_scene

##############################################################################
# The central game loop.
##############################################################################
game_loop:
    # 1. Check for keyboard input.
    lw $t0, keyboard_address
    lw $t1, 0($t0)                  # first word: 1 if a key was pressed
    andi $t1, $t1, 1
    beq $t1, $zero, gl_no_key
    lw $t2, 4($t0)                  # second word: ASCII code of the key
    ori $t2, $t2, 0x20              # treat upper case like lower case

    # 2. Process the player's action (3. matches are resolved by the throw).
    beq $t2, 0x61, gl_key_a
    beq $t2, 0x64, gl_key_d
    beq $t2, 0x73, gl_key_s
    beq $t2, 0x77, gl_key_w
    beq $t2, 0x70, gl_key_p
    beq $t2, 0x71, exit_game
    j gl_no_key
gl_key_a:
    jal move_left
    j gl_count_key
gl_key_d:
    jal move_right
    j gl_count_key
gl_key_s:
    jal handle_grab
    j gl_count_key
gl_key_w:
    jal handle_throw
    j gl_count_key
gl_key_p:
    jal pause_game
    j gl_no_key
gl_count_key:
    lw $t0, key_count
    addi $t0, $t0, 1
    sw $t0, key_count
gl_no_key:

    # 4. Check for row advancement.
    lw $t0, difficulty
    li $t1, 4
    beq $t0, $t1, gl_keystroke_mode
    lw $t2, row_timer               # timer modes: count frames
    addi $t2, $t2, 1
    sw $t2, row_timer
    lw $t3, row_interval
    blt $t2, $t3, gl_draw
    j gl_advance
gl_keystroke_mode:
    lw $t2, key_count               # keystroke mode: a row every 10 keys
    li $t3, 10
    blt $t2, $t3, gl_draw
gl_advance:
    sw $zero, row_timer
    sw $zero, key_count
    jal advance_row                 # $v0 = 1 if a bubble reached the bottom row
    bne $v0, $zero, gl_lose
    lw $t0, rows_left
    blez $t0, gl_win
    # Speed up the row advancement a little after every new row.
    lw $t0, difficulty
    li $t1, 4
    beq $t0, $t1, gl_draw
    lw $t0, row_interval
    addi $t0, $t0, -10
    li $t1, 150
    bge $t0, $t1, gl_speed_ok
    move $t0, $t1
gl_speed_ok:
    sw $t0, row_interval

gl_draw:
    # 5. Redraw the screen.
    jal draw_scene
    lw $t0, frame_count
    addi $t0, $t0, 1
    sw $t0, frame_count

    # 6. Sleep (about 60 frames per second).
    li $a0, 16
    jal sleep_ms

    # 7. Go back to step 1.
    j game_loop

gl_lose:
    sw $zero, game_result
    j game_over
gl_win:
    li $t0, 1
    sw $t0, game_result

##############################################################################
# Game over: play the end animation, show the Game Over screen and wait for
# r (retry), m (menu) or q (quit).
##############################################################################
game_over:
    jal draw_preview
    jal draw_board
    jal draw_hud
    lw $t0, game_result
    bne $t0, $zero, go_win

    # Lost: every bubble turns grey, one row at a time.
    li $s0, 0                       # row
go_curtain_row:
    li $s1, 0                       # column
go_curtain_col:
    sll $t0, $s0, 3
    sub $t0, $t0, $s0               # 7 * row
    add $t0, $t0, $s1
    sll $t0, $t0, 2
    la $t1, grid
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    beq $t2, $zero, go_curtain_next
    sll $a0, $s1, 2
    addi $a0, $a0, 2
    sll $a1, $s0, 2
    addi $a1, $a1, 6
    li $a2, 5
    jal draw_bubble
go_curtain_next:
    addi $s1, $s1, 1
    li $t0, 7
    blt $s1, $t0, go_curtain_col
    li $a0, 62                      # a falling scale, one note per row
    sll $t0, $s0, 1
    sub $a0, $a0, $t0
    li $a1, 150
    li $a2, 0
    jal play_sound
    li $a0, 60
    jal sleep_ms
    addi $s0, $s0, 1
    li $t0, 14
    blt $s0, $t0, go_curtain_row
    j go_show

go_win:
    # Won: a short rising jingle.
    li $s0, 0
go_win_loop:
    la $t0, win_notes
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $a0, 0($t0)
    li $a1, 250
    li $a2, 9
    jal play_sound
    li $a0, 160
    jal sleep_ms
    addi $s0, $s0, 1
    li $t0, 4
    blt $s0, $t0, go_win_loop

go_show:
    li $a0, 700
    jal sleep_ms
    jal clear_screen
    lw $t0, game_result
    bne $t0, $zero, go_text_win
    li $a0, 14
    li $a1, 6
    la $a2, str_game_over
    li $a3, 0xe02020
    jal draw_string
    li $a0, 16
    li $a1, 16
    la $a2, str_you_lose
    li $a3, 0xe02020
    jal draw_string
    j go_text_rest
go_text_win:
    li $a0, 14
    li $a1, 6
    la $a2, str_game_over
    li $a3, 0x10c030
    jal draw_string
    li $a0, 18
    li $a1, 16
    la $a2, str_you_win
    li $a3, 0x10c030
    jal draw_string
go_text_rest:
    li $a0, 6
    li $a1, 27
    la $a2, str_score
    li $a3, 0xf0d000
    jal draw_string
    li $a0, 30
    li $a1, 27
    lw $a2, score
    li $a3, 6
    jal draw_number
    li $a0, 6
    li $a1, 34
    la $a2, str_best
    li $a3, 0xf0d000
    jal draw_string
    li $a0, 30
    li $a1, 34
    lw $a2, high_score
    li $a3, 6
    jal draw_number
    li $a0, 18
    li $a1, 44
    la $a2, str_retry
    li $a3, 0xc0c0c0
    jal draw_string
    li $a0, 18
    li $a1, 50
    la $a2, str_menu
    li $a3, 0xc0c0c0
    jal draw_string
    li $a0, 18
    li $a1, 56
    la $a2, str_quit
    li $a3, 0xc0c0c0
    jal draw_string

go_wait:
    li $a0, 30
    jal sleep_ms
    lw $t0, keyboard_address
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beq $t1, $zero, go_wait
    lw $t2, 4($t0)
    ori $t2, $t2, 0x20
    beq $t2, 0x72, new_game         # r: retry with the same difficulty
    beq $t2, 0x6d, menu_screen      # m: back to the menu
    beq $t2, 0x71, exit_game        # q: quit
    j go_wait

##############################################################################
# Quit the game.
##############################################################################
exit_game:
    jal clear_screen
    li $v0, 10                      # terminate the program gracefully
    syscall

##############################################################################
# Player actions
##############################################################################

# move_left: move the character one column to the left, unless it is already
# at the left edge of the playing field.
move_left:
    lw $t0, player_col
    blez $t0, ml_done
    addi $t0, $t0, -1
    sw $t0, player_col
ml_done:
    jr $ra

# move_right: move the character one column to the right, unless it is
# already at the right edge of the playing field.
move_right:
    lw $t0, player_col
    li $t1, 6
    bge $t0, $t1, mr_done
    addi $t0, $t0, 1
    sw $t0, player_col
mr_done:
    jr $ra

# handle_grab: grab the bottom-most bubble of the character's column together
# with all bubbles of the same colour stacked directly above it. If the
# character already holds bubbles, only bubbles of that colour can be added.
handle_grab:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a0, player_col
    jal find_lowest                 # $v0 = row of the lowest bubble, or -1
    bltz $v0, hg_done               # the column is empty
    la $t0, grid
    sll $t1, $v0, 3
    sub $t1, $t1, $v0               # 7 * row
    lw $t2, player_col
    add $t1, $t1, $t2
    sll $t1, $t1, 2
    add $t0, $t0, $t1               # $t0 = address of the lowest bubble
    lw $t3, 0($t0)                  # $t3 = its colour
    lw $t4, held_count
    beq $t4, $zero, hg_take
    lw $t5, held_colour
    bne $t5, $t3, hg_blocked        # holding a different colour
hg_take:
    sw $t3, held_colour
hg_loop:
    sw $zero, 0($t0)                # remove the bubble from the field
    addi $t4, $t4, 1                # and add it to the held bubbles
    addi $v0, $v0, -1               # move up one row
    bltz $v0, hg_taken
    addi $t0, $t0, -28
    lw $t6, 0($t0)
    beq $t6, $t3, hg_loop           # same colour: grab it as well
hg_taken:
    sw $t4, held_count
    li $t0, 1
    sw $t0, hud_dirty
    li $a0, 60
    li $a1, 100
    li $a2, 12
    jal play_sound
    jal validate_next_row
    j hg_done
hg_blocked:
    li $a0, 36
    li $a1, 150
    li $a2, 0
    jal play_sound
hg_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# handle_throw: throw the held bubbles up into the character's column. They
# land directly below the lowest bubble of that column (rows 0..12 only; the
# character's row is never used). Bubbles that do not fit stay in the hand.
# Afterwards matches and chain reactions are resolved.
handle_throw:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    lw $s0, held_count              # $s0 = bubbles still in the hand
    beq $s0, $zero, ht_done
    lw $a0, player_col
    jal find_lowest
    addi $s1, $v0, 1                # $s1 = landing row (first free row)
    li $t0, 13
    bge $s1, $t0, ht_blocked        # no room in this column

    # Animation: a bubble flies from the character up to the landing row.
    li $s2, 12
ht_fly:
    ble $s2, $s1, ht_place
    lw $a0, player_col
    sll $a0, $a0, 2
    addi $a0, $a0, 2
    sll $a1, $s2, 2
    addi $a1, $a1, 6
    lw $a2, held_colour
    jal draw_bubble
    li $a0, 12
    jal sleep_ms
    lw $a0, player_col
    sll $a0, $a0, 2
    addi $a0, $a0, 2
    sll $a1, $s2, 2
    addi $a1, $a1, 6
    li $a2, 0
    jal draw_bubble
    addi $s2, $s2, -1
    j ht_fly

ht_place:
    la $t0, grid
    sll $t1, $s1, 3
    sub $t1, $t1, $s1               # 7 * landing row
    lw $t2, player_col
    add $t1, $t1, $t2
    sll $t1, $t1, 2
    add $t0, $t0, $t1               # $t0 = address of the landing cell
    lw $t3, held_colour
    li $t4, 13
ht_place_loop:
    beq $s0, $zero, ht_placed       # nothing left in the hand
    bge $s1, $t4, ht_placed         # reached the character's row
    sw $t3, 0($t0)
    addi $t0, $t0, 28
    addi $s1, $s1, 1
    addi $s0, $s0, -1
    j ht_place_loop
ht_placed:
    sw $s0, held_count
    bne $s0, $zero, ht_still_holding
    sw $zero, held_colour
ht_still_holding:
    li $t0, 1
    sw $t0, hud_dirty
    li $a0, 72
    li $a1, 100
    li $a2, 12
    jal play_sound
    jal draw_board
    jal resolve_matches
    jal validate_next_row
    j ht_done
ht_blocked:
    li $a0, 36
    li $a1, 150
    li $a2, 0
    jal play_sound
ht_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# pause_game: show "PAUSED" until p is pressed again (q still quits).
pause_game:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 1
    li $a1, 26
    li $a2, 29
    li $a3, 11
    jal clear_rect
    li $a0, 4
    li $a1, 29
    la $a2, str_paused
    li $a3, 0xffffff
    jal draw_string
pg_wait:
    li $a0, 30
    jal sleep_ms
    lw $t0, keyboard_address
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beq $t1, $zero, pg_wait
    lw $t2, 4($t0)
    ori $t2, $t2, 0x20
    beq $t2, 0x71, exit_game        # q
    li $t3, 0x70                    # p
    bne $t2, $t3, pg_wait
    jal draw_static_scene           # repaint everything and resume
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Field logic
##############################################################################

# find_lowest: $a0 = column.
# Returns $v0 = row of the lowest (bottom-most) bubble in that column, or -1
# if the column is empty. Only changes $t0-$t2 and $v0.
find_lowest:
    la $t0, grid
    li $v0, 13
fl_loop:
    sll $t1, $v0, 3
    sub $t1, $t1, $v0               # 7 * row
    add $t1, $t1, $a0
    sll $t1, $t1, 2
    add $t1, $t1, $t0
    lw $t2, 0($t1)
    bne $t2, $zero, fl_done
    addi $v0, $v0, -1
    bgez $v0, fl_loop
fl_done:
    jr $ra

# random_colour: returns a random bubble colour (1..4) in $v0.
random_colour:
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall                         # $a0 = random number in 0..3
    addi $v0, $a0, 1
    jr $ra

# gen_next_row: fill next_row with seven random bubbles.
gen_next_row:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    li $s0, 0
gn_loop:
    jal random_colour
    la $t0, next_row
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    sw $v0, 0($t0)
    addi $s0, $s0, 1
    li $t0, 7
    blt $s0, $t0, gn_loop
    jal validate_next_row
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# validate_next_row: make sure the next row will not arrive already forming a
# vertical match-3 (hard feature 4). A bubble of next_row is re-rolled while
# it has the same colour as the two top bubbles of its column.
validate_next_row:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    li $s0, 0                       # column
vn_loop:
    la $t0, grid
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $t2, 0($t0)                  # grid[0][c]
    beq $t2, $zero, vn_next
    lw $t3, 28($t0)                 # grid[1][c]
    bne $t2, $t3, vn_next
    la $t4, next_row
    add $t4, $t4, $t1
    lw $t5, 0($t4)
    bne $t5, $t2, vn_next
    jal random_colour               # conflict: pick a new colour, check again
    la $t4, next_row
    sll $t1, $s0, 2
    add $t4, $t4, $t1
    sw $v0, 0($t4)
    j vn_loop
vn_next:
    addi $s0, $s0, 1
    li $t0, 7
    blt $s0, $t0, vn_loop
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# push_row: push every bubble down by one row, put next_row into the top row
# and generate a new next_row.
push_row:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, grid
    li $t1, 97                      # from the last cell back to cell 7
pr_shift:
    sll $t2, $t1, 2
    add $t2, $t2, $t0
    lw $t3, -28($t2)                # the cell directly above
    sw $t3, 0($t2)
    addi $t1, $t1, -1
    li $t4, 7
    bge $t1, $t4, pr_shift
    la $t5, next_row
    li $t1, 0
pr_copy:
    sll $t2, $t1, 2
    add $t3, $t2, $t5
    lw $t4, 0($t3)
    add $t3, $t2, $t0
    sw $t4, 0($t3)
    addi $t1, $t1, 1
    li $t4, 7
    blt $t1, $t4, pr_copy
    jal gen_next_row
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# advance_row: a new row arrives at the top of the field.
# Returns $v0 = 1 if a bubble has reached the character's row (game over).
advance_row:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal push_row
    lw $t0, rows_left
    addi $t0, $t0, -1
    sw $t0, rows_left
    li $t0, 1
    sw $t0, hud_dirty
    li $a0, 43
    li $a1, 150
    li $a2, 0
    jal play_sound
    la $t0, grid
    addi $t0, $t0, 364              # first cell of row 13
    li $t1, 7
    li $v0, 0
ar_check:
    lw $t2, 0($t0)
    beq $t2, $zero, ar_next
    li $v0, 1
ar_next:
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, ar_check
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# resolve_matches: the complete matching process. Repeats
#   trigger (vertical match-3) -> flood fill -> explosion -> gravity
# until no vertical match-3 remains (chain reactions), and updates the score.
resolve_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    sw $zero, chain_depth
rm_loop:
    jal find_matches                # $v0 = number of triggering bubbles
    beq $v0, $zero, rm_done
    jal flood_fill
    lw $t0, chain_depth
    addi $t0, $t0, 1
    sw $t0, chain_depth
    jal explode_animation
    jal remove_marked               # $v0 = number of bubbles removed

    # points = bubbles removed * 10 * chain depth * difficulty multiplier
    lw $t0, cleared_total
    add $t0, $t0, $v0
    sw $t0, cleared_total
    li $t1, 10
    mult $v0, $t1
    mflo $t2
    lw $t3, chain_depth
    mult $t2, $t3
    mflo $t2
    lw $t3, score_mult
    mult $t2, $t3
    mflo $t2
    lw $t4, score
    add $t4, $t4, $t2
    li $t5, 999999
    ble $t4, $t5, rm_score_ok
    move $t4, $t5
rm_score_ok:
    sw $t4, score
    lw $t5, high_score
    ble $t4, $t5, rm_not_best
    sw $t4, high_score
rm_not_best:
    li $t0, 1
    sw $t0, hud_dirty
    jal draw_hud

    # Show the holes, then let the unsupported bubbles float up row by row.
    jal draw_board
    li $a0, 60
    jal sleep_ms
rm_float:
    jal float_step                  # $v0 = 1 if a bubble moved
    beq $v0, $zero, rm_loop
    jal draw_board
    li $a0, 40
    jal sleep_ms
    j rm_float
rm_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# find_matches: the trigger stage. Every vertical run of three or more
# bubbles of the same colour is marked and pushed on the flood fill stack.
# Returns $v0 = number of bubbles marked (0 if there is no match).
find_matches:
    la $t0, grid
    la $t1, mark
    la $t2, ff_stack
    li $t3, 0                       # number of entries on the stack
    li $t4, 0                       # column
fm_col:
    li $t5, 0                       # row
fm_row:
    sll $t6, $t5, 3
    sub $t6, $t6, $t5
    add $t6, $t6, $t4               # $t6 = cell index = 7 * row + column
    sll $t7, $t6, 2
    add $t7, $t7, $t0
    lw $t8, 0($t7)                  # $t8 = colour of this cell
    li $t9, 1                       # $t9 = length of the run starting here
    beq $t8, $zero, fm_advance      # empty cell
    move $a0, $t5
fm_run:
    addi $a0, $a0, 1
    li $a1, 14
    bge $a0, $a1, fm_run_end
    addi $t7, $t7, 28               # the cell directly below
    lw $a2, 0($t7)
    bne $a2, $t8, fm_run_end
    addi $t9, $t9, 1
    j fm_run
fm_run_end:
    li $a1, 3
    blt $t9, $a1, fm_advance
    move $a0, $t6                   # mark the whole run
    move $a1, $t9
fm_mark:
    sll $a2, $a0, 2
    add $a3, $a2, $t1
    li $v0, 1
    sw $v0, 0($a3)                  # mark[index] = 1
    sll $a3, $t3, 2
    add $a3, $a3, $t2
    sw $a0, 0($a3)                  # push index
    addi $t3, $t3, 1
    addi $a0, $a0, 7
    addi $a1, $a1, -1
    bgtz $a1, fm_mark
fm_advance:
    add $t5, $t5, $t9               # skip the run that was just examined
    li $a1, 14
    blt $t5, $a1, fm_row
    addi $t4, $t4, 1
    li $a1, 7
    blt $t4, $a1, fm_col
    sw $t3, ff_count
    move $v0, $t3
    jr $ra

# flood_fill: the explosion stage. Starting from the bubbles marked by
# find_matches, every bubble of the same colour that is connected to them
# (left, right, above or below) is marked as well.
flood_fill:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, grid
    la $t1, mark
    la $t2, ff_stack
    lw $t3, ff_count
ff_loop:
    beq $t3, $zero, ff_done
    addi $t3, $t3, -1               # pop a cell index
    sll $t4, $t3, 2
    add $t4, $t4, $t2
    lw $t5, 0($t4)                  # $t5 = cell index
    sll $t6, $t5, 2
    add $t6, $t6, $t0
    lw $t7, 0($t6)                  # $t7 = colour of that cell
    li $t8, 7
    div $t5, $t8
    mfhi $t9                        # $t9 = column of that cell
    blt $t5, $t8, ff_no_up          # row 0 has no neighbour above
    addi $a0, $t5, -7
    jal ff_try
ff_no_up:
    li $t8, 91
    bge $t5, $t8, ff_no_down        # row 13 has no neighbour below
    addi $a0, $t5, 7
    jal ff_try
ff_no_down:
    beq $t9, $zero, ff_no_left      # column 0 has no left neighbour
    addi $a0, $t5, -1
    jal ff_try
ff_no_left:
    li $t8, 6
    beq $t9, $t8, ff_loop           # column 6 has no right neighbour
    addi $a0, $t5, 1
    jal ff_try
    j ff_loop
ff_done:
    sw $zero, ff_count
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ff_try: helper of flood_fill. $a0 = index of a neighbouring cell. If that
# cell is not marked yet and has the colour in $t7, mark it and push it.
# Uses the registers set up by flood_fill ($t0-$t3, $t7); changes $a1-$a3.
ff_try:
    sll $a1, $a0, 2
    add $a2, $a1, $t1
    lw $a3, 0($a2)
    bne $a3, $zero, ff_try_done     # already marked
    add $a3, $a1, $t0
    lw $a3, 0($a3)
    bne $a3, $t7, ff_try_done       # a different colour (or empty)
    li $a3, 1
    sw $a3, 0($a2)                  # mark it
    sll $a3, $t3, 2
    add $a3, $a3, $t2
    sw $a0, 0($a3)                  # push it
    addi $t3, $t3, 1
ff_try_done:
    jr $ra

# remove_marked: delete every marked bubble from the field and clear the
# marks. Returns $v0 = number of bubbles removed.
remove_marked:
    la $t0, grid
    la $t1, mark
    li $t2, 98
    li $v0, 0
rk_loop:
    lw $t3, 0($t1)
    beq $t3, $zero, rk_next
    sw $zero, 0($t0)
    sw $zero, 0($t1)
    addi $v0, $v0, 1
rk_next:
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    bgtz $t2, rk_loop
    jr $ra

# float_step: one step of gravity. Every bubble with an empty cell directly
# above it moves up by one row. Returns $v0 = 1 if any bubble moved.
float_step:
    la $t0, grid
    li $v0, 0
    li $t1, 7                       # cell index, starting with row 1
    li $t5, 98
fs_loop:
    sll $t2, $t1, 2
    add $t2, $t2, $t0
    lw $t3, 0($t2)
    beq $t3, $zero, fs_next         # nothing here
    lw $t4, -28($t2)
    bne $t4, $zero, fs_next         # supported by the bubble above
    sw $t3, -28($t2)                # float up one row
    sw $zero, 0($t2)
    li $v0, 1
fs_next:
    addi $t1, $t1, 1
    blt $t1, $t5, fs_loop
    jr $ra

##############################################################################
# Drawing
##############################################################################

# draw_scene: repaint everything that can change during the game.
draw_scene:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_preview
    jal draw_board
    jal draw_aim
    jal draw_timer_bar
    jal draw_hud
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draw_static_scene: clear the screen and draw everything that never changes
# during a game (walls and HUD labels).
draw_static_scene:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal clear_screen
    li $a0, 0                       # top wall
    li $a1, 0
    li $a2, 31
    li $a3, 0x808080
    jal draw_hline
    li $a0, 0                       # separator under the preview panel
    li $a1, 4
    li $a2, 31
    li $a3, 0x808080
    jal draw_hline
    li $a0, 0                       # bottom wall
    li $a1, 62
    li $a2, 31
    li $a3, 0x808080
    jal draw_hline
    li $a0, 0                       # left wall
    li $a1, 0
    li $a2, 63
    li $a3, 0x808080
    jal draw_vline
    li $a0, 30                      # right wall
    li $a1, 0
    li $a2, 63
    li $a3, 0x808080
    jal draw_vline
    li $a0, 1                       # line above the character's row
    li $a1, 57
    li $a2, 29
    li $a3, 0x700000
    jal draw_hline

    li $a0, 33
    li $a1, 1
    la $a2, str_score
    li $a3, 0x90b0ff
    jal draw_string
    li $a0, 33
    li $a1, 14
    la $a2, str_best
    li $a3, 0x90b0ff
    jal draw_string
    li $a0, 33
    li $a1, 27
    la $a2, str_left
    li $a3, 0x90b0ff
    jal draw_string
    li $a0, 33
    li $a1, 40
    la $a2, str_hold
    li $a3, 0x90b0ff
    jal draw_string

    # Name of the current mode.
    lw $t0, difficulty
    la $a2, str_easy
    li $a3, 0x10c030
    li $t1, 1
    beq $t0, $t1, dss_mode
    la $a2, str_medium
    li $a3, 0xf0d000
    li $t1, 2
    beq $t0, $t1, dss_mode
    la $a2, str_hard
    li $a3, 0xe02020
    li $t1, 3
    beq $t0, $t1, dss_mode
    la $a2, str_keys
    li $a3, 0x90b0ff
dss_mode:
    li $a0, 33
    li $a1, 56
    jal draw_string

    li $t0, 1
    sw $t0, hud_dirty
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draw_hud: redraw the HUD numbers, but only when one of them has changed.
draw_hud:
    lw $t0, hud_dirty
    beq $t0, $zero, dh_skip
    sw $zero, hud_dirty
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 33
    li $a1, 7
    lw $a2, score
    li $a3, 6
    jal draw_number
    li $a0, 33
    li $a1, 20
    lw $a2, high_score
    li $a3, 6
    jal draw_number
    li $a0, 33
    li $a1, 33
    lw $a2, rows_left
    li $a3, 3
    jal draw_number
    li $a0, 33                      # the held bubbles: colour and count
    li $a1, 47
    li $a2, 0
    lw $t0, held_count
    beq $t0, $zero, dh_icon
    lw $a2, held_colour
dh_icon:
    jal draw_bubble
    li $a0, 38
    li $a1, 46
    lw $a2, held_count
    li $a3, 2
    jal draw_number
    lw $ra, 0($sp)
    addi $sp, $sp, 4
dh_skip:
    jr $ra

# draw_preview: draw next_row in the preview panel above the field.
draw_preview:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    li $s0, 0
dpv_loop:
    sll $a0, $s0, 2
    addi $a0, $a0, 2
    li $a1, 1
    la $t0, next_row
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $a2, 0($t0)
    jal draw_bubble
    addi $s0, $s0, 1
    li $t0, 7
    blt $s0, $t0, dpv_loop
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# draw_board: draw the playing field and the character.
draw_board:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_grid
    jal draw_player
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draw_grid: draw all 14 x 7 cells of the playing field.
draw_grid:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    la $s2, grid                    # address of the current cell
    li $s0, 0                       # row
dg_row:
    li $s1, 0                       # column
dg_col:
    sll $a0, $s1, 2
    addi $a0, $a0, 2                # x = 2 + 4 * column
    sll $a1, $s0, 2
    addi $a1, $a1, 6                # y = 6 + 4 * row
    lw $a2, 0($s2)
    jal draw_bubble
    addi $s2, $s2, 4
    addi $s1, $s1, 1
    li $t0, 7
    blt $s1, $t0, dg_col
    addi $s0, $s0, 1
    li $t0, 14
    blt $s0, $t0, dg_row
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# draw_marked: $a0 = palette entry. Draw every marked cell with that palette
# entry (used by the explosion animation).
draw_marked:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    move $s3, $a0
    la $s2, mark
    li $s0, 0                       # row
dm_row:
    li $s1, 0                       # column
dm_col:
    lw $t0, 0($s2)
    beq $t0, $zero, dm_next
    sll $a0, $s1, 2
    addi $a0, $a0, 2
    sll $a1, $s0, 2
    addi $a1, $a1, 6
    move $a2, $s3
    jal draw_bubble
dm_next:
    addi $s2, $s2, 4
    addi $s1, $s1, 1
    li $t0, 7
    blt $s1, $t0, dm_col
    addi $s0, $s0, 1
    li $t0, 14
    blt $s0, $t0, dm_row
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# explode_animation: the marked bubbles flash white and shrink away. The
# sound gets higher with every step of a chain reaction.
explode_animation:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    lw $t0, chain_depth
    sll $a0, $t0, 1
    add $a0, $a0, $t0
    addi $a0, $a0, 73               # pitch = 73 + 3 * chain depth
    li $t1, 120
    ble $a0, $t1, ea_pitch_ok
    move $a0, $t1
ea_pitch_ok:
    li $a1, 300
    li $a2, 9
    jal play_sound
    li $s0, 6                       # palette entries 6, 7, 8
ea_loop:
    move $a0, $s0
    jal draw_marked
    li $a0, 70
    jal sleep_ms
    addi $s0, $s0, 1
    li $t0, 9
    blt $s0, $t0, ea_loop
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# draw_bubble: $a0 = x, $a1 = y (top-left unit), $a2 = palette entry.
# Draws one 3 x 3 bubble (entry 0 erases the cell). Only changes $t0-$t4.
draw_bubble:
    lw $t0, display_address
    sll $t1, $a1, 8                 # y * 64 units * 4 bytes
    add $t0, $t0, $t1
    sll $t1, $a0, 2                 # x * 4 bytes
    add $t0, $t0, $t1               # $t0 = address of the top-left unit
    la $t1, palette
    sll $t2, $a2, 3
    sll $t3, $a2, 2
    add $t2, $t2, $t3               # 12 bytes per palette entry
    add $t1, $t1, $t2
    lw $t2, 0($t1)                  # dark shade
    lw $t3, 4($t1)                  # base colour
    lw $t4, 8($t1)                  # light shade
    sw $t2, 0($t0)
    sw $t3, 4($t0)
    sw $t2, 8($t0)
    sw $t3, 256($t0)
    sw $t4, 260($t0)
    sw $t3, 264($t0)
    sw $t2, 512($t0)
    sw $t3, 516($t0)
    sw $t2, 520($t0)
    jr $ra

# draw_player: draw the character in its column of the bottom row. The centre
# of the sprite shows the colour of the held bubbles.
draw_player:
    lw $t0, display_address
    lw $t1, player_col
    sll $t1, $t1, 4                 # 4 units per column * 4 bytes
    addi $t1, $t1, 14856            # row 13: y = 58 -> 58 * 256, plus x = 2 -> 8
    add $t0, $t0, $t1               # $t0 = address of the top-left unit
    la $t1, player_sprite
    lw $t2, 16($t1)                 # centre unit of the sprite
    lw $t3, held_count
    beq $t3, $zero, dp_centre
    lw $t3, held_colour             # holding: use the bubble's base colour
    la $t4, palette
    sll $t5, $t3, 3
    sll $t3, $t3, 2
    add $t5, $t5, $t3
    add $t4, $t4, $t5
    lw $t2, 4($t4)
dp_centre:
    lw $t3, 0($t1)
    sw $t3, 0($t0)
    lw $t3, 4($t1)
    sw $t3, 4($t0)
    lw $t3, 8($t1)
    sw $t3, 8($t0)
    lw $t3, 12($t1)
    sw $t3, 256($t0)
    sw $t2, 260($t0)
    lw $t3, 20($t1)
    sw $t3, 264($t0)
    lw $t3, 24($t1)
    sw $t3, 512($t0)
    lw $t3, 28($t1)
    sw $t3, 516($t0)
    lw $t3, 32($t1)
    sw $t3, 520($t0)
    jr $ra

# draw_aim: a dotted line in the character's column, from the lowest bubble
# down to the character, that flashes on and off (hard feature 6). The dots
# take the colour of the held bubbles.
draw_aim:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, frame_count
    andi $t0, $t0, 16               # on for 16 frames, off for 16 frames
    bne $t0, $zero, da_done
    lw $a0, player_col
    jal find_lowest
    addi $t3, $v0, 1                # first empty row of the column
    li $t5, 0x707070                # colour of the dots
    lw $t6, held_count
    beq $t6, $zero, da_colour_ok
    lw $t6, held_colour
    la $t7, palette
    sll $t8, $t6, 3
    sll $t6, $t6, 2
    add $t8, $t8, $t6
    add $t7, $t7, $t8
    lw $t5, 4($t7)
da_colour_ok:
    lw $t0, display_address
    lw $t1, player_col
    sll $t1, $t1, 4
    addi $t1, $t1, 12               # x = 2 + 4 * column + 1, times 4 bytes
    add $t0, $t0, $t1
    li $t4, 13
da_loop:
    bge $t3, $t4, da_done           # rows up to 12 only
    sll $t2, $t3, 10                # 4 units per row * 256 bytes
    addi $t2, $t2, 1792             # y = 6 + 4 * row + 1 -> 7 * 256
    add $t2, $t2, $t0
    sw $t5, 0($t2)
    addi $t3, $t3, 1
    j da_loop
da_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draw_timer_bar: the separator under the preview panel fills up from left to
# right while the next row is getting closer.
draw_timer_bar:
    lw $t0, difficulty
    li $t1, 4
    beq $t0, $t1, tb_keys
    lw $t2, row_timer               # progress
    lw $t3, row_interval            # out of
    j tb_calc
tb_keys:
    lw $t2, key_count
    li $t3, 10
tb_calc:
    li $t4, 29
    mult $t2, $t4
    mflo $t2
    div $t2, $t3
    mflo $t2                        # $t2 = number of filled units (0..29)
    lw $t0, display_address
    addi $t0, $t0, 1028             # x = 1, y = 4
    li $t5, 0
    li $t6, 29
tb_loop:
    li $t7, 0x808080
    bge $t5, $t2, tb_put
    li $t7, 0xff8000
tb_put:
    sw $t7, 0($t0)
    addi $t0, $t0, 4
    addi $t5, $t5, 1
    blt $t5, $t6, tb_loop
    jr $ra

# draw_char: $a0 = x, $a1 = y (top-left unit), $a2 = ASCII code, $a3 = colour.
# Draws one 3 x 5 character; units that are off are painted black. Characters
# other than 0-9 and A-Z are drawn as a blank.
draw_char:
    li $t0, 0                       # glyph bits (blank by default)
    li $t1, 48
    blt $a2, $t1, dc_have_glyph
    li $t1, 58
    blt $a2, $t1, dc_digit
    li $t1, 65
    blt $a2, $t1, dc_have_glyph
    li $t1, 91
    bge $a2, $t1, dc_have_glyph
    addi $t2, $a2, -55              # 'A' -> glyph 10
    j dc_lookup
dc_digit:
    addi $t2, $a2, -48              # '0' -> glyph 0
dc_lookup:
    la $t3, font
    sll $t2, $t2, 2
    add $t3, $t3, $t2
    lw $t0, 0($t3)
dc_have_glyph:
    lw $t3, display_address
    sll $t4, $a1, 8
    add $t3, $t3, $t4
    sll $t4, $a0, 2
    add $t3, $t3, $t4               # $t3 = address of the top-left unit
    li $t5, 0x4000                  # mask, starting with bit 14
    li $t6, 5                       # rows left
dc_row:
    li $t7, 3                       # columns left
dc_col:
    and $t8, $t0, $t5
    li $t9, 0
    beq $t8, $zero, dc_put
    move $t9, $a3
dc_put:
    sw $t9, 0($t3)
    addi $t3, $t3, 4
    srl $t5, $t5, 1
    addi $t7, $t7, -1
    bgtz $t7, dc_col
    addi $t3, $t3, 244              # start of the next row (256 - 12)
    addi $t6, $t6, -1
    bgtz $t6, dc_row
    jr $ra

# draw_string: $a0 = x, $a1 = y, $a2 = address of a null-terminated string,
# $a3 = colour. Draws the string with 4 units per character.
draw_string:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
ds_loop:
    lbu $a2, 0($s2)
    beq $a2, $zero, ds_done
    move $a0, $s0
    move $a1, $s1
    move $a3, $s3
    jal draw_char
    addi $s0, $s0, 4
    addi $s2, $s2, 1
    j ds_loop
ds_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# draw_number: $a0 = x of the left-most digit, $a1 = y, $a2 = value,
# $a3 = number of digits. Draws the value in white with leading zeros.
draw_number:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    addi $t0, $a3, -1
    sll $t0, $t0, 2
    add $s0, $a0, $t0               # x of the right-most digit
    move $s1, $a1
    move $s2, $a2                   # value still to be drawn
    move $s3, $a3                   # digits left
dn_loop:
    li $t0, 10
    div $s2, $t0
    mflo $s2                        # value / 10
    mfhi $a2                        # value % 10
    addi $a2, $a2, 48
    move $a0, $s0
    move $a1, $s1
    li $a3, 0xffffff
    jal draw_char
    addi $s0, $s0, -4
    addi $s3, $s3, -1
    bgtz $s3, dn_loop
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# draw_hline: $a0 = x, $a1 = y, $a2 = length, $a3 = colour.
draw_hline:
    lw $t0, display_address
    sll $t1, $a1, 8
    add $t0, $t0, $t1
    sll $t1, $a0, 2
    add $t0, $t0, $t1
hl_loop:
    sw $a3, 0($t0)
    addi $t0, $t0, 4
    addi $a2, $a2, -1
    bgtz $a2, hl_loop
    jr $ra

# draw_vline: $a0 = x, $a1 = y, $a2 = length, $a3 = colour.
draw_vline:
    lw $t0, display_address
    sll $t1, $a1, 8
    add $t0, $t0, $t1
    sll $t1, $a0, 2
    add $t0, $t0, $t1
vl_loop:
    sw $a3, 0($t0)
    addi $t0, $t0, 256
    addi $a2, $a2, -1
    bgtz $a2, vl_loop
    jr $ra

# clear_rect: $a0 = x, $a1 = y, $a2 = width, $a3 = height. Paints it black.
clear_rect:
    lw $t0, display_address
    sll $t1, $a1, 8
    add $t0, $t0, $t1
    sll $t1, $a0, 2
    add $t0, $t0, $t1               # address of the top-left unit
cr_row:
    move $t1, $t0
    move $t2, $a2
cr_col:
    sw $zero, 0($t1)
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    bgtz $t2, cr_col
    addi $t0, $t0, 256
    addi $a3, $a3, -1
    bgtz $a3, cr_row
    jr $ra

# clear_screen: paint all 64 x 64 units black.
clear_screen:
    lw $t0, display_address
    li $t1, 4096
cs_loop:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, cs_loop
    jr $ra

##############################################################################
# Small helpers
##############################################################################

# clear_words: $a0 = address, $a1 = number of words to set to zero.
clear_words:
    sw $zero, 0($a0)
    addi $a0, $a0, 4
    addi $a1, $a1, -1
    bgtz $a1, clear_words
    jr $ra

# sleep_ms: $a0 = number of milliseconds to sleep.
sleep_ms:
    li $v0, 32
    syscall
    jr $ra

# play_sound: $a0 = pitch (0-127), $a1 = duration in milliseconds,
# $a2 = instrument (0-127). Plays the note without waiting for it to end.
play_sound:
    li $a3, 100                     # volume
    li $v0, 31
    syscall
    jr $ra
