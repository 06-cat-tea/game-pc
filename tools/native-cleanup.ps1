param([string]$Plan = (Join-Path $PSScriptRoot '..\artifacts\godot\native-cleanup-plan.json'))
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskAudit = Get-Content -LiteralPath $Plan -Raw -Encoding UTF8 | ConvertFrom-Json
if ($taskAudit.missing.Count -gt 0) { throw 'Resolve missing resources before cleanup' }
$taskBackup = Join-Path $taskRoot 'artifacts\backups\before-godot-only-20261016.zip'
if (-not (Test-Path -LiteralPath $taskBackup)) { throw 'Pre-change backup is required' }
$taskResolvedTargets = @()
foreach ($taskEntry in $taskAudit.deletions) {
    if (-not (Test-Path -LiteralPath $taskEntry.path)) { continue }
    $taskTarget = (Resolve-Path -LiteralPath $taskEntry.path).Path
    if (-not $taskTarget.StartsWith($taskRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Cleanup target escapes desktop workspace' }
    foreach ($taskProtected in @('.git','artifacts\backups','artifacts\godot\engine','artifacts\godot\windows','art-source','godot\scripts','godot\data','godot\tests','godot\.godot')) {
        $taskProtectedPath = Join-Path $taskRoot $taskProtected
        if ($taskTarget -eq $taskProtectedPath -or $taskTarget.StartsWith($taskProtectedPath + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw "Protected cleanup target: $taskTarget" }
    }
    $taskResolvedTargets += $taskTarget
}
foreach ($taskTarget in $taskResolvedTargets) { Remove-Item -LiteralPath ('\\?\' + $taskTarget) -Recurse -Force }
[ordered]@{passed=$true;deletedEntries=$taskAudit.deletions.Count;deletedBytes=$taskAudit.deletedBytes;beforeBytes=$taskAudit.beforeBytes;afterBytes=$taskAudit.beforeBytes-$taskAudit.deletedBytes;backup=$taskBackup;deletions=$taskAudit.deletions} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskRoot 'artifacts\godot\native-cleanup-result.json') -Encoding UTF8
Write-Output "Cleaned $($taskResolvedTargets.Count) entries; $($taskAudit.deletedBytes) bytes"
