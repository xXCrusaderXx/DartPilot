#include "dartpilot/session/json.hpp"

#include <array>
#include <cstdio>
#include <stdexcept>

namespace dartpilot::session
{
namespace
{
// Recursive descent over RFC 8259; deep nesting is limited, so a hostile file cannot exhaust the stack.
class Parser
{
   public:
    explicit Parser (std::string_view text)
        : text_(text)
    {
    }

    JsonValue document ()
    {
        JsonValue value = parseValue(0);
        skipSpace();
        if(pos_ != text_.size())
        {
            fail("unexpected text after the value");
        }
        return value;
    }

    std::size_t position () const { return pos_; }

   private:
    static constexpr int kMaxDepth = 64;

    [[noreturn]] void fail (const std::string& what) const { throw std::runtime_error(what); }

    void skipSpace ()
    {
        while(pos_ < text_.size() && (text_[pos_] == ' ' || text_[pos_] == '\t' || text_[pos_] == '\n' || text_[pos_] == '\r'))
        {
            ++pos_;
        }
    }

    bool consume (std::string_view word)
    {
        if(text_.substr(pos_, word.size()) == word)
        {
            pos_ += word.size();
            return true;
        }
        return false;
    }

    JsonValue parseValue (int depth)
    {
        if(depth > kMaxDepth)
        {
            fail("nested too deeply");
        }
        skipSpace();
        if(pos_ >= text_.size())
        {
            fail("unexpected end");
        }
        JsonValue value;
        const char c = text_[pos_];
        if(c == '{')
        {
            value.type = JsonValue::Type::Object;
            ++pos_;
            skipSpace();
            if(consume("}"))
            {
                return value;
            }
            while(true)
            {
                skipSpace();
                if(pos_ >= text_.size() || text_[pos_] != '"')
                {
                    fail("expected a member name");
                }
                std::string key = parseString();
                skipSpace();
                if(!consume(":"))
                {
                    fail("expected ':'");
                }
                value.members[key] = parseValue(depth + 1);
                skipSpace();
                if(consume("}"))
                {
                    return value;
                }
                if(!consume(","))
                {
                    fail("expected ',' or '}'");
                }
            }
        }
        if(c == '[')
        {
            value.type = JsonValue::Type::Array;
            ++pos_;
            skipSpace();
            if(consume("]"))
            {
                return value;
            }
            while(true)
            {
                value.items.push_back(parseValue(depth + 1));
                skipSpace();
                if(consume("]"))
                {
                    return value;
                }
                if(!consume(","))
                {
                    fail("expected ',' or ']'");
                }
            }
        }
        if(c == '"')
        {
            value.type = JsonValue::Type::String;
            value.text = parseString();
            return value;
        }
        if(consume("true") || consume("false"))
        {
            value.type = JsonValue::Type::Boolean;
            value.boolean = text_[pos_ - 4] == 't';
            return value;
        }
        if(consume("null"))
        {
            return value;
        }
        if(c == '-' || (c >= '0' && c <= '9'))
        {
            value.type = JsonValue::Type::Number;
            const std::size_t start = pos_;
            ++pos_;
            while(pos_ < text_.size() && std::string_view("0123456789.eE+-").find(text_[pos_]) != std::string_view::npos)
            {
                ++pos_;
            }
            value.text = std::string(text_.substr(start, pos_ - start));
            return value;
        }
        fail("unexpected character");
    }

    static void appendUtf8 (std::string& out, unsigned code)
    {
        if(code < 0x80)
        {
            out += static_cast<char>(code);
        }
        else if(code < 0x800)
        {
            out += static_cast<char>(0xc0 | (code >> 6));
            out += static_cast<char>(0x80 | (code & 0x3f));
        }
        else if(code < 0x10000)
        {
            out += static_cast<char>(0xe0 | (code >> 12));
            out += static_cast<char>(0x80 | ((code >> 6) & 0x3f));
            out += static_cast<char>(0x80 | (code & 0x3f));
        }
        else
        {
            out += static_cast<char>(0xf0 | (code >> 18));
            out += static_cast<char>(0x80 | ((code >> 12) & 0x3f));
            out += static_cast<char>(0x80 | ((code >> 6) & 0x3f));
            out += static_cast<char>(0x80 | (code & 0x3f));
        }
    }

