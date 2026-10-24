#include "preview_sources.hpp"

#include <chrono>
#include <cmath>
#include <string>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/capture/v4l2_frame_source.hpp"
#include "dartpilot/scoring/score.hpp"

namespace dartpilot::cli
{
namespace
{
constexpr std::chrono::milliseconds kStatusInterval{1000};
// Simulated cameras look at the board from three sides; each image is the board squeezed along its view.
constexpr double kSimulatedFps = 10.0;
constexpr int kSimulatedWidth = 640;
constexpr int kSimulatedHeight = 360;
}  // namespace

std::vector<std::uint8_t> scaleJpeg (const std::vector<std::uint8_t>& jpeg, int max_width, int& width, int& height)
{
    const cv::Mat image = cv::imdecode(jpeg, cv::IMREAD_COLOR);
    if(image.empty() || max_width <= 0)
    {
        return {};
    }
    const double scale = std::min(1.0, static_cast<double>(max_width) / image.cols);
    cv::Mat scaled;
    cv::resize(image, scaled, cv::Size(), scale, scale, cv::INTER_AREA);
    std::vector<std::uint8_t> out;
    cv::imencode(".jpg", scaled, out, {cv::IMWRITE_JPEG_QUALITY, 80});
    width = scaled.cols;
    height = scaled.rows;
    return out;
}

CameraPreviews::CameraPreviews (api::Server& server)
    : server_(server)
{
}

CameraPreviews::~CameraPreviews () { stop(); }

std::vector<capture::CameraDevice> CameraPreviews::start ()
{
    for(const auto& device : capture::findCameras())
    {
        auto capture = std::make_unique<capture::CaptureThread>(std::make_unique<capture::V4l2FrameSource>(device), 4);
        if(capture->start())
        {
            devices_.push_back(device);
            captures_.push_back(std::move(capture));
            latest_.emplace_back();
            latest_sequence_.push_back(0);
        }
    }
    stop_ = false;
    thread_ = std::thread([this] { run(); });
    return devices_;
}

void CameraPreviews::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
    for(auto& capture : captures_)
    {
        capture->stop();
    }
}

bool CameraPreviews::latest (std::size_t camera, std::vector<std::uint8_t>& jpeg, std::uint32_t& sequence) const
{
    std::lock_guard lock(latest_mutex_);
    if(camera >= latest_.size() || latest_[camera].empty())
    {
        return false;
    }
    jpeg = latest_[camera];
    sequence = latest_sequence_[camera];
    return true;
}

void CameraPreviews::run ()
{
    auto next_status = std::chrono::steady_clock::now();
    while(!stop_)
    {
        bool any = false;
        for(std::size_t i = 0; i < captures_.size(); ++i)
        {
            const std::string id = "usb-" + devices_[i].usb_port;
            // Draining the ring keeps the newest frame at hand even when nobody watches.
            while(auto frame = captures_[i]->frames().tryPop())
            {
                any = true;
                {
                    std::lock_guard lock(latest_mutex_);
                    latest_[i] = frame->data;
                    latest_sequence_[i] = frame->sequence;
                }
                if(!server_.wantsPreview(id))
                {
                    continue;
                }
                const capture::StreamSettings stream;
                api::PreviewHeader header{id, frame->sequence, frame->exposure_ns, stream.width, stream.height};
                server_.publishPreview(header, frame->data);
            }
        }
        if(std::chrono::steady_clock::now() >= next_status)
        {
            for(std::size_t i = 0; i < captures_.size(); ++i)
            {
                const auto stats = captures_[i]->stats();
                const std::string state = !stats.running ? "lost" : stats.lost_frames > 0 || stats.overflow_drops > 0 ? "degraded" : "ok";
                // Mean brightness of the newest frame at an eighth of its size, once per status (ADR 0002)
                double brightness = -1.0;
                std::vector<std::uint8_t> jpeg;
                std::uint32_t sequence = 0;
                if(latest(i, jpeg, sequence))
                {
                    const cv::Mat gray = cv::imdecode(jpeg, cv::IMREAD_REDUCED_GRAYSCALE_8);
                    brightness = gray.empty() ? -1.0 : cv::mean(gray)[0];
                }
                server_.publishCameraStatus({"usb-" + devices_[i].usb_port, state, stats.effective_fps, stats.lost_frames, stats.overflow_drops,
                                             brightness, stats.latency_ms});
            }
            next_status += kStatusInterval;
        }
        if(!any)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
        }
    }
}

