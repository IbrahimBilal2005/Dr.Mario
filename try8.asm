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
lfsr_seed:     .word 0xBe12  # Initial LFSR seed (change for different sequences)
##############################################################################
# Code
##############################################################################
	.text
	.globl main

main:
    # Initialize random seed from system time
    jal set_random_seed_from_time

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
     
    after_capsule_generate:
    # Continuously check keyboard input
    lw $t0, ADDR_KBRD   # Load keyboard address
    lw $t1, 0($t0)      # Read first word (1 if key is pressed)

    bne $t1, 1, continue_fall  # If no key is pressed, continue gravity

    lw $t1, 4($t0)      # Load the actual key pressed

    beq $t1, 0x77, handle_rotate  		# 'w' - Rotate
    beq $t1, 0x61, handle_left      		# 'a' - Move Left
    beq $t1, 0x64, handle_right      		# 'd' - Move Right
    beq $t1, 0x73, handle_down_fast  		# 's' - Drop Fast
    j continue_fall 				# Invalid key input 

    handle_rotate:
        jal erase_capsule 	# First erase the current capsule
	jal rotate_capsule     # Determine updated location based on rotation
    	jal draw_capsule     	# Redraw the capsule based on updated positions
    	j continue_fall     	# Continue with the game loop
    handle_left:
        jal erase_capsule 	# First erase the current capsule
	jal move_left     	# Determine updated location based on left movement
    	jal draw_capsule     	# Redraw the capsule based on updated positions
    	j continue_fall     	# Continue with the game loop
    handle_right:
        jal erase_capsule 	# First erase the current capsule
	jal move_right     	# Determine updated location based on right movement
    	jal draw_capsule     	# Redraw the capsule based on updated positions
    	j continue_fall     	# Continue with the game loop
    handle_down_fast:
        jal erase_capsule 	# First erase the current capsule
	jal move_down_fast     # Determine updated location based on fast down
    	jal draw_capsule     	# Redraw the capsule based on updated positions
    	j continue_fall     	# Continue with the game loop
    	
continue_fall:

    jal move_down  # Continue capsule falling
    j game_loop

##############################################################################
# Function: set_random_seed_from_time
##############################################################################
set_random_seed_from_time:
    # Get system time
    li $v0, 30         # System call code for time
    syscall            # System time in $a0 (low) and $a1 (high)
    
    # Use the low-order 16 bits as our seed
    andi $t0, $a0, 0xFFFF  # Extract lower 16 bits of time
    
    # Ensure seed is not zero (LFSR needs non-zero seed)
    beqz $t0, use_default_seed
    
    # Store the seed
    sw $t0, lfsr_seed
    j seed_set_done
    
use_default_seed:
    # If time was zero for some reason, use a default seed
    li $t0, 0xBe12
    sw $t0, lfsr_seed
    
seed_set_done:
    jr $ra  # Return
    
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

    # Determine if the capsule is vertical or horizontal and which way
    sub $t3, $a1, $a0       # Difference between positions

    # Possible orientations:
    # 4: horizontal (right is to the right of left)
    # 128: vertical (right is below left)
    # -4: horizontal (right is to the left of left)
    # -128: vertical (right is above left)

    li $t4, 4
    beq $t3, $t4, check_horizontal    # Right is to the right of left

    li $t4, 128
    beq $t3, $t4, check_vertical_down        # Right is below left

    li $t4, -4
    beq $t3, $t4, check_horizontal   # Right is to the left of left

    li $t4, -128
    beq $t3, $t4, check_vertical_up          # Right is above left

    # Default case (should not happen)
    j stop_moving

check_vertical_down:
    # For vertical orientation with right below left, only check below the bottom piece (right)
    addi $t7, $a1, 128      # Position below right (bottom) half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below
    bnez $t9, stop_moving   # If not black, stop moving
    j move_down_continue    # Otherwise, move down

check_vertical_up:
    # For vertical orientation with right above left, only check below the bottom piece (left)
    addi $t7, $a0, 128      # Position below left (bottom) half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below
    bnez $t9, stop_moving   # If not black, stop moving
    j move_down_continue    # Otherwise, move down

check_horizontal:
    # For horizontal orientation with right to the right of left, check below both pieces
    addi $t7, $a0, 128      # Position below left half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below left
    bnez $t9, stop_moving   # If not black, stop moving

    addi $t7, $a1, 128      # Position below right half
    add $t8, $t0, $t7
    lw $s1, 0($t8)          # Load color of pixel below right
    bnez $s1, stop_moving   # If not black, stop moving
    j move_down_continue    # Otherwise, move down

