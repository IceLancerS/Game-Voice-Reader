#Requires AutoHotkey v2
#SingleInstance Force
#include .\Lib\OCR.ahk
InstallKeybdHook 1, 1
#UseHook 1

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
DllCall("SetThreadDpiAwarenessContext", "ptr", -3)
OCR.PerformanceMode := 1

; =====================================================================
;  Game Voice Reader - GUI edition
;  Settings are saved next to the script in GameVoiceReader.ini
; =====================================================================

global IniFile := A_ScriptDir "\GameVoiceReader.ini"
global Speaker := ComObject("SAPI.SpVoice")
global Voices := []          ; SAPI voice objects
global VoiceNames := []      ; their descriptions
global Slots := Map()        ; slot 1-9 -> index in Voices (0 = empty)
global CurrentIdx := 1
global bX := 0, bY := 0, bW := 0, bH := 0   ; last selected area (for Repeat)
global Picking := false
global HotkeyChoices := ["XButton1", "XButton2", "MButton", "F6", "F7", "F11", "F12"]
global SelectKey := "XButton2", RepeatKey := "XButton1"
global ShownTrayTip := false

; ---------------------------------------------------------------------
;  Load voices + settings
; ---------------------------------------------------------------------
try {
    all := Speaker.GetVoices()
    Loop all.Count {
        v := all.Item(A_Index - 1)
        Voices.Push(v)
        VoiceNames.Push(v.GetDescription())
    }
}
if !Voices.Length {
    MsgBox "No text-to-speech voices were found on this PC.", "Game Voice Reader", 16
    ExitApp
}

SetDefaultSlots()
Loop 9 {   ; override defaults with saved slots
    name := IniRead(IniFile, "Slots", A_Index, "")
    if (name != "" && (i := IndexOf(VoiceNames, name)))
        Slots[A_Index] := i
}

savedRate   := Max(-10, Min(10, Integer(IniRead(IniFile, "General", "Rate", 0))))
savedVolume := Max(0, Min(100, Integer(IniRead(IniFile, "General", "Volume", 100))))
savedScale  := IniRead(IniFile, "General", "Scale", "2")
savedLang   := IniRead(IniFile, "General", "Language", "")
savedVoice  := IniRead(IniFile, "General", "Voice", "")
useNumpad   := Integer(IniRead(IniFile, "General", "Numpad", 1))
alwaysTop   := Integer(IniRead(IniFile, "General", "AlwaysOnTop", 0))
copyClip    := Integer(IniRead(IniFile, "General", "CopyToClipboard", 0))
s := IniRead(IniFile, "Keys", "Select", "XButton2")
r := IniRead(IniFile, "Keys", "Repeat", "XButton1")
if IndexOf(HotkeyChoices, s) && IndexOf(HotkeyChoices, r) && s != r
    SelectKey := s, RepeatKey := r

Speaker.Rate := savedRate
Speaker.Volume := savedVolume

; ---------------------------------------------------------------------
;  Build the window
; ---------------------------------------------------------------------
G := Gui(, "Game Voice Reader")
G.SetFont("s10", "Segoe UI")
G.OnEvent("Close", OnGuiClose)
Tabs := G.Add("Tab3", "w490 h510", ["Reader", "Voice", "Settings"])

; ----- Reader tab -----
Tabs.UseTab(1)
G.Add("Button", "w155 h38 Section", "Select Area && Read").OnEvent("Click", PickFromButton)
G.Add("Button", "x+8 w155 h38", "Repeat Last Area").OnEvent("Click", (*) => RepeatLast())
G.Add("Button", "x+8 w120 h38", "Stop Speaking").OnEvent("Click", (*) => StopSpeaking())
G.Add("Text", "xs y+16", "Text that was read (you can edit it and speak it again):")
TxtBox := G.Add("Edit", "xs w455 r10")
G.Add("Button", "xs w140", "Speak This Text").OnEvent("Click", (*) => Say(TxtBox.Value))
G.Add("Button", "x+8 w90", "Copy").OnEvent("Click", (*) => (A_Clipboard := TxtBox.Value))
G.Add("Button", "x+8 w90", "Clear").OnEvent("Click", (*) => (TxtBox.Value := ""))
G.Add("Button", "x+8 w120", "Read Clipboard").OnEvent("Click", (*) => ReadClipboard())
HintTxt := G.Add("Text", "xs y+16 w455 h60 cGray")
G.Add("Button", "xs y+10 w120 h34", "Quit").OnEvent("Click", (*) => ExitApp())

