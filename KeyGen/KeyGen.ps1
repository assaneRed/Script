$key = New-Object byte[](32)
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$rng.GetBytes($key)
$key | Out-File key.txt

$pwd = Read-Host -AsSecureString "Enter a secret password." | ConvertFrom-SecureString -Key $key
$pwd | Out-file securePass.txt
