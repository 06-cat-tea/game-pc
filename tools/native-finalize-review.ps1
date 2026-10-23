$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskTargets = @('artifacts\godot\isolated-checks','artifacts\godot\brand-runtime-profile')
$taskReview = Join-Path $taskRoot 'artifacts\godot\upgrade-review'
$taskEntries = @()
foreach ($taskRelative in $taskTargets) {
    $taskPath = Join-Path $taskRoot $taskRelative
    if (Test-Path -LiteralPath $taskPath) { $taskEntries += Get-Item -LiteralPath $taskPath }
}
$taskEntries += Get-ChildItem -LiteralPath $taskReview -File | Where-Object Name -Match '^click-\d{2}-\d\.png$'
$taskBytes = 0L
$taskDeleted = @()
foreach ($taskEntry in $taskEntries) {
    $taskPath = (Resolve-Path -LiteralPath $taskEntry.FullName).Path
    if (-not $taskPath.StartsWith((Join-Path $taskRoot 'artifacts\godot') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Temporary cleanup path escapes native artifacts' }
    if ($taskEntry.PSIsContainer) { $taskBytes += (Get-ChildItem -LiteralPath $taskPath -Recurse -File | Measure-Object -Property Length -Sum).Sum } else { $taskBytes += $taskEntry.Length }
    $taskDeleted += $taskPath
    Remove-Item -LiteralPath ('\\?\' + $taskPath) -Recurse -Force
}
# Remove now-empty retired asset and editor placeholder directories only.
$taskDirectories = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'godot\assets') -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending)
foreach ($taskName in @('export_templates','feature_profiles','licenses','script_templates','text_editor_themes')) {
    $taskPath = Join-Path $taskRoot ('godot\' + $taskName)
    if (Test-Path -LiteralPath $taskPath) { $taskDirectories += Get-Item -LiteralPath $taskPath }
}
foreach ($taskEntry in $taskDirectories) {
    $taskPath = (Resolve-Path -LiteralPath $taskEntry.FullName).Path
    if (-not $taskPath.StartsWith((Join-Path $taskRoot 'godot') + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Empty directory cleanup escapes project' }
    if ((Get-ChildItem -LiteralPath $taskPath -Force | Measure-Object).Count -eq 0) { Remove-Item -LiteralPath $taskPath; $taskDeleted += $taskPath }
}
[ordered]@{passed=$true;temporaryBytes=$taskBytes;deleted=$taskDeleted;note='Discarded completed isolated verification copies and superseded screenshots; reports and latest evidence retained.'} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskRoot 'artifacts\godot\native-final-cleanup.json') -Encoding UTF8
