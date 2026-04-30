param (
    [string]$exePath = "C:\Program Files\Titanium Solutions\Dental Web Services\bin\Titanium.Migration.DataAccess.Migration.exe",
    [string]$server ,
    [string]$database,
    [string]$user,
    [string]$password,
    [string]$logFile = "C:\Build\DataMigrationLog.txt"
)

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator."
    exit 1
}

# Ensure the EXE exists
if (-not (Test-Path -Path $exePath)) {
    Write-Host "Error: Migration executable not found at $exePath"
    exit 1
}

# Construct argument list with properly formatted parameters
$migrationArgs = @(
    "-server=`"$server`"",
    "-database=`"$database`"",
    "-user=`"$user`"",
    "-password=`"$password`"",
    "-autorun",
    "-audittables"
)

# Log execution
Write-Host "Running data migration: $exePath with arguments: $migrationArgs"

# Define separate log files for standard output and error
$stdOutFile = "C:\Build\DataMigrationLog_out.txt"
$stdErrFile = "C:\Build\DataMigrationLog_err.txt"

try {
    # Run the process and capture output in separate files
    $process = Start-Process -FilePath $exePath `
                             -ArgumentList $migrationArgs `
                             -NoNewWindow `
                             -Wait `
                             -PassThru `
                             -RedirectStandardOutput $stdOutFile `
                             -RedirectStandardError $stdErrFile

    $exitCode = $process.ExitCode

    # Optionally, merge the two logs into a single file if needed
    Get-Content $stdOutFile, $stdErrFile | Set-Content $logFile

    if ($exitCode -ne 0) {
        Write-Host "Migration process failed with exit code: $exitCode"
        Get-Content $logFile -Tail 10 | ForEach-Object { Write-Host $_ }
        exit $exitCode
    } else {
        Write-Host "Data migration completed successfully."
    
        # Show log output in Azure Pipelines console
        Write-Host "===== Begin Migration Output ====="
        Get-Content $logFile | ForEach-Object { Write-Host $_ }
        Write-Host "===== End Migration Output ====="
    }
} catch {
    Write-Host "Error while running migration process: $_"
    exit 1
}