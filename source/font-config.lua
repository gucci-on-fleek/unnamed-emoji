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
--- @field licence string The licence text to inject into the PDF

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

        mp_scale = 0.069102923920223,

        licence = "Noto Emoji, Apache 2.0, GitHub:googlefonts/noto-emoji@934a5706."
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

        mp_scale = 0.23034513512007,

        licence = "Twitter Emoji, CC-BY 4.0, GitHub:twitter/twemoji@d94f4cf7."
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

        mp_scale = 0.016690725419491,

        licence = "FxEmojis, CC-BY 4.0, GitHub:mozilla/fxemoji@270af343."
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

        mp_scale = 0.14862871711128,

        licence = "OpenMoji, CC-BY-SA 4.0, GitHub:hfg-gmuend/openmoji@d6d0daad."
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

        mp_scale = 0.13678660479151,

        licence = "EmojiOne, CC-BY 4.0, GitHub:joypixels/emojione@v2.2.7."
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

        mp_scale = 0.29615803086866,

        keep_effects = true,

        licence = "Fluent Emoji, MIT, GitHub:microsoft/fluentui-emoji@dfb5c3b7."
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

            local unicode
            if metadata.unicodeSkintones then
                local tone <const> = file.nameonly(
                    file.collapsepath(dirname .. "/..")
                )
                unicode = metadata.unicodeSkintones[fluent_skin[tone]]
            else
                unicode = metadata.unicode
            end

            if unicode then
                return unicode:split(" ")
            else
                return {}
            end
        end,

        mp_scale = 0.29615803086866,

        licence = "Fluent Emoji, MIT, GitHub:microsoft/fluentui-emoji@dfb5c3b7."
    },

    ["noto-blob"] = {
        get_components = function(name)
            local components <const> = {}
            name = file.nameonly(name)
            for char in name:match("emoji_u(.*)$"):gmatch("[^_]+") do
                components[#components+1] = char
            end

            return components
        end,

        mp_scale = 0.065173101201993,

        licence = "Noto Emoji, Apache 2.0, GitHub:googlefonts/noto-emoji@8f0a65b1."
    },
}

return font[document.getargument("font")] or error("Unknown font")
