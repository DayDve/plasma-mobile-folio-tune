#!/bin/sh
# Build Folio Tune in Docker (dev packages live only in the image) and install it into ~/.local.
#   ./build.sh            build and install
#   ./build.sh --image    rebuild the image (after a Qt/Plasma update on the system)
#   ./build.sh --restart  restart plasmashell after installing
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")
IMG=folio-tune-build
ID=org.kde.plasma.mobile.homescreen.foliotune
PLUGDIR=$HOME/.local/lib/qt6/plugins

if [ "${1:-}" = "--image" ] || ! docker image inspect $IMG >/dev/null 2>&1; then
    docker build --pull -t $IMG "$HERE"
fi

docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/src" -w /src/packaging $IMG sh -ec '
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF >/dev/null
    cmake --build build -j"$(nproc)"'

SO=$(find "$HERE/build" -name "$ID.so" | head -1)
[ -n "$SO" ] || { echo "the plugin was not built"; exit 1; }
# Via a temporary file and mv: overwriting a .so loaded by plasmashell crashes it
DEST=$PLUGDIR/plasma/applets/$ID.so
install -Dm644 "$SO" "$DEST.new" && mv -f "$DEST.new" "$DEST"

# Folio's translation under the new domain
for mo in /usr/share/locale/*/LC_MESSAGES/plasma_applet_org.kde.plasma.mobile.homescreen.folio.mo; do
    [ -f "$mo" ] || continue
    lang=$(basename "$(dirname "$(dirname "$mo")")")
    install -Dm644 "$mo" "$HOME/.local/share/locale/$lang/LC_MESSAGES/plasma_applet_$ID.mo"
done

# plasmashell has to see ~/.local/lib/qt6/plugins
ENV=$HOME/.config/plasma-workspace/env/foliotune.sh
mkdir -p "$(dirname "$ENV")"
cat > "$ENV" <<EOF
export QT_PLUGIN_PATH=$PLUGDIR\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}
EOF

echo "Installed: $DEST"
if [ "${1:-}" = "--restart" ] || [ "${2:-}" = "--restart" ]; then
    # a regular stop of plasmashell with this plugin ends in drkonqi, so kill it
    systemctl --user kill --signal=SIGKILL plasma-plasmashell.service || true
    sleep 1
    systemctl --user reset-failed plasma-plasmashell.service 2>/dev/null || true
    systemctl --user start plasma-plasmashell.service
fi
