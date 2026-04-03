param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RepoOwner = 'RobinWM'
$RepoName = 'ship-cli'
$ReleaseBaseUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download"
$InstallDir = Join-Path $env:USERPROFILE '.ship\bin'
$TargetExe = Join-Path $InstallDir 'ship.exe'
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ship-" + [System.Guid]::NewGuid().ToString('N'))

function Fail([string]$Message) {
  Write-Error $Message
  exit 1
}

if (-not [Environment]::Is64BitOperatingSystem) {
  Fail 'ship does not support 32-bit Windows. Please use a 64-bit version of Windows.'
}

if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
  Fail 'Windows ARM64 is not supported yet.'
}

$assetName = 'ship-windows-x64.exe'
$downloadUrl = "$ReleaseBaseUrl/$assetName"
$tempExe = Join-Path $TempDir $assetName

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

try {
  Write-Output 'Installing ship...'
  Invoke-WebRequest -Uri $downloadUrl -OutFile $tempExe -ErrorAction Stop

  & $tempExe --help *> $null
  if ($LASTEXITCODE -ne 0) {
    Fail "Downloaded binary failed verification: $tempExe"
  }

  Copy-Item -Force $tempExe $TargetExe

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $installDirNormalized = [System.IO.Path]::GetFullPath($InstallDir)
  $pathEntries = @()
  if ($userPath) {
    $pathEntries = $userPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
  }

  $alreadyPresent = $pathEntries | Where-Object {
    try {
      [System.IO.Path]::GetFullPath($_) -eq $installDirNormalized
    } catch {
      $_ -eq $InstallDir
    }
  }

  if (-not $alreadyPresent) {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
      $InstallDir
    } else {
      "$InstallDir;$userPath"
    }
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    Write-Output "⚠️ Added $InstallDir to your user PATH. Restart your terminal to use 'ship'."
  }

  Write-Output "✅ Installed ship to $TargetExe"
  Write-Output "✅ Done! Run 'ship --help' in a new terminal."
}
finally {
  if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
  }
}
