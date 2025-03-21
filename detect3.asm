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
color_white: .word 0xFFFFFF	# White 
color_green: .word 0x39FF14 #Green

game_over_flag: .word 0       # 0 = game running, 1 = game over

GAME_OVER_ARRAY:
    .word
    # "GAME OVER" represented as a 19x11 grid (0 = blank, -1 = pixel)
    0, -1, -1, 0, 0, 0, 0, -1, 0, 0, -1, 0, 0, 0, -1, 0, 0, -1, -1, 0,  # G A M E
    -1, 0, 0, 0, 0, 0, -1, 0, -1, 0, -1, -1, 0, -1, -1, 0, -1, 0, 0, 0,
    -1, 0, -1, -1, -1, 0, -1, -1, -1, 0, -1, -1, -1, -1, -1, 0, -1, -1, 0, 0,
    -1, 0, 0, -1, 0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, 0, 0,
    0, -1, -1, 0, 0, 0, -1, 0, -1, 0, -1, 0, 0, 0, -1, 0, 0, -1, -1, 0,
    
    # Empty row between "GAME" and "OVER"
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    
    # "OVER" as a 20x5 grid
    0, 0, -1, 0, 0, -1, 0, 0, 0, -1, 0, 0, -1, -1, 0, -1, -1, 0, 0, 0,  # O V E R
    0, -1, 0, -1, 0, -1, -1, 0, -1, -1, 0, -1, 0, 0, 0, -1, 0, -1, 0, 0, 
    0, -1, 0, -1, 0, 0, -1, 0, -1, 0, 0, -1, -1, 0, 0, -1, -1, 0, 0, 0,
    0, -1, 0, -1, 0, 0, -1, -1, -1, 0, 0, -1, 0, 0, 0, -1, 0, -1, 0, 0, 
    0, 0, -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, -1, -1, 0, -1, 0, 0, -1, 0
    
PRESS_R_ARRAY:
    .word
    # "RESTART" represented as a 7x5 grid
    -1, 0, -1, -1, 0, 0, -1, 
    -1, 0, -1, 0, -1, 0, -1, 
     0, 0, -1, -1, 0, 0, 0, 
     0, 0, -1, 0, -1, 0, 0, 
     0, 0, -1, 0, 0, -1, 0
     
PAUSE_ARRAY:
    .word
    # "II" represented as a 3x4 grid (0 = blank, -1 = pixel)
    -1, 0, -1, 
    -1, 0, -1, 
    -1, 0, -1, 
    
##############################################################################
# Mutable Data
##############################################################################
capsule_left:  .word 0  	# Stores left half of capsule
capsule_right: .word 0  	# Stores right half of capsule
capsule_left_pos:  .word 552  	# Initial position of left half
capsule_right_pos: .word 680  	# Initial position of right half

#### Increase fall delay to slow down capsules
fall_delay:    .word 40      	# Delay for gravity (milliseconds) 
move_delay:    .word 5       	# Delay for controls (milliseconds)
gravity_counter: .word 0     	# Counter for gravity application
gravity_speed:   .word 50    	# Apply gravity every N frames

ghost_color: .word 0xb0aeae   	# Gray color for ghost capsule
ghost_left_pos:  .word 0      	# Position of left ghost capsule
ghost_right_pos: .word 0      	# Position of right ghost capsule

is_paused:      .word 0       # 0 = not paused, 1 = paused

##############################################################################
# Code
##############################################################################
	.text
	.globl main
main:
    lw $t1, gray_color  	# Load colors
    lw $t4, color_red
    lw $t5, color_blue
    lw $t6, color_yellow
    lw $t0, ADDR_DSPL   	# Load display base address

    jal draw_box 			# Step 1: Draw the medicine bottle (Only Once)
    jal generate_capsule_colors	# Step 2: Generate capsule colors

    # Reset capsule positions to initial values
    li $t0, 552
    sw $t0, capsule_left_pos
    li $t0, 680
    sw $t0, capsule_right_pos
    
    # Reset ghost positions
    li $t0, 0
    sw $t0, ghost_left_pos
    sw $t0, ghost_right_pos
    
    sw $zero, gravity_counter	    # Reset gravity counter
    
    jal draw_capsule  		# Draw capsule

game_loop:
    li $v0, 32			# Apply a shorter delay for smoother controls
    lw $a0, move_delay
    syscall
    
    # Check if game is paused, if so skip all game updates
    lw $t0, is_paused
    bnez $t0, check_unpause
    
    lw $t0, gravity_counter	# Increment gravity counter
    addi $t0, $t0, 1
    sw $t0, gravity_counter
    lw $t1, gravity_speed	# Check if it's time to apply gravity
    blt $t0, $t1, skip_gravity
    sw $zero, gravity_counter	# Reset gravity counter and apply gravity
    jal apply_gravity
    
