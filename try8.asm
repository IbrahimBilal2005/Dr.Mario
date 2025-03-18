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
lfsr_seed:     .word 0   # Initial LFSR seed (change for different sequences)
##############################################################################
# Code
##############################################################################
	.text
	.globl main

main:

    jal initialize_random_seed
    
    lw $t1, gray_color  # Load gray color
    lw $t4, color_red
    lw $t5, color_blue
    lw $t6, color_yellow
    lw $t0, ADDR_DSPL   # Load display base address
	

    # Step 1: Draw the medicine bottle (Only Once)
    jal draw_box  

    # Step 2: Generate capsule colors (replacing the old first/second half generation)
    jal generate_capsule_colors  # This new function handles both colors

    # Step 3: Draw Capsule
    li $a0, 552  # First half position
    li $a1, 680  # Second half position
    jal draw_capsule  # Draw capsule

game_loop:
    # Speed up gravity - reduce delay for a more natural fall speed
    li $v0, 32  # Reduce delay for faster gravity
    syscall
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

    jal move_down  # Continue capsule falling
    j game_loop
    # if no more viruses, end game, else generate new capsule by looping back to game loop

##############################################################################
# Function: initialize_random_seed
# Uses system time to generate a seed for the LFSR
##############################################################################
initialize_random_seed:
    # Get system time
    li $v0, 30           # syscall 30: get system time
    syscall              # time stored in $a0 (low) and $a1 (high)
    
    # Use the lower 16 bits of the low word as our seed
    andi $t0, $a0, 0xFFFF
    
    # Ensure the seed is never zero (which is bad for LFSR)
    beqz $t0, use_fallback_seed
    
    # Store the seed
    sw $t0, lfsr_seed
    jr $ra
    
use_fallback_seed:
    # In the unlikely event that we get a 0 seed, use a fallback
    li $t0, 0xACE1
    sw $t0, lfsr_seed
    jr $ra
    
##############################################################################
# Function: lfsr_next (Improved 16-bit LFSR)
##############################################################################
lfsr_next:
    lw $t0, lfsr_seed      # Load current seed
    
    # Check if seed is 0 (bad state)
    beqz $t0, init_lfsr_seed
    
    # Update LFSR (taps at 16, 14, 13, 11)
    move $t1, $t0
    srl $t2, $t1, 0        # Bit 0
    srl $t3, $t1, 2        # Bit 2
    srl $t4, $t1, 3        # Bit 3
    srl $t5, $t1, 5        # Bit 5
    
    # XOR all taps
    xor $t6, $t2, $t3
    xor $t6, $t6, $t4
    xor $t6, $t6, $t5
    
    # Mask to get just the least significant bit
    andi $t6, $t6, 1
    
    # Shift and insert feedback bit
    srl $t0, $t0, 1
    sll $t6, $t6, 15
    or $t0, $t0, $t6
    
    # Store new seed
    sw $t0, lfsr_seed
    
    # Return new value
    move $v0, $t0
    jr $ra

init_lfsr_seed:
    # Initialize with a non-zero seed
    li $t0, 0xACE1      # Different initial value
    sw $t0, lfsr_seed
    
    # Return the new seed
    move $v0, $t0
    jr $ra

##############################################################################
# Function: generate_capsule_colors (Generate random colors for capsule)
##############################################################################
generate_capsule_colors:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Generate first half color
    jal generate_random_color
    sw $v0, capsule_left
    
    # Generate second half color
    jal generate_random_color
    sw $v0, capsule_right
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Function: generate_random_color (Returns a random color from the color list)
##############################################################################
generate_random_color:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Generate a random number
    jal lfsr_next
    move $t0, $v0
    
    # Use modulo 3 to get a number between 0-2
    # We'll use division to get remainder when divided by 3
    li $t1, 3
    div $t0, $t1
    mfhi $t2    # $t2 contains the remainder (0, 1, or 2)
    
    # Map the remainder to a color index
    la $t3, color_red    # Base address of color array
    sll $t4, $t2, 2      # Multiply by 4 (word size)
    add $t3, $t3, $t4    # Compute address of color
    lw $v0, 0($t3)       # Load the color
    
    # Restore return address and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    

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

    # Check if it reaches the bottom (bottom row)
    li $t2, 3464  # Correct bottom boundary (one row lower)
    bge $a0, $t2, stop_moving
    bge $a1, $t2, stop_moving  # Also check right side

    # Determine if the capsule is vertical or horizontal
    sub $t3, $a1, $a0  # Difference between positions

    # If difference is 128, it's vertical
    li $t4, 128
    beq $t3, $t4, check_vertical

    # Otherwise, it's horizontal
    j check_horizontal

