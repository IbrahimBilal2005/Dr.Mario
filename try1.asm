    .data
##############################################################################
# Immutable Data
##############################################################################
ADDR_DSPL:  .word 0x10008000  # Address of the bitmap display
ADDR_KBRD:  .word 0xFFFF0000  # Address of the keyboard

row_width:  .word 256         # 64 pixels * 4 bytes per pixel
gray_color: .word 0x808080     # Gray color

color_red:    .word 0xFF0000  # Red
color_blue:   .word 0x0000FF  # Blue
color_yellow: .word 0xFFFF00  # Yellow

##############################################################################
# Mutable Data
##############################################################################
capsule_x:    .word 552  # X position of the capsule (starting)
capsule_y:    .word 680  # Y position of the **bottom** half
capsule_left:  .word 0  # Stores left half of capsule
capsule_right: .word 0  # Stores right half of capsule
lfsr_seed:     .word 0xACE2  # Initial LFSR seed
fall_delay:    .word 500000  # Delay counter for gravity

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
    jal lfsr_next  
    andi $t1, $v0, 0x0003  
    beq $t1, 3, generate_first_half  

    la $t2, color_red  
    sll $t1, $t1, 2    
    add $t2, $t2, $t1  
    lw $t3, 0($t2)     
    sw $t3, capsule_left  

    # Step 3: Generate second half color
generate_second_half:
    jal lfsr_next
    andi $t1, $v0, 0x0003
    beq $t1, 3, generate_second_half  

    la $t2, color_red
    sll $t1, $t1, 2
    add $t2, $t2, $t1
    lw $t4, 0($t2)    
    sw $t4, capsule_right  

game_loop:
    lw $t0, ADDR_DSPL  # Load display base address

    # Read Key Input
    lw $t9, ADDR_KBRD  # Load keyboard input

    # Move Left (A key: ASCII 0x61)
    li $t2, 0x61
    beq $t9, $t2, move_left

    # Move Right (D key: ASCII 0x64)
    li $t2, 0x64
    beq $t9, $t2, move_right

    # Drop Faster (S key: ASCII 0x73)
    li $t2, 0x73
    beq $t9, $t2, fast_drop

apply_gravity:
    lw $t8, fall_delay  # Load delay counter
    subi $t8, $t8, 1    # Reduce delay
    sw $t8, fall_delay
    bnez $t8, game_loop # If delay isn't zero, wait

    # Reset delay
    li $t8, 500000
    sw $t8, fall_delay  

    # Collision Check (Stop Falling at Bottom)
    lw $t7, capsule_y  
    bge $t7, 3456, game_loop  # If at bottom, stop falling

    addi $t7, $t7, 128  # Move **both halves** down
    sw $t7, capsule_y

    jal draw_capsule  # Redraw the capsule at new position
    j game_loop  # Repeat

# ================================
# Move Capsule Left
# ================================
move_left:
    lw $t7, capsule_x  
    subi $t7, $t7, 4  # x = x - 1
    bge $t7, 0, update_x  # Ensure it doesn’t go out of bounds
    li $t7, 0  # Prevent moving out of bounds
update_x:
    sw $t7, capsule_x
    j game_loop  

# ================================
# Move Capsule Right
# ================================
move_right:
    lw $t7, capsule_x  
    addi $t7, $t7, 4  # x = x + 1
    ble $t7, 252, update_x  # Prevent out-of-bounds movement
    li $t7, 252  
    j game_loop  

# ================================
# Fast Drop
# ================================
fast_drop:
    lw $t7, capsule_y  
    bge $t7, 3456, game_loop  # If at bottom, stop falling
    addi $t7, $t7, 256  # Double speed
    sw $t7, capsule_y
    j game_loop  

##############################################################################
# Function: draw_capsule (Update Position)
##############################################################################
draw_capsule:
    lw $t0, ADDR_DSPL  # Load display base address
    lw $t5, capsule_left  # Load left half color
    lw $t6, capsule_right # Load right half color

    lw $a0, capsule_x  # Load X position
    lw $a1, capsule_y  # Load Y position (bottom half)

    # ===============================
    # 1️⃣ CLEAR PREVIOUS POSITION FIRST (Before Moving)
    # ===============================
    lw $t3, capsule_y  # Load previous bottom Y position
    subi $t4, $t3, 128  # Compute previous top Y position

    # Erase OLD TOP half FIRST (before moving)
    add $t9, $t0, $t4  
    sw $zero, 0($t9)  # Clear previous top half

    # Erase OLD BOTTOM half
    add $t9, $t0, $t3  
    sw $zero, 0($t9)  # Clear previous bottom half

    # ===============================
    # 2️⃣ UPDATE Y POSITION (Move Down)
    # ===============================
    addi $t3, $t3, 128  # Move bottom half **DOWN**
    subi $t4, $t3, 128  # Compute new top half position (1 row above bottom)

    sw $t3, capsule_y  # Update bottom half Y position

    # ===============================
    # 3️⃣ DRAW NEW CAPSULE POSITION (After Moving)
    # ===============================

    # Compute NEW top half position
    add $t7, $t0, $t4  
    sw $t5, 0($t7)  # Draw new top half **after moving down**

    # Compute NEW bottom half position
    add $t8, $t0, $t3  
    sw $t6, 0($t8)  # Draw new bottom half

    jr $ra  # Return


##############################################################################
# Function: lfsr_next (LFSR for Random Numbers)
##############################################################################
lfsr_next:
    lw $s0, lfsr_seed  
    li $t1, 0xB400     
    and $t2, $s0, 1    
    beqz $t2, no_xor   
    xor $s0, $s0, $t1  

no_xor:
    srl $s0, $s0, 1  
    sw $s0, lfsr_seed  
    move $v0, $s0  
    jr $ra  

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

    # Draw sides properly
    li $t2, 648  
    li $t3, 712  
side_loop:
    add $t9, $t0, $t2  # Compute address for left side
    sw $t1, 0($t9)     # Store left wall pixel

    add $s0, $t0, $t3  # Compute address for right side
    sw $t1, 0($s0)     # Store right wall pixel

    addi $t2, $t2, 128  # Move down one row
    addi $t3, $t3, 128  # Move down one row

    blt $t2, 3456, side_loop  # Repeat until bottom is reached

    # Draw Bottom of the Medicine Bottle
    li $t6, 3592  # Start of bottom row
    li $t7, 3656  # End of bottom row

bottom_loop:
    add $t9, $t0, $t6  # Compute address for bottom row
    sw $t1, 0($t9)     # Store bottom wall pixel

    addi $t6, $t6, 4  # Move right (next pixel)

    ble $t6, $t7, bottom_loop  # Repeat until end of row is reached

    jr $ra  # Return