move_down_continue:
    # Clear previous position (set to background color)
    add $t8, $t0, $a0
    sw $zero, 0($t8)        # Clear left half

    add $t9, $t0, $a1
    sw $zero, 0($t9)        # Clear right half

    # Move down by one row (128 bytes per row)
    addi $a0, $a0, 128
    addi $a1, $a1, 128

    # Store updated position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Draw capsule at new position
    jal draw_capsule

    j game_loop             # Continue looping

stop_moving:
    # When it reaches the bottom or is blocked, generate a new capsule
    jal generate_new_capsule
    j game_loop

##############################################################################
# Function: move_down_fast ('s' key to drop quickly)
##############################################################################
move_down_fast:
    # Save return address to stack
    addi $sp, $sp, -4   
    sw $ra, 0($sp)

    # First erase the current capsule
    jal erase_capsule
       
    # Load display address and current positions
    lw $t5, ADDR_DSPL
    lw $t0, capsule_left_pos
    lw $t1, capsule_right_pos

    # Determine orientation based on position difference
    sub $t3, $t1, $t0           # t3 = right - left

    # Check orientation type
    li $t4, 4                   # Horizontal (right to right of left)
    beq $t3, $t4, fast_down_horizontal
    
    li $t4, 128                 # Vertical (right below left)
    beq $t3, $t4, fast_down_vertical_down
    
    li $t4, -4                  # Horizontal (right to left of left)
    beq $t3, $t4, fast_down_horizontal
    
    li $t4, -128                # Vertical (right above left)
    beq $t3, $t4, fast_down_vertical_up
    
    # Default case (shouldn't happen)
    j end_fast_drop

fast_down_horizontal: # Keep moving down until we hit something (right is to right of left)
horizontal_loop:
    # Calculate positions one row down
    addi $t2, $t0, 128   # Left position + 1 row
    addi $t3, $t1, 128   # Right position + 1 row
    
    # Check if there's something below left half
    add $t7, $t5, $t2    # Address of pixel below left half
    lw $t8, 0($t7)       # Load color at that position
    bnez $t8, end_fast_drop  # If not black (0), stop

    # Check if there's something below right half
    add $t7, $t5, $t3    # Address of pixel below right half
    lw $t8, 0($t7)       # Load color at that position
    bnez $t8, end_fast_drop  # If not black (0), stop

    # Move capsule down one row
    move $t0, $t2
    move $t1, $t3
    
    j horizontal_loop    # Continue checking next row

fast_down_vertical_down: # Keep moving down until we hit something (right is below left)
vertical_down_loop:
    # Only need to check below the bottom piece (right)
    addi $t3, $t1, 128   # Bottom piece (right) + 1 row down

    # Check if there's something below bottom half
    add $t7, $t5, $t3    # Address of pixel below bottom half
    lw $t8, 0($t7)       # Load color at that position
    bnez $t8, end_fast_drop  # If not black (0), stop

    # Move capsule down one row
    addi $t0, $t0, 128   # Move top half down
    addi $t1, $t1, 128   # Move bottom half down
    
    j vertical_down_loop      # Continue checking next row

fast_down_vertical_up: # Keep moving down until we hit something (right is above left)
vertical_up_loop:
    # Only need to check below the bottom piece (left)
    addi $t2, $t0, 128   # Bottom piece (left) + 1 row down

    # Check if there's something below bottom half
    add $t7, $t5, $t2    # Address of pixel below bottom half
    lw $t8, 0($t7)       # Load color at that position
    bnez $t8, end_fast_drop  # If not black (0), stop

    # Move capsule down one row
    addi $t0, $t0, 128   # Move top half down
    addi $t1, $t1, 128   # Move bottom half down
    
    j vertical_up_loop      # Continue checking next row

end_fast_drop:
    # Update capsule positions with final location
    sw $t0, capsule_left_pos
    sw $t1, capsule_right_pos

    jal draw_capsule

    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    jr $ra  # Return to caller
   
