-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

local json = require("util-jsn")

--------------------------
--- Font-specific code ---
--------------------------
-- Each font has a different naming convention and glyph sizes, so we need some
-- custom code for each font to normalize all this.

local fluent_skin = {
    Default = 1,
    Light = 2,
    ["Medium-Light"] = 3,
    Medium = 4,
    ["Medium-Dark"] = 5,
    Dark = 6,
}


--- @class font
--- @field get_components fun(name: string): table<string>
---     Converts a filename into a table of hex-encoded Unicode codepoints.
--- @field mp_scale number The scaling factor to apply to the MetaPost code
--- @field keep_effects boolean? Whether to retain shadings/transparencies

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

    ["fluent-color"] = { -- Mostly broken...
    get_components = function(name)
        if not file.nameonly(name):match("_color") then
            return {}
        end

        local dirname <const> = file.dirname(name)

        local metadata = json.load(
            file.collapsepath(dirname .. "/../metadata.json")
        ) or json.load(
            file.collapsepath(dirname .. "/../../metadata.json")
        )

        if metadata.unicodeSkintones then
            local tone <const> = file.nameonly(
                file.collapsepath(dirname .. "/..")
            )
            return metadata.unicodeSkintones[fluent_skin[tone]]:split(" ")
        else
            return metadata.unicode:split(" ")
        end
    end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 32,

        keep_effects = true,
    },

    ["fluent-flat"] = {
        get_components = function(name)
            if not file.nameonly(name):match("_flat") then
                return {}
            end

            local dirname <const> = file.dirname(name)

            local metadata = json.load(
                file.collapsepath(dirname .. "/../metadata.json")
            ) or json.load(
                file.collapsepath(dirname .. "/../../metadata.json")
            )

            if metadata.unicodeSkintones then
                local tone <const> = file.nameonly(
                    file.collapsepath(dirname .. "/..")
                )
                return metadata.unicodeSkintones[fluent_skin[tone]]:split(" ")
            else
                return metadata.unicode:split(" ")
            end
        end,

        mp_scale = tex.sp("10pt") / tex.sp("1bp") / 32,
    },
}

return font[document.getargument("font")] or error("Unknown font")
