# Migration Guide: mawesome → gh CLI + jq

## Why migrate

`simonecorsi/mawesome` GitHub Action 已被 GitHub 封禁，无法继续使用。
本方案用 GitHub 官方 CLI (`gh`) 配合 `jq` 和自定义模板语法实现零依赖替代。

## What changed — at a glance

| Item | Before | After |
|---|---|---|
| Star fetching | mawesome Action (Node.js) | `gh api --paginate /user/starred` |
| Template engine | EJS | EJS-compatible `<%= %>` syntax |
| Template file | `template/README.ejs` | `template/README.ejs` (EJS `<%= %>` + `<%# %>` syntax) |
| Auth | `secrets.API_TOKEN` (PAT) | `secrets.GITHUB_TOKEN` (built-in) |
| Commit/push | Handled inside Action | Explicit in workflow step |
| data.json schema | `{ "Language": [...] }` | Same (backward compatible) |

## Template syntax reference

### Variables

| Syntax | Source | Example |
|---|---|---|
| `<%= username %>` | `gh api /user --jq '.login'` | `llxlr` |
| `<%= lang.language %>` | Repo `.language` field | `TypeScript` |
| `<%= lang.anchor %>` | language → lower + slugify | `typescript` |
| `<%= repo.full_name %>` | Repo `.full_name` | `ceifa/wasmoon` |
| `<%= repo.html_url %>` | Repo `.html_url` | `https://github.com/...` |
| `<%= repo.description %>` | Repo `.description` (falls back to `"No description"`) | |

### Block markers

| Marker | Purpose |
|---|---|
| `<%# LANGUAGES %>` … `<%# /LANGUAGES %>` | Iterate language groups |
| `<%# REPOS %>` … `<%# /REPOS %>` | Iterate repos (nested inside LANGUAGES) |

### Converting from EJS

**Old (`template/README.ejs`):**

```ejs
<%= username %>
<% for(let [language, repositories] of stars) { %>
## <%= language %>
  <% for(let repo of repositories) { %>
- [<%= repo.full_name %>](<%= repo.html_url %>) - <%= repo.description %>
  <% } %>
<% } %>
```

**New (`template/README.ejs`) — EJS-compatible syntax:**

```
<%= username %>

<%# LANGUAGES %>
## <%= lang.language %>

<%# REPOS %>
- [<%= repo.full_name %>](<%= repo.html_url %>) - <%= repo.description %>
<%# /REPOS %>

<%# /LANGUAGES %>
```

> The new syntax is fully EJS-compatible: `<%= %>` for output, `<%# %>` for comments/block markers.

## Step-by-step migration

### 1. Replace template file

```bash
mv template/README.ejs template/README.ejs.bak   # keep backup
# Create new template/README.ejs with EJS-compatible syntax (see above)
```

### 2. Add generate.sh

Place `scripts/generate.sh` at repo root. Ensure executable:

```bash
chmod +x scripts/generate.sh
```

### 3. Update workflow

In `.github/workflows/main.yml`:
- Remove `uses: simonecorsi/mawesome@v2` step
- Replace with `run: bash scripts/generate.sh`
- Add explicit `git commit && git push` step
- Add `permissions.contents: write`

### 4. Verify locally

```bash
gh auth login
bash scripts/generate.sh
# Check: README.md and data.json should be generated
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `gh: command not found` | `brew install gh` / `apt install gh` |
| `jq: command not found` | `brew install jq` / `apt install jq` |
| `gh auth` 401 | Run `gh auth login` or set `GH_TOKEN` |
| Template block not rendering | Ensure markers are on their **own line**; no trailing spaces |
| Empty description | Falls back to `"No description"` automatically |