; ----- Voice tab -----
Tabs.UseTab(2)
G.Add("Text", "Section", "Voice:")
VoiceDDL := G.Add("DropDownList", "xs w360", VoiceNames)
VoiceDDL.OnEvent("Change", (*) => ApplyVoice(VoiceDDL.Value))
G.Add("Button", "x+8 w80", "Test").OnEvent("Click", (*) => Say("This is how I sound when reading your game text."))

G.Add("Text", "xs y+12", "Speed:")
RateSl := G.Add("Slider", "xs w340 Range-10-10 TickInterval5 ToolTip", savedRate)
RateSl.OnEvent("Change", OnRate)
RateLbl := G.Add("Text", "x+10 w60", savedRate)

G.Add("Text", "xs y+8", "Volume:")
VolSl := G.Add("Slider", "xs w340 Range0-100 TickInterval25 ToolTip", savedVolume)
VolSl.OnEvent("Change", OnVolume)
VolLbl := G.Add("Text", "x+10 w60", savedVolume)

G.Add("Text", "xs y+14", "Quick voice slots (pick a row, choose a voice above, then assign):")
SlotLV := G.Add("ListView", "xs w455 r9 -Multi NoSortHdr", ["Slot", "Voice"])
G.Add("Button", "xs w270", "Assign voice above to selected slot").OnEvent("Click", AssignSlot)
cbNum := G.Add("Checkbox", "x+10 yp+5 Checked" useNumpad, "Numpad 1-9 (NumLock on)")
cbNum.OnEvent("Click", OnSettingChange)

; ----- Settings tab -----
Tabs.UseTab(3)
langs := ["Auto (Windows default)"]
try {
    for l in StrSplit(Trim(OCR.GetAvailableLanguages(), "`n"), "`n")
        if l != ""
            langs.Push(l)
}
G.Add("Text", "Section", "OCR language:")
LangDDL := G.Add("DropDownList", "xs w300 Choose1", langs)
if (i := IndexOf(langs, savedLang))
    LangDDL.Choose(i)
LangDDL.OnEvent("Change", OnSettingChange)

G.Add("Text", "xs y+12", "OCR image scale (higher = better for small text, but slower):")
ScaleDDL := G.Add("DropDownList", "xs w80", ["1", "2", "3", "4"])
ScaleDDL.Choose(IndexOf(["1", "2", "3", "4"], savedScale) || 2)
ScaleDDL.OnEvent("Change", OnSettingChange)

G.Add("Text", "xs y+12", "Select area (hold and drag):")
SelDDL := G.Add("DropDownList", "xs w150", HotkeyChoices)
SelDDL.Choose(SelectKey)
SelDDL.OnEvent("Change", OnSettingChange)
G.Add("Text", "x+20 yp-22", "Repeat last area:")
RepDDL := G.Add("DropDownList", "xp y+4 w150", HotkeyChoices)
RepDDL.Choose(RepeatKey)
RepDDL.OnEvent("Change", OnSettingChange)

cbTop := G.Add("Checkbox", "xs y+16 Checked" alwaysTop, "Keep this window on top")
cbTop.OnEvent("Click", OnSettingChange)
cbClip := G.Add("Checkbox", "xs Checked" copyClip, "Copy recognised text to the clipboard")
cbClip.OnEvent("Click", OnSettingChange)

