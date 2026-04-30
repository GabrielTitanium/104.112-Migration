param (
    [string]$buildDirectory = "C:\Build\",
    [string]$installerFile = "Setup_Salud.msi",
    [string]$logFile = "msiexec.log",
    [string]$installDir = "C:\Program Files\Titanium Solutions",
    [string]$features = "SelfCheckInFeature,WebServicesFeature,ConfigureIISFeature,APIServicesFeature,RenderServicesFeature",
    [string]$webSite = "Default Web Site",
    [string]$webDescription = "Default Web Site",
    [string]$webSPort = 80,
    [string]$webSiteIp = "*",
    [string]$dsnMssqlDatabase,
    [string]$dsnMssqlPassword,
    [string]$dsnMssqlServer,
    [string]$dsnMssqlUsername,
    [string]$webServicesPathName = "TITANIUMWSERVER",
    [string]$webApplicationsPathName = "TITANIUMCLIENT",
    [string]$allowMultipleVersions = "No",
    [string]$webAppName = "Salud",
    [string]$webAppPool = "TitaniumSolutionsDentalAppPool",
    [string]$webAppPoolCreate = "true",
    [string]$documentsPath = "%ALLUSERSPROFILE%\Titanium Solutions\Documents",
    [string]$reportingServicesURL = "",
    [string]$reportingServicesContextFolder = "",
    [string]$reportingServicesMenuFolder = "",
    [string]$reportingServicesUserName = "",
    [string]$reportingServicesPassword = ""
)

# Ensure the script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator."
    exit 1
}

# Set execution policy
Set-ExecutionPolicy Unrestricted -Scope Process -Force

# Start Windows Installer service
Write-Host "Starting Windows Installer service..."
Start-Service -Name msiserver -ErrorAction SilentlyContinue

# Verify if the service started
$installerService = Get-Service -Name "msiserver" -ErrorAction SilentlyContinue
if ($installerService.Status -ne 'Running') {
    Write-Host "Failed to start Windows Installer service."
    exit 1
}

# Change to the correct directory
Set-Location -Path $buildDirectory -ErrorAction Stop

# Define installer and log file paths
$installerPath = Join-Path -Path $buildDirectory -ChildPath $installerFile
$logPath = Join-Path -Path $buildDirectory -ChildPath $logFile

# Validate that installer exists
if (-not (Test-Path $installerPath)) {
    Write-Host "Installer file not found: $installerPath"
    exit 1
}

Write-Host "Installer found at: $installerPath"
Write-Host "Database: $dsnMssqlDatabase"
Write-Host "Features: $features"
Write-Host "Installation directory: $installDir"
Write-Host "Log file: $logPath"

# Construct installation command
$arguments = @(
    "/i", "`"$installerPath`"",
    "/l*v", "`"$logPath`"",
    "/qn",  # fully silent mode (no UI, required for pipelines)
    "INSTALLDIR=`"$installDir`"",
    "ADDLOCAL=`"$features`"",
    "WEBSITE=`"$webSite`"",
    "WEBSITE_IP=`"$webSiteIp`"",
    "WEBSITE_PORT=`"$webSPort`"",
    "WEBSITE_DESCRIPTION=`"$webDescription`"",
    "DSN_MSSQL_DATABASE=`"$dsnMssqlDatabase`"",
    "DSN_MSSQL_PASSWORD=`"$dsnMssqlPassword`"",
    "DSN_MSSQL_SERVER=`"$dsnMssqlServer`"",
    "DSN_MSSQL_USERNAME=`"$dsnMssqlUsername`"",
    "WEBSERVICESPATHNAME=`"$webServicesPathName`"",
    "WEBAPPLICATIONSPATHNAME=`"$webApplicationsPathName`"",
    "ALLOWMULTIPLEVERSIONS=`"$allowMultipleVersions`"",
    "WEBAPP_NAME=`"$webAppName`"",
    "WEBSITE_APPPOOL=`"$webAppPool`"",
    "WEBSITE_APPPOOL_CREATE=`"$webAppPoolCreate`"",
    "REPORTING_SERVICES_URL=`"$reportingServicesURL`"",
    "REPORTING_SERVICES_CONTEXT_FOLDER=`"$reportingServicesContextFolder`"",
    "REPORTING_SERVICES_MENU_FOLDER=`"$reportingServicesMenuFolder`"",
    "REPORTING_SERVICES_USER_NAME=`"$reportingServicesUserName`"",
    "REPORTING_SERVICES_PASSWORD=`"$reportingServicesPassword`"",
    "DOCUMENTS_PATH=`"$documentsPath`""
)

# Join argument array for logging
Write-Host "Running command: msiexec.exe $($arguments -join ' ')"

# Try to start the MSI process
try {
    Write-Host "Starting MSI installer..."
    $process = Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop
} catch {
    Write-Host "Failed to start MSI installer: $($_.Exception.Message)"
    exit 1
}

# Validate process creation
if (-not $process) {
    Write-Host "MSI process failed to start (null process object)."
    exit 1
}

# Monitor progress
$timeout = 600
$elapsedTime = 0
$interval = 5

while (-not $process.HasExited -and $elapsedTime -lt $timeout) {
    Start-Sleep -Seconds $interval
    $elapsedTime += $interval
    Write-Host "Waiting for installer to complete... ($elapsedTime seconds elapsed)"
}

# Handle timeout
if (-not $process.HasExited) {
    Write-Host "Installer still running after $timeout seconds. Terminating process..."
    $process.Kill()
    exit 1
}

# Check exit code
if ($process.ExitCode -eq 0) {
    Write-Host "Installer completed successfully."
    Write-Host "Log file available at: $logPath"
} else {
    Write-Host "Installer exited with code $($process.ExitCode)."
    Write-Host "Check log for details: $logPath"
    exit $process.ExitCode
}
