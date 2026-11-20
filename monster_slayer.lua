-- monster_slayer.lua — Monster Slayer statistics
--
-- Counts every monster killed by a player (per mob family + overall total),
-- stored in player meta so progress survives relog and server restart.
--
-- Kill credit uses the same rule Mineclonia itself uses for its
-- "Monster Hunter" award: the mob must die within 5 seconds of the player's
-- last hit (mcl_mobs sets last_player_hit_name on every player/wolf punch).
-- The hook wraps mcl_mobs.mob_class.check_for_death, which runs on every
-- damage event; a kill is counted exactly when the mob transitions from
-- alive (self.dead == false) to dead (self.dead == true).
--
-- Progress is viewable in the "Award Collection" GUI, Monster Slayer tab
-- (see collection_ui.lua), where each family has 6 trophy tiers.

local modname = core.get_current_modname()
local S = core.get_translator and core.get_translator(modname) or function(s) return s end

awards_mcl.slayer = {}

local slayer = awards_mcl.slayer

local announce_enabled = core.settings:get_bool("awards_mcl.slayer_announce", true)

-- ---------------------------------------------------------------------------
-- Config: mob families, milestones and trophy tiers
-- ---------------------------------------------------------------------------

-- Entity variants are folded into their family (husk/drowned/villager zombie
-- all count as Zombie; stray/wither skeleton as Skeleton; cave spider as
-- Spider) — matches how Mineclonia groups them for drops and sounds.
slayer.mobs = {
	{
		key = "creeper",
		title = "Creeper",
		color = "#7ECB4A",
		entities = { ["mobs_mc:creeper"] = true },
		milestones = { 10, 25, 75, 150, 300, 500 },
	},
	{
		key = "witch",
		title = "Witch",
		color = "#B062D8",
		entities = { ["mobs_mc:witch"] = true },
		milestones = { 10, 25, 75, 150, 300, 500 },
	},
	{
		key = "zombie",
		title = "Zombie",
		color = "#5CA04A",
		entities = {
			["mobs_mc:zombie"] = true,
			["mobs_mc:husk"] = true,
			["mobs_mc:villager_zombie"] = true,
			["mobs_mc:drowned"] = true,
		},
		milestones = { 25, 75, 150, 500, 1000, 1500 },
	},
	{
		key = "skeleton",
		title = "Skeleton",
		color = "#C9CDD2",
		entities = {
			["mobs_mc:skeleton"] = true,
			["mobs_mc:stray"] = true,
			["mobs_mc:witherskeleton"] = true,
		},
		milestones = { 25, 75, 150, 500, 1000, 1500 },
	},
	{
		key = "spider",
		title = "Spider",
		color = "#9E6A50",
		entities = {
			["mobs_mc:spider"] = true,
			["mobs_mc:cave_spider"] = true,
		},
		milestones = { 10, 50, 100, 300, 600, 1000 },
	},
}

-- Overall entry: kills are the sum of all families above.
slayer.total = {
	key = "total",
	title = "Monster Slayer",
	color = "#FFD74A",
	milestones = { 50, 250, 750, 1500, 3000, 5000 },
}

