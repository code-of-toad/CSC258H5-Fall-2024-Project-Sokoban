###############################################################################
# =====================   CODE DOCUMENTATION FOR TA'S   ===================== #
#                                                                             #
#                       +-----------------------------+                       #
#                       |  Name: Donghee (Danny) Han  |                       #
#                       |  Student No.: 999825596     |                       #
#                       |  Lecture Section: LEC0102   |                       #
#                       +-----------------------------+                       #
#                                                                             #
# My two choices of enhancement are the following:                            #
#                                                                             #
# 1. GENERATE INTERNAL WALLS IN ADDITION TO OTHER GAME OBJECTS                #
#    ---------------------------------------------------------                #
#        I designed my own algorithm to generate internal walls such that     #
#        they cover exactly 25% of the empty space within the grid, and such  #
#        that the game is solvable when other game objects spawn. Much of the #
#        loading time in the beggining of program execution is spent here.    #
#        It relies heavily on the PRNG that I implemented using the Linear    #
#        Feedback Shift Register algorithm.                                   #
#                                                                             #
# 2. INCREASE THE NUMBER OF BOXES AND TARGETS                                 #
#    ----------------------------------------                                 #
#        The number of boxes and targets are randomly generated, with one of  #
#        each being the minimum in every case. The maximum possible number of #
#        each object scales with the randomly generated grid size. Users are  #
#        NOT given the option to choose the grid size themselves.             #
#                                                                             #
#                                                                             #
# Below, I describe how I use the stack memory to allocate data pertaining    #
# to each uniquely generated level:                                           #
#                                                                             #
#        +=============================+  <---  sp = 0x80000000               #
#        |                             |                                      #
#        |     Initial Grid State      |                                      #
#        |                             |                                      #
#        +-----------------------------+  <---  fp (during level generation)  #
#        |                             |                                      #
#        |     Current Grid State      |                                      #
#        |                             |                                      #
#        +-----------------------------+  <---  fp (during gameplay)          # 
#        |            STACK            |                                      #
#        |              :              |                                      #
#                       :                                                     #
#                       V                                                     #
#                                                                             #
# The stack pointer's default position is always address 0x80000000.          #
# The frame pointer (the s0 register) is what moves around as a sort of a     #
# "checkpoint" depending on the state of the program.                         #
#                                                                             #
# When the user requests for a level reset, the current grid state is simply  #
# overwritten with the data in initial grid state.                            #
#                                                                             #
# When the user wants to generate a whole new level, the initial grid state   #
# itself is overwritten with new randomly generated values.                   #
#                                                                             #
#                                                                             # 
# References for the LFSR algorithm:                                          #
#                                                                             #
#   [1] Thomas W. Cusick and Pantelimon Stanica. 2017. Chapter 2 - Fourier    #
#       Analysis of Boolean Functions. Crytographic Boolean Functions and     #
#       Applications, 2nd Edition. Academic Press, 7-29.                      #
#       https://doi.org/10.1016/B978-0-12-811129-1.00002-X                    #
#                                                                             #
#   [2] Computerphile. 2021. Random Numbers with LFSR (Linear Feedback Shift  #
#       Register). YouTube. (September 10, 2021).                             #
#       https://www.youtube.com/watch?v=Ks1pw1X22y4&ab_channel=Computerphile  #
#                                                                             #
#                                                                             #
# Functions:                                                                  #
# ==========                                                                  #
#        [line  165]  _start                                                  #
#        [line  809]  RNG_LFSR                                                #
#        [line  871]  GENERATE_OUTER_WALLS                                    #
#        [line  943]  GENERATE_INTERNAL_WALLS                                 #
#        [line 1093]  GENERATE_BOXES                                          #
#        [line 1244]  GENERATE_PLAYER                                         #
#        [line 1337]  GENERATE_TARGETS                                        #
#        [line 1436]  COPY_GRID_STATE                                         #
#        [line 1486]  PRINT_GRID_STATE_CURR                                   #
#        [line 2359]  PROCESS_USER_INPUT                                      #
#                                                                             #
# Debug Helpers:                                                              #
# ==============                                                              #
#        [line 2718]  DEBUGGG_PRINT_VALUES_1                                  #
#        [line 2789]  DEBUGGG_PRINT_VALUES_2                                  #
#        [line 2823]  DEBUGGG_PRINT_GRID_STATE_INIT                           #
#                                                                             #
# =========================================================================== #
###############################################################################
.data
# GameStateInit: These values only change when user requests an entirely new
#                level. The numbers are 0-indexed.
# -----------------------------------------------------------------------------
grid_size:           .word 10,10   # number of rows, number of cols (INCLUDING outer walls)
stack_size:          .word 0
box_count:           .word 0       # MAX == ((17*17)*(3/4))//8 == 27 => clamped to 19
internal_wall_count: .word 0
empty_grid_count:    .word 0
init_loc_player:     .word 0,0
adj_grid_cell_bool:  .byte 0,0,0,0 # left, right, up, down

.align 4

# GameStateCurr: These values can (and will) change with every user input;
#                can be reset to the same values as GameStateInit.
# -----------------------------------------------------------------------------
remaining_boxes:               .word 0
curr_loc_player:               .word 0,0
player_is_standing_on_target:  .word 0

.align 4

# String Constants:
# -----------------------------------------------------------------------------
# Game Info Strings
str_buffer_space: .string "        "      # 8 bytes
str_boxes_left_1: .string "Boxes Left: "  # 12 bytes
str_boxes_left_2: .string " / "           # 3 bytes
str_keymap_0:     .string "KEYMAP: "      # 8 bytes
str_keymap_1:     .string " [W] Up     "  # 12 bytes
str_keymap_2:     .string " [S] Down   "  # 12 bytes
str_keymap_3:     .string " [A] Left   "  # 12 bytes
str_keymap_4:     .string " [D] Right  "  # 12 bytes
str_keymap_5:     .string "[R] Reset Current Level "  # 24 bytes
str_keymap_6:     .string "[G] Generate New Level  "  # 24 bytes
str_keymap_7:     .string "[Q] Exit Proj_258: Sokoban  "  # 28 bytes

# User Prompt Strings
are_you_sure_reset:  .string "*** Reset the current level??? [Y or N] "  # 40 bytes
are_you_sure_regen:  .string "*** Generate a new level??? [Y or N]    "  # 40 bytes
are_you_sure_quit:   .string "*** Exit Proj_258: Sokoban??? [Y or N]  "  # 40 bytes
str_victory:         .string "**************************************  LEVEL SOLVED! :)  Choose [R] or [G] or [Q]: "

# Utility Strings
clear_screen:       .string "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
newline:            .string "\n"
loading:            .string "\n\n\nLOADING:  ///////"
loading_dots:       .string "///////"
loading_dots_2:     .string "//////////////////////////"
thanks_for_playing: .string "\nThank you for playing Proj_258: Sokoban.\n\nAuthor: Danny Han\nCourse: CSC258H5, University of Toronto"

# DEBUGGG Strings
db_grid_cols:   .string "Grid Width  (cols): "
db_grid_rows:   .string "Grid Height (rows): "
db_int_walls:   .string "Internal Walls:     "
db_empty_grids: .string "Empty Grids:        "
db_box_count:   .string "Box Count:          "
db_stack_bytes: .string "Bytes for Stack:    "
db_push_bytes:  .string "Negated Byte Value: "

db_stack_pre_copy:  .string "Stack Value (PRE-copy):  "
db_stack_post_copy: .string "Stack Value (POST-copy): "

.align 4

# STRING DISPLAY (Grid + Game Info):
# -----------------------------------------------------------------------------
str_display: .fill 1000,1,0

.align 4

.text
.globl _start

