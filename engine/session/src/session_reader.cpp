#include "dartpilot/session/session_reader.hpp"

#include <charconv>
#include <sstream>
#include <string_view>

#include "dartpilot/session/json.hpp"

namespace dartpilot::session
{
namespace
{
std::vector<std::string_view> splitCsv (std::string_view line)
{
    std::vector<std::string_view> fields;
    std::size_t start = 0;
    while(true)
    {
        const std::size_t comma = line.find(',', start);
        fields.push_back(line.substr(start, comma == std::string_view::npos ? std::string_view::npos : comma - start));
        if(comma == std::string_view::npos)
        {
            return fields;
        }
        start = comma + 1;
    }
}

template <typename T>
bool parseNumber (std::string_view text, T& value)
{
    const auto [end, ec] = std::from_chars(text.data(), text.data() + text.size(), value);
    return ec == std::errc() && end == text.data() + text.size();
}

std::optional<FileReference> fileReference (const JsonValue* value)
{
    if(!value || value->type != JsonValue::Type::Object)
    {
        return std::nullopt;
    }
    return FileReference{value->string("file"), value->string("sha256")};
}

// The columns are found by name, so columns added at the end by a later writer are ignored (docs/replay-format.md).
bool readFrameIndex (const std::filesystem::path& path, std::uint64_t data_size, std::vector<FrameIndex>& frames, std::string& error)
{
    std::ifstream in(path);
    std::string header;
    if(!in || !std::getline(in, header))
    {
        error = "Cannot read " + path.string();
        return false;
    }
    const auto names = splitCsv(header);
    const auto column = [&] (std::string_view name) -> int
    {
        for(std::size_t i = 0; i < names.size(); ++i)
        {
            if(names[i] == name)
            {
                return static_cast<int>(i);
            }
        }
        return -1;
    };
    const int sequence = column("sequence"), exposure = column("exposure_ns"), source = column("timestamp_source"), driver = column("driver_ns"),
              arrival = column("arrival_ns"), pts = column("pts"), offset = column("offset"), size = column("size");
    if(sequence < 0 || exposure < 0 || offset < 0 || size < 0)
    {
        error = path.string() + " lacks a required column";
        return false;
    }
    std::string line;
    int line_number = 1;
    while(std::getline(in, line))
    {
        ++line_number;
        if(line.empty())
        {
            continue;
        }
        const auto fields = splitCsv(line);
        const auto field = [&] (int index) { return index >= 0 && index < static_cast<int>(fields.size()) ? fields[index] : std::string_view(); };
        FrameIndex frame;
        bool ok = parseNumber(field(sequence), frame.sequence) && parseNumber(field(exposure), frame.exposure_ns) &&
                  parseNumber(field(offset), frame.offset) && parseNumber(field(size), frame.size);
        frame.timestamp_source = std::string(field(source));
        ok = ok && (driver < 0 || parseNumber(field(driver), frame.driver_ns)) && (arrival < 0 || parseNumber(field(arrival), frame.arrival_ns));
        if(!field(pts).empty())
        {
            std::uint32_t value = 0;
            ok = ok && parseNumber(field(pts), value);
            frame.pts = value;
        }
        if(!ok)
        {
            error = path.string() + ":" + std::to_string(line_number) + " is not a frame line";
            return false;
        }
        // After a crash the index may name a JPEG that never reached frames.mjpg completely.
        if(frame.offset + frame.size > data_size)
        {
            break;
        }
        frames.push_back(std::move(frame));
    }
    return true;
}
}  // namespace

std::optional<RecordedSession> openSession (const std::filesystem::path& directory, std::string& error)
{
    std::ifstream manifest_file(directory / "manifest.json");
    if(!manifest_file)
    {
        error = "No manifest.json in " + directory.string();
        return std::nullopt;
    }
    std::ostringstream text;
    text << manifest_file.rdbuf();
    std::string parse_error;
    const auto manifest = parseJson(text.str(), parse_error);
    if(!manifest)
    {
        error = "manifest.json: " + parse_error;
        return std::nullopt;
    }
    if(manifest->string("format") != "dartpilot-session")
    {
        error = "manifest.json is not a DartPilot session";
        return std::nullopt;
    }
    RecordedSession session;
    session.directory = directory;
    session.version = static_cast<int>(manifest->integer("version"));
    if(session.version < 1 || session.version > kFormatVersion)
    {
        error = "Session format version " + std::to_string(session.version) + " is not supported (this build reads up to " +
                std::to_string(kFormatVersion) + ")";
        return std::nullopt;
    }
    session.session_id = manifest->string("session_id");
    if(const JsonValue* software = manifest->find("software"))
    {
        session.software_version = software->string("version");
        session.software_commit = software->string("commit");
    }
    const JsonValue* cameras = manifest->find("cameras");
    if(!cameras || cameras->type != JsonValue::Type::Array)
    {
        error = "manifest.json has no cameras";
        return std::nullopt;
    }
    for(const JsonValue& entry : cameras->items)
    {
        RecordedCamera camera;
        camera.id = entry.string("id");
        camera.usb_port = entry.string("usb_port");
        camera.name = entry.string("name");
        if(const JsonValue* stream = entry.find("stream"))
        {
            camera.width = static_cast<int>(stream->integer("width"));
            camera.height = static_cast<int>(stream->integer("height"));
            camera.fps = static_cast<int>(stream->integer("fps"));
        }
        if(const JsonValue* calibration = entry.find("calibration"))
        {
            camera.intrinsics = fileReference(calibration->find("intrinsics"));
            camera.extrinsics = fileReference(calibration->find("extrinsics"));
        }
        // The id names a directory; it must not lead out of the session.
        if(camera.id.empty() || camera.id.find('/') != std::string::npos || camera.id == "." || camera.id == "..")
        {
            error = "manifest.json has a camera without a valid id";
            return std::nullopt;
        }
        const std::filesystem::path camera_dir = directory / "cameras" / camera.id;
        std::error_code size_error;
        const auto data_size = std::filesystem::file_size(camera_dir / "frames.mjpg", size_error);
        if(size_error)
        {
            error = "Cannot read " + (camera_dir / "frames.mjpg").string();
            return std::nullopt;
        }
        if(!readFrameIndex(camera_dir / "frames.csv", data_size, camera.frames, error))
        {
            return std::nullopt;
        }
        session.cameras.push_back(std::move(camera));
    }
    return session;
}

FrameReader::FrameReader (const RecordedSession& session, std::size_t camera)
    : camera_(session.cameras.at(camera))
    , file_(session.directory / "cameras" / camera_.id / "frames.mjpg", std::ios::binary)
{
}

std::vector<std::uint8_t> FrameReader::read (std::size_t frame)
{
    const FrameIndex& index = camera_.frames.at(frame);
    std::vector<std::uint8_t> data(index.size);
    file_.clear();
    file_.seekg(static_cast<std::streamoff>(index.offset));
    file_.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(data.size()));
    if(!file_ || file_.gcount() != static_cast<std::streamsize>(data.size()))
    {
        return {};
    }
    return data;
}
}  // namespace dartpilot::session
