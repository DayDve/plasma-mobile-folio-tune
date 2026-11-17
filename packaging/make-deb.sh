#!/bin/sh
# Build the plasma-mobile-folio-tune .deb (run inside the packaging/Dockerfile image,
# from the repository root):
#   packaging/make-deb.sh [VERSION]
# Contents:
#   - the Folio Tune homescreen plugin (its own ID, next to the stock Folio);
#   - the org.kde.plasma.private.mobileshell QML module with our fixes, in
#     /usr/lib/plasma-mobile-folio-tune/qml, put ahead of the system one by
#     QML_IMPORT_PATH from /etc/xdg/plasma-workspace/env.
# The mobileshell module must match the installed plasma-mobile exactly, so the
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

mkdir -p "$PKG/etc/xdg/plasma-workspace/env"
cat > "$PKG/etc/xdg/plasma-workspace/env/$NAME.sh" <<EOF
# $NAME: the mobileshell QML module with fixes, ahead of the system one
export QML_IMPORT_PATH=$QML\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}
EOF

# Only the files of this package: drop anything else cmake --install brought along
find "$PKG" -name '*.cmake' -delete
find "$PKG" -type d -empty -delete
mkdir -p "$PKG/DEBIAN"

NEXT=$(echo "$UPSTREAM" | awk -F. '{print $1"."$2"."$3+1}')
SIZE=$(du -sk "$PKG" | cut -f1)
cat > "$PKG/DEBIAN/control" <<EOF
Package: $NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: DayDve <daydve@smbit.pro>
Installed-Size: $SIZE
Depends: plasma-mobile (>= $UPSTREAM), plasma-mobile (<< $NEXT~)
Section: kde
Priority: optional
Homepage: https://github.com/DayDve/plasma-mobile-folio-tune
Description: Folio Tune homescreen and Plasma Mobile shell fixes
 Folio Tune is the Folio homescreen under its own plugin ID with a compact
 favourites bar and launcher badges. Choose it in the homescreen settings.
 .
 Also ships the mobileshell QML module of plasma-mobile $UPSTREAM with fixes
 (the action drawer marquee no longer animates while hidden), loaded ahead of
 the system one through QML_IMPORT_PATH. Log out and back in after installing.
EOF
echo /etc/xdg/plasma-workspace/env/$NAME.sh > "$PKG/DEBIAN/conffiles"

dpkg-deb --root-owner-group -Zxz --build "$PKG" "$OUT/${NAME}_${VERSION}_$ARCH.deb"
dpkg-deb -c "$OUT/${NAME}_${VERSION}_$ARCH.deb"