_start:

    NEW_SOKOBAN_LEVEL:

    la   a0, clear_screen
    li   a7, 4
    ecall
    
    la   a0, loading
    li   a7, 4
    ecall

    li fp, 0x80000000   # fp = will later mark the boundary between "init_grid_state" and "curr_grid_state"
    li sp, 0x80000000   # sp = will be used to iterate through either the "init_grid_state",
                        #                                          or the "curr_grid_state"
    # Step_1: RNG -- Grid Size (width)  [# cols including outer wall] [DONE]
    la   s1, grid_size  # s1 = &gridsize
    li   a0, 10
    li   a1, 20
    jal  ra, RNG_LFSR   # width = RNG_LFSR(a0=10, a1=20)
    sw   a0, 0(s1)      #                                           ***   0(s1) = number of rows  ***

    la   a0, loading_dots
    li   a7, 4
    ecall

    # Step_2: RNG -- Grid Size (height) [# rows including outer wall] [DONE]
    li   a0, 10
    li   a1, 20
    jal  ra, RNG_LFSR   # height = RNG_LFSR(a0=10, a1=20)
    sw   a0, 4(s1)      #                                           ***   4(s1) = number of cols   ***

    la   a0, loading_dots
    li   a7, 4
    ecall

    # Step_3: Calculate Number of Internal Walls [DONE]
    lw   t0, 0(s1)
    addi t0, t0, -2     # t0 = Number of empty rows
    lw   t1, 4(s1)
    addi t1, t1, -2     # t1 = Number of empty cols

    mul  t0, t0, t1     # t0 = Number of empty grids
    srli t1, t0, 2      # t1 = Number of internal walls
    la   s7, internal_wall_count  # s7 = &internal_wall_count
    sw   t1, 0(s7)      #                                      ***   0(s7) = number of internal walls   ***

    la   a0, loading_dots
    li   a7, 4
    ecall

    # Step_4. RNG -- Box Count (based on available empty space) [DONE]
    sub  t0, t0, t1
    la   s3, empty_grid_count  # s3 = &empty_grid_count
    sw   t0, 0(s3)      #                                          ***   0(s3) = empty grid count   ***
    srli a1, t0, 3
    li   a0, 1
    jal  ra, RNG_LFSR   # box_count = RNG_LFSR(a0=1, a1=(empty_grids//8))
    clamp_box_count_TRUE:  # Limit the maximum box count to 19
    li   t6, 19
    ble  a0, t6, clamp_box_count_FALSE
    li   a0, 19
    clamp_box_count_FALSE:
    la   s2, box_count  # s2 = &box_count
    sw   a0, 0(s2)      #                                             ***   0(s2) = box count   ***


    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    # -------------------------------------------------------------------------
    #jal  ra, DEBUGGG_PRINT_VALUES_1
    # -------------------------------------------------------------------------
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG


    # ********** Program State **********
    #  0(s1) = number of rows
    #  4(s1) = number of cols
    #  0(s2) = box count
    #  0(s3) = number of empty grids
    #  0(s7) = number of internal walls
    # ***********************************


    # Step_5: Allocate stack space for "init_grid_state" [DONE]
    lw   t0, 0(s1)   # t0 = rows
    lw   t1, 4(s1)   # t1 = cols
    mul  t2, t0, t1
    slli t2, t2, 2   # t2 = (cols*rows)*4 = total bytes to allocate for grid state


    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    # -------------------------------------------------------------------------
    #jal  ra, DEBUGGG_PRINT_VALUES_2
    # -------------------------------------------------------------------------
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    
    # Save allocation byte to FP
    neg  t2, t2      # t2 = -(stack_size_bytes)
    add  fp, fp, t2  # fp = 0x80000000 + t2
    
    neg  t2, t2      # t2 = stack_size_bytes
    la   s3, stack_size
    sw   t2, 0(s3)   #                                             ***   0(s3) = stack size   ***
    
    
    # ********** Program State **********
    #  0(s1) = number of rows
    #  4(s1) = number of cols
    #  0(s2) = box count
    #  0(s3) = stack size (positive byte value)
    #  0(s7) = number of internal walls
    # ***********************************
    
    
    # Step_6: Generate Outer Walls [DONE]
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    jal  ra, GENERATE_OUTER_WALLS  # GENERATE_OUTER_WALLS(a0=max_row_index, a1=max_col_index)

    la   a0, loading_dots
    li   a7, 4
    ecall


    # ********** Program State **********
    #  0(s1) = number of rows
    #  4(s1) = number of cols
    #  0(s2) = box count
    #  0(s3) = stack size (positive byte value)
    #  0(s7) = number of internal walls
    #
    #  fp = 0x80000000 - stack_size
    #  sp = 0x80000000
    #
    #  s5 = pseudo-temp register = 0
    # ***********************************


    # Step_7: Generate Internal Walls
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    lw   a2, 0(s7)
    li   s5, 0      # rEgIsTeR cLoBbErReD
    jal  ra, GENERATE_INTERNAL_WALLS  # GENERATE_OUTER_WALLS(a0=max_row_index, a1=max_col_index, a2=int_wall_count)

    la   a0, loading_dots_2
    li   a7, 4
    ecall


    # Step_8: Generate Boxes
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    lw   a2, 0(s2)
    li   s5, 0      # rEgIsTeR cLoBbErReD
    jal  ra, GENERATE_BOXES

    la   a0, loading_dots
    li   a7, 4
    ecall


    # Step_9: Generate Player
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    jal  ra, GENERATE_PLAYER

    la   a0, loading_dots
    li   a7, 4
    ecall


    # Step_10: Generate Targets
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    lw   a2, 0(s2)
    jal  ra, GENERATE_TARGETS

    la   a0, loading_dots
    li   a7, 4
    ecall

    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    # -------------------------------------------------------------------------
    #la   a0, clear_screen
    #li   a7, 4
    #ecall

    #lw   a0, 0(s1)
    #lw   a1, 4(s1)
    #jal  ra, DEBUGGG_PRINT_GRID_STATE_INIT

    #la   a0, newline
    #li   a7, 4
    #ecall

    #li   a7, 1
    #la   t0, init_loc_player
    #lw   a0, 0(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall
    #li   a7, 1
    #lw   a0, 4(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall
    # -------------------------------------------------------------------------
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    
    
    # STEP_11: Use `s5` as a helper stack pointer (i.e., a second frame pointer)
    mv   s5, fp      # s5 = 0x80000000 - stack_size
    lw   t0, 0(s3)
    sub  fp, fp, t0  # fp = 0x80000000 - 2*(stack_size)
    
    
    # ********** Program State **********
    #  0(s1) = number of rows
    #  4(s1) = number of cols
    #  0(s2) = box count
    #  0(s3) = stack size (positive byte value)
    #  0(s7) = number of internal walls
    #
    #  s5 = 0x80000000 - stack_size
    #  fp = 0x80000000 - 2*(stack_size)
    #  sp = 0x80000000           (to be pushed & popped by 2*stack_size bytes from within subsequent functions)
    # ***********************************
    
    ###########################################################################################################
    
    # STEP_12: Copy GridStateInit to GridStateCurr
    RESET_SOKOBAN_LEVEL:
    la   s2, box_count
    mv   a0, fp
    jal  ra, COPY_GRID_STATE
    
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    # -------------------------------------------------------------------------
    #li   a7, 1
    #la   t0, curr_loc_player
    #lw   a0, 0(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall
    #li   a7, 1
    #lw   a0, 4(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall

    #li   a7, 1
    #la   t0, box_count
    #lw   a0, 0(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall
    #li   a7, 1
    #la   t0, remaining_boxes
    #lw   a0, 0(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall

    #li   a7, 1
    #la   t0, player_is_standing_on_target
    #lw   a0, 0(t0)
    #ecall
    #la   a0, newline
    #li   a7, 4
    #ecall
    # -------------------------------------------------------------------------
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG


    # STEP_13: Print the new GridStateCurr for the first time
    la   a0, clear_screen
    li   a7, 4
    ecall
    la   t0, grid_size
    lw   a0, 0(t0)
    lw   a1, 4(t0)
    li   a2, 0
    la   s1, remaining_boxes               # s1  = &(remaining_boxes)
    jal  ra, PRINT_GRID_STATE_CURR
    




    # STEP_14: GAME LOOP
    game_loop_START:
    # -------------------------------------------------------------------------
    # (a) Setup ALL registers that will be used for the game loop.
    la    s2, curr_loc_player               # s2  = &(curr_loc_player)
    la    t0, stack_size
    lw    s3, 0(t0)                         # s3  = *(stack_size)
    la    t0, grid_size
    lw    s8, 0(t0)                         # s8  = *(# rows)
    lw    s9, 4(t0)                         # s9  = *(# cols)
    lw    s10, 0(s2)                        # s10 = *(player_row_index BEFORE user_input)
    lw    s11, 4(s2)                        # s11 = *(player_col_index BEFORE user_input)
    # -------------------------------------------------------------------------
    # (b) Calculate: stack_address(player)
    mul  s4, s10, s9  # s4 = (player_row_index * num_cols)
    add  s4, s4, s11  # s4 = (player_row_index * num_cols) + player_col_index
    slli s4, s4, 2    # s4 = byte_offset for stack_address_player
    add  s4, s4, fp                         # s4 = *(stack_address_player)
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    #la   a0, newline
	#li   a7, 4
    #ecall
    #mv   a0, s4
	#li   a7, 1
	#ecall
	#la   a0, newline
	#li   a7, 4
    #ecall
	#mv   a0, s10
	#li   a7, 1
	#ecall
	#la   a0, newline
	#li   a7, 4
    #ecall
	#mv   a0, s11
	#li   a7, 1
	#ecall
	#la   a0, newline
	#li   a7, 4
    #ecall
	#lw   a0, 0(s4)
	#li   a7, 1
	#ecall
	#la   a0, newline
	#li   a7, 4
    #ecall
	#la   t6, player_is_standing_on_target
	#lw   a0, 0(t6)
	#li   a7, 1
	#ecall
    # DEBUGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
    # -------------------------------------------------------------------------
    # (c) User Input Verification
    gl_input_handler_START:
    li   a7, 12
    ecall                    # a0 = USER_INPUT


    gl_input_handler_CASE_LEFT:  # 97 or 65
    # INPUT VERIFICATION
    addi s6, s4, -4  # s6 = stack_address(left_block)
    addi s7, s6, -4  # s7 = stack_address(left_block_block)
    
    li   t6, 97
    beq  a0, t6, gl_logic_left
    li   t6, 65
    bne  a0, t6, gl_input_handler_CASE_RIGHT
    # ======= LOGIC FOR LEFT BLOCK =======
    gl_logic_left:
        li   a0, 0
        mv   a1, s4
        mv   a2, s6
        mv   a3, s7
        la   a4, player_is_standing_on_target
        jal  ra, PROCESS_USER_INPUT
        li   a2, 0
    # ====================================
    j    game_loop_RENDER


    gl_input_handler_CASE_RIGHT:  # 100 or 68
    # INPUT VERIFICATION
    addi s6, s4, 4   # s6 = stack_address(right_block)
    addi s7, s6, 4   # s7 = stack_address(right_block_block)
    
    li   t6, 100
    beq  a0, t6, gl_logic_right
    li   t6, 68
    bne  a0, t6, gl_input_handler_CASE_UP
    # ======= LOGIC FOR RIGHT BLOCK =======
    gl_logic_right:
        li   a0, 1
        mv   a1, s4
        mv   a2, s6
        mv   a3, s7
        la   a4, player_is_standing_on_target
        jal  ra, PROCESS_USER_INPUT
        li   a2, 0
    # =====================================
    j    game_loop_RENDER


    gl_input_handler_CASE_UP:  # 119 or 87
    # INPUT VERIFICATION
    slli t6, s9, 2
    sub  s6, s4, t6  # s6 = stack_address(up_block)
    sub  s7, s6, t6  # s7 = stack_address(up_block_block)
    
    li   t6, 119
    beq  a0, t6, gl_logic_up
    li   t6, 87
    bne  a0, t6, gl_input_handler_CASE_DOWN
    # ======== LOGIC FOR UP BLOCK ========
    gl_logic_up:
        li   a0, 2
        mv   a1, s4
        mv   a2, s6
        mv   a3, s7
        la   a4, player_is_standing_on_target
        jal  ra, PROCESS_USER_INPUT
        li   a2, 0
    # ====================================
    j    game_loop_RENDER


    gl_input_handler_CASE_DOWN:  # 115 or 83
    # INPUT VERIFICATION
    slli t6, s9, 2
    add  s6, s4, t6  # s6 = stack_address(down_block)
    add  s7, s6, t6  # s7 = stack_address(down_block_block)
    
    li   t6, 115
    beq  a0, t6, gl_logic_down
    li   t6, 83
    bne  a0, t6, gl_input_handler_CASE_RESET
    # ======= LOGIC FOR DOWN BLOCK =======
    gl_logic_down:
        li   a0, 3
        mv   a1, s4
        mv   a2, s6
        mv   a3, s7
        la   a4, player_is_standing_on_target
        jal  ra, PROCESS_USER_INPUT
        li   a2, 0
    # ====================================
    j    game_loop_RENDER


    gl_input_handler_CASE_RESET:  # 114 or 82
    # INPUT VERIFICATION
    li   t6, 114
    beq  a0, t6, gl_logic_reset
    li   t6, 82
    bne  a0, t6, gl_input_handler_CASE_REGEN
    # ======= LOGIC FOR USER: RESET =======
    gl_logic_reset:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 1
        jal  ra, PRINT_GRID_STATE_CURR
        listen_reset_yes:
        li   a7, 12   # listen for [Y/N]: 121 or 89, 110 or 78
        ecall
        li   t6, 121
        beq  a0, t6, RESET_SOKOBAN_LEVEL
        li   t6, 89
        beq  a0, t6, RESET_SOKOBAN_LEVEL
        li   t6, 110
        beq  a0, t6, listen_reset_no
        li   t6, 78
        beq  a0, t6, listen_reset_no
        j    listen_reset_yes
        listen_reset_no:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 0
        jal  ra, PRINT_GRID_STATE_CURR
        j    game_loop_START
    # =====================================
    j    gl_input_handler_CLEAN


    gl_input_handler_CASE_REGEN:  # 103 or 71
    # INPUT VERIFICATION
    li   t6, 103
    beq  a0, t6, gl_logic_regen
    li   t6, 71
    bne  a0, t6, gl_input_handler_CASE_EXIT
    # ======= LOGIC FOR USER: REGEN =======
    gl_logic_regen:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 2
        jal  ra, PRINT_GRID_STATE_CURR
        listen_regen_yes:
        li   a7, 12   # listen for [Y/N]: 121 or 89, 110 or 78
        ecall
        li   t6, 121
        beq  a0, t6, NEW_SOKOBAN_LEVEL
        li   t6, 89
        beq  a0, t6, NEW_SOKOBAN_LEVEL
        li   t6, 110
        beq  a0, t6, listen_regen_no
        li   t6, 78
        beq  a0, t6, listen_regen_no
        j    listen_regen_yes
        listen_regen_no:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 0
        jal  ra, PRINT_GRID_STATE_CURR
        j    game_loop_START
    # =====================================
    j    gl_input_handler_CLEAN


    gl_input_handler_CASE_EXIT:  # 113 or 81
    # INPUT VERIFICATION
    li   t6, 113
    beq  a0, t6, gl_logic_exit
    li   t6, 81
    bne  a0, t6, gl_input_handler_START
    # ======= LOGIC FOR USER: EXIT =======
    gl_logic_exit:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 3
        jal  ra, PRINT_GRID_STATE_CURR
        listen_exit_yes:
        li   a7, 12   # listen for [Y/N]: 121 or 89, 110 or 78
        ecall
        li   t6, 121
        beq  a0, t6, EXIT
        li   t6, 89
        beq  a0, t6, EXIT
        li   t6, 110
        beq  a0, t6, listen_exit_no
        li   t6, 78
        beq  a0, t6, listen_exit_no
        j    listen_exit_yes
        listen_exit_no:
        la   a0, clear_screen
        li   a7, 4
        ecall
        mv   a0, s8
        mv   a1, s9
        li   a2, 0
        jal  ra, PRINT_GRID_STATE_CURR
        j    game_loop_START
    # ====================================
    j    gl_input_handler_CLEAN


    game_loop_RENDER:
    # if no movement has occurred, do NOT render a new screen
    beqz a0, gl_input_handler_CLEAN

    la   a0, clear_screen
    li   a7, 4
    ecall
    mv   a0, s8
    mv   a1, s9
    # li   a2    THIS IS DECIDED AT THE END OF EACH GL_INPUT_HANDLER BRANCH. DO NOT FORGET !!!
    jal  ra, PRINT_GRID_STATE_CURR
    
    lw   t6, 0(s1)
    beqz t6, game_loop_VICTORY
    
    gl_input_handler_CLEAN:
    j    game_loop_START

    game_loop_VICTORY:
    # Inform user that he/she has solved the current level
    la   a0, str_victory
    li   a7, 4
    ecall
    # Listen for user input
    victory_input:
    li   a7, 12
    ecall
    li   t6, 114
    beq  a0, t6, RESET_SOKOBAN_LEVEL
    li   t6, 82
    beq  a0, t6, RESET_SOKOBAN_LEVEL
    li   t6, 103
    beq  a0, t6, NEW_SOKOBAN_LEVEL
    li   t6, 71
    beq  a0, t6, NEW_SOKOBAN_LEVEL
    li   t6, 113
    beq  a0, t6, EXIT
    li   t6, 81
    beq  a0, t6, EXIT
    j    victory_input
    
    game_loop_END:
    # ------------------------------------------------------------------------


