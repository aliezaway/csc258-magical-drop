################################################################################
# CSC258 Assembly Project: Magical Drop
#
# Student 1: Xiangyu Zhou, 1012571708
# Student 2: Belina Zhu, 1011889262
#
######################## Bitmap Display Configuration ##########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   512
# - Base Address for Display:   0x10008000 ($gp)
#   (the display is therefore 32 x 64 units)
################################################################################
#
# Milestones reached: 1, 2, 3, 4, 5
#   (2 easy + 4 hard features: Milestone 5 through combination d or e)
#
# Easy features implemented (numbers refer to the project handout):
#   1. Row advancement on a timer: the first timer row comes after 500 frames
#   2. Row advancement gets faster: 50 frames less after every new row,
#      down to 150 frames
#
# Hard features implemented:
#   2. Flood fill (horizontal + vertical) after the vertical match-3 trigger
#   3. Gravity: unsupported bubbles float upwards
#   5. Chain reactions: if gravity lines up a new match-3, the matching and
#      removal process repeats until no match remains
#   6. Flashing dotted aiming line in the character's column
#
# How to play:
#   a / d = move the character left / right
#   s     = grab the bottom-most bubble of the column above, together with the
#           bubbles of the same colour stacked directly above it
#   w     = throw the held bubbles back up into the column above (the flashing
#           dotted line shows where they will land)
#   q     = quit
#   A new row arrives after 10 keystrokes (a, d, s, w) or when the row timer
#   runs out, whichever comes first. The game is over when a bubble reaches
#   the character's row.
#
################################################################################
#
# Screen layout (in units, x to the right, y downwards):
#   x = 0 and x = 30      side walls of the playing field
#   y = 0 and y = 58      top and bottom walls
#   y = 53                red line above the character's row
#   grid cell (r, c)      3 x 3 units with its top-left corner at
#                         x = 2 + 4*c,  y = 2 + 4*r      (r = 0..13, c = 0..6)
#   row 13                the character's row (a bubble here = game over)
#   aiming line           the centre unit of every empty cell of the
#                         character's column (rows 0..12)
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
# Number of entries currently on ff_stack.
ff_count:       .word 0

# The character and the bubbles it is holding.
player_col:     .word 3     # column of the character (0..6)
held_colour:    .word 0     # colour of the held bubbles (0 = none)
held_count:     .word 0     # how many bubbles are held

# Row advancement.
row_timer:      .word 0     # frames since the last new row
key_count:      .word 0     # keystrokes (a, d, s, w) since the last new row
row_interval:   .word 500   # frames until the next timer row (easy 1 and 2)

# Frames drawn so far (makes the aiming line flash).
frame_count:    .word 0

##############################################################################
# Colours
##############################################################################
# Bubble palette: three shades (dark, base, light) per colour.
# A bubble is drawn as    dark  base  dark
#                         base  light base
#                         dark  base  dark
palette:
    .word 0x000000, 0x000000, 0x000000      # 0 empty cell
    .word 0x900000, 0xe02020, 0xff9090      # 1 red
    .word 0x907000, 0xf0d000, 0xffff90      # 2 yellow
    .word 0x006000, 0x10c030, 0x90ff90      # 3 green
    .word 0x001090, 0x2050f0, 0x90b0ff      # 4 blue

# The character, 3 x 3 units, row major order. The centre unit is replaced by
# the colour of the held bubbles while the character is holding something.
player_sprite:
    .word 0x000000, 0xffffff, 0x000000
    .word 0xc0c0c0, 0xff60c0, 0xc0c0c0
    .word 0xffffff, 0x000000, 0xffffff

##############################################################################
# Code
##############################################################################
    .text
    .globl main

# Run the game.
main:
    # Milestone 1: start with five rows of random bubbles.
    li $s0, 5
init_rows:
    jal push_row
    addi $s0, $s0, -1
    bgtz $s0, init_rows
    jal resolve_matches             # random rows may already hold a match-3
    jal draw_walls

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

    # 2. Process the player's action (3. a throw also resolves the matches).
    beq $t2, 0x61, gl_key_a
    beq $t2, 0x64, gl_key_d
    beq $t2, 0x73, gl_key_s
    beq $t2, 0x77, gl_key_w
    beq $t2, 0x71, quit_game
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
gl_count_key:
    lw $t0, key_count
    addi $t0, $t0, 1
    sw $t0, key_count
gl_no_key:

    # 4. Check for row advancement: after 10 keystrokes (Milestone 2) or when
    #    the timer runs out (easy feature 1), whichever comes first.
    lw $t0, key_count
    li $t1, 10
    bge $t0, $t1, gl_new_row
    lw $t0, row_timer
    addi $t0, $t0, 1
    sw $t0, row_timer
    lw $t1, row_interval
    blt $t0, $t1, gl_draw
