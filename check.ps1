#Requires -Version 7
<#
.SYNOPSIS
  Reports differences between a project's docs skeleton and the current kit templates.
.DESCRIPTION
  Read-only. Never writes to the project. Compares section headings only; the content of the
  project's files is never inspected or touched.
.PARAMETER Project
  Project root (default: current directory). Must contain docs/.kit-version written by project-init.
#>
[CmdletBinding()]
param([string]$Project = (Get-Location).Path)
$ErrorActionPreference = 'Stop'
$Kit = $PSScriptRoot
$kitVer = (Get-Content (Join-Path $Kit 'VERSION') -Raw).Trim()
$verFile = Join-Path $Project 'docs\.kit-version'
if (-not (Test-Path -LiteralPath $verFile)) { Write-Host "[check]  $Project has no docs/.kit-version; it was not initialised with the kit."; exit 1 }

$lines = @(Get-Content -LiteralPath $verFile)
$projVer = $lines[0].Trim()
$lang = 'en'
foreach ($l in $lines) { if ($l -match '^\s*lang:\s*(\w+)') { $lang = $Matches[1] } }
Write-Host "[check]  project skeleton v$projVer ($lang), kit v$kitVer"

function Headings($path) {
  Get-Content -LiteralPath $path | Where-Object { $_ -match '^#{2,6}\s+\S' } | ForEach-Object { $_.Trim().ToLowerInvariant() }
}
$issues = 0
$tmplDir = Join-Path $Kit "templates\project\$lang\docs"
foreach ($t in Get-ChildItem $tmplDir -Filter *.md -File) {
  $target = Join-Path $Project "docs\$($t.Name)"
  if (-not (Test-Path -LiteralPath $target)) { Write-Host "[diff]   docs/$($t.Name): file missing in project"; $issues++; continue }
  $have = @(Headings $target)
  foreach ($h in Headings $t.FullName) { if ($have -notcontains $h) { Write-Host "[diff]   docs/$($t.Name): missing section '$h'"; $issues++ } }
}
$agents = Join-Path $Project 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agents)) { Write-Host '[diff]   AGENTS.md: missing'; $issues++ }
else {
  $have = @(Headings $agents)
  foreach ($h in '## read first', '## working style') { if ($have -notcontains $h) { Write-Host "[diff]   AGENTS.md: missing section '$h'"; $issues++ } }
  $text = Get-Content -LiteralPath $agents -Raw
  foreach ($d in 'DESIGN', 'DECISIONS', 'ROADMAP', 'QUESTIONS', 'DISCOVERY') { if ($text -notmatch "docs/$d\.md") { Write-Host "[diff]   AGENTS.md: does not mention docs/$d.md"; $issues++ } }
}
if (-not (Test-Path -LiteralPath (Join-Path $Project 'CLAUDE.md'))) { Write-Host '[diff]   CLAUDE.md: missing (should contain @AGENTS.md)'; $issues++ }

git -C $Kit rev-parse -q --verify "refs/tags/v$projVer" *> $null
if ($LASTEXITCODE -eq 0 -and $projVer -ne $kitVer) {
  Write-Host "[kit]    template changes since v${projVer}:"
  git -C $Kit diff --stat "v$projVer" HEAD -- templates/project skills/project-docs | ForEach-Object { Write-Host "         $_" }
}
if ($issues -eq 0) { Write-Host '[check]  skeleton structure matches the kit.' } else { Write-Host "[check]  $issues difference(s). Nothing was changed; apply what you want by hand." }
