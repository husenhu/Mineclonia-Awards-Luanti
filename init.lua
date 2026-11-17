-- MCL Awards — XP-level rank medals for Mineclonia
-- Ranks are derived from the XP level shown between the health and hunger bars.
--
-- Display:
--   * Above the head : bitmap medal floating above the nametag + nametag
--                      becomes "[Level Tier] <Name>" in the rank color.
--                      (nametags are plain text — a bitmap cannot be embedded)
--   * Chat           : "[Level Tier] <Name> message" in the rank color.
--
-- The medal entity follows its player every step (no set_attach) so it is
-- reliably visible to other clients on all engine versions.

local modname = core.get_current_modname()
local S = core.get_translator and core.get_translator(modname) or function(s) return s end

awards_mcl = {}

local chat_tag_enabled = core.settings:get_bool("awards_mcl.chat_tag", true)
local head_medal_enabled = core.settings:get_bool("awards_mcl.head_medal", true)
local fanfare_enabled = core.settings:get_bool("awards_mcl.rankup_fanfare", true)

local last_inv_base = {} -- player name -> base inventory formspec last built

-- ---------------------------------------------------------------------------
-- Rank table (index 1 = lowest). Order must go from lowest to highest.
-- ---------------------------------------------------------------------------

local ranks = {
	{ name = "Nothing",     level = 0,   color = "#FFFFFF", texture = nil },                  -- no medal at all
	{ name = "Bronze",      level = 5,   color = "#DA9A3C", texture = "awards_mcl_bronze.png" },
	{ name = "Silver",      level = 10,  color = "#D8DCE0", texture = "awards_mcl_silver.png" },
	{ name = "Gold",        level = 15,  color = "#FFD74A", texture = "awards_mcl_gold.png" },
	{ name = "Diamond",     level = 20,  color = "#4AEDD9", texture = "awards_mcl_diamond.png" },
	{ name = "Netherite",   level = 30,  color = "#9C8E95", texture = "awards_mcl_netherite.png" },
	{ name = "Veteran",     level = 40,  color = "#6FD7FF", texture = "awards_mcl_veteran.png" },
	{ name = "Immortal",    level = 55,  color = "#D3A4FF", texture = "awards_mcl_immortal.png" },
	{ name = "Untouchable", level = 75,  color = "#C05AFF", texture = "awards_mcl_untouchable.png" },
	{ name = "Eternal",     level = 100, color = "#FFD93B", texture = "awards_mcl_eternal.png" },
}
awards_mcl.ranks = ranks

-- Badge shown inside nametags and chat.
local GLYPH = "★"

local function rank_index_for_level(level)
	local idx = 1
	for i, r in ipairs(ranks) do
		if level >= r.level then
			idx = i
		end
	end
	return idx
end

local function rank(idx)
	return ranks[idx]
end

-- ---------------------------------------------------------------------------
-- Medal sprite (bitmap) floating above the nametag — follows every step
--
-- One entity definition per rank: the texture is part of initial_properties,
-- so every client receives the final texture with the object-add packet.
-- (Changing textures/visibility via set_properties after creation is exactly
-- the kind of property update that some clients fail to apply.)
-- ---------------------------------------------------------------------------

local MEDAL_Y_OFFSET = 2.85   -- above the feet; nametag sits at ~2.3
local MEDAL_SIZE_W    = 0.30  -- texture is 40x80, height keeps the aspect

local MEDAL_PROPS = {
	visual               = "sprite",
	physical             = false,
	collide_with_objects = false,
	pointable            = false,
	static_save          = false,
	is_visible           = true,
	glow                 = 1,
	visual_size          = { x = MEDAL_SIZE_W, y = MEDAL_SIZE_W * 2, z = MEDAL_SIZE_W },
	nametag              = "",
}

-- Register one luaentity per rank. The texture lives in initial_properties so
-- every client receives the final texture straight from the object-add packet
-- (no set_properties updates afterwards).
for _, r in ipairs(ranks) do
	if r.texture then
		local props = table.copy(MEDAL_PROPS)
		props.textures = { r.texture }
		core.register_entity("awards_mcl:medal_" .. r.name:lower(), {
			initial_properties = props,
			on_activate = function(self, staticdata, dtime_s)
				-- Purely visual sprite: cannot be attacked / used for anything
				self.object:set_armor_groups({ immortal = 1 })
			end,
		})
	end
end