G.Add("Text", "xs y+16 w455 cGray",
    "Fixed hotkeys:`n"
    "F8 show / hide this window    F9 exit`n"
    "F10 next voice    Ctrl+F10 back to slot 1`n"
    "Hold the select key + mouse wheel = change speed")

Tabs.UseTab()
SB := G.Add("StatusBar", , "Ready")

; ---------------------------------------------------------------------
;  Start up
; ---------------------------------------------------------------------
RefreshSlots()
startIdx := IndexOf(VoiceNames, savedVoice) || Slots[1] || 1
ApplyVoice(startIdx, false)
BindHotkeys(SelectKey, RepeatKey)
UpdateHint()
G.Opt((alwaysTop ? "+" : "-") "AlwaysOnTop")

; Fixed hotkey: wheel changes speed while the select key is held
HotIf((*) => GetKeyState(SelectKey, "P"))
Hotkey "~WheelUp", (*) => AdjustRate(1)
Hotkey "~WheelDown", (*) => AdjustRate(-1)

; Numpad slots
HotIf((*) => cbNum.Value && GetKeyState("NumLock", "T"))
Loop 9
    Hotkey "~Numpad" A_Index, (hk) => SetSlot(Integer(SubStr(hk, -1)))
HotIf()

A_TrayMenu.Add()
A_TrayMenu.Add("Show / hide window", (*) => ToggleGui())
A_TrayMenu.Default := "Show / hide window"
OnExit((*) => (SaveSettings(), 0))

G.Show("w515")
return

; =====================================================================
;  Hotkeys
; =====================================================================
F8:: ToggleGui()
F9:: ExitApp
^F10:: SetSlot(1)
F10:: {
    global CurrentIdx
    ApplyVoice(CurrentIdx >= Voices.Length ? 1 : CurrentIdx + 1)
}

#HotIf Picking
*LButton:: return        ; swallow the click while picking an area from the GUI
#HotIf

; =====================================================================
;  Hotkey binding (dynamic, so the user can change the keys)
; =====================================================================
BindHotkeys(sel, rep) {
    static prev := []
    for hk in prev
        try Hotkey(hk, "Off")
    prev := [sel, "~" rep]
    HotIf()   ; make sure these are global hotkeys
    Hotkey sel, SelectHandler, "On"
    Hotkey "~" rep, (*) => RepeatLast(), "On"
}

SelectHandler(hk) {
    DragAndRead(RegExReplace(hk, "^[~*$!+^#<>]+"))
}

; =====================================================================
;  Selecting + reading
; =====================================================================
DragAndRead(key) {
    global bX, bY, bW, bH
    MouseGetPos(&sx, &sy)
    cx := sx, cy := sy
    while GetKeyState(key, "P") {
        MouseGetPos(&cx, &cy)
        Highlight(sx, sy, cx - sx, cy - sy)
        Sleep 10
    }
    Highlight()
    if (Abs(cx - sx) > 5 && Abs(cy - sy) > 5) {
        bX := sx, bY := sy, bW := cx - sx, bH := cy - sy
        ReadRegion(bX, bY, bW, bH)
    }
}

PickFromButton(*) {
    global Picking
    G.Hide()
    Picking := true
    ToolTip "Click and drag over the text to read. Esc cancels."
    cancelled := false
    while !GetKeyState("LButton", "P") {
        if GetKeyState("Escape", "P") {
            cancelled := true
            break
        }
        Sleep 15
    }
    ToolTip
    if !cancelled
        DragAndRead("LButton")
    Picking := false
    G.Show()
}

RepeatLast() {
    if (bW = 0 || bH = 0) {
        SetStatus("Nothing to repeat yet - select an area first.")
        return
    }
    rx := (bW > 0) ? bX : bX + bW
    ry := (bH > 0) ? bY : bY + bH
    Highlight(rx, ry, Abs(bW), Abs(bH))
    ReadRegion(bX, bY, bW, bH)
    SetTimer(Highlight, -300)
}