    unsigned hex4 ()
    {
        if(pos_ + 4 > text_.size())
        {
            fail("short \\u escape");
        }
        unsigned code = 0;
        for(int i = 0; i < 4; ++i)
        {
            const char h = text_[pos_++];
            code <<= 4;
            if(h >= '0' && h <= '9')
            {
                code |= static_cast<unsigned>(h - '0');
            }
            else if(h >= 'a' && h <= 'f')
            {
                code |= static_cast<unsigned>(h - 'a' + 10);
            }
            else if(h >= 'A' && h <= 'F')
            {
                code |= static_cast<unsigned>(h - 'A' + 10);
            }
            else
            {
                fail("bad \\u escape");
            }
        }
        return code;
    }

    std::string parseString ()
    {
        ++pos_;
        std::string out;
        while(true)
        {
            if(pos_ >= text_.size())
            {
                fail("unterminated string");
            }
            const char c = text_[pos_++];
            if(c == '"')
            {
                return out;
            }
            if(c != '\\')
            {
                out += c;
                continue;
            }
            if(pos_ >= text_.size())
            {
                fail("unterminated escape");
            }
            const char e = text_[pos_++];
            switch(e)
            {
                case '"':
                    out += '"';
                    break;
                case '\\':
                    out += '\\';
                    break;
                case '/':
                    out += '/';
                    break;
                case 'b':
                    out += '\b';
                    break;
                case 'f':
                    out += '\f';
                    break;
                case 'n':
                    out += '\n';
                    break;
                case 'r':
                    out += '\r';
                    break;
                case 't':
                    out += '\t';
                    break;
                case 'u':
                {
                    unsigned code = hex4();
                    // A surrogate pair encodes one code point above the basic plane.
                    if(code >= 0xd800 && code < 0xdc00 && consume("\\u"))
                    {
                        const unsigned low = hex4();
                        code = 0x10000 + ((code - 0xd800) << 10) + (low - 0xdc00);
                    }
                    appendUtf8(out, code);
                    break;
                }
                default:
                    fail("bad escape");
            }
        }
    }

    std::string_view text_;
    std::size_t pos_ = 0;
};
}  // namespace

std::string jsonString (const std::string& value)
{
    std::string out = "\"";
    for(const char c : value)
    {
        switch(c)
        {
            case '"':
                out += "\\\"";
                break;
            case '\\':
                out += "\\\\";
                break;
            case '\n':
                out += "\\n";
                break;
            case '\t':
                out += "\\t";
                break;
            default:
                if(static_cast<unsigned char>(c) < 0x20)
                {
                    std::array<char, 8> escaped{};
                    std::snprintf(escaped.data(), escaped.size(), "\\u%04x", c);
                    out += escaped.data();
                }
                else
                {
                    out += c;
                }
        }
    }
    return out + "\"";
}

const JsonValue* JsonValue::find (std::string_view key) const
{
    if(type != Type::Object)
    {
        return nullptr;
    }
    const auto it = members.find(key);
    return it == members.end() ? nullptr : &it->second;
}

std::string JsonValue::string (std::string_view key) const
{
    const JsonValue* member = find(key);
    return member && member->type == Type::String ? member->text : std::string();
}

long long JsonValue::integer (std::string_view key, long long fallback) const
{
    const JsonValue* member = find(key);
    if(!member || member->type != Type::Number)
    {
        return fallback;
    }
    try
    {
        std::size_t used = 0;
        const long long value = std::stoll(member->text, &used);
        return used == member->text.size() ? value : fallback;
    }
    catch(const std::exception&)
    {
        return fallback;
    }
}

std::optional<JsonValue> parseJson (std::string_view text, std::string& error)
{
    Parser parser(text);
    try
    {
        return parser.document();
    }
    catch(const std::runtime_error& e)
    {
        error = std::string(e.what()) + " at byte " + std::to_string(parser.position());
        return std::nullopt;
    }
}
}  // namespace dartpilot::session
