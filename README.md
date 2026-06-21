# Authon PowerShell SDK

<p align="center">
  <img src="https://authon.pro/logo.png" alt="Authon" width="80" />
  <br/>
  <strong>Official PowerShell SDK for Authon — Software Licensing & Authentication Platform</strong>
</p>

<p align="center">
  <a href="https://authon.pro">Website</a> •
  <a href="https://authon.pro/docs">Docs</a> •
  <a href="https://discord.gg/MTY79JDFm6">Discord</a> •
  <a href="https://authon.pro/status">Status</a>
</p>

---

## Requirements

- PowerShell 5.1+ or PowerShell 7+
- No modules required

## Quick Start

```powershell
. .\Authon.ps1

$auth = New-Authon -AppId "your-app-id" -ApiKey "your-api-key"
Initialize-Authon $auth

$result = Login-Authon $auth -Username "user" -Password "pass"
if ($result.success) { Write-Host "Level: $($auth.Level)" }

Logout-Authon $auth
```

## Run Example

```powershell
.\example.ps1
```

## Links

- 🌐 Website: https://authon.pro
- 📖 Docs: https://authon.pro/docs
- 💬 Discord: https://discord.gg/MTY79JDFm6
- 📊 Status: https://authon.pro/status
- 🔗 API Health: https://api.authon.pro/health

## License

MIT