skip_gravity:

    jal draw_ghost_capsule    	# Draw ghost capsule
    
    lw $t0, ADDR_KBRD   	# Load keyboard address
    lw $t1, 0($t0)      	# Read first word (1 if key is pressed)
    bne $t1, 1, game_loop  	# If no key is pressed, continue loop
    lw $t1, 4($t0)      	# Load the actual key pressed

    beq $t1, 0x70, initiate_pause # 'p' - Toggle pause state
    
    # If game is paused, ignore all other inputs
    lw $t0, is_paused
    bnez $t0, game_loop
    
    beq $t1, 0x77, initiate_rotate  	# 'w' - Rotate
    beq $t1, 0x61, initiate_left      	# 'a' - Move Left
    beq $t1, 0x64, initiate_right     	# 'd' - Move Right
    beq $t1, 0x73, initiate_down_fast 	# 's' - Drop Fast
    beq $t1, 0x71, game_over    	# 'q' - Quit/Game Over
    beq $t1, 0x72, restart_game 	# 'r' - Restart
    j game_loop 			# Invalid key input 
    
    check_unpause:	    # When paused, only check for unpause key
    lw $t0, ADDR_KBRD         # Load keyboard address
    lw $t1, 0($t0)            # Read first word (1 if key is pressed)
    bne $t1, 1, game_loop     # If no key is pressed, continue loop
    lw $t1, 4($t0)            # Load the actual key pressed
    
    beq $t1, 0x70, initiate_pause 	# 'p' - Toggle pause state
    j game_loop               		# Any other key, continue waiting

    initiate_rotate:
        jal erase_ghost_capsule	# Erase ghost capsule first
        jal erase_capsule 	  	# Erase the current capsule
        jal rotate_capsule		# Determine updated location based on rotation
        jal draw_capsule     	  	# Redraw the capsule based on updated positions
        j game_loop     	  	# Continue with the game loop
    initiate_left:
        jal erase_ghost_capsule  	# Erase ghost capsule first
        jal erase_capsule 	  	# Erase the current capsule
        jal move_left     	  	# Determine updated location based on left movement
        jal draw_capsule     	  	# Redraw the capsule based on updated positions
        j game_loop     	  	# Continue with the game loop
    initiate_right:
        jal erase_ghost_capsule  	# Erase ghost capsule first
        jal erase_capsule 	  	# Erase the current capsule
        jal move_right     	  	# Determine updated location based on right movement
        jal draw_capsule     	  	# Redraw the capsule based on updated positions
        j game_loop     	  	# Continue with the game loop
    initiate_down_fast:
        jal erase_ghost_capsule  	# Erase ghost capsule first
        jal erase_capsule 	  	# Erase the current capsule
        jal move_down_fast        	# Determine updated location based on fast down
        jal draw_capsule     	  	# Redraw the capsule based on updated positions
        j game_loop     	  	# Continue with the game loop
    initiate_pause:
    	jal toggle_pause_state		# Toggle pause state
    	jal update_pause_display	# Draw or erase "PAUSED" text based on current state
    	j game_loop		       	# Return to game loop

##############################################################################
# Function to return random color
##############################################################################
generate_random_color:
    li $v0, 42                      # syscall 42: generate random number
    li $a0, 0                       # Random number generator ID 0
    li $a1, 3                       # Upper bound 3 (exclusive), so 0-2 inclusive
    syscall
    
    beq $a0, 0, return_red          # Check if the random number is 0
    beq $a0, 1, return_green        # Check if the random number is 1
    beq $a0, 2, return_blue         # Check if the random number is 2
    j colour_selection_end

return_red:
    lw $v0, color_red              # Return red color
    j colour_selection_end
return_green:
    lw $v0, color_yellow           # Return yellow color
    j colour_selection_end
return_blue:
    lw $v0, color_blue             # Return blue color
    j colour_selection_end
colour_selection_end:
    jr $ra

##############################################################################
# Function: generate_capsule_colors
# Generates random colors for both halves of the capsule using syscall
# Returns: None (updates capsule_left and capsule_right in memory)
##############################################################################
generate_capsule_colors:
    addi $sp, $sp, -4       # Save return address
    sw $ra, 0($sp)
    
    jal generate_random_color       # Generate first random color
    move $t2, $v0                   # $t2 = first color
    
    jal generate_random_color       # Generate second random color
    move $t3, $v0                   # $t3 = second color
    
    # Set left color
    move $a1, $t2                   # $a1 = first random color
    sw $a1, capsule_left            # Set left color
    
    # Set right color
    move $a1, $t3                   # $a1 = second random color
    sw $a1, capsule_right           # Set right color
    
    lw $ra, 0($sp)                  # Load return address
    addi $sp, $sp, 4               
    jr $ra                          # Return
    
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
    lw $t0, color_black   # Load lack color (0x000000)

    # Load the capsule's current positions
    lw $t1, capsule_left_pos   # $t1 = left capsule position
    lw $t2, capsule_right_pos  # $t2 = right capsule position

    lw $t3, ADDR_DSPL  
    add $t4, $t3, $t1  	# Calculate current position
    sw $t0, 0($t4)  		# Set value to black
    add $t5, $t3, $t2  
    sw $t0, 0($t5) 
    jr $ra  			# Return to caller
   
