<#
  Safe SSM Agent install + Hybrid Activation (Windows)
  - Uses official AWS public download path
  - Sets TLS12, does basic connectivity checks
  - Installs the agent silently and attempts hybrid activation
  - For authorized test environments only
#>

# ---------- CONFIG ----------
# NOTE: Hardcoded secrets removed. Replace the placeholders below
# with your activation values before running the script.
$ActivationCode = "REPLACE_WITH_ACT_CODE"
$ActivationId   = "REPLACE_WITH_ACT_ID"
$Region         = "REPLACE_WITH_REGION"               # only used for registration
$DownloadUrl    = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
$InstallerPath  = Join-Path $env:TEMP "AmazonSSMAgentSetup.exe"
# -----------------------------

Write-Host "=== SSM Agent Install + Hybrid Activation (safe test) ===" -ForegroundColor Cyan

# Ensure running as Administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERROR] This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

# Use TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Basic connectivity check (to AWS S3 public download)
Write-Host "[1/6] Checking download endpoint connectivity..." -ForegroundColor Cyan
try {
    $resp = Invoke-WebRequest -Uri $DownloadUrl -Method Head -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Write-Host "[OK] Download endpoint reachable (HTTP $($resp.StatusCode))." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Cannot reach download URL. Server returned:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Download installer
Write-Host "[2/6] Downloading official SSM installer to $InstallerPath ..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing -ErrorAction Stop
    Write-Host "[OK] Download complete." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Download failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if (Test-Path $InstallerPath) { Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue }
    exit 1
}

# Install silently
Write-Host "[3/6] Installing SSM Agent (silent) ..." -ForegroundColor Cyan
try {
    $proc = Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -PassThru -ErrorAction Stop
    if ($proc.ExitCode -ne 0) {
        Write-Host "[WARNING] Installer returned exit code $($proc.ExitCode) — check installer logs if present." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Installer completed (exit code 0)." -ForegroundColor Green
    }
}
catch {
    Write-Host "[ERROR] Installation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Verify agent binary path
$agentPath = "C:\Program Files\Amazon\SSM\amazon-ssm-agent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Host "[ERROR] Agent binary not found at expected path: $agentPath" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[4/6] Agent binary exists: $agentPath" -ForegroundColor Green
}

# Attempt hybrid activation (register)
Write-Host "[5/6] Attempting hybrid activation (register) ..." -ForegroundColor Cyan
try {
    & $agentPath -register -code $ActivationCode -id $ActivationId -region $Region 2>&1 | ForEach-Object { Write-Host $_ }
    Write-Host "[INFO] Registration command executed. Check AWS Console for managed instance entry." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Registration failed (see message):" -ForegroundColor Red
    Write-Host $_.Exception.Message
    # Do not exit immediately — attempt to start service so logs are available
}

# Start / Restart the service
Write-Host "[6/6] Ensuring AmazonSSMAgent service is running ..." -ForegroundColor Cyan
try {
    if (Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue) {
        Restart-Service -Name "AmazonSSMAgent" -ErrorAction Stop
    } else {
        Start-Service -Name "AmazonSSMAgent" -ErrorAction Stop
    }
    Write-Host "[OK] AmazonSSMAgent is running." -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Could not start/restart service:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

Write-Host "=== Done. Verify in AWS Console: Systems Manager → Managed Instances ===" -ForegroundColor Cyan