$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskArtifacts = Join-Path $taskRoot 'artifacts\godot'
$taskStage = (Resolve-Path -LiteralPath (Join-Path $taskArtifacts 'native-quest-stage')).Path
$taskLive = (Resolve-Path -LiteralPath (Join-Path $taskArtifacts 'windows')).Path
$taskBackupParent = (Resolve-Path -LiteralPath (Join-Path $taskRoot 'artifacts\backups')).Path
$taskBackup = Join-Path $taskBackupParent 'windows-before-quests-20261017'
foreach ($taskPath in @($taskStage,$taskLive,$taskBackupParent,$taskBackup)) {
    if (-not $taskPath.StartsWith($taskRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Publication path escapes desktop workspace.' }
}
if (Test-Path -LiteralPath $taskBackup) { throw 'This pre-quest package backup already exists; inspect it before retrying publication.' }
$taskHash = (Get-FileHash -LiteralPath (Join-Path $taskStage '灰烬边境.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
foreach ($taskName in @('native-quest-build.json','native-release-quests.json','native-release-dialogue.json','windows-acceptance.json')) {
    $taskReport = Get-Content -LiteralPath (Join-Path $taskArtifacts $taskName) -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $taskReport.passed -or $taskReport.pckSha256 -ne $taskHash) { throw "The staged PCK has not passed current verification: $taskName" }
}
$taskBuild = Get-Content -LiteralPath (Join-Path $taskArtifacts 'native-quest-build.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($taskFile in $taskBuild.sourceFiles.PSObject.Properties) {
    $taskSource = Join-Path (Join-Path $taskRoot 'godot') $taskFile.Name
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.Value) { throw "Source changed after verification: $($taskFile.Name)" }
}
$taskRunning = @(Get-CimInstance Win32_Process -Filter "Name='灰烬边境.exe'" | Where-Object { [string]::IsNullOrEmpty($_.ExecutablePath) -or $_.ExecutablePath -eq (Join-Path $taskLive '灰烬边境.exe') })
if ($taskRunning.Count -gt 0) { throw '正式游戏仍在运行。请正常退出保存进度后再替换，不能强行关闭。' }
$taskPreviousHash = (Get-FileHash -LiteralPath (Join-Path $taskLive '灰烬边境.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
Move-Item -LiteralPath $taskLive -Destination $taskBackup
try { Move-Item -LiteralPath $taskStage -Destination $taskLive }
catch {
    if (-not (Test-Path -LiteralPath $taskLive)) { Move-Item -LiteralPath $taskBackup -Destination $taskLive }
    throw
}
if ((Get-FileHash -LiteralPath (Join-Path $taskLive '灰烬边境.pck') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskHash) { throw 'Published PCK hash mismatch.' }
[ordered]@{passed=$true;created=[DateTime]::UtcNow.ToString('o');directory=$taskLive;backup=$taskBackup;pckSha256=$taskHash;previousPckSha256=$taskPreviousHash;method='Verified stage; backed up and renamed directories on the same volume; live game process absent.'} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskArtifacts 'native-quest-publish.json') -Encoding UTF8
Write-Output "Published verified release. Previous package: $taskBackup"
