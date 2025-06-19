<table>
  <tr>
    <td style="vertical-align: top;">
      <h1>🧬 Dr. Mario – CSC258 Final Project</h1>
      <p><strong>By:</strong> Ahnaf Keenan Ardhito & Ibrahim Bilal</p>
    </td>
    <td align="right">
      <img src="gameplay_images/Screenshot 2025-06-19 183344.png" alt="Gameplay Screenshot 1" width="400"/>
    </td>
  </tr>
</table>

---


## 🧠 Game Summary

This is a clone of the classic **Dr. Mario** game built in MIPS Assembly by Ibrahim and Keenan as part of the CSC258 final project.

- Capsules fall from the top and must be aligned to eliminate viruses by matching colors.
- New levels spawn additional viruses and increase gravity.
- The game ends when capsules block the top of the bottle.

---

## 🎮 Features

### Easy Features Implemented
- ✅ Gravity  
- ✅ Gravity speeding up  
- ✅ Game over and restart  
- ✅ Pause  
- ✅ Sound effects  
- ✅ Ghost capsule  
- ✅ Levels  
- ✅ Draw Dr. Mario and virus indicators on the side  
- ✅ Update virus indicators as viruses are removed  
- ✅ Preview next capsule  

### Hard Features Implemented
- ✅ Dr. Mario Theme Music  


---
## 🎵 Theme Song Integration

We manually transcribed the **Fever Theme** note-by-note using MIPS `.word` instructions.  
Key technical challenges included:

- Manual conversion of pitch, rhythm, volume, and instrument
- Synchronized playback with a tick-based timer system
- Dual-channel music for harmony and bass
- Dynamic note changes with volume/instrument handling

---

## 💻 How to Run (Saturn IDE Setup)

1. **Download Saturn IDE:**
   - Get it from the official [Saturn GitHub](https://github.com/1whatleytay/saturn)

2. **Load the Project:**
   - Open `saturn.html` in your browser
   - Load your `.asm` file via the Saturn IDE UI

3. **Game Configuration:**
   - Unit width: `2 pixels`  
   - Unit height: `2 pixels`  
   - Display resolution: `64 x 64`  
   - Base address: `0x10008000`

4. **Compile & Run:**
   - Assemble the code
   - Hit `Run` to play!


## 👥 Authors
- Ibrahim Bilal  
- Ahnaf Keenan Ardhito
<div align="center">
  <img src="gameplay_images/Screenshot 2025-06-19 183435.png" alt="Gameplay Screenshot 2" width="400"/>
</div>


