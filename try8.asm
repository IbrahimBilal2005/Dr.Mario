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
color_black: .word 0x000000
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
	
     #logic for generating new capsule
     
    after_capsule_generate:
    # Continuously check keyboard input
    lw $t0, ADDR_KBRD   # Load keyboard address
    lw $t1, 0($t0)      # Read first word (1 if key is pressed)

    bne $t1, 1, continue_fall  # If no key is pressed, continue gravity

    lw $t1, 4($t0)      # Load the actual key pressed

    beq $t1, 0x77, handle_rotate  		# 'w' - Rotate
    beq $t1, 0x61, move_left      		# 'a' - Move Left
    beq $t1, 0x64, move_right      		# 'd' - Move Right
    beq $t1, 0x73, move_down_fast  		# 's' - Drop Fast
    j continue_fall 				# Invalid key input 

    handle_rotate:
    	jal erase_capsule		# erase the current capsule
    	jal rotate_capsule		# determine updated location based on rotation 
    	jal draw_capsule 		# redraw the capsule based on any updates
    	j continue_fall
    	
   	# logic to check if capsule has stopped and connected 4 colours
  
continue_fall:
    # Speed up gravity - reduce delay for a more natural fall speed
    li $v0, 32  # Reduce delay for faster gravity
    syscall
    jal move_down  # Continue capsule falling
    
    # if no more viruses, end game, else generate new capsule by looping back to game loop
    
    j after_capsule_generate


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
    lw $t5, capsule_left # Load left half color
    lw $t6, capsule_right # Load right half color
    
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

    # Calculate current level (Y position / 128)
    div $t3, $a0, 128  # Get current level (integer division)
    mflo $t3           # Store quotient (level number)

    # Calculate left boundary: 12 pixels from start of level
    mul $t2, $t3, 128  # Base of current level
    addi $t2, $t2, 12  # Add 12 pixels

    # Prevent moving past the left boundary
    ble $a0, $t2, continue_fall  # If at left limit, don't move

    # Calculate previous addresses to clear
    add $t8, $t0, $a0  # Address of left half
    add $t9, $t0, $a1  # Address of right half

    # Clear previous location
    sw $zero, 0($t8)  # Clear left half
    sw $zero, 0($t9)  # Clear right half

    # Move left by 1 pixel (4 bytes per pixel)
    subi $a0, $a0, 4  
    subi $a1, $a1, 4

    # Store new position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Redraw capsule at new location
    jal draw_capsule
    j move_down
    jr $ra
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

    sw $t3, capsule_right_pos     # Update right capsule position (now above)
    j rotate_end                  # Jump to the end

rotate_to_horizontal:
    # Compute new right position (move right by one column)
    addi $t3, $t0, 4              # $t3 = left_pos + 4 (move to the right)

    # Get memory address for the new position
    lw $t4, ADDR_DSPL             # Load display base address
    add $t5, $t4, $t3             # Compute address of new position
    lw $t6, 0($t5)                 # Load color value at new position

    # Check if the new position is occupied
    lw $t7, color_black             # Load background color (black)
    bne $t6, $t7, rotate_fail     # If not empty, play error sound and return
    
    sw $t3, capsule_right_pos     # Update right capsule position (now to the right)
    j rotate_end                  # Jump to the end

rotate_fail:
    # jal play_error_sound          # Play error sound if rotation is blocked
    j rotate_end

rotate_end:
    # Restore return address and return to caller
    lw $ra, 0($sp)                
    addi $sp, $sp, 4              
    jr $ra                        # Return


    
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
