# Authon PowerShell SDK - Example
# Run: .\example.ps1

. "$PSScriptRoot\Authon.ps1"

# ============ SETUP ============
$auth = New-Authon -AppId "your-app-id" -ApiKey "your-api-key"

# ============ CONNECT ============
if (-not (Initialize-Authon $auth)) {
    Write-Host "[-] Failed to connect" -ForegroundColor Red
    exit 1
}
Write-Host "[+] Connected: $($auth.AppName) v$($auth.AppVersion)" -ForegroundColor Green

# ============ AUTHENTICATE ============
Write-Host "`n[1] Login (Username + Password)"
Write-Host "[2] License Key"
$choice = Read-Host "`n>"

if ($choice -eq "1") {
    $username = Read-Host "Username"
    $password = Read-Host "Password"
    $result = Login-Authon $auth -Username $username -Password $password
} else {
    $key = Read-Host "License Key"
    $result = License-Authon $auth -Key $key
}

if (-not $result.success) {
    Write-Host "`n[-] $($result.message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n[+] Authenticated!" -ForegroundColor Green
Write-Host "    Level: $($auth.Level)"
Write-Host "    Subscription: $(if ($auth.Subscription) { $auth.Subscription } else { 'None' })"
Write-Host "    Expires: $(if ($auth.ExpiresAt) { $auth.ExpiresAt } else { 'Lifetime' })"

# ============ FEATURES ============
$msg = Get-AuthonVar $auth -Key "welcome_message"
if ($msg) { Write-Host "`n[*] $msg" -ForegroundColor Cyan }

Send-AuthonLog $auth -Message "PowerShell SDK example executed"

# ============ CLEANUP ============
Write-Host "`n[+] Done. Logging out..." -ForegroundColor Green
Logout-Authon $auth
