$AppPoolName = "TitaniumSolutionsDentalAppPool"
$RecycleTime = "02:00"

# Import IISAdministration module
Import-Module IISAdministration

# Start IIS Server Manager session
$session = Get-IISServerManager

# Check if the Application Pool exists
$appPool = $session.ApplicationPools[$AppPoolName]
if (-not $appPool) {
Write-Host "Application Pool '$AppPoolName' not found!"
exit 1
}

Write-Host "Configuring IIS Application Pool: $AppPoolName"

# Set Start Mode to AlwaysRunning
$appPool.managedPipelineMode = 0  # 0 = Integrated, 1 = Classic
$appPool.AutoStart = $true
# Set StartMode to AlwaysRunning
$appPool.StartMode = [Microsoft.Web.Administration.StartMode]::AlwaysRunning
# Commit the changes
Write-Host "Set Start Mode to AlwaysRunning"

# Set Recycling -> Disable Overlapping Recycle to True
$appPool.Recycling.DisallowOverlappingRotation = $true
Write-Host "Set Recycling: Disable Overlapping Recycle to True"

# Remove Fixed Intervals if it was set before
#$appPool.Recycling.PeriodicRestart = [TimeSpan]::Zero
#Write-Host "Removed Fixed Interval if it was previously set"
$appPool.Recycling.PeriodicRestart.Schedule.Clear()
$appPool.Recycling.PeriodicRestart.Time = [TimeSpan]::Zero
$appPool.Recycling.PeriodicRestart.Requests = 0
$appPool.Recycling.PeriodicRestart.Memory = 0
$appPool.Recycling.PeriodicRestart.PrivateMemory = 0

# Set Recycling Specific Time at 02:00 AM
$schedule = $appPool.Recycling.PeriodicRestart.Schedule
foreach ($item in $schedule) {
# Remove specific schedules, here we're assuming you want to clear all schedules
$item.Delete()  # Delete each scheduled item
}
$schedule.Clear()  # Remove existing schedules
$schedule.Add($RecycleTime)

Write-Host "Set Recycling Specific Time to $RecycleTime AM"

# Commit Changes
$session.CommitChanges()

Write-Host "All settings applied successfully!"