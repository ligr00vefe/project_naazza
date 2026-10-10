param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('prepare', 'run', 'build-apk', 'sync-secrets')]
  [string]$Action,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'

if (-not (Test-Path -LiteralPath $envPath)) {
  throw "Missing $envPath. Copy .env.example to .env and fill in the values."
}

$settings = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
  $trimmed = $line.Trim()
  if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
  $separator = $line.IndexOf('=')
  if ($separator -lt 1) { continue }
  $name = $line.Substring(0, $separator).Trim()
  $value = $line.Substring($separator + 1).Trim()
  $settings[$name] = $value
}

function Require-Setting([string]$Name) {
  if (-not $settings.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($settings[$Name]) -or $settings[$Name].StartsWith('YOUR_')) {
    throw "Missing $Name in $envPath"
  }
}

if ($Action -eq 'sync-secrets') {
  Require-Setting 'GEMINI_API_KEY'
  Require-Setting 'GEMINI_MODEL'
  $temporarySecretFile = Join-Path $env:TEMP ("naazza-secrets-{0}.env" -f [guid]::NewGuid())
  try {
    $serverSettings = @(
      "GEMINI_API_KEY=$($settings['GEMINI_API_KEY'])"
      "GEMINI_MODEL=$($settings['GEMINI_MODEL'])"
    )
    Set-Content -LiteralPath $temporarySecretFile -Value $serverSettings
    & npx --yes supabase@2.81.3 secrets set --env-file $temporarySecretFile
    if ($LASTEXITCODE -ne 0) { throw "Supabase secret sync failed with exit code $LASTEXITCODE" }
  }
  finally {
    if (Test-Path -LiteralPath $temporarySecretFile) {
      Remove-Item -LiteralPath $temporarySecretFile -Force
    }
  }
  exit 0
}

Require-Setting 'SUPABASE_URL'
Require-Setting 'SUPABASE_PUBLISHABLE_KEY'

$publicConfigPath = Join-Path $projectRoot 'config\public.generated.json'
$publicConfig = [ordered]@{
  SUPABASE_URL = $settings['SUPABASE_URL']
  SUPABASE_PUBLISHABLE_KEY = $settings['SUPABASE_PUBLISHABLE_KEY']
}
$publicConfig | ConvertTo-Json | Set-Content -LiteralPath $publicConfigPath
if ($Action -eq 'prepare') { exit 0 }

Push-Location $projectRoot
try {
  if ($Action -eq 'run') {
    & flutter run "--dart-define-from-file=$publicConfigPath" @ExtraArgs
  }
  else {
    & flutter build apk --debug "--dart-define-from-file=$publicConfigPath" @ExtraArgs
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter command failed with exit code $LASTEXITCODE" }
}
finally {
  Pop-Location
}
