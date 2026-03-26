# Codex Prompt Starters

## 1. Kick Off Requirement Analysis

```text
Use $prioritization-advisor and $problem-statement to analyze the request in `.pm-workspace/inbox/<项目名>/<file>.md`.
Ask up to 3 clarifying questions first.
Then produce:
1. the real business problem,
2. the likely scope,
3. non-goals,
4. missing information,
5. a recommended next step.
Save the working notes in `.pm-workspace/analysis/<项目名>/`.
```

## 2. Compare Against Older Projects

```text
Review `.pm-workspace/references/<项目名>/` and compare those patterns with the current request in `.pm-workspace/inbox/<项目名>/<file>.md`.
Highlight:
1. reusable ideas,
2. risks from copying old behavior,
3. missing implementation details that require reading a mounted legacy project.
If code-level review is needed:
1. tell me to mount the old project into `projects/旧项目名/`,
2. if the project is already mounted but there is no summary yet, generate a summary first,
3. then continue the comparison.
```

## 3. Draft A PRD

```text
Use $prd-development to turn `.pm-workspace/analysis/<项目名>/<file>.md` into a decision-ready PRD.
Keep it concise but engineering-ready.
End with assumptions, risks, and unresolved questions.
Write the result to `.pm-workspace/outputs/<项目名>/`.
```

## 4. Draft Stories After PRD

```text
Use $user-story and $user-story-splitting to turn `.pm-workspace/outputs/<项目名>/<prd-file>.md` into implementation-ready stories.
Include acceptance criteria and call out anything that still needs design or backend confirmation.
```