##############################################################################
# Apply Gravity Function 
##############################################################################
apply_gravity:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Apply gravity (former move_down code)
    jal erase_capsule  # Erase current position
    jal move_down      # Calculate new position
    jal draw_capsule   # Draw at new position
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Function: move_down (Apply Gravity)
##############################################################################
move_down:
    lw $t0, ADDR_DSPL        # Load display base address
    lw $t5, capsule_left     # Left half color
    lw $t6, capsule_right    # Right half color

    lw $a0, capsule_left_pos    # Load current positions
    lw $a1, capsule_right_pos

    # Determine if the capsule is vertical or horizontal and which way
    sub $t3, $a1, $a0       # Difference between positions

    # Orientation checks
    li $t4, 4
    beq $t3, $t4, check_horizontal    # Right is to the right of left
    li $t4, 128
    beq $t3, $t4, check_vertical_down # Right is below left
    li $t4, -4
    beq $t3, $t4, check_horizontal    # Right is to the left of left
    li $t4, -128
    beq $t3, $t4, check_vertical_up   	# Right is above left
    j stop_moving  		       	# Default case

check_vertical_down:
    # For vertical orientation with right below left
    addi $t7, $a1, 128      # Position below right (bottom) half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below
    beqz $t9, move_down_continue   # If black, move down
    
    # Check if it's a ghost capsule
    lw $t4, ghost_color
    beq $t9, $t4, move_down_continue  # If ghost color, move down
    j stop_moving   # Otherwise, stop moving

check_vertical_up:
    # For vertical orientation with right above left
    addi $t7, $a0, 128      # Position below left (bottom) half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below
    beqz $t9, move_down_continue   # If black, move down
    
    # Check if it's a ghost capsule
    lw $t4, ghost_color
    beq $t9, $t4, move_down_continue  # If ghost color, move down
    j stop_moving   # Otherwise, stop moving

check_horizontal:
    # For horizontal orientation, check below both pieces
    addi $t7, $a0, 128      # Position below left half
    add $t8, $t0, $t7
    lw $t9, 0($t8)          # Load color of pixel below left
    beqz $t9, check_horizontal_right   # If black, check right piece
    
    # Check if it's a ghost capsule
    lw $t4, ghost_color
    beq $t9, $t4, check_horizontal_right  # If ghost color, check right
    j stop_moving   	# Otherwise, stop moving

check_horizontal_right:
    addi $t7, $a1, 128      # Position below right half
    add $t8, $t0, $t7
    lw $s1, 0($t8)          		# Load color of pixel below right
    beqz $s1, move_down_continue   	# If black, move down
    
    # Check if it's a ghost capsule
    lw $t4, ghost_color
    beq $s1, $t4, move_down_continue  # If ghost color, move down
    j stop_moving   			# Otherwise, stop moving

move_down_continue:
    # Clear previous position (set to background color)
    add $t8, $t0, $a0
    sw $zero, 0($t8)        # Clear left half

    add $t9, $t0, $a1
    sw $zero, 0($t9)        # Clear right half

    addi $a0, $a0, 128	     # Move down by one row
    addi $a1, $a1, 128

    # Store updated position
    sw $a0, capsule_left_pos
    sw $a1, capsule_right_pos

    jal draw_capsule	    # Draw capsule at new position
    j game_loop            # Continue looping

stop_moving:    
    jal erase_ghost_capsule	# Erase ghost capsule when capsule stops
    jal draw_capsule		# Draw the current capsule in its final position
    
    # Reset ghost positions
    li $t0, 0
    sw $t0, ghost_left_pos
    sw $t0, ghost_right_pos
    
    jal check_for_matches
    jal generate_new_capsule	    # Then generate a new capsule
    j game_loop

##############################################################################
# Function: move_down_fast ('s' key to drop quickly)
##############################################################################
move_down_fast:
    # Save return address to stack
    addi $sp, $sp, -4   
    sw $ra, 0($sp)
    
    # Load display address and current positions
    lw $t5, ADDR_DSPL
    lw $t0, capsule_left_pos
    lw $t1, capsule_right_pos

    # Determine orientation based on position difference
    sub $t3, $t1, $t0           # t3 = right - left

