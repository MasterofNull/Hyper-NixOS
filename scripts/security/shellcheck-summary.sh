#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

find "$repo_root" -name '*.sh' -print0 | xargs -0 shellcheck -f gcc 2>/dev/null > "$tmp_file" || true

awk '
BEGIN { errors=0; warnings=0; notes=0 }
/: error: / { errors++ }
/: warning: / { warnings++ }
/: note: / { notes++ }
END {
  printf("errors=%d\nwarnings=%d\nnotes=%d\ntotal=%d\n", errors, warnings, notes, errors + warnings + notes)
}
' "$tmp_file"

echo "TOP_CODES"
python3 - "$tmp_file" <<'PY'
import collections
import re
import sys

path = sys.argv[1]
pattern = re.compile(r"^(.*?):\d+:\d+: (warning|error|note): .* \[(SC\d+)\]$")
counts = collections.Counter()

with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        match = pattern.match(line.rstrip())
        if match:
            counts[(match.group(2), match.group(3))] += 1

for (severity, code), count in counts.most_common(15):
    print(f"{severity}\t{code}\t{count}")
PY
