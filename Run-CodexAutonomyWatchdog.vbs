Set shell = CreateObject("WScript.Shell")
root = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.codex\autonomy-watchdog"
command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & root & "\Watch-CodexAutonomy.ps1"""
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
