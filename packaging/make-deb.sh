#!/bin/sh
# Build the plasma-mobile-folio-tune .deb (run inside the packaging/Dockerfile image,
# from the repository root):
#   packaging/make-deb.sh [VERSION]
# Contents:
#   - the Folio Tune homescreen plugin (its own ID, next to the stock Folio);
#   - the org.kde.plasma.private.mobileshell QML module with our fixes, in
#     /usr/lib/plasma-mobile-folio-tune/qml, put ahead of the system one by
#     QML_IMPORT_PATH from /etc/xdg/plasma-workspace/env;
#   - the navigation panel containment (org.kde.plasma.mobile.taskpanel) with a
#     button that hides the panel, in /usr/lib/plasma-mobile-folio-tune/plugins,
#     put ahead of the system one by QT_PLUGIN_PATH from the same file;
#   - the convergentwindows KWin script and the mobiletaskswitcher effect with
#     floating windows, in /usr/share/plasma-mobile-folio-tune/kwin, put ahead of
#     the system ones by XDG_DATA_DIRS from the same file.
# Both override parts of plasma-mobile and must match it exactly, so the
# package depends on that upstream version.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
UPSTREAM=$(sed -n 's/^set(PROJECT_VERSION "\(.*\)")/\1/p' "$ROOT/CMakeLists.txt")
VERSION=${1:-$UPSTREAM+mobile0}
NAME=plasma-mobile-folio-tune
ARCH=$(dpkg --print-architecture)
OUT=$ROOT/packaging/out
PKG=$OUT/pkg
BUILD=$OUT/build
rm -rf "$PKG" "$BUILD"
mkdir -p "$PKG/DEBIAN" "$BUILD"

# Folio Tune
cmake -Wno-dev -S "$ROOT/packaging" -B "$BUILD/foliotune" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD/foliotune" -j"$(nproc)"
DESTDIR=$PKG cmake --install "$BUILD/foliotune" >/dev/null

# Folio's translations under the new domain
ID=org.kde.plasma.mobile.homescreen.foliotune
for po in "$ROOT"/po/*/plasma_applet_org.kde.plasma.mobile.homescreen.folio.po; do
    lang=$(basename "$(dirname "$po")")
    mkdir -p "$PKG/usr/share/locale/$lang/LC_MESSAGES"
    msgfmt -o "$PKG/usr/share/locale/$lang/LC_MESSAGES/plasma_applet_$ID.mo" "$po"
done

# mobileshell module
cmake -Wno-dev -S "$ROOT/packaging/mobileshell" -B "$BUILD/mobileshell" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD/mobileshell" -j"$(nproc)"
DESTDIR=$BUILD/mobileshell-stage cmake --install "$BUILD/mobileshell" >/dev/null
SRCDIR=$(find "$BUILD/mobileshell-stage" -type d -path '*/qml/org/kde/plasma/private/mobileshell' | head -1)
[ -n "$SRCDIR" ] && [ -f "$SRCDIR/libmobileshellplugin.so" ] || { echo "the mobileshell module was not built"; exit 1; }
grep -q '^prefer :/' "$SRCDIR/qmldir" || { echo "no prefer in qmldir: wrong qmldir"; exit 1; }
QML=/usr/lib/$NAME/qml
mkdir -p "$PKG$QML/org/kde/plasma/private/mobileshell"
find "$SRCDIR" -maxdepth 1 -type f -exec cp {} "$PKG$QML/org/kde/plasma/private/mobileshell/" \;

# navigation panel containment
cmake -Wno-dev -S "$ROOT/packaging/taskpanel" -B "$BUILD/taskpanel" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD/taskpanel" -j"$(nproc)"
DESTDIR=$BUILD/taskpanel-stage cmake --install "$BUILD/taskpanel" >/dev/null
TP=$(find "$BUILD/taskpanel-stage" -name 'org.kde.plasma.mobile.taskpanel.so' | head -1)
[ -n "$TP" ] || { echo "the taskpanel containment was not built"; exit 1; }
PLUG=/usr/lib/$NAME/plugins
install -Dm644 "$TP" "$PKG$PLUG/plasma/applets/org.kde.plasma.mobile.taskpanel.so"

