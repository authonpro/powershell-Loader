<#
╔══════════════════════════════════════════════════════════════════════════════╗
║  Authon PowerShell SDK — Software Licensing & Authentication               ║
║  Version: 1.0.0                                                            ║
║  Dependencies: None (Invoke-RestMethod built-in)                           ║
║                                                                            ║
║  Website: https://authon.pro                                               ║
║  Docs:    https://authon.pro/docs                                          ║
║  Discord: https://discord.gg/jMZCTKPsmE                                    ║
║  Status:  https://authon.pro/status                                        ║
║  Health:  https://api.authon.pro/health                                    ║
║  GitHub:  https://github.com/authonpro                                     ║
║                                                                            ║
║  Requirements: PowerShell 5.1+ or PowerShell Core 7+                       ║
║                                                                            ║
║  Usage:                                                                    ║
║    . .\Authon.ps1                                                          ║
║    Initialize-Authon -AppId "app-id" -ApiKey "api-key"                     ║
║    $result = Invoke-AuthonInit                                             ║
║    $login = Invoke-AuthonLogin -Username "user" -Password "pass"           ║
║    if ($login.success) { Write-Host "Welcome $($Script:AuthonUsername)!" } ║
╚══════════════════════════════════════════════════════════════════════════════╝
#>

# ═══════════════════════════════════════════════════════════════════════════════
# MODULE STATE
# ═══════════════════════════════════════════════════════════════════════════════

$Script:AuthonVersion = "1.0.0"
$Script:AuthonApiUrl = "https://api.authon.pro/v1"
$Script:AuthonAppId = $null
$Script:AuthonApiKey = $null
$Script:AuthonTimeout = 15

# Session state
$Script:AuthonSessionToken = $null
$Script:AuthonUsername = $null
$Script:AuthonLevel = 0
$Script:AuthonSubscription = $null
$Script:AuthonExpiresAt = $null

# App info
$Script:AuthonAppName = $null
$Script:AuthonAppVersion = $null
$Script:AuthonHwidLock = $false
$Script:AuthonHashCheck = $false
$Script:AuthonInitialized = $false

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Configures the Authon SDK with your application credentials.
.DESCRIPTION
    Must be called before any other Authon function.
    Sets the Application ID and API Key for all subsequent requests.
.PARAMETER AppId
    Your Application ID from the Authon dashboard.
.PARAMETER ApiKey
    Your API Key from the Authon dashboard.
.PARAMETER ApiUrl
    Custom API URL (default: https://api.authon.pro/v1).
.EXAMPLE
    Initialize-Authon -AppId "your-app-id" -ApiKey "your-api-key"
#>
function Initialize-Authon {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$ApiKey,

        [string]$ApiUrl = "https://api.authon.pro/v1"
    )

    if ([string]::IsNullOrWhiteSpace($AppId)) { throw "AppId is required" }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw "ApiKey is required" }

    $Script:AuthonAppId = $AppId.Trim()
    $Script:AuthonApiKey = $ApiKey.Trim()
    $Script:AuthonApiUrl = $ApiUrl.TrimEnd('/')
}

# ═══════════════════════════════════════════════════════════════════════════════
# HWID GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Generates a hardware ID unique to the current machine.
.DESCRIPTION
    Uses WMI disk serial number + computer name, hashed with MD5.
    Falls back to computer name + username if WMI is unavailable.
.OUTPUTS
    System.String — 32-character lowercase hex MD5 hash.
.EXAMPLE
    $hwid = Get-AuthonHWID
    Write-Host "HWID: $hwid"
