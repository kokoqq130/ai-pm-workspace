param(
  [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsRoot = Join-Path $workspaceRoot '.agents\skills'
$pmSourceRoot = Join-Path $workspaceRoot 'tools\Product-Manager-Skills\skills'
$validator = 'C:\Users\wangf\.codex\skills\.system\skill-creator\scripts\quick_validate.py'
$skillsLockPath = Join-Path $workspaceRoot 'skills-lock.json'

if (!(Test-Path -LiteralPath $skillsRoot -PathType Container)) {
  throw "未找到 skills 目录: $skillsRoot"
}

$discoveredNames = @{}
$lockedNames = @{}
$discoveryError = $null

try {
  $jsonText = & npx skills list -a codex --json
  $discovered = $jsonText | ConvertFrom-Json
  foreach ($item in $discovered) {
    $discoveredNames[$item.name] = $true
  }
} catch {
  $discoveryError = $_.Exception.Message
}

if (Test-Path -LiteralPath $skillsLockPath -PathType Leaf) {
  try {
    $skillsLock = Get-Content -Raw -LiteralPath $skillsLockPath | ConvertFrom-Json
    if ($skillsLock.skills) {
      foreach ($property in $skillsLock.skills.PSObject.Properties) {
        $lockedNames[$property.Name] = $true
      }
    }
  } catch {
    Write-Warning "无法解析 skills-lock.json: $($_.Exception.Message)"
  }
}

$results = @()

foreach ($dir in Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name) {
  $isLink = [bool]($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)
  $linkType = if ($isLink) { [string]$dir.LinkType } else { '' }
  $targetPath = ''

  if ($isLink -and $null -ne $dir.Target) {
    $targetPath = [string](@($dir.Target)[0])
  }

  $targetExists = if ($isLink) { Test-Path -LiteralPath $targetPath } else { $true }
  $skillMdPath = Join-Path $dir.FullName 'SKILL.md'
  $hasSkillMd = Test-Path -LiteralPath $skillMdPath -PathType Leaf

  $type = 'local'
  if ($isLink) {
    if ($targetPath.StartsWith($pmSourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      $type = 'pm-junction'
    } else {
      $type = 'linked'
    }
  }

  $codexDiscovered = if ($discoveredNames.Count -gt 0) {
    if ($discoveredNames.ContainsKey($dir.Name)) { 'yes' } else { 'no' }
  } else {
    'unknown'
  }
  $lockRegistered = if ($lockedNames.Count -gt 0) {
    if ($lockedNames.ContainsKey($dir.Name)) { 'yes' } else { 'no' }
  } else {
    'unknown'
  }

  $validate = 'skipped'
  $notes = [System.Collections.Generic.List[string]]::new()

  if (!$hasSkillMd) {
    $notes.Add('missing SKILL.md')
  }

  if ($isLink -and !$targetExists) {
    $notes.Add('broken junction')
  }

  if ($type -eq 'local' -and $hasSkillMd) {
    if ($codexDiscovered -eq 'no') {
      $notes.Add('local skill not discovered by skills CLI')
    }
    if ((Test-Path -LiteralPath $validator -PathType Leaf) -and (Get-Command python -ErrorAction SilentlyContinue)) {
      & python $validator $dir.FullName *> $null
      if ($LASTEXITCODE -eq 0) {
        $validate = 'valid'
      } else {
        $validate = 'failed'
        $notes.Add('local skill validation failed')
      }
    } else {
      $validate = 'unavailable'
      $notes.Add('validator unavailable')
    }
  } elseif ($type -eq 'pm-junction') {
    $validate = 'upstream-skip'
    if ($lockRegistered -eq 'no') {
      $notes.Add('missing skills-lock entry')
    }
    if ($codexDiscovered -eq 'no') {
      $notes.Add('not listed by skills CLI after junction linking')
    }
  }

  $hasBlockingIssue = $false
  if (!$hasSkillMd -or ($isLink -and !$targetExists)) {
    $hasBlockingIssue = $true
  }
  if ($type -eq 'local' -and ($validate -eq 'failed' -or $codexDiscovered -eq 'no')) {
    $hasBlockingIssue = $true
  }
  if ($type -eq 'pm-junction' -and $lockRegistered -eq 'no') {
    $hasBlockingIssue = $true
  }

  $status = if ($hasBlockingIssue) { 'check' } else { 'ok' }

  $row = [ordered]@{
    Skill    = $dir.Name
    Type     = $type
    SkillMd  = if ($hasSkillMd) { 'yes' } else { 'no' }
    Cli      = $codexDiscovered
    Lock     = $lockRegistered
    Validate = $validate
    Status   = $status
    Notes    = if ($notes.Count -gt 0) { $notes -join '; ' } else { '' }
  }

  if ($Detailed) {
    $row.LinkType = $linkType
    $row.Target = $targetPath
  }

  $results += [PSCustomObject]$row
}

$results | Format-Table -AutoSize

if ($discoveryError) {
  Write-Warning "无法确认 Codex 发现状态: $discoveryError"
}

$problemRows = @($results | Where-Object { $_.Status -ne 'ok' })

if ($problemRows.Count -gt 0) {
  Write-Output ''
  Write-Output '发现需要检查的项，请查看 Notes 列。'
  exit 1
}

Write-Output ''
Write-Output '当前工作空间 skills 状态正常。'
