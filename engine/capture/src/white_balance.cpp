#include "dartpilot/capture/white_balance.hpp"

#include <filesystem>

#include <opencv2/core.hpp>

namespace dartpilot::capture
{
std::string whiteBalanceFileName (std::string_view usb_port) { return "white-balance-usb-" + std::string(usb_port) + ".yml"; }

int storedWhiteBalance (const std::string& path)
{
    if(!std::filesystem::exists(path))
    {
        return kDefaultWhiteBalance_K;
    }
    try
    {
        cv::FileStorage file(path, cv::FileStorage::READ);
        const int kelvin = file.isOpened() ? static_cast<int>(file["white_balance_K"]) : 0;
        return kelvin >= kMinWhiteBalance_K && kelvin <= kMaxWhiteBalance_K + kWhiteBalanceStep_K ? kelvin : kDefaultWhiteBalance_K;
    }
    catch(const cv::Exception&)
    {
        return kDefaultWhiteBalance_K;
    }
}

std::optional<int> chooseWhiteBalance (const std::vector<std::pair<int, bool>>& found_at_K)
{
    std::size_t best_first = 0, best_length = 0;
    for(std::size_t i = 0; i < found_at_K.size();)
    {
        if(!found_at_K[i].second)
        {
            ++i;
            continue;
        }
        std::size_t j = i;
        while(j < found_at_K.size() && found_at_K[j].second)
        {
            ++j;
        }
        if(j - i > best_length)
        {
            best_first = i;
            best_length = j - i;
        }
        i = j;
    }
    if(best_length == 0)
    {
        return std::nullopt;
    }
    const int low = found_at_K[best_first].first, high = found_at_K[best_first + best_length - 1].first;
    // Rounded down to a step, so the result is one of the temperatures tried
    const int middle = (low + high) / 2;
    return low + (middle - low) / kWhiteBalanceStep_K * kWhiteBalanceStep_K;
}

bool saveWhiteBalance (const std::string& path, int white_balance_K, const std::vector<std::pair<int, bool>>& found_at_K)
{
    try
    {
        cv::FileStorage file(path, cv::FileStorage::WRITE);
        if(!file.isOpened())
        {
            return false;
        }
        file << "format" << "dartpilot-white-balance-1";
        file << "white_balance_K" << white_balance_K;
        file << "board_found" << "[";
        for(const auto& [kelvin, found] : found_at_K)
        {
            file << "{" << "K" << kelvin << "found" << (found ? 1 : 0) << "}";
        }
        file << "]";
        return true;
    }
    catch(const cv::Exception&)
    {
        return false;
    }
}
}  // namespace dartpilot::capture
