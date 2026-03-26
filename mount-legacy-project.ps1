param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,

  [Parameter(Mandatory = $false)]
  [string]$AliasName
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectsRoot = Join-Path $workspaceRoot 'projects'

if (!(Test-Path -LiteralPath $projectsRoot)) {
  New-Item -ItemType Directory -Path $projectsRoot | Out-Null
}

$resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
if (!(Test-Path -LiteralPath $resolvedSource -PathType Container)) {
  throw "源目录不存在或不是文件夹: $SourcePath"
}

if ([string]::IsNullOrWhiteSpace($AliasName)) {
  $AliasName = Split-Path -Leaf $resolvedSource
}

$targetPath = Join-Path $projectsRoot $AliasName

if (Test-Path -LiteralPath $targetPath) {
  $targetItem = Get-Item -LiteralPath $targetPath

  if ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Remove-Item -LiteralPath $targetPath -Force
  } else {
    throw "目标路径已存在且不是链接，请先手动处理后再重试: $targetPath"
  }
}

New-Item -ItemType Junction -Path $targetPath -Target $resolvedSource | Out-Null

Write-Output "已创建旧项目挂载:"
Write-Output "source=$resolvedSource"
Write-Output "link=$targetPath"