EXIT:
    la   a0, newline
    li   a7, 4
    ecall
    la   a0, thanks_for_playing
    ecall
    li   a7, 10
    ecall
    
    
# --------------------------------------------------------------------------- #
# RNG_LFSR                                                                    #
#                                                                             #
# This RNG function was implemented using the Linear Feedback Shift Register  #
# (LFSR) algorithm.                                                           #
#                                                                             #
# References:                                                                 #
#                                                                             #
#   [1] Thomas W. Cusick and Pantelimon Stanica. 2017. Chapter 2 - Fourier    #
#       Analysis of Boolean Functions. Crytographic Boolean Functions and     #
#       Applications, 2nd Edition. Academic Press, 7-29.                      #
#       https://doi.org/10.1016/B978-0-12-811129-1.00002-X                    #
#                                                                             #
#   [2] Computerphile. 2021. Random Numbers with LFSR (Linear Feedback Shift  #
#       Register). YouTube. (September 10, 2021).                             #
#       https://www.youtube.com/watch?v=Ks1pw1X22y4&ab_channel=Computerphile  #
#                                                                             #
# Args:                                                                       #
#   a0: MIN integer (inclusive)                                               #
#   a1: MAX integer (exclusive)                                               #
# Pre-Condition:                                                              #
#   0 <= a0 < a1 <= 255                                                       #
# Return:                                                                     #
#   a0: A positive integer within [MIN, MAX)                                  #
# --------------------------------------------------------------------------- #
RNG_LFSR:
    mv   t5, a0  # t5 = MIN integer (inc)
    mv   t6, a1  # t6 = MAX integer (exc)
    li   a0, 10
    li   a7, 32
    ecall        # Sleep for 10 ms. This guarantees a unique seed for every call.
    li   a7, 30
    ecall
    mv   t2, a0
    andi t2, t2, 0xFF  # t2 = Seed (current time in ms, lowest 8 bits)
    
    # Loop Init
    li   t0, 0    # int i = 0
    li   t1, 237  # while i < 200
    
    # LFSR algorithm loop (8-bit seed number)
    lfsr_loop:  # Tap Positions (0-indexed): 7, 5, 2
        bge  t0, t1, lfsr_done
        
        srli t3, t2, 7   # Get bit-7 bit of seed
        andi t3, t3, 1   # Mask all but lowest bit
        
        srli t4, t2, 5   # Get bit-5 bit of seed
        andi t4, t4, 1   # Mask all but lowest bit
        xor  t3, t3, t4  # [bit-7] XOR [bit-5]
        
        srli t4, t2, 2   # Get bit-2 of seed
        andi t4, t4, 1   # Mask all but lowest bit
        xor  t3, t3, t4  # [bit-7] XOR [bit-5] XOR [bit-2]
        
        slli t3, t3, 7   # Push the XOR result to highest bit
        srli t2, t2, 1   # s2 >> 1
        or   t2, t2, t3  # Update seed number
        
        addi t0, t0, 1   # i++
        j    lfsr_loop    
    lfsr_done:
    rem  t2, t2, t6
    mv   a0, t2
    rng_check_min:
    bge  a0, t5, rng_return
    add  a0, a0, t5
    rng_return:
    jr   ra


