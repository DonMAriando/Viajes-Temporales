param(
    [ValidateSet('Play', 'Editor', 'Import', 'Test')]
    [string]$Mode = 'Play',
    [string]$GodotPath = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) {
    $local = Join-Path $root '.tools\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $local) { $GodotPath = $local }
}
if (-not $GodotPath) {
    $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $GodotPath = $installed.Source }
}
if (-not $GodotPath) { $GodotPath = & (Join-Path $PSScriptRoot 'setup_godot.ps1') }
$console = $GodotPath -replace '\.exe$', '_console.exe'
if (Test-Path -LiteralPath $console) { $GodotPath = $console }
$version = & $GodotPath --headless --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.') {
    throw "Godot 4.7.2 is required. Executable reports: $version"
}
if ($Mode -in @('Play', 'Test')) {
    $importMessages = @(& $GodotPath --path $root --headless --editor --import --quit --quiet 2>&1)
    $importCode = $LASTEXITCODE
    if ($importCode -ne 0 -or $importMessages -match 'SCRIPT ERROR|^ERROR:') {
        $importMessages | ForEach-Object { Write-Output $_ }
        exit 1
    }
}

$arguments = @('--path', $root)
switch ($Mode) {
    'Editor' { $arguments += '--editor' }
    'Import' { $arguments += @('--headless', '--editor', '--import', '--quit') }
    'Test' { $arguments += @('--headless', '--fixed-fps', '60', 'res://tests/run_tests.tscn') }
}
if ($Mode -in @('Import', 'Test')) {
    $messages = @(& $GodotPath @arguments 2>&1)
    $code = $LASTEXITCODE
    $messages | ForEach-Object { Write-Output $_ }
    if ($messages -match 'SCRIPT ERROR|^ERROR:') { exit 1 }
    exit $code
} else {
    & $GodotPath @arguments
    exit $LASTEXITCODE
}
