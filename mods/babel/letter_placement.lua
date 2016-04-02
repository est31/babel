-- Copyright (c) the babel mod author(s).
-- For detailed information about the authorship
-- see the README.md file and the version control log.
-- This source code is distributed under the terms
-- of the LGPL 2.1 license.


local astore = AreaStore()
local unfinished_words = {}
legal_words_dict = {}

local unfinished_words_path = minetest.get_worldpath() .. "/babel_unfinished_words.dat"
local legal_words_dict_default_path = minetest.get_modpath(minetest.get_current_modname()) .. "/sowpods.txt"

-- Length that is guaranteed to be too long for a given word
local generally_too_long_word = 16

local function load_uwords_from_file()
	local f = io.open(unfinished_words_path, "r")
	if f then
		local b = f:read("*all")
		local nuw = minetest.deserialize(b)
		if nuw then
			unfinished_words = nuw
		end
		f:close()
	end
end


local function save_uwords_to_file()
	local f = io.open(unfinished_words_path, "w")
	if f then
		f:write(minetest.serialize(unfinished_words))
		f:close()
	end
end

local function load_legal_words_from_file()
	local path = minetest.setting_get("babel_dictionary_path")
	if not path or path == "" then
		path = legal_words_dict_default_path
	end
	local f = io.open(path, "r")
	if f then
		while true do
			local line = f:read("*line")
			if not line then
				break
			end
			legal_words_dict[line:lower()] = true
		end
		f:close()
	end
end

minetest.after(.1, function()
	load_uwords_from_file()
	load_legal_words_from_file()
end)

minetest.register_on_shutdown(save_uwords_to_file)
-- TODO save them in regular intervals too, to not have problems when mt crashes

local function is_word_legal(word)
	return legal_words_dict[word]
end

local function get_letter_from_node_name(nname)
	if string.sub(nname, 1, 8) == "letters:" and string.len(nname) >= 9 then
		return string.sub(nname, 9, 9)
	end
	return nil
end

local function get_is_building_from_node_name(nname)
	return string.find(nname, "_building")
end

local function get_letter_for_pos(pos)
	local n = minetest.get_node_or_nil(pos)
	if n then
		return get_letter_from_node_name(n.name)
	end
	return nil
end

-- returns the word placed in the world in the directory of vec.
-- vec_back should be in the opposite direction of vec.
local function get_word_in_vec_dir(pos, vec_back, vec, letter_name, gl4p)
	-- First go back to the beginning of the word.
	local pre_word = ""
	local b = pos
	local c = ""
	while true do
		b = vector.add(b, vec_back)
		c = gl4p(b)
		if not c then break end
		pre_word = pre_word .. c
	end
	-- Now start walking into the actual direction.
	local word = ""
	b = pos
	while true do
		b = vector.add(b, vec)
		c = gl4p(b)
		if not c then break end
		word = word .. c
	end
	--print("'" .. string.reverse(pre_word) .. "','" .. letter_name .. "','" .. word .. "'")
	return string.reverse(pre_word) .. letter_name .. word
end

local function does_letter_generate_legal_words(letter_name, pos, gl4p)
	-- Find out whether a letter with letter_name placed at pos
	-- would generate legal words all around it.

	-- Returns:
	-- * true, if all words in all 3 directions fit
	-- * nil, if words in 2 directions fit (one non fitting one)
	-- * false, otherwise

	-- Single letter "words" are considered "fitting", but if
	-- in all directions the word length is 1, false is returned.

	local xword = get_word_in_vec_dir(pos, {x = -1, y = 0, z = 0}, {x = 1, y = 0, z = 0}, letter_name, gl4p)
	local yword = get_word_in_vec_dir(pos, {x = 0, y = 1, z = 0}, {x = 0, y = -1, z = 0}, letter_name, gl4p)
	local zword = get_word_in_vec_dir(pos, {x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1}, letter_name, gl4p)

	--print("xw: '" .. xword .. "' yw: '" .. yword .. "' zw: '" .. zword .. "'")

	local x_fits = xword:len() == 1 or is_word_legal(xword)
	local y_fits = yword:len() == 1 or is_word_legal(yword)
	local z_fits = zword:len() == 1 or is_word_legal(zword)

	local num_fitting_words = (x_fits and 1 or 0) + (y_fits and 1 or 0) + (z_fits and 1 or 0)
	local max_len = math.max(xword:len(), yword:len(), zword:len())

	--print("x_fits: " .. dump(x_fits) .. " yfits: " .. dump(y_fits) .. " zfits: " .. dump(z_fits))

	if max_len == 1 then
		return false
	end
	if num_fitting_words == 3 then
		return true
	end
	if num_fitting_words == 2 then
		return nil
	end
	return false
end

local function pos_belongs_to_uw(pos, unfinished_word)
	-- pos must share all coords with each unfinished word's letter,
	-- but one. If all already existing unfinished word letters were
	-- checked by this method, they are already on a line, so if we
	-- check now, we ensure that pos is on the same line as all letters
	-- from the unfinished word.
	-- Also, pos must be sufficiently close.
	-- If these two conditions are provided, we return true, otherwise false.
	for i, ipos in pairs(unfinished_word) do
		local d = vector.subtract(ipos, pos)
		local num_of_unshared_coords = (d.x == 0 and 0 or 1) +
			(d.y == 0 and 0 or 1) + (d.z == 0 and 0 or 1)
		if (num_of_unshared_coords > 1) or
				(vector.length(d) >= generally_too_long_word) then
			return false
		end
	end
	return true
end

local function place_words(placer_name)
	-- Convert all the building nodes to built ones.
	-- Make extra sure that only valid words get created.
	local uw = unfinished_words[placer_name]
	local map_data_unavail = false
	local found_foreign_unfinished_word = false
	local positions_to_finish = {}
	local gl4p = function(pos)
		local n = minetest.get_node_or_nil(pos)
		if n then
			if get_is_building_from_node_name(n.name) then
				local idx = nil
				for i, ipos in pairs(uw) do
					if vector.equals(pos, ipos) then
						idx = i
					end
				end
				if not idx then
					found_foreign_unfinished_word = true
				else
					positions_to_finish[idx] = { p = pos, n = get_letter_from_node_name(n.name) }
				end
			end
			return get_letter_from_node_name(n.name)
		end
		return nil
	end
	local found_non_legal_words = false
	for i, ipos in pairs(uw) do
		local glw = does_letter_generate_legal_words(gl4p(ipos), ipos, gl4p)
		if glw ~= true then
			found_non_legal_words = true
		end
	end

	if found_foreign_unfinished_word or found_non_legal_words then
		minetest.chat_send_player(pname, "Sorry, illegal move.")
		return
	end

	if map_data_unavail then
		minetest.chat_send_player(pname, "Sorry, map data not available.")
		return
	end

	-- Okay now do the actual conversion

	local new_uw = {}
	for i, ipos in ipairs(uw) do
		if not positions_to_finish[i] then
			table.insert(new_uw, ipos)
		end
	end
	unfinished_words[placer_name] = new_uw

	local num_pos = 0
	for i, v in ipairs(positions_to_finish) do
		-- TODO take care of glowing building one too
		minetest.swap_node(v.p, { name = "letters:" .. v.n })
		num_pos = num_pos + 1
	end

	-- TODO add num_pos new many items to the rack
	-- TODO increase score

	minetest.chat_send_player(placer_name, "Congrats, you placed a legal word!")
end

function babel.on_place_letter(letter_name, ldef, itemstack, placer, pointed_thing)
	if not ldef.building then
		return minetest.item_place(itemstack, placer, pointed_thing)
	end
	local pname = placer:get_player_name()
	local uw = unfinished_words[pname]
	-- TODO: don't guess the pos that minetest.item_place choses for placing
	-- the item, but use a method that gives the pos directly
	local pos_to_place = pointed_thing.above
	if uw then
	minetest.chat_send_player(pname, "Hello! " .. minetest.pos_to_string(pos_to_place))
		if not pos_belongs_to_uw(pos_to_place, uw) then
			minetest.chat_send_player(pname, "Illegal move. There is an unfinished word near " .. minetest.pos_to_string(uw[1]))
			return itemstack
		end
		local r = does_letter_generate_legal_words(letter_name, pos_to_place, get_letter_for_pos)
		if r or r == nil then
			local rstack, succ = minetest.item_place(itemstack, placer, pointed_thing)
			if succ then
				table.insert(unfinished_words[pname], pos_to_place)
			end
			if r == true then
				minetest.after(.1, function() place_words(pname) end)
			end
			return rstack
		end
		if r == false then
			minetest.chat_send_player(pname, "Sorry, illegal move. You wouldn't create valid words.")
			return rstack
		end
	else
		local rstack, succ = minetest.item_place(itemstack, placer, pointed_thing)
		if succ then
			unfinished_words[pname] = {}
			table.insert(unfinished_words[pname], pos_to_place)
		end
		return rstack
	end
end

letters.on_place_letter = babel.on_place_letter

function babel.on_destruct_building_letter(letter_name, ldef, pos)
	local m = minetest.get_meta(pos)
	local placer = m:get_string("plc")
	local unfinished_word = unfinished_words[placer]
	local idx = nil
	for i, ipos in pairs(unfinished_word) do
		if vector.equals(pos, ipos) then
			idx = i
		end
	end
	table.remove(unfinished_word, idx)
end

letters.on_destruct_building_letter = babel.on_destruct_building_letter

function babel.after_place_letter(letter_name, ldef, pos, placer, itemstack, pointed_thing)
	local m = minetest.get_meta(pos)
	m:set_string("plc", placer:get_player_name())
end

letters.after_place_letter = babel.after_place_letter
