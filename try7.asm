################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################
 
    .data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL:  .word 0x10008000  # Address of the bitmap display
ADDR_KBRD:  .word 0xffff0000  # Address of the keyboard

row_width:  .word 256          # 64 pixels * 4 bytes per pixel
gray_color: .word 0x808080      # Gray color

color_red:    .word 0xFF0000  # Red
color_blue:   .word 0x0000FF  # Blue
color_yellow: .word 0xFFFF00  # Yellow

##############################################################################
# Mutable Data
##############################################################################
capsule_left:  .word 0  # Stores left half of capsule
capsule_right: .word 0  # Stores right half of capsule
capsule_left_pos:  .word 552  # Initial position of left half
capsule_right_pos: .word 680  # Initial position of right half
lfsr_seed:     .word 0xA1E6  # Initial LFSR seed (change for different sequences)
##############################################################################
# Code
##############################################################################
	.text
	.globl main

main:
    lw $t1, gray_color  # Load gray color
    lw $t4, color_red
    lw $t5, color_blue
    lw $t6, color_yellow
    lw $t0, ADDR_DSPL   # Load display base address

    # Step 1: Draw the medicine bottle (Only Once)
    jal draw_box  

    # Step 2: Generate first half color
generate_first_half:
    jal lfsr_next  # Generate next LFSR value
    andi $t1, $v0, 0x0003  # Mask lowest 2 bits (0-3 range)
    beq $t1, 3, generate_first_half  # If 3, retry (only allow 0,1,2)

    la $t2, color_red  # Base address of colors
    sll $t1, $t1, 2    # Multiply by 4 (word size)
    add $t2, $t2, $t1  # Get address of chosen color
    lw $t3, 0($t2)     # Load the first capsule half color
    sw $t3, capsule_left  # Store first half

    # Step 3: Generate second half color
generate_second_half:
    jal lfsr_next
    andi $t1, $v0, 0x0003
    beq $t1, 3, generate_second_half  # If 3, retry

    la $t2, color_red
    sll $t1, $t1, 2
    add $t2, $t2, $t1
    lw $t4, 0($t2)    # Load the second capsule half color
    sw $t4, capsule_right  # Store second half

    # Step 4: Draw Capsule
    li $a0, 552  # First half position
    li $a1, 680  # Second half position
    jal draw_capsule  # Draw capsule

game_loop:
    # Speed up gravity - reduce delay for a more natural fall speed
    li $v0, 32  # Reduce delay for faster gravity
    syscall

    # Continuously check keyboard input
    lw $t0, ADDR_KBRD   # Load keyboard address
    lw $t1, 0($t0)      # Read first word (1 if key is pressed)

    beqz $t1, continue_fall  # If no key is pressed, continue gravity

    lw $t1, 4($t0)      # Load the actual key pressed

    beq $t1, 0x77, rotate_capsule  # 'w' - Rotate
    beq $t1, 0x61, move_left       # 'a' - Move Left
    beq $t1, 0x64, move_right      # 'd' - Move Right
    beq $t1, 0x73, move_down_fast  # 's' - Drop Fast

continue_fall:
    jal move_down  # Continue capsule falling
    j game_loop


##############################################################################
# Function: lfsr_next (16-bit LFSR Pseudo-Random Number Generator)
##############################################################################
lfsr_next:
    lw $s0, lfsr_seed  # Load LFSR seed

    # LFSR feedback (XOR taps at 16, 14, 13, 11)
    li $t1, 0xB400     # Polynomial for taps (0b1011_0100_0000_0000)
    and $t2, $s0, 1    # Get lowest bit
    beqz $t2, no_xor   # If LSB = 0, skip XOR
    xor $s0, $s0, $t1  # Apply XOR with polynomial

no_xor:
    srl $s0, $s0, 1  # Shift right (divide by 2)
    sw $s0, lfsr_seed  # Store updated LFSR seed
    move $v0, $s0  # Return LFSR value
    jr $ra  # Return

