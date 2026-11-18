# Build environment: the same Qt/KF6/Plasma versions as the target system (Debian forky).
FROM debian:forky-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      cmake g++ make extra-cmake-modules gettext \
      qt6-base-dev qt6-declarative-dev qt6-tools-dev libplasma-dev \
      libkf6i18n-dev libkf6service-dev libkf6kio-dev libkf6notifications-dev \
      libkf6windowsystem-dev libkf6jobwidgets-dev kwayland-dev \
      qt6-wayland-dev qt6-wayland-private-dev liblayershellqtinterface-dev \
      libkf6itemmodels-dev libkf6package-dev libkf6config-dev \
      qt6-sensors-dev libkscreen-dev libkf6kcmutils-dev \
      kwin-dev libdrm-dev libvulkan-dev libwayland-dev libxkbcommon-dev libgbm-dev pkgconf \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8
