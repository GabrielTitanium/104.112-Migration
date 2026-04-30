# Description: This script creates an XML file with parameterized values for a web service upload configuration.
# Usage: .\Create-UploadWebServices.ps1 -url "http://example.com" -username "user" -password "pass" -clinic "clinic1" -filepath "C:\Temp"

# Define your parameterized values
param (
    [Parameter(Mandatory = $true)]
    [string]$url,

    [Parameter(Mandatory = $true)]
    [string]$username,

    [Parameter(Mandatory = $true)]
    [string]$password,

    [Parameter(Mandatory = $true)]
    [string]$clinic,

    [Parameter(Mandatory = $true)]
    [string]$filepath
)

# Define the XML template as a here-string
$xmlTemplate = @'
<UploadFiles>
  <WebServices url="[REPLACE WITH URL]" />
  <Authentication username="[REPLACE WITH USER NAME]" password="[REPLACE WITH PASSWORD]" clinic="[REPLACE WITH CLINIC]" />
</UploadFiles>
'@

# Cast the template to an XML object
[xml]$xml = $xmlTemplate

# Update the attribute values using the SetAttribute() method
$xml.UploadFiles.WebServices.SetAttribute("url", $url)
$xml.UploadFiles.Authentication.SetAttribute("username", $username)
$xml.UploadFiles.Authentication.SetAttribute("password", $password)
$xml.UploadFiles.Authentication.SetAttribute("clinic", $clinic)

# Define the output file path
$outputFile = Join-Path -Path $filepath -ChildPath "UploadFiles_WebServices.xml"

# Save the updated XML to a file with error handling
try {
    $xml.Save($outputFile)
    Write-Output "The file '$outputFile' has been created."
} catch {
    Write-Output "Error: Failed to save the file '$outputFile'. Exception: $_"
}