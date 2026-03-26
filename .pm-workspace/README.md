# 需求分析工作区

这个工作区专门用于做需求分析、需求梳理和产品文档整理。

从现在开始，`.pm-workspace/` 默认采用“按分类 + 按项目名”的双层结构。

也就是说，真正的材料优先放在：

- `inbox/<项目名>/`
- `references/<项目名>/`
- `analysis/<项目名>/`
- `outputs/<项目名>/`
- `scratch/<项目名>/`

如果暂时还没有明确项目名，可以先放在 `general/`，等项目名稳定后再移动。

## 目录说明

- `inbox/`：存放从聊天、会议、工单或截图里整理出的原始需求输入。建议使用 `inbox/<项目名>/`
- `references/`：存放从旧项目中提炼出来的笔记、截图和文档摘要。建议使用 `references/<项目名>/`
- `analysis/`：存放过程中的分析记录、范围判断、差距分析和决策日志。建议使用 `analysis/<项目名>/`
- `outputs/`：存放最终产出的 PRD、用户故事、需求摘要和交接文档。建议使用 `outputs/<项目名>/`
- `scratch/`：存放一次性临时材料，适合会话中途随手记录后再清理。建议使用 `scratch/<项目名>/`
- `templates/`：存放可复用的 Markdown 模板和给 Codex 用的提示词模板。

## 推荐使用流程

1. 先把原始需求放进 `inbox/<项目名>/`。
2. 以 `templates/requirement-brief.md` 为模板，在 `analysis/<项目名>/` 中新建一份分析文档。
3. 只把和当前需求真正相关的旧项目经验整理到 `references/<项目名>/`。
4. 如果确实需要代码级对比，优先把旧项目以目录联接方式挂载到 `projects/旧项目名/`，而不是复制项目副本。
5. 稳定后的结果放进 `outputs/<项目名>/`。

## Product Manager Skills 使用建议

- `Product-Manager-Skills` 仓库尽量放在业务仓库之外单独管理。
- 这个需求分析工作区优先使用项目级 Codex skill 安装，而不是一开始就全局安装。
- 如果后面这里变成你的主力 PM 工作空间，再考虑把整套 skill 安装完整。

## 当前 Skills 状态

当前工作空间已经安装了一批和需求分析相关的项目级 Codex skills。

- PM 相关 skills 以链接方式指向 `tools/Product-Manager-Skills/skills/`
- 本工作空间自定义的本地 skill 保留在 `.agents/skills/`

如果你想确认当前到底有哪些 skill，以 `.agents/skills/` 目录中的内容为准。

如果你更新了 `tools/Product-Manager-Skills` 仓库，相关 PM skills 会随着源仓库内容一起更新。

如果你想检查当前工作空间里的 skills 是否都正常可用，可以在工作区根目录运行：

```powershell
.\check-workspace-skills.ps1
```

## 边界约定

- 和需求分析、历史对比有关的内容统一放在 `.pm-workspace/` 下。
- 默认优先按项目建子目录，不要把多个项目的文件直接混在同一层。
- `references/<项目名>/` 里优先保留精简后的摘要，不建议直接堆整份旧仓库。
- 旧项目原始内容优先挂载到 `projects/`，不要直接混放进 `.pm-workspace/`。
