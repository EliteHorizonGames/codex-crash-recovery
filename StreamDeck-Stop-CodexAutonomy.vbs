Set shell = CreateObject("WScript.Shell")
root = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.codex\autonomy-watchdog"
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & root & "\Stop-CodexAutonomyRun.ps1"" -Reason ""manual Stream Deck stop"""
shell.Run command, 0, True
