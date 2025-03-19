import numpy as np

# Constants
ROWS = 16   # Number of rows in the bottle
COLS = 8    # Number of columns in the bottle

# Define the grid (0 = empty, 1 = red, 2 = blue, 3 = yellow)
# This represents the 64x64 display but in a smaller logical grid
grid = np.zeros((ROWS, COLS), dtype=int)

def detect_and_remove_matches(grid):
    """
    Detects and removes groups of 4+ connected capsules (horizontally or vertically).
    Applies gravity after removal.
    """
    to_remove = set()  # Store positions of capsules to remove

    # Step 1: Detect horizontal matches
    for r in range(ROWS):
        for c in range(COLS - 3):  # check 4 horizontally
            if grid[r, c] != 0 and grid[r, c] == grid[r, c+1] == grid[r, c+2] == grid[r, c+3]:
                to_remove.update([(r, c), (r, c+1), (r, c+2), (r, c+3)])

    # Step 2: Detect vertical matches
    for c in range(COLS):
        for r in range(ROWS - 3):  # check 4 vertically
            if grid[r, c] != 0 and grid[r, c] == grid[r+1, c] == grid[r+2, c] == grid[r+3, c]:
                to_remove.update([(r, c), (r+1, c), (r+2, c), (r+3, c)])

    # Step 3: Remove marked capsules
    for (r, c) in to_remove:
        grid[r, c] = 0

    # Step 4: Apply gravity (shift capsules down if any is removed..)
    for c in range(COLS):
        # Extract column
        column_values = [grid[r, c] for r in range(ROWS)]
        # Remove zeroes and add them back at the top
        filtered = [value for value in column_values if value != 0]
        new_column = [0] * (ROWS - len(filtered)) + filtered
        # Update the column in grid
        for r in range(ROWS):
            grid[r, c] = new_column[r]

    return len(to_remove) > 0  # Return True if any capsules were removed
