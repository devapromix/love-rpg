-- lib/json.lua
-- Мінімальний JSON-декодер без зовнішніх залежностей (потрібен лише decode).

local json = {}

local function skipWhitespace(s, i)
    local _, e = s:find("^[ \t\n\r]*", i)
    return e + 1
end

local decodeValue -- forward declaration

local function decodeString(s, i)
    -- i вказує на символ одразу після відкриваючої лапки
    local out = {}
    while true do
        local c = s:sub(i, i)
        if c == "" then
            error("Unterminated string in JSON at position " .. i)
        elseif c == '"' then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local nc = s:sub(i + 1, i + 1)
            if nc == "n" then table.insert(out, "\n")
            elseif nc == "t" then table.insert(out, "\t")
            elseif nc == "r" then table.insert(out, "\r")
            elseif nc == '"' then table.insert(out, '"')
            elseif nc == "\\" then table.insert(out, "\\")
            elseif nc == "/" then table.insert(out, "/")
            elseif nc == "u" then
                local hex = s:sub(i + 2, i + 5)
                local code = tonumber(hex, 16) or 63
                table.insert(out, string.char(code < 256 and code or 63))
                i = i + 4
            else
                table.insert(out, nc)
            end
            i = i + 2
        else
            table.insert(out, c)
            i = i + 1
        end
    end
end

local function decodeNumber(s, i)
    local numStr, e = s:match("^(-?%d+%.?%d*[eE]?[%+%-]?%d*)()", i)
    return tonumber(numStr), e
end

local function decodeArray(s, i)
    local arr = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == "]" then return arr, i + 1 end
    while true do
        local value
        value, i = decodeValue(s, i)
        table.insert(arr, value)
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = skipWhitespace(s, i + 1)
        elseif c == "]" then
            return arr, i + 1
        else
            error("Expected ',' or ']' in JSON array at position " .. i)
        end
    end
end

local function decodeObject(s, i)
    local obj = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == "}" then return obj, i + 1 end
    while true do
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= '"' then
            error("Expected string key in JSON object at position " .. i)
        end
        local key
        key, i = decodeString(s, i + 1)
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= ":" then
            error("Expected ':' in JSON object at position " .. i)
        end
        i = skipWhitespace(s, i + 1)
        local value
        value, i = decodeValue(s, i)
        obj[key] = value
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = skipWhitespace(s, i + 1)
        elseif c == "}" then
            return obj, i + 1
        else
            error("Expected ',' or '}' in JSON object at position " .. i)
        end
    end
end

decodeValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then
        return decodeString(s, i + 1)
    elseif c == "{" then
        return decodeObject(s, i + 1)
    elseif c == "[" then
        return decodeArray(s, i + 1)
    elseif c == "t" and s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif c == "f" and s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif c == "n" and s:sub(i, i + 3) == "null" then
        return nil, i + 4
    elseif c:match("[%-%d]") then
        return decodeNumber(s, i)
    else
        error("Unexpected character in JSON at position " .. i .. ": " .. c)
    end
end

function json.decode(s)
    if not s or s == "" then
        error("json.decode: empty input")
    end
    local value = decodeValue(s, 1)
    return value
end

return json
