param(
  [string[]]$SkillNames,
  [switch]$ForceReplace
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceSkillsRoot = Join-Path $workspaceRoot 'tools\Product-Manager-Skills\skills'
$targetSkillsRoot = Join-Path $workspaceRoot '.agents\skills'

if (!(Test-Path -LiteralPath $sourceSkillsRoot -PathType Container)) {
  throw "未找到源 skills 目录: $sourceSkillsRoot"
}

if (!(Test-Path -LiteralPath $targetSkillsRoot -PathType Container)) {
  throw "未找到目标 skills 目录: $targetSkillsRoot"
}

if (!$SkillNames -or $SkillNames.Count -eq 0) {
  $SkillNames = Get-ChildItem -LiteralPath $targetSkillsRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $sourceSkillsRoot $_.Name) } |
    Select-Object -ExpandProperty Name
}

if (!$SkillNames -or $SkillNames.Count -eq 0) {
  throw '没有找到可转换为源仓库链接的 PM skills。'
}

$results = @()

foreach ($skill in $SkillNames) {
  $sourcePath = Join-Path $sourceSkillsRoot $skill
  $targetPath = Join-Path $targetSkillsRoot $skill

  if (!(Test-Path -LiteralPath $sourcePath -PathType Container)) {
    Write-Warning "跳过 $skill：源 skill 不存在于 Product-Manager-Skills 仓库中。"
    continue
  }

  if (Test-Path -LiteralPath $targetPath) {
    $item = Get-Item -LiteralPath $targetPath

    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      Remove-Item -LiteralPath $targetPath -Force
    } elseif ($ForceReplace) {
      Remove-Item -LiteralPath $targetPath -Recurse -Force
    } else {
      throw "目标 skill 已存在且不是链接: $targetPath。若确认这是可替换的复制快照，请使用 -ForceReplace 重试。"
    }
  }

  New-Item -ItemType Junction -Path $targetPath -Target $sourcePath | Out-Null

  $results += [PSCustomObject]@{
    Skill  = $skill
    Source = $sourcePath
    Target = $targetPath
    Type   = 'Junction'
  }
}

$results | Format-Table -AutoSize
