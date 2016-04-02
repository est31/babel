-- Copyright (c) the babel mod author(s).
-- For detailed information about the authorship
-- see the README.md file and the version control log.
-- This source code is distributed under the terms
-- of the LGPL 2.1 license.

minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_params({mgname='singlenode', water_level=-32000})
end)

minetest.register_on_generated(function(minp, maxp, blockseed)
	if minp.x <= 0 and minp.y <= 0 and minp.z <= 0 and
			maxp.x >= 0 and maxp.y >= 0 and maxp.z >= 0 then
		minetest.set_node(vector.new(0, 0, 0), { name = "letters:a_glowing" })
	end
end)