fast_drop_loop:
    # Calculate positions one row down
    addi $t6, $t0, 128   # Left position + 1 row
    addi $t7, $t1, 128   # Right position + 1 row
    
    # Check if we've hit the bottom boundary
    li $t2, 3464            # Bottom boundary
    bge $t6, $t2, end_fast_drop
    bge $t7, $t2, end_fast_drop
    
    # Determine which pixel(s) to check based on orientation
    li $t4, 4                   # Horizontal (right to right of left)
    beq $t3, $t4, check_horizontal_fast
    
    li $t4, 128                 # Vertical (right below left)
    beq $t3, $t4, check_vertical_down_fast
    
    li $t4, -4                  # Horizontal (right to left of left)
    beq $t3, $t4, check_horizontal_fast
    
    li $t4, -128                # Vertical (right above left)
    beq $t3, $t4, check_vertical_up_fast
    
    j end_fast_drop	  # Default case - shouldn't happen

check_horizontal_fast:	  # Check below both pieces
    add $t8, $t5, $t6    # Address of pixel below left half
    lw $t9, 0($t8)       # Load color at that position
    bnez $t9, end_fast_drop  # If not black (0), stop

    add $t8, $t5, $t7    # Address of pixel below right half
    lw $t9, 0($t8)       # Load color at that position
    bnez $t9, end_fast_drop  # If not black (0), stop
    
    j update_fast_drop_pos

check_vertical_down_fast:    	# Only check below bottom piece (right)
    add $t8, $t5, $t7    	# Address of pixel below bottom half
    lw $t9, 0($t8)       	# Load color at that position
    bnez $t9, end_fast_drop  	# If not black (0), stop
    
    j update_fast_drop_pos

check_vertical_up_fast:  # Only check below bottom piece (left)
    add $t8, $t5, $t6    # Address of pixel below bottom half
    lw $t9, 0($t8)       # Load color at that position
    bnez $t9, end_fast_drop  # If not black (0), stop
    
    j update_fast_drop_pos

update_fast_drop_pos:	# Move capsule down one row
    move $t0, $t6    	# Update left position
    move $t1, $t7    	# Update right position
    
    j fast_drop_loop  	# Continue checking next row

end_fast_drop:		# Update capsule positions with final location
    sw $t0, capsule_left_pos
    sw $t1, capsule_right_pos

    # Restore return address and return normally
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra    
   
##############################################################################
# Function: move_left ('a' key)
##############################################################################
move_left:
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

left_check_left_piece:	  	# Check only the left piece (left is leftmost)
    addi $t5, $t1, -4   	# Position to the left of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     	# Load color at that position
    bnez $t7, end_move_left  	# If not black (0), don't move
    j perform_move_left

left_check_right_piece:	# Check only the right piece (right is leftmost)
    addi $t5, $t2, -4   	# Position to the left of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     	# Load color at that position
    bnez $t7, end_move_left  	# If not black (0), don't move
    j perform_move_left

left_check_both_pieces:	# Check both pieces (vertical orientation)
    addi $t5, $t1, -4   	# Position to the left of left piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     	# Load color at that position
    bnez $t7, end_move_right  	# If not black (0), don't move

    addi $t5, $t2, -4   	# Position to the left of right piece
    add $t6, $t0, $t5
    lw $t7, 0($t6)     	# Load color at that position
    bnez $t7, end_move_right  	# If not black (0), don't move
    j perform_move_left

perform_move_left:	 # Move left by 1 pixel
    addi $t1, $t1, -4   # Move left piece right
    addi $t2, $t2, -4   # Move right piece right
    
    # Update capsule positions
    sw $t1, capsule_left_pos
    sw $t2, capsule_right_pos

end_move_left:	   	# Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4   
    j apply_gravity    # Continue with the main game loop
    
##############################################################################
# Function: move_right ('d' key)
##############################################################################
move_right:
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
    j apply_gravity    # Continue with the main game loop

##############################################################################
# Function: rotate_capsule ('w' key)
##############################################################################
rotate_capsule:
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
    j rotation_complete        # Invalid state or already initiated

rotate_horizontal_to_vertical_down:	# Right is to the right, rotate to down
    addi $t4, $t1, 128         	# Address below left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             	# Load color at that position
    bnez $t6, rotation_complete     	# Check if position below left is empty

    # Update right capsule position to below left (left position stays the same)
    addi $t2, $t1, 128         # New right position is below left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_vertical_to_horizontal_left:  	# Right is below, rotate to left
    addi $t4, $t1, -4          	# Address to the left of left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             	# Load color at that position
    bnez $t6, rotation_complete     	# Check if position to the left of left is empty

    # Update right capsule position to left of left (left position stays the same)
    addi $t2, $t1, -4          # New right position is to the left of left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_horizontal_to_vertical_up:	# Right is to the left, rotate to up
    addi $t4, $t1, -128        	# Address above left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             	# Load color at that position
    bnez $t6, rotation_complete 	# Check if position above left is empty

    # Update right capsule position to above left (left position stays the same)
    addi $t2, $t1, -128        # New right position is above left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotate_vertical_to_horizontal_right:	# Right is above, rotate to right
    addi $t4, $t1, 4           	# Address to the right of left
    add $t5, $t0, $t4
    lw $t6, 0($t5)             	# Load color at that position
    bnez $t6, rotation_complete 	# Check if position to the right of left is empty

    # Update right capsule position to right of left (left position stays the same)
    addi $t2, $t1, 4           # New right position is to the right of left
    sw $t2, capsule_right_pos  # Store updated right position
    j rotation_complete