# --------------------------------------------------------------------------- #
# GENERATE_OUTER_WALLS                                                        #
#                                                                             #
# Fill the border of the grid w/ immovable and impassible walls.              #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
GENERATE_OUTER_WALLS:
    mv   sp, fp  # STACK PUSH
    li   t0, 0   # t0=0 <= a0=max_row_index
    gow_row_START:
        li   t1, 0   # t1=0 <= a1=max_col_index
        gow_col_START:
            gow_col_0:  # if (t0 == 0):  fill entire row w/ wall (5)
            bnez t0, gow_col_1
            li   t6, 5
            sw   t6, 0(sp)
            j gow_col_LOOP_COND
            
            gow_col_1:  # if (t0 == a0): fill entire row w/ wall (5)
            mv   t6, a0
            addi t6, t6, -1
            bne  t0, t6, gow_col_2
            li   t6, 5
            sw   t6, 0(sp)
            #li   t5, 0x80000000
            j gow_col_LOOP_COND
            
            gow_col_2:  # if (t1 == 0):  fill first cell of row w/ wall (5)
            bnez t1, gow_col_3
            li   t6, 5
            sw   t6, 0(sp)
            j gow_col_LOOP_COND
            
            gow_col_3:  # if (t1 == a1): fill last cell of row w/ wall  (5)
            mv   t6, a1
            addi t6, t6, -1
            bne  t1, t6, gow_col_4
            li   t6, 5
            sw   t6, 0(sp)
            j gow_col_LOOP_COND
            
            gow_col_4:  # else:          encode cell as empty space (0)
            li   t6, 0
            sw   t6, 0(sp)
            j gow_col_LOOP_COND
            
            gow_col_LOOP_COND:
            #beq  sp, t5, gow_col_END
            addi sp, sp, 4
            addi t1, t1, 1
            blt  t1, a1, gow_col_START
        gow_col_END:
        gow_row_LOOP_COND:
        addi t0, t0, 1
        blt  t0, a0, gow_row_START
    gow_row_END:
    # RETURN
    li   sp, 0x80000000  # STACK POP
    jr   ra


# --------------------------------------------------------------------------- #
# GENERATE_INTERNAL_WALLS                                                     #
#                                                                             #
# Cover 25% of the grid's empty space w/ immovable and impassible walls.      #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
#   a2: Number of internal walls                                              #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
GENERATE_INTERNAL_WALLS:
    mv   sp, fp  # STACK PUSH
    li   t0, 0   # t0=0 <= max_row_index
    giw_row_START:
        li   t1, 0  # t1=0 <= max_col_index
        giw_col_START:

            # RETURN Condition: NO MORE internal walls left to construct
            beqz a2, giw_row_END
            
            giw_col_0:
            li   t6, 5
            lw   t3, 0(sp)
            beq  t3, t6, giw_col_LOOP_COND
            
            giw_col_WALL_RNG:  # if (grid_cell == empty): some chance that this grid_cell will be walled
            # ===================================================================================
            # Before calling 'RNG_LFSR'
            mv   t3, sp
            mv   sp, fp
            addi sp, sp, -24
            sw   ra, 0(sp)
            sw   a0, 4(sp)
            sw   a1, 8(sp)
            sw   t0, 12(sp)
            sw   t1, 16(sp)
            sw   t3, 20(sp)
            li   a0, 1
            li   a1, 6
            jal  ra, RNG_LFSR
            mv   t2, a0                       # t2 = RNG_LFSR(a0=1, a1=6)
            lw   t3, 20(sp)
            lw   t1, 16(sp)
            lw   t0, 12(sp)
            lw   a1, 8(sp)
            lw   a0, 4(sp)
            lw   ra, 0(sp)
            addi sp, sp, 24
            mv   sp, t3
            # After retruning from 'RNG_LFSR'
            # ===================================================================================
            # if (P(test fails)=4/5): skip this iteration
            li   t6, 2
            blt  t2, t6, giw_col_LOOP_COND
            
            giw_col_WALL_PLACEMENT:
            # TODO: Place Wall or NO??????????????????
            # -----------------------------------------------------------------------------------
            # FREE REGISTERS: t2, t3, t4, t5, t6
            # -----------------------------------------------------------------------------------
            mv   s5, sp      # uNaLlOcAtEd StAcK sPaCe
            mv   sp, fp      # uNaLlOcAtEd StAcK sPaCe
            li   t6, 0       # t6 = adj. wall count
            # CALCULATE: curr_grid
            mul  t2, a1, t0  # t2 = (#cols)*(curr_row_i)
            add  t2, t2, t1  # t2 = (#cols)*(curr_row_i) + curr_col_j
            slli t2, t2, 2   # t2 = byte_offset for curr_grid
            
            giw_col_WALL_PLACEMENT_CHECK_LEFT:
            # CASE: (curr_grid + LEFT)
            addi t3, t2, -4
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + LEFT)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + LEFT)
            # ====== logic for LEFT ======
            beqz t4, giw_col_WALL_PLACEMENT_CHECK_RIGHT
            addi t6, t6, 1
            # ============================
            
            giw_col_WALL_PLACEMENT_CHECK_RIGHT:
            # CASE: (curr_grid + RIGHT)
            addi t3, t2, 4
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + RIGHT)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + RIGHT)
            # ====== logic for RIGHT ======
            beqz  t4, giw_col_WALL_PLACEMENT_CHECK_UP
            addi t6, t6, 1
            # =============================
            
            giw_col_WALL_PLACEMENT_CHECK_UP:
            # CASE: (curr_grid + UP)
            slli t3, a1, 2
            neg  t3, t3
            add  t3, t3, t2
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + UP)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + UP)
            # ====== logic for up ======
            beqz  t4, giw_col_WALL_PLACEMENT_CHECK_DOWN
            addi t6, t6, 1
            # ==========================
            
            giw_col_WALL_PLACEMENT_CHECK_DOWN:
            # CASE: (curr_grid + DOWN)
            slli t3, a1, 2
            add  t3, t3, t2
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + DOWN)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + DOWN)
            # ====== logic for down ======
            beqz  t4, giw_col_WALL_PLACEMENT_CHECK_ADJ_COUNT
            addi t6, t6, 1
            # ============================
            
            giw_col_WALL_PLACEMENT_CHECK_ADJ_COUNT:
            # FREE REGISTERS: t2, t3, t4, t5
            # ------------------------------
            mv   sp, s5     # uNaLlOcAtEd StAcK sPaCe
            li   t2, 2      #                            <-------------- IMPORTANT VALUE
            blt  t6, t2, giw_col_LOOP_COND
            # ------------------------------
            
            giw_col_WALL_PLACEMENT_TRUE:
            # -----------------------------------------------------------------------------------
            li   t6, 5
            sw   t6, 0(sp)
            addi a2, a2, -1  # Decrement the number of internal walls req'd
            # -----------------------------------------------------------------------------------
            
            giw_col_LOOP_COND:
            addi sp, sp, 4  # Update stack
            addi t1, t1, 1  # t1++
            blt  t1, a1, giw_col_START
        giw_col_END:
        addi t0, t0, 1  # t0++
        blt  t0, a0, giw_row_START
        giw_RESET:
        j    GENERATE_INTERNAL_WALLS
    giw_row_END:
    # RETURN
    li   sp, 0x80000000  # STACK POP
    li   s5, 0  # rEgIsTeR cLoBbErReD
    jr   ra


