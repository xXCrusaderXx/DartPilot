#include "dartpilot/capture/uvc_metadata.hpp"

#include <cstring>

namespace dartpilot::capture
{
namespace
{
// struct uvc_meta_buf from <linux/uvcvideo.h>: u64 ns, u16 sof, then the payload header itself,
// starting with bHeaderLength and bmHeaderInfo.
constexpr std::size_t kBlockPrefix = 10;
constexpr std::uint8_t kHasPts = 0x04;
constexpr std::uint8_t kHasScr = 0x08;

template <typename T>
T readLittleEndian (const std::uint8_t* data)
{
    T value{};
    std::memcpy(&value, data, sizeof(T));
    return value;
}
}  // namespace

std::vector<UvcHeaderSample> parseUvcMetadata (std::span<const std::uint8_t> buffer)
{
    std::vector<UvcHeaderSample> samples;
    std::size_t offset = 0;
    while(offset + kBlockPrefix + 2 <= buffer.size())
    {
        const std::uint8_t* block = buffer.data() + offset;
        const std::uint8_t header_length = block[kBlockPrefix];
        const std::size_t block_size = kBlockPrefix + (header_length < 2 ? 2 : header_length);
        if(offset + block_size > buffer.size())
        {
            break;
        }
        UvcHeaderSample sample;
        sample.host_ns = static_cast<std::int64_t>(readLittleEndian<std::uint64_t>(block));
        sample.usb_sof = readLittleEndian<std::uint16_t>(block + 8);
        sample.header_flags = block[kBlockPrefix + 1];
        const std::uint8_t* field = block + kBlockPrefix + 2;
        const std::uint8_t* header_end = block + kBlockPrefix + header_length;
        if((sample.header_flags & kHasPts) != 0 && field + 4 <= header_end)
        {
            sample.pts = readLittleEndian<std::uint32_t>(field);
            field += 4;
        }
        if((sample.header_flags & kHasScr) != 0 && field + 6 <= header_end)
        {
            sample.scr_stc = readLittleEndian<std::uint32_t>(field);
            sample.scr_sof = readLittleEndian<std::uint16_t>(field + 4) & 0x7ff;
        }
        samples.push_back(sample);
        offset += block_size;
    }
    return samples;
}

std::optional<std::uint32_t> framePts (const std::vector<UvcHeaderSample>& samples)
{
    for(const auto& sample : samples)
    {
        if(sample.pts && *sample.pts != 0)
        {
            return sample.pts;
        }
    }
    return std::nullopt;
}
}  // namespace dartpilot::capture
