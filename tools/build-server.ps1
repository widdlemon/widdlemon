# build-server.ps1 - run from anywhere; builds an upload-ready server bundle for the host.
# Output: dist\widdlemon-server-<version>\ (folder) and dist\widdlemon-server-<version>.zip
#   mods\     server-side mods only (client-only mods are skipped)
#   config\   pack configs + server-only overlay (server\config)
#   <world>\datapacks\widdlemon-admin   admin functions (LuckPerms setup)
param(
    [string]$JavaHome  = $env:JAVA_HOME,   # must be Java 21
    [string]$WorldName = "world",          # the host's level-name
    [int]$Port         = 8081,
    [switch]$Force                         # rebuild even if this version's output already exists
)

$ErrorActionPreference = "Stop"
$repo    = Split-Path $PSScriptRoot -Parent
$version = ((Get-Content (Join-Path $repo "pack.toml")) | Where-Object { $_ -match '^version\s*=' }) -replace '^version\s*=\s*"(.*)"','$1'
$dist    = Join-Path $repo "dist"
$out     = Join-Path $dist "widdlemon-server-$version"
$zip     = "$out.zip"

$java = Join-Path $JavaHome "bin\java.exe"
if (-not (Test-Path $java)) { throw "No java.exe under JavaHome '$JavaHome'. Pass -JavaHome <path to JDK 21>." }
$javaVersion = (& cmd /c "`"$java`" -version 2>&1" | Select-Object -First 1)
if ($javaVersion -notmatch '"21\.') { throw "Need Java 21, but $java is: $javaVersion" }

if ((Test-Path $zip) -and -not $Force) {
    Write-Host "Version $version is already built: $zip" -ForegroundColor Green
    Write-Host "Upload that file. To rebuild the same version (e.g. after changing configs), run with -Force." -ForegroundColor DarkGray
    return
}
if (Test-Path $out) { Get-ChildItem $out -Force | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Force -Path $out | Out-Null

# Reuse the bootstrap jar the test server already downloaded, else fetch it
$bootstrap = Join-Path $repo "test-server\packwiz-installer-bootstrap.jar"
if (-not (Test-Path $bootstrap)) {
    $bootstrap = Join-Path $dist "packwiz-installer-bootstrap.jar"
    if (-not (Test-Path $bootstrap)) {
        Invoke-WebRequest "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar" -OutFile $bootstrap
    }
}
Copy-Item $bootstrap $out
# Reuse the cached installer too, so a GitHub outage can't break the build
$installer = Join-Path $repo "test-server\packwiz-installer.jar"
$noUpdate = @()
if (Test-Path $installer) { Copy-Item $installer $out; $noUpdate = @("--bootstrap-no-update") }

$serve = Start-Process packwiz -ArgumentList "serve", "--port", $Port -WorkingDirectory $repo -PassThru -WindowStyle Minimized
Start-Sleep -Seconds 2
try {
    Push-Location $out
    Write-Host "Syncing server side of pack $version ..." -ForegroundColor Cyan
    $ErrorActionPreference = "Continue"   # java logs to stderr; judge by exit code instead
    & $java -jar packwiz-installer-bootstrap.jar @noUpdate -g -s server "http://localhost:$Port/pack.toml"
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($code -ne 0) { throw "Server sync failed (exit $code)" }
}
finally {
    Pop-Location
    Stop-Process -Id $serve.Id -ErrorAction SilentlyContinue
}

# Server-only overlay
Copy-Item (Join-Path $repo "server\config\*") (Join-Path $out "config") -Recurse -Force
$dp = Join-Path $out "$WorldName\datapacks"
New-Item -ItemType Directory -Force -Path $dp | Out-Null
Copy-Item (Join-Path $repo "server\world\datapacks\*") $dp -Recurse -Force

# Installer leftovers don't belong on the host
Remove-Item (Join-Path $out "packwiz-installer-bootstrap.jar"), (Join-Path $out "packwiz-installer.jar"), (Join-Path $out "packwiz.json") -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression
# Build entries by hand: Windows PowerShell's zip helpers store "config\x.json" with backslashes,
# which Linux hosts extract as flat files literally named "config\x.json". Zip paths must use "/".
# Antivirus may briefly lock freshly written files; retry the zip a few times.
for ($try = 1; $try -le 5; $try++) {
    try {
        $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($f in Get-ChildItem $out -Recurse -File) {
                $entry = $f.FullName.Substring($out.Length + 1).Replace('\', '/')
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
            }
        } finally { $archive.Dispose() }
        break
    }
    catch { if (Test-Path $zip) { Remove-Item $zip }; if ($try -eq 5) { throw }; Start-Sleep -Seconds 3 }
}
$z = [IO.Compression.ZipFile]::OpenRead($zip); $zipped = $z.Entries.Count
$bad = @($z.Entries | Where-Object { $_.FullName.Contains('\') }).Count; $z.Dispose()
if ($bad -gt 0) { throw "$bad zip entries still contain backslashes" }
$onDisk = (Get-ChildItem $out -Recurse -File).Count
if ($zipped -ne $onDisk) { throw "Zip has $zipped files but the folder has $onDisk" }

$mods = (Get-ChildItem (Join-Path $out "mods") -Filter *.jar).Count
Write-Host ""
Write-Host "Built $zip  ($mods server mods)" -ForegroundColor Green
Write-Host "Upload: stop server -> DELETE remote mods\ -> upload + extract zip at the server root (merge config\, don't delete it) -> start." -ForegroundColor Yellow
Write-Host "First deploy only: set server.properties (whitelist, pvp, motd from server\motd.properties), then run 'function widdlemon:setup_luckperms'." -ForegroundColor Yellow