# --------------------------------------------------------------------------- #
# GENERATE_BOXES                                                              #
#                                                                             #
# Spawn boxes in random locations on the grid such that they cover 25% of the #
# empty grid cells present PRIOR the call to this function.                   #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
#   a2: Number of boxes                                                       #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
GENERATE_BOXES:
    mv   sp, fp  # STACK PUSH
    li   t0, 0   # t0=0 <= max_row_index
    gb_row_START:
        li   t1, 0  # t1=0 <= max_col_index
        gb_col_START:

            # RETURN Condition: NO MORE boxes left to spawn
            beqz a2, gb_row_END

            # --------------------------------------
            #   FREE REGISTERS: t2, t3, t4, t5, t6
            # --------------------------------------
            gb_col_0:
            lw   t3, 0(sp)
            bnez t3, gb_col_LOOP_COND

            gb_col_BOX_RNG:  # if (grid_cell == empty): some chance that this grid_cell will be walled
            # ===================================================================================
            # Before calling 'RNG_LFSR'
            mv   t3, sp
            mv   sp, fp
            addi sp, sp, -24
            sw   ra, 0(sp)
            sw   a0, 4(sp)
            sw   a1, 8(sp)
            sw   t0, 12(sp)
            sw   t1, 16(sp)
            sw   t3, 20(sp)
            li   a0, 1
            li   a1, 31
            jal  ra, RNG_LFSR
            mv   t2, a0                       # t2 = RNG_LFSR(a0=1, a1=31)
            lw   t3, 20(sp)
            lw   t1, 16(sp)
            lw   t0, 12(sp)
            lw   a1, 8(sp)
            lw   a0, 4(sp)
            lw   ra, 0(sp)
            addi sp, sp, 24
            mv   sp, t3
            # After returning from 'RNG_LFSR'
            # ===================================================================================
            # if (P(test fails)=29/30): skip this iteration
            li   t6, 2
            bge  t2, t6, gb_col_LOOP_COND
            
            gb_col_BOX_PLACEMENT:
            # TODO: Place BOX or NO??????????????????
            # -----------------------------------------------------------------------------------
            # FREE REGISTERS: t2, t3, t4, t5, t6
            # -----------------------------------------------------------------------------------
            mv   s5, sp      # uNaLlOcAtEd StAcK sPaCe
            mv   sp, fp      # uNaLlOcAtEd StAcK sPaCe
            li   t5, 5       # t5 = wall
            #LI   t6, 2       # t6 = box
            # CALCULATE: curr_grid
            mul  t2, a1, t0  # t2 = (#cols)*(curr_row_i)
            add  t2, t2, t1  # t2 = (#cols)*(curr_row_i) + curr_col_j
            slli t2, t2, 2   # t2 = byte_offset for curr_grid
            
            gb_col_BOX_PLACEMENT_CHECK_LEFT:
            # CASE: (curr_grid + LEFT)
            addi t3, t2, -4
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + LEFT)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + LEFT)
            # ====== logic for LEFT ======
            beq  t4, t5, gb_col_BOX_PLACEMENT_CLEAN
            # ============================
            
            gb_col_BOX_PLACEMENT_CHECK_RIGHT:
            # CASE: (curr_grid + RIGHT)
            addi t3, t2, 4
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + RIGHT)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + RIGHT)
            # ====== logic for RIGHT ======
            beq  t4, t5, gb_col_BOX_PLACEMENT_CLEAN
            # =============================
            
            gb_col_BOX_PLACEMENT_CHECK_UP:
            # CASE: (curr_grid + UP)
            slli t3, a1, 2
            neg  t3, t3
            add  t3, t3, t2
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + UP)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + UP)
            # ====== logic for UP =======
            beq  t4, t5, gb_col_BOX_PLACEMENT_CLEAN
            # ===========================
            
			gb_col_BOX_PLACEMENT_CHECK_DOWN:
            # CASE: (curr_grid + DOWN)
            slli t3, a1, 2
            add  t3, t3, t2
            add  t3, t3, fp  # t3 = fp + byte_offset for (curr_grid + DOWN)
            lw   t4, 0(t3)   # t4 = grid_state_code (0-5) for (curr_grid + DOWN)
            # ====== logic for DOWN =======
            beq  t4, t5, gb_col_BOX_PLACEMENT_CLEAN
            # =============================
            
            gb_col_BOX_PLACEMENT_TRUE:
            # -----------------------------------------------------------------------------------
            mv   sp, s5
            li   t6, 2
            sw   t6, 0(sp)
            addi a2, a2, -1  # Decrement the number of boxes req'd
            j    gb_col_LOOP_COND
            # -----------------------------------------------------------------------------------
            
            gb_col_BOX_PLACEMENT_CLEAN:
            mv   sp, s5      # uNaLlOcAtEd StAcK sPaCe
            
            gb_col_LOOP_COND:
            li   t3, 0x80000000
            bne  sp, t3, aaaaaaa1
            mv   sp, fp
            addi t1, t1, 1
            j    aaaaaaa2
            aaaaaaa1:
            addi sp, sp, 4   # Update stack (SKIP IF SP == 0x80000000)
            addi t1, t1, 1   # t1++
            aaaaaaa2:
            blt  t1, a1, gb_col_START
        gb_col_END:
        addi t0, t0, 1  # t0++
        blt  t0, a0, gb_row_START
        gb_RESET:
        j    GENERATE_BOXES
    gb_row_END:
    # RETURN
    li   sp, 0x80000000  # STACK POP
    li   s5, 0  # rEgIsTeR cLoBbErReD
    jr   ra


# --------------------------------------------------------------------------- #
# GENERATE_PLAYER                                                             #
#                                                                             #
# Spawn one player in a random location on the grid.                          #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
GENERATE_PLAYER:
    mv   sp, fp  # STACK PUSH
    li   t0, 0   # t0=0 <= max_row_index
    gp_row_START:
        li   t1, 0  # t1=0 <= max_col_index
        gp_col_START:

            # --------------------------------------
            #   FREE REGISTERS: t2, t3, t4, t5, t6
            # --------------------------------------
            gp_col_0:
            lw   t3, 0(sp)
            bnez t3, gp_col_LOOP_COND

            gp_col_PLAYER_RNG:  # if (grid_cell == empty): some chance that this grid_cell will be walled
            # ===================================================================================
            # Before calling 'RNG_LFSR'
            mv   t3, sp
            mv   sp, fp
            addi sp, sp, -24
            sw   ra, 0(sp)
            sw   a0, 4(sp)
            sw   a1, 8(sp)
            sw   t0, 12(sp)
            sw   t1, 16(sp)
            sw   t3, 20(sp)
            li   a0, 1
            li   a1, 51
            jal  ra, RNG_LFSR
            mv   t2, a0                       # t2 = RNG_LFSR(a0=1, a1=51)
            lw   t3, 20(sp)
            lw   t1, 16(sp)
            lw   t0, 12(sp)
            lw   a1, 8(sp)
            lw   a0, 4(sp)
            lw   ra, 0(sp)
            addi sp, sp, 24
            mv   sp, t3
            # After returning from 'RNG_LFSR'
            # ===================================================================================
            # if (P(test fails)=49/50): skip this iteration
            li   t6, 2
            bge  t2, t6, gp_col_LOOP_COND
            
            gp_col_PLAYER_PLACEMENT:
            li   t3, 1
            sw   t3, 0(sp)
            # Save Player Position
            la   t6, init_loc_player
            sw   t0, 0(t6)
            sw   t1, 4(t6)
            j    gp_row_END
            
            gp_col_LOOP_COND:
            li   t3, 0x80000000
            bne  sp, t3, aaaaaaa3
            mv   sp, fp
            addi t1, t1, 1
            j    aaaaaaa4
            aaaaaaa3:
            addi sp, sp, 4   # Update stack (SKIP IF SP == 0x80000000)
            addi t1, t1, 1   # t1++
            aaaaaaa4:
            blt  t1, a1, gp_col_START
        gp_col_END:
        addi t0, t0, 1  # t0++
        blt  t0, a0, gp_row_START
        gp_RESET:
        j    GENERATE_PLAYER
    gp_row_END:
    # RETURN
    li   sp, 0x80000000  # STACK POP
    li   s5, 0  # rEgIsTeR cLoBbErReD
    jr   ra


