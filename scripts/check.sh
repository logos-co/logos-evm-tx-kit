#!/usr/bin/env bash
# check.sh <app repo>: fail unless the app's src/qml/kit is exactly this kit, vendored at the
# commit its VERSION names. Run from a checkout of the kit at that commit.
set -euo pipefail
kit=$(cd "$(dirname "$0")/.." && pwd)
app=$(cd "${1:?usage: check.sh <app repo>}" && pwd)
want=$(cat "$app/src/qml/kit/VERSION")
have=$(git -C "$kit" rev-parse HEAD)
[ "$want" = "$have" ] || { echo "the app pins $want; this kit checkout is $have"; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$app/metadata.json" "$tmp/"
"$kit/scripts/vendor.sh" "$tmp" "$want" > /dev/null
diff -r "$tmp/src/qml/kit" "$app/src/qml/kit" && echo "src/qml/kit is logos-evm-tx-kit $want"
