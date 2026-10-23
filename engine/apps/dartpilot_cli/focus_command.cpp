#include "focus_command.hpp"

#include <algorithm>
#include <array>
#include <csignal>
#include <cstdio>
#include <iostream>
#include <optional>
#include <string>
#include <string_view>

#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/videoio.hpp>

#include "dartpilot/capture/focus.hpp"

namespace dartpilot::cli
{
namespace
{
constexpr int kGridSize = 3;
constexpr int kCellCount = kGridSize * kGridSize;
// Smooths sensor noise so the value can be read while turning the lens.
constexpr double kSmoothing = 0.3;
// The raw measure is a small ratio; scaled for display only.
constexpr double kDisplayScale = 100.0;
constexpr const char* kWindow = "dartpilot focus";
// Below this mean gray value sensor noise dominates the gradient energy and the measure no longer follows the focus.
constexpr double kMinMeanIntensity = 40.0;

// Set by Ctrl+C or SIGTERM, so the exposure is restored on those exits too.
volatile std::sig_atomic_t stop_requested = 0;

void requestStop (int) { stop_requested = 1; }

const char* const kUsage =
    "Usage: dartpilot focus --camera <device> [--exposure <value>]\n"
    "  --camera    V4L2 device, preferably /dev/v4l/by-path/...-video-index0\n"
    "  --exposure  fixed exposure_time_absolute (units of 100 us) while focusing; usually not needed, since the\n"
    "              sharpness measure is normalised by brightness and the reference cameras need automatic exposure\n"
    "Keys: click a cell to select it, r resets the peaks, q or Esc quits.\n";

struct Options
{
    std::string camera;
    std::optional<double> exposure;
};

std::optional<Options> parseOptions (int argc, char* argv[])
{
    Options options;
    for(int i = 0; i < argc; ++i)
    {
        const std::string_view arg = argv[i];
        if(arg == "--camera" && i + 1 < argc)
        {
            options.camera = argv[++i];
        }
        else if(arg == "--exposure" && i + 1 < argc)
        {
            try
            {
                options.exposure = std::stod(argv[++i]);
            }
            catch(const std::exception&)
            {
                return std::nullopt;
            }
        }
        else
        {
            return std::nullopt;
        }
    }
    if(options.camera.empty())
    {
        return std::nullopt;
    }
    return options;
}

cv::Rect cellRect (const cv::Size& size, int cell) { return capture::gridCell(size, kGridSize, cell); }

void putLabel (cv::Mat& image, const std::string& text, cv::Point origin, double scale, int thickness)
{
    int baseline = 0;
    const cv::Size text_size = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, scale, thickness, &baseline);
    const cv::Rect box(origin.x - 4, origin.y - text_size.height - 4, text_size.width + 8, text_size.height + baseline + 8);
    cv::rectangle(image, box & cv::Rect(cv::Point(), image.size()), cv::Scalar(0, 0, 0), cv::FILLED);
    cv::putText(image, text, origin, cv::FONT_HERSHEY_SIMPLEX, scale, cv::Scalar(255, 255, 255), thickness, cv::LINE_AA);
}

struct Selection
{
    int cell = kCellCount / 2;
    cv::Size frame_size;
};

void onMouse (int event, int x, int y, int, void* user_data)
{
    auto& selection = *static_cast<Selection*>(user_data);
    if(event != cv::EVENT_LBUTTONDOWN || selection.frame_size.width <= 0 || selection.frame_size.height <= 0)
    {
        return;
    }
    const int col = std::clamp(x * kGridSize / selection.frame_size.width, 0, kGridSize - 1);
    const int row = std::clamp(y * kGridSize / selection.frame_size.height, 0, kGridSize - 1);
    selection.cell = row * kGridSize + col;
}

std::string formatValue (double value)
{
    std::array<char, 32> buffer{};
    std::snprintf(buffer.data(), buffer.size(), "%.2f", value * kDisplayScale);
    return buffer.data();
}
}  // namespace