rotation_complete:     	# Restore return address
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
    
    jal generate_capsule_colors	# Generate new random colors for the capsule
    jal draw_capsule	   		# Draw the new capsule

    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
##############################################################################
# Function: check_for_matches (Remove 4+ in a row of same color)
##############################################################################
check_for_matches:
lw $t0, ADDR_DSPL      # $t0 = base address = 0x10008000
    addi $sp, $sp, -4
    sw $ra, 0($sp)

match_loop:
    li $t9, 0              # $t9 = found_match = 0
    li $t8, 416            # Start of play area
    li $t7, 3728           # End of play area

check_match_pixel:
    add $t1, $t0, $t8      # $t1 = current pixel address
    lw $t2, 0($t1)         # Load color

    # Skip if black or gray
    lw $t3, color_black
    beq $t2, $t3, next_pixel
    lw $t3, gray_color
    beq $t2, $t3, next_pixel

        #####################
    # Horizontal match
    #####################
    li $t4, 1              # Match count = 1 (we're on a valid pixel)
    move $s0, $t8          # Start position (anchor)
    move $s1, $t8          # Cursor to scan right

check_horiz:
    addi $s1, $s1, 4       # Move to the next pixel to the right

    # Stop if we cross row boundary
    li $t6, 256
    andi $t5, $s1, 0xFC     # current column (in bytes)
    andi $t7, $t8, 0xFC     # original column
    sub $t5, $t5, $t7
    bge $t5, $t6, done_horiz

    # Compare color at $s1 with $t2
    add $t3, $t0, $s1
    lw $t6, 0($t3)
    bne $t6, $t2, done_horiz

    addi $t4, $t4, 1       # Increment match count
    j check_horiz

done_horiz:
    li $t6, 4
    blt $t4, $t6, skip_horiz_clear
    li $t9, 1              # Found a match

    # Clear from $t8 for $t4 matches
    li $s2, 0
clear_horiz_loop:
    mul $s3, $s2, 4
    add $s4, $t8, $s3       # pixel offset = t8 + 4*i
    add $s5, $t0, $s4       # actual address
    sw $zero, 0($s5)
    addi $s2, $s2, 1
    blt $s2, $t4, clear_horiz_loop


skip_horiz_clear:

    #####################
    # Vertical match
    #####################
    li $t4, 0
    move $s0, $t8

check_vert_loop:
    add $t5, $t0, $s0
    lw $t6, 0($t5)
    bne $t6, $t2, end_vert
    addi $t4, $t4, 1
    addi $s0, $s0, 128     # Next row
    li $s1, 3548
    bgt $s0, $s1, end_vert
    j check_vert_loop

end_vert:
    li $s3, 4
    blt $t4, $s3, skip_vert_clear
    li $t9, 1              # Found match
    li $s0, 0
clear_vert_loop:
    mul $t5, $s0, 128
    add $t5, $t5, $t8
    add $t6, $t0, $t5
    sw $zero, 0($t6)
    addi $s0, $s0, 1
    blt $s0, $t4, clear_vert_loop

skip_vert_clear:

next_pixel:
    addi $t8, $t8, 4
    li $t3, 3660
    blt $t8, $t3, check_match_pixel

    beqz $t9, done_match_loop   # If no matches found, exit
    jal apply_gravity_to_floating_capsules  # Otherwise, apply gravity and check again
    j match_loop

done_match_loop:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
##############################################################################
# Function: apply_gravity_to_floating_capsules
##############################################################################
apply_gravity_to_floating_capsules:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

gravity_loop:
    li $t7, 0                # change_flag = 0
    lw $t0, ADDR_DSPL        # $t0 = base display address
    li $t1, 3456             # start from second-to-last row (row 60)
    li $t6, 416              # top of playable area

row_loop:
    li $t2, 0                # column offset

