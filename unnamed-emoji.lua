-- Define some utility functions
local array = pdfe.arraytotable
local dict = pdfe.dictionarytotable
local pairs = pairs

local function ref(ref)
    return select(2, pdfe.getfromreference(ref[2]))
end

--- Creates a TeX command that evaluates a Lua function
---
--- @param name string The name of the csname to define
--- @param func function
--- @param args table<string> The TeX types of the function arguments
--- @return nil
local function register_tex_cmd(name, func, args)
    local scanning_func
    name = "__unemoji_" .. name .. ":" .. string.rep("n", #args)

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
local files = setmetatable({}, { __index = function(files, font)
    local chars = {}
    local doc = pdfe.open(font)

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
                    local key = key
                    local chars = chars
                    chars[key] = function()
                        local num = array(dict(ref(vvv)).D[2])[3][2]
                        local page = img.new {
                            filename = font,
                            page = tonumber(num)
                        }
                        chars[key] = function() return page end
                        return page
                    end
                end
            end
        end
    end

    files[font] = chars
    return chars
end })

local function emoji_load(font, char)
    return files[font][char]()
end

local function emoji_print(font, char)
    img.write(emoji_load(font, char))
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
