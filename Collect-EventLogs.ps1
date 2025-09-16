# CollectEventLogs.ps1
# Exports Application, System, Security, Defender Operational,
# WDAC (CodeIntegrity Operational), and AppLocker (EXE and DLL / MSI and Script) logs.
# Creates a ZIP on the current user's Desktop and removes the temp folder.
# Run as Administrator. Requires PowerShell 5+ for Compress-Archive.

$ErrorActionPreference = 'Stop'

# Verify elevation
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

# Event channels to export (Channel Name -> Output file)
$channels = @(
    @{ Name = "Application";                                        File = "Application.evtx" }
    @{ Name = "System";                                             File = "System.evtx" }
    @{ Name = "Security";                                           File = "Security.evtx" }
    @{ Name = "Microsoft-Windows-Windows Defender/Operational";     File = "Defender_Operational.evtx" }
    @{ Name = "Microsoft-Windows-CodeIntegrity/Operational";        File = "WDAC_CodeIntegrity_Operational.evtx" }
    @{ Name = "Microsoft-Windows-AppLocker/EXE and DLL";            File = "AppLocker_EXE_and_DLL.evtx" }
    @{ Name = "Microsoft-Windows-AppLocker/MSI and Script";         File = "AppLocker_MSI_and_Script.evtx" }
)

# Get the list of existing channels to avoid noisy failures on systems without AppLocker/WDAC channels
$existingChannels = wevtutil el

# Export each channel that exists
foreach ($ch in $channels) {
    $out = Join-Path $logDir $ch.File
    if ($existingChannels -contains $ch.Name) {
        try {
            Write-Host "Exporting: $($ch.Name) -> $out"
            wevtutil epl "$($ch.Name)" "$out"
        }
        catch {
            Write-Warning "Failed to export '$($ch.Name)': $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "Channel not found on this system: '$($ch.Name)'. Skipping."
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
