#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <regex>
#include <sstream>
#include <string>

#include "dartpilot/version.hpp"

namespace
{
std::string readFile (const std::filesystem::path& path)
{
    std::ifstream in(path);
    std::stringstream text;
    text << in.rdbuf();
    return text.str();
}

// The first group of the first line of a file that matches pattern
std::string find (const std::string& file, const std::string& pattern)
{
    std::smatch match;
    const std::string text = readFile(std::filesystem::path(DARTPILOT_SOURCE_DIR) / file);
    return std::regex_search(text, match, std::regex(pattern)) ? match[1].str() : std::string();
}
}  // namespace

// Engine, app and tools carry one version (CONTRIBUTING.md, "Versions"). A release build sets the engine's from the
// milestone, so only X.Y.Z is compared: the files on dev say 0.3.0-dev while 0.3.0 is built.
TEST(Version, EngineAppAndToolsAgree)
{
    const std::string engine(dartpilot::kVersion);
    std::smatch number;
    ASSERT_TRUE(std::regex_search(engine, number, std::regex(R"(^(\d+\.\d+\.\d+))"))) << engine;
    const std::string app = find("ui/pubspec.yaml", R"(\nversion: (\d+\.\d+\.\d+)[-+])");
    const std::string tools = find("tools/pyproject.toml", R"(\nversion = "(\d+\.\d+\.\d+))");
    EXPECT_EQ(app, number[1].str()) << "ui/pubspec.yaml";
    EXPECT_EQ(tools, number[1].str()) << "tools/pyproject.toml";
    const std::string cmake = find("CMakeLists.txt", R"(set\(DARTPILOT_VERSION (\d+\.\d+\.\d+))");
    EXPECT_EQ(cmake, app) << "CMakeLists.txt";
}