# Shell settings page with the screenshot options
cmake -Wno-dev -S "$ROOT/packaging/kcm" -B "$BUILD/kcm" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD/kcm" -j"$(nproc)"
DESTDIR=$BUILD/kcm-stage cmake --install "$BUILD/kcm" >/dev/null
KCM=$(find "$BUILD/kcm-stage" -name 'kcm_mobileshell.so' | head -1)
[ -n "$KCM" ] || { echo "the shell settings page was not built"; exit 1; }
install -Dm644 "$KCM" "$PKG$PLUG/plasma/kcms/systemsettings/kcm_mobileshell.so"

# Screenshots: KWin module, settings module, capture tool
cmake -Wno-dev -S "$ROOT/packaging/screenshot" -B "$BUILD/screenshot" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "$BUILD/screenshot" -j"$(nproc)"
DESTDIR=$PKG cmake --install "$BUILD/screenshot" >/dev/null
for po in "$ROOT"/po/*/plasma_mobile_screenshot.po; do
    lang=$(basename "$(dirname "$po")")
    mkdir -p "$PKG/usr/share/locale/$lang/LC_MESSAGES"
    msgfmt -o "$PKG/usr/share/locale/$lang/LC_MESSAGES/plasma_mobile_screenshot.mo" "$po"
done
find "$PKG" -name 'libscreenshotplugin.so' | grep -q . || { echo "the screenshot module was not built"; exit 1; }

# KWin script and task switcher effect
DATA=/usr/share/$NAME
mkdir -p "$PKG$DATA/kwin/scripts" "$PKG$DATA/kwin/effects"
cp -r "$ROOT/kwin/scripts/convergentwindows" "$PKG$DATA/kwin/scripts/"
cp -r "$ROOT/kwin/mobiletaskswitcher/package" "$PKG$DATA/kwin/effects/mobiletaskswitcher"

mkdir -p "$PKG/etc/xdg/plasma-workspace/env"
cat > "$PKG/etc/xdg/plasma-workspace/env/$NAME.sh" <<EOF
# $NAME: the mobileshell QML module and the navigation panel with fixes,
# ahead of the system ones
export QML_IMPORT_PATH=$QML\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}
export QT_PLUGIN_PATH=$PLUG\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}
export XDG_DATA_DIRS=$DATA:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
EOF

# Only the files of this package: drop anything else cmake --install brought along
find "$PKG" -name '*.cmake' -delete
find "$PKG" -type d -empty -delete
mkdir -p "$PKG/DEBIAN"

# The screenshot module uses KWin's internal interfaces: only the version it was built for.
KWIN=$(dpkg-query -W -f='${Version}' kwin-dev | sed 's/+b[0-9]*$//')

NEXT=$(echo "$UPSTREAM" | awk -F. '{print $1"."$2"."$3+1}')
SIZE=$(du -sk "$PKG" | cut -f1)
cat > "$PKG/DEBIAN/control" <<EOF
Package: $NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: DayDve <daydve@smbit.pro>
Installed-Size: $SIZE
Depends: plasma-mobile (>= $UPSTREAM), plasma-mobile (<< $NEXT~), kwin-wayland (>= $KWIN), kwin-wayland (<< $KWIN.0~~next), pipewire-bin, sound-theme-freedesktop
Section: kde
Priority: optional
Homepage: https://github.com/DayDve/plasma-mobile-folio-tune
Description: Folio Tune homescreen and Plasma Mobile shell fixes
 Folio Tune is the Folio homescreen under its own plugin ID with a compact
 favourites bar and launcher badges. Choose it in the homescreen settings.
 .
 Also ships the mobileshell QML module and the navigation panel of
 plasma-mobile $UPSTREAM with changes, loaded ahead of the system ones through
 QML_IMPORT_PATH and QT_PLUGIN_PATH: the action drawer marquee no longer
 animates while hidden, and a button on the navigation panel hides it until a
 swipe from the screen edge. The task switcher can make a window floating.
 Log out and back in after installing.
EOF
echo /etc/xdg/plasma-workspace/env/$NAME.sh > "$PKG/DEBIAN/conffiles"

dpkg-deb --root-owner-group -Zxz --build "$PKG" "$OUT/${NAME}_${VERSION}_$ARCH.deb"
dpkg-deb -c "$OUT/${NAME}_${VERSION}_$ARCH.deb"
