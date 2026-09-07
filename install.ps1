# Phanor installer — Windows.
#
#   irm https://raw.githubusercontent.com/udhaybegyall/phanor/main/install.ps1 | iex
#
# The same four steps as the shell installer: work out the build, download it,
# check its digest, put it on PATH. And the same promise — it never touches
# your newsroom. Everything Phanor keeps lives under one home folder that the
# binary creates for itself, and upgrading is replacing one file.
#
# Windows-specific things worth knowing:
#
#   * A running `phanor.exe` cannot be overwritten. The installer detects that
#     and stops with the one instruction that fixes it, rather than failing
#     halfway with a locked-file error nobody can act on.
#   * PATH is set for the current user only. This never needs administrator,
#     and an installer that quietly wanted it would be worse than one that
#     says it does not.

$ErrorActionPreference = 'Stop'

$Repo       = if ($env:PHANOR_REPO) { $env:PHANOR_REPO } else { 'udhaybegyall/phanor' }
$Version    = if ($env:PHANOR_VERSION) { $env:PHANOR_VERSION } else { 'latest' }
$InstallDir = if ($env:PHANOR_INSTALL_DIR) { $env:PHANOR_INSTALL_DIR } else { "$env:LOCALAPPDATA\Phanor\bin" }

function Write-Step($label, $value) { Write-Host ("  {0,-9} {1}" -f $label, $value) }
function Write-Title($text) { Write-Host $text -ForegroundColor Cyan }
function Fail($message) { Write-Host "error: $message" -ForegroundColor Red; exit 1 }

# ---- 1. which binary --------------------------------------------------------
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne 'AMD64') {
  Fail "Phanor has no Windows build for $arch yet. Only 64-bit Intel/AMD is published today."
}
$target  = 'phanor-windows-x86_64'
$archive = "$target.zip"
$base = if ($Version -eq 'latest') {
  "https://github.com/$Repo/releases/latest/download"
} else {
  "https://github.com/$Repo/releases/download/v$($Version.TrimStart('v'))"
}

Write-Title 'Installing Phanor'
Write-Step 'build' $target
Write-Step 'from'  $base

# ---- the one failure worth checking before downloading anything -------------
#
# Windows locks a running executable. Discovering that after the download, at
# the moment of the copy, produces an "access denied" that reads as a
# permissions problem and sends people looking for an administrator prompt they
# do not need.
$exe = Join-Path $InstallDir 'phanor.exe'
if (Test-Path $exe) {
  $running = Get-Process -Name 'phanor' -ErrorAction SilentlyContinue |
             Where-Object { $_.Path -eq $exe }
  if ($running) {
    Fail @"
Phanor is running, and Windows will not let an installer replace a running program.

Stop it first:

    Stop-Process -Name phanor

then run this installer again. Your newsroom is not affected by either step.
"@
  }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("phanor-install-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $zip = Join-Path $tmp $archive
  Write-Step 'fetching' $archive
  try {
    Invoke-WebRequest -Uri "$base/$archive" -OutFile $zip -UseBasicParsing
  } catch {
    Fail "could not download $base/$archive`n       If this is a brand-new install, check that a release has been published for Windows."
  }

  # ---- 2. verify ------------------------------------------------------------
  try {
    $sumFile = "$zip.sha256"
    Invoke-WebRequest -Uri "$base/$archive.sha256" -OutFile $sumFile -UseBasicParsing
    $expected = (Get-Content $sumFile -Raw).Split()[0].Trim().ToLower()
    $actual   = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) {
      Fail "checksum mismatch — the download does not match its published digest.`n       expected $expected`n       got      $actual`n       Not installing."
    }
    Write-Step 'checksum' 'ok'
  } catch [System.Net.WebException] {
    Write-Step 'checksum' 'no digest published for this build; skipping'
  }

  # ---- 3. install -----------------------------------------------------------
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  $built = Join-Path $tmp 'phanor.exe'
  if (-not (Test-Path $built)) { Fail 'the archive did not contain phanor.exe' }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Move-Item -Path $built -Destination $exe -Force
  Write-Step 'installed' $exe

  $reported = (& $exe --version) -split ' ' | Select-Object -Last 1
  if ($reported) { Write-Step 'version' $reported }

  # ---- PATH, for this user only ---------------------------------------------
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -notlike "*$InstallDir*") {
    $joined = if ([string]::IsNullOrEmpty($userPath)) { $InstallDir } else { "$userPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable('Path', $joined, 'User')
    # Set in this session too, so the "run this next" below actually works
    # without opening a new terminal.
    $env:Path = "$env:Path;$InstallDir"
    Write-Step 'path' "added $InstallDir for your user"
    $reopen = $true
  }

  Write-Host ''
  Write-Title 'Done. Start your newsroom:'
  Write-Host ''
  Write-Host '    phanor serve'
  Write-Host ''
  Write-Host 'That opens the dashboard and runs the newsroom. Everything Phanor keeps'
  Write-Host 'lives in one folder — run `phanor where` to see exactly where.'
  if ($reopen) {
    Write-Host ''
    Write-Host 'In any terminal you already had open, reopen it first so it picks up the new PATH.' -ForegroundColor Yellow
  }
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
