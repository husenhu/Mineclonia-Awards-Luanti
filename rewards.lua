-- rewards.lua — one-time claimable rewards for XP ranks and Monster Slayer
-- trophies.
--
-- Every XP rank (Bronze..Eternal) and every Monster Slayer trophy tier
-- (Bronze..Legendary — for each of the 5 families AND the overall entry)
-- carries an item reward. Rewards are claimed through the Award Collection
-- GUI (see collection_ui.lua):
--
--   * XP Ranks tab     : CLAIM button for the selected rank + CLAIM ALL
--   * Monster Slayer   : CLAIM button for the selected entry (claims every
--                        unclaimed tier of that entry at once) + CLAIM ALL
--
-- Claimed state lives in player meta so it survives relog and server
-- restart:
--   awards_mcl:claim_rank_<rank index>               = 1
--   awards_mcl:claim_slayer_<entry key>_<tier>       = 1
--
-- Reward definitions sit next to the data they belong to:
--   * XP ranks     -> `rewards` field in the ranks table    (init.lua)
--   * Slayer tiers -> `rewards` field in slayer.tiers       (monster_slayer.lua)
--
-- A reward entry is either a string "itemstring count" or a table
-- { item = "...", count = n, meta = { key = value } } for items that need
-- stack metadata (e.g. Potion of Strength II, which stores its level in
-- "mcl_potions:potion_potent").
--
-- Delivery: items go into the player's "main" inventory list; anything that
-- does not fit drops at the player's feet (never destroyed).

local modname = core.get_current_modname()
local S = core.get_translator and core.get_translator(modname) or function(s) return s end

awards_mcl.rewards = {}

local rewards = awards_mcl.rewards

local META_RANK = "awards_mcl:claim_rank_"      -- .. <rank index>
local META_SLAYER = "awards_mcl:claim_slayer_"  -- .. <entry key> .. "_" .. <tier>

-- ---------------------------------------------------------------------------
-- Parsing / display helpers
-- ---------------------------------------------------------------------------

local function parse_one(r)
	if type(r) == "string" then
		local item, count = r:match("^(%S+)%s+(%d+)$")
		if not item then
			core.log("error", "[awards_mcl] invalid reward spec: " .. tostring(r))
			return nil
		end
		return { item = item, count = tonumber(count) }
	end
	if type(r) == "table" and type(r.item) == "string" then
		return { item = r.item, count = r.count or 1, meta = r.meta }
	end
	core.log("error", "[awards_mcl] invalid reward entry: " .. tostring(r))
	return nil
end

