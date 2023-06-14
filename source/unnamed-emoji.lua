-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

-- Save some globals
local array = pdfe.arraytotable
local dict = pdfe.dictionarytotable
local getfromdictionary = pdfe.getfromdictionary
local getfromreference = pdfe.getfromreference
local l_type = type
local pairs = pairs
local rawget = rawget
local rawset = rawset
local select = select
local tonumber = tonumber
local unpack = table.unpack
local yield = coroutine.yield

-- Define some numerical constants
local height = tex.sp("10bp")
local bp_to_sp = tex.sp("1bp")

-- General-purpose utility functions

--- A variant of `type` that also works on userdata.
---
--- @param val any
--- @return string - The type of the value
local function type(val)
    local meta = getmetatable(val)
    if meta and meta.__name then
        return meta.__name
    else
        return l_type(val)
    end
end


--- Memoizes a function call/table index.
---
--- @param func function<any, any> The function to memoize
--- @return table
local function memoized_table(func)
    return setmetatable({}, { __index = function(cache, key)
        local ret = func(key, cache)
        cache[key] = ret
        return ret
    end,  __call = function(self, arg)
        return self[arg]
    end })
end


-- Specialized utility functions

--- Converts a filename to an absolute path.
---
--- @param name string A filename
--- @return string path An absolute path to the file
local function get_font_path(name)
    return kpse.find_file(name .. ".pdf")
end


