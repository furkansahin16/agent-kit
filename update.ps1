#Requires -Version 7
<#
.SYNOPSIS
  Updates the agent-kit: git pull, summary of what changed, then install again.
.DESCRIPTION
  Junction-linked skills update through the pull itself. Agents are copies, so install re-copies
  them (never over local edits unless -Force). With -WhatIf nothing is pulled: it fetches and shows
  what would arrive, then runs install in dry-run mode.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$TargetHome = $HOME,
  [switch]$SkipMcp,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$Kit = $PSScriptRoot
# Not named "Git": function names are case-insensitive and would shadow git.exe (infinite recursion).
function Invoke-KitGit { & git -C $Kit @args; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" } }

$oldVer = (Get-Content (Join-Path $Kit 'VERSION') -Raw).Trim()
$old = (git -C $Kit rev-parse HEAD).Trim()
if (git -C $Kit status --porcelain) { throw "Uncommitted changes in $Kit. Commit or stash them first." }

$remotes = @(git -C $Kit remote)
if ($remotes.Count -eq 0) {
  Write-Host '[note]   no git remote configured; skipping pull and re-running install only'
} elseif ($WhatIfPreference) {
  Invoke-KitGit fetch --quiet
  $upstream = git -C $Kit rev-parse --abbrev-ref '@{u}' 2>$null
  if ($LASTEXITCODE -eq 0 -and $upstream) {
    Write-Host "[would]  git pull --ff-only ($upstream). Incoming commits:"
    $incoming = git -C $Kit log --oneline --no-decorate "HEAD..$upstream"
    if ($incoming) { $incoming | ForEach-Object { Write-Host "         $_" } } else { Write-Host '         (none, already up to date)' }
  } else { Write-Host '[note]   no upstream branch configured; nothing to pull' }
} else {
  Invoke-KitGit pull --ff-only
}

$new = (git -C $Kit rev-parse HEAD).Trim()
$newVer = (Get-Content (Join-Path $Kit 'VERSION') -Raw).Trim()
if ($old -eq $new) { Write-Host "[kit]    already at v$newVer ($($new.Substring(0,7)))" }
else {
  Write-Host "[kit]    v$oldVer -> v$newVer  ($($old.Substring(0,7)) -> $($new.Substring(0,7)))"
  git -C $Kit log --oneline --no-decorate "$old..$new" | ForEach-Object { Write-Host "         $_" }
  Write-Host '[note]   project skeletons are copies; run check.ps1 -Project <path> to see skeleton changes'
}

$p = @{ TargetHome = $TargetHome }
if ($SkipMcp) { $p.SkipMcp = $true }
if ($Force) { $p.Force = $true }
if ($WhatIfPreference) { $p.WhatIf = $true }
& (Join-Path $Kit 'install.ps1') @p
