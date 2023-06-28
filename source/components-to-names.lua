-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

-----------------
--- Constants ---
-----------------
-- We use lots of tight loops, so we want to reduce table lookups later on.

-- Base Lua
local codepoint = utf8.codepoint
local codes = utf8.codes
local concat <const> = table.concat
local insert <const> = table.insert
local ipairs <const> = ipairs
local len <const> = utf8.len
local lowercase <const> = string.lower
local next <const> = next
local pairs <const> = pairs
local utf_char <const> = utf8.char

-- ConTeXt-specific
local character_data <const> = characters.data
local dec_str <const> = string.formatters["%d"]
local hex_single <const> = string.formatters["0x%04x"]
local hex_component <const> = string.formatters["%04x"]
local json <const> = require("util-jsn")
local lpeg_match <const> = lpeg.match
local lpeg_P <const> = lpeg.P
local lpeg_stripper <const> = lpeg.stripper
local sortedpairs <const> = table.sortedpairs

-- Custom
local ALWAYS <const> = "always"
local NEVER <const> = "never"
local UNIQUE <const> = "unique"

local SKIN_FIRST <const> = 0x1f3fb
local SKIN_LAST <const> = 0x1f3ff
local ZWJ <const> = 0x200d


---------------------------------
--- Generic utility functions ---
---------------------------------

--- Removes the given strings from the input string.
---
--- @param str string The input string
--- @param deletes string[] The strings to remove
--- @return string - The input string with the given strings removed
local function deleter(str, deletes)
    local Ps
    for _, delete in ipairs(deletes) do
        Ps = Ps and Ps + lpeg_P(delete) or lpeg_P(delete)
    end
    return lpeg_match(lpeg_stripper(Ps), str)
end


--- Filter a table's values.
---
--- @param t any[] The table to filter
--- @param func fun(any): boolean The function to use to filter
--- @return table
local function filter(t, func)
    local out = {}
    for _, v in ipairs(t) do
        if func(v) then
            out[#out+1] = v
        end
    end
    return out
end


-------------------------------------
--- Specialized utility functions ---
-------------------------------------
local by_name <const> = {}

--- Saves a character name
---
--- @param char string The Unicode glyph for the character
--- @param name string The name to associate with the glyph
--- @param retention "always"|"never"|"unique" When to retain the character
local function add_name(char, name, retention)
    -- Make everything lowercase
    name = lowercase(name):gsub("\u{fe0f}", "")

    -- Remove some superfluous text to make input easier
    local shortened <const> = deleter(
        name,
        {
            "flag: ",
            "“",
            "”",
            "’",
            " skin tone",
            "tag latin small letter ",
            "cancel tag",
        }
    )
    if shortened ~= name then
        add_name(char, shortened, retention)
    end

    -- Save each name. We do `[name] = true` to avoid duplicates.
    by_name[name] = by_name[name] or {}
    by_name[name][char] = retention
end


-----------------------------
--- Process the CLDR data ---
-----------------------------

-- Load all the English annotations
local annotations <const> = {}
dir.globpattern(
    document.getargument("cldr"),
    "/annotations.*/en.*/annotations%.json$",
    true,
    function(path)
        local contents <const> = json.load(path)
        local root <const> = contents.annotations or
                             contents.annotationsDerived

        insert(annotations, root.annotations)
    end
)


-- Map each annotation name to a list of associated characters
for _, annotation in ipairs(annotations) do  -- Loop over each file
    for char, t in sortedpairs(annotation) do -- Loop over each character
        local skin_tone = false

        add_name(char, char, NEVER)

        -- Base Unicode data
        if len(char) == 1 then -- Single character
            local code <const> = codepoint(char)
            add_name(char, character_data[code].description, ALWAYS)
            add_name(char, dec_str(code), UNIQUE)
            add_name(char, hex_single(code), ALWAYS)

        else -- Composed/ligated characters
            local char_names <const> = {}
            local char_hexes <const> = {}

            for _, code in codes(char) do
                -- We check to see if there are any skin tone modifiers
                if code >= SKIN_FIRST and code <= SKIN_LAST then
                    skin_tone = true
                end

                if code ~= ZWJ then -- Zero-width joiner, ignore
                    insert(char_names, character_data[code].description)
                end

                insert(char_hexes, hex_component(code))
            end

            add_name(char, concat(char_names, " "), ALWAYS)
            add_name(char, concat(char_hexes, "-"), ALWAYS)
        end

        -- The CLDR "text-to-speech" attribute is the best human-readable
        -- name for each character (sequence).
        if t.tts then
            add_name(char, t.tts[1], UNIQUE)
        end

        -- The CLDR "tags" are also pretty good, but they can be duplicated
        -- between characters so we need to be careful.
        if not skin_tone and t.default then
            for i, name in ipairs(t.default) do
                add_name(char, name, UNIQUE)
            end
        end
    end
end


-- Map each character to a list of associated characters
for codepoint, data in pairs(character_data) do
    local char <const> = utf_char(codepoint)
    add_name(char, char, NEVER)
    add_name(char, data.description, ALWAYS)
    add_name(char, dec_str(codepoint), UNIQUE)
    add_name(char, hex_single(codepoint), ALWAYS)
    if data.adobename then
        add_name(char, data.adobename, UNIQUE)
    end
end


-- Now map each character to a list of associated names
local by_char <const> = {}
for name, glyphs in sortedpairs(by_name) do
    local first <const>, value <const> = next(glyphs)

    -- If there's just a single "unique" name, then use it
    if not next(glyphs, first) and -- Like `#values == 1`
       value ~= NEVER
    then
        by_char[first] = by_char[first] or {}
        insert(by_char[first], name)

    -- If there are other names, then only keep the "always" names
    else
        for glyph, value in sortedpairs(glyphs) do
            if value == ALWAYS and
               not name:match("private")
            then
                by_char[glyph] = by_char[glyph] or {}
                insert(by_char[glyph], name)
            end
        end
    end
end


--- Converts a list of codepoints to a list of names.
---
--- @param components string[]|string A list of hex strings for each codepoint
--- @return string[] - A list of names for the given codepoints
return function(components)
    local status <const>, result <const> = pcall(function()
        if type(components) == "string" then
            return by_char[components] or {}
        elseif type(components) == "table" then
            components = filter(components, function(v) return v ~= "fe0f" end)

            local key = concat(components, "-")

            if #components == 1 then
                key = "0x" .. key
            end

            return by_char[next(by_name[key])]
        end
    end)

    if status then
        return result
    else
        return {}
    end
end
