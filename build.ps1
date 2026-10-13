# Builds VibePlayer for every supported Windows version and creates the installers.
#   powershell -ExecutionPolicy Bypass -File build.ps1                    # all editions
#   powershell -ExecutionPolicy Bypass -File build.ps1 -Editions x64      # just one
#   powershell -ExecutionPolicy Bypass -File build.ps1 -SkipInstaller     # apps only -> publish\<edition>
# Output: dist\VibePlayer-Setup-<version>-<edition>.exe and dist\SHA256SUMS.txt
param(
    [string]$Version = "1.0.2",
    [ValidateSet("x64", "arm64", "x86", "legacy")]
    [string[]]$Editions = @("x64", "arm64", "x86", "legacy"),
    [switch]$SkipInstaller
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$project = Join-Path $root "src\VibePlayer\VibePlayer.csproj"
$publishRoot = Join-Path $root "publish"
$dist = Join-Path $root "dist"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

function Find-Tool([string[]]$candidates) {
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

# ---- tools ---------------------------------------------------------------------------
$dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
$dotnet = Find-Tool @("$env:LOCALAPPDATA\Microsoft\dotnet\dotnet.exe", $(if ($dotnetCmd) { $dotnetCmd.Source }))
if (-not $dotnet) { throw ".NET SDK not found. Install the .NET 10 SDK from https://dot.net" }

$iscc = Find-Tool @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
if (-not $iscc -and -not $SkipInstaller) { throw "Inno Setup 6 not found. Install it from https://jrsoftware.org/isdl.php" }

# ---- icon ----------------------------------------------------------------------------
$icon = Join-Path $root "src\VibePlayer\Assets\VibePlayer.ico"
if (-not (Test-Path $icon)) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\make-icon.ps1") -OutFile $icon
}

$running = Get-Process VibePlayer -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($publishRoot, [StringComparison]::OrdinalIgnoreCase) }
if ($running) { throw "VibePlayer is running from $publishRoot - close it and run the build again." }

# ---- VLC plugin cache (makes start-up instant instead of scanning ~320 DLLs) ----------
# plugins.dat is what VLC's own installer creates with vlc-cache-gen. It is only valid while every plugin
# file keeps the exact size and timestamp it had when the cache was built (the installer keeps them).
function New-PluginCache([string]$exe, [string]$cache) {
    Write-Host "==> Building VLC plugin cache: $cache" -ForegroundColor Cyan
    if (Test-Path $cache) { Remove-Item $cache -Force }
    $p = Start-Process $exe -ArgumentList "--build-plugin-cache" -PassThru -Wait
    if ($p.ExitCode -ne 0 -or -not (Test-Path $cache)) { throw "Could not build the VLC plugin cache ($cache)" }
}

