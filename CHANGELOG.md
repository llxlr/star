# Changelog

## [2.0.0] — 2026-01-XX

### Changed

- **从 mawesome GitHub Action 迁移至纯 CLI 方案**。原依赖 `simonecorsi/mawesome@v2` 已被 GitHub 封禁，现改用 `gh api` + `jq` + Bash 脚本完全替代。

### Added

- `scripts/generate.sh` — 核心脚本，负责：
  - 通过 `gh api --paginate /user/starred` 拉取全部 starred 仓库
  - 用 `jq` 按 `language` 字段分组排序
  - **基于模板文件 `template/README.ejs` 渲染**（EJS 兼容 `<%= %>` 语法）
  - 输出与原 mawesome 同构的 `data.json`
- `template/README.ejs` — EJS 兼容模板文件（保留 `.ejs` 扩展名），支持：
  - `<%= username %>` — 变量替换
  - `<%# LANGUAGES %>`…`<%# /LANGUAGES %>` — 语言分组遍历
  - `<%= lang.language %>` / `<%= lang.anchor %>` — 语言名与锚点
  - `<%# REPOS %>`…`<%# /REPOS %>` — 仓库列表遍历（嵌套在 LANGUAGES 内）
  - `<%= repo.full_name %>` / `<%= repo.html_url %>` / `<%= repo.description %>` — 仓库字段
- `.github/workflows/main.yml` 新增显式 `git commit` + `git push` 步骤，替代原 Action 内置的自动提交

### Removed

- `uses: simonecorsi/mawesome@v2` 外部 Action 依赖，消除供应链风险
- `template/README.ejs`（旧版） — 被重写为 EJS 兼容 `<%= %>` + `<%# %>` 语法
- `api-token` 参数，还用 `API_TOKEN` 环境变量（`gh` CLI 原生认证）

### Changed

- 认证方式：从自定义 PAT (`secrets.API_TOKEN`) 切换为 Actions 内置 `secrets.GITHUB_TOKEN`
- README footer：`generated with simonecorsi/mawesome` → `generated with gh CLI`
- 渲染方式：从 EJS 模板引擎改为 EJS 兼容 `<%= %>` 语法，模板为 `template/README.ejs`
- 目录 anchor 生成规则：改为 `ascii_downcase + 去除非字母数字`，与旧版效果等价

### Fixed

- 修复 workflow 因 mawesome 仓库被封禁而无法运行的问题
