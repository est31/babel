-- Copyright (c) the babel mod author(s).
-- For detailed information about the authorship
-- see the README.md file and the version control log.
-- This source code is distributed under the terms
-- of the LGPL 2.1 license.

babel = {}

dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/mapgen.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/letter_placement.lua")

minetest.register_on_newplayer(function(player)
	local player_name = player:get_player_name()
	local privs = minetest.get_player_privs(player_name)
	privs["fly"] = true
	privs["fast"] = true
	minetest.set_player_privs(player_name, privs)
end)

minetest.register_on_joinplayer(function(player)
	player:get_inventory():set_size("main", 8)
	player:set_physics_override({
		gravity = 0,
	})
end)