int runFocus (int argc, char* argv[])
{
    const auto options = parseOptions(argc, argv);
    if(!options)
    {
        std::cerr << kUsage;
        return 2;
    }

    cv::VideoCapture camera(options->camera, cv::CAP_V4L2);
    if(!camera.isOpened())
    {
        std::cerr << "Cannot open camera " << options->camera << '\n';
        return 1;
    }
    // Reference mode, see docs/hardware.md. The FOURCC must be set before the size.
    camera.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('M', 'J', 'P', 'G'));
    camera.set(cv::CAP_PROP_FRAME_WIDTH, 1280);
    camera.set(cv::CAP_PROP_FRAME_HEIGHT, 720);
    camera.set(cv::CAP_PROP_FPS, 30);

    // V4L2 values: 1 = manual, 3 = aperture priority. Restored on exit, because the camera keeps them until it is reconnected.
    const double previous_auto_exposure = camera.get(cv::CAP_PROP_AUTO_EXPOSURE);
    const double previous_exposure = camera.get(cv::CAP_PROP_EXPOSURE);
    if(options->exposure)
    {
        camera.set(cv::CAP_PROP_AUTO_EXPOSURE, 1);
        camera.set(cv::CAP_PROP_EXPOSURE, *options->exposure);
    }

    std::array<double, kCellCount> current{};
    std::array<double, kCellCount> peak{};
    std::array<bool, kCellCount> too_dark{};
    Selection selection;

    // Without the GUI_NORMAL flag the Qt backend adds a toolbar and opens the window far below the frame size.
    cv::namedWindow(kWindow, cv::WINDOW_NORMAL | cv::WINDOW_KEEPRATIO | cv::WINDOW_GUI_NORMAL);
    cv::resizeWindow(kWindow, 1280, 720);
    cv::setMouseCallback(kWindow, onMouse, &selection);

    std::signal(SIGINT, requestStop);
    std::signal(SIGTERM, requestStop);

    int exit_code = 0;
    cv::Mat frame, gray;
    while(stop_requested == 0)
    {
        if(!camera.read(frame) || frame.empty())
        {
            if(stop_requested != 0)
            {
                break;
            }
            std::cerr << "Camera " << options->camera << " delivered no frame\n";
            exit_code = 1;
            break;
        }
        selection.frame_size = frame.size();
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);

        for(int cell = 0; cell < kCellCount; ++cell)
        {
            const cv::Mat region = gray(cellRect(gray.size(), cell));
            too_dark[cell] = cv::mean(region)[0] < kMinMeanIntensity;
            if(too_dark[cell])
            {
                continue;
            }
            const double value = capture::sharpness(region);
            current[cell] = current[cell] > 0.0 ? (1.0 - kSmoothing) * current[cell] + kSmoothing * value : value;
            peak[cell] = std::max(peak[cell], current[cell]);
        }

        for(int cell = 0; cell < kCellCount; ++cell)
        {
            const cv::Rect rect = cellRect(frame.size(), cell);
            const bool is_selected = cell == selection.cell;
            cv::rectangle(frame, rect, is_selected ? cv::Scalar(0, 200, 255) : cv::Scalar(200, 200, 200), is_selected ? 3 : 1);
            const std::string label = too_dark[cell] ? "too dark" : formatValue(current[cell]) + " / " + formatValue(peak[cell]);
            putLabel(frame, label, rect.tl() + cv::Point(8, 24), 0.6, 1);
        }
        const cv::Rect sel = cellRect(frame.size(), selection.cell);
        if(!too_dark[selection.cell])
        {
            const double ratio = peak[selection.cell] > 0.0 ? current[selection.cell] / peak[selection.cell] : 0.0;
            putLabel(frame, formatValue(current[selection.cell]), sel.tl() + cv::Point(8, sel.height / 2 + 20), 1.6, 3);
            putLabel(frame, std::to_string(static_cast<int>(ratio * 100.0 + 0.5)) + "% of peak", sel.tl() + cv::Point(8, sel.height / 2 + 60), 0.8,
                     2);
        }

        if(cv::mean(gray)[0] < kMinMeanIntensity)
        {
            putLabel(frame, "Image too dark: raise --exposure or the light", cv::Point(8, frame.rows - 16), 0.8, 2);
        }

        cv::imshow(kWindow, frame);
        const int key = cv::waitKey(1);
        if(key == 'q' || key == 27 || cv::getWindowProperty(kWindow, cv::WND_PROP_VISIBLE) < 1)
        {
            break;
        }
        if(key == 'r')
        {
            peak = current;
        }
    }

    if(options->exposure)
    {
        camera.set(cv::CAP_PROP_EXPOSURE, previous_exposure);
        camera.set(cv::CAP_PROP_AUTO_EXPOSURE, previous_auto_exposure);
    }
    cv::destroyAllWindows();
    return exit_code;
}
}  // namespace dartpilot::cli
