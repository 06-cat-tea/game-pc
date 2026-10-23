param([ValidateSet('run','editor','test','export')][string]$Action = 'export')
$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
if ($Action -eq 'export') {
    $exportTarget = Join-Path $projectDirectory 'build\windows\灰烬边境.exe'
    if ((Test-Path -LiteralPath $exportTarget) -and @(Get-Process -Name '灰烬边境' -ErrorAction SilentlyContinue | Where-Object { [string]::IsNullOrEmpty($_.Path) -or $_.Path -eq $exportTarget }).Count -gt 0) { throw 'Please exit the running game before replacing its EXE/PCK.' }
}
$enginePath = $env:GODOT_PATH
if (-not $enginePath) {
    $localEngine = Join-Path $projectDirectory '..\artifacts\godot\engine\godot.exe'
    if (Test-Path -LiteralPath $localEngine) { $enginePath = (Resolve-Path -LiteralPath $localEngine).Path }
}
if (-not $enginePath) {
    $command = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $enginePath = $command.Source }
}
if (-not $enginePath -and $IsWindows -ne $false) {
    $steam = Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
    if ($steam) {
        $candidate = Join-Path $steam.SteamPath 'steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
        if (Test-Path -LiteralPath $candidate) { $enginePath = $candidate }
    }
}
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath)) { throw 'Set GODOT_PATH to your Godot 4.7.2 executable.' }
if ($Action -in @('test','export')) {
    $importArguments = @('--headless','--editor','--import','--recovery-mode','--path',$projectDirectory)
    $importProcess = Start-Process -FilePath $enginePath -ArgumentList ($importArguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle Hidden -Wait -PassThru
    if ($importProcess.ExitCode -ne 0) { throw "Godot import exited with code $($importProcess.ExitCode)" }
}
$engineArguments = @('--path', $projectDirectory)
switch ($Action) {
    'editor' { $engineArguments += '--editor' }
    'test' { $engineArguments += @('--headless','--script','res://tests/test_suite.gd') }
    'export' {
        $destination = Join-Path $projectDirectory 'build\windows'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $engineArguments += @('--headless','--recovery-mode','--export-release','Windows Desktop',(Join-Path $destination '灰烬边境.exe'))
    }
}
$windowStyle = if ($Action -in @('run','editor')) { 'Normal' } else { 'Hidden' }
$process = Start-Process -FilePath $enginePath -ArgumentList ($engineArguments | ForEach-Object { '"' + $_ + '"' }) -WindowStyle $windowStyle -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Godot exited with code $($process.ExitCode)" }
if ($Action -eq 'export') {
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'WINDOWS-README.txt') -Destination (Join-Path $destination 'README.txt') -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE-Game-CC0.txt') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE-Icons-CC-BY-3.0.txt') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE-Godot.txt') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'LICENSE-ThirdParty-CC0.txt') -Destination $destination -Force
    Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets\fonts\OFL.txt') -Destination (Join-Path $destination 'LICENSE-Font-OFL.txt') -Force
    Get-ChildItem -LiteralPath $destination -File | Where-Object Name -Match '^灰烬边境\.exe~RF[\da-f]+\.TMP$' | ForEach-Object {
        $exportTemporary = $_.FullName
        try { Remove-Item -LiteralPath $exportTemporary -Force -ErrorAction Stop }
        catch {
            if (-not (Test-Path -LiteralPath $exportTemporary)) { throw }
            $exportHolding = Join-Path $projectDirectory 'build\export-residue'
            New-Item -ItemType Directory -Path $exportHolding -Force | Out-Null
            Move-Item -LiteralPath $exportTemporary -Destination (Join-Path $exportHolding (([DateTime]::UtcNow.Ticks.ToString()) + '-' + (Split-Path -Leaf $exportTemporary)))
        }
    }
}
