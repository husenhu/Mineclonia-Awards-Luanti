-- Headless test for the rank auras (awards_mcl/effects.lua)
--
-- Run it as a worldmod (see docs/test_rewards.lua for the world setup):
--   worlds/<test>/worldmods/awards_test/init.lua  <- this file
--   load_mod_awards_mcl = true in world.mt
-- The test mocks the player object and captures particlespawner calls, so no
-- real client is needed.

local store = {}

local mock = {
	is_player = function() return true end,
	get_player_name = function() return "TestKiller" end,
	get_meta = function()
		return {
			get_int = function(_, k) return store[k] or 0 end,
			set_int = function(_, k, v) store[k] = v end,
			get_string = function(_, k) return tostring(store[k] or "") end,
			set_string = function(_, k, v) store[k] = v end,
		}
	end,
	get_pos = function() return vector.new(0, 10, 0) end,
	get_inventory = function()
		return { add_item = function(_, _, st) return ItemStack("") end }
	end,
	get_string = function() return "" end,
}

local added, deleted = {}, {}
local next_id = 0

local function install_mocks()
	core.add_particlespawner = function(def)
		next_id = next_id + 1
		added[#added + 1] = { id = next_id, def = def }
		return next_id
	end
	core.delete_particlespawner = function(id, player)
		deleted[#deleted + 1] = { id = id, player = player }
	end
end

-- Collect every texture that the engine already ships to clients through
-- item / node definitions. Particle textures must be part of this set,
-- otherwise clients would show a missing texture.
local function build_media_set()
	local media = {}
	local function one(t)
		if type(t) == "string" then
			media[t] = true
		elseif type(t) == "table" and type(t.name) == "string" then
			media[t.name] = true
		end
	end
	for _, def in pairs(core.registered_items) do
		if type(def.tiles) == "table" then
			for _, t in ipairs(def.tiles) do one(t) end
		end
		if type(def.overlay_tiles) == "table" then
			for _, t in ipairs(def.overlay_tiles) do one(t) end
		end
		one(def.inventory_image)
		one(def.wield_image)
	end
	return media
end

local VALID_BLEND = { alpha = true, clip = true, add = true, screen = true, sub = true }

-- PNG size reader: catches animated vertical strips that would otherwise be
-- rendered as one squashed texture when used without an animation table.
local TEXTURE_MODS = { "mcl_core", "mcl_nether", "mcl_ocean", "mcl_redstone", "mcl_redstone_torch" }

local function be32(s, i)
	local a, b, c, d = s:byte(i, i + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

local function texture_size(name)
	for _, mod in ipairs(TEXTURE_MODS) do
		local mp = core.get_modpath(mod)
		if mp then
			local f = io.open(mp .. "/textures/" .. name, "rb")
			if f then
				local head = f:read(24)
				f:close()
				if head and #head >= 24 then
					return be32(head, 17), be32(head, 21)
				end
			end
		end
	end
end

local function check_texture(t, ctx)
	assert(type(t) == "table" and type(t.name) == "string", ctx .. ": bad texture table")
	assert(t.name:match("%.png$"), ctx .. ": texture is not a .png: " .. tostring(t.name))
	if t.blend then
		assert(VALID_BLEND[t.blend], ctx .. ": invalid blend " .. tostring(t.blend))
	end
	if t.scale_tween then
		assert(#t.scale_tween == 2, ctx .. ": scale_tween needs 2 frames")
		for i, f in ipairs(t.scale_tween) do
			assert(type(f) == "table" and tonumber(f.x) and tonumber(f.y),
				ctx .. ": bad scale_tween frame " .. i)
		end
	end
	if t.alpha_tween then
		assert(#t.alpha_tween == 2, ctx .. ": alpha_tween needs 2 values")
	end
	if t.alpha then
		assert(type(t.alpha) == "number" and t.alpha >= 0 and t.alpha <= 1,
			ctx .. ": alpha out of range")
	end
end

local function check_range(v, ctx)
	if type(v) == "table" and v.min ~= nil then
		assert(type(v.min) == "number" and type(v.max) == "number",
			ctx .. ": bad range")
		assert(v.min <= v.max, ctx .. ": min > max")
	end
end

local function check_def(def, ctx)
	assert(def.time == 0, ctx .. ": spawner must be infinite (time = 0)")
	assert(type(def.amount) == "number" and def.amount >= 1, ctx .. ": bad amount")
	assert(type(def.glow) == "number" and def.glow >= 0 and def.glow <= 14,
		ctx .. ": glow must be 0..14")
	assert(def.texture or def.texpool, ctx .. ": missing texture/texpool")
	if def.texture then
		check_texture(def.texture, ctx)
	end
	if def.texpool then
		assert(#def.texpool >= 1, ctx .. ": empty texpool")
		for _, t in ipairs(def.texpool) do
			check_texture(t, ctx)
		end
	end
	check_range(def.exptime, ctx .. ".exptime")
	check_range(def.size, ctx .. ".size")
	check_range(def.bounce, ctx .. ".bounce")
	check_range(def.radius, ctx .. ".radius")
	if def.size and type(def.size) == "table" then
		assert(def.size.min > 0, ctx .. ": size must be > 0 for texture particles")
	end
end

core.after(3, function()
	install_mocks()

	local real_getpbn = core.get_player_by_name
	core.get_player_by_name = function(n)
		if n == "TestKiller" then
			return mock
		end
		return real_getpbn(n)
	end
	local real_level = mcl_experience.get_level
	mcl_experience.get_level = function(p)
		if p == mock then
			return mock.level or 0
		end
		return real_level(p)
	end
	local captured = {}
	core.show_formspec = function(name, formname, fs)
		captured[#captured + 1] = fs
		return true
	end

	local ok, err = pcall(function()
		local effects = awards_mcl.effects
		assert(effects, "effects module missing")
		local media = build_media_set()

		-- 1. Every rank 2..10 has a valid, distinct aura
		local names = {}
		for idx = 2, #awards_mcl.ranks do
			local defs = effects.definitions(idx)
			assert(defs and #defs >= 1, "rank " .. idx .. " has no effect")
			local name = effects.get_name(idx)
			assert(type(name) == "string" and name ~= "", "rank " .. idx .. " has no effect_name")
			assert(not names[name], "duplicate effect name: " .. name)
			names[name] = true

			local built = effects.build(idx, mock)
			assert(built and #built == #defs, "build() count mismatch for rank " .. idx)
			for n, def in ipairs(built) do
				local ctx = "rank " .. idx .. " (" .. name .. ") spawner " .. n
				check_def(def, ctx)
				assert(def.attached == mock, ctx .. ": not attached to the player")
				assert(def.playername == nil, ctx .. ": public by default")
			end
		end
		assert(effects.get_name(1) == nil, "Nothing rank must have no aura")
		assert(#effects.definitions(10) == 3, "Eternal must use 3 spawners")
		core.log("action", "[awards_test] 1. 9 rank auras valid (" ..
			table.concat({ "Debu Tanah", "Percikan Pasir", "Serpihan Batu",
				"Kilau Mineral", "Energi Kristal", "Aura Api", "Badai Petir",
				"Aura Dewa", "Supernova" }, ", ") .. ")")

		-- 2. Texture media check (textures must be known to the engine)
		for idx = 2, #awards_mcl.ranks do
			for n, def in ipairs(effects.definitions(idx)) do
				local list = {}
				if def.texture then list[#list + 1] = def.texture end
				if def.texpool then
					for _, t in ipairs(def.texpool) do list[#list + 1] = t end
				end
				for _, t in ipairs(list) do
					assert(media[t.name],
						"rank " .. idx .. " spawner " .. n .. ": texture not shipped to clients: " .. t.name)
					local w, h = texture_size(t.name)
					assert(w and h, "texture file not found: " .. t.name)
					if t.animation then
						local a = t.animation
						assert(a.type == "vertical_frames", t.name .. ": only vertical_frames is supported")
						assert(a.aspect_w and a.aspect_h, t.name .. ": animation needs aspect_w/aspect_h")
						assert(w % a.aspect_w == 0 and h % a.aspect_h == 0,
							t.name .. ": animation frame size does not divide the image")
					else
						assert(h <= w * 2,
							t.name .. ": looks like an animated strip but has no animation table")
					end
				end
			end
		end
		core.log("action", "[awards_test] 2. all particle textures are shipped media")

		-- 3. Apply / idempotence / rank change / clear
		effects.clear(mock)
		added, deleted = {}, {}
		assert(effects.update(mock, 2), "bronze update failed")
		local bronze_n = #effects.definitions(2)
		assert(#added == bronze_n, "bronze spawners not added")
		assert(added[1].def.attached == mock, "bronze spawner not attached")

		local count = #added
		assert(effects.update(mock, 2), "bronze re-update failed")
		assert(#added == count, "update must be idempotent")

		assert(effects.update(mock, 10), "eternal update failed")
		assert(#deleted == bronze_n, "old bronze spawners not deleted")
		local eternal_n = #effects.definitions(10)
		assert(#added == count + eternal_n, "eternal spawners not added")
		assert(#added == 1 + eternal_n, "expected one apply for eternal")

		assert(not effects.update(mock, 1), "rank 1 should not spawn")
		assert(#deleted == bronze_n + eternal_n, "eternal spawners not deleted")
		core.log("action", "[awards_test] 3. apply / idempotence / rank change / clear OK")

		-- 4. Private visibility: playername on add and on delete
		core.settings:set("awards_mcl.rank_effects_visibility", "self")
		added, deleted = {}, {}
		assert(effects.update(mock, 3), "private update failed")
		for _, a in ipairs(added) do
			assert(a.def.playername == "TestKiller", "private spawner has no playername")
		end
		effects.update(mock, 1)
		for _, d in ipairs(deleted) do
			assert(d.player == "TestKiller", "private spawner not deleted per player")
		end
		core.settings:set("awards_mcl.rank_effects_visibility", "all")
		core.log("action", "[awards_test] 4. private visibility OK")

		-- 5. Changing visibility while active re-applies the aura
		added, deleted = {}, {}
		assert(effects.update(mock, 4), "public update failed")
		local public_n = #added
		core.settings:set("awards_mcl.rank_effects_visibility", "self")
		assert(effects.update(mock, 4), "visibility switch failed")
		assert(#deleted == public_n, "old public spawners not deleted on switch")
		assert(#added == public_n * 2, "private spawners not added on switch")
		core.settings:set("awards_mcl.rank_effects_visibility", "all")
		effects.update(mock, 1)
		core.log("action", "[awards_test] 5. visibility switch re-applies OK")

		-- 6. Master switch
		added, deleted = {}, {}
		core.settings:set("awards_mcl.rank_effects", "false")
		assert(not effects.is_enabled(), "effects should be disabled")
		assert(not effects.update(mock, 5), "disabled update must not spawn")
		assert(#added == 0, "spawners added while disabled")
		core.settings:set("awards_mcl.rank_effects", "true")
		assert(effects.is_enabled(), "effects should be enabled again")
		core.log("action", "[awards_test] 6. master switch OK")

		-- 7. GUI shows the aura name for the selected rank
		local handler
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			captured = {}
			pcall(fn, mock, "awards_mcl:collection", { select_tab_xp = "" })
			if captured[1] and captured[1]:find("AWARD COLLECTION", 1, true) then
				handler = fn
				break
			end
		end
		assert(handler, "collection handler not found")

		mock.level = 100
		captured = {}
		handler(mock, "awards_mcl:collection", { select_rank_10 = "" })
		local fs = captured[#captured]
		assert(fs, "xp formspec not shown")
		assert(fs:find("Aura: ", 1, true), "aura label missing")
		assert(fs:find("Supernova", 1, true), "Eternal aura missing")

		captured = {}
		handler(mock, "awards_mcl:collection", { select_rank_2 = "" })
		fs = captured[#captured]
		assert(fs and fs:find("Debu Tanah", 1, true), "Bronze aura missing")
		core.log("action", "[awards_test] 7. GUI aura label OK")

		-- 8. /rank mentions the aura
		local cmd = core.registered_chatcommands["rank"]
		assert(cmd, "/rank missing")
		local okc, msg = cmd.func("TestKiller")
		assert(okc, "/rank failed: " .. tostring(msg))
		assert(msg:find("Aura:", 1, true), "/rank has no aura line")
		assert(msg:find("Supernova", 1, true), "/rank shows wrong aura")
		core.log("action", "[awards_test] 8. /rank aura line OK")

		-- Cleanup
		effects.update(mock, 1)
	end)

	if ok then
		core.log("action", "[awards_test] ALL EFFECT TESTS PASSED")
	else
		core.log("error", "[awards_test] FAILED: " .. tostring(err))
	end
	core.after(1, function() core.request_shutdown() end)
end)
