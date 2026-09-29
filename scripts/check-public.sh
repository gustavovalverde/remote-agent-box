#!/usr/bin/env bash
# Keeps instance data, secrets and style violations out of this public repo.
# Usage: scripts/check-public.sh [--require-denylist] [--commits]
#   PUBLIC_DENYLIST  newline- or comma-separated fixed strings (case-insensitive);
#                    matches print file:line and "denylist", never the term.
#   --require-denylist  fail when PUBLIC_DENYLIST is empty.
#   --commits           fail when any commit author or committer address is not a
#                       GitHub noreply address.
# Scans tracked files, or every file outside a git checkout (except this script
# and binaries). Exits 1 on any finding.
set -euo pipefail

require_denylist=0
check_commits=0
for arg in "$@"; do
  case "$arg" in
    --require-denylist) require_denylist=1 ;;
    --commits) check_commits=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."

list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files
  else
    find . -type f -not -path './.git/*' | sed 's|^\./||' | sort
  fi
}

files=()
while IFS= read -r f; do
  [ "$f" = "scripts/check-public.sh" ] && continue
  [ -f "$f" ] || continue
  grep -Iq . "$f" 2>/dev/null || continue
  files+=("$f")
done < <(list_files)

declare -A counts
total=0

report() { # rule, grep output lines (file:line:text)
  local rule="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s [%s]\n' "$(cut -d: -f1,2 <<<"$line")" "$rule"
    counts[$rule]=$(( ${counts[$rule]:-0} + 1 ))
    total=$((total + 1))
  done
}

scan() { # rule, ERE, [file glob filter]
  local rule="$1" re="$2" glob="${3:-}" targets=() f
  for f in "${files[@]}"; do
    # shellcheck disable=SC2254
    case "$f" in $glob) targets+=("$f") ;; esac
  done
  [ "${#targets[@]}" -gt 0 ] || return 0
  report "$rule" < <(grep -nEH -- "$re" "${targets[@]}" 2>/dev/null || true)
}

scan cgnat-mesh-address '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}\b' '*'
scan tailnet-dns '\.ts\.net\b' '*'
scan tailnet-id '\btail[0-9a-f]{6}\b' '*'
scan provider-hostname '\bns[0-9]+\.ip-' '*'
scan macos-home-path '/Users/[A-Za-z]' '*'
scan authorization-literal 'Authorization:' '*'
scan token-shape 'sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_|xox[bp]-' '*'
scan ssh-public-key 'ssh-(ed25519|rsa) AAAA' '*'
scan pinned-model '\bclaude-(opus|sonnet|haiku|fable)-[0-9]|\bgpt-[0-9]' '*'
scan em-dash "$(printf '\xe2\x80\x94')" '*.md'

# Email addresses, except @example.com and GitHub noreply addresses.
for f in "${files[@]}"; do
  report email-address < <(grep -noE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- "$f" 2>/dev/null \
    | grep -vE '@example\.com$|@users\.noreply\.github\.com$|^[0-9]+:noreply@github\.com$' \
    | sed "s|^|$f:|" || true)
done

# Denylist of instance terms, supplied out of band.
terms="$(printf '%s' "${PUBLIC_DENYLIST:-}" | tr ',' '\n' | sed '/^[[:space:]]*$/d')"
if [ -n "$terms" ]; then
  printf '%s\n' "$terms" > "${TMPDIR:-/tmp}/denylist.$$"
  for f in "${files[@]}"; do
    report denylist < <(grep -nFiH -f "${TMPDIR:-/tmp}/denylist.$$" -- "$f" 2>/dev/null || true)
  done
  rm -f "${TMPDIR:-/tmp}/denylist.$$"
elif [ "$require_denylist" -eq 1 ]; then
  echo "denylist: PUBLIC_DENYLIST is empty but --require-denylist was given"
  counts[denylist-missing]=1
  total=$((total + 1))
else
  echo "denylist: skipped (PUBLIC_DENYLIST empty)"
fi

if [ "$check_commits" -eq 1 ]; then
  if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    bad="$(git log --format='%ae%n%ce' | sort -u | grep -vE '(^|\+)[^@]*@users\.noreply\.github\.com$|^noreply@github\.com$' | sed '/^$/d' || true)"
    if [ -n "$bad" ]; then
      n="$(wc -l <<<"$bad" | tr -d ' ')"
      echo "commits: $n author or committer address(es) are not GitHub noreply addresses [commit-email]"
      counts[commit-email]=$n
      total=$((total + n))
    fi
  fi
fi

if [ "$total" -gt 0 ]; then
  echo "--"
  for rule in "${!counts[@]}"; do echo "$rule: ${counts[$rule]}"; done | sort
  echo "check-public: $total finding(s)"
  exit 1
fi
echo "check-public: ok"