##############################################################################
# Function: draw_capsule (Place Random Capsule in Memory)
##############################################################################
draw_capsule:
    lw $t0, ADDR_DSPL  # Load display base address
    lw $t5, capsule_left  # Load left half color
    lw $t6, capsule_right # Load right half color

    # Compute the address for the first half (552)
    add $t7, $t0, $a0  # t7 = base + 552
    sw $t5, 0($t7)  # Store first half color

    # Compute the address for the second half (680)
    add $t8, $t0, $a1  # t8 = base + 680
    sw $t6, 0($t8)  # Store second half color

    jr $ra  # Return
##############################################################################
# Function: draw_box (Medicine Bottle)
##############################################################################
draw_box:
    # Draw Top of Medicine Bottle
    sw $t1, 648($t0)
    sw $t1, 652($t0)
    sw $t1, 656($t0)
    sw $t1, 660($t0)
    sw $t1, 664($t0)
    sw $t1, 668($t0)
    sw $t1, 672($t0)

    sw $t1, 544($t0)
    sw $t1, 416($t0)

    sw $t1, 560($t0)
    sw $t1, 432($t0)

    sw $t1, 688($t0)
    sw $t1, 692($t0)
    sw $t1, 696($t0)
    sw $t1, 700($t0)
    sw $t1, 704($t0)
    sw $t1, 708($t0)
    sw $t1, 712($t0)

    # Draw Sides of the Medicine Bottle
    li $t2, 648  # Left column start offset
    li $t3, 712  # Right column start offset
    li $t4, 3464 # Bottom limit for left side
    li $t5, 3528 # Bottom limit for right side

side_loop:
    add $t9, $t0, $t2  # Compute address for left column
    sw $t1, 0($t9)     # Store gray pixel in left column

    add $s0, $t0, $t3  # Compute address for right column
    sw $t1, 0($s0)     # Store gray pixel in right column

    addi $t2, $t2, 128  # Move one row down (Y+1)
    addi $t3, $t3, 128  # Move one row down (Y+1)

    ble $t2, $t4, side_loop  # Keep looping until reaching the bottom
    ble $t3, $t5, side_loop

    # Drawing Bottom of the Medicine Bottle (Using a Loop)
    li $t6, 3592  # Start of bottom row
    li $t7, 3656  # End of bottom row

bottom_loop:
    add $t9, $t0, $t6  # Compute address for bottom row
    sw $t1, 0($t9)     # Store gray pixel in bottom row

    addi $t6, $t6, 4  # Move right (X+1)

    ble $t6, $t7, bottom_loop  # Keep looping until reaching the end

    jr $ra  # Return
    
##############################################################################
# Function: move_down (Apply Gravity)
##############################################################################
move_down:
    lw $t0, ADDR_DSPL       # Load display base address
    lw $t5, capsule_left     # Left half color
    lw $t6, capsule_right    # Right half color

    # Load current positions
    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos

    # Check if it reaches the bottom (Y = 58, last row)
    li $t2, 3272  # Bottom boundary
    bge $a0, $t2, stop_moving

    # Clear previous position (set to background color)
    add $t8, $t0, $a0
    sw $zero, 0($t8)  # Clear left half

    add $t9, $t0, $a1
    sw $zero, 0($t9)  # Clear right half

    # Move down by one row (128 bytes per row)
    addi $a0, $a0, 128
    addi $a1, $a1, 128

    # Store updated position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Draw capsule at new position
    jal draw_capsule

    j game_loop  # Continue looping

stop_moving:
    # When it reaches the bottom, generate a new capsule
    jal generate_new_capsule
    j game_loop

##############################################################################
# Function: move_down_fast ('s' key to drop quickly)
##############################################################################
move_down_fast:
    jal move_down  # Move capsule down instantly
    j game_loop    # Keep dropping (no delay)

##############################################################################
# Function: move_left ('a' key)
##############################################################################
move_left:
    lw $t0, ADDR_DSPL      # Load display base address

    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos

    # Determine if the capsule is vertical or horizontal
    sub $t3, $a1, $a0  # Difference between positions

    # If difference is 128, it's vertical
    li $t4, 128
    beq $t3, $t4, check_vertical_left

    # Otherwise, it's horizontal
    j check_horizontal_left