# Lists every plugin file (path, size, time, hash) so two plugin folders can be compared exactly.
function Get-PluginManifest([string]$dir) {
    Get-ChildItem $dir -Recurse -File | Where-Object { $_.Name -ne "plugins.dat" } | Sort-Object FullName | ForEach-Object {
        "{0}|{1}|{2}|{3}" -f $_.FullName.Substring($dir.Length), $_.Length, $_.LastWriteTimeUtc.Ticks, (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    }
}

# ---- publish -------------------------------------------------------------------------
# Fixed order: the legacy edition reuses the x86 edition's plugin cache.
$ordered = @("x64", "arm64", "x86", "legacy") | Where-Object { $Editions -contains $_ }
foreach ($edition in $ordered) {
    $out = Join-Path $publishRoot $edition
    # Embedded in the app (AssemblyMetadata "Edition"): the updater downloads the installer for the same edition.
    $feedEdition = if ($edition -eq "legacy") { "win7-8" } else { $edition }
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }

    if ($edition -eq "legacy") {
        # Windows 7 SP1 / 8.1: .NET Framework 4.8 (built into Windows or from Windows Update), both VLC engines.
        Write-Host "==> Publishing VibePlayer $Version for Windows 7 / 8.1 (.NET Framework 4.8)" -ForegroundColor Cyan
        & $dotnet publish $project -c Release -f net48 -o $out -p:DebugType=none -p:Version=$Version -p:VibeEdition=$feedEdition
    }
    else {
        # Windows 10 / 11: self-contained, nothing else to install.
        Write-Host "==> Publishing VibePlayer $Version for Windows 10 / 11 ($edition)" -ForegroundColor Cyan
        & $dotnet publish $project -c Release -f net10.0-windows -r "win-$edition" --self-contained true -o $out -p:DebugType=none -p:Version=$Version -p:VibeEdition=$feedEdition
    }
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $edition" }

    $exe = Join-Path $out "VibePlayer.exe"
    switch ($edition) {
        "x64" { New-PluginCache $exe (Join-Path $out "libvlc\win-x64\plugins\plugins.dat") }
        "x86" { New-PluginCache $exe (Join-Path $out "libvlc\win-x86\plugins\plugins.dat") }
        "arm64" {
            # ARM64 binaries can't run on this PC: VLC scans its plugins at start-up instead (a bit slower).
            Write-Host "    (no plugin cache for ARM64)" -ForegroundColor Yellow
        }
        "legacy" {
            # AnyCPU: on 64-bit Windows it runs as a 64-bit process and builds the win-x64 cache.
            if ([Environment]::Is64BitOperatingSystem) {
                New-PluginCache $exe (Join-Path $out "libvlc\win-x64\plugins\plugins.dat")
            }
            else {
                New-PluginCache $exe (Join-Path $out "libvlc\win-x86\plugins\plugins.dat")
            }

            # The other engine's cache comes from a matching edition, if its plugin files are identical.
            $other = if ([Environment]::Is64BitOperatingSystem) { @{ Edition = "x86"; Rid = "win-x86" } } else { @{ Edition = "x64"; Rid = "win-x64" } }
            $mine = Join-Path $out "libvlc\$($other.Rid)\plugins"
            $theirs = Join-Path $publishRoot "$($other.Edition)\libvlc\$($other.Rid)\plugins"
            $theirCache = Join-Path $theirs "plugins.dat"
            if ((Test-Path $theirCache) -and
                ((@(Get-PluginManifest $mine) -join "`n") -ceq (@(Get-PluginManifest $theirs) -join "`n"))) {
                Copy-Item $theirCache (Join-Path $mine "plugins.dat") -Force
                Write-Host "    Reused the $($other.Edition) edition's plugin cache for libvlc\$($other.Rid)" -ForegroundColor Cyan
            }
            else {
                Write-Host "    No identical $($other.Edition) build to take the libvlc\$($other.Rid) plugin cache from - skipped" -ForegroundColor Yellow
            }
        }
    }
}

if ($SkipInstaller) {
    Write-Host "Done: $publishRoot" -ForegroundColor Green
    return
}

# ---- file associations (generated from MediaFormats.cs so app & installer agree) -----
$formats = Get-Content (Join-Path $root "src\VibePlayer\Core\MediaFormats.cs") -Raw
function Get-Extensions([string]$name) {
    $m = [regex]::Match($formats, "$name\s*=\s*\{([^}]*)\}")
    if (-not $m.Success) { throw "Could not read $name from MediaFormats.cs" }
    return [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
}
$extensions = @(Get-Extensions "VideoExtensions") + @(Get-Extensions "AudioExtensions")

$lines = @("; Generated by build.ps1 - do not edit")
foreach ($ext in $extensions) {
    $lines += "Root: HKA; Subkey: ""Software\Classes\.$ext\OpenWithProgids""; ValueType: string; ValueName: ""{#ProgId}""; ValueData: """"; Flags: uninsdeletevalue; Tasks: fileassoc"
    $lines += "Root: HKA; Subkey: ""Software\{#AppName}\Capabilities\FileAssociations""; ValueType: string; ValueName: "".$ext""; ValueData: ""{#ProgId}""; Tasks: fileassoc"
    $lines += "Root: HKA; Subkey: ""Software\Classes\Applications\{#AppExe}\SupportedTypes""; ValueType: string; ValueName: "".$ext""; ValueData: """""
}
Set-Content -Path (Join-Path $root "installer\associations.iss") -Value $lines -Encoding UTF8

# ---- installers ----------------------------------------------------------------------
foreach ($edition in $ordered) {
    Write-Host "==> Compiling installer ($edition)" -ForegroundColor Cyan
    & $iscc /Q "/DAppVersion=$Version" "/DEdition=$edition" (Join-Path $root "installer\VibePlayer.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed for $edition" }
}

$setups = Get-ChildItem $dist -Filter "VibePlayer-Setup-$Version-*.exe" | Sort-Object Name
$sums = $setups | ForEach-Object {
    "{0}  {1}" -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
}
Set-Content -Path (Join-Path $dist "SHA256SUMS.txt") -Value $sums -Encoding ASCII
foreach ($setup in $setups) {
    Write-Host ("Done: {0} ({1:N1} MB)" -f $setup.Name, ($setup.Length / 1MB)) -ForegroundColor Green
    # GitHub refuses files of 100 MB or more.
    if ($setup.Length -ge 100MB) { Write-Warning "$($setup.Name) is too big for GitHub (100 MB limit)" }
}
