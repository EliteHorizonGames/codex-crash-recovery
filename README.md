# Codex Crash Recovery

`Codex Crash Recovery` is a local Windows watchdog for long-running Codex Desktop work. It records the active Codex thread, watches for an unexpected Codex Desktop exit, and reopens the recorded thread after a bounded confirmation window. It is intended to accompany a persistent Codex `/goal`, rather than replace Codex's own goal-continuation behavior.

It is designed for unattended development runs where losing the desktop app would otherwise leave work stranded. It is deliberately conservative: recovery reopens the app and thread, but it does **not** send a prompt, approve tools, execute commands, or make server changes.

**[Download the latest release](https://github.com/EliteHorizonGames/codex-crash-recovery/releases/latest)** for normal installation. Cloning the repository is only needed for development or contributing changes.

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
- It does not resume a command-line Codex session or submit a continuation message. It relies on the reopened Codex task having an active persistent `/goal` to retain and continue its direction; otherwise you must continue the task yourself.
- It does not start before an interactive Windows logon, and it cannot recover a signed-out or unavailable Codex account.
- `codex://threads/<thread-id>` is a practical desktop deep link, not a documented stability guarantee from OpenAI. Test it after Codex updates.
- `-UseMostRecentSession` is only a fallback. It may select the wrong thread if several tasks have recently been active.

## Requirements

- Windows 10 or 11 with the Codex Desktop app installed and signed in.
- PowerShell and Windows Task Scheduler.
- A user session: the Scheduled Task runs at logon, not as a background service before login.
- An active persistent Codex `/goal` for unattended work. The watchdog restores the task window; `/goal` is the mechanism that preserves the task's autonomous continuation intent.
- Optional but strongly recommended: a Stream Deck pause/resume control. This marks an intentional close before you stop or cancel Codex, preventing unwanted recovery.

The runtime state and logs live under `%USERPROFILE%\.codex\autonomy-watchdog`. They are intentionally ignored by Git.

## Quick Start

Open the Codex task you want to protect, make sure it has its persistent `/goal`, then download and extract the [latest release](https://github.com/EliteHorizonGames/codex-crash-recovery/releases/latest). Open PowerShell in the extracted folder and run one script:

```powershell
.\QuickStart-CodexCrashRecovery.ps1
```

That installs every required file, creates the hidden `Elite Horizon Codex Autonomy Watchdog` Scheduled Task, and arms recovery for the most recent Codex task using the current folder as its workspace. No UUID, task path, or Task Scheduler setup is required.

To install the optional Stream Deck PAUSE/RESUME switch at the same time:

```powershell
.\QuickStart-CodexCrashRecovery.ps1 -InstallStreamDeck
```

When more than one compatible Stream Deck page exists, the installer shows a short numbered list. Choose the page once; it creates a timestamped backup before changing it.

For development, clone the repository instead and run the same installer from the checkout.

## Use With A Persistent `/goal`

Start the Codex task with a persistent `/goal` before arming the watchdog. The goal should state the objective, the unattended/autonomous expectation, and any safe stop conditions. The watchdog is intentionally only the recovery layer: after an unexpected desktop-app exit, it reopens the saved task and lets the task's existing `/goal` govern continuation. It never fabricates a prompt or silently changes the goal.

## Everyday Controls

These are short commands from the installed runtime folder. They do not require a UUID.

```powershell
# Arm or re-arm the most recent Codex task for the current workspace.
& "$HOME\.codex\autonomy-watchdog\Arm-CodexCrashRecovery.ps1"

# Unarm before you intentionally cancel or close Codex.
& "$HOME\.codex\autonomy-watchdog\Unarm-CodexCrashRecovery.ps1"

# Add the optional Stream Deck PAUSE/RESUME switch later.
& "$HOME\.codex\autonomy-watchdog\Install-StreamDeckStopButton.ps1"
```

## Advanced: Manually Arm Or Change A Run (Optional)

**Most users can skip this section.** Once the watchdog has been armed for a persistent `/goal`, it keeps that remembered task across normal restarts. In a normal established workflow, a goal integration can arm it for you. These commands are only for first-time manual setup, deliberately changing the tracked task, or troubleshooting.

The simple manual option is one PowerShell command from the workspace you want to associate with the current Codex task:

```powershell
& "$HOME\.codex\autonomy-watchdog\Start-CodexAutonomyRun.ps1" `
  -UseMostRecentSession `
  -WorkspacePath (Get-Location) `
  -Label 'My Codex goal'
```

For an exact, manually selected task, use the UUID from the Codex task URL or route:

```powershell
& "$HOME\.codex\autonomy-watchdog\Start-CodexAutonomyRun.ps1" `
  -ThreadId '00000000-0000-0000-0000-000000000000' `
  -WorkspacePath 'C:\Path\To\Workspace' `
  -Label 'Overnight development run'
```

`-UseMostRecentSession` is only appropriate when the intended Codex task is unmistakably the latest one. During a sustained run, an integration can refresh the watchdog heartbeat after meaningful work:

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

Normally, simply run the installer without parameters and choose from its numbered page list:

```powershell
& "$HOME\.codex\autonomy-watchdog\Install-StreamDeckStopButton.ps1"
```

It automatically finds compatible local Stream Deck profile pages with a free key at `3,1`. Advanced users may still supply `-ProfileManifestPath` and `-KeyPosition` when they need an exact target. Restart Stream Deck after installation. The button label describes the action it will take; Stream Deck can show a stale visual state after an app restart, so the local watchdog state remains authoritative.

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

## Maintenance And Warranty

This project is provided as-is. Updates may be published occasionally, but there is no promised maintenance schedule, support commitment, compatibility guarantee, or obligation to keep pace with Codex, Windows, or Stream Deck changes.

To the fullest extent permitted by law, the project is provided without warranty of any kind, whether express, implied, or statutory. Review the source, test it in your own environment, and decide whether it is appropriate for your workflow before relying on it for unattended work.

## License

MIT. See [LICENSE](LICENSE).
