param (
    [string]$sourcePath = "$(Pipeline.Workspace)\SaludServicesTrunk\drop\",
    [string]$destinationPath = "C:\Build\",
    [string]$itemsToMove = "Setup_Salud.msi,CustomerPackages.zip"
)

# Convert comma-separated items into an array
$itemsArray = $itemsToMove -split ','

# Remove existing directory if it exists
if (Test-Path $destinationPath) {
    Remove-Item $destinationPath -Recurse -Force
}

# Create new directory if it doesn't exist
if (-Not (Test-Path -Path $destinationPath)) {
    Write-Host "Creating Build directory..."
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
} else {
    Write-Host "Build directory already exists."
}

# Copy each item
foreach ($item in $itemsArray) {
    $fullPath = Join-Path -Path $sourcePath -ChildPath $item.Trim()
    
    if (Test-Path $fullPath) {
        Copy-Item -Path $fullPath -Destination $destinationPath -Recurse -Force
        Write-Host "Copied: $item"
    } else {
        Write-Host "Item $item not found in $sourcePath"
        exit 1
    }
}

Write-Host "All specified items have been copied."