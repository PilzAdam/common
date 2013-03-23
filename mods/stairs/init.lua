-- Minetest 0.4 mod: stairs
-- See README.txt for licensing and other information.

stairs = {}

-- Use a modified version of minetest.item_place to be able to modify param2
-- returns itemstack, boolean if node was placed
local function item_place(itemstack, placer, pointed_thing, upside_down)
	-- Call on_rightclick if the pointed node defines it
	if pointed_thing.type == "node" and placer and
			not placer:get_player_control().sneak then
		local n = minetest.env:get_node(pointed_thing.under)
		local nn = n.name
		if minetest.registered_nodes[nn] and minetest.registered_nodes[nn].on_rightclick then
			return minetest.registered_nodes[nn].on_rightclick(pointed_thing.under, n, placer, itemstack)
		end
	end

	if itemstack:get_definition().type == "node" then
		local def = itemstack:get_definition()

		local under = pointed_thing.under
		local oldnode_under = minetest.env:get_node(under)
		local olddef_under = ItemStack({name=oldnode_under.name}):get_definition()
		olddef_under = olddef_under or minetest.nodedef_default
		local above = pointed_thing.above
		local oldnode_above = minetest.env:get_node(above)
		local olddef_above = ItemStack({name=oldnode_above.name}):get_definition()
		olddef_above = olddef_above or minetest.nodedef_default

		if not olddef_above.buildable_to and not olddef_under.buildable_to then
			minetest.log("info", placer:get_player_name() .. " tried to place"
				.. " node in invalid position " .. minetest.pos_to_string(above)
				.. ", replacing " .. oldnode_above.name)
			return itemstack
		end

		-- Place above pointed node
		local place_to = {x = above.x, y = above.y, z = above.z}

		-- If node under is buildable_to, place into it instead (eg. snow)
		if olddef_under.buildable_to then
			minetest.log("info", "node under is buildable to")
			place_to = {x = under.x, y = under.y, z = under.z}
		end

		minetest.log("action", placer:get_player_name() .. " places node "
			.. def.name .. " at " .. minetest.pos_to_string(place_to))
		
		local oldnode = minetest.env:get_node(place_to)
		local newnode = {name = def.name, param1 = 0, param2 = 0}

		-- Calculate direction for wall mounted stuff like torches and signs
		if def.paramtype2 == 'wallmounted' then
			local dir = {
				x = under.x - above.x,
				y = under.y - above.y,
				z = under.z - above.z
			}
			newnode.param2 = minetest.dir_to_wallmounted(dir)
		-- Calculate the direction for furnaces and chests and stuff
		elseif def.paramtype2 == 'facedir' then
			local placer_pos = placer:getpos()
			if placer_pos then
				local dir = {
					x = above.x - placer_pos.x,
					y = above.y - placer_pos.y,
					z = above.z - placer_pos.z
				}
				newnode.param2 = minetest.dir_to_facedir(dir)
				if upside_down then
					newnode.param2 = newnode.param2 + 20
					if newnode.param2 == 21 then
						newnode.param2 = 23
					elseif newnode.param2 == 23 then
						newnode.param2 = 21
					end
				end
				minetest.log("action", "facedir: " .. newnode.param2)
			end
		end

		-- Check if the node is attached and if it can be placed there
		if minetest.get_item_group(def.name, "attached_node") ~= 0 and
			not check_attached_node(place_to, newnode) then
			minetest.log("action", "attached node " .. def.name ..
				" can not be placed at " .. minetest.pos_to_string(place_to))
			return itemstack
		end

		-- Add node and update
		minetest.env:add_node(place_to, newnode)

		local take_item = true

		-- Run callback
		if def.after_place_node then
			-- Copy place_to because callback can modify it
			local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
			if def.after_place_node(place_to_copy, placer, itemstack) then
				take_item = false
			end
		end

		-- Run script hook
		local _, callback
		for _, callback in ipairs(minetest.registered_on_placenodes) do
			-- Copy pos and node because callback can modify them
			local place_to_copy = {x=place_to.x, y=place_to.y, z=place_to.z}
			local newnode_copy = {name=newnode.name, param1=newnode.param1, param2=newnode.param2}
			local oldnode_copy = {name=oldnode.name, param1=oldnode.param1, param2=oldnode.param2}
			if callback(place_to_copy, newnode_copy, placer, oldnode_copy, itemstack) then
				take_item = false
			end
		end

		if take_item then
			itemstack:take_item()
		end
		return itemstack, true
	end
	return itemstack
end

-- Node will be called stairs:stair_<subname>
function stairs.register_stair(subname, recipeitem, groups, images, description, sounds)
	minetest.register_node(":stairs:stair_" .. subname, {
		description = description,
		drawtype = "nodebox",
		tiles = images,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = groups,
		sounds = sounds,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0, 0.5},
				{-0.5, 0, 0, 0.5, 0.5, 0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, 0, 0.5},
				{-0.5, 0, 0, 0.5, 0.5, 0.5},
			},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end
			
			local p0 = pointed_thing.under
			local p1 = pointed_thing.above
			if p0.y-1 == p1.y then
				return item_place(itemstack, placer, pointed_thing, true)
			end
			
			-- Otherwise place regularly
			return minetest.item_place(itemstack, placer, pointed_thing)
		end,
	})
	
	minetest.register_node(":stairs:stair_" .. subname.."upside_down", {
		drop = "stairs:stair_" .. subname,
		drawtype = "nodebox",
		tiles = images,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = groups,
		sounds = sounds,
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0, -0.5, 0.5, 0.5, 0.5},
				{-0.5, -0.5, 0, 0.5, 0, 0.5},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0, -0.5, 0.5, 0.5, 0.5},
				{-0.5, -0.5, 0, 0.5, 0, 0.5},
			},
		},
	})

	minetest.register_craft({
		output = 'stairs:stair_' .. subname .. ' 4',
		recipe = {
			{recipeitem, "", ""},
			{recipeitem, recipeitem, ""},
			{recipeitem, recipeitem, recipeitem},
		},
	})

	-- Flipped recipe for the silly minecrafters
	minetest.register_craft({
		output = 'stairs:stair_' .. subname .. ' 4',
		recipe = {
			{"", "", recipeitem},
			{"", recipeitem, recipeitem},
			{recipeitem, recipeitem, recipeitem},
		},
	})
end

-- Node will be called stairs:slab_<subname>
function stairs.register_slab(subname, recipeitem, groups, images, description, sounds)
	minetest.register_node(":stairs:slab_" .. subname, {
		description = description,
		drawtype = "nodebox",
		tiles = images,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = true,
		groups = groups,
		sounds = sounds,
		node_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
		},
		selection_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5, 0.5, 0, 0.5},
		},
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end

			-- If it's being placed on an another similar one, replace it with
			-- a full block
			local slabpos = nil
			local slabnode = nil
			local p0 = pointed_thing.under
			local p1 = pointed_thing.above
			local n0 = minetest.env:get_node(p0)
			if n0.name == "stairs:slab_" .. subname and
					p0.y+1 == p1.y and not (n0.param2>=20 and n0.param2<=23) then
				slabpos = p0
				slabnode = n0
			end
			if slabpos then
				-- Remove the slab at slabpos
				minetest.env:remove_node(slabpos)
				-- Make a fake stack of a single item and try to place it
				local fakestack = ItemStack(recipeitem)
				pointed_thing.above = slabpos
				fakestack, placed = item_place(fakestack, placer, pointed_thing)
				-- If the item was placed set the count of itemstack
				if placed then
					itemstack:take_item(1-fakestack:get_count())
				-- Else put old node back
				else
					minetest.env:set_node(slabpos, slabnode)
				end
				return itemstack
			end
			
			-- Upside down slabs
			if p0.y-1 == p1.y then
				-- Turn into full block if pointing at a existing slab
				if n0.name == "stairs:slab_" .. subname.."upside_down" or
						(n0.param2>=20 and n0.param2<=23 and n0.name=="stairs:slab_"..subname) then
					-- Remove the slab at the position of the slab
					minetest.env:remove_node(p0)
					-- Make a fake stack of a single item and try to place it
					local fakestack = ItemStack(recipeitem)
					pointed_thing.above = p0
					fakestack, placed = item_place(fakestack, placer, pointed_thing)
					-- If the item was placed set the count of itemstack
					if placed then
						itemstack:take_item(1-fakestack:get_count())
					-- Else put old node back
					else
						minetest.env:set_node(p0, n0)
					end
					return itemstack
				end
				
				-- Place upside down slab
				return item_place(itemstack, placer, pointed_thing, true)
			end
			
			-- If pointing at the side of a upside down slab
			if (n0.name == "stairs:slab_" .. subname.."upside_down" or
					(n0.param2 >= 20 and n0.param2 <= 23)) and
					p0.y+1 ~= p1.y then
				-- Place upside down slab
				return item_place(itemstack, placer, pointed_thing, true)
			end
			
			-- Otherwise place regularly
			return minetest.item_place(itemstack, placer, pointed_thing)
		end,
	})
	
	minetest.register_node(":stairs:slab_" .. subname.."upside_down", {
		drop = "stairs:slab_"..subname,
		drawtype = "nodebox",
		tiles = images,
		paramtype = "light",
		is_ground_content = true,
		groups = groups,
		sounds = sounds,
		node_box = {
			type = "fixed",
			fixed = {-0.5, 0, -0.5, 0.5, 0.5, 0.5},
		},
		selection_box = {
			type = "fixed",
			fixed = {-0.5, 0, -0.5, 0.5, 0.5, 0.5},
		},
	})

	minetest.register_craft({
		output = 'stairs:slab_' .. subname .. ' 6',
		recipe = {
			{recipeitem, recipeitem, recipeitem},
		},
	})
end

-- Nodes will be called stairs:{stair,slab}_<subname>
function stairs.register_stair_and_slab(subname, recipeitem, groups, images, desc_stair, desc_slab, sounds)
	stairs.register_stair(subname, recipeitem, groups, images, desc_stair, sounds)
	stairs.register_slab(subname, recipeitem, groups, images, desc_slab, sounds)
end

stairs.register_stair_and_slab("wood", "default:wood",
		{snappy=2,choppy=2,oddly_breakable_by_hand=2,flammable=3},
		{"default_wood.png"},
		"Wooden Stair",
		"Wooden Slab",
		default.node_sound_wood_defaults())

stairs.register_stair_and_slab("stone", "default:stone",
		{cracky=3},
		{"default_stone.png"},
		"Stone Stair",
		"Stone Slab",
		default.node_sound_stone_defaults())

stairs.register_stair_and_slab("cobble", "default:cobble",
		{cracky=3},
		{"default_cobble.png"},
		"Cobble Stair",
		"Cobble Slab",
		default.node_sound_stone_defaults())

stairs.register_stair_and_slab("brick", "default:brick",
		{cracky=3},
		{"default_brick.png"},
		"Brick Stair",
		"Brick Slab",
		default.node_sound_stone_defaults())

stairs.register_stair_and_slab("sandstone", "default:sandstone",
		{crumbly=2,cracky=2},
		{"default_sandstone.png"},
		"Sandstone Stair",
		"Sandstone Slab",
		default.node_sound_stone_defaults())

stairs.register_stair_and_slab("junglewood", "default:junglewood",
		{snappy=2,choppy=2,oddly_breakable_by_hand=2,flammable=3},
		{"default_junglewood.png"},
		"Junglewood Stair",
		"Junglewood Slab",
		default.node_sound_wood_defaults())

stairs.register_stair_and_slab("stonebrick", "default:stonebrick",
		{cracky=3},
		{"default_stone_brick.png"},
		"Stone Brick Stair",
		"Stone Brick Slab",
		default.node_sound_stone_defaults())
