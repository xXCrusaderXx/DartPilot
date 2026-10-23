#include "pattern_image_provider.hpp"

#include <algorithm>

#include <opencv2/imgproc.hpp>
#include <opencv2/objdetect.hpp>

#include "calibration_paths.hpp"
#include "dartpilot/geometry/charuco.hpp"

namespace dartpilot::setup
{
PatternImageProvider::PatternImageProvider ()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

namespace
{
QImage qrCode (const QString& text, int size_px)
{
    cv::Mat modules;
    cv::QRCodeEncoder::create()->encode(text.toStdString(), modules);
    if(modules.empty())
    {
        return {};
    }
    // One pixel per module from the encoder; scaled up without smoothing, with a white quiet zone of four modules.
    cv::Mat padded;
    cv::copyMakeBorder(modules, padded, 4, 4, 4, 4, cv::BORDER_CONSTANT, cv::Scalar(255));
    cv::Mat scaled;
    const int scale = std::max(1, size_px / padded.cols);
    cv::resize(padded, scaled, cv::Size(), scale, scale, cv::INTER_NEAREST);
    return QImage(scaled.data, scaled.cols, scaled.rows, static_cast<qsizetype>(scaled.step), QImage::Format_Grayscale8).copy();
}
}  // namespace

QImage PatternImageProvider::requestImage (const QString& id, QSize* size, const QSize& requested_size)
{
    const geometry::CharucoTarget target =
        id.endsWith(QLatin1String("/phone")) ? geometry::CharucoTarget::phone() : geometry::CharucoTarget::tablet();
    if(id.startsWith(QLatin1String("qr")))
    {
        const QImage image = qrCode(patternDownloadUrl(target), requested_size.width() > 0 ? requested_size.width() : 300);
        if(size)
        {
            *size = image.size();
        }
        return image;
    }
    // Keep the target's aspect ratio; the width decides.
    const int width = requested_size.width() > 0 ? requested_size.width() : 1000;
    const int height = width * target.squares_y / target.squares_x;
    const cv::Mat pattern = geometry::CharucoFinder(target).patternImage(cv::Size(width, height));
    QImage image;
    if(pattern.empty())
    {
        image = QImage(width, height, QImage::Format_Grayscale8);
        image.fill(Qt::lightGray);
    }
    else
    {
        image = QImage(pattern.data, pattern.cols, pattern.rows, static_cast<qsizetype>(pattern.step), QImage::Format_Grayscale8).copy();
    }
    if(size)
    {
        *size = image.size();
    }
    return image;
}
}  // namespace dartpilot::setup
