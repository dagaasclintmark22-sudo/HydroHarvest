<#
Automate setup and deployment for Hydro_Harvest on Windows PowerShell.

Usage examples:
.\scripts\automate.ps1 -FunctionSecret "my-secret" -FirebaseProject "my-firebase-project" -DeployFunctions -RunFlutterChecks

Notes:
- This script does not bypass interactive logins. You will be prompted to run `firebase login` when required.
- Installing Node via winget will only be attempted if `winget` is present.
#>

param(
  [string]$FunctionSecret,
  [string]$FirebaseProject,
  [switch]$DeployFunctions,
  [switch]$RunFlutterChecks
)

function Test-Cmd {
  param([string]$Name)
  return (Get-Command $Name -ErrorAction SilentlyContinue) -ne $null
}

Write-Host "=== HydroHarvest automation starting ==="

if (-not (Test-Cmd npm)) {
  Write-Host "npm not found on PATH." -ForegroundColor Yellow
  if (Test-Cmd winget) {
    Write-Host "Attempting to install Node.js LTS via winget... (requires admin)" -ForegroundColor Cyan
    $res = Start-Process -FilePath winget -ArgumentList 'install','--id','OpenJS.NodeJS.LTS','-e' -NoNewWindow -Wait -PassThru
    if ($res.ExitCode -ne 0) {
      Write-Host "winget install failed or aborted." -ForegroundColor Red
      Write-Host "Please install Node.js (LTS) from https://nodejs.org and re-run this script." -ForegroundColor Red
      exit 1
    }
    Write-Host "After installation, please re-open PowerShell and re-run this script." -ForegroundColor Green
    exit 0
  } else {
    Write-Host "Please install Node.js (LTS) from https://nodejs.org and re-run this script." -ForegroundColor Red
    exit 1
  }
}

if (-not (Test-Cmd firebase)) {
  Write-Host "firebase CLI not found. Installing firebase-tools globally via npm..." -ForegroundColor Cyan
  & npm install -g firebase-tools
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install firebase-tools. Please install manually." -ForegroundColor Red
  }
}

# Install function dependencies
$functionsPath = Join-Path $PSScriptRoot '..\functions' | Resolve-Path
Set-Location $functionsPath
Write-Host "Installing Cloud Functions dependencies..."
& npm install
if ($LASTEXITCODE -ne 0) {
  Write-Host "npm install failed. Inspect output above." -ForegroundColor Red
}

if ($FunctionSecret) {
  Write-Host "Setting functions config devices.secret..."
  if ($FirebaseProject) {
    firebase functions:config:set devices.secret="$FunctionSecret" --project $FirebaseProject
  } else {
    firebase functions:config:set devices.secret="$FunctionSecret"
  }
}

if ($DeployFunctions) {
  Write-Host "Deploying Cloud Function ingestSensor..."
  if ($FirebaseProject) {
    firebase deploy --only functions:ingestSensor --project $FirebaseProject
  } else {
    firebase deploy --only functions:ingestSensor
  }
}

Set-Location (Join-Path $PSScriptRoot '..')

if ($RunFlutterChecks) {
  Write-Host "Running Flutter format and dart analyze..."
  if (Test-Cmd flutter) {
    flutter format .
    & dart analyze
    if ($LASTEXITCODE -ne 0) {
      Write-Host "dart analyze found issues." -ForegroundColor Yellow
    }
  } else {
    Write-Host "Flutter not found on PATH. Please ensure Flutter SDK is installed and on PATH to run checks." -ForegroundColor Yellow
  }
}

Write-Host "=== Automation finished (check output above for errors) ==="