col_loop:
    add $t3, $t1, $t2        # pixel index = row + col
    add $t4, $t0, $t3        # pixel address
    lw $t5, 0($t4)           # color at (row, col)

    # Skip black or gray
    lw $s1, color_black
    beq $t5, $s1, skip
    lw $s2, gray_color
    beq $t5, $s2, skip

    # Check below
    addi $t9, $t3, 128       # pixel below
    li $s0, 3584
    bgt $t9, $s0, skip       # skip if out of bounds

    add $t8, $t0, $t9
    lw $s3, 0($t8)
    bne $s3, $s1, skip       # if pixel below is NOT black, skip

    

    # Move pixel down
    sw $zero, 0($t4)         # clear current
    sw $t5, 0($t8)           # move to below
    li $t7, 1                # set change_flag

skip:
    addi $t2, $t2, 4
    li $s1, 256
    blt $t2, $s1, col_loop

    addi $t1, $t1, -128
    bge $t1, $t6, row_loop

    bnez $t7, gravity_loop   # Repeat if changes occurred

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
    
    
 
##############################################################################
# Function: calculate_ghost_position (Calculate where capsule would land)
##############################################################################
calculate_ghost_position:
    # Save return address to stack
    addi $sp, $sp, -4   
    sw $ra, 0($sp)
    
    # Load display address and current capsule positions
    lw $t0, ADDR_DSPL
    lw $t1, capsule_left_pos
    lw $t2, capsule_right_pos
    
    # Store original positions for later use
    move $s0, $t1   # Store original left position
    move $s1, $t2   # Store original right position
    
    # Determine orientation based on position difference
    sub $t3, $t2, $t1   # t3 = right - left
    
ghost_drop_loop:
    # Calculate positions one row down
    addi $t6, $t1, 128   # Left position + 1 row
    addi $t7, $t2, 128   # Right position + 1 row
    
    # Check for bottle base pixels
    add $t8, $t0, $t6    # Address of pixel below left half
    lw $t9, 0($t8)       # Load color at that position
    lw $t4, gray_color   # Load bottle color
    beq $t9, $t4, end_ghost_calc  # If it's the bottle, stop here

    add $t8, $t0, $t7    # Address of pixel below right half
    lw $t9, 0($t8)       # Load color at that position
    beq $t9, $t4, end_ghost_calc  # If it's the bottle, stop here
    
    # Determine which pixel(s) to check based on orientation
    li $t4, 4                   # Horizontal (right)
    beq $t3, $t4, check_horizontal_ghost
    
    li $t4, -4                  # Horizontal (left)
    beq $t3, $t4, check_horizontal_ghost
    
    li $t4, 128                 # Vertical (down)
    beq $t3, $t4, check_vertical_ghost
    
    li $t4, -128                # Vertical (up)
    beq $t3, $t4, check_vertical_ghost
    
    # Default case - shouldn't happen
    j end_ghost_calc

check_horizontal_ghost:
    # Get both pixel colors below capsule pieces
    add $t8, $t0, $t6    # Address of pixel below left half
    lw $t9, 0($t8)       # Load color at that position
    
    add $t4, $t0, $t7    # Address of pixel below right half
    lw $t5, 0($t4)       # Load color at that position
    
    # If both are black (0), continue dropping
    beqz $t9, check_right_pixel
    
    # Left pixel has color, check if it's ghost
    lw $t4, ghost_color
    bne $t9, $t4, end_ghost_calc  # If not ghost color, stop
    
check_right_pixel:    
    beqz $t5, update_ghost_pos  # Right is black, continue dropping
    
    # Right pixel has color, check if it's ghost
    lw $t4, ghost_color
    bne $t5, $t4, end_ghost_calc  # If not ghost color, stop
    
    # Both pixels are either black or ghost, continue dropping
    j update_ghost_pos

check_vertical_ghost:
    # For vertical, only check below the bottom piece
    beq $t3, 128, check_bottom_right  # If right is below, check right
    
    # Otherwise, left is below so check left
    add $t8, $t0, $t6    # Address of pixel below left half
    j check_vertical_common
    
check_bottom_right:
    add $t8, $t0, $t7    # Address of pixel below right half
    
check_vertical_common:
    lw $t9, 0($t8)       # Load color at that position
    beqz $t9, update_ghost_pos  # If black (0), continue
    
    lw $t4, ghost_color
    beq $t9, $t4, update_ghost_pos  # If ghost color, continue
    j end_ghost_calc     # Otherwise, stop here

update_ghost_pos:
    # Move ghost position down one row
    move $t1, $t6    # Update left position
    move $t2, $t7    # Update right position
    
    j ghost_drop_loop  # Continue checking next row

