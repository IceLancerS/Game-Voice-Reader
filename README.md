# Game Voice Reader

<img width="532" height="598" alt="Screenshot 2026-10-30 222639" src="https://github.com/user-attachments/assets/72a4b3b1-4d96-4917-a3ff-0e4014393e8c" />

[![Watch the video](https://youtube.com)](https://youtu.be/cTRi3w8FAFM)



Select any area of your screen and have it read aloud. It uses Windows OCR to read the text and a text-to-speech voice to speak it. It works in games, launchers and anywhere else text can't be selected or copied.

Written in AutoHotkey v2 with a simple settings window.

## Features

- Drag over text on screen and it is read out loud
- Repeat the last area with one key
- Change speed and volume, choose voices, and assign 9 quick-switch voice slots (Numpad 1-9)
- Choose the OCR language and the hotkeys
- Settings are saved automatically
- Runs in the tray, so the hotkeys keep working when the window is closed

## Requirements

1. **Windows 10 or 11**
2. **[AutoHotkey v2](https://www.autohotkey.com/)**
3. **Natural voices from Windows Narrator.** Install them in
   *Settings → Accessibility → Narrator → Add natural voices*.
4. **[NaturalVoiceSAPIAdapter](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter)** makes those Narrator voices available to SAPI, which is what this script uses. Follow the install steps in its README.
5. A Windows OCR language pack for the language you want to read. English is usually installed already.

Without the adapter the script still works, but it can only use the older classic Windows voices.

## Setup

1. Install the requirements above.
2. Download this repository and keep this layout:
   ```
   Game_Voice_Reader_GUI.ahk
   Lib\OCR.ahk
   ```
3. Double-click `Game_Voice_Reader_GUI.ahk`.

## Default controls

| Action | Key |
|---|---|
| Select an area and read it | Hold **XButton2** (side mouse button) and drag |
| Read the last area again | **XButton1** |
| Change speed | Hold **XButton2** and use the mouse wheel |
| Switch voice slot | **Numpad 1-9** (NumLock on) |
| Next voice | **F10** |
| Back to slot 1 | **Ctrl+F10** |
| Show or hide the window | **F8** |
| Exit | **F9** |

If your mouse has no side buttons, use the **Select Area & Read** button in the window, or pick other keys in the Settings tab.

## Tips

- If words are missed, raise **OCR image scale** in the Settings tab (try 3).
- The text box on the Reader tab shows what OCR saw. If the text is right but the speech isn't, try another voice or a lower speed.
- Settings are stored in `GameVoiceReader.ini` next to the script.

## Credits

- [NaturalVoiceSAPIAdapter](https://github.com/gexgd0419/NaturalVoiceSAPIAdapter) by gexgd0419
- [OCR library for AutoHotkey v2](https://github.com/Descolada/OCR) by Descolada, based on the UWP OCR function by malcev
