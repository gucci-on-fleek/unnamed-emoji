-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

-- Loads a PDF file into a Type 3 font.

-- Save some globals
local copy_list = node.copy_list or node.copylist
local get_codepoint = utf8.codepoint
local getfromarray = pdfe.getfromarray
local getfromdictionary = pdfe.getfromdictionary
local getfromreference = pdfe.getfromreference
local l_fonts = fonts
local l_type = type
local last = node.slide
local lpeg_match = lpeg.match
local pairs = pairs
local pcall = pcall
local select = select
local string_char = string.char
local tonumber = tonumber
local yield = coroutine.yield

-- Define some useful constants
local ASCII_LAST = 0x7f
local bp_to_sp = tex.sp("1bp")
local matrix_format = "%.2f 0 0 %.2f"
local OPEN_QUOTE = 0x201c
local PDF_STRING = 6
local SCALE_FACTOR = 282168  -- 1ex in cmr10
local t3_scale = 0.001


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


if not lpeg.replacer then
    --- Replace a list of patterns with the given replacements.
    ---
    --- @param maps (string|function)[][] A list of patterns and replacements
    --- @return Capture - The replacement pattern
    function lpeg.replacer(maps)
        local p = lpeg.P(false)
        for _, map in ipairs(maps) do
            p = p + lpeg.P(map[1]) / map[2]
        end
        return lpeg.Cs((p + 1)^0)
    end
end


-----------------------------------
-- Specialized utility functions --
-----------------------------------

--- Converts a filename to an absolute path.
---
--- @param name string A filename
--- @return string path An absolute path to the file
local function get_font_path(name)
    if not context and not name:match("/") then
        return kpse.find_file("unnamed-emoji-" .. name .. ".pdf")
    elseif not name:match("/") then
        return resolvers.findfile("unnamed-emoji-" .. name .. ".pdf")
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
    elseif context then
        name = "unemoji_" .. name
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
    elseif context then
        interfaces.implement {
            name = name,
            public = true,
            arguments = args,
            actions = func,
        }
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


--- Replace PDF escape sequences with their actual characters.
local pdf_unescape = lpeg.replacer {
    { [[\r]], "\r" },
    { [[\t]], "\t" },
    { [[\b]], "\b" },
    { [[\f]], "\f" },
    { [[\n]], "\n" },
    { [[\(]], "(" },
    { [[\)]], ")" },
    { [[\\]], "\\" },
    { lpeg.P("\\") * -lpeg.R("07")^4 * lpeg.R("07")^3, function(s)
        return string_char(tonumber(s:sub(2), 8))
    end },
}


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

        local pdf_type, value, encoded = getfromarray(array, index)

        -- If we have a hex-encoded string, we need to manually decode it
        -- since the built-in decoder fails sometimes.
        if pdf_type == PDF_STRING and encoded then
            local iter = value:gmatch("..")
            value = ""
            for byte in iter do
                value = value .. string_char(tonumber(byte, 16))
            end

        -- If we don't have a string, then we should use the generic getter
        else
            value = array[index]
        end

        -- Now we can process the backslash escapes
        if pdf_type == PDF_STRING and value:match("\\") then
            value = lpeg_match(pdf_unescape, value)
        end

        return index, value
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
    local type = type(stream)
    if type == "luatex.pdfe.stream" or type == "pdfe.stream" then
        return stream(true)
    elseif type == "string" then
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


--- Adds any extra names to the character's data.
---
--- @param name string
--- @param char table<string, string|integer>
local function add_extra_names(name, char)
    local success, first, second = pcall(get_codepoint, name, 1, -1)
    if success and
       ((first > ASCII_LAST and first ~= OPEN_QUOTE) or
        (second and second > ASCII_LAST and second ~= OPEN_QUOTE) or
        utf8.len(name) == 1)
    then
        char.unicode = name:gsub("\u{fe0f}", "")
    end

    local codepoint = tonumber(name, 10)
    if codepoint then
        char.codepoint = codepoint
    end
end


-- We need this semi-complex node list to properly scale a glyph.
local char_nodes do
    local save = node.new("whatsit", "pdf_save")
    local matrix = node.new("whatsit", "pdf_setmatrix")
    local glyph = node.new("glyph")
    local box = node.hpack(glyph, 0, "exactly")
    local restore = node.new("whatsit", "pdf_restore")
    local empty = node.new("hlist")

    save.next = matrix
    matrix.next = box
    box.next = restore
    restore.next = empty

    char_nodes = save
end


--- Gives the node list for a scaled character.
---
--- @param font_id integer The internal font ID
--- @param codepoint integer The codepoint of the character
--- @param scale number The scale factor
--- @return node n The node list containing the scaled character
local function make_scaled_char(font_id, codepoint, scale)
    local char_nodes = copy_list(char_nodes)

    -- Make the glyph
    local glyph = char_nodes.next.next.list
    glyph.char = codepoint
    glyph.font = font_id

    -- Make the scaling matrix
    local matrix = char_nodes.next
    matrix.data = string.format(matrix_format, scale, scale)

    -- Width adjustments, since \pdfsave and \pdfrestore need to be
    -- at the same position.
    local empty = last(char_nodes)
    empty.width = scale * glyph.width
    empty.height = scale * glyph.height

    return char_nodes