end_ghost_calc:
    # Store the final ghost positions
    sw $t1, ghost_left_pos
    sw $t2, ghost_right_pos
    
    # Restore original capsule positions
    move $t1, $s0
    move $t2, $s1
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Function: draw_ghost_capsule (Draw the ghost capsule)
##############################################################################
draw_ghost_capsule:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Calculate ghost position first
    jal calculate_ghost_position
    
    # Don't draw if ghost position is same as actual position
    lw $t0, capsule_left_pos
    lw $t1, ghost_left_pos
    beq $t0, $t1, skip_ghost_draw
    
    # Draw ghost capsule
    lw $t0, ADDR_DSPL      # Load display base address
    lw $t1, ghost_color    # Load ghost color
    
    # Draw both halves of the ghost
    lw $t2, ghost_left_pos
    add $t3, $t0, $t2
    sw $t1, 0($t3)
    
    lw $t2, ghost_right_pos
    add $t3, $t0, $t2
    sw $t1, 0($t3)
    
skip_ghost_draw:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# Function: erase_ghost_capsule (Erase the ghost capsule)
##############################################################################
erase_ghost_capsule:
    # Load the black color and display address
    lw $t0, color_black   # $t0 = black color (0x000000)
    lw $t3, ADDR_DSPL
    
    # Load the ghost capsule's current positions
    lw $t1, ghost_left_pos
    lw $t2, ghost_right_pos
    
    # Only erase if positions are not zero (quick check both at once)
    or $t4, $t1, $t2
    beqz $t4, ghost_erase_done
    
    # Erase both halves
    add $t4, $t3, $t1
    sw $t0, 0($t4)
    
    add $t4, $t3, $t2
    sw $t0, 0($t4)
    
ghost_erase_done:
    jr $ra  # Return to caller
    
    
    
    
##############################################################################
# Function: draw_text_array - Generic function to draw any text array
#
# Parameters:
#   $a0 - Address of the array
#   $a1 - Start row
#   $a2 - Start column
#   $a3 - Width of the array (columns)
#   Stack+0 - Height of the array (rows)
#   Stack+4 - Color to use for drawing
##############################################################################
draw_text_array:
    # Save registers
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    
    # Load parameters
    move $s0, $a0              # Array address
    move $s1, $a1              # Start row
    move $s2, $a2              # Start column
    move $s3, $a3              # Width
    
    lw $t0, 20($sp)           	# Load height parameter from stack
    lw $t2, 24($sp)           	# Load color parameter from stack
    lw $t1, ADDR_DSPL         	# Load display address
    
    # Loop through rows
    li $t3, 0                  # Current row
draw_array_row_loop:
    beq $t3, $t0, draw_array_done   # If row == height, we're done
    
    # Loop through columns in this row
    li $t4, 0                  # Current column
draw_array_col_loop:
    beq $t4, $s3, draw_array_next_row   # If col == width, go to next row
    
    # Calculate array index: row * width + column
    mul $t5, $t3, $s3          # row * width
    add $t5, $t5, $t4          # + column
    sll $t5, $t5, 2            # * 4 (word size)
    add $t5, $t5, $s0          # + array base address
    
    lw $t6, 0($t5)	   	# Load the value from the array
    
    beq $t6, $zero, draw_array_skip_pixel	    # If value is -1, draw a pixel
    
    # Calculate display position: (start_row + row) * 128 + (start_col + col) * 4
    add $t7, $s1, $t3          # start_row + row
    sll $t7, $t7, 7            # * 128 (row width in bytes)
    add $t8, $s2, $t4          # start_col + col
    sll $t8, $t8, 2            # * 4 (bytes per pixel)
    add $t7, $t7, $t8          # Combined offset
    
    # Draw the pixel with the specified color
    add $t7, $t7, $t1          # Add display base address
    sw $t2, 0($t7)             # Set pixel to specified color
    
draw_array_skip_pixel:
    addi $t4, $t4, 1           # Next column
    j draw_array_col_loop
    
draw_array_next_row:
    addi $t3, $t3, 1           # Next row
    j draw_array_row_loop
    
draw_array_done:
    # Restore registers
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

##############################################################################
# Function: toggle_pause_state
##############################################################################
toggle_pause_state:
    lw $t0, is_paused
    xori $t0, $t0, 1        # Toggle between 0 and 1
    sw $t0, is_paused
    jr $ra

##############################################################################
# Function: update_pause_display: draw or erase the pause indicator 
##############################################################################
update_pause_display:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Setup parameters for text display
    la $a0, PAUSE_ARRAY     # Address of the array
    li $a1, 1               # Start row
    li $a2, 28              # Start column (center screen)
    li $a3, 3               # Width of the array (columns)
    li $t1, 3               # Height of the array (rows)
    
    # Determine color based on pause state
    lw $t0, is_paused
    beqz $t0, pause_erase   # If paused=0 (unpaused), use black
    lw $t2, color_white     # Use white for pause text
    j pause_draw
    
pause_erase:
    lw $t2, color_black     # Use black to erase
    
