param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root '.tools'
$name = 'Godot_v4.7.2-stable_win64.exe.zip'
$base = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable'
$executable = Join-Path $destination 'Godot_v4.7.2-stable_win64.exe'
if (Test-Path -LiteralPath $executable) { return $executable }

New-Item -ItemType Directory -Force -Path $destination | Out-Null
$archive = Join-Path $destination $name
$checksumFile = Join-Path $destination 'SHA512-SUMS.txt'
Invoke-WebRequest -Uri "$base/$name" -OutFile $archive
Invoke-WebRequest -Uri "$base/SHA512-SUMS.txt" -OutFile $checksumFile
$line = Get-Content -LiteralPath $checksumFile | Where-Object { $_ -match " $([regex]::Escape($name))$" }
if (-not $line) { throw 'The official Godot checksum is missing.' }
$expected = ($line.Trim() -split '\s+')[0]
$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash
if ($actual.ToLowerInvariant() -ne $expected.ToLowerInvariant()) { throw 'Godot SHA512 checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
Remove-Item -LiteralPath $archive
return $executable