ReadRegion(x, y, w, h) {
    rx := (w > 0) ? x : x + w
    ry := (h > 0) ? y : y + h
    try {
        text := Trim(OCR.FromRect(rx, ry, Abs(w), Abs(h), LangValue(), Integer(ScaleDDL.Text)).Text)
    } catch as e {
        SetStatus("OCR error: " e.Message)
        return
    }
    if (StrLen(text) = 0) {
        SetStatus("No text found in that area.")
        return
    }
    TxtBox.Value := RegExReplace(text, "\R", "`r`n")
    if cbClip.Value
        A_Clipboard := text
    SetStatus("Read " StrLen(text) " characters.")
    Say(text)
}

ReadClipboard() {
    if (A_Clipboard = "") {
        SetStatus("Clipboard is empty.")
        return
    }
    TxtBox.Value := A_Clipboard
    Say(A_Clipboard)
}

LangValue() => (LangDDL.Value <= 1) ? "FirstFromAvailableLanguages" : LangDDL.Text

; =====================================================================
;  Speech
; =====================================================================
Say(text) {
    if (Trim(text) = "")
        return
    Speaker.Speak("", 1 + 2)      ; stop whatever is being said
    Speaker.Speak(text, 1)        ; speak asynchronously
}

StopSpeaking() {
    Speaker.Speak("", 1 + 2)
}

ApplyVoice(idx, announce := true) {
    global CurrentIdx
    if (idx < 1 || idx > Voices.Length)
        return
    try {
        Speaker.Voice := Voices[idx]
        CurrentIdx := idx
        VoiceDDL.Choose(idx)
        if announce
            Say(ShortName(VoiceNames[idx]))
    }
}

SetSlot(n) {
    if (Slots.Has(n) && Slots[n])
        ApplyVoice(Slots[n])
    else {
        ToolTip "Slot " n " is empty"
        SetTimer(() => ToolTip(), -1000)
    }
}

AdjustRate(delta) {
    rate := Max(-10, Min(10, Speaker.Rate + delta))
    Speaker.Rate := rate
    RateSl.Value := rate
    RateLbl.Text := rate
    ToolTip "Speed: " rate
    SetTimer(() => ToolTip(), -1000)
}

OnRate(*) {
    Speaker.Rate := RateSl.Value
    RateLbl.Text := RateSl.Value
}

OnVolume(*) {
    Speaker.Volume := VolSl.Value
    VolLbl.Text := VolSl.Value
}

ShortName(desc) {
    return RegExMatch(desc, "(?:Microsoft )?(\w+)", &m) ? m[1] : desc
}

; =====================================================================
;  Voice slots
; =====================================================================
SetDefaultSlots() {
    global Slots
    fav := ["Sonia (Natural)", "Ava Online (Natural)", "Emma Online (Natural)",
            "Aria Online (Natural)", "Ana Online (Natural)", "Jenny Online (Natural)",
            "Andrew Online (Natural)", "Eric Online (Natural)", "Guy Online (Natural)"]
    used := Map()
    for n, name in fav {
        Slots[n] := 0
        for j, d in VoiceNames {
            if (InStr(d, name) && !used.Has(j)) {
                Slots[n] := j
                used[j] := true
                break
            }
        }
    }
    next := 1
    Loop 9 {
        if Slots[A_Index]
            continue
        while (next <= Voices.Length && used.Has(next))
            next++
        if (next <= Voices.Length) {
            Slots[A_Index] := next
            used[next] := true
        }
    }
}

RefreshSlots() {
    SlotLV.Delete()
    Loop 9
        SlotLV.Add(, A_Index, Slots[A_Index] ? VoiceNames[Slots[A_Index]] : "(empty)")
    SlotLV.ModifyCol(1, 50)
    SlotLV.ModifyCol(2, 380)
}

