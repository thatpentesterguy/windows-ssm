**windowsssm.ps1 — Quick README**

- **File**: `windowsssm.ps1`
- **Purpose**: Download and install Amazon SSM Agent on Windows and attempt hybrid activation.

Placeholders (edit top of script before running):
- `$ActivationCode` = `REPLACE_WITH_ACT_CODE`
- `$ActivationId`   = `REPLACE_WITH_ACT_ID`
- `$Region`         = `REPLACE_WITH_REGION`

Run (Administrator PowerShell):
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\windowsssm.ps1
```

What it does (short):
- Downloads official `AmazonSSMAgentSetup.exe` to `%TEMP%` and installs it silently.
- Verifies the agent binary at `C:\Program Files\Amazon\SSM\amazon-ssm-agent.exe`.
- Attempts registration with `-register -code <code> -id <id> -region <region>` using the agent.
- Restarts/starts the `AmazonSSMAgent` service.

Post-install checks:
- `Get-Service -Name AmazonSSMAgent`
- Check logs under `C:\ProgramData\Amazon\SSM\Logs\`.
- Verify registration in AWS Console → Systems Manager → Managed instances.
