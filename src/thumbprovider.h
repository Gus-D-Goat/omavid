#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>
#include <QVector>

// Serves the filmstrip thumbnails to QML. QML requests them by revision/index,
// e.g. Image { source: "image://thumbs/7/3" }.
class ThumbProvider : public QQuickImageProvider {
public:
    ThumbProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    void setImages(const QVector<QImage> &images);
    void setImage(int index, const QImage &image);

    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;

private:
    QVector<QImage> m_images;
    QMutex m_mutex;
};
