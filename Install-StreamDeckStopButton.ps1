[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ProfileManifestPath,
    [string]$KeyPosition = '3,1'
)

$stopLauncher = Join-Path $PSScriptRoot 'StreamDeck-Stop-CodexAutonomy.vbs'
$resumeLauncher = Join-Path $PSScriptRoot 'StreamDeck-Resume-CodexAutonomy.vbs'
if (-not (Test-Path -LiteralPath $ProfileManifestPath)) {
    throw ('Stream Deck profile manifest was not found: {0}' -f $ProfileManifestPath)
}
if (-not (Test-Path -LiteralPath $stopLauncher)) {
    throw ('Stream Deck stop launcher was not found: {0}' -f $stopLauncher)
}
if (-not (Test-Path -LiteralPath $resumeLauncher)) {
    throw ('Stream Deck resume launcher was not found: {0}' -f $resumeLauncher)
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