end


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
                height = char.height * bp_to_sp,
                depth = 0,
                tounicode = {
                    get_codepoint(char.unicode or "", 1, -1, true)
                },
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
        -- The page object
        local page = dest.D[1]

        -- If we've already seen the page this destination points to, just use a
        -- reference to the page's character
        local dest_key = tostring(dest)
        local prev_dest = dests[dest_key]
        if prev_dest then
            add_extra_names(name, prev_dest)
            pdf_font[name] = prev_dest

        -- Otherwise, we need to parse the page's contents
        elseif page.Resources.Font then
            -- The font's internal name and object
            local fontname, _, font = getfromdictionary(
                page.Resources.Font,
                1
            )
            font = select(2, getfromreference(font))

            -- Get the character's slot as an integer from the page's stream
            local contents = page.Contents(true)
            local slot

            if context then
                -- Decode manually with ConTeXt (LMTX)
                slot = tonumber(contents:match("<(..)>") or "", 16)
            else
                local info = {}

                -- Use pdfscanner to decode with LuaTeX
                pdfscanner.scan(contents, {
                    TJ = function(scanner, info)
                        info.slot = scanner:pop()[2][1][2]
                    end
                }, info)

                if info.slot and #info.slot == 1 then
                    slot = string.byte(info.slot)
                end
            end

            if slot then
                -- Our internal data about this character
                local char = {
                    inner_fontname = fontname,
                    inner_slot = slot,
                    char_obj = stream_data[font.CharProcs["I" .. slot]],
                    width = font.Widths[slot + 1] * font.FontMatrix[1] * 10,
                    height = page.CropBox[4],
                }

                add_extra_names(name, char)

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
        name = tonumber(name, 10)
        if name then
            local id = fonts[pdf_font][char.inner_fontname]
            define_chars[name] = {
                width = char.width * bp_to_sp,
                height = char.height * bp_to_sp,
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


local make_glyph
if context then
    local count = 0
    local id = memoized_table(function(font)
        count = count + 1
        return l_fonts.definers.internal {
            name = "LMRoman10-Regular",
            size = tex.sp("10pt") + count,
        }
    end)

    -- Register the dropin method "rawpdf" to allow us to inject raw PDF code
    -- as the contents of a Type 3 glyph.
    if not rawget(lpdf, "registerfontmethod") then
        -- ConTeXt LMTX contains the code to register a new font method, but
        -- it's commented out (disabled) by default, so we need to manually edit
        -- the file to forcibly enable it.
        error('Please uncomment "lpdf.registerfontmethod" in "lpdf-emb.lmt"!')
    end


    lpdf.registerfontmethod("rawpdf", function(filename, details)
        return
            details.properties.indexdata[1], -- Table of glyphs
            t3_scale, -- Scale factor to export the glyph at
            function(char) -- Code to convert the character to PDF
                return char.code, char.width / bp_to_sp / t3_scale / 10
            end,
            function() end, -- "Reset"
            function() end -- Add any used resources to the font dict
    end)


    --- Add the provided glyph to the current font.
    ---
    --- @param codepoint integer The Unicode codepoint to register
    --- @param unicode string The glyph as a Unicode string
    --- @param width number The width of the glyph in sp's
    --- @param height number The height of the glyph in sp's
    --- @param code string The raw PDF stream to use for the glyph
    --- @param id integer The font id
    make_glyph = function (codepoint, unicode, width, height, code, id)
        -- Data for this glyph
        local spec = {
            width   = width,
            height  = height,
            depth   = 0,
            unicode = { get_codepoint(unicode or "", 1, -1, true) },
            code = code,
        }
        -- Data for the original font
        local tfmdata = l_fonts.hashes.identifiers[id]

        -- Add the character metrics
        tfmdata.characters[codepoint] = spec

        -- Add the character drawing code
        l_fonts.dropins.swapone(
            "rawpdf",
            tfmdata,
            { code = spec },
            codepoint
        )

        -- Finally, add the character to the font
        l_fonts.constructors.addcharacters(
            id,
            { characters = { [codepoint] = spec } }
        )
    end


    make_fonts = function(pdf_name, characters)
        for fontname, characters in pairs(characters) do
            for slot, char in pairs(characters) do
                if char.codepoint then
                    make_glyph(
                        char.codepoint,
                        char.unicode,
                        char.width * bp_to_sp,
                        char.height * bp_to_sp,
                        char.char_obj,
                        id[pdf_name]
                    )
                end
            end
        end
    end


    load_font = memoized_table(function(pdf_font)
        return id[pdf_font]
    end)


    function make_scaled_char(font_id, codepoint, scale)
        -- Make the glyph
        local glyph = node.new("glyph")
        glyph.font = font_id
        glyph.char = codepoint
        glyph.xscale = 1000 * scale
        glyph.yscale = 1000 * scale

        return glyph
    end
end


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
                 chars[fontname][tostring(get_codepoint(char_name))]

    -- Directly write the glyph node into TeX's current list
    if char and char.codepoint then
        local char_nodes = make_scaled_char(
            load_font(fontname),
            char.codepoint,
            tex.sp("1ex") / SCALE_FACTOR
        )

        -- Inject the nodes
        tex.forcehmode()
        node.write(char_nodes)
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
if not context then
    luatexbase.add_to_callback(
        "provide_charproc_data",
        function (mode, font_id, slot)
            if mode == 2 then -- Mode 2 wants the PDF stream
                local char = fonts[font_id][slot]
                return
                    stream_object[char.char_obj],
                    char.width / 10 / t3_scale

            elseif mode == 3 then -- Mode 3 wants the font's overall scale factor
                return t3_scale
            end
        end,
        "unemoji"
    )
end


local unemoji = {
    chars = chars,
    get_font_path = get_font_path,
    load_font = load_font,
    make_glyph = make_glyph,
    print = print_char,
    register_tex_cmd = register_tex_cmd,
}

if context then
    thirddata.unemoji = unemoji
end

return unemoji