#>
function Get-AuthonHWID {
    $raw = ""

    try {
        # Get disk serial via WMI
        $disk = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($disk -and $disk.SerialNumber) {
            $raw = $disk.SerialNumber.Trim()
        }
    }
    catch {
        # WMI not available
    }

    $raw += $env:COMPUTERNAME

    if ([string]::IsNullOrWhiteSpace($raw)) {
        $raw = "$env:COMPUTERNAME$env:USERNAME"
    }

    # Compute MD5
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    $hash = $md5.ComputeHash($bytes)
    $md5.Dispose()

    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ''
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL HTTP
# ═══════════════════════════════════════════════════════════════════════════════

function Invoke-AuthonRequest {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Payload
    )

    if (-not $Script:AuthonAppId) { throw "Call Initialize-Authon first" }

    $Payload["appId"] = $Script:AuthonAppId
    $Payload["apiKey"] = $Script:AuthonApiKey

    $json = $Payload | ConvertTo-Json -Depth 10 -Compress

    try {
        $response = Invoke-RestMethod -Uri $Script:AuthonApiUrl `
            -Method Post `
            -Body $json `
            -ContentType "application/json" `
            -Headers @{ "User-Agent" = "Authon-PowerShell-SDK/$Script:AuthonVersion" } `
            -TimeoutSec $Script:AuthonTimeout `
            -ErrorAction Stop

        return $response
    }
    catch [System.Net.WebException] {
        return @{ success = $false; message = "Connection failed. Check https://authon.pro/status" }
    }
    catch {
        return @{ success = $false; message = "Unexpected error: $($_.Exception.Message)" }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: INIT
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Initializes the Authon API connection.
.DESCRIPTION
    Validates credentials and retrieves app info.
    Must be called after Initialize-Authon and before login/license.
.OUTPUTS
    PSObject with success, message, data properties.
.EXAMPLE
    $result = Invoke-AuthonInit
    if ($result.success) { Write-Host "Connected to $Script:AuthonAppName" }
#>
function Invoke-AuthonInit {
    $result = Invoke-AuthonRequest -Payload @{ type = "init" }

    if ($result.success) {
        $Script:AuthonAppName = $result.data.name
        $Script:AuthonAppVersion = $result.data.version
        $Script:AuthonHwidLock = $result.data.hwidLock
        $Script:AuthonHashCheck = $result.data.hashCheck
        $Script:AuthonInitialized = $true
    }

    return $result
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: AUTHENTICATION
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Authenticates with username and password.
.PARAMETER Username
    User's username.
.PARAMETER Password
    User's password.
.PARAMETER HWID
    Hardware ID (auto-generated if not provided).
.OUTPUTS
    PSObject with success, message, data (sessionToken, username, level, subscription, expiresAt).
.EXAMPLE
    $login = Invoke-AuthonLogin -Username "john" -Password "pass123"
    if ($login.success) { Write-Host "Level: $Script:AuthonLevel" }
#>
function Invoke-AuthonLogin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [string]$HWID
    )

    if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
        return @{ success = $false; message = "Username and password are required" }
    }

    if ([string]::IsNullOrWhiteSpace($HWID)) { $HWID = Get-AuthonHWID }

    $result = Invoke-AuthonRequest -Payload @{
        type     = "login"
        username = $Username
        password = $Password
        hwid     = $HWID
    }

    if ($result.success) {
        $Script:AuthonSessionToken = $result.data.sessionToken
        $Script:AuthonUsername = $result.data.username
        $Script:AuthonLevel = $result.data.level
        $Script:AuthonSubscription = $result.data.subscription
        $Script:AuthonExpiresAt = $result.data.expiresAt
    }

    return $result
}

<#
.SYNOPSIS
    Authenticates using a license key only.
.PARAMETER LicenseKey
    The license key to validate/activate.
.PARAMETER HWID
    Hardware ID (auto-generated if not provided).
.EXAMPLE
    $result = Invoke-AuthonLicense -LicenseKey "XXXXX-XXXXX-XXXXX-XXXXX"
#>
function Invoke-AuthonLicense {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,

        [string]$HWID
    )

    if ([string]::IsNullOrWhiteSpace($LicenseKey)) {
        return @{ success = $false; message = "License key is required" }
    }

    if ([string]::IsNullOrWhiteSpace($HWID)) { $HWID = Get-AuthonHWID }

    $result = Invoke-AuthonRequest -Payload @{
        type       = "license"
        licenseKey = $LicenseKey
        hwid       = $HWID
    }

    if ($result.success) {
        $Script:AuthonSessionToken = $result.data.sessionToken
        $Script:AuthonUsername = $result.data.username
        $Script:AuthonLevel = $result.data.level
        $Script:AuthonSubscription = $result.data.subscription
        $Script:AuthonExpiresAt = $result.data.expiresAt
    }

    return $result
}

<#
.SYNOPSIS
    Registers a new user account with a license key.
