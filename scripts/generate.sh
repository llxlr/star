#!/usr/bin/env bash
# generate.sh — Fetch starred repos via gh CLI and render from template
#
# Requires: gh, jq
# Template file: template/README.ejs — EJS-compatible with <%= %> and <%# %> markers
#   <%= username %>              — GitHub username (top-level)
#   <%# LANGUAGES %>...<%# /LANGUAGES %> — iterate language groups
#     <%= lang.language %>       — language name
#     <%= lang.anchor %>         — anchor link for ToC
#   <%# REPOS %>...<%# /REPOS %>  — iterate repos (nested inside LANGUAGES)
#     <%= repo.full_name %>      — owner/repo
#     <%= repo.html_url %>       — repo URL
#     <%= repo.description %>    — repo description
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "📦 Fetching starred repos via gh api..." >&2
gh api --paginate user/starred --jq '.[]' | jq -s '.' > /tmp/stars.json

echo "🔄 Rendering README.md from template..." >&2

# Get current GitHub username
USERNAME="$(gh api user --jq '.login')"

# Read template file
TEMPLATE=$(<template/README.ejs)

# ── Step 1: Replace top-level variables ──────────────────────────────
TEMPLATE="${TEMPLATE//'<%= username %>'/$USERNAME}"

# ── Step 2: Process <%# LANGUAGES %>…<%# /LANGUAGES %> blocks ──────
# Each iteration handles one block (leftmost).  The while loop keeps
# going until no more block markers remain.
while [[ "$TEMPLATE" == *'<%# LANGUAGES %>'* ]]; do
  # Split on the block start marker
  before="${TEMPLATE%%'<%# LANGUAGES %>'*}"
  rest="${TEMPLATE#*'<%# LANGUAGES %>'}"

  # Extract inner content (everything up to <%# /LANGUAGES %>)
  inner_text="${rest%%'<%# /LANGUAGES %>'*}"
  after="${rest#*'<%# /LANGUAGES %>'}"

  # Trim leading/trailing newlines from inner_text
  inner_text="${inner_text#$'\n'}"
  inner_text="${inner_text%$'\n'}"

  # Check for nested <%# REPOS %>…<%# /REPOS %> sub-block
  repo_tpl=""
  lang_tpl="$inner_text"
  if [[ "$inner_text" == *'<%# REPOS %>'* ]]; then
    before_repos="${inner_text%%'<%# REPOS %>'*}"
    after_repos="${inner_text#*'<%# /REPOS %>'}"
    repo_tpl="${inner_text#*'<%# REPOS %>'}"
    repo_tpl="${repo_tpl%%'<%# /REPOS %>'*}"
    # Trim leading/trailing newlines from repo_tpl
    repo_tpl="${repo_tpl#$'\n'}"
    repo_tpl="${repo_tpl%$'\n'}"
    lang_tpl="${before_repos}__REPOS__${after_repos}"
  fi

  # ── Render the block via jq ───────────────────────────────────────
  # NOTE: jq's | pipe changes what . refers to.  Capture all needed
  # values into $variables BEFORE piping into the template string.
  if [ -n "$repo_tpl" ]; then
    # Block with nested repos loop
    rendered=$(LANG_TPL="$lang_tpl" REPO_TPL="$repo_tpl" jq -r '
      group_by(if .language then .language else "Miscellaneous" end)
      | map({
          language: (if .[0].language then .[0].language else "Miscellaneous" end),
          anchor:  (if .[0].language then .[0].language else "Miscellaneous" end
                    | ascii_downcase
                    | gsub("[^a-z0-9 ]"; "")
                    | gsub(" "; "-")),
          repos: .
        })
      | sort_by(.language)
      | map(
          .language as $lang
          | .anchor  as $anchor
          | .repos   as $repos
          | env.LANG_TPL
          | gsub("__REPOS__";
              ([$repos[] |
                .full_name    as $fn
                | .html_url   as $url
                | .description as $desc
                | env.REPO_TPL
                | gsub("<%= repo.full_name %>";    $fn)
                | gsub("<%= repo.html_url %>";     $url)
                | gsub("<%= repo.description %>";  (if $desc then $desc else "No description" end))
              ] | join("\n"))
            )
          | gsub("<%= lang.language %>"; $lang)
          | gsub("<%= lang.anchor %>";   $anchor)
        )
      | join("\n\n")
    ' /tmp/stars.json)
  else
    # Block without repos (e.g. Table of Contents)
    rendered=$(LANG_TPL="$lang_tpl" jq -r '
      group_by(if .language then .language else "Miscellaneous" end)
      | map({
          language: (if .[0].language then .[0].language else "Miscellaneous" end),
          anchor:  (if .[0].language then .[0].language else "Miscellaneous" end
                    | ascii_downcase
                    | gsub("[^a-z0-9 ]"; "")
                    | gsub(" "; "-"))
        })
      | sort_by(.language)
      | map(
          .language as $lang
          | .anchor  as $anchor
          | env.LANG_TPL
          | gsub("<%= lang.language %>"; $lang)
          | gsub("<%= lang.anchor %>";   $anchor)
        )
      | join("\n")
    ' /tmp/stars.json)
  fi

  # Reassemble: replace the block with rendered content
  TEMPLATE="${before}${rendered}${after}"
done

# Write final README
echo "$TEMPLATE" > README.md

# ── Save grouped data (cache / diff) ─────────────────────────────────
echo "💾 Saving organized data to data.json..." >&2
jq '
  group_by(if .language then .language else "Miscellaneous" end)
  | map({
      key:   (if .[0].language then .[0].language else "Miscellaneous" end),
      value: .
    })
  | from_entries
' /tmp/stars.json > data.json

rm -f /tmp/stars.json
echo "✅ Done! README.md and data.json updated." >&2