check_vertical_left:
    # Check left of both top and bottom halves
    subi $t7, $a0, 4  # Left of top half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    subi $t7, $a1, 4  # Left of bottom half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    or $t9, $t9, $t9  # If either pixel is nonzero (not black), stop
    bnez $t9, continue_fall
    j move_left_continue

check_horizontal_left:
    # Check only the leftmost pixel
    subi $t7, $a0, 4  # Left of leftmost half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    bnez $t9, continue_fall  # If not black, don't move
    j move_left_continue

move_left_continue:
    # Clear previous position (set to background color)
    add $t8, $t0, $a0
    sw $zero, 0($t8)  # Clear left half

    add $t9, $t0, $a1
    sw $zero, 0($t9)  # Clear right half

    # Move left by 1 pixel (4 bytes per pixel)
    subi $a0, $a0, 4  
    subi $a1, $a1, 4

    # Store new position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Redraw capsule at new location
    jal draw_capsule

    j move_down  # Continue falling

continue_fall:
    j move_down  # Continue normal movement


##############################################################################
# Function: move_right ('d' key)
##############################################################################
move_right:
    lw $t0, ADDR_DSPL      # Load display base address

    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos

    # Calculate current level (Y position / 128)
    div $t3, $a0, 128  # Get current level (integer division)
    mflo $t3           # Store quotient (level number)

    # Calculate right boundary: 56 pixels from start of level
    mul $t2, $t3, 128  # Base of current level
    subi $t2, $t2, 56  # 56 pixels away from right of level

    # Prevent moving past the right boundary
    ble $a1, $t2, continue_fall  # If at right limit, don't move

    # Calculate previous addresses to clear
    add $t8, $t0, $a0  # Address of left half
    add $t9, $t0, $a1  # Address of right half

    # Clear previous location
    sw $zero, 0($t8)  # Clear left half
    sw $zero, 0($t9)  # Clear right half

    # Move right by 1 pixel (4 bytes per pixel)
    addi $a0, $a0, 4  
    addi $a1, $a1, 4

    # Store new position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Redraw capsule at new location
    jal draw_capsule
    j move_down
    jr $ra

##############################################################################
# Function: rotate_capsule ('w' key)
##############################################################################
rotate_capsule:
    lw $t0, ADDR_DSPL      # Load display base address
    lw $t5, capsule_left   # Load left half color
    lw $t6, capsule_right  # Load right half color
    lw $t7, gray_color     # Load background color

    # Load current positions
    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos

    # Compute current capsule shape (horizontal or vertical)
    sub $t8, $a1, $a0  # Difference between left & right half

    # Clear current capsule (set to background color)
    add $t9, $t0, $a0
    sw $t7, 0($t9)  # Clear left half

    add $t9, $t0, $a1
    sw $t7, 0($t9)  # Clear right half

    # If horizontal (difference = 4), make vertical
    beq $t8, 4, horizontal_to_vertical

    # Otherwise, it's vertical -> make horizontal
    j vertical_to_horizontal

horizontal_to_vertical:
    addi $t9, $a0, 128  # Move second half **one row down**
    
    # Check if rotation is **within boundaries**
    li $t2, 3528  # Bottom boundary
    bge $t9, $t2, finish_rotation  # Don't rotate if at bottom

    move $a1, $t9  # Apply vertical rotation
    j finish_rotation

vertical_to_horizontal:
    subi $t9, $a0, 128  # Move second half **one column right**
    
    # Check if rotation is **within boundaries**
    li $t2, 648  # Left wall boundary
    ble $t9, $t2, finish_rotation  # Don't rotate if out of bounds

    move $a1, $t9  # Apply horizontal rotation

finish_rotation:
    # Store updated positions
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    jal draw_capsule  # Redraw rotated capsule
    j move_down
    jr $ra  # Return
    
##############################################################################
# Function: generate_new_capsule (Spawn a new capsule at the top)
##############################################################################
generate_new_capsule:
    # Reset capsule position to the top
    li $a0, 552  # Reset to top row
    li $a1, 680

    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    jal draw_capsule  # Draw new capsule
    jr $ra