AssignSlot(*) {
    row := SlotLV.GetNext()
    if !row {
        SetStatus("Select a slot in the list first.")
        return
    }
    Slots[row] := VoiceDDL.Value
    RefreshSlots()
    SlotLV.Modify(row, "Select Focus")
    SaveSettings()
    SetStatus("Slot " row " = " ShortName(VoiceNames[Slots[row]]))
}

; =====================================================================
;  Settings
; =====================================================================
OnSettingChange(*) {
    global SelectKey, RepeatKey
    newSel := SelDDL.Text, newRep := RepDDL.Text
    if (newSel = newRep) {
        SelDDL.Choose(SelectKey)
        RepDDL.Choose(RepeatKey)
        MsgBox "The select key and the repeat key must be different.", "Game Voice Reader", 48
        return
    }
    if (newSel != SelectKey || newRep != RepeatKey) {
        SelectKey := newSel, RepeatKey := newRep
        BindHotkeys(SelectKey, RepeatKey)
        UpdateHint()
    }
    G.Opt((cbTop.Value ? "+" : "-") "AlwaysOnTop")
    SaveSettings()
}

SaveSettings() {
    IniWrite VoiceNames[CurrentIdx], IniFile, "General", "Voice"
    IniWrite Speaker.Rate, IniFile, "General", "Rate"
    IniWrite Speaker.Volume, IniFile, "General", "Volume"
    IniWrite ScaleDDL.Text, IniFile, "General", "Scale"
    IniWrite(LangDDL.Value <= 1 ? "" : LangDDL.Text, IniFile, "General", "Language")
    IniWrite cbNum.Value, IniFile, "General", "Numpad"
    IniWrite cbTop.Value, IniFile, "General", "AlwaysOnTop"
    IniWrite cbClip.Value, IniFile, "General", "CopyToClipboard"
    IniWrite SelectKey, IniFile, "Keys", "Select"
    IniWrite RepeatKey, IniFile, "Keys", "Repeat"
    Loop 9
        IniWrite(Slots[A_Index] ? VoiceNames[Slots[A_Index]] : "", IniFile, "Slots", A_Index)
}

UpdateHint() {
    HintTxt.Text := "Hold " SelectKey " and drag over text to read it.`n"
        . "Press " RepeatKey " to read the last area again.`n"
        . "Hold " SelectKey " and scroll the mouse wheel to change speed."
}

SetStatus(msg) => SB.SetText(msg)

; =====================================================================
;  Window helpers
; =====================================================================
ToggleGui() {
    if WinActive("ahk_id " G.Hwnd)
        G.Hide()
    else
        G.Show()
}

OnGuiClose(*) {
    global ShownTrayTip
    G.Hide()
    SaveSettings()
    if !ShownTrayTip {
        ShownTrayTip := true
        TrayTip "Still running in the tray. F8 reopens the window, F9 exits.", "Game Voice Reader"
    }
    return true
}

IndexOf(arr, val) {
    for i, v in arr
        if (v = val)
            return i
    return 0
}

; =====================================================================
;  Red selection rectangle (unchanged from the original script)
; =====================================================================
Highlight(x?, y?, w?, h?, color := "Red", d := 2) {
    static guis := []
    if !IsSet(x) {
        for g in guis
            g.Destroy()
        guis := []
        return
    }
    if !guis.Length {
        Loop 4
            guis.Push(Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"))
    }
    nx := (w < 0) ? x + w : x, ny := (h < 0) ? y + h : y
    nw := Abs(w), nh := Abs(h)
    Loop 4 {
        i := A_Index, x1 := (i = 2 ? nx + nw : nx - d), y1 := (i = 3 ? ny + nh : ny - d)
        w1 := (i = 1 or i = 3 ? nw + 2 * d : d), h1 := (i = 2 or i = 4 ? nh + 2 * d : d)
        guis[i].BackColor := color
        guis[i].Show("NA x" . x1 . " y" . y1 . " w" . w1 . " h" . h1)
    }
}
