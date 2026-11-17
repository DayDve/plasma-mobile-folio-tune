#!/bin/sh
# The org.kde.plasma.private.mobileshell module with our fixes (sources: ../components/mobileshell)
# into ~/.local/lib/qt6/qml, ahead of the system one via QML_IMPORT_PATH.
# The source version must match the plasma-mobile package on the system.
#   ./build-mobileshell.sh            build and install
#   ./build-mobileshell.sh --restart  and restart plasmashell
#   ./build-mobileshell.sh --remove   remove it, back to the system module
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
IMG=folio-tune-build
QMLDIR=$HOME/.local/lib/qt6/qml
DEST=$QMLDIR/org/kde/plasma/private/mobileshell
ENV=$HOME/.config/plasma-workspace/env/mobileshell-tune.sh

restart() {
    systemctl --user kill --signal=SIGKILL plasma-plasmashell.service || true
    sleep 1
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user start plasma-plasmashell.service
}

if [ "${1:-}" = "--remove" ]; then
    rm -rf "$DEST" "$ENV"
    echo "Removed. Restart the session (QML_IMPORT_PATH is in the environment)."
    exit 0
fi

sys=$(dpkg-query -W -f='${Version}' plasma-mobile | cut -d- -f1)
src=$(sed -n 's/^set(PROJECT_VERSION "\(.*\)")/\1/p' "$ROOT/CMakeLists.txt")
[ "$sys" = "$src" ] || { echo "plasma-mobile on the system is $sys, the sources are $src: merge upstream first"; exit 1; }

docker image inspect $IMG >/dev/null 2>&1 || docker build -t $IMG "$HERE"
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/src" -w /src/packaging/mobileshell $IMG sh -ec '
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
    cmake --build build -j"$(nproc)"
    rm -rf stage
    DESTDIR=/src/packaging/mobileshell/stage cmake --install build >/dev/null'

# Install what cmake --install gives (qmldir with "prefer :/...": QML from the plugin's qrc, not from disk)
SRCDIR=$(find "$HERE/mobileshell/stage" -type d -path '*/qml/org/kde/plasma/private/mobileshell' | head -1)
[ -n "$SRCDIR" ] && [ -f "$SRCDIR/libmobileshellplugin.so" ] || { echo "the module was not built"; exit 1; }
grep -q '^prefer :/' "$SRCDIR/qmldir" || { echo "no prefer in qmldir: wrong qmldir"; exit 1; }
mkdir -p "$DEST"
for f in "$SRCDIR"/*; do
    [ -f "$f" ] || continue
    n=$(basename "$f")
    # via a temporary file and mv: overwriting a loaded .so crashes plasmashell
    install -m644 "$f" "$DEST/$n.new" && mv -f "$DEST/$n.new" "$DEST/$n"
done

mkdir -p "$(dirname "$ENV")"
cat > "$ENV" <<EOT
export QML_IMPORT_PATH=$QMLDIR\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}
EOT
echo "Installed: $DEST"
[ "${1:-}" = "--restart" ] && restart
exit 0