-- Register the medal as an item so Luanti's engine is forced to load its texture
for _, r in ipairs(ranks) do
	if r.texture then
		core.register_craftitem("awards_mcl:item_" .. r.name:lower(), {
			description = S("@1 Medal", r.name),
			inventory_image = r.texture,
			groups = { not_in_creative_inventory = 1 },
		})
	end
end

local medal_by_player = {} -- player name -> luaentity (last_pos mirrors player pos)

local function remove_medal(player_name)
	local ent = medal_by_player[player_name]
	medal_by_player[player_name] = nil
	if ent and ent.object then
		pcall(ent.object.remove, ent.object)
	end
end

local function medal_defname(r)
	return "awards_mcl:medal_" .. r.name:lower()
end

local function update_medal(player, idx)
	local name = player:get_player_name()
	local r = rank(idx)

	-- "Nothing" tier: no medal at all
	if not head_medal_enabled or not r.texture then
		remove_medal(name)
		return
	end

	local defname = medal_defname(r)
	local ent = medal_by_player[name]

	-- Create (or re-create) when missing, dead, or of the wrong rank.
	if not ent or not ent.object or not ent.object:get_pos() or ent.awards_def ~= defname then
		remove_medal(name)
		local pos = player:get_pos()
		if not pos then
			return
		end
		local obj = core.add_entity(vector.offset(pos, 0, MEDAL_Y_OFFSET, 0), defname)
		if not obj then
			return
		end
		ent = obj:get_luaentity()
		if not ent then
			return
		end
		ent.awards_def = defname
		medal_by_player[name] = ent
	end
end

-- ---------------------------------------------------------------------------
-- Nametag: "<star> <Name>" colored like the rank (visible to everyone)
-- ---------------------------------------------------------------------------

local DEFAULT_TAG_COLOR = { r = 255, g = 255, b = 255, a = 255 }

local current_tag_text = {} -- player name -> last text we set

