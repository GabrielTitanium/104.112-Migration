# Description: This script is used to run the UploadZipFile.ps1 script
# Usage: .\Run-UploadPackages.ps1

function global:Read-Host { return "" }

. "$PSScriptRoot\UploadZipFile.ps1"