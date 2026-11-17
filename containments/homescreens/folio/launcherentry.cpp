// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "launcherentry.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusServiceWatcher>
#include <QSet>

static const QString s_interface = QStringLiteral("com.canonical.Unity.LauncherEntry");

LauncherEntryBackend *LauncherEntryBackend::instance()
{
    static LauncherEntryBackend *s_instance = new LauncherEntryBackend;
    return s_instance;
}

LauncherEntryBackend::LauncherEntryBackend(QObject *parent)
    : QObject(parent)
    , m_watcher(new QDBusServiceWatcher(this))
{
    auto bus = QDBusConnection::sessionBus();

    // Some applications only publish when a launcher owns this name (as Unity's dock and the
    // Plasma task manager do). Fine if someone else already owns it: the signal is broadcast.
    bus.interface()->registerService(QStringLiteral("com.canonical.Unity"), QDBusConnectionInterface::DontQueueService);

    bus.connect(QString(), QString(), s_interface, QStringLiteral("Update"), this, SLOT(update(QString, QVariantMap)));

    m_watcher->setConnection(bus);
    m_watcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &LauncherEntryBackend::serviceUnregistered);
}

QString LauncherEntryBackend::normalize(QString id)
{
    if (id.startsWith(QLatin1String("application://"))) {
        id = id.mid(14);
    }
    if (id.endsWith(QLatin1String(".desktop"))) {
        id.chop(8);
    }
    return id;
}

LauncherEntryBackend::Entry LauncherEntryBackend::entry(const QString &desktopId) const
{
    return m_entries.value(desktopId);
}

int LauncherEntryBackend::notificationCount(const QString &desktopId) const
{
    return m_notificationCounts.value(desktopId);
}

void LauncherEntryBackend::setNotificationCounts(const QVariantMap &counts)
{
    QHash<QString, int> next;
    for (auto it = counts.cbegin(); it != counts.cend(); ++it) {
        const QString id = normalize(it.key());
        if (!id.isEmpty()) {
            next[id] += it.value().toInt();
        }
    }
    QSet<QString> changed;
    for (auto it = next.cbegin(); it != next.cend(); ++it) {
        if (m_notificationCounts.value(it.key()) != it.value()) {
            changed.insert(it.key());
        }
    }
    for (auto it = m_notificationCounts.cbegin(); it != m_notificationCounts.cend(); ++it) {
        if (!next.contains(it.key())) {
            changed.insert(it.key());
        }
    }
    m_notificationCounts = next;
    for (const QString &id : std::as_const(changed)) {
        Q_EMIT entryChanged(id);
    }
}

void LauncherEntryBackend::update(const QString &appUri, const QVariantMap &properties)
{
    const QString id = normalize(appUri);
    if (id.isEmpty()) {
        return;
    }

    // Updates are partial: keep what is not in this one
    Entry &e = m_entries[id];
    for (auto it = properties.cbegin(); it != properties.cend(); ++it) {
        const QString &key = it.key();
        if (key == QLatin1String("count")) {
            e.count = it.value().toLongLong();
        } else if (key == QLatin1String("count-visible")) {
            e.countVisible = it.value().toBool();
        } else if (key == QLatin1String("progress")) {
            e.progress = qBound(0.0, it.value().toDouble(), 1.0);
        } else if (key == QLatin1String("progress-visible")) {
            e.progressVisible = it.value().toBool();
        } else if (key == QLatin1String("urgent")) {
            e.urgent = it.value().toBool();
        }
    }

    if (calledFromDBus()) {
        const QString service = message().service();
        if (!service.isEmpty() && e.service != service) {
            e.service = service;
            m_watcher->addWatchedService(service);
        }
    }

    Q_EMIT entryChanged(id);
}

void LauncherEntryBackend::serviceUnregistered(const QString &service)
{
    m_watcher->removeWatchedService(service);
    for (auto it = m_entries.begin(); it != m_entries.end();) {
        if (it->service == service) {
            const QString id = it.key();
            it = m_entries.erase(it);
            Q_EMIT entryChanged(id);
        } else {
            ++it;
        }
    }
}

LauncherEntry::LauncherEntry(QObject *parent)
    : QObject(parent)
{
    connect(LauncherEntryBackend::instance(), &LauncherEntryBackend::entryChanged, this, [this](const QString &id) {
        if (id == m_id) {
            m_entry = LauncherEntryBackend::instance()->entry(m_id);
            m_notificationCount = LauncherEntryBackend::instance()->notificationCount(m_id);
            Q_EMIT changed();
        }
    });
}

QString LauncherEntry::storageId() const
{
    return m_storageId;
}

void LauncherEntry::setStorageId(const QString &storageId)
{
    if (m_storageId == storageId) {
        return;
    }
    m_storageId = storageId;
    m_id = LauncherEntryBackend::normalize(storageId);
    m_entry = LauncherEntryBackend::instance()->entry(m_id);
    m_notificationCount = LauncherEntryBackend::instance()->notificationCount(m_id);
    Q_EMIT storageIdChanged();
    Q_EMIT changed();
}

qint64 LauncherEntry::count() const
{
    return m_entry.count;
}

bool LauncherEntry::countVisible() const
{
    return m_entry.countVisible && m_entry.count > 0;
}

double LauncherEntry::progress() const
{
    return m_entry.progress;
}

bool LauncherEntry::progressVisible() const
{
    return m_entry.progressVisible;
}

bool LauncherEntry::urgent() const
{
    return m_entry.urgent;
}

int LauncherEntry::notificationCount() const
{
    return m_notificationCount;
}

qint64 LauncherEntry::badgeCount() const
{
    return countVisible() ? m_entry.count : m_notificationCount;
}

void LauncherNotificationCounts::update(const QVariantMap &counts)
{
    LauncherEntryBackend::instance()->setNotificationCounts(counts);
}
