@{
    RootModule        = 'Authon.ps1'
    ModuleVersion     = '1.0.0'
    GUID              = 'd4e5f6a7-b8c9-0123-def0-123456789abc'
    Author            = 'Authon'
    CompanyName       = 'Authon'
    Copyright         = '(c) 2026 Authon. All rights reserved.'
    Description       = 'Official Authon PowerShell SDK — Software Licensing & Authentication'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'New-Authon',
        'Get-AuthonHWID',
        'Initialize-Authon',
        'Login-Authon',
        'License-Authon',
        'Check-Authon',
        'Get-AuthonVar',
        'Set-AuthonVar',
        'Send-AuthonLog',
        'Logout-Authon'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('authon', 'licensing', 'authentication', 'sdk')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/authonpro/sdk-powershell'
            IconUri    = 'https://authon.pro/logo.png'
        }
    }
}