local function parse_list(list)
	local out = {}
	for _, r in ipairs(list or {}) do
		local rw = parse_one(r)
		if rw then
			out[#out + 1] = rw
		end
	end
	return out
end

-- "itemstring count" for formspec item_image[] (works for both spec forms)
function rewards.icon_spec(rw)
	if type(rw) == "string" then
		return rw
	end
	return rw.item .. " " .. tostring(rw.count or 1)
end

-- Short display name for tooltips/chat: "4× Golden Apple". Builds a real
-- stack so potion meta (Strength II etc.) shows up in the description.
function rewards.reward_label(rw)
	local parsed = type(rw) == "table" and rw or parse_one(rw)
	if not parsed or not core.registered_items[parsed.item] then
		return parsed and parsed.item or "?"
	end
	local stack = ItemStack(parsed.item .. " " .. parsed.count)
	if parsed.meta then
		local m = stack:get_meta()
		for k, v in pairs(parsed.meta) do
			if type(v) == "number" then
				m:set_int(k, v)
			else
				m:set_string(k, tostring(v))
			end
		end
		if type(tt) == "table" and tt.reload_itemstack_description then
			pcall(tt.reload_itemstack_description, stack)
		end
	end
	local desc = stack:get_meta():get_string("description")
	if desc == "" then
		desc = stack:get_description() or parsed.item
	end
	desc = desc:match("^[^\n]*") or desc -- drop tt snippets on extra lines
	local n = stack:get_count()
	if n > 1 then
		return n .. "× " .. desc
	end
	return desc
end

-- ---------------------------------------------------------------------------
-- State accessors
-- ---------------------------------------------------------------------------

local function player_level(player)
	local ok, level = pcall(mcl_experience.get_level, player)
	if ok and type(level) == "number" then
		return level
	end
	return 0
end

-- "claimed" | "claimable" | "locked" | nil (rank has no rewards, e.g. Nothing)
function rewards.rank_state(player, idx)
	local r = awards_mcl.ranks[idx]
	if not r or idx < 2 or not r.rewards or #r.rewards == 0 then
		return nil
	end
	local meta = player:get_meta()
	if meta:get_int(META_RANK .. idx) == 1 then
		return "claimed"
	end
	if player_level(player) >= r.level then
		return "claimable"
	end
	return "locked"
end

-- Rank indices (ascending) that can be claimed right now.
function rewards.pending_ranks(player)
	local out = {}
	for i = 2, #awards_mcl.ranks do
		if rewards.rank_state(player, i) == "claimable" then
			out[#out + 1] = i
		end
	end
	return out
end

-- Trophy tiers of one entry (family or overall) that are reached but not
-- yet claimed, ascending.
function rewards.slayer_pending(player, entry)
	local slayer = awards_mcl.slayer
	local out = {}
	if not entry or not entry.milestones then
		return out
	end
	local kills = slayer.get_kills(player, entry.key)
	local current = slayer.tier_for(entry, kills)
	local meta = player:get_meta()
	for tier = 1, current do
		if meta:get_int(META_SLAYER .. entry.key .. "_" .. tier) ~= 1 then
			out[#out + 1] = tier
		end
	end
	return out
end

-- Total unclaimed trophy tiers across all entries (for CLAIM ALL).
function rewards.pending_slayer_count(player)
	local n = 0
	for _, e in ipairs(awards_mcl.slayer.entries) do
		n = n + #rewards.slayer_pending(player, e)
	end
	return n
end

-- ---------------------------------------------------------------------------
-- Delivery
-- ---------------------------------------------------------------------------

local function give_one(player, rw)
	if not core.registered_items[rw.item] then
		core.log("error", "[awards_mcl] reward item does not exist: " .. tostring(rw.item))
		return nil
	end
	local stack = ItemStack(rw.item .. " " .. rw.count)
	if rw.meta then
		local m = stack:get_meta()
		for k, v in pairs(rw.meta) do
			if type(v) == "number" then
				m:set_int(k, v)
			else
				m:set_string(k, tostring(v))
			end
		end
		if type(tt) == "table" and tt.reload_itemstack_description then
			pcall(tt.reload_itemstack_description, stack)
		end
	end
	local inv = player:get_inventory()
	if inv then
		local leftover = inv:add_item("main", stack)
		if leftover and not leftover:is_empty() then
			-- Inventory full: drop at the player's feet, never destroy
			local pos = player:get_pos()
			if pos then
				core.add_item(pos, leftover)
			end
		end
	end
	return stack
end

local function give_all(player, parsed)
	local given = {}
	for _, rw in ipairs(parsed) do
		local st = give_one(player, rw)
		if st then
			given[#given + 1] = st
		end
	end
	return given
end

-- Private chat + sound + a small XP-orb burst (personal reward moment)
local function announce_claim(player, given, what)
	if #given == 0 then
		return
	end
	local names = {}
	for _, st in ipairs(given) do
		local desc = st:get_meta():get_string("description")
		if desc == "" then
			desc = st:get_description() or st:get_name()
		end
		desc = desc:match("^[^\n]*") or desc
		local n = st:get_count()
		names[#names + 1] = (n > 1 and (n .. "× ") or "") .. desc
	end
	local pname = player:get_player_name()
	core.chat_send_player(pname, core.colorize("#FFD74A", "🎁 " ..
		S("@1 claimed: @2", what, table.concat(names, ", "))))
	local pos = player:get_pos()
	core.sound_play("mcl_experience_level_up", {
		pos = pos,
		gain = 0.35,
		pitch = 1.15,
	})
	if pos then
		core.add_particlespawner({
			amount = 16,
			time = 0.4,
			pos = vector.offset(pos, 0, 1.2, 0),
			vel = { min = vector.new(-1.0, 2.0, -1.0), max = vector.new(1.0, 3.5, 1.0) },
			acc = { min = vector.new(0, -5, 0), max = vector.new(0, -5, 0) },
			exptime = { min = 0.4, max = 0.8 },
			size = { min = 0.6, max = 1.2 },
			texture = "mcl_experience_orb.png",
			glow = 5,
		})
	end
end

-- ---------------------------------------------------------------------------
-- Claim API (used by collection_ui.lua; also handy for chat commands/tests)
-- ---------------------------------------------------------------------------

-- Claim one XP rank. Returns the list of given ItemStacks, or nil when the
-- rank is not claimable (locked or already claimed).
function rewards.claim_rank(player, idx)
	if rewards.rank_state(player, idx) ~= "claimable" then
		return nil
	end
	local r = awards_mcl.ranks[idx]
	local given = give_all(player, parse_list(r.rewards))
	player:get_meta():set_int(META_RANK .. idx, 1)
	announce_claim(player, given, S("the @1 reward", r.name))
	return given
end

-- Claim every unlocked, unclaimed XP rank at once. Returns all given stacks
-- (empty when there was nothing to claim).
function rewards.claim_all_ranks(player)
	local given = {}
	for _, idx in ipairs(rewards.pending_ranks(player)) do
		local r = awards_mcl.ranks[idx]
		for _, st in ipairs(give_all(player, parse_list(r.rewards))) do
			given[#given + 1] = st
		end
		player:get_meta():set_int(META_RANK .. idx, 1)
	end
	announce_claim(player, given, S("XP rank rewards"))
	return given
end

local function claim_slayer_collect(player, entry, given)
	local pending = rewards.slayer_pending(player, entry)
	if #pending == 0 then
		return false
	end
	local slayer = awards_mcl.slayer
	local meta = player:get_meta()
	for _, tier in ipairs(pending) do
		local t = slayer.tiers[tier]
		for _, st in ipairs(give_all(player, parse_list(t.rewards))) do
			given[#given + 1] = st
		end
		meta:set_int(META_SLAYER .. entry.key .. "_" .. tier, 1)
	end
	return true
end

-- Claim every unclaimed trophy tier of ONE entry (family or overall) in one
-- go — a player who jumps straight to tier 4 collects tiers 1..4 together.
function rewards.claim_slayer(player, entry)
	local given = {}
	if not claim_slayer_collect(player, entry, given) then
		return nil
	end
	announce_claim(player, given, S("@1 trophy rewards", entry.title))
	return given
end

-- Claim unclaimed trophy tiers of ALL entries (5 families + overall).
function rewards.claim_all_slayer(player)
	local given = {}
	for _, e in ipairs(awards_mcl.slayer.entries) do
		claim_slayer_collect(player, e, given)
	end
	announce_claim(player, given, S("Monster Slayer rewards"))
	return given
end
