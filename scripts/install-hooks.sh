#!/usr/bin/env bash
# Install this repo's git hooks.
#
#   scripts/install-hooks.sh
#
# Git does not version .git/hooks, so this has to be run once per clone.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p .git/hooks

cat > .git/hooks/pre-push <<'HOOK'
#!/usr/bin/env bash
# Refuse to push a stale freeze cache or an unsafe file.
#
# Both checks also run in CI. Running them here turns a failed build into an
# instant local error, which matters most for the freeze cache: the mistake it
# catches is silent, and you would otherwise learn about it from a red tick
# several minutes after moving on.
#
# Skip with --no-verify if you know what you are doing.
set -uo pipefail

fail=0
scripts/check-freeze.sh || fail=1
python3 scripts/check-links.py --nav || fail=1
scripts/check-public.sh >/dev/null 2>&1 || {
  printf '\n'
  scripts/check-public.sh 2>&1 | grep -A2 '^FAIL'
  fail=1
}

if [ "$fail" -ne 0 ]; then
  printf '\nPush refused. Fix the above, or use --no-verify to override.\n'
  exit 1
fi

exit 0
HOOK

chmod +x .git/hooks/pre-push
printf 'Installed .git/hooks/pre-push\n'
printf 'It runs check-freeze.sh, check-links.py and check-public.sh before every push.\n'
