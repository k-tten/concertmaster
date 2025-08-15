#Requires AutoHotkey v2.0
#SingleInstance Force
#Include JXON.ahk

; --- Hotkeys ---
Esc:: ExitApp
global stopPlayback := false
^+s:: stopPlayback := true ; Ctrl+Shift+S to stop playback

; Global array to track key releases
global pendingReleases := []

^+m:: {
    stopPlayback := false

    if !WinExist("ahk_exe GenshinImpact.exe") && !WinExist("Genshin Impact") {
        MsgBox("Could not find Genshin Impact window", "Genshin Impact Concertmaster")
        return
    }

    song := InputBox("Enter song name (without .json):", "Genshin Impact Concertmaster")

    if NOT WinActive("ahk_exe GenshinImpact.exe") {
        ; Activate Genshin Impact
        WinActivate()
        WinSetAlwaysOnTop(1, "ahk_exe GenshinImpact.exe")
        Sleep(100)
        WinSetAlwaysOnTop(0, "ahk_exe GenshinImpact.exe")
        Sleep(1500)
        SendInput("{z}")
        Sleep(1000)
    }

    ; --- Load MIDI JSON ---
    rawText := FileRead("music/" song.Value ".json")
    midiData := Jxon_Load(&rawText)
    notes := midiData.Get("tracks")[1].Get("notes")
    ppq := midiData.Get("header").Get("ppq")
    bpm := midiData.Get("header").Get("tempos")[1].Get("bpm")

    ; Convert to array and filter
    tmp := []
    for _, note in notes
        if note.Get("midi") >= 60
            tmp.Push(note)
    notes := tmp

    ; Sort by ticks
    SortNotesByTicks(notes)

    ; Convert ticks to milliseconds
    tickToMs := (ticks) => (ticks * (60000 / bpm) / ppq)

    startTime := A_TickCount

    ; Start a single timer to handle key releases
    SetTimer(HandlePendingReleases, 10)

    ; --- Play notes ---
    currentTime := 0  ; accumulated time based on actual notes played

    for idx, note in notes {
        if stopPlayback
            break

        noteDelta := tickToMs(note.Get("ticks")) - currentTime  ; time since last note
        if noteDelta > 0
            Sleep(noteDelta)

        now := A_TickCount
        actualDelta := now - startTime - currentTime
        currentTime += actualDelta  ; update accumulated time with actual elapsed

        ; Press key
        noteKey := MapNoteNameToKey(note.Get("name"))
        if noteKey {
            SendInput("{" noteKey " down}")
            releaseTime := Round(tickToMs(note.Get("durationTicks")))
            pendingReleases.Push({ key: noteKey, releaseAt: A_TickCount + releaseTime })
        }

        HandlePendingReleases()
    }

    ; Stop the release timer after playback
    SetTimer(HandlePendingReleases, 0)
}

; --- Timer function to release keys ---
HandlePendingReleases() {
    global pendingReleases
    now := A_TickCount
    for i, release in pendingReleases {
        if now >= release.releaseAt {
            SendInput("{" release.key " up}")
            pendingReleases.RemoveAt(i)
        }
    }
}

; --- Utilities ---
SortNotesByTicks(arr) {
    total := arr.Length
    for i, _ in arr {
        for j, _ in arr {
            if j < total && arr[j].Get("ticks") > arr[j + 1].Get("ticks") {
                tmp := arr[j]
                arr[j] := arr[j + 1]
                arr[j + 1] := tmp
            }
        }
    }
}

MapNoteNameToKey(name) {
    static mapping := Map(
        "C4", "z", "D4", "x", "E4", "c", "F4", "v",
        "G4", "b", "A4", "n", "B4", "m",
        "C5", "a", "D5", "s", "E5", "d", "F5", "f", "G5", "g",
        "A5", "h", "B5", "j",
        "C6", "q", "D6", "w", "E6", "e", "F6", "r", "G6", "t",
        "A6", "y", "B6", "u"
    )
    return mapping.Has(name) ? mapping[name] : ""
}