# --------------------------------------------------------------------------- #
# GENERATE_TARGETS                                                            #
#                                                                             #
# Spawn targets in random locations on the grid.                              #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
#   a2: Number of targets                                                     #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
GENERATE_TARGETS:
    mv   sp, fp  # STACK PUSH
    li   t0, 0   # t0=0 <= max_row_index
    gt_row_START:
        li   t1, 0  # t1=0 <= max_col_index
        gt_col_START:

            # RETURN Condition: NO MORE targets left to construct
            beqz a2, gt_row_END

            # --------------------------------------
            #   FREE REGISTERS: t2, t3, t4, t5, t6
            # --------------------------------------
            gt_col_0:
            lw   t3, 0(sp)
            bnez t3, gt_col_LOOP_COND

            gt_col_TARGET_RNG:  # if (grid_cell == empty): some chance that this grid_cell will be walled
            # ===================================================================================
            # Before calling 'RNG_LFSR'
            mv   t3, sp
            mv   sp, fp
            addi sp, sp, -24
            sw   ra, 0(sp)
            sw   a0, 4(sp)
            sw   a1, 8(sp)
            sw   t0, 12(sp)
            sw   t1, 16(sp)
            sw   t3, 20(sp)
            li   a0, 1
            li   a1, 51
            jal  ra, RNG_LFSR
            mv   t2, a0                       # t2 = RNG_LFSR(a0=1, a1=51)
            lw   t3, 20(sp)
            lw   t1, 16(sp)
            lw   t0, 12(sp)
            lw   a1, 8(sp)
            lw   a0, 4(sp)
            lw   ra, 0(sp)
            addi sp, sp, 24
            mv   sp, t3
            # After returning from 'RNG_LFSR'
            # ===================================================================================
            # if (P(test fails)=49/50): skip this iteration
            li   t6, 2
            bge  t2, t6, gt_col_LOOP_COND
            
            gt_col_TARGET_PLACEMENT:
            li   t3, 3
            sw   t3, 0(sp)
            # Decrement Target Count
            addi a2, a2, -1
            
            gt_col_LOOP_COND:
            li   t3, 0x80000000
            bne  sp, t3, aaaaaaa5
            mv   sp, fp
            addi t1, t1, 1
            j    aaaaaaa6
            aaaaaaa5:
            addi sp, sp, 4   # Update stack (SKIP IF SP == 0x80000000)
            addi t1, t1, 1   # t1++
            aaaaaaa6:
            blt  t1, a1, gt_col_START
        gt_col_END:
        addi t0, t0, 1  # t0++
        blt  t0, a0, gt_row_START
        gt_RESET:
        j    GENERATE_TARGETS
    gt_row_END:
    # RETURN
    li   sp, 0x80000000  # STACK POP
    li   s5, 0  # rEgIsTeR cLoBbErReD
    jr   ra


# --------------------------------------------------------------------------- #
# COPY_GRID_STATE                                                             #
#                                                                             #
# Copy the first portion of the stack that contains the initial grid state    #
# to a second portion of the stack that shall be referred to as the CURRENT   #
# grid state.                                                                 #
#                                                                             #
# The current grid state is updated with every valid user input, while the    #
# initial grid remains the same throughout the gameplay. This enables the     #
# user to re-load the same level to its initial state (i.e., reset).          #
#                                                                             #
# Args:                                                                       #
#   a0: address of FP prior to the call to this function                      #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of s5 shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
COPY_GRID_STATE:
    mv   sp, fp  # STACK PUSH
    mv   fp, s5  # FP POP
    cgs_while_START:
        lw   t0, 0(fp)
        sw   t0, 0(sp)
        addi fp, fp, 4
        addi sp, sp, 4
        blt  sp, s5, cgs_while_START
    cgs_while_END:
    # Copy box_count -> remaining_boxes
    lw   t0, 0(s2)
    la   t1, remaining_boxes
    sw   t0, 0(t1)
    # Copy init_loc_player -> curr_loc_player
    la   t6, init_loc_player
    lw   t0, 0(t6)
    lw   t1, 4(t6)
    la   t6, curr_loc_player
    sw   t0, 0(t6)
    sw   t1, 4(t6)
    # Set player_is_standing_on_target = 0
    la   t6, player_is_standing_on_target
    sw   x0, 0(t6)
    # RETURN
    li   sp, 0x80000000  # STACK POP
    mv   fp, a0          # FP PUSH
    jr   ra
    
    
# --------------------------------------------------------------------------- #
# PRINT_GRID_STATE_CURR                                                       #
#                                                                             #
# Print the current grid state to console.                                    #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
#   a2: message flag (0 = nothing,                                            #
#                     1 = confirm_reset,                                      #
#                     2 = confirm_regen,                                      #
#                     3 = confirm_exit)                                       #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
PRINT_GRID_STATE_CURR:  # t3=&str_display, t4=misc, t6=0(sp)
    mv   sp, fp  # STACK PUSH
    la   t3, str_display
    li   t0, 0   # t0=0 < a0=max_row_index
    pgsc_row_START:
        li   t1, 0   # t1=0 < a1=max_col_index
        pgsc_col_START:
            lw   t6, 0(sp)
            pgsc_col_empty:  # if (grid_state[t0][t1] == 0): construct empty cell
            li   t4, 0
            bne  t6, t4, pgsc_col_wall
            li   t4, ' '
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_wall:   # if (grid_state[t0][t1] == 5): construct wall
            li   t4, 5
            bne  t6, t4, pgsc_col_box
            li   t4, '='
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_box:    # if (grid_state[t0][t1] == 2): construct box
            li   t4, 2
			bne  t6, t4, pgsc_col_player
            li   t4, '%'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_player: # if (grid_state[t0][t1] == 1): construct player
            li   t4, 1
			bne  t6, t4, pgsc_col_target_unfilled
            li   t4, 'A'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_target_unfilled:  # if (grid_state[t0][t1] == 3): construct target (unfilled)
            li   t4, 3
			bne  t6, t4, pgsc_col_target_filled
            li   t4, '*'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_target_filled:  # if (grid_state[t0][t1] == 4): construct target (FILLED)
            li   t4, 4
			bne  t6, t4, pgsc_col_target_player
            li   t4, 'O'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsc_col_LOOP_COND

            pgsc_col_target_player:  # if (grid_state[t0][t1] == 6): construct target (player standing on it)
            li   t4, 'A'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)

            pgsc_col_LOOP_COND:
            addi t3, t3, 2
            addi sp, sp, 4
            addi t1, t1, 1
            blt  t1, a1, pgsc_col_START
        pgsc_col_END:
        # -------------------------------------------
        #     FREE REGISTERS: t2, t4, t5, t6
        # -------------------------------------------
        # Start building game info strings
        la   t2, str_buffer_space
        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        sb   t4, 0(t3)
        addi t3, t3, 1

        pgsc_row_case_0:  # CASE_0: Remaining Boxes
        # -------------------------------------------
        #     FREE REGISTERS: t2, t4, t5, t6
        # -------------------------------------------
        li   t6, 0
        bne  t0, t6, pgsc_row_case_1

        la   t2, str_boxes_left_1

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

# --------------------------------------------------
        lw   t4, 0(s1)
        addi t4, t4, 48
        # TODO: Now, t4 = decimal ASCII code for number.
        # NOTE: 57="9", 58=":"
        boxes_left_is_single_digit:
        li   t6, 58
        bge  t4, t6, boxes_left_is_double_digit
        sb   t4, 0(t3)
        addi t3, t3, 1
        j    boxes_left_digit_count_END
        boxes_left_is_double_digit:
        li   t6, 49
        sb   t6, 0(t3)
        addi t3, t3, 1
        li   t6, 10
        sub  t4, t4, t6
        sb   t4, 0(t3)
        addi t3, t3, 1
        boxes_left_digit_count_END:
# --------------------------------------------------

        la   t2, str_boxes_left_2
        
        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

# --------------------------------------------------
        la   t2, box_count
        lw   t4, 0(t2)
        addi t4, t4, 48
        # TODO: Now, t4 = decimal ASCII code for number.
        # NOTE: 57="9", 58=":"
        box_count_is_single_digit:
        li   t6, 58
        bge  t4, t6, box_count_is_double_digit
        sb   t4, 0(t3)
        addi t3, t3, 1
        j    box_count_digit_count_END
        box_count_is_double_digit:
        li   t6, 49
        sb   t6, 0(t3)
        addi t3, t3, 1
        li   t6, 10
        sub  t4, t4, t6
        sb   t4, 0(t3)
        addi t3, t3, 1
        box_count_digit_count_END:
