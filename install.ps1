#Requires -Version 7
<#
.SYNOPSIS
  Installs the agent-kit into Claude Code and Codex CLI (global layer).
.DESCRIPTION
  - Skills: one directory junction per skill into ~/.claude/skills and ~/.agents/skills.
  - Agents: copied into ~/.claude/agents (tracked in a manifest so updates never clobber local edits).
  - Global instructions: a managed block in ~/.codex/AGENTS.md and an @import block in ~/.claude/CLAUDE.md.
  - CodeGraph MCP: registered with `claude mcp add` / `codex mcp add` only when missing.
  Idempotent. Use -WhatIf for a dry run. Never touches ~/.claude/skills/synced.
.PARAMETER TargetHome
  Home directory to install into. Defaults to the current user's home; override it for testing.
.PARAMETER SkipMcp
  Do not register the CodeGraph MCP server.
.PARAMETER Force
  Overwrite agent files that were modified locally.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$TargetHome = $HOME,
  [switch]$SkipMcp,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$Kit = $PSScriptRoot
$Version = (Get-Content (Join-Path $Kit 'VERSION') -Raw).Trim()
$Begin = '<!-- agent-kit:begin -->'
$End   = '<!-- agent-kit:end -->'
$script:Warnings = 0

function Say($tag, $msg) { Write-Host ("{0,-8} {1}" -f "[$tag]", $msg) }
function Warn($msg) { $script:Warnings++; Say 'warn' $msg }
function Norm($p) { [IO.Path]::GetFullPath($p).TrimEnd('\', '/').ToLowerInvariant() }
function Ensure-Dir($dir) {
  if (-not (Test-Path -LiteralPath $dir)) {
    if ($PSCmdlet.ShouldProcess($dir, 'create directory')) { New-Item -ItemType Directory -Path $dir | Out-Null }
  }
}
function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false)) }
function Backup-File($path) {
  $bak = "$path.agent-kit.bak-$(Get-Date -Format yyyyMMddHHmmss)"
  if ($PSCmdlet.ShouldProcess($path, "back up to $bak")) { Copy-Item -LiteralPath $path -Destination $bak }
  Say 'backup' $bak
}

Say 'kit' "agent-kit v$Version at $Kit"
Say 'target' $TargetHome

# --- 1. Skills: one junction per skill -------------------------------------
foreach ($skill in Get-ChildItem (Join-Path $Kit 'skills') -Directory) {
  $src = $skill.FullName
  foreach ($root in @((Join-Path $TargetHome '.claude\skills'), (Join-Path $TargetHome '.agents\skills'))) {
    $link = Join-Path $root $skill.Name
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item) {
      if ($item.LinkType -in 'Junction', 'SymbolicLink') {
        if ((Norm ($item.Target | Select-Object -First 1)) -eq (Norm $src)) { Say 'ok' "skill $($skill.Name) -> $link" }
        else { Warn "$link is a link to somewhere else; left alone" }
      } else { Warn "$link exists as a real directory; left alone" }
      continue
    }
    Ensure-Dir $root
    if ($PSCmdlet.ShouldProcess($link, "junction -> $src")) {
      New-Item -ItemType Junction -Path $link -Target $src | Out-Null
    }
    Say 'new' "skill $($skill.Name) -> $link"
  }
}

# --- 2. Agents: copy into ~/.claude/agents ---------------------------------
$agentDir = Join-Path $TargetHome '.claude\agents'
$manifestPath = Join-Path $agentDir '.agent-kit-manifest.json'
$manifest = @{}
if (Test-Path -LiteralPath $manifestPath) { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashTable }
$kitAgents = @(Get-ChildItem (Join-Path $Kit 'agents') -Filter *.md -File -ErrorAction SilentlyContinue)
$changed = $false
foreach ($agent in $kitAgents) {
  $dst = Join-Path $agentDir $agent.Name
  $newHash = (Get-FileHash -LiteralPath $agent.FullName).Hash
  $action = $null
  if (-not (Test-Path -LiteralPath $dst)) { $action = 'new' }
  else {
    $cur = (Get-FileHash -LiteralPath $dst).Hash
    if ($cur -eq $newHash) { Say 'ok' "agent $($agent.BaseName)"; if ($manifest[$agent.Name] -ne $newHash) { $manifest[$agent.Name] = $newHash; $changed = $true }; continue }
    elseif ($manifest[$agent.Name] -eq $cur) { $action = 'update' }
    elseif ($Force) { $action = 'update' }
    else { Warn "agent $($agent.BaseName): $dst differs and is not managed by the kit (or was edited); skipped (use -Force)"; continue }
  }
  Ensure-Dir $agentDir
  if ($PSCmdlet.ShouldProcess($dst, "$action agent")) { Copy-Item -LiteralPath $agent.FullName -Destination $dst -Force }
  $manifest[$agent.Name] = $newHash; $changed = $true
  Say $action "agent $($agent.BaseName)"
}
foreach ($name in @($manifest.Keys)) {
  if (-not ($kitAgents.Name -contains $name)) { Say 'note' "agent $name was removed from the kit; its installed copy is left in place" }
}
if ($changed) {
  Ensure-Dir $agentDir
  if ($PSCmdlet.ShouldProcess($manifestPath, 'write manifest')) { Write-Utf8 $manifestPath ($manifest | ConvertTo-Json) }
}