--- Creates a TeX command that evaluates a Lua function
---
--- @param name string The name of the \csname to define
--- @param func function
--- @param args table<string> The TeX types of the function arguments
--- @return nil
local function register_tex_cmd(name, func, args)
    local scanning_func

    if tex.formatname:find("latex") then
        name = "__unemoji_" .. name .. ":" .. string.rep("n", #args)
    else
        name = "unemoji@" .. name
    end

    local scanners = {}
    for _, arg in ipairs(args) do
        scanners[#scanners+1] = token['scan_' .. arg]
    end

    -- An intermediate function that properly "scans" for its arguments
    -- in the \TeX{} side.
    scanning_func = function()
        local values = {}
        for _, scanner in ipairs(scanners) do
            values[#values+1] = scanner()
        end

        func(table.unpack(values))
    end

    local index = luatexbase.new_luafunction(name)
    lua.get_functions_table()[index] = scanning_func
    token.set_lua(name, index)
end


--- Iterator for a PDF array/dictionary.
---
--- @param array luatex.pdfe.array|luatex.pdfe.dictionary
--- @return function iterator `{index: integer, value: any}`
local function array_pairs(array)
    local len = #array
    return function(state, index)
        if not index then
            index = 1
        elseif index >= len then
            return
        else
            index = index + 1
        end

        return index, array[index]
    end
end


--- Iterator over all named destinations in a PDF document.
---
--- @param document luatex.pdfe.dictionary The root of a PDF document
--- @return function iterator `{name: string, dest: luatex.pdfe.dictionary}`
local function get_dests(document)
    return coroutine.wrap(function()
        for i, dests in array_pairs(document.Catalog.Names.Dests.Kids) do
            for i, dests in array_pairs(dests.Kids) do
                local char_name = ""
                for _, dest in array_pairs(dests.Names) do
                    if type(dest) == "string" then
                        char_name = dest:match("emoji(.*)$")
                    else
                        yield(char_name, dest)
                    end
                end
            end
        end
    end)
end


-- Font/PDF processing

local fonts = {}
--- Makes the low-level Type 3 fonts from the provided characters.
---
--- @param pdf_name string The name of the PDF file
--- @param characters table A mapping of characters
local function make_fonts(pdf_name, characters)
    pdf.setgentounicode(1)

    for fontname, characters in pairs(characters) do
        local define_chars = {}
        for slot, char in pairs(characters) do
            define_chars[slot] = {
                width = char.width * bp_to_sp,
                height = height,
                depth = 0,
                tounicode = char.codepoint,
            }
        end

        local id = font.define {
            name = ("unemoji-%s-%s"):format(pdf_name, fontname),
            parameters = {},
            properties = {},
            characters = define_chars,
            encodingbytes = 0,
            psname = "none",
        }

        fonts[id] = characters
        fonts[pdf_name] = fonts[pdf_name] or {}
        fonts[pdf_name][fontname] = id
    end
end


--- Gets a character's data from its name and PDF file.
---
--- @param filename string The name of the PDF file
--- @param char string|integer|nil The name/codepoint of the character
--- @return table - The character's data
local chars = memoized_table(function(filename)
    local pdf_font = {}
    local by_font = {}
    local dests = {}
    local document = pdfe.open(filename)

    for name, dest in get_dests(document) do
        local dest_key = tostring(dest)
        local prev_dest = dests[dest_key]
        if prev_dest then
            if tonumber(name) then
                prev_dest.codepoint = tonumber(name)
            end
            pdf_font[name] = prev_dest
        else
            local page = dest.D[1]
            local fontname, _, font = getfromdictionary(
                page.Resources.Font,
                1
            )
            font = select(2, getfromreference(font))
            local info = {}
            pdfscanner.scan(page.Contents(true), {
                TJ = function(scanner, info)
                    info.slot = scanner:pop()[2][1][2]
                end
            }, info)

            if info.slot and #info.slot == 1 then
                local slot = string.byte(info.slot)

                local char = {
                    inner_fontname = fontname,
                    inner_slot = slot,
                    char_obj = font.CharProcs["I" .. slot],
                    width = font.Widths[slot + 1],
                    codepoint = tonumber(name),
                }

                pdf_font[name] = char
                dests[dest_key] = char

                by_font[fontname] = by_font[fontname] or {}
                by_font[fontname][slot] = char
            end
        end
    end

    make_fonts(filename, by_font)

    return pdf_font
end)


--- Makes the upper-level virtual font from the provided PDF document.
---
--- @param pdf_font string The name of the PDF file
--- @return integer font_id - The id of the font
local load_font = memoized_table(function(pdf_font)
    chars(pdf_font)

    local define_ids = {}
    local fontid_to_defindex = {}
    for name, id in pairs(fonts[pdf_font]) do
        define_ids[#define_ids+1] = { id = id }
        fontid_to_defindex[id] = #define_ids
    end

    local define_chars = {}
    for name, char in pairs(chars[pdf_font]) do
        name = tonumber(name)
        if name then
            local id = fonts[pdf_font][char.inner_fontname]
            define_chars[name] = {
                width = char.width * bp_to_sp,
                height = height,
                depth = 0,
                commands = {
                    { "slot", fontid_to_defindex[id], char.inner_slot }
                },
            }
        end
    end

    return font.define {
        name = "unemojifont-" .. pdf_font,
        parameters = {},
        characters = define_chars,
        properties = {},
        type = "virtual",
        fonts = define_ids,
    }
end)


--- Gets the PDF object for a stream.
---
--- @param stream luatex.pdfe.stream|string The stream
--- @return integer - The PDF object number
local stream_object = memoized_table(function(stream)
    local str
    if type(stream) == "luatex.pdfe.stream" then
        str = stream(true)
    elseif type(stream) == "string" then
        str = stream
    else
        return 0
    end

    return pdf.immediateobj("stream", str)
end)


-- Expose everything to the TeX side

register_tex_cmd(
    "load",
    function(fontname)
        token.set_char("unemojifont", load_font(get_font_path(fontname)))
    end,
    { "string", "string" }
)

register_tex_cmd(
    "print",
    function(fontname, char_name)
        fontname = get_font_path(fontname)
        local char = chars[fontname][char_name] or
                     chars[fontname][tostring(utf8.codepoint(char_name))]

        if char and char.codepoint then
            tex.forcehmode()
            local glyph = node.new("glyph")
            glyph.char = char.codepoint
            glyph.font = load_font(fontname)
            node.write(glyph)
        end
    end,
    { "string", "string" }
)


luatexbase.add_to_callback(
    "provide_charproc_data",
    function (mode, font_id, slot)
        if mode == 2 then
            local char = fonts[font_id][slot]
            return stream_object[char.char_obj], char.width
        elseif mode == 3 then
            return 0.093
        end
    end,
    "unemoji"
)
