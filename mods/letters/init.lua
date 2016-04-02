-- Copyright (c) the letters mod authors.
-- For detailed information about the authorship
-- see the README.md file and the version control log.
-- This source code is distributed under the terms
-- of the LGPL 2.1 license.

letters = {}

letters.on_place_letter = function() end
letters.on_destruct_building_letter = function() end
letters.after_place_letter = function() end

local function register_letter(letter_name, def)
	local ldef = def
	if not ldef then
		ldef = {}
	end
	local ndef = {
		stack_max = 1,
		groups = {},
		on_place = function(itemstack, placer, pointed_thing)
			letters.on_place_letter(letter_name, ldef, itemstack, placer, pointed_thing)
		end,
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			letters.after_place_letter(letter_name, ldef, pos, placer, itemstack, pointed_thing)
		end,
	}

	local kind_name_append = ""
	if ldef.building then
		kind_name_append = kind_name_append .. "_building"
		ndef.groups.oddly_breakable_by_hand = 3
		ndef.on_destruct = function(pos)
			letters.on_destruct_building_letter(letter_name, ldef, pos)
		end
	end
	local tbase
	if ldef.glowing then
		kind_name_append = kind_name_append .. "_glowing"
		ndef.light_source = 13
		tbase = "letters_mese_lamp.png"
	elseif ldef.building then
		tbase = "letters_acacia_wood.png"
	else
		tbase = "letters_pine_wood.png"
	end
	local tletter = tbase .. "^letters_letter_" ..
		letter_name .. ".png"
	ndef.tiles = { tletter, tletter, tletter, tletter, tletter, tletter }
	minetest.register_node("letters:" .. letter_name .. kind_name_append, ndef)
end

local letter_list = {
	"a", "b", "c", "d", "e",
	"f", "g", "h", "i", "j",
	"k", "l", "m", "n", "o",
	"p", "q", "r", "s", "t",
	"u", "v", "w", "x", "y",
	"z"
}

for _,l in pairs(letter_list) do
	register_letter(l)
	register_letter(l, { building = true })
end

register_letter("a", {glowing = true})