##############################################################################
# Function: move_left ('a' key)
##############################################################################
move_left:
# get left and right positions
# if left - right = 128 or -128
#	if either left side of both left and right is not black, dont move
#	else: update positions of both to one left
# if left - right = 4, right is to the left
# 	if left side of right is not black, dont move
#	else: update positions of both to one left
# if left - right = -4, left is to the left 
# 	if right side of left is not black, dont move
#	else: update positions of both to one right

# Save return address to stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load display address and capsule positions
    lw $t0, ADDR_DSPL      # Load display base address
    lw $t1, capsule_left_pos
    lw $t2, capsule_right_pos

    # Determine orientation based on position difference
    sub $t3, $t1, $t2  # Difference between positions (left - right)

    # Check orientation to determine which pieces to check
    li $t5, -4         # Horizontal (left is to the left of right)
    beq $t3, $t5, left_check_left_piece
    
    li $t5, 4          # Horizontal (right is to the left of left)
    beq $t3, $t5, left_check_right_piece
    
    li $t5, -128       # Vertical (left is above right)
    beq $t3, $t5, left_check_both_pieces
    
    li $t5, 128        # Vertical (left is below right)
    beq $t3, $t5, left_check_both_pieces
    
    j end_move_right   # Unknown orientation, don't move

left_check_left_piece:
    # Check only the left piece (left is leftmost)
    addi $t5, $t1, -4   # Position to the left of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_left  # If not black (0), don't move
   
    j perform_move_left

left_check_right_piece:
    # Check only the right piece (right is leftmost)
    addi $t5, $t2, -4   # Position to the left of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_left  # If not black (0), don't move
    
    j perform_move_left

left_check_both_pieces:
    # Check both pieces (vertical orientation)
    addi $t5, $t1, -4   # Position to the left of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move

    addi $t5, $t2, -4   # Position to the left of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move
    
    j perform_move_left

perform_move_left:
    # Move left by 1 pixel (4 bytes per pixel)
    addi $t1, $t1, -4   # Move left piece right
    addi $t2, $t2, -4   # Move right piece right
    
    # Update capsule positions
    sw $t1, capsule_left_pos
    sw $t2, capsule_right_pos

end_move_left:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    j continue_fall    # Continue with the main game loop
    
##############################################################################
# Function: move_right ('d' key)
##############################################################################
move_right:
# get left and right positions
# if left - right = 128 or -128
#	if either right side of both left and right is not black, dont move
#	else: update positions of both to one right
# if left - right = 4, left is to the right
# 	if right side of right is not black, dont move
#	else: update positions of both to one right
# if left - right = -4, right is to the right 
# 	if right side of left is not black, dont move
#	else: update positions of both to one right

# Save return address to stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load display address and capsule positions
    lw $t0, ADDR_DSPL      # Load display base address
    lw $t1, capsule_left_pos
    lw $t2, capsule_right_pos

    # Determine orientation based on position difference
    sub $t3, $t1, $t2  # Difference between positions (left - right)

    # Check orientation to determine which pieces to check
    li $t5, -4         # Horizontal (right is to the right of left)
    beq $t3, $t5, right_check_right_piece
    
    li $t5, 4          # Horizontal (left is to the right of right)
    beq $t3, $t5, right_check_left_piece
    
    li $t5, -128       # Vertical (right is below left)
    beq $t3, $t5, right_check_both_pieces
    
    li $t5, 128        # Vertical (right is above left)
    beq $t3, $t5, right_check_both_pieces
    
    j end_move_right   # Unknown orientation, don't move

right_check_right_piece:
    # Check only the right piece (right is rightmost)
    addi $t5, $t2, 4   # Position to the right of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move
   
    j perform_move_right

right_check_left_piece:
    # Check only the left piece (left is rightmost)
    addi $t5, $t1, 4   # Position to the right of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move
    
    j perform_move_right

right_check_both_pieces:
    # Check both pieces (vertical orientation)
    addi $t5, $t1, 4   # Position to the right of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move

    addi $t5, $t2, 4   # Position to the right of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     # Load color at that position
    bnez $t7, end_move_right  # If not black (0), don't move
    
    j perform_move_right

perform_move_right:
    # Move right by 1 pixel (4 bytes per pixel)
    addi $t1, $t1, 4   # Move left piece right
    addi $t2, $t2, 4   # Move right piece right
    
    # Update capsule positions
    sw $t1, capsule_left_pos
    sw $t2, capsule_right_pos

end_move_right:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    j continue_fall    # Continue with the main game loop

##############################################################################
# Function: rotate_capsule ('w' key)
##############################################################################
rotate_capsule:

# get the left and right position. 
# we will treat the left position as an anchor, meaning it never moves during rotations
# calculate the different between the two positions to determine the current state
# if left - right = -4, right is to the right of left
#	if the position below left is black
#		update position of right capsule and redraw
#	else rotation not possible
# if left - right = 4, right is to the left of left
#	if the position above left is black
#		update position of right capsule and redraw
#	else rotation not possible
# if left - right - 128, right is above left
#	if the position to the left of left is black
#		update position of right capsule and redraw
#	else rotation not possible
# if left - right = -128, righ is below left 
#	if the position to the right of left is black
#		update position of right capsule and redraw
#	else rotation not possible


    # Save return address to stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the display address and current capsule positions
    lw $t0, ADDR_DSPL
    lw $t1, capsule_left_pos   # Left position (anchor)
    lw $t2, capsule_right_pos  # Right position

    # Calculate difference to determine current orientation
    sub $t3, $t2, $t1          # t3 = right - left (changed from left-right)

    # Check orientation and rotate accordingly
    li $t4, 4                  # Right is to the right of left
    beq $t3, $t4, rotate_horizontal_to_vertical_down

    li $t4, 128                # Right is below left
    beq $t3, $t4, rotate_vertical_to_horizontal_left

    li $t4, -4                 # Right is to the left of left
    beq $t3, $t4, rotate_horizontal_to_vertical_up

    li $t4, -128               # Right is above left
    beq $t3, $t4, rotate_vertical_to_horizontal_right

    j rotation_complete        # Invalid state or already handled

rotate_horizontal_to_vertical_down:
    # Right is to the right, rotate to down
    # Check if position below left is empty
    addi $t4, $t1, 128         # Address below left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             # Load color at that position
    bnez $t6, rotation_complete # If not black, rotation not possible

    # Update right capsule position to below left (left position stays the same)
    addi $t2, $t1, 128         # New right position is below left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_vertical_to_horizontal_left:
    # Right is below, rotate to left
    # Check if position to the left of left is empty
    addi $t4, $t1, -4          # Address to the left of left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             # Load color at that position
    bnez $t6, rotation_complete # If not black, rotation not possible

    # Update right capsule position to left of left (left position stays the same)
    addi $t2, $t1, -4          # New right position is to the left of left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_horizontal_to_vertical_up:
    # Right is to the left, rotate to up
    # Check if position above left is empty
    addi $t4, $t1, -128        # Address above left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             # Load color at that position
    bnez $t6, rotation_complete # If not black, rotation not possible

    # Update right capsule position to above left (left position stays the same)
    addi $t2, $t1, -128        # New right position is above left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_vertical_to_horizontal_right:
    # Right is above, rotate to right
    # Check if position to the right of left is empty
    addi $t4, $t1, 4           # Address to the right of left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             # Load color at that position
    bnez $t6, rotation_complete # If not black, rotation not possible

    # Update right capsule position to right of left (left position stays the same)
    addi $t2, $t1, 4           # New right position is to the right of left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotation_complete:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Function: generate_new_capsule (Spawn a new capsule at the top)
##############################################################################
generate_new_capsule:
    # Save return address to stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Reset capsule position to the top
    li $t0, 552  # Reset to top row
    li $t1, 680

    sw $t0, capsule_left_pos
    sw $t1, capsule_right_pos

    # Generate new random colors for the capsule
    # First half color
    jal lfsr_next  # Generate next LFSR value
    andi $t1, $v0, 0x0003  # Mask lowest 2 bits (0-3 range)
    beq $t1, 3, skip_first_half  # If 3, retry (only allow 0,1,2)

    la $t2, color_red  # Base address of colors
    sll $t1, $t1, 2    # Multiply by 4 (word size)
    add $t2, $t2, $t1  # Get address of chosen color
    lw $t3, 0($t2)     # Load the first capsule half color
    sw $t3, capsule_left  # Store first half

skip_first_half:
    # Second half color
    jal lfsr_next
    andi $t1, $v0, 0x0003
    beq $t1, 3, skip_second_half  # If 3, retry

    la $t2, color_red
    sll $t1, $t1, 2
    add $t2, $t2, $t1
    lw $t4, 0($t2)    # Load the second capsule half color
    sw $t4, capsule_right  # Store second half

skip_second_half:
    # Draw the new capsule
    jal draw_capsule

    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
