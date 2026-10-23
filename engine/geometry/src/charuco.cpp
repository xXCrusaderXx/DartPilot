#include "dartpilot/geometry/charuco.hpp"

#include <algorithm>
#include <array>
#include <charconv>

#ifdef DARTPILOT_HAVE_CHARUCO
#include <opencv2/objdetect/charuco_detector.hpp>
#endif

namespace dartpilot::geometry
{
namespace
{
constexpr std::size_t kMinCorners = 6;
// Names of the cv::aruco::PredefinedDictionaryType values, in enum order
constexpr std::array<const char*, 17> kDictionaryNames = {"DICT_4X4_50",   "DICT_4X4_100",       "DICT_4X4_250",  "DICT_4X4_1000", "DICT_5X5_50",
                                                          "DICT_5X5_100",  "DICT_5X5_250",       "DICT_5X5_1000", "DICT_6X6_50",   "DICT_6X6_100",
                                                          "DICT_6X6_250",  "DICT_6X6_1000",      "DICT_7X7_50",   "DICT_7X7_100",  "DICT_7X7_250",
                                                          "DICT_7X7_1000", "DICT_ARUCO_ORIGINAL"};
}  // namespace

std::string CharucoTarget::describe () const
{
    const char* dictionary_name =
        dictionary >= 0 && static_cast<std::size_t>(dictionary) < kDictionaryNames.size() ? kDictionaryNames[dictionary] : "DICT_unknown";
    // to_chars ignores the C locale, so a German desktop still writes "0.70", not "0,70".
    std::array<char, 16> ratio{};
    const auto end = std::to_chars(ratio.data(), ratio.data() + ratio.size(), marker_to_square, std::chars_format::fixed, 2).ptr;
    return "charuco " + std::to_string(squares_x) + "x" + std::to_string(squares_y) + " " + dictionary_name + " marker " +
           std::string(ratio.data(), end);
}

std::string CharucoTarget::imageFileName () const
{
    std::string name = describe();
    std::replace(name.begin(), name.end(), ' ', '-');
    return name + ".png";
}

#ifdef DARTPILOT_HAVE_CHARUCO

bool charucoAvailable () { return true; }

struct CharucoFinder::Impl
{
    cv::aruco::CharucoBoard board;
    cv::aruco::CharucoDetector detector;
};

CharucoFinder::CharucoFinder (const CharucoTarget& target)
    : target_(target)
{
    // Square length 1: object points are in squares, which is enough for intrinsics.
    cv::aruco::CharucoBoard board(cv::Size(target.squares_x, target.squares_y), 1.0f, target.marker_to_square,
                                  cv::aruco::getPredefinedDictionary(target.dictionary));
    impl_ = std::make_unique<Impl>(Impl{board, cv::aruco::CharucoDetector(board)});
}

CharucoFinder::~CharucoFinder () = default;

std::optional<CalibrationView> CharucoFinder::detect (const cv::Mat& gray) const
{
    std::vector<cv::Point2f> corners;
    std::vector<int> ids;
    impl_->detector.detectBoard(gray, corners, ids);
    if(ids.size() < kMinCorners)
    {
        return std::nullopt;
    }
    CalibrationView view;
    view.ids = ids;
    view.image_points_px = corners;
    const auto& chessboard_corners = impl_->board.getChessboardCorners();
    for(const int id : ids)
    {
        view.object_points.push_back(chessboard_corners[id]);
    }
    return view;
}

cv::Mat CharucoFinder::patternImage (const cv::Size& size_px) const
{
    cv::Mat image;
    // A white margin of one square helps the marker detection at the image border.
    const int margin_px = std::min(size_px.width / (target_.squares_x + 2), size_px.height / (target_.squares_y + 2));
    impl_->board.generateImage(size_px, image, margin_px);
    return image;
}

#else

bool charucoAvailable () { return false; }

struct CharucoFinder::Impl
{
};

CharucoFinder::CharucoFinder (const CharucoTarget& target)
    : target_(target)
{
}

CharucoFinder::~CharucoFinder () = default;

std::optional<CalibrationView> CharucoFinder::detect (const cv::Mat&) const { return std::nullopt; }

cv::Mat CharucoFinder::patternImage (const cv::Size&) const { return {}; }

#endif
}  // namespace dartpilot::geometry
