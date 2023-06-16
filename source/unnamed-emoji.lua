-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

-- Loads a PDF file into a Type 3 font.

-- Save some globals
local getfromdictionary = pdfe.getfromdictionary
local getfromreference = pdfe.getfromreference
local l_type = type
local pairs = pairs
local select = select
local tonumber = tonumber
local yield = coroutine.yield

-- Define some numerical constants
local height = tex.sp("10bp")
local bp_to_sp = tex.sp("1bp")


-----------------------------------------
--- General-purpose utility functions ---
-----------------------------------------

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
--- @return table - The "function"
local function memoized_table(func)
    return setmetatable({}, { __index = function(cache, key)
        local ret = func(key, cache)
        cache[key] = ret
        return ret
    end,  __call = function(self, arg)
        return self[arg]
    end })
end


-----------------------------------
-- Specialized utility functions --
-----------------------------------

--- Converts a filename to an absolute path.
---
--- @param name string A filename
--- @return string path An absolute path to the file
local function get_font_path(name)
    if not name:match("/") then
        return kpse.find_file(name .. ".pdf")
    else
        return name
    end
end


--- Creates a TeX command that evaluates a Lua function
---
--- @param name string The name of the `\csname` to define
--- @param func function
--- @param args table<string> The TeX types of the function arguments
--- @param protected boolean|nil Define the command as `\protected`
--- @return nil
local function register_tex_cmd(name, func, args, protected)
    -- Mangle the name to an appropriate form for each supported format.
    if tex.formatname:find("latex") then
        name = "__unemoji_" .. name .. ":" .. string.rep("n", #args)
    elseif optex then
        name = "_unemoji_" .. name
    else
        name = "unemoji@" .. name
    end

    -- Push the appropriate scanner functions onto the scanning stack.
    local scanners = {}
    for _, arg in ipairs(args) do
        scanners[#scanners+1] = token['scan_' .. arg]
    end

    -- An intermediate function that properly "scans" for its arguments
    -- in the TeX side.
    local scanning_func = function()
        local values = {}
        for _, scanner in ipairs(scanners) do
            values[#values+1] = scanner()
        end

        func(table.unpack(values))
    end

    -- Actually register the function
    if optex then
        define_lua_command(name, scanning_func)
    else
        local index = luatexbase.new_luafunction(name)
        lua.get_functions_table()[index] = scanning_func

        if protected then
            token.set_lua(name, index, "protected")
        else
            token.set_lua(name, index)
        end
    end
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
    -- A coroutine is *way* easier than implementing this by hand
    return coroutine.wrap(function()
        -- Outer Kids array
        for i, dests in array_pairs(document.Catalog.Names.Dests.Kids) do
            -- Inner Kids array
            for i, dests in array_pairs(dests.Kids) do
                local char_name = ""
                for _, dest in array_pairs(dests.Names) do
                    if type(dest) == "string" then
                        -- Push the character name
                        char_name = dest:match("emoji(.*)$")
                    else
                        -- Send the name and destination out to the caller
                        yield(char_name, dest)
                    end
                end
            end
        end
    end)
end


--- Gets the contents of a stream.
---
--- @param stream luatex.pdfe.stream|string The stream
--- @return string - The contents of the stream
local stream_data = memoized_table(function(stream)
    local str
    if type(stream) == "luatex.pdfe.stream" then
        return stream(true)
    elseif type(stream) == "string" then
        return stream
    else
        return ""
    end
end)


--- Gets the PDF object for a stream.
---
--- @param stream string The stream's contents
--- @return integer - The PDF object number
local stream_object = memoized_table(function(stream)
    return pdf.immediateobj("stream", stream)
end)


---------------------------
--- Font/PDF processing ---
---------------------------

-- Store the fonts defined by this script
local fonts = {}

--- Makes the low-level Type 3 fonts from the provided characters.
---
--- @param pdf_name string The name of the PDF file
--- @param characters table A mapping of characters
local function make_fonts(pdf_name, characters)
    -- Make proper /ToUnicode mappings
    pdf.setgentounicode(1)

    -- Iterate over each T3 font in the PDF
    for fontname, characters in pairs(characters) do
        local define_chars = {}

        -- Iterate over each character in the T3 font
        for slot, char in pairs(characters) do
            define_chars[slot] = {
                width = char.width * bp_to_sp,
                height = height,
                depth = 0,
                tounicode = char.codepoint,
            }
        end

        -- Make a new T3 font
        local id = font.define {
            name = ("unemoji-%s-%s"):format(pdf_name, fontname),
            parameters = {},
            properties = {},
            characters = define_chars,
            -- These parameters are both needed to force `provide_charproc_data`
            -- to run on this font
            encodingbytes = 0,
            psname = "none",
        }

        -- Store references to the font
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
    -- Initialize some tables
    local pdf_font = {}
    local by_font = {}
    local dests = {}

    -- Read the PDF file
    local document = pdfe.open(filename)

    -- Loop over each named destination
    for name, dest in get_dests(document) do
        -- If we've already seen the page this destination points to, just use a
        -- reference to the page's character
        local dest_key = tostring(dest)
        local prev_dest = dests[dest_key]
        if prev_dest then
            if tonumber(name) then
                prev_dest.codepoint = tonumber(name)
            end
            pdf_font[name] = prev_dest
        else -- Otherwise, we need to parse the page's contents
            -- The page object
            local page = dest.D[1]

            -- The font's internal name and object
            local fontname, _, font = getfromdictionary(
                page.Resources.Font,
                1
            )
            font = select(2, getfromreference(font))

            -- Get the character's slot as an integer from the page's stream
            local info = {}
            pdfscanner.scan(page.Contents(true), {
                TJ = function(scanner, info)
                    info.slot = scanner:pop()[2][1][2]
                end
            }, info)

            if info.slot and #info.slot == 1 then
                local slot = string.byte(info.slot)

                -- Our internal data about this character
                local char = {
                    inner_fontname = fontname,
                    inner_slot = slot,
                    char_obj = stream_data[font.CharProcs["I" .. slot]],
                    width = font.Widths[slot + 1],
                    codepoint = tonumber(name),
                }

                -- Save this data in multiple tables for easy access
                pdf_font[name] = char
                dests[dest_key] = char

                by_font[fontname] = by_font[fontname] or {}
                by_font[fontname][slot] = char
            end
        end
    end

    -- Make the LuaTeX T3 fonts from the data we found in the PDF
    make_fonts(filename, by_font)

    return pdf_font
end)


--- Makes the upper-level virtual font from the provided PDF document.
---
--- A Type 3 font can only hold 255 characters, so we need to make a virtual
--- font that points to multiple Type 3 fonts so that we can reference all
--- characters with a single font.
---
--- @param pdf_font string The name of the PDF file
--- @return integer font_id - The id of the font
local load_font = memoized_table(function(pdf_font)
    -- Make sure that the `chars` table is ready to go
    chars(pdf_font)

    -- Get all the T3 fonts that we need to define
    local define_ids = {}
    local fontid_to_defindex = {}
    for name, id in pairs(fonts[pdf_font]) do
        define_ids[#define_ids+1] = { id = id }
        fontid_to_defindex[id] = #define_ids
    end

    -- Make the VF metadata for all characters
    local define_chars = {}
    for name, char in pairs(chars[pdf_font]) do
        name = tonumber(name)
        if name then
            local id = fonts[pdf_font][char.inner_fontname]
            define_chars[name] = {
                width = char.width * bp_to_sp,
                height = height,
                depth = 0,
                -- "slot" indexes the VF's fonts table and prints the
                -- corresponding character from the selected font.
                commands = {
                    { "slot", fontid_to_defindex[id], char.inner_slot }
                },
            }
        end
    end

    -- Make the virtual font
    return font.define {
        name = "unemojifont-" .. pdf_font,
        parameters = {}, -- Needs a value, but we don't use it
        characters = define_chars,
        properties = {}, -- ditto
        type = "virtual",
        fonts = define_ids,
    }
end)


-----------------------------------------
--- Expose everything to the TeX side ---
-----------------------------------------

register_tex_cmd(
    "load",
    function(fontname) -- Loads a given font into LuaTeX
        token.set_char("unemojifont", load_font(get_font_path(fontname)))
    end,
    { "string", "string" }
)


--- Prints a character from a given font.
---
--- @param fontname string The name of the font
--- @param char_name string The name of the character
local function print_char(fontname, char_name)
    fontname = get_font_path(fontname)
    local char = chars[fontname][char_name] or
                 chars[fontname][tostring(utf8.codepoint(char_name))]

    -- Directly write the glyph node, without any help from TeX
    if char and char.codepoint then
        tex.forcehmode()
        local glyph = node.new("glyph")
        glyph.char = char.codepoint
        glyph.font = load_font(fontname)
        node.write(glyph)
    end
end


register_tex_cmd(
    "print",
    print_char,
    { "string", "string" },
    true
)


-- Undocumented callback that allows us to provide the PDF stream for each glyph
-- of a T3 font to LuaTeX when it writes the PDF file.
luatexbase.add_to_callback(
    "provide_charproc_data",
    function (mode, font_id, slot)
        if mode == 2 then -- Mode 2 wants the PDF stream
            local char = fonts[font_id][slot]
            return stream_object[char.char_obj], char.width
        elseif mode == 3 then -- Mode 3 wants the font's overall scale factor
            return 0.093
        end
    end,
    "unemoji"
)


return {
    chars = chars,
    load_font = load_font,
    print = print_char,
    register_tex_cmd = register_tex_cmd,
}
