# Description: This script searches for installed applications by name and optionally uninstalls them.

param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter part or all of the application name.")]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, HelpMessage = "Include this switch to uninstall the found application.")]
    [switch]$Uninstall
)

# Define registry paths for both 32-bit and 64-bit installations.
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Search the registry for installed applications matching the name.
$apps = foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Get-ItemProperty -Path $path | Where-Object {
            $_.DisplayName -and $_.DisplayName -ilike "*$ApplicationName*"
        }
    }
}

if (-not $apps) {
    Write-Host "Application '$ApplicationName' not found." -ForegroundColor Yellow
    exit 0
}

foreach ($app in $apps) {
    $productCode = $app.PSChildName
    $displayName = $app.DisplayName
    Write-Host "Found application: $displayName (Product Code: $productCode)" -ForegroundColor Green

    if ($Uninstall) {
        Write-Host "Attempting to uninstall $displayName..." -ForegroundColor Cyan
        # Uninstall the application silently; /qn performs a silent uninstallation with no user interface.
        $process = Start-Process msiexec.exe -ArgumentList "/x $productCode /qn" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "$displayName uninstalled successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Uninstallation of $displayName (Product Code: $productCode) encountered an error. Exit code: $($process.ExitCode)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Uninstallation skipped for $displayName. Use -Uninstall switch to proceed." -ForegroundColor Yellow
    }
}
# End of script