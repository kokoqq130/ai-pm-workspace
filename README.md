# AI PM Workspace

这是一个面向 Codex / AI 的需求分析工作空间，用来做：

- 需求分析与需求澄清
- PRD 草稿整理
- 用户故事拆分
- 旧项目摘要与迭代判断
- 基于 Product-Manager-Skills 的产品分析工作流

## 目录结构

- `AGENTS.md`：工作区级 AI 行为说明
- `.pm-workspace/`：需求分析主工作区
- `projects/`：旧项目挂载入口
- `tools/Product-Manager-Skills/`：PM skills 源仓库
- `.agents/skills/mount-legacy-project/`：本地自定义 skill
- `mount-legacy-project.ps1`：挂载旧项目
- `link-pm-skills.ps1`：重建 PM skills 链接
- `check-workspace-skills.ps1`：检查当前工作区 skills 状态

## 仓库说明

为了避免把本机绝对路径和外部项目副本一起推到 GitHub：

- `projects/` 下实际挂载的旧项目不会被提交
- `.agents/skills/` 下指向 PM skills 源仓库的链接不会被提交
- 本地自定义 skill `mount-legacy-project` 会保留在仓库中

## 克隆后建议操作

如果你克隆这个仓库后想恢复完整工作区能力，建议按这个顺序执行：

```powershell
git submodule update --init --recursive
.\link-pm-skills.ps1 -ForceReplace
.\check-workspace-skills.ps1
```

如果你还需要接入旧项目：

```powershell
.\mount-legacy-project.ps1 -SourcePath "D:\你的旧项目路径" -AliasName "旧项目名"
```

## 当前工作方式

- `.pm-workspace/` 采用“按分类 + 按项目名”的双层结构
- 同一项目的材料优先写入：
  - `.pm-workspace/inbox/<项目名>/`
  - `.pm-workspace/references/<项目名>/`
  - `.pm-workspace/analysis/<项目名>/`
  - `.pm-workspace/outputs/<项目名>/`
  - `.pm-workspace/scratch/<项目名>/`
- 如果暂时没有明确项目名，可以先放到 `general/`

## 上游依赖

`tools/Product-Manager-Skills/` 来自：

- https://github.com/deanpeters/Product-Manager-Skills
