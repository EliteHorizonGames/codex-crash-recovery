[CmdletBinding()]
param(
    [string]$ProfileManifestPath,
    [string]$KeyPosition = '3,1'
)

$stopLauncher = Join-Path $PSScriptRoot 'StreamDeck-Stop-CodexAutonomy.vbs'
$resumeLauncher = Join-Path $PSScriptRoot 'StreamDeck-Resume-CodexAutonomy.vbs'
if (-not (Test-Path -LiteralPath $stopLauncher)) {
    throw ('Stream Deck stop launcher was not found: {0}' -f $stopLauncher)
}
if (-not (Test-Path -LiteralPath $resumeLauncher)) {
    throw ('Stream Deck resume launcher was not found: {0}' -f $resumeLauncher)
}

function Get-StreamDeckProfileCandidate {
    param([Parameter(Mandatory)][string]$ManifestPath)

    try {
        $candidateManifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }

    $candidateController = @($candidateManifest.Controllers | Where-Object { $_.Type -eq 'Keypad' } | Select-Object -First 1)
    if ($candidateController.Count -ne 1 -or $null -ne $candidateController[0].Actions.PSObject.Properties[$KeyPosition]) {
        return $null
    }

    [pscustomobject]@{
        Path = (Resolve-Path -LiteralPath $ManifestPath).Path
        Name = if ([string]::IsNullOrWhiteSpace($candidateManifest.Name)) { Split-Path -Leaf (Split-Path -Parent $ManifestPath) } else { $candidateManifest.Name }
    }
}

if ([string]::IsNullOrWhiteSpace($ProfileManifestPath)) {
    $profilesRoot = Join-Path $env:APPDATA 'Elgato\StreamDeck\ProfilesV3'
    if (-not (Test-Path -LiteralPath $profilesRoot -PathType Container)) {
        throw 'No Stream Deck profiles were found. Install and open Stream Deck first, then run this script again.'
    }

    $candidates = @(Get-ChildItem -LiteralPath $profilesRoot -Filter manifest.json -File -Recurse |
        ForEach-Object { Get-StreamDeckProfileCandidate -ManifestPath $_.FullName })
    $candidates = @($candidates | Where-Object { $null -ne $_ })
    if ($candidates.Count -eq 0) {
        throw ('No Stream Deck profile page has a free key at {0}. Supply -ProfileManifestPath and -KeyPosition to choose one manually.' -f $KeyPosition)
    }
    if ($candidates.Count -eq 1) {
        $ProfileManifestPath = $candidates[0].Path
        Write-Output ('Using Stream Deck profile page: {0}' -f $candidates[0].Name)
    } else {
        Write-Output 'Choose the Stream Deck profile page for the PAUSE/RESUME switch:'
        for ($candidateIndex = 0; $candidateIndex -lt $candidates.Count; $candidateIndex++) {
            Write-Output ('[{0}] {1}' -f ($candidateIndex + 1), $candidates[$candidateIndex].Name)
        }
        $selection = Read-Host 'Number'
        $selectionNumber = 0
        if (-not [int]::TryParse($selection, [ref]$selectionNumber) -or $selectionNumber -lt 1 -or $selectionNumber -gt $candidates.Count) {
            throw 'No valid Stream Deck profile page was selected.'
        }
        $ProfileManifestPath = $candidates[$selectionNumber - 1].Path
    }
}

if (-not (Test-Path -LiteralPath $ProfileManifestPath -PathType Leaf)) {
    throw ('Stream Deck profile manifest was not found: {0}' -f $ProfileManifestPath)
}

$manifest = Get-Content -LiteralPath $ProfileManifestPath -Raw | ConvertFrom-Json
$controller = @($manifest.Controllers | Where-Object { $_.Type -eq 'Keypad' } | Select-Object -First 1)
if ($controller.Count -ne 1) {
    throw 'The target profile does not contain exactly one Keypad controller.'
}
if ($null -ne $controller[0].Actions.PSObject.Properties[$KeyPosition]) {
    throw ('The requested Stream Deck key is already occupied: {0}' -f $KeyPosition)
}

$action = [pscustomobject]@{
    ActionID = [guid]::NewGuid().Guid
    LinkedTitle = $true
    Name = 'Multi Action Switch'
    Plugin = [pscustomobject]@{
        Name = 'Multi Action'
        UUID = 'com.elgato.streamdeck.multiactions'
        Version = '1.0'
    }
    Resources = $null
    Settings = [pscustomobject]@{}
    State = 0
    Actions = @(
        [pscustomobject]@{
            Actions = @(
                [pscustomobject]@{
                    ActionID = [guid]::NewGuid().Guid
                    LinkedTitle = $true
                    Name = 'Open'
                    Plugin = [pscustomobject]@{
                        Name = 'Open'
                        UUID = 'com.elgato.streamdeck.system.open'
                        Version = '1.0'
                    }
                    Resources = $null
                    Settings = [pscustomobject]@{ path = $stopLauncher }
                    State = 0
                    States = @([pscustomobject]@{})
                    UUID = 'com.elgato.streamdeck.system.open'
                }
            )
        },
        [pscustomobject]@{
            Actions = @(
                [pscustomobject]@{
                    ActionID = [guid]::NewGuid().Guid
                    LinkedTitle = $true
                    Name = 'Open'
                    Plugin = [pscustomobject]@{
                        Name = 'Open'
                        UUID = 'com.elgato.streamdeck.system.open'
                        Version = '1.0'
                    }
                    Resources = $null
                    Settings = [pscustomobject]@{ path = $resumeLauncher }
                    State = 0
                    States = @([pscustomobject]@{})
                    UUID = 'com.elgato.streamdeck.system.open'
                }
            )
        }
    )
    States = @(
        [pscustomobject]@{
            Title = "PAUSE`nAUTO"
        },
        [pscustomobject]@{
            Title = "RESUME`nAUTO"
        }
    )
    UUID = 'com.elgato.streamdeck.multiactions.routine2'
}

$resolvedManifestPath = (Resolve-Path -LiteralPath $ProfileManifestPath).Path
$backupPath = '{0}.bak-codex-autonomy-{1}' -f $resolvedManifestPath, (Get-Date -Format 'yyyyMMdd-HHmmss')
Copy-Item -LiteralPath $resolvedManifestPath -Destination $backupPath -ErrorAction Stop
$controller[0].Actions | Add-Member -NotePropertyName $KeyPosition -NotePropertyValue $action
$manifest | ConvertTo-Json -Depth 32 -Compress | Set-Content -LiteralPath $resolvedManifestPath -Encoding utf8NoBOM
Write-Output ('Installed PAUSE/RESUME AUTO switch on Stream Deck key {0}. Backup: {1}' -f $KeyPosition, $backupPath)