check_vertical:
    # Check the pixel below the lower half
    addi $t7, $a1, 128
    add $t8, $t0, $t7
    lw $t9, 0($t8)  # Load color of the pixel below

    bnez $t9, stop_moving  # If it's not black, stop moving
    j move_down_continue   # Otherwise, move down

check_horizontal:
    # Check the pixel below left half
    addi $t7, $a0, 128
    add $t8, $t0, $t7
    lw $t9, 0($t8)  # Load color of the pixel below left half
    bnez $t9, stop_moving  # If not black, stop moving

    # Check the pixel below right half
    addi $t7, $a1, 128
    add $t8, $t0, $t7
    lw $s1, 0($t8)  # Load color of the pixel below right half
    bnez $s1, stop_moving  # If not black, stop moving

    j move_down_continue

move_down_continue:
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

    # Check if capsule is horizontal or vertical
    sub $t3, $t1, $t0
    li $t4, 4
    beq $t3, $t4, fast_down_horizontal  # If t1-t0 = 4, it's horizontal
    j fast_down_vertical                # Otherwise it's vertical

fast_down_horizontal:
    # Keep moving down until we hit something
horizontal_loop:
    # Calculate positions one row down
    addi $t2, $t0, 128   # Left position + 1 row
    addi $t3, $t1, 128   # Right position + 1 row
    
    # Check if we've hit the bottom boundary
    li $t6, 3592         # Correct bottom boundary (one row lower)
    bge $t2, $t6, end_fast_drop
    bge $t3, $t6, end_fast_drop  # Also check right side

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

fast_down_vertical:
    # Keep moving down until we hit something
vertical_loop:
    # Check both pieces for vertical orientation
    addi $t2, $t0, 128   # Top piece + 1 row down
    addi $t3, $t1, 128   # Bottom piece + 1 row down
    
    # Check if we've hit the bottom boundary
    li $t6, 3592         # Correct bottom boundary (one row lower)
    bge $t3, $t6, end_fast_drop  # Check if bottom piece hits boundary

    # Check if there's something below bottom half
    add $t7, $t5, $t3    # Address of pixel below bottom half
    lw $t8, 0($t7)       # Load color at that position
    bnez $t8, end_fast_drop  # If not black (0), stop

    # Move capsule down one row
    addi $t0, $t0, 128   # Move top half down
    addi $t1, $t1, 128   # Move bottom half down
    
    j vertical_loop      # Continue checking next row

end_fast_drop:
    # Update capsule positions with final location
    sw $t0, capsule_left_pos
    sw $t1, capsule_right_pos
    
    # Draw capsule at new position
    jal draw_capsule

    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    j continue_fall  # Return to main loop
    
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

##############################################################################
# Function: move_right ('d' key)
##############################################################################
move_right:
    lw $t0, ADDR_DSPL      # Load display base address

    lw $a0, capsule_left_pos
    lw $a1, capsule_right_pos

    # Determine if the capsule is vertical or horizontal
    sub $t3, $a1, $a0  # Difference between positions

    # If difference is 128, it's vertical
    li $t4, 128
    beq $t3, $t4, check_vertical_right

    # Otherwise, it's horizontal
    j check_horizontal_right

check_vertical_right:
    # Check right of both top and bottom halves
    addi $t7, $a0, 4  # Right of top half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    addi $t7, $a1, 4  # Right of bottom half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    or $t9, $t9, $t9  # If either pixel is nonzero (not black), stop
    bnez $t9, continue_fall
    j move_right_continue

check_horizontal_right:
    # Check only the rightmost pixel
    addi $t7, $a1, 4  # Right of rightmost half
    add $t8, $t0, $t7
    lw $t9, 0($t8)    # Load color of pixel

    bnez $t9, continue_fall  # If not black, don't move
    j move_right_continue

move_right_continue:
    # Clear previous position (set to background color)
    add $t8, $t0, $a0
    sw $zero, 0($t8)  # Clear left half

    add $t9, $t0, $a1
    sw $zero, 0($t9)  # Clear right half

    # Move right by 1 pixel (4 bytes per pixel)
    addi $a0, $a0, 4  
    addi $a1, $a1, 4

    # Store new position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    # Redraw capsule at new location
    jal draw_capsule

    j move_down  # Continue falling

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
# Function: generate_new_capsule (Spawn a new capsule at the top with random colors)
##############################################################################
generate_new_capsule:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Use the improved color generation system
    jal generate_capsule_colors  # This will set both capsule_left and capsule_right colors
    
    # Reset capsule position to the top
    li $t0, 552  # Reset to top position for left half (middle of the top)
    li $t1, 556  # Position for horizontal capsule (right next to left part)
    
    # Store the new positions
    sw $t0, capsule_left_pos
    sw $t1, capsule_right_pos
    
    # Draw the new capsule with its random colors
    jal draw_capsule
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra