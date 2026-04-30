# Check if the 'w3svc' service exists
$service = Get-Service -Name "w3svc" -ErrorAction SilentlyContinue
if ($service) {
    try {
        Write-Host "Stopping IIS (w3svc)..."
        Stop-Service -Name "w3svc" -Force -ErrorAction Stop
    } catch {
        Write-Host "Error stopping IIS: $_"
        exit 1
    }

    # Wait for IIS to stop completely
    $timeout = 30  # Max wait time in seconds
    $elapsed = 0
    $interval = 2  # Check every 2 seconds

    while (($service = Get-Service -Name "w3svc").Status -eq "Running" -and $elapsed -lt $timeout) {
        Write-Host "Waiting for IIS to stop... ($elapsed seconds elapsed)"
        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }

    # Final verification
    if ((Get-Service -Name "w3svc").Status -eq "Stopped") {
        Write-Host "IIS (w3svc) has stopped successfully."
    } else {
        Write-Host "IIS did not stop within $timeout seconds."
        exit 1
    }
}
else {
    Write-Host "Service 'w3svc' not found. Skipping IIS stop step."
}