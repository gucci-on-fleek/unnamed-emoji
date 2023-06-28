#!/usr/bin/env texlua

-- unnamed-emoji
-- https://github.com/gucci-on-fleek/unnamed-emoji
-- SPDX-License-Identifier: MPL-2.0+
-- SPDX-FileCopyrightText: 2023 Max Chernoff

local insert = table.insert

local exec_name = arg[1]
local out_dir = arg[2]
local in_name = arg[3]

local country, region = in_name:match("(%u%u)%-?([^.]*)%.svg$")

local codes = {}
if region ~= "" then
    insert(codes, 0x1f3f4)
    for _, code in utf8.codes((country .. region):lower()) do
        insert(codes, 0xe0000 + code)
    end
    insert(codes, 0xe007f)
else
    for _, code in utf8.codes(country) do
        insert(codes, 0x1f1a5 + code)
    end
end

local out_file = out_dir .. "/" .. "emoji_u"
for i, code in ipairs(codes) do
    local sep = i == 1 and "" or "_"
    out_file = out_file .. string.format(sep .. "%04x", code)
end
out_file = out_file .. ".svg"

os.execute(
    "python3 " ..
    exec_name .. " " ..
    "--viewbox_size 128 " ..
    "--width 126 " ..
    "--height 86 " ..
    "--right_margin 1 " ..
    "--top_margin 21 " ..
    in_name .. "  " ..
    "--out_file " ..
    out_file
)