local function update_nametag(player, idx, level)
	local name = player:get_player_name()
	local r = rank(idx)
	local text
	if idx <= 1 then
		text = name
	else
		-- "[Level Tier] Name", colored via escape codes: nametag strings are
		-- rendered as EnrichedStrings, so the color survives mcl_player
		-- periodically resetting nametag_color (sneak/elytra props).
		text = core.colorize(r.color, "[" .. level .. " " .. r.name .. "]") .. " " .. name
	end
	if current_tag_text[name] == text then
		return
	end
	local ok, err = pcall(player.set_properties, player, {
		nametag = text,
		nametag_color = table.copy(DEFAULT_TAG_COLOR),
	})
	if ok then
		current_tag_text[name] = text
	else
		core.log("warning", "[awards_mcl] could not set nametag: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------------------
-- Rank-up announcement
-- ---------------------------------------------------------------------------

local function announce_rankup(player, idx, level)
	local r = rank(idx)
	local pname = player:get_player_name()
	core.chat_send_all(core.colorize(r.color, "✦ " .. S("@1 earned the @2 rank!", pname, r.name)) ..
		core.colorize("#CCCCCC", " " .. S("(Level @1)", level)))

	if not fanfare_enabled then
		return
	end
	local pos = player:get_pos()
	core.sound_play("mcl_experience_level_up", {
		pos = pos,
		gain = 0.5,
		pitch = 1.0 + idx * 0.03, -- slightly higher pitch for higher ranks
	})
	core.add_particlespawner({
		amount = 24,
		time = 0.5,
		pos = vector.offset(pos, 0, 1.2, 0),
		vel = { min = vector.new(-1.2, 2.5, -1.2), max = vector.new(1.2, 4.2, 1.2) },
		acc = { min = vector.new(0, -6, 0), max = vector.new(0, -6, 0) },
		exptime = { min = 0.5, max = 0.9 },
		size = { min = 0.7, max = 1.4 },
		texture = "mcl_experience_orb.png",
		glow = 5,
	})
end

-- ---------------------------------------------------------------------------
-- Chat tag: "[Level Tier] <Name> message"
-- ---------------------------------------------------------------------------

if chat_tag_enabled then
	core.register_on_chat_message(function(name, message)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		local ok, level = pcall(mcl_experience.get_level, player)
		if not ok or type(level) ~= "number" then
			return false
		end
		local idx = rank_index_for_level(level)
		if idx <= 1 then
			return false -- Nothing: plain chat
		end
		local r = rank(idx)
		core.chat_send_all(core.colorize(r.color, "[" .. level .. " " .. r.name .. "]") ..
			" <" .. name .. "> " .. message)
		return true
	end)
end

-- ---------------------------------------------------------------------------
-- Rank polling (cheap: level is cached inside mcl_experience)
-- ---------------------------------------------------------------------------

local state = {} -- per connected player: { adopted, announced, tag_level }

local function update_player(player)
	local name = player:get_player_name()
	local ok, level = pcall(mcl_experience.get_level, player)
	if not ok or type(level) ~= "number" then
		return
	end

	local st = state[name]
	if not st then
		st = {}
		state[name] = st
	end

	local idx = rank_index_for_level(level)

	-- First check after join: adopt the current rank silently, so players do
	-- not get spammed with a rank-up for progress from a previous session.
	if not st.adopted then
		st.adopted = true
		st.announced = idx
		st.tag_level = level
		update_medal(player, idx)
		update_nametag(player, idx, level)
		return
	end

	local changed = false
	if idx > st.announced then
		announce_rankup(player, idx, level)
		st.announced = idx
		changed = true
	elseif idx < st.announced then
		-- Demotion (e.g. death drops XP to 0) is silent.
		st.announced = idx
		changed = true
	end

	-- Refresh the nametag on rank change OR whenever the level number itself
	-- changed (the tag shows the live level).
	if changed or st.tag_level ~= level then
		st.tag_level = level
		update_nametag(player, idx, level)
		-- Rebuild the inventory formspec if one was built for this player, so
		-- the badge in the character box follows the live level too.
		local base = last_inv_base[name]
		if base then
			mcl_player.set_inventory_formspec(player, base, 0)
		end
	end
	-- Always (re)ensure the sprite exists with the right texture; caching on
	-- the current texture makes this a no-op most of the time.
	update_medal(player, idx)
end

-- Medal follows the player every step (no attachment: avoids the well-known
-- engine quirk where entities attached to players are invisible to others).
local tag_acc = 0
core.register_globalstep(function(dt)
	-- follow medals (every step, smooth)
	for _, player in ipairs(core.get_connected_players()) do
		local ent = medal_by_player[player:get_player_name()]
		if ent and ent.object then
			local pos = player:get_pos()
			if pos then
				local lp = ent.last_pos
				if not lp or lp.x ~= pos.x or lp.y ~= pos.y or lp.z ~= pos.z then
					ent.object:set_pos(vector.offset(pos, 0, MEDAL_Y_OFFSET, 0))
					ent.last_pos = { x = pos.x, y = pos.y, z = pos.z }
				end
			end
		end
	end

	-- rank polling (twice a second is plenty)
	tag_acc = tag_acc + dt
	if tag_acc < 0.5 then
		return
	end
	tag_acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		update_player(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	state[name] = nil
	current_tag_text[name] = nil
	remove_medal(name)
end)

-- ---------------------------------------------------------------------------
-- Chat command
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Inventory badge: "<level> <medal icon>" in the top-right of the character
-- box of the inventory formspec (survival and creative both build that box
-- with mcl_player.get_player_formspec_model(...), i.e. a "model[...]"
-- element — its rectangle is what we anchor the badge to).
-- ---------------------------------------------------------------------------

local function badge_formspec(player, formspec)
	local ok, level = pcall(mcl_experience.get_level, player)
	if not ok or type(level) ~= "number" then
		return ""
	end
	local idx = rank_index_for_level(level)
	if idx <= 1 then
		return ""
	end
	local r = rank(idx)

	-- Find the player-model element: model[X,Y;W,H;...]
	local nx, ny, nw, nh = formspec:match("model%[([^;]+),([^;]+);([^;]+),([^;]+);")
	if not nx then
		return ""
	end
	local mx, my, mw, mh = tonumber(nx), tonumber(ny), tonumber(nw), tonumber(nh)
	if not mx or not my or not mw or not mh then
		return ""
	end

	-- Medal / badge size and position
	local icon_w = 0.32
	local icon_h = 0.64
	local bx = mx + mw - icon_w - 0.12
	local by = my + 0.10
	local lx = bx - 0.50 -- Level number position, tuned for up to 3 digits
	local ly = by + (icon_h / 2) - 0.16

	-- Award Collection button styled like an MMORPG card — matching the
	-- Award Collection GUI: dark card, gold border on hover, dynamic rank
	-- icon based on the player's tier.
	-- Placed in the TOP-LEFT corner of the character canvas, vertically
	-- aligned with the medal badge in the top-right corner.
	local btn_w = 2
	local btn_h = 0.55
	local btn_x = mx + 0.12
	local btn_y = by + (icon_h - btn_h) / 2
	local btn_icon = "awards_mcl_icon_" .. r.name:lower() .. ".png"
	local ic_x = btn_x + 0.14
	local ic_y = btn_y + (btn_h - 0.34) / 2
	local tx = btn_x + 0.58
	local ty = btn_y + btn_h / 2

	-- Card texture is drawn via [fill (rendered client-side, no new files):
	-- a semi-transparent dark box + 3px border
	local card_border = "#2D3748"
	local card_gold = "#FFD74A"
	local function card_tex(border, bg)
		return "[fill:64x64:0,0:" .. bg
			.. "^[fill:64x3:0,0:" .. border
			.. "^[fill:64x3:0,61:" .. border
			.. "^[fill:3x64:0,0:" .. border
			.. "^[fill:3x64:61,0:" .. border
	end

	return table.concat({
		-- 1. Main medal / badge image
		"image[", string.format("%.3f", bx), ",", string.format("%.3f", by),
		";", string.format("%.3f", icon_w), ",", string.format("%.3f", icon_h),
		";", r.texture, "]",

		-- 2. Level number label
		"label[", string.format("%.3f", lx), ",", string.format("%.3f", ly), ";",
		core.formspec_escape(core.colorize(r.color, tostring(level))), "]",

		-- 3. Award Collection button (dark card + rank icon + gold text)
		"style[awards_mcl_open_collection;border=false;bgimg=",
		card_tex(card_border, "#1E293BE6"),
		";bgimg_hovered=", card_tex(card_gold, "#24304AE6"),
		";bgimg_pressed=", card_tex(card_gold, "#151B26E6"), "]",
		"image_button[", string.format("%.3f", btn_x), ",", string.format("%.3f", btn_y),
		";", string.format("%.3f", btn_w), ",", string.format("%.3f", btn_h),
		";awards_mcl_blank.png;awards_mcl_open_collection;]",
		"image[", string.format("%.3f", ic_x), ",", string.format("%.3f", ic_y),
		";0.34,0.34;", btn_icon, "]",
		"label[", string.format("%.3f", tx), ",", string.format("%.3f", ty), ";",
		core.formspec_escape(core.colorize(card_gold, "AWARDS")), "]",

		"tooltip[awards_mcl_open_collection;Buka Award Collection (Lv. ", level, ")]",
	})
end

if mcl_player and mcl_player.set_inventory_formspec then
	local orig_set_inventory_formspec = mcl_player.set_inventory_formspec
	mcl_player.set_inventory_formspec = function(player, formspec, priority)
		-- priority 0 is the player inventory (survival + creative); other GUIs
		-- that piggyback on this API (e.g. mounting a horse) use higher values
		-- and must not receive the badge.
		if priority == 0 and type(formspec) == "string"
				and formspec:find("model[", 1, true) then
			last_inv_base[player:get_player_name()] = formspec
			local badge = badge_formspec(player, formspec)
			if badge ~= "" then
				formspec = formspec .. badge
			end
		end
		return orig_set_inventory_formspec(player, formspec, priority)
	end
end

core.register_on_leaveplayer(function(player)
	last_inv_base[player:get_player_name()] = nil
end)

-- ---------------------------------------------------------------------------
-- Chat command
-- ---------------------------------------------------------------------------

core.register_chatcommand("rank", {
	description = S("Show your MCL Awards rank and progress"),
	params = S("[list]"),
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("You must be online to check your rank.")
		end
		local ok, level = pcall(mcl_experience.get_level, player)
		if not ok then
			return false, S("Experience data not available yet.")
		end
		local idx = rank_index_for_level(level)
		local r = rank(idx)
		local lines = {
			core.colorize(r.color, S("@1 — Level @2", r.name, level)),
		}
		local nxt = ranks[idx + 1]
		if nxt then
			lines[#lines + 1] = S("Next rank: @1 at level @2 (@3 levels to go)",
				core.colorize(nxt.color, nxt.name), nxt.level, nxt.level - level)
		else
			lines[#lines + 1] = S("You have reached the highest rank!")
		end
		if param == "list" then
			lines[#lines + 1] = ""
			for i = #ranks, 2, -1 do
				local rr = rank(i)
				lines[#lines + 1] = core.colorize(rr.color, GLYPH) ..
					(" Level %3d — %s"):format(rr.level, rr.name)
			end
		end
		return true, table.concat(lines, "\n")
	end,
})

-- ---------------------------------------------------------------------------
-- UI for Award Collection
-- ---------------------------------------------------------------------------

dofile(core.get_modpath(modname) .. "/collection_ui.lua")