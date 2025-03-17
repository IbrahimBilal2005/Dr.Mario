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
lfsr_seed:     .word 0xA1E7  # Initial LFSR seed (change for different sequences)

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
    j game_loop  # Infinite loop

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
