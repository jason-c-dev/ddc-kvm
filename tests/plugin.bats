#!/usr/bin/env bats
# Plugin packaging: manifests agree with each other, the CLI, and the
# changelog; the skill's frontmatter and reference links are intact.

load test_helper

PLUGIN="$REPO_ROOT/.claude-plugin/plugin.json"
MARKET="$REPO_ROOT/.claude-plugin/marketplace.json"
SKILL="$REPO_ROOT/skills/setup/SKILL.md"

setup() {
  command -v jq >/dev/null || skip "jq not installed"
}

@test "plugin.json is valid JSON with the required fields" {
  run jq -e '.name and .version and .description and .author.name and .repository and .license' "$PLUGIN"
  assert_success
}

@test "marketplace.json is valid JSON with one plugin entry" {
  run jq -e '.name and .owner.name and (.plugins | length == 1) and .plugins[0].source == "./"' "$MARKET"
  assert_success
}

@test "plugin, marketplace, and marketplace entry share the name ddc-kvm" {
  assert_equal "$(jq -r .name "$PLUGIN")" "ddc-kvm"
  assert_equal "$(jq -r .name "$MARKET")" "ddc-kvm"
  assert_equal "$(jq -r '.plugins[0].name' "$MARKET")" "ddc-kvm"
}

@test "versions agree across plugin.json, marketplace.json, the CLI, and the changelog" {
  local plugin_v market_v cli_v changelog_v
  plugin_v=$(jq -r .version "$PLUGIN")
  market_v=$(jq -r '.plugins[0].version' "$MARKET")
  cli_v=$("$DDC_KVM" --version | awk '{print $2}')
  changelog_v=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$REPO_ROOT/CHANGELOG.md" | tr -d '#[] ')
  assert_equal "$market_v" "$plugin_v"
  assert_equal "$cli_v" "$plugin_v"
  assert_equal "$changelog_v" "$plugin_v"
}

@test "SKILL.md has name and description frontmatter" {
  run awk 'NR==1 && $0!="---" {exit 1} /^---$/ {n++; if (n==2) exit} n==1 {print}' "$SKILL"
  assert_success
  assert_output --partial "name: setup"
  assert_output --partial "description:"
}

@test "SKILL.md stays under 200 lines" {
  [ "$(wc -l <"$SKILL")" -lt 200 ]
}

@test "every reference linked from SKILL.md exists" {
  local ref
  while read -r ref; do
    [ -f "$REPO_ROOT/skills/setup/$ref" ] || { echo "missing $ref"; return 1; }
  done < <(grep -oE 'references/[a-z0-9-]+\.md' "$SKILL" | sort -u)
}

@test "every reference file is linked from SKILL.md" {
  local f
  for f in "$REPO_ROOT"/skills/setup/references/*.md; do
    grep -q "references/$(basename "$f")" "$SKILL" || { echo "unlinked $(basename "$f")"; return 1; }
  done
}

@test "the bundled script path in SKILL.md is real" {
  grep -q '\${CLAUDE_PLUGIN_ROOT}/scripts/ddc-kvm' "$SKILL"
  [ -x "$REPO_ROOT/scripts/ddc-kvm" ]
}

@test "claude plugin validate --strict passes" {
  command -v claude >/dev/null || skip "claude CLI not installed"
  run claude plugin validate --strict "$REPO_ROOT"
  assert_success
}
