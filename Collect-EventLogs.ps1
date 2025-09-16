# CollectEventLogs.ps1
# Exports Application, System, Security, and Defender Operational logs,
# zips them on the current user's Desktop, and cleans up the temp folder.

# Requires: PowerShell 5+ (for Compress-Archive). Run as Administrator.

$ErrorActionPreference = 'Stop'

# Ensure we're elevated
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

# Paths & names
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$desktop   = [Environment]::GetFolderPath('Desktop')
$logDir    = Join-Path $desktop "EventLogs_$timestamp"
$null = New-Item -ItemType Directory -Path $logDir -Force

# Channels to export (Name -> output file)
$channels = @(
    @{ Name = "Application";                                       File = "Application.evtx" }
    @{ Name = "System";                                            File = "System.evtx" }
    @{ Name = "Security";                                          File = "Security.evtx" }
    @{ Name = "Microsoft-Windows-Windows Defender/Operational";    File = "Defender_Operational.evtx" }
)

# Export each channel
foreach ($ch in $channels) {
    try {
        $out = Join-Path $logDir $ch.File
        Write-Host "Exporting: $($ch.Name) -> $out"
        wevtutil epl "$($ch.Name)" "$out"
    }
    catch {
        Write-Warning "Failed to export '$($ch.Name)': $($_.Exception.Message)"
    }
}

# Zip the exports
$zipPath = Join-Path $desktop "EventLogs_$timestamp.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-Host "Creating ZIP: $zipPath"
Compress-Archive -Path (Join-Path $logDir '*') -DestinationPath $zipPath -Force

# Cleanup temp folder
Write-Host "Cleaning up: $logDir"
Remove-Item $logDir -Recurse -Force

Write-Host "Done. Logs archived to: $zipPath"
