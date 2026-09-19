#!/usr/bin/env bash
# Load the kit's components under an OFFSCREEN Qt and assert what they say; every probe_*.qml
# beside this file runs. Qt comes from $QML_BIN / $QT_QML_DIR, else a qtdeclarative in the nix
# store; the design system from $LOGOS_DESIGN_SYSTEM_QML, else the store. Missing either SKIPS.
set -uo pipefail
cd "$(dirname "$0")"
if [ -z "${QML_BIN:-}" ]; then
    for c in /nix/store/*-qtdeclarative-*/bin/qml; do
        "$c" --version >/dev/null 2>&1 && QML_BIN="$c" && break
    done
fi
QML_BIN="${QML_BIN:-}"
QT_QML_DIR="${QT_QML_DIR:-${QML_BIN:+${QML_BIN%/bin/qml}/lib/qt-6/qml}}"
DS="${LOGOS_DESIGN_SYSTEM_QML:-$(ls -d /nix/store/*-logos-design-system-src/src/qml 2>/dev/null | head -1)}"
if [ -z "$QML_BIN" ] || [ ! -x "$QML_BIN" ] || [ -z "$QT_QML_DIR" ] || [ -z "$DS" ]; then
    echo "SKIP: no Qt Quick runtime or design system found (set QML_BIN, QT_QML_DIR,"
    echo "      LOGOS_DESIGN_SYSTEM_QML to run the probes)"
    exit 0
fi
rc=0
for probe in probe_*.qml; do
    echo "--- $probe"
    QT_QPA_PLATFORM=offscreen "$QML_BIN" -I "$QT_QML_DIR" -I "$DS" "$probe" 2>&1 \
        | grep -vE "does not support customization|Unsupported image format|Populating font|createPlatformOpenGLContext" \
        | sed 's/^qml: //'
    [ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
done
exit "$rc"