# --------------------------------------------------

        j    pgsc_row_LOOP_COND

        pgsc_row_case_1:  # CASE_1: keymap_0
        li   t6, 2
        bne  t0, t6, pgsc_row_case_2
        
        la   t2, str_keymap_0

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        j    pgsc_row_LOOP_COND
        
        pgsc_row_case_2:  # CASE_2: keymap_1 + keymap_5
        li   t6, 3
        bne  t0, t6, pgsc_row_case_3

        la   t2, str_keymap_1

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        la   t2, str_keymap_5

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 12(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 13(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 14(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 15(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 16(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 17(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 18(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 19(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 20(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 21(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 22(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 23(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        
        j    pgsc_row_LOOP_COND
        
        pgsc_row_case_3:  # CASE_3: keymap_2 + keymap_6
        li   t6, 4
        bne  t0, t6, pgsc_row_case_4

        la   t2, str_keymap_2

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        la   t2, str_keymap_6

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 12(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 13(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 14(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 15(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 16(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 17(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 18(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 19(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 20(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 21(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 22(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 23(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        
        j    pgsc_row_LOOP_COND
        
        pgsc_row_case_4:  # CASE_4: keymap_3 + keymap_7
        li   t6, 5
        bne  t0, t6, pgsc_row_case_5

        la   t2, str_keymap_3

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        la   t2, str_keymap_7

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 12(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 13(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 14(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 15(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 16(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 17(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 18(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 19(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 20(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 21(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 22(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 23(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 24(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 25(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 26(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 27(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        
        j    pgsc_row_LOOP_COND
        
        pgsc_row_case_5:  # CASE_5: keymap_4
        li   t6, 6
        bne  t0, t6, pgsc_row_case_6

        la   t2, str_keymap_4

        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 1(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 2(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 3(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 4(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 5(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 6(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 7(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 8(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 9(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 10(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1

        lb   t4, 11(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        
        j    pgsc_row_LOOP_COND
        
        pgsc_row_case_6:  # CASE_6
        li   t6, 8
        bne  t0, t6, pgsc_row_LOOP_COND
        beqz a2, pgsc_row_LOOP_COND
        
        pgsc_row_case_6_reset:  # CASE_6a: are_you_sure_reset
        li   t6, 1
        bne  a2, t6, pgsc_row_case_6_regen
        la   t2, are_you_sure_reset
        li   t5, 0
        li   t6, 41
        case_reset_loop:
        addi t3, t3, -1
        bge  t5, t6, case_reset_loop_end
        addi t3, t3, 1
        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        addi t2, t2, 1
        addi t5, t5, 1
        j    case_reset_loop
        case_reset_loop_end:
        j    pgsc_row_LOOP_COND

        pgsc_row_case_6_regen:  # CASE_6b: are_you_sure_regen
        li   t6, 2
        bne  a2, t6, pgsc_row_case_6_quit
        la   t2, are_you_sure_regen
        li   t5, 0
        li   t6, 41
        case_regen_loop:
        addi t3, t3, -1
        bge  t5, t6, case_regen_loop_end
        addi t3, t3, 1
        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        addi t2, t2, 1
        addi t5, t5, 1
        j    case_regen_loop
        case_regen_loop_end:
        j    pgsc_row_LOOP_COND

        pgsc_row_case_6_quit:   # CASE_6c: are_you_sure_quit
        li   t6, 3
        bne  a2, t6, pgsc_row_LOOP_COND
        la   t2, are_you_sure_quit
        li   t5, 0
        li   t6, 41
        case_quit_loop:
        addi t3, t3, -1
        bge  t5, t6, case_quit_loop_end
        addi t3, t3, 1
        lb   t4, 0(t2)
        sb   t4, 0(t3)
        addi t3, t3, 1
        addi t2, t2, 1
        addi t5, t5, 1
        j    case_quit_loop
        case_quit_loop_end:
        j    pgsc_row_LOOP_COND

        pgsc_row_LOOP_COND:
        li   t4, '\n'
        sb   t4, 0(t3)
        addi t3, t3, 1
        addi t0, t0, 1
        blt  t0, a0, pgsc_row_START
    pgsc_row_END:
    # Null-terminate the string
    li   t4, 0
    sb   t4, 0(t3)
    # Print curr grid state
    la   a0, str_display
    li   a7, 4
    ecall
    # RETURN
    li   sp, 0x80000000  # STACK POP
    jr   ra


# --------------------------------------------------------------------------- #
# PROCESS_USER_INPUT                                                          #
#                                                                             #
# Based on the user input received, update GameStateCurr accordingly.         #
#                                                                             #
# Args:                                                                       #
#   a0: dir_flag (0=left, 1=right, 2=up, 3=down)                              #
#   a1: stack_address(player)                                                 #
#   a2: stack_address(block)                                                  #
#   a3: stack_address(blockblock)                                             #
#   a4: address(player_is_standing_on_target)                                 #
# Return:                                                                     #
#   a0: if (GridStateCurr has been updated) return 1;                         #
#       else return 0                                                         #
# --------------------------------------------------------------------------- #
PROCESS_USER_INPUT:
    # Function Setup
    lw   t1, 0(a1)  # t1 = encoding(player)
    lw   t2, 0(a2)  # t2 = encoding(block)
    lw   t3, 0(a3)  # t3 = encoding(blockblock)
    lw   t4, 0(a4)  # t4 = player_is_standing_on_target
    # FREE REGISTERS: t0, t5, t6
    
    
    pui_case_0:  # CASE_0: Player (1/6) moves into empty space (0)
    # Check case condition
    li   t6, 0
    bne  t2, t6, pui_case_1
    # Update block
    li   t6, 1
    sw   t6, 0(a2)
    case_0_player_NOT_standing_on_target:
    # if (player is NOT standing on a target): update player to 0
    li   t6, 6
    beq  t1, t6, case_0_player_is_standing_on_target
    li   t6, 0
    sw   t6, 0(a1)
    # Jump to update curr_loc_player
    j    case_0_moved_left
    case_0_player_is_standing_on_target:
    # else: update player to 3
    li   t6, 3
    sw   t6, 0(a1)
    # Update player platform status
    li   t6, 0
    sw   t6, 0(a4)
    case_0_moved_left:
    li   t6, 0
    bne  a0, t6, case_0_moved_right
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, -1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_0_moved_right:
    li   t6, 1
    bne  a0, t6, case_0_moved_up
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, 1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_0_moved_up:
    li   t6, 2
    bne  a0, t6, case_0_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, -1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    case_0_moved_down:
    #li   t6, 3
    #bne  a0, t6, case_0_moved_down:
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, 1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    

    pui_case_1:  # CASE_1: Player (1/6) moves into an unfilled target (3)
    # Check case condition
    li   t6, 3
    bne  t2, t6, pui_case_2
    # Update player platform status
    li   t6, 1
    sw   t6, 0(a4)
    # Update block
    li   t6, 6
    sw   t6, 0(a2)
    case_1_player_NOT_standing_on_target:
    # if (player is NOT standing on a target): update player to 0
    li   t6, 6
    beq  t1, t6, case_1_player_is_standing_on_target
    li   t6, 0
    sw   t6, 0(a1)
    # Jump to update curr_loc_player
    j    case_1_moved_left
    case_1_player_is_standing_on_target:
    # else: update player to 3
    li   t6, 3
    sw   t6, 0(a1)
    case_1_moved_left:
    li   t6, 0
    bne  a0, t6, case_1_moved_right
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, -1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_1_moved_right:
    li   t6, 1
    bne  a0, t6, case_1_moved_up
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, 1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_1_moved_up:
    li   t6, 2
    bne  a0, t6, case_1_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, -1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    case_1_moved_down:
    #li   t6, 3
    #bne  a0, t6, case_1_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, 1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1

    
    pui_case_2:  # CASE_2: Player (1/6) pushes on a box (2)
    # Check case condition
    li   t6, 2
    bne  t2, t6, pui_case_3

    pui_case_2_0:  # CASE_2_0: blockblock == wall (5)
    li   t6, 5
    beq  t3, t6, pui_return_0
    pui_case_2_1:  # CASE_2_1: blockblock == box (2)
    li   t6, 2
    beq  t3, t6, pui_return_0
    pui_case_2_2:  # CASE_2_2: blockblock == box_on_target (4)
    li   t6, 4
    beq  t3, t6, pui_return_0
    pui_case_2_3:  # CASE_2_3: blockblock == empty_space (0)
    # Check case condition
    li   t6, 0
    bne  t3, t6, pui_case_2_4
    # Update blockblock
    li   t6, 2
    sw   t6, 0(a3)
    # Update block
    li   t6, 1
    sw   t6, 0(a2)
    # Jump to update player movement data
    j    case_2_player_NOT_standing_on_target
    pui_case_2_4:  # CASE_2_4: blockblock == unfilled_target (3)
    # Check case condition
    li   t6, 3
    #bne  t3, t6, pui_return_1
    # Update remaining box count
    lw   t6, 0(s1)
    addi t6, t6, -1
    sw   t6, 0(s1)
    # Update blockblock
    li   t6, 4
    sw   t6, 0(a3)
    # Update block
    li   t6, 1
    sw   t6, 0(a2)
    # Jump to update player movement data
    j    case_2_player_NOT_standing_on_target

    case_2_player_NOT_standing_on_target:
    # if (player is NOT standing on a target): update player to 0
    li   t6, 6
    beq  t1, t6, case_2_player_is_standing_on_target
    li   t6, 0
    sw   t6, 0(a1)
    # Jump to update curr_loc_player
    j    case_0_moved_left

    case_2_player_is_standing_on_target:
    # else: update player to 3
    li   t6, 3
    sw   t6, 0(a1)
    
    case_2_moved_left:
    li   t6, 0
    bne  a0, t6, case_2_moved_right
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, -1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_2_moved_right:
    li   t6, 1
    bne  a0, t6, case_2_moved_up
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, 1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_2_moved_up:
    li   t6, 2
    bne  a0, t6, case_2_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, -1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    case_2_moved_down:
    #li   t6, 3
    #bne  a0, t6, case_2_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, 1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    
    
    pui_case_3:  # CASE_3: Player (1/6) pushes on a box that is resting on a target (4)
    # Check case condition
    li   t6, 4
    bne  t2, t6, pui_case_4

    pui_case_3_0:  # CASE_3_0: blockblock == wall (5)
    li   t6, 5
    beq  t3, t6, pui_return_0
    pui_case_3_1:  # CASE_3_1: blockblock == box (2)
    li   t6, 2
    beq  t3, t6, pui_return_0
    pui_case_3_2:  # CASE_3_2: blockblock == box_on_target (4)
    li   t6, 4
    beq  t3, t6, pui_return_0
    pui_case_3_3:  # CASE_3_3: blockblock == empty_space (0)
    # Check case condition
    li   t6, 0
    bne  t3, t6, pui_case_3_4
    # Update player platform status
    li   t6, 1
    sw   t6, 0(a4)
    # Update remaining box count
    lw   t6, 0(s1)
    addi t6, t6, 1
    sw   t6, 0(s1)
    # Update blockblock
    li   t6, 2
    sw   t6, 0(a3)
    # Update block
    li   t6, 6
    sw   t6, 0(a2)
    # Jump to update player movement data
    j    case_3_player_NOT_standing_on_target
    pui_case_3_4:  # CASE_3_4: blockblock == unfilled_target (3)
    # Check case condition
    #li   t6, 3
    #bne  t3, t6, pui_case_3_moved_down
    # Update player platform status
    li   t6, 1
    sw   t6, 0(a4)
    # Update blockblock
    li   t6, 4
    sw   t6, 0(a3)
    # Update block
    li   t6, 1
    sw   t6, 0(a2)
    # Jump to update player movement data
    j    case_3_player_NOT_standing_on_target

    case_3_player_NOT_standing_on_target:
    # if (player is NOT standing on a target): update player to 0
    li   t6, 6
    beq  t1, t6, case_3_player_is_standing_on_target
    li   t6, 0
    sw   t6, 0(a1)
    # Jump to update curr_loc_player
    j    case_0_moved_left

    case_3_player_is_standing_on_target:
    # else: update player to 3
    li   t6, 3
    sw   t6, 0(a1)
    
    case_3_moved_left:
    li   t6, 0
    bne  a0, t6, case_3_moved_right
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, -1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_3_moved_right:
    li   t6, 1
    bne  a0, t6, case_3_moved_up
    # Update curr_loc_player
    lw   t0, 4(s2)
    addi t0, t0, 1
    sw   t0, 4(s2)
    # RETURN_1
    j    pui_return_1
    case_3_moved_up:
    li   t6, 2
    bne  a0, t6, case_3_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, -1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1
    case_3_moved_down:
    #li   t6, 3
    #bne  a0, t6, case_3_moved_down
    # Update curr_loc_player
    lw   t0, 0(s2)
    addi t0, t0, 1
    sw   t0, 0(s2)
    # RETURN_1
    j    pui_return_1

    pui_case_4:  # CASE_4: Player pushes a wall (5)
    # Check case condition
    li   t6, 5
    beq  t2, t6, pui_return_0


    pui_return_0:
    # RETURN_0
    li   a0, 0
    jr   ra



    pui_return_1:
    # RETURN_1
    li   a0, 1
    jr   ra

# --------------------------------------------------------------------------- #
# DEBUGGG_PRINT_VALUES_1                                                      #
#                                                                             #
# Double check that the initial values for a particular level have been       #
# generated and calculated correctly.                                         #
#                                                                             #
# Args:                                                                       #
#   N/A                                                                       #
# Pre-Conditions AND Post-Conditions:                                         #
#   0(s1) == Grid width - 1                                                   #
#   4(s1) == Grid height - 1                                                  #
#   0(s7) == Number of internal walls                                         #
#   0(s3) == Number of empty grids                                            #
#   0(s2) == Box count                                                        #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
DEBUGGG_PRINT_VALUES_1:
    la   a0, newline
    li   a7, 4
    ecall
    # Check the grid height
    la   a0, db_grid_rows
    li   a7, 4
    ecall
    lw   a0, 0(s1)
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    # Check the grid width
    la   a0, db_grid_cols
    li   a7, 4
    ecall
    lw   a0, 4(s1)
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    # Check the number of internal walls
    la   a0, db_int_walls
    li   a7, 4
    ecall
    lw   a0, 0(s7)
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    # Check the total number of empty grids
    la   a0, db_empty_grids
    li   a7, 4
    ecall
    lw   a0, 0(s3)
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    # Check the box count
    la   a0, db_box_count
    li   a7, 4
    ecall
    lw   a0, 0(s2)
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    # RETURN
    jr   ra


# --------------------------------------------------------------------------- #
# DEBUGGG_PRINT_VALUES_2                                                      #
#                                                                             #
# Doublecheck that the number of bytes to be allocated on the stack is        #
# correctly calculated (each grid index is 4 bytes).                          #
#                                                                             #
# Args:                                                                       #
#   N/A                                                                       #
# Pre-Conditions AND Post-Conditions:                                         #
#   t2 = (cols*rows)*4 = total bytes to allocate for grid state               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
DEBUGGG_PRINT_VALUES_2:
    # Check for the correct byte size for stack allocation
    la   a0, newline
    li   a7, 4
    ecall
    la   a0, db_stack_bytes
    ecall
    mv   a0, t2
    li   a7, 1
    ecall
    la   a0, newline
    li   a7, 4
    ecall
    ecall
    # RETURN
    jr   ra


# --------------------------------------------------------------------------- #
# DEBUGGG_PRINT_GRID_STATE_INIT                                               #
#                                                                             #
# Print the initial grid state to console.                                    #
#                                                                             #
# Args:                                                                       #
#   a0: number of rows                                                        #
#   a1: number of cols                                                        #
# Post-Conditions:                                                            #
#   - The value of SP shall be the same before AND after a call to this       #
#     function.                                                               #
#   - The value of FP shall be the same before AND after a call to this       #
#     function.                                                               #
# Return:                                                                     #
#   N/A                                                                       #
# --------------------------------------------------------------------------- #
DEBUGGG_PRINT_GRID_STATE_INIT:  # t3=&str_display, t4=misc, t6=0(sp)
    mv   sp, fp  # STACK PUSH
    la   t3, str_display
    li   t0, 0   # t0=0 < a0=max_row_index
    pgsi_row_START:
        li   t1, 0   # t1=0 < a1=max_col_index
        pgsi_col_START:
            lw   t6, 0(sp)
            pgsi_col_empty:  # if (grid_state[t0][t1] == 0): construct empty cell
            li   t4, 0
            bne  t6, t4, pgsi_col_wall
            li   t4, ' '
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsi_col_LOOP_COND

            pgsi_col_wall:  # if (grid_state[t0][t1] == 5): construct wall
            li   t4, 5
            bne  t6, t4, pgsi_col_box
            li   t4, '='
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsi_col_LOOP_COND

            pgsi_col_box:  # if (grid_state[t0][t1] == 2): construct box
            li   t4, 2
			bne  t6, t4, pgsi_col_player
            li   t4, '%'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsi_col_LOOP_COND

            pgsi_col_player:  # if (grid_state[t0][t1] == 1): construct player
            li   t4, 1
			bne  t6, t4, pgsi_col_target_unfilled
            li   t4, 'A'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)
            j pgsi_col_LOOP_COND

            pgsi_col_target_unfilled:  # if (grid_state[t0][t1] == 3): construct target (unfilled)
            li   t4, '*'
            sb   t4, 0(t3)
            li   t4, ' '
            sb   t4, 1(t3)

            pgsi_col_LOOP_COND:
            addi t3, t3, 2
            addi sp, sp, 4
            addi t1, t1, 1
            blt  t1, a1, pgsi_col_START
        pgsi_col_END:
        pgsi_row_LOOP_COND:
        li   t4, '\n'
        sb   t4, 0(t3)
        addi t3, t3, 1
        addi t0, t0, 1
        blt  t0, a0, pgsi_row_START
    pgsi_row_END:
    # Null-terminate the string
    li   t4, 0
    sb   t4, 0(t3)
    # Print init grid state
    la   a0, str_display
    li   a7, 4
    ecall
    # RETURN
    li   sp, 0x80000000  # STACK POP
    jr   ra
