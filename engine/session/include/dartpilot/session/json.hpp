#pragma once

#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

// The small amount of JSON the session format needs: escaping for the writers, and a reader for manifest.json and
// run.json. Numbers keep their text, so integers such as nanosecond times are read without going through a double.
namespace dartpilot::session
{
// The value as a JSON string literal, quotes included
std::string jsonString (const std::string& value);

struct JsonValue
{
    enum class Type
    {
        Null,
        Boolean,
        Number,
        String,
        Array,
        Object,
    };

    Type type = Type::Null;
    bool boolean = false;
    // The number's text, or the decoded string
    std::string text;
    std::vector<JsonValue> items;
    std::map<std::string, JsonValue, std::less<>> members;

    bool isNull () const { return type == Type::Null; }
    // The member, or nullptr if this is no object or has no such member
    const JsonValue* find (std::string_view key) const;
    // The member's string, or empty
    std::string string (std::string_view key) const;
    // The member's integer, or the fallback if it is missing or no integer
    long long integer (std::string_view key, long long fallback = 0) const;
};

// Nothing and an error message with the position for anything that is not one complete JSON value.
std::optional<JsonValue> parseJson (std::string_view text, std::string& error);
}  // namespace dartpilot::session
