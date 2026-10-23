$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\godot'))
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory 'project.godot'))) { throw 'Native project missing' }
$codexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$integrationDirectory = Join-Path $codexDirectory 'integrations\godot-mcp'
$launcher = Join-Path $integrationDirectory 'launch-mcp.cjs'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'Install the pinned local Godot MCP integration first.' }
$server = (& codex mcp get godot --json | ConvertFrom-Json)
Copy-Item -LiteralPath (Join-Path $codexDirectory 'config.toml') -Destination (Join-Path $integrationDirectory 'config-before-native-desktop.toml') -Force
& codex mcp add godot -- $server.transport.command $launcher -p $projectDirectory
if ($LASTEXITCODE -ne 0) { throw 'MCP registration failed' }
Write-Output "Godot MCP target configured: $projectDirectory"
Write-Output 'Restart the godot MCP server in Codex to refresh file-tool context.'
