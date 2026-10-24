#include <gtest/gtest.h>

#include <filesystem>
#include <random>
#include <string>

#include "SyntheticBoard.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/replay/diagnosis.hpp"
#include "dartpilot/session/session_writer.hpp"

using namespace dartpilot;

namespace
{
class TemporaryDirectory
{
   public:
    TemporaryDirectory ()
        : path_(std::filesystem::temp_directory_path() / ("dartpilot-diagnosis-test-" + std::to_string(std::random_device{}())))
    {
        std::filesystem::create_directories(path_);
    }
    ~TemporaryDirectory () { std::filesystem::remove_all(path_); }
    const std::filesystem::path& path () const { return path_; }

   private:
    std::filesystem::path path_;
};

const std::array<cv::Matx33d, 2> kViews = {synthetic_board::boardToImage(40.0, 600.0, 15.0), synthetic_board::boardToImage(45.0, 620.0, -20.0)};
constexpr std::int64_t kFrame_ns = 33'333'333;

std::vector<std::uint8_t> jpeg (const cv::Mat& image)
{
    std::vector<std::uint8_t> data;
    cv::imencode(".jpg", image, data, {cv::IMWRITE_JPEG_QUALITY, 95});
    return data;
}

// Moves an image by a fraction of a pixel and scales its brightness
cv::Mat altered (const cv::Mat& image, double shift_px, double gain)
{
    cv::Mat out;
    cv::warpAffine(image, out, cv::Matx23d(1, 0, shift_px, 0, 1, 0), image.size(), cv::INTER_LINEAR, cv::BORDER_REPLICATE);
    out.convertTo(out, CV_8UC3, gain);
    return out;
}

// The board refinement of both cameras from their own images, as the setup GUI would make it
geometry::StoredExtrinsics extrinsics ()
{
    std::vector<geometry::RefinementInput> inputs;
    for(std::size_t c = 0; c < kViews.size(); ++c)
    {
        const auto detection = geometry::detectBoard(synthetic_board::renderCameraImage(kViews[c], 1.0, 90));
        EXPECT_TRUE(detection);
        const auto twenty = geometry::sectorAt(*detection, synthetic_board::project(kViews[c], 0.0, 60.0));
        geometry::RefinementInput input;
        input.usb_port = c == 0 ? "1.2" : "1.3";
        input.correspondences = geometry::orientBoard(*detection, twenty.value_or(0));
        input.prior = geometry::boardOnlyPrior(cv::Size(1280, 720));
        inputs.push_back(input);
    }
    const auto refinement = geometry::refineBoardCameras(inputs);
    EXPECT_TRUE(refinement);
    return {"2026-10-24T11:00:00Z", *refinement, inputs};
}

// A test as a user records it: empty board, an object in the board, empty board again, separated by movement. Camera
// usb-1.3 drifts by a pixel and gets 12 % brighter, without saturating, by the second empty board, and loses every tenth frame.
std::filesystem::path writeTest (const std::filesystem::path& root)
{
    session::SessionInfo info;
    info.session_id = "20261024T120000Z-diag";
    info.created_utc = "2026-10-24T12:00:00Z";
    info.cameras.push_back({"usb-1.2", "1.2", "/dev/null", "Cam A", {}, false, {}, std::nullopt, std::nullopt});
    info.cameras.push_back({"usb-1.3", "1.3", "/dev/null", "Cam B", {}, false, {}, std::nullopt, std::nullopt});
    std::string error;
    auto writer = session::SessionWriter::create(root, info, error);
    EXPECT_TRUE(writer) << error;
    for(std::size_t c = 0; c < kViews.size(); ++c)
    {
        const cv::Mat board = synthetic_board::renderCameraImage(kViews[c], 1.0, 90);
        cv::Mat object = board.clone();
        const cv::Point2f tip = synthetic_board::project(kViews[c], 40.0, 70.0);
        cv::line(object, tip, tip + cv::Point2f(30, -170), cv::Scalar(50, 50, 50), 7, cv::LINE_AA);
        cv::Mat noise(board.size(), CV_8UC3);
        cv::RNG rng(static_cast<std::uint64_t>(c) + 1);
        const auto still = [&] (const cv::Mat& image) { return jpeg(image); };
        const std::vector<std::uint8_t> empty_a = still(board), dart = still(object);
        const std::vector<std::uint8_t> empty_b = still(c == 1 ? altered(board, 1.0, 1.12) : board);
        std::vector<std::vector<std::uint8_t>> frames;
        const auto moving = [&] (int count)
        {
            for(int i = 0; i < count; ++i)
            {
                rng.fill(noise, cv::RNG::UNIFORM, 0, 255);
                frames.push_back(jpeg(noise));
            }
        };
        for(int i = 0; i < 60; ++i)
        {
            frames.push_back(empty_a);
        }
        moving(8);
        for(int i = 0; i < 60; ++i)
        {
            frames.push_back(dart);
        }
        moving(8);
        for(int i = 0; i < 60; ++i)
        {
            frames.push_back(empty_b);
        }
        std::uint32_t sequence = 1;
        for(std::size_t i = 0; i < frames.size(); ++i, ++sequence)
        {
            if(c == 1 && i % 10 == 9)
            {
                ++sequence;
            }
            capture::Frame frame;
            frame.sequence = sequence;
            frame.exposure_ns = 1'000'000'000 + static_cast<std::int64_t>(i) * kFrame_ns + static_cast<std::int64_t>(c) * 5'000'000;
            frame.data = frames[i];
            writer->writeFrame(c, frame);
        }
    }
    writer->finish("2026-10-24T12:00:10Z", std::vector<capture::CaptureStats>(2));
    return writer->directory();
}

bool has (const replay::Diagnosis& diagnosis, const std::string& check, const std::string& camera, replay::Severity at_least)
{
    return std::any_of(diagnosis.findings.begin(), diagnosis.findings.end(), [&] (const replay::Finding& f)
                       { return f.check == check && f.camera == camera && static_cast<int>(f.severity) >= static_cast<int>(at_least); });
}
}  // namespace

