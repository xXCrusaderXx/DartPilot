#include "dartpilot/tip_candidates/tip_candidates.hpp"

namespace dartpilot::tip_candidates
{
std::string_view moduleName () { return "tip_candidates"; }

std::optional<cv::Point2f> extremePoint (const cv::Mat& mask, const cv::Point2f& direction)
{
    std::optional<cv::Point2f> best;
    double best_projection = 0.0;
    for(int y = 0; y < mask.rows; ++y)
    {
        const auto* row = mask.ptr<std::uint8_t>(y);
        for(int x = 0; x < mask.cols; ++x)
        {
            if(row[x] == 0)
            {
                continue;
            }
            const double projection = static_cast<double>(direction.x) * x + static_cast<double>(direction.y) * y;
            if(!best || projection > best_projection)
            {
                best = cv::Point2f(static_cast<float>(x), static_cast<float>(y));
                best_projection = projection;
            }
        }
    }
    return best;
}
}  // namespace dartpilot::tip_candidates