gl_new_row:
    sw $zero, key_count
    sw $zero, row_timer
    jal advance_row                 # $v0 = 1 if a bubble reached the bottom row
    bne $v0, $zero, game_over
    # Easy feature 2: the next timer row comes 50 frames sooner (at least 150).
    lw $t0, row_interval
    addi $t0, $t0, -50
    li $t1, 150
    bge $t0, $t1, gl_speed_ok
    move $t0, $t1
gl_speed_ok:
    sw $t0, row_interval

gl_draw:
    # 5. Redraw the screen.
    lw $t0, frame_count
    addi $t0, $t0, 1
    sw $t0, frame_count
    jal draw_board

    # 6. Sleep (about 60 frames per second).
    li $a0, 16
    jal sleep_ms

    # 7. Go back to step 1.
    j game_loop

##############################################################################
# Game over: show the final field and stop the program. The character is only
# drawn if its own cell is still empty, so a bubble that reached the
# character's row is never hidden behind the character.
##############################################################################
game_over:
    jal draw_grid                   # the whole field, including row 13
    la $t0, grid
    lw $t1, player_col
    sll $t1, $t1, 2
    add $t0, $t0, $t1
    lw $t2, 364($t0)                # grid[13][player_col] (row 13 starts at 4 * 91)
    bne $t2, $zero, quit_game       # a bubble is on the character's cell: show it
    jal draw_player
quit_game:
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
    bne $t5, $t3, hg_done           # holding a different colour: do nothing
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
hg_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# handle_throw: throw the held bubbles up into the character's column. They
# land directly below the lowest bubble of that column (rows 0..12 only; the
# character's row is never used). Bubbles that do not fit stay in the hand.
# Afterwards the matches are resolved.
handle_throw:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    lw $s0, held_count              # $s0 = bubbles still in the hand
    beq $s0, $zero, ht_done
    lw $a0, player_col
    jal find_lowest
    addi $s1, $v0, 1                # $s1 = landing row (first free row)
    li $t0, 13
    bge $s1, $t0, ht_done           # no room in this column: keep holding
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
    addi $t0, $t0, 28               # the cell below
    addi $s1, $s1, 1
    addi $s0, $s0, -1
    j ht_place_loop
ht_placed:
    sw $s0, held_count
    bne $s0, $zero, ht_match
    sw $zero, held_colour           # the hand is empty
ht_match:
    jal resolve_matches             # Milestone 3c and hard features 2, 3
ht_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
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

# push_row: push every bubble down by one row and fill the top row with
# seven random bubbles.
push_row:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
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
    li $s0, 0                       # column of the top row
pr_fill:
    jal random_colour
    la $t0, grid
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    sw $v0, 0($t0)
    addi $s0, $s0, 1
    li $t0, 7
    blt $s0, $t0, pr_fill
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# advance_row: a new row arrives at the top of the field.
# Returns $v0 = 1 if a bubble has reached the character's row (game over).
# Otherwise the matches the new row may have completed are resolved.
advance_row:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal push_row
    la $t0, grid
    addi $t0, $t0, 364              # first cell of row 13 (4 * 7 * 13)
    li $t1, 7
ar_check:
    lw $t2, 0($t0)
    bne $t2, $zero, ar_lose         # a bubble in the character's row
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, ar_check
    jal resolve_matches
    li $v0, 0
    j ar_done
ar_lose:
    li $v0, 1
ar_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# resolve_matches: the complete matching process. Repeats
#   trigger (vertical match-3) -> flood fill -> remove -> gravity
# until no vertical match-3 remains, so a match that gravity lines up is
# removed as well (chain reactions, hard feature 5).
resolve_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
rm_loop:
    jal find_matches                # $v0 = number of triggering bubbles
    beq $v0, $zero, rm_done
    jal flood_fill
    jal remove_marked
rm_float:
    jal float_step                  # $v0 = 1 if a bubble moved
    bne $v0, $zero, rm_float        # repeat until every bubble is supported
    j rm_loop                       # chain reaction: check for a new match
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

# flood_fill: the explosion stage (hard feature 2). Starting from the bubbles
# marked by find_matches, every bubble of the same colour that is connected to
# them (left, right, above or below) is marked as well.
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
# marks.
remove_marked:
    la $t0, grid
    la $t1, mark
    li $t2, 98
rk_loop:
    lw $t3, 0($t1)
    beq $t3, $zero, rk_next
    sw $zero, 0($t0)
    sw $zero, 0($t1)
rk_next:
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    bgtz $t2, rk_loop
    jr $ra