# --- 3. Global instructions: managed blocks --------------------------------
function Set-ManagedBlock($file, $content, $label) {
  $block = "$Begin`n$content`n$End`n"
  $exists = Test-Path -LiteralPath $file
  $raw = if ($exists) { (Get-Content -LiteralPath $file -Raw) } else { $null }
  $raw = if ($null -eq $raw) { '' } else { $raw -replace "`r`n", "`n" }
  if ($raw.Trim() -eq '') {
    Ensure-Dir (Split-Path $file)
    if ($PSCmdlet.ShouldProcess($file, "write $label")) { Write-Utf8 $file $block }
    Say 'new' "$label -> $file"; return
  }
  if ($raw.Contains($Begin) -and $raw.Contains($End)) {
    $pattern = '(?s)' + [regex]::Escape($Begin) + '.*?' + [regex]::Escape($End) + '\n?'
    $new = [regex]::Replace($raw, $pattern, { param($m) $block })
    if ($new -eq $raw) { Say 'ok' "$label in $file"; return }
    Backup-File $file
    if ($PSCmdlet.ShouldProcess($file, "update $label")) { Write-Utf8 $file $new }
    Say 'update' "$label in $file"; return
  }
  Backup-File $file
  if ($PSCmdlet.ShouldProcess($file, "append $label")) { Write-Utf8 $file ($raw.TrimEnd() + "`n`n" + $block) }
  Say 'update' "$label appended to $file"
}

$instr = Join-Path $Kit 'instructions\AGENTS.md'
$instrText = ((Get-Content -LiteralPath $instr -Raw) -replace "`r`n", "`n").TrimEnd()
Set-ManagedBlock (Join-Path $TargetHome '.codex\AGENTS.md') $instrText 'global instructions (copy)'

$kitFull = ([IO.Path]::GetFullPath($instr)) -replace '\\', '/'
$homeFull = ([IO.Path]::GetFullPath($TargetHome)).TrimEnd('\', '/') -replace '\\', '/'
$importPath = if ($kitFull.ToLowerInvariant().StartsWith($homeFull.ToLowerInvariant() + '/')) { '~' + $kitFull.Substring($homeFull.Length) } else { $kitFull }
Set-ManagedBlock (Join-Path $TargetHome '.claude\CLAUDE.md') "@$importPath" 'global instructions (@import)'

# --- 4. CodeGraph MCP (only when missing) ----------------------------------
if ($SkipMcp) { Say 'skip' 'MCP registration (-SkipMcp)' }
elseif (-not (Get-Command codegraph -ErrorAction SilentlyContinue)) { Warn 'codegraph CLI not found on PATH; MCP registration skipped (install it, then re-run)' }
else {
  foreach ($tool in 'claude', 'codex') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { Say 'skip' "$tool not installed"; continue }
    $null = & $tool mcp get codegraph 2>&1
    if ($LASTEXITCODE -eq 0) { Say 'ok' "$tool already has the codegraph MCP server"; continue }
    $cmd = if ($tool -eq 'claude') { @('mcp', 'add', '--scope', 'user', 'codegraph', '--', 'codegraph', 'serve', '--mcp') } else { @('mcp', 'add', 'codegraph', '--', 'codegraph', 'serve', '--mcp') }
    if ($PSCmdlet.ShouldProcess("$tool mcp", "register codegraph: $tool $($cmd -join ' ')")) {
      & $tool @cmd
      if ($LASTEXITCODE -ne 0) { Warn "$tool mcp add failed (exit $LASTEXITCODE)" } else { Say 'new' "$tool MCP server codegraph" }
    } else { Say 'would' "$tool $($cmd -join ' ')" }
  }
}

Say 'done' "agent-kit v$Version, $script:Warnings warning(s). The .codegraph index is not created here: run 'codegraph init -i' per repository when you want it."
