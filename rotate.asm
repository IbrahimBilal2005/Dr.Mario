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
color_black:  .word 0x000000

##############################################################################
# Mutable Data
##############################################################################
capsule_left_colour:  .word 0  # Stores left half colour of capsule
capsule_right_colour: .word 0  # Stores right half colour of capsule

capsule_left_pos:  .word 0  # Stores left half position of capsule
capsule_right_pos:  .word 0  # Stores left half position of capsule

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
    sw $t3, capsule_left_colour  # Store first half

    # Step 3: Generate second half color
generate_second_half:
    jal lfsr_next
    andi $t1, $v0, 0x0003
    beq $t1, 3, generate_second_half  # If 3, retry

    la $t2, color_red
    sll $t1, $t1, 2
    add $t2, $t2, $t1
    lw $t4, 0($t2)    # Load the second capsule half color
    sw $t4, capsule_right_colour  # Store second half

    # Step 4: Draw Capsule 
    li $a0, 552  # First half position
    li $a1, 680  # Second half position
    
    sw $a0, capsule_right_pos	#initialize capsule left position
    sw $a1, capsule_left_pos	#initialize capsule right position
    
    jal draw_capsule  # Draw capsule

game_loop:

generate_complete:

    # First check if any key has been pressed
    lw $t0, ADDR_KBRD                   	# $t0 = keyboard base address
    lw $t1, 0($t0)				# Load first word from keyboard
    bne $t1, 1, keyboard_input_complete	# If the first word is not 1, no key is pressed
    
    # Check which was pressed
    lw $t1, 4($t0)               	# $t1 = key pressed (second word from keyboard)
    beq $t1, 0x70, handle_pause         	# Check if the key is 'p'
    beq $t1, 0x71, handle_game_end      	# Check if the key is 'q'
    beq $t1, 0x77, handle_rotate	# Check if the key is 'w'
    beq $t1, 0x61, handle_move_left     	# Check if the key is 'a'
    beq $t1, 0x73, handle_move_down     	# Check if the key is 's'
    beq $t1, 0x64, handle_move_right    	# Check if the key is 'd'
    beq $t1, 0x72, handle_reset         	# Check if the key is 'r'
    beq $t1, 0x7a, change_capsule	# Check if the key is 'z'
    
    j keyboard_input_complete         # Invalid key pressed
    
    handle_pause:
        # jal pause
        j keyboard_input_complete
        
    handle_rotate:
    	jal rotate
    	
        j keyboard_input_complete
    handle_move_left:

        j keyboard_input_complete
    handle_move_down:
       
        j keyboard_input_complete
    handle_move_right:
       
        j keyboard_input_complete
    handle_change_capsule:
     
    handle_reset:
        j main
        
    handle_game_end:
    	#
        
    keyboard_input_complete:
    
    
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
    lw $t5, capsule_left_colour # Load left half color
    lw $t6, capsule_right_colour # Load right half color
    
    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos
    
    # Compute the address for the first half (552)
    add $t7, $t0, $a0  # t7 = base + 552
    sw $t5, 0($t7)  # Store first half color

    # Compute the address for the second half (680)
    add $t8, $t0, $a1  # t8 = base + 680
    sw $t6, 0($t8)  # Store second half color

    jr $ra  # Return
    
##############################################################################
# Function: erase_capsule (Place Random Capsule in Memory)
##############################################################################
erase_capsule:
    # Load the black color
    lw $t0, color_black   # $t0 = black color (0x000000)

    # Load the capsule's current positions
    lw $t1, capsule_left_pos   # $t1 = left capsule position
    lw $t2, capsule_right_pos  # $t2 = right capsule position

    lw $t3, ADDR_DSPL  
    add $t4, $t3, $t1  
    sw $t0, 0($t4)  

    add $t5, $t3, $t2  
    sw $t0, 0($t5) 
    
    jr $ra  # Return to caller
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
# Function: rotate
##############################################################################

rotate:
    # Save return address to stack (so we can return after rotation)
    addi $sp, $sp, -4   
    sw $ra, 0($sp)       

    # Load left and right capsule positions
    lw $t0, capsule_left_pos      	# $t0 = Left capsule position
    lw $t1, capsule_right_pos     	# $t1 = Right capsule position

    # Check if capsule is currently horizontal (right is exactly 4 bytes ahead)
    addi $t2, $t0, 4              	# $t2 = left_pos + 4 (horizontal check)
    beq $t1, $t2, rotate_to_vertical  # If right_pos == left_pos + 4, rotate to vertical

    j rotate_to_horizontal 		# If not horizontal, it must be vertical → Rotate to horizontal
     

rotate_to_vertical:
    # Compute new right position (move up one row)
    addi $t3, $t0, -128           # $t3 = left_pos - 128 (move to row above)

    # Get memory address for the new position
    lw $t4, ADDR_DSPL             # Load display base address
    add $t5, $t4, $t3             # Compute address of new position
    lw $t6, 0($t5)                # Load color value at new position

    # Check if the new position is occupied
    lw $t7, color_black             # Load background color (black)
    bne $t6, $t7, rotate_fail     # If not empty, play error sound and return

    # Erase old capsule, update position, redraw
    jal erase_capsule
    
    sw $t3, capsule_right_pos     # Update right capsule position (now above)
    jal draw_capsule              # Draw the capsule at the new rotated position
    j rotate_end                  # Jump to the end

rotate_to_horizontal:
    # Compute new right position (move right by one column)
    addi $t3, $t0, 4              # $t3 = left_pos + 4 (move to the right)

    # Get memory address for the new position
    #lw $t4, ADDR_DSPL             # Load display base address
    #add $t5, $t4, $t3             # Compute address of new position
    lw $t4, ADDR_DSPL  
    add $t5, $t4, $t3  
    lw $t6, 0($t5)                 # Load color value at new position

    # Check if the new position is occupied
    lw $t7, color_black             # Load background color (black)
    bne $t6, $t7, rotate_fail     # If not empty, play error sound and return

    # Erase old capsule, update position, redraw
    jal erase_capsule
    
    sw $t3, capsule_right_pos     # Update right capsule position (now to the right)
    jal draw_capsule              # Draw the capsule at the new rotated position
    j rotate_end                  # Jump to the end

rotate_fail:
    # jal play_error_sound          # Play error sound if rotation is blocked
    j rotate_end

rotate_end:
    # Restore return address and return to caller
    lw $ra, 0($sp)                
    addi $sp, $sp, 4              
    jr $ra                        # Return


pause:
game_end:
move_left:
move_right:
move_down:
reset:
change_capsule:


