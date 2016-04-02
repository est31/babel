-- Copyright (c) the "default" mod author(s).
-- For detailed information about the authorship
-- see the README.md file and the version control log.
-- This source code is distributed under the terms
-- of the LGPL 2.1 license.

-- Very minimal default init.lua

minetest.register_item(":", {
	type = "none",
	wield_image = "wield_hand.png",
	wield_scale = vector.new(1, 1, 2.5),
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {times = {[2] = 3.00, [3] = 0.70}, uses = 0, maxlevel = 1},
			snappy = {times = {[3] = 0.40}, uses = 0, maxlevel = 1},
			oddly_breakable_by_hand = {times = {[1] = 3.50, [2] = 2.00, [3] = 0.70}, uses = 0}
		},
		damage_groups = {fleshy=1},
	}
})

default = {}

dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/player.lua")
