# Test signing certificate for the driver package (build.bat). Creates "CN=SQRL FK Test Driver" in the current
# user's certificate store the first time, saves its public part as <Package>\sqrlfk.cer and prints its thumbprint.
# The certificate is not added to any trusted store. Windows loads a test-signed driver only with test signing on
# (bcdedit /set testsigning on).
param([Parameter(Mandatory = $true)] [string] $Package)
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Security

$subject = 'CN=SQRL FK Test Driver'
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $subject -and $_.HasPrivateKey } |
    Select-Object -First 1
if (-not $cert) {
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject -CertStoreLocation Cert:\CurrentUser\My `
        -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(10)
}
Export-Certificate -Cert $cert -FilePath (Join-Path $Package 'sqrlfk.cer') | Out-Null
$cert.Thumbprint