.PARAMETER Username
    Desired username.
.PARAMETER Password
    Desired password.
.PARAMETER LicenseKey
    A valid, unused license key.
.PARAMETER HWID
    Hardware ID (auto-generated if not provided).
.EXAMPLE
    $result = Invoke-AuthonRegister -Username "newuser" -Password "pass" -LicenseKey "XXXXX"
#>
function Invoke-AuthonRegister {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,

        [string]$HWID
    )

    if ([string]::IsNullOrWhiteSpace($HWID)) { $HWID = Get-AuthonHWID }

    return Invoke-AuthonRequest -Payload @{
        type       = "register"
        username   = $Username
        password   = $Password
        licenseKey = $LicenseKey
        hwid       = $HWID
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Validates the current session (heartbeat).
.OUTPUTS
    Boolean — True if session is valid.
#>
function Invoke-AuthonCheck {
    if (-not $Script:AuthonSessionToken) { return $false }

    $result = Invoke-AuthonRequest -Payload @{
        type         = "check"
        sessionToken = $Script:AuthonSessionToken
    }

    return [bool]$result.success
}

<#
.SYNOPSIS
    Ends the current session and clears local state.
.OUTPUTS
    Boolean — True if logout was successful.
#>
function Invoke-AuthonLogout {
    if (-not $Script:AuthonSessionToken) { return $false }

    $result = Invoke-AuthonRequest -Payload @{
        type         = "logout"
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) {
        $Script:AuthonSessionToken = $null
        $Script:AuthonUsername = $null
        $Script:AuthonLevel = 0
        $Script:AuthonSubscription = $null
        $Script:AuthonExpiresAt = $null
    }

    return [bool]$result.success
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Gets an application-level variable.
.PARAMETER Key
    Variable name.
.OUTPUTS
    String — Variable value, or $null.
#>
function Get-AuthonVar {
    param([Parameter(Mandatory = $true)] [string]$Key)

    $result = Invoke-AuthonRequest -Payload @{
        type         = "var"
        key          = $Key
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) { return $result.data.value }
    return $null
}

<#
.SYNOPSIS
    Sets a user-level variable.
.PARAMETER Key
    Variable name.
.PARAMETER Value
    Variable value.
.OUTPUTS
    Boolean — True if saved.
#>
function Set-AuthonVar {
    param(
        [Parameter(Mandatory = $true)] [string]$Key,
        [Parameter(Mandatory = $true)] [string]$Value
    )

    $result = Invoke-AuthonRequest -Payload @{
        type         = "setvar"
        key          = $Key
        value        = $Value
        sessionToken = $Script:AuthonSessionToken
    }

    return [bool]$result.success
}

<#
.SYNOPSIS
    Gets a user-level variable.
.PARAMETER Key
    Variable name.
.OUTPUTS
    String — Variable value, or $null.
#>
function Get-AuthonUserVar {
    param([Parameter(Mandatory = $true)] [string]$Key)

    $result = Invoke-AuthonRequest -Payload @{
        type         = "getvar"
        key          = $Key
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) { return $result.data.value }
    return $null
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: FILES
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Lists files available to the authenticated user.
.OUTPUTS
    Array of file objects with id, name, size, minLevel.
#>
function Get-AuthonFiles {
    $result = Invoke-AuthonRequest -Payload @{
        type         = "list_files"
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) { return $result.data }
    return @()
}

<#
.SYNOPSIS
    Downloads a file by its ID.
.PARAMETER FileId
    File ID from Get-AuthonFiles.
.PARAMETER OutputPath
    Path to save the downloaded file.
.OUTPUTS
    Boolean — True if download was successful.
#>
function Save-AuthonFile {
    param(
        [Parameter(Mandatory = $true)] [string]$FileId,
        [Parameter(Mandatory = $true)] [string]$OutputPath
    )

    if (-not $Script:AuthonSessionToken) { return $false }

    $payload = @{
        type         = "file"
        appId        = $Script:AuthonAppId
        apiKey       = $Script:AuthonApiKey
        fileId       = $FileId
        sessionToken = $Script:AuthonSessionToken
    }

    $json = $payload | ConvertTo-Json -Depth 10 -Compress

    try {
        Invoke-RestMethod -Uri $Script:AuthonApiUrl `
            -Method Post `
            -Body $json `
            -ContentType "application/json" `
            -OutFile $OutputPath `
            -ErrorAction Stop

        return $true
    }
    catch {
        # Try GET fallback
        try {
            $url = "$Script:AuthonApiUrl/files/download/$FileId`?token=$Script:AuthonSessionToken"
            Invoke-WebRequest -Uri $url -OutFile $OutputPath -ErrorAction Stop
            return $true
        }
        catch {
            return $false
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: LOGGING & ANALYTICS
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Sends an activity log message to the dashboard.
.PARAMETER Message
    Log message (max 500 chars).
.OUTPUTS
    Boolean — True if logged.
#>
function Send-AuthonLog {
    param([Parameter(Mandatory = $true)] [string]$Message)

    if ($Message.Length -gt 500) { $Message = $Message.Substring(0, 500) }

    $result = Invoke-AuthonRequest -Payload @{
        type         = "log"
        message      = $Message
        sessionToken = $Script:AuthonSessionToken
    }

    return [bool]$result.success
}

<#
.SYNOPSIS
    Gets the list of currently online users.
.OUTPUTS
    PSObject with count and users.
#>
function Get-AuthonOnline {
    $result = Invoke-AuthonRequest -Payload @{
        type         = "fetch_online"
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) { return $result.data }
    return @{ count = 0; users = @() }
}

<#
.SYNOPSIS
    Gets application statistics.
.OUTPUTS
    PSObject with totalUsers, onlineUsers, totalKeys, appVersion.
#>
function Get-AuthonStats {
    $result = Invoke-AuthonRequest -Payload @{
        type         = "fetch_stats"
        sessionToken = $Script:AuthonSessionToken
    }

    if ($result.success) { return $result.data }
    return @{}
}

# ═══════════════════════════════════════════════════════════════════════════════
# API: SECURITY
# ═══════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    Checks if an IP or HWID is blacklisted.
.PARAMETER IP
    IP address to check (optional).
.PARAMETER HWID
    HWID to check (optional).
.OUTPUTS
    PSObject with blacklisted (bool) and reason.
#>
function Test-AuthonBlacklist {
    param(
        [string]$IP,
        [string]$HWID
    )

    $payload = @{ type = "check_blacklist" }
    if (-not [string]::IsNullOrWhiteSpace($IP)) { $payload["ip"] = $IP }
    if (-not [string]::IsNullOrWhiteSpace($HWID)) { $payload["hwid"] = $HWID }

    $result = Invoke-AuthonRequest -Payload $payload

    if ($result.success) { return $result.data }
    return @{ blacklisted = $false; reason = $null }
}

<#
.SYNOPSIS
    Redeems a referral code for bonus subscription days.
.PARAMETER Code
    Referral code.
.OUTPUTS
    PSObject with success, message, data (expiresAt, rewardDays).
#>
function Invoke-AuthonRedeemReferral {
    param([Parameter(Mandatory = $true)] [string]$Code)

    return Invoke-AuthonRequest -Payload @{
        type         = "redeem_referral"
        code         = $Code
        sessionToken = $Script:AuthonSessionToken
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT
# ═══════════════════════════════════════════════════════════════════════════════

# Export all public functions
Export-ModuleMember -Function @(
    'Initialize-Authon',
    'Get-AuthonHWID',
    'Invoke-AuthonInit',
    'Invoke-AuthonLogin',
    'Invoke-AuthonLicense',
    'Invoke-AuthonRegister',
    'Invoke-AuthonCheck',
    'Invoke-AuthonLogout',
    'Get-AuthonVar',
    'Set-AuthonVar',
    'Get-AuthonUserVar',
    'Get-AuthonFiles',
    'Save-AuthonFile',
    'Send-AuthonLog',
    'Get-AuthonOnline',
    'Get-AuthonStats',
    'Test-AuthonBlacklist',
    'Invoke-AuthonRedeemReferral'
) -Variable @(
    'AuthonSessionToken',
    'AuthonUsername',
    'AuthonLevel',
    'AuthonSubscription',
    'AuthonExpiresAt',
    'AuthonAppName',
    'AuthonAppVersion',
    'AuthonInitialized'
)