# float_step: one step of gravity (hard feature 3). Every bubble with an empty
# cell directly above it moves up by one row. Returns $v0 = 1 if any bubble
# moved.
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
# Drawing (unit (x, y) is at display_address + 4 * (32 * y + x))
##############################################################################

# draw_walls: clear the screen, then draw the walls of the playing field and
# the red line above the character's row.
draw_walls:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal clear_screen
    li $a0, 0                       # top wall
    li $a1, 0
    li $a2, 31
    li $a3, 0x808080
    jal draw_hline
    li $a0, 0                       # bottom wall
    li $a1, 58
    li $a2, 31
    li $a3, 0x808080
    jal draw_hline
    li $a0, 0                       # left wall
    li $a1, 0
    li $a2, 59
    li $a3, 0x808080
    jal draw_vline
    li $a0, 30                      # right wall
    li $a1, 0
    li $a2, 59
    li $a3, 0x808080
    jal draw_vline
    li $a0, 1                       # red line above the character's row
    li $a1, 53
    li $a2, 29
    li $a3, 0x700000
    jal draw_hline
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# draw_board: draw the playing field, the aiming line and the character.
draw_board:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal draw_grid
    jal draw_aim
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
    addi $a1, $a1, 2                # y = 2 + 4 * row
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

# draw_aim: hard feature 6. A dotted line in the character's column: one dot
# in the centre of every empty cell between the lowest bubble and the
# character's row. It is drawn for 16 frames and left out for the next 16, so
# it flashes. draw_grid paints empty cells black first, so the dots disappear
# by themselves in the frames where they are not drawn.
draw_aim:
    lw $t0, frame_count
    andi $t0, $t0, 16               # bit 4 of the frame counter
    bne $t0, $zero, da_done         # the "off" half: draw nothing
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a0, player_col
    jal find_lowest                 # $v0 = row of the lowest bubble, or -1
    addi $t3, $v0, 1                # $t3 = first empty row of the column
    lw $t0, display_address
    lw $t1, player_col
    sll $t1, $t1, 4                 # 4 units per column * 4 bytes
    addi $t1, $t1, 12               # x = 3 + 4 * column (centre of the cell)
    add $t0, $t0, $t1
    li $t4, 0xa0a0a0                # colour of the dots
    li $t5, 13
da_loop:
    bge $t3, $t5, da_end            # rows 0..12 only
    sll $t2, $t3, 9                 # 4 units per row * 128 bytes
    addi $t2, $t2, 384              # y = 3 + 4 * row (centre of the cell)
    add $t2, $t2, $t0
    sw $t4, 0($t2)
    addi $t3, $t3, 1
    j da_loop
da_end:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
da_done:
    jr $ra

# draw_bubble: $a0 = x, $a1 = y (top-left unit), $a2 = colour (0..4).
# Draws one 3 x 3 bubble (colour 0 erases the cell). Only changes $t0-$t4.
draw_bubble:
    lw $t0, display_address
    sll $t1, $a1, 7                 # y * 32 units * 4 bytes
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
    sw $t3, 128($t0)
    sw $t4, 132($t0)
    sw $t3, 136($t0)
    sw $t2, 256($t0)
    sw $t3, 260($t0)
    sw $t2, 264($t0)
    jr $ra

# draw_player: draw the character in its column of the bottom row. The centre
# of the sprite shows the colour of the held bubbles.
draw_player:
    lw $t0, display_address
    lw $t1, player_col
    sll $t1, $t1, 4                 # 4 units per column * 4 bytes
    addi $t1, $t1, 6920             # row 13: y = 54 -> 54 * 128, plus x = 2 -> 8
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
    sw $t3, 128($t0)
    sw $t2, 132($t0)
    lw $t3, 20($t1)
    sw $t3, 136($t0)
    lw $t3, 24($t1)
    sw $t3, 256($t0)
    lw $t3, 28($t1)
    sw $t3, 260($t0)
    lw $t3, 32($t1)
    sw $t3, 264($t0)
    jr $ra

# draw_hline: $a0 = x, $a1 = y, $a2 = length, $a3 = colour.
draw_hline:
    lw $t0, display_address
    sll $t1, $a1, 7
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
    sll $t1, $a1, 7
    add $t0, $t0, $t1
    sll $t1, $a0, 2
    add $t0, $t0, $t1
vl_loop:
    sw $a3, 0($t0)
    addi $t0, $t0, 128
    addi $a2, $a2, -1
    bgtz $a2, vl_loop
    jr $ra

# clear_screen: paint all 32 x 64 units black.
clear_screen:
    lw $t0, display_address
    li $t1, 2048
cs_loop:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, cs_loop
    jr $ra

##############################################################################
# Helper
##############################################################################

# sleep_ms: $a0 = number of milliseconds to sleep.
sleep_ms:
    li $v0, 32
    syscall
    jr $ra