pause_draw:
    # Push additional parameters on stack (height and color)
    addi $sp, $sp, -8
    sw $t1, 0($sp)          # Height
    sw $t2, 4($sp)          # Color
    
    jal draw_text_array
    
    # Pop the pushed parameters
    addi $sp, $sp, 8
    
    # Restore return address and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
        
##############################################################################
# Function: game_over - Handles game over state
##############################################################################
game_over:
    # Set game over flag
    li $t0, 1
    sw $t0, game_over_flag
    
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal clear_screen	    # Clear the screen
    
    # Draw game over message
    jal draw_game_over
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4

game_over_loop:
    # Check for keyboard input
    lw $t0, ADDR_KBRD         # Load keyboard address
    lw $t1, 0($t0)            # Read first word (1 if key is pressed)
    bne $t1, 1, game_over_loop # If no key is pressed, continue loop
    
    lw $t1, 4($t0)            # Load the actual key pressed
    beq $t1, 0x72, restart_game # 'r' - Restart
    
    j game_over_loop	    # Any other key just continues the loop

restart_game: # initialize new game
    sw $zero, game_over_flag	# Reset game over flag
    jal clear_screen 		#clear screen
    j main

##############################################################################
# Function: draw_game_over - Displays game over message using arrays
##############################################################################
draw_game_over:
    # Save registers
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t9, color_red	    # Load red color for text
    lw $t1, color_green 
    
    # Draw "GAME OVER" array at row 8, column 22
    la $a0, GAME_OVER_ARRAY    # Address of the array
    li $a1, 9                  # Start row
    li $a2, 6                  # Start column
    li $a3, 20                 # Width of the array (columns)
    li $t0, 11                 # Height of the array (rows)
    
    # Push additional parameters on stack (height and color)
    addi $sp, $sp, -8
    sw $t0, 0($sp)             # Height
    sw $t9, 4($sp)             # Color (white)
    
    jal draw_text_array
    
    addi $sp, $sp, 8	    # Pop the pushed parameters
    
    # Draw "PRESS R" array at row 24, column 26
    la $a0, PRESS_R_ARRAY      # Address of the array
    li $a1, 24                 # Start row
    li $a2, 12                 # Start column
    li $a3, 7                  # Width of the array (columns)
    li $t0, 5                  # Height of the array (rows)
    
    # Push additional parameters on stack (height and color)
    addi $sp, $sp, -8
    sw $t0, 0($sp)             # Height
    sw $t1, 4($sp)             # Color (white)
    
    jal draw_text_array
    
    # Pop the pushed parameters
    addi $sp, $sp, 8
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
   
##############################################################################
# Function: clear_screen - Clears the entire display
##############################################################################
clear_screen:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t0, ADDR_DSPL      # Load display base address
    lw $t1, color_black    # Load black color
    
    li $t2, 0              # Start from the first pixel
    li $t3, 4096           # 64x64 pixels = 4096 pixels
    
clear_loop:
    add $t4, $t0, $t2      # Calculate pixel address
    sw $t1, 0($t4)         # Set pixel to black
    
    addi $t2, $t2, 4       # Move to next pixel
    blt $t2, $t3, clear_loop # Continue until all pixels are cleared
    
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
##############################################################################
# Function: draw_box (Medicine Bottle)
##############################################################################
draw_box:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t0, ADDR_DSPL  # Load display base address
    lw $t1, gray_color  # Load gray color
    
    # Draw Top of Medicine Bottle (648-672) using a loop
    li $t2, 648  # Start of top row
    li $t3, 672  # End of top row

top_loop:
    add $t9, $t0, $t2  # Compute address for top row
    sw $t1, 0($t9)     # Store gray pixel in top row
    addi $t2, $t2, 4   # Move right (X+1)
    ble $t2, $t3, top_loop  # Keep looping until end

    # Draw Top of Medicine Bottle (688-712) using a loop
    li $t2, 688  # Start of second top row
    li $t3, 712  # End of second top row

top_loop2:
    add $t9, $t0, $t2  # Compute address for top row
    sw $t1, 0($t9)     # Store gray pixel in top row
    addi $t2, $t2, 4   # Move right (X+1)
    ble $t2, $t3, top_loop2  # Keep looping until end

    # Draw individual pixels for the corners
    sw $t1, 544($t0)
    sw $t1, 416($t0)
    sw $t1, 560($t0)
    sw $t1, 432($t0)

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

    # Drawing Bottom of the Medicine Bottle (Using a Loop)
    li $t6, 3592  # Start of bottom row
    li $t7, 3656  # End of bottom row

bottom_loop:
    add $t9, $t0, $t6  # Compute address for bottom row
    sw $t1, 0($t9)     # Store gray pixel in bottom row
    addi $t6, $t6, 4   # Move right (X+1)
    ble $t6, $t7, bottom_loop  # Keep looping until reaching the end

    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra  # Return
    
