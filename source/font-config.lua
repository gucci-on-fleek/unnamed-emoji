-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

--------------------------
--- Font-specific code ---
--------------------------
-- Each font has a different naming convention and glyph sizes, so we need some
-- custom code for each font to normalize all this.

--- @class font
--- @field get_components fun(name: string): table<string>
---     Converts a filename into a table of hex-encoded Unicode codepoints.
--- @field mp_scale number The scaling factor to apply to the MetaPost code

--- @type table<string, font>
local font = {
    ["noto-emoji"] = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name)
            for char in name:match("emoji_u(.*)$"):gmatch("[^_]+") do
                components[#components+1] = char
            end

            return components
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 128,
    },

    twemoji = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name)
            for char in name:gmatch("[^-]+") do
                components[#components+1] = char
            end

            return components
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 48,
    },

    fxemoji = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name):match("u(%x*)%-")
            if not name then
                return {}
            end

            for char in name:gmatch("[^-]+") do
                components[#components+1] = char:lower()
            end

            return components
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 512,
    },

    openmoji = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name)
            for char in name:gmatch("[^-]+") do
                components[#components+1] = char:lower()
            end

            return components
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 72,
    },

    emojione = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name)
            for char in name:gmatch("[^-]+") do
                components[#components+1] = char
            end

            return components
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 74,
    },
}

return font[document.getargument("font")] or error("Unknown font")