SimulatedPreviews::SimulatedPreviews (api::Server& server, std::vector<std::string> cameras)
    : server_(server)
    , cameras_(std::move(cameras))
{
}

SimulatedPreviews::~SimulatedPreviews () { stop(); }

void SimulatedPreviews::start ()
{
    stop_ = false;
    thread_ = std::thread([this] { run(); });
}

void SimulatedPreviews::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

void SimulatedPreviews::run ()
{
    std::uint32_t sequence = 0;
    const auto interval = std::chrono::duration<double>(1.0 / kSimulatedFps);
    auto next = std::chrono::steady_clock::now();
    while(!stop_)
    {
        ++sequence;
        const auto points = server_.visitPoints();
        for(std::size_t c = 0; c < cameras_.size(); ++c)
        {
            if(!server_.wantsPreview(cameras_[c]))
            {
                continue;
            }
            cv::Mat image(kSimulatedHeight, kSimulatedWidth, CV_8UC3, cv::Scalar(30, 30, 30));
            // Each camera sees the board from another side: rotate by 120 degrees and squeeze vertically.
            const double view = c * 2.0 * 3.14159265358979323846 / 3.0;
            const cv::Point2d centre(kSimulatedWidth / 2.0, kSimulatedHeight / 2.0);
            const double scale = 0.9;
            auto project = [&] (double x_mm, double y_mm)
            {
                const double xr = x_mm * std::cos(view) - y_mm * std::sin(view);
                const double yr = x_mm * std::sin(view) + y_mm * std::cos(view);
                return cv::Point(static_cast<int>(centre.x + scale * xr), static_cast<int>(centre.y - 0.55 * scale * yr));
            };
            const scoring::BoardGeometry geometry;
            for(const double radius : {geometry.double_outer_radius_mm, geometry.double_inner_radius_mm, geometry.triple_outer_radius_mm,
                                       geometry.triple_inner_radius_mm, geometry.outer_bull_radius_mm, geometry.bull_radius_mm})
            {
                std::vector<cv::Point> ring;
                for(int a = 0; a <= 72; ++a)
                {
                    const double phi = a * 5.0 * 3.14159265358979323846 / 180.0;
                    ring.push_back(project(radius * std::cos(phi), radius * std::sin(phi)));
                }
                cv::polylines(image, ring, false, cv::Scalar(200, 200, 200), 1, cv::LINE_AA);
            }
            for(int k = 0; k < 20; ++k)
            {
                const double phi = (9.0 + 18.0 * k) * 3.14159265358979323846 / 180.0;
                cv::line(image, project(geometry.outer_bull_radius_mm * std::cos(phi), geometry.outer_bull_radius_mm * std::sin(phi)),
                         project(geometry.double_outer_radius_mm * std::cos(phi), geometry.double_outer_radius_mm * std::sin(phi)),
                         cv::Scalar(120, 120, 120), 1, cv::LINE_AA);
            }
            for(const auto& point : points)
            {
                const cv::Point tip = project(point.x_mm, point.y_mm);
                cv::line(image, tip, tip + cv::Point(0, -40), cv::Scalar(60, 200, 60), 3, cv::LINE_AA);
                cv::circle(image, tip, 4, cv::Scalar(40, 40, 230), cv::FILLED, cv::LINE_AA);
            }
            cv::putText(image, cameras_[c] + " (simulated)", cv::Point(12, 26), cv::FONT_HERSHEY_SIMPLEX, 0.6, cv::Scalar(230, 230, 230), 1,
                        cv::LINE_AA);
            std::vector<std::uint8_t> jpeg;
            cv::imencode(".jpg", image, jpeg, {cv::IMWRITE_JPEG_QUALITY, 80});
            const auto exposure_ns =
                std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
            server_.publishPreview({cameras_[c], sequence, exposure_ns, kSimulatedWidth, kSimulatedHeight}, jpeg);
        }
        next += std::chrono::duration_cast<std::chrono::steady_clock::duration>(interval);
        std::this_thread::sleep_until(next);
    }
}
}  // namespace dartpilot::cli
