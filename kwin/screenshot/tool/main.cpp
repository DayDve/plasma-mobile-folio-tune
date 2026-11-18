// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

// Takes one screenshot and exits. Reports on stdout: "captured" as soon as the picture is
// in memory, then "saved <path>".

#include <KConfigGroup>
#include <KSharedConfig>

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusUnixFileDescriptor>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>

#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>

using namespace Qt::StringLiterals;

// Returns an open device playing the effect: closing it would stop the vibration.
static int vibrate(int milliseconds)
{
    const auto group = KConfigGroup{KSharedConfig::openConfig(u"plasmamobilerc"_s), u"General"_s};
    if (!group.readEntry("vibrationsEnabled", true)) {
        return -1;
    }

    const auto devices = QDir(u"/dev/input"_s).entryList({u"event*"_s}, QDir::System);
    for (const QString &name : devices) {
        const int fd = open(QFile::encodeName(u"/dev/input/"_s + name).constData(), O_RDWR | O_CLOEXEC);
        if (fd < 0) {
            continue;
        }
        unsigned long features[(FF_MAX / (8 * sizeof(unsigned long))) + 1] = {};
        if (ioctl(fd, EVIOCGBIT(EV_FF, sizeof(features)), features) >= 0
            && (features[FF_RUMBLE / (8 * sizeof(unsigned long))] >> (FF_RUMBLE % (8 * sizeof(unsigned long)))) & 1) {
            ff_effect effect{};
            effect.type = FF_RUMBLE;
            effect.id = -1;
            effect.replay.length = milliseconds;
            effect.u.rumble.strong_magnitude = 0xffff;
            effect.u.rumble.weak_magnitude = 0xffff;
            if (ioctl(fd, EVIOCSFF, &effect) >= 0) {
                input_event play{};
                play.type = EV_FF;
                play.code = effect.id;
                play.value = 1;
                if (write(fd, &play, sizeof(play)) == sizeof(play)) {
                    return fd;
                }
            }
        }
        close(fd);
    }
    return -1;
}

static bool readAll(int fd, char *target, qsizetype size)
{
    while (size > 0) {
        const ssize_t got = read(fd, target, size);
        if (got <= 0) {
            return false;
        }
        target += got;
        size -= got;
    }
    return true;
}

static QImage capture()
{
    int fds[2];
    if (pipe2(fds, O_CLOEXEC) != 0) {
        return {};
    }

    auto call = QDBusMessage::createMethodCall(u"org.kde.KWin.ScreenShot2"_s,
                                               u"/org/kde/KWin/ScreenShot2"_s,
                                               u"org.kde.KWin.ScreenShot2"_s,
                                               u"CaptureActiveScreen"_s);
    const QVariantMap options{{u"native-resolution"_s, true}};
    call << options << QVariant::fromValue(QDBusUnixFileDescriptor(fds[1]));
    const QDBusMessage reply = QDBusConnection::sessionBus().call(call, QDBus::Block, 10000);
    close(fds[1]);

    QImage image;
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        fprintf(stderr, "capture failed: %s\n", qPrintable(reply.errorMessage()));
    } else {
        const QVariantMap info = qdbus_cast<QVariantMap>(reply.arguments().constFirst());
        const int stride = info.value(u"stride"_s).toInt();
        image = QImage(info.value(u"width"_s).toInt(), info.value(u"height"_s).toInt(),
                       QImage::Format(info.value(u"format"_s).toInt()));
        QByteArray line(stride, Qt::Uninitialized);
        for (int y = 0; !image.isNull() && y < image.height(); ++y) {
            if (!readAll(fds[0], line.data(), stride)) {
                image = QImage();
                break;
            }
            memcpy(image.scanLine(y), line.constData(), qMin<qsizetype>(stride, image.bytesPerLine()));
        }
    }
    close(fds[0]);
    return image;
}

static QString newPath()
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::PicturesLocation));
    if (!dir.mkpath(u"Screenshots"_s) || !dir.cd(u"Screenshots"_s)) {
        return {};
    }
    const QString stamp = QDateTime::currentDateTime().toString(u"yyyyMMdd_hhmmss"_s);
    QString path = dir.filePath(u"Screenshot_%1.png"_s.arg(stamp));
    for (int i = 2; QFile::exists(path); ++i) {
        path = dir.filePath(u"Screenshot_%1_%2.png"_s.arg(stamp).arg(i));
    }
    return path;
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTextStream out(stdout);

    const int vibrator = vibrate(50);

    const QImage image = capture();
    if (image.isNull()) {
        return 1;
    }
    out << "captured\n" << Qt::flush;

    // The sink is muted while the phone is set to silent, so this obeys that too.
    QProcess::startDetached(u"pw-play"_s, {u"/usr/share/sounds/freedesktop/stereo/screen-capture.oga"_s});

    const QString path = newPath();
    // little compression: the phone should not spend seconds on it
    if (path.isEmpty() || !image.convertToFormat(QImage::Format_RGB32).save(path, "PNG", 80)) {
        fprintf(stderr, "could not save the screenshot\n");
        return 1;
    }
    out << "saved " << path << '\n' << Qt::flush;

    if (vibrator >= 0) {
        close(vibrator);
    }
    return 0;
}
