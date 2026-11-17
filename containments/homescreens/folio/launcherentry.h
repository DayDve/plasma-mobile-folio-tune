// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QDBusContext>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <qqmlregistration.h>

class QDBusServiceWatcher;

/**
 * Badges and progress that applications publish for their launcher with the
 * com.canonical.Unity.LauncherEntry D-Bus API (Telegram, Firefox and Chromium
 * downloads, ...), like the Plasma task manager shows them on the desktop.
 *
 * One shared backend listens to the Update signal; a LauncherEntry object per icon
 * exposes the values for its application.
 */
class LauncherEntryBackend : public QObject, protected QDBusContext
{
    Q_OBJECT

public:
    struct Entry {
        qint64 count = 0;
        bool countVisible = false;
        double progress = 0;
        bool progressVisible = false;
        bool urgent = false;
        QString service; // sender, to drop the entry when the application quits
    };

    static LauncherEntryBackend *instance();

    Entry entry(const QString &desktopId) const;
    int notificationCount(const QString &desktopId) const;
    void setNotificationCounts(const QVariantMap &counts);

    /** "application://org.telegram.desktop.desktop", "org.telegram.desktop.desktop" -> "org.telegram.desktop" */
    static QString normalize(QString id);

Q_SIGNALS:
    void entryChanged(const QString &desktopId);

private Q_SLOTS:
    void update(const QString &appUri, const QVariantMap &properties);
    void serviceUnregistered(const QString &service);

private:
    explicit LauncherEntryBackend(QObject *parent = nullptr);

    QHash<QString, Entry> m_entries;
    QHash<QString, int> m_notificationCounts;
    QDBusServiceWatcher *m_watcher;
};

class LauncherEntry : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    /** Desktop file id of the application, as FolioApplication::storageId */
    Q_PROPERTY(QString storageId READ storageId WRITE setStorageId NOTIFY storageIdChanged)

    Q_PROPERTY(qint64 count READ count NOTIFY changed)
    Q_PROPERTY(bool countVisible READ countVisible NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(bool progressVisible READ progressVisible NOTIFY changed)
    Q_PROPERTY(bool urgent READ urgent NOTIFY changed)
    /** Notifications of the application in the shade (for apps without a LauncherEntry count) */
    Q_PROPERTY(int notificationCount READ notificationCount NOTIFY changed)
    /** What the badge shows: the application's own count, else its notifications */
    Q_PROPERTY(qint64 badgeCount READ badgeCount NOTIFY changed)

public:
    explicit LauncherEntry(QObject *parent = nullptr);

    QString storageId() const;
    void setStorageId(const QString &storageId);

    qint64 count() const;
    bool countVisible() const;
    double progress() const;
    bool progressVisible() const;
    bool urgent() const;
    int notificationCount() const;
    qint64 badgeCount() const;

Q_SIGNALS:
    void storageIdChanged();
    void changed();

private:
    QString m_storageId;
    QString m_id;
    LauncherEntryBackend::Entry m_entry;
    int m_notificationCount = 0;
};

/**
 * Feeds the notification counts per application (desktop entry -> count) from the one
 * notification model of the home screen (main.qml) to the backend.
 */
class LauncherNotificationCounts : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    using QObject::QObject;
    Q_INVOKABLE void update(const QVariantMap &counts);
};