-- Everything (5 families + overall) can be selected in the GUI.
slayer.entries = {}
for _, m in ipairs(slayer.mobs) do
	slayer.entries[#slayer.entries + 1] = m
end
slayer.entries[#slayer.entries + 1] = slayer.total

slayer.entry_by_key = {}
for _, e in ipairs(slayer.entries) do
	slayer.entry_by_key[e.key] = e
end

-- Entity name -> family entry (built once)
local entity_to_entry = {}
for _, m in ipairs(slayer.mobs) do
	for ename in pairs(m.entities) do
		entity_to_entry[ename] = m
	end
end

-- Trophy tiers (6 per mob). Index 1 = lowest. Textures are 32x32.
slayer.tiers = {
	{ name = "Bronze",    color = "#DA9A3C", texture = "awards_mcl_trophy_1.png" },
	{ name = "Silver",    color = "#D8DCE0", texture = "awards_mcl_trophy_2.png" },
	{ name = "Gold",      color = "#FFD74A", texture = "awards_mcl_trophy_3.png" },
	{ name = "Platinum",  color = "#6FD7FF", texture = "awards_mcl_trophy_4.png" },
	{ name = "Crystal",   color = "#4AEDD9", texture = "awards_mcl_trophy_5.png" },
	{ name = "Legendary", color = "#C05AFF", texture = "awards_mcl_trophy_6.png" },
}

slayer.TIER_COUNT = #slayer.tiers

local META_PREFIX = "awards_mcl:slayer_"

-- ---------------------------------------------------------------------------
-- Stats accessors
-- ---------------------------------------------------------------------------

-- Total kills of one family (or "total") for a player.
function slayer.get_kills(player, key)
	local meta = player:get_meta()
	return meta:get_int(META_PREFIX .. key)
end

-- Highest trophy tier index reached for a number of kills (0 = none).
function slayer.tier_for(entry, kills)
	local tier = 0
	for i, ms in ipairs(entry.milestones) do
		if kills >= ms then
			tier = i
		end
	end
	return tier
end

-- Highest overall kill count of one player across all families.
function slayer.get_total_kills(player)
	local sum = 0
	for _, m in ipairs(slayer.mobs) do
		sum = sum + slayer.get_kills(player, m.key)
	end
	return sum
end

-- ---------------------------------------------------------------------------
-- Tier-up announcements
-- ---------------------------------------------------------------------------

local function announce_tier(player, entry, tier)
	local t = slayer.tiers[tier]
	if not t then
		return
	end
	local pname = player:get_player_name()
	core.chat_send_all(core.colorize(entry.color, "⚔ " ..
		S("@1 earned the @2 @3 trophy!", pname, t.name, entry.title)))
	if announce_enabled then
		core.sound_play("mcl_experience_level_up", {
			pos = player:get_pos(),
			gain = 0.4,
			pitch = 0.9 + tier * 0.05,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Kill registration
-- ---------------------------------------------------------------------------

local function register_kill(pname, entity_name)
	local entry = entity_to_entry[entity_name]
	if not entry then
		return
	end
	local player = core.get_player_by_name(pname)
	if not player then
		return
	end
	local meta = player:get_meta()

	-- Per-family count
	local family_key = META_PREFIX .. entry.key
	local kills = meta:get_int(family_key) + 1
	meta:set_int(family_key, kills)

	-- Overall count (kept separately so old data can never disagree)
	local total_key = META_PREFIX .. slayer.total.key
	local total = meta:get_int(total_key) + 1
	meta:set_int(total_key, total)

	-- Announce any newly reached tier (family and overall)
	local old_family_tier = slayer.tier_for(entry, kills - 1)
	local new_family_tier = slayer.tier_for(entry, kills)
	if new_family_tier > old_family_tier then
		announce_tier(player, entry, new_family_tier)
	end

	local total_entry = slayer.total
	local old_total_tier = slayer.tier_for(total_entry, total - 1)
	local new_total_tier = slayer.tier_for(total_entry, total)
	if new_total_tier > old_total_tier then
		announce_tier(player, total_entry, new_total_tier)
	end
end

-- ---------------------------------------------------------------------------
-- Hook: wrap mcl_mobs death detection
-- ---------------------------------------------------------------------------

core.register_on_mods_loaded(function()
	if not (core.global_exists("mcl_mobs") and mcl_mobs.mob_class
			and mcl_mobs.mob_class.check_for_death) then
		core.log("warning", "[awards_mcl] mcl_mobs not found — Monster Slayer disabled")
		return
	end
	local mob_class = mcl_mobs.mob_class
	local orig_check_for_death = mob_class.check_for_death

	mob_class.check_for_death = function(self, mcl_reason, damage)
		local was_dead = self.dead
		local result = orig_check_for_death(self, mcl_reason, damage)
		if not was_dead and self.dead and self.type == "monster" then
			-- Same credit rule Mineclonia uses for its Monster Hunter award:
			-- killed by the player within the last 5 seconds.
			if self.last_player_hit_name
					and self.last_player_hit_time
					and core.get_gametime() - self.last_player_hit_time <= 5 then
				register_kill(self.last_player_hit_name, self.name)
			end
		end
		return result
	end

	core.log("action", "[awards_mcl] Monster Slayer tracking enabled")
end)