TEST(Diagnosis, FindsTheStillPeriodsAndWhatChangedInThem)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeTest(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    const auto stored = extrinsics();
    const auto diagnosis = replay::diagnoseSession(*recorded, &stored, error);
    ASSERT_TRUE(diagnosis) << error;

    ASSERT_EQ(diagnosis->periods.size(), 3u);
    EXPECT_TRUE(diagnosis->periods[0].empty);
    EXPECT_FALSE(diagnosis->periods[1].empty);
    EXPECT_TRUE(diagnosis->periods[2].empty);
    EXPECT_EQ(diagnosis->periods[1].cameras[0].dart, "seen");
    // Both cameras check against their calibration on the empty boards.
    ASSERT_TRUE(diagnosis->periods[0].cameras[0].calibration_mm);
    EXPECT_LT(*diagnosis->periods[0].cameras[0].calibration_mm, 1.0);

    EXPECT_TRUE(has(*diagnosis, "drift", "usb-1.3", replay::Severity::Warning));
    EXPECT_FALSE(has(*diagnosis, "drift", "usb-1.2", replay::Severity::Info));
    EXPECT_TRUE(has(*diagnosis, "light", "usb-1.3", replay::Severity::Warning));
    EXPECT_TRUE(has(*diagnosis, "capture", "usb-1.3", replay::Severity::Warning));
    EXPECT_FALSE(has(*diagnosis, "capture", "usb-1.2", replay::Severity::Info));
    // Findings come most severe first, and every warning tells the user what to do.
    for(std::size_t i = 1; i < diagnosis->findings.size(); ++i)
    {
        EXPECT_GE(static_cast<int>(diagnosis->findings[i - 1].severity), static_cast<int>(diagnosis->findings[i].severity));
    }
    for(const auto& f : diagnosis->findings)
    {
        EXPECT_TRUE(f.severity == replay::Severity::Info || !f.hint.empty()) << f.message;
    }

    // The same session gives the same report; both forms are written.
    const auto again = replay::diagnoseSession(*recorded, &stored, error);
    EXPECT_EQ(replay::toJson(*diagnosis), replay::toJson(*again));
    EXPECT_NE(replay::toJson(*diagnosis).find("\"severity\": \"warning\""), std::string::npos);
    EXPECT_NE(replay::toMarkdown(*diagnosis).find("## Findings"), std::string::npos);
}

TEST(Diagnosis, WithoutCalibrationItSaysWhatWasNotChecked)
{
    TemporaryDirectory root;
    std::string error;
    const auto recorded = session::openSession(writeTest(root.path()), error);
    ASSERT_TRUE(recorded) << error;
    const auto diagnosis = replay::diagnoseSession(*recorded, nullptr, error);
    ASSERT_TRUE(diagnosis) << error;
    EXPECT_TRUE(has(*diagnosis, "calibration", "usb-1.2", replay::Severity::Warning));
    EXPECT_FALSE(diagnosis->periods[0].cameras[0].calibration_mm);
}
