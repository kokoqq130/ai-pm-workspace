---
name: mount-legacy-project
description: Mount a legacy or old project into this workspace's `projects/` directory as a Windows junction instead of copying files. Use when the user asks to 挂载旧项目, 接入旧项目, link an existing project into `projects/`, or provides a source path and wants the project to be readable in this workspace without moving the physical files.
---

# Mount Legacy Project

Mount an existing project into `projects/` as a directory junction so the source files stay in their original location.

## Quick Start

When the user asks to mount or attach an old project:

1. Ask for the source path only if it is missing.
2. Ask for the alias name only if the user wants a custom display name under `projects/`.
3. Run the workspace script:

```powershell
.\mount-legacy-project.ps1 -SourcePath "<source-path>" -AliasName "<alias-name>"
```

If no alias is provided, omit `-AliasName` and let the script default to the source folder name.

## What To Do

### Case 1: User already gave a source path

- Use the provided path.
- If the user also gave the name they want to appear under `projects/`, pass it as `-AliasName`.
- After the script finishes, tell the user the mounted location under `projects/`.

### Case 2: User asked to mount a project but did not give a path

Ask for:

- the source project path
- an optional alias name if they do not want to use the original folder name

Do not guess missing paths.

### Case 3: A real directory already exists at `projects/<alias>`

Do not delete it automatically.

Explain clearly:

- the target path already exists as a normal directory, not a junction
- this usually means the user copied the project in instead of linking it
- they can either choose a different alias or explicitly ask to replace that copied folder after confirming the original project still exists elsewhere

### Case 4: A junction already exists at `projects/<alias>`

The script can safely replace the existing junction and point it to the new source path.

## Command Rules

- Always run from the workspace root: `D:\写需求用工作空间`
- Always use `.\mount-legacy-project.ps1`
- Prefer junction mounting over copying
- Do not move the original project
- Do not recommend dragging the only physical project folder into `projects/`

## Expected Output

After mounting, report:

- source path
- mounted path under `projects/`
- whether a custom alias was used

Example response shape:

```text
已挂载旧项目。
源路径: D:\codes\old-admin
工作区入口: D:\写需求用工作空间\projects\old-admin
挂载方式: junction
```

## When To Stop And Ask

Stop and ask instead of proceeding when:

- the source path does not exist
- the source path is not a directory
- the target path already exists as a normal directory
- the user did not provide enough information to identify the source project

## Notes

- This skill is workspace-specific and assumes the helper script exists at the workspace root.
- This skill is for mounting read-only reference projects into the PM analysis workspace.
