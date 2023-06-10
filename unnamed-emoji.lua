-- Define some utility functions
local array = pdfe.arraytotable
local dict = pdfe.dictionarytotable
local pairs = pairs

local function ref(ref)
    return select(2, pdfe.getfromreference(ref[2]))
end

local l_type = type
local function type(val)
    local meta = getmetatable(val)
    if meta and meta.__name then
        return meta.__name
    else
        return l_type(val)
    end
end

--- Creates a TeX command that evaluates a Lua function
---
--- @param name string The name of the csname to define
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

-- Define the main font loading command
local fonts = setmetatable({}, { __index = function(fonts, filename)
    local doc = pdfe.open(filename)
    local internal = {}

    for number, page in pairs(doc.Pages) do
        local name, reference = next(dict(page.Resources.Font))
        internal[name] = {
            dict(ref(dict(ref(reference)).CharProcs)),
            array(ref(dict(ref(reference)).Widths)),
        }
    end

    local font = setmetatable({ __internal = internal }, { __index = function(used_fonts, packed)
        local name, char = table.unpack(packed)
        local char_procs, widths = table.unpack(internal[name])

        local char_ref = pdf.immediateobj(
            "stream",
            pdfe.readwholestream(ref(char_procs["I" .. char]), true) .. ""
        )

        local ret = { char_ref, widths[tonumber(char)][2] }
        used_fonts[packed] = ret
        return ret
    end })

    fonts[filename] = font
    return font
end })

local chars = setmetatable({}, { __index = function(chars, filename)
    local font = {}
    local doc = pdfe.open(filename)

    local t = array(doc.Catalog.Names.Dests.Kids)

    for _, v in pairs(t) do
        local tt = array(ref(v).Kids)
        for _, vv in pairs(tt) do
            local ttt = array(dict(ref(vv)).Names[2])
            local key = ""
            for _, vvv in pairs(ttt) do
                if type(vvv[2]) == "string" then
                    key = vvv[2]:match("emoji(.*)$")
                else
                    local char = {}
                    local page = ref(array(dict(ref(vvv)).D[2])[1])
                    char[1] = next(dict(page.Resources.Font))
                    char[2] = tonumber(
                        pdfe.readwholestream(page.Contents, true)
                            :match("<(..)>"),
                        16
                    )

                    font[key] = char
                end
            end
        end
    end

    -- inspect(font)
    chars[filename] = font
    return font
end })

local function emoji_load(font, char)
    -- char = chars[font][char]
    -- font = fonts[font][char]

    -- print(font, char)
    -- inspect(char)
    -- return ref { nil, font }
    return font
end

local function emoji_print(font, char)
    -- local emoji = emoji_load(font, char)
    -- print(emoji)
    -- print(pdf.getpageresources())
end

register_tex_cmd(
    "load",
    emoji_load,
    { "string", "string" }
)

register_tex_cmd(
    "print",
    emoji_print,
    { "string", "string" }
)

local base_char = {
    width = tex.sp("10bp"),
    height = tex.sp("10bp"),
    depth = 0,
}

local ids = {}
local type3s = setmetatable({}, { __index = function(t, k)
    if type(k) == "string" then
        local characters = {}
        for i = 1,255 do
            characters[i] = base_char
        end

        local id = font.define {
            name = "unemoji-" .. k,
            parameters = {},
            properties = {},
            characters = characters,
            encodingbytes = 0,
            psname = "none",
        }

        ids[#ids+1] = { id = id }
        local ret = { #ids, id }
        t[k] = ret
        return ret
    elseif type(k) == "number" then
        for kk, vv in pairs(t) do
            if vv[2] == k then
                return kk
            end
        end
    end
end })

do
    local characters = {}
    for char, val in pairs(chars["noto-emoji.pdf"]) do
        char = tonumber(char)
        if char then
            local data = table.copy(base_char)
            data.commands = { { "slot", type3s[val[1]][1], val[2] } }
            characters[char] = data
        end
    end

    token.set_char("unemojifont", font.define {
        name = "unemojifont",
        parameters = {},
        characters = characters,
        properties = {},
        type = "virtual",
        fonts = ids
    })
end

luatexbase.add_to_callback("provide_charproc_data", function (mode, id, char)
    if mode == 2 then
        local font = "noto-emoji.pdf"
        char = tostring(char)
        local char_ref, width = table.unpack(fonts[font][{type3s[id], char}])
        return char_ref, width
    elseif mode == 3 then
        return 0.08
    end
end, "unemoji")
