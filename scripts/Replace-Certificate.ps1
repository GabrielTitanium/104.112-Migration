param(
    [string]$pfxPath,
    [string]$pfxPassword,
    [string]$siteName = "Default Web Site"
)

# Import IIS Module
Import-Module WebAdministration

$certStorePath = "Cert:\LocalMachine\My"
$bindingPort   = 443
$securePassword = ConvertTo-SecureString -String $pfxPassword -AsPlainText -Force

# -------------------------------------------------------
# Step 1: Remove existing HTTPS binding from IIS
# -------------------------------------------------------
Write-Host "Checking for existing HTTPS binding on '$siteName'..." -ForegroundColor Cyan
$existingBinding = Get-WebBinding -Name $siteName -Protocol "https" -Port $bindingPort -ErrorAction SilentlyContinue

if ($existingBinding) {
    Write-Host "Removing existing HTTPS binding..." -ForegroundColor Yellow
    Remove-WebBinding -Name $siteName -Protocol "https" -Port $bindingPort -ErrorAction SilentlyContinue
    Write-Host "Existing HTTPS binding removed." -ForegroundColor Green
} else {
    Write-Host "No existing HTTPS binding found. Skipping removal." -ForegroundColor Gray
}

# -------------------------------------------------------
# Step 2: Remove expired/old certificates from the store
# -------------------------------------------------------
Write-Host "Scanning for expired or existing wildcard certificates in store..." -ForegroundColor Cyan
$existingCerts = Get-ChildItem -Path $certStorePath | Where-Object {
    $_.Subject -like "*titanium*" -or $_.Subject -like "*titanium.solutions*"
}

if ($existingCerts) {
    foreach ($cert in $existingCerts) {
        Write-Host "Removing certificate: $($cert.Subject) | Thumbprint: $($cert.Thumbprint) | Expiry: $($cert.NotAfter)" -ForegroundColor Yellow
        Remove-Item -Path "$certStorePath\$($cert.Thumbprint)" -Force
        Write-Host "Certificate removed." -ForegroundColor Green
    }
} else {
    Write-Host "No existing matching certificates found in store." -ForegroundColor Gray
}

# -------------------------------------------------------
# Step 3: Import the new PFX certificate
# -------------------------------------------------------
Write-Host "Importing new certificate from: $pfxPath" -ForegroundColor Cyan

if (!(Test-Path $pfxPath)) {
    Write-Host "ERROR: PFX file not found at path: $pfxPath" -ForegroundColor Red
    exit 1
}

$newCert = Import-PfxCertificate -FilePath $pfxPath -Password $securePassword -CertStoreLocation $certStorePath

if (!$newCert) {
    Write-Host "ERROR: Failed to import PFX certificate." -ForegroundColor Red
    exit 1
}

Write-Host "New certificate imported successfully." -ForegroundColor Green
Write-Host "  Subject:    $($newCert.Subject)" -ForegroundColor White
Write-Host "  Thumbprint: $($newCert.Thumbprint)" -ForegroundColor White
Write-Host "  Expiry:     $($newCert.NotAfter)" -ForegroundColor White

# -------------------------------------------------------
# Step 4: Create new HTTPS binding
# -------------------------------------------------------
Write-Host "Adding new HTTPS binding to site '$siteName'..." -ForegroundColor Cyan
New-WebBinding -Name $siteName -Protocol "https" -Port $bindingPort -IPAddress "*" -HostHeader "" -SslFlags 0
Write-Host "HTTPS binding added." -ForegroundColor Green

# -------------------------------------------------------
# Step 5: Assign new certificate to the HTTPS binding
# -------------------------------------------------------
Write-Host "Assigning new certificate to HTTPS binding..." -ForegroundColor Cyan
$binding = Get-WebBinding -Name $siteName -Protocol "https" -Port $bindingPort
$binding.AddSslCertificate($newCert.Thumbprint, "MY")
Write-Host "Certificate successfully bound to site '$siteName'!" -ForegroundColor Green

# -------------------------------------------------------
# Step 6: Restart IIS to apply changes
# -------------------------------------------------------
Write-Host "Restarting IIS..." -ForegroundColor Cyan
Restart-Service -Name W3SVC -Force
Write-Host "IIS restarted successfully." -ForegroundColor Green

Write-Host "-------------------------------------------" -ForegroundColor White
Write-Host "Certificate replacement completed!" -ForegroundColor Green
Write-Host "  Site:       $siteName" -ForegroundColor White
Write-Host "  Thumbprint: $($newCert.Thumbprint)" -ForegroundColor White
Write-Host "  Expiry:     $($newCert.NotAfter)" -ForegroundColor White
Write-Host "-------------------------------------------" -ForegroundColor White