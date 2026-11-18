// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>

#include <Plasma/Applet>

#include "homescreen.h"

class HomeScreen;

class FolioSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

    Q_PROPERTY(int homeScreenRows READ homeScreenRows WRITE setHomeScreenRows NOTIFY homeScreenRowsChanged)
    Q_PROPERTY(int homeScreenColumns READ homeScreenColumns WRITE setHomeScreenColumns NOTIFY homeScreenColumnsChanged)
    Q_PROPERTY(bool showPagesAppLabels READ showPagesAppLabels WRITE setShowPagesAppLabels NOTIFY showPagesAppLabelsChanged)
    Q_PROPERTY(bool showFavouritesAppLabels READ showFavouritesAppLabels WRITE setShowFavouritesAppLabels NOTIFY showFavouritesAppLabelsChanged)
    Q_PROPERTY(bool lockLayout READ lockLayout WRITE setLockLayout NOTIFY lockLayoutChanged)
    Q_PROPERTY(int delegateIconSize READ delegateIconSize WRITE setDelegateIconSize NOTIFY delegateIconSizeChanged)
    Q_PROPERTY(bool showFavouritesBarBackground READ showFavouritesBarBackground WRITE setShowFavouritesBarBackground NOTIFY showFavouritesBarBackgroundChanged)
    Q_PROPERTY(bool favouritesBarFitToIcons READ favouritesBarFitToIcons WRITE setFavouritesBarFitToIcons NOTIFY favouritesBarFitToIconsChanged)
    Q_PROPERTY(int favouritesBarPadding READ favouritesBarPadding WRITE setFavouritesBarPadding NOTIFY favouritesBarPaddingChanged)
    Q_PROPERTY(
        FolioSettings::PageTransitionEffect pageTransitionEffect READ pageTransitionEffect WRITE setPageTransitionEffect NOTIFY pageTransitionEffectChanged)
    Q_PROPERTY(FolioSettings::WallpaperBlurEffect wallpaperBlurEffect READ wallpaperBlurEffect WRITE setWallpaperBlurEffect NOTIFY wallpaperBlurEffectChanged)
    Q_PROPERTY(bool doubleTapToLock READ doubleTapToLock WRITE setDoubleTapToLock NOTIFY doubleTapToLockChanged)
    // The navigation panel's button that hides it. Kept in plasmamobilerc rather than in the
    // homescreen's own config, because the navigation panel reads it.
    Q_PROPERTY(bool navigationPanelHideButton READ navigationPanelHideButton WRITE setNavigationPanelHideButton NOTIFY
                   navigationPanelHideButtonChanged)

public:
    FolioSettings(HomeScreen *parent = nullptr);

    // ensure that existing enum values are the same when modifying, since this value is saved
    enum PageTransitionEffect {
        SlideTransition = 0,
        CubeTransition = 1,
        FadeTransition = 2,
        StackTransition = 3,
        RotationTransition = 4,
    };
    Q_ENUM(PageTransitionEffect)

    enum WallpaperBlurEffect {
        None = 0,
        Simple = 1,
        Full = 2,
    };
    Q_ENUM(WallpaperBlurEffect)

    // JSON object
    QString favorites() const;
    void setFavorites(const QString &favoritesJson);

    // JSON object
    QString pages() const;
    void setPages(const QString &pagesJson);

    // number of rows and columns in the config for the homescreen
    // NOTE: use HomeScreenState.pageRows() instead in UI logic since we may have the rows and
    //       columns swapped (in landscape layouts)
    int homeScreenRows() const;
    void setHomeScreenRows(int homeScreenRows);

    int homeScreenColumns() const;
    void setHomeScreenColumns(int homeScreenColumns);

    bool showPagesAppLabels() const;
    void setShowPagesAppLabels(bool showPagesAppLabels);

    bool showFavouritesAppLabels() const;
    void setShowFavouritesAppLabels(bool showFavouritesAppLabels);

    bool lockLayout() const;
    void setLockLayout(bool lockLayout);

    int delegateIconSize() const;
    void setDelegateIconSize(int delegateIconSize);

    bool showFavouritesBarBackground() const;
    void setShowFavouritesBarBackground(bool showFavouritesBarBackground);

    // size the favourites bar to its icons (plus padding) instead of a fixed thickness
    bool favouritesBarFitToIcons() const;
    void setFavouritesBarFitToIcons(bool favouritesBarFitToIcons);

    // padding on each side of the icons when favouritesBarFitToIcons is enabled
    int favouritesBarPadding() const;
    void setFavouritesBarPadding(int favouritesBarPadding);

    PageTransitionEffect pageTransitionEffect() const;
    void setPageTransitionEffect(PageTransitionEffect pageTransitionEffect);

    WallpaperBlurEffect wallpaperBlurEffect() const;
    void setWallpaperBlurEffect(WallpaperBlurEffect wallpaperBlurEffect);

    bool doubleTapToLock() const;
    void setDoubleTapToLock(bool doubleTapToLock);

    bool navigationPanelHideButton() const;
    void setNavigationPanelHideButton(bool navigationPanelHideButton);

    Q_INVOKABLE void load();

    Q_INVOKABLE bool saveLayoutToFile(QString path);
    Q_INVOKABLE bool loadLayoutFromFile(QString path);

Q_SIGNALS:
    void homeScreenRowsChanged();
    void homeScreenColumnsChanged();
    void showPagesAppLabelsChanged();
    void showFavouritesAppLabelsChanged();
    void lockLayoutChanged();
    void delegateIconSizeChanged();
    void showFavouritesBarBackgroundChanged();
    void favouritesBarFitToIconsChanged();
    void favouritesBarPaddingChanged();
    void pageTransitionEffectChanged();
    void wallpaperBlurEffectChanged();
    void doubleTapToLockChanged();
    void navigationPanelHideButtonChanged();

private:
    void save();
    KConfigGroup generalConfigGroup() const;

    // Legacy
    void migrateConfigFromPlasma6_4();

    HomeScreen *m_homeScreen{nullptr};

    int m_homeScreenRows{5};
    int m_homeScreenColumns{4};
    bool m_showPagesAppLabels{false};
    bool m_showFavouritesAppLabels{false};
    bool m_lockLayout{false};
    qreal m_delegateIconSize{48};
    bool m_showFavouritesBarBackground{false};
    bool m_favouritesBarFitToIcons{false};
    int m_favouritesBarPadding{12};
    PageTransitionEffect m_pageTransitionEffect{SlideTransition};
    WallpaperBlurEffect m_wallpaperBlurEffect{Full};
    bool m_doubleTapToLock{false};
    bool m_navigationPanelHideButton{false};
};
