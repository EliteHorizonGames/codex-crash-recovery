# Codex Crash Recovery

`Codex Crash Recovery` is a local Windows watchdog for long-running Codex Desktop work. It records the active Codex thread, watches for an unexpected Codex Desktop exit, and reopens the recorded thread after a bounded confirmation window.

It is designed for unattended development runs where losing the desktop app would otherwise leave work stranded. It is deliberately conservative: recovery reopens the app and thread, but it does **not** send a prompt, approve tools, execute commands, or make server changes.

## What It Does

- Stores one explicitly armed run: thread UUID, workspace path, label, and heartbeat.
- Starts after Windows logon and checks the Codex Desktop process once per minute.
- Requires two consecutive missing-process checks before attempting recovery.
- Reopens the saved thread through `codex://threads/<thread-id>`.
- Uses a per-user named mutex so the watcher, heartbeats, and pause/resume actions cannot overwrite state concurrently.
- Uses bounded retry delays: 1, 2, 5, 10, 15, 20, 30, then 30 minutes.
- Writes rotating local watchdog logs and retains an audit trail of recovery attempts.

## What It Does Not Do

- It cannot prove that a running Codex process is healthy or responsive; it detects a missing process, not a frozen UI.
- It does not resume a command-line Codex session or submit a continuation message. You remain in control of any new work.
- It does not start before an interactive Windows logon, and it cannot recover a signed-out or unavailable Codex account.
- `codex://threads/<thread-id>` is a practical desktop deep link, not a documented stability guarantee from OpenAI. Test it after Codex updates.
- `-UseMostRecentSession` is only a fallback. It may select the wrong thread if several tasks have recently been active.

## Requirements

- Windows 10 or 11 with the Codex Desktop app installed and signed in.
- PowerShell and Windows Task Scheduler.
- A user session: the Scheduled Task runs at logon, not as a background service before login.
- Optional but strongly recommended: a Stream Deck pause/resume control. This marks an intentional close before you stop or cancel Codex, preventing unwanted recovery.

The runtime state and logs live under `%USERPROFILE%\.codex\autonomy-watchdog`. They are intentionally ignored by Git.

## Install

Clone this repository, open PowerShell in the clone, then install the files and Scheduled Task:

```powershell
.\Install-CodexCrashRecovery.ps1 -InstallScheduledTask
```

This copies the runtime scripts to `%USERPROFILE%\.codex\autonomy-watchdog` and creates the `Elite Horizon Codex Autonomy Watchdog` task. The task launches invisibly through `wscript.exe`, so the minute health check does not flash a PowerShell window.

## Arm A Run

Use the UUID from the Codex task URL or route:

```powershell
& "$HOME\.codex\autonomy-watchdog\Start-CodexAutonomyRun.ps1" `
  -ThreadId '00000000-0000-0000-0000-000000000000' `
  -WorkspacePath 'C:\Path\To\Workspace' `
  -Label 'Overnight development run'
```

For a fallback only, after checking that Codex has one clearly most-recent task:

```powershell
& "$HOME\.codex\autonomy-watchdog\Start-CodexAutonomyRun.ps1" `
  -UseMostRecentSession `
  -WorkspacePath 'C:\Path\To\Workspace' `
  -Label 'Overnight development run'
```

During a sustained run, refresh the watchdog heartbeat after meaningful work:

```powershell
& "$HOME\.codex\autonomy-watchdog\Heartbeat-CodexAutonomyRun.ps1" `
  -ThreadId '00000000-0000-0000-0000-000000000000'
```

## Intentional Stop And Resume

Before deliberately cancelling or closing Codex, pause recovery:

```powershell
& "$HOME\.codex\autonomy-watchdog\Stop-CodexAutonomyRun.ps1"
```

Re-arm the remembered run later:

```powershell
& "$HOME\.codex\autonomy-watchdog\Resume-CodexAutonomyRun.ps1"
```

## Stream Deck Control

The optional Stream Deck helper installs two actions on an existing profile page: `PAUSE AUTO` and `RESUME AUTO`. They only modify the local recovery marker. They never kill Codex, launch Codex, approve actions, or send prompts.

Give the installer the exact Stream Deck profile-page `manifest.json`; the repository does not know or publish your profile identity:

```powershell
& "$HOME\.codex\autonomy-watchdog\Install-StreamDeckStopButton.ps1" `
  -ProfileManifestPath "$env:APPDATA\Elgato\StreamDeck\ProfilesV3\<profile>\Profiles\<page>\manifest.json" `
  -KeyPosition '3,1'
```

Restart Stream Deck after installation. The button label describes the action it will take; Stream Deck can show a stale visual state after an app restart, so the local watchdog state remains authoritative.

## Inspecting State And Logs

```powershell
& "$HOME\.codex\autonomy-watchdog\Get-CodexAutonomyWatchdogStatus.ps1"
```

Logs are kept in `%USERPROFILE%\.codex\autonomy-watchdog\logs`. They record state transitions, detected process loss, recovery launches, and healthy checks without collecting Codex prompts or project content.

## Validation

Run the included static source check before packaging a change:

```powershell
pwsh -NoProfile -File .\tests\Test-Source.ps1
git diff --check
```

The source test confirms the expected runtime files, blocks hard-coded developer paths, checks the hidden launcher, and verifies that personal runtime state and logs remain ignored.

## Security Notes

The Scheduled Task runs as the signed-in user and requires no administrator privileges after installation. Do not place secrets, session exports, logs, Stream Deck profiles, or active `state.json` files in the repository.

## License

MIT. See [LICENSE](LICENSE).
