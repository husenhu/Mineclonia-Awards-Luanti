-- effects.lua — particle auras for XP ranks
--
-- Every XP rank (Bronze .. Eternal, i.e. ranks table index 2 .. 10) gets a
-- particle effect that follows the player. The effects form a progression
-- from subtle natural dust (Bronze) up to a three-spawner supernova (Eternal):
--
--   Bronze      -> Debu Tanah       (sparse dirt dust at the feet)
--   Silver      -> Percikan Pasir   (sand / gravel splashes)
--   Gold        -> Serpihan Batu    (stone chips that bounce off the ground)
--   Diamond     -> Kilau Mineral    (soft additive iron / gold sparkle)
--   Netherite   -> Energi Kristal   (diamond / emerald energy, shrinking)
--   Veteran     -> Aura Api         (rising magma / redstone embers)
--   Immortal    -> Badai Petir      (gold flashes + stone dust + sparks)
--   Untouchable -> Aura Dewa        (wide diamond / emerald crystal aura)
--   Eternal     -> Supernova        (core burst + wide ring + spark shower)
--
-- All textures are vanilla Mineclonia node textures, so they are already in
-- the client media cache. Spawners use `time = 0` (infinite) and `attached`
-- to the player object, so they follow the character for free — no per-tick
-- particlespawner calls.
--
-- Settings:
--   awards_mcl.rank_effects            bool   master switch (default true)
--   awards_mcl.rank_effects_visibility enum   "all" (everyone sees) or
--                                              "self" (only the player)

local modname = core.get_current_modname()
local S = core.get_translator and core.get_translator(modname) or function(s) return s end

awards_mcl.effects = {}

local effects = awards_mcl.effects

local V = vector.new

-- Texture table helper. In the modern particle API `blend`, `alpha` and
-- `scale_tween` belong to the texture table, NOT to the spawner itself.
local function T(name, opts)
	local t = opts or {}
	t.name = name
	if t.blend == nil then
		t.blend = "alpha"
	end
	return t
end

local function shrink(from, to)
	return {
		{ x = from, y = from },
		{ x = to,   y = to   },
	}
end

-- ---------------------------------------------------------------------------
-- Effect definitions (key = rank index in awards_mcl.ranks)
--
-- Fields are standard particlespawner fields. `pos` is relative to the
-- player (attached spawners are positioned relative to the object position
-- and yaw). `radius` turns `pos` into a sphere of random emission points.
-- ---------------------------------------------------------------------------

local EFFECTS = {
	-- ===== 2. Bronze — Debu Tanah =====================================
	[2] = {
		{
			amount = 3,
			time = 0,
			exptime = { min = 0.7, max = 1.4 },
			size = { min = 0.08, max = 0.16 },
			pos = V(0, 0.15, 0),
			radius = { min = 0.15, max = 0.45 },
			vel = { min = V(-0.20, 0.05, -0.20), max = V(0.20, 0.35, 0.20) },
			acc = { min = V(0, -0.6, 0), max = V(0, -0.6, 0) },
			texture = T("default_dirt.png", { alpha = 0.55 }),
			glow = 0,
		},
	},

	-- ===== 3. Silver — Percikan Pasir =================================
	[3] = {
		{
			amount = 5,
			time = 0,
			exptime = { min = 0.6, max = 1.1 },
			size = { min = 0.08, max = 0.18 },
			pos = V(0, 0.15, 0),
			radius = { min = 0.20, max = 0.55 },
			vel = { min = V(-0.30, 0.30, -0.30), max = V(0.30, 0.80, 0.30) },
			acc = { min = V(0, -1.2, 0), max = V(0, -1.2, 0) },
			texpool = {
				T("default_sand.png",   { alpha = 0.75 }),
				T("default_gravel.png", { alpha = 0.75 }),
			},
			glow = 0,
		},
	},

	-- ===== 4. Gold — Serpihan Batu ====================================
	[4] = {
		{
			amount = 6,
			time = 0,
			exptime = { min = 0.7, max = 1.3 },
			size = { min = 0.10, max = 0.22 },
			pos = V(0, 0.20, 0),
			radius = { min = 0.20, max = 0.55 },
			vel = { min = V(-0.50, 0.40, -0.50), max = V(0.50, 1.00, 0.50) },
			acc = { min = V(0, -2.0, 0), max = V(0, -2.0, 0) },
			collisiondetection = true,
			bounce = { min = 0.20, max = 0.40 },
			texpool = {
				T("default_cobble.png", { alpha = 0.85 }),
				T("default_stone.png",  { alpha = 0.85 }),
			},
			glow = 0,
		},
	},

	-- ===== 5. Diamond — Kilau Mineral =================================
	[5] = {
		{
			amount = 7,
			time = 0,
			exptime = { min = 0.8, max = 1.5 },
			size = { min = 0.07, max = 0.15 },
			pos = V(0, 0.90, 0),
			radius = { min = 0.40, max = 0.80 },
			vel = { min = V(-0.15, 0.15, -0.15), max = V(0.15, 0.50, 0.15) },
			acc = { min = V(0, -0.2, 0), max = V(0, -0.2, 0) },
			texpool = {
				T("default_steel_block.png", { blend = "add", alpha = 0.9 }),
				T("default_gold_block.png",  { blend = "add", alpha = 0.9 }),
			},
			glow = 5,
		},
	},

	-- ===== 6. Netherite — Energi Kristal ==============================
	[6] = {
		-- Body aura: crystals that shrink as they are "absorbed"
		{
			amount = 7,
			time = 0,
			exptime = { min = 0.9, max = 1.4 },
			size = { min = 0.08, max = 0.18 },
			pos = V(0, 1.00, 0),
			radius = { min = 0.60, max = 1.00 },
			vel = { min = V(-0.10, 0.10, -0.10), max = V(0.10, 0.40, 0.10) },
			acc = { min = V(0, 0.1, 0), max = V(0, 0.1, 0) },
			texpool = {
				T("default_diamond_block.png", {
					blend = "add", alpha = 0.9, scale_tween = shrink(1.0, 0.15),
				}),
				T("mcl_core_emerald_block.png", {
					blend = "add", alpha = 0.9, scale_tween = shrink(1.0, 0.15),
				}),
			},
			glow = 8,
		},
		-- Ground sparkle at the feet
		{
			amount = 3,
			time = 0,
			exptime = { min = 0.6, max = 1.1 },
			size = { min = 0.05, max = 0.10 },
			pos = V(0, 0.20, 0),
			radius = { min = 0.20, max = 0.50 },
			vel = { min = V(-0.10, 0.30, -0.10), max = V(0.10, 0.60, 0.10) },
			texture = T("mcl_core_emerald_block.png", { blend = "add", alpha = 0.85 }),
			glow = 8,
		},
	},

	-- ===== 7. Veteran — Aura Api ======================================
	[7] = {
		-- Rising magma flames
		{
			amount = 10,
			time = 0,
			exptime = { min = 0.6, max = 1.2 },
			size = { min = 0.09, max = 0.20 },
			pos = V(0, 0.30, 0),
			radius = { min = 0.25, max = 0.60 },
			vel = { min = V(-0.30, 0.60, -0.30), max = V(0.30, 1.80, 0.30) },
			acc = { min = V(0, 0.8, 0), max = V(0, 0.8, 0) },
			texture = T("mcl_nether_magma.png", {
				blend = "add", alpha = 0.9,
				-- 16x64 texture = 4 vertical frames of 16x16
				animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.5 },
			}),
			glow = 12,
		},
		-- Redstone embers around the body
		{
			amount = 6,
			time = 0,
			exptime = { min = 0.8, max = 1.4 },
			size = { min = 0.05, max = 0.12 },
			pos = V(0, 1.00, 0),
			radius = { min = 0.40, max = 0.80 },
			vel = { min = V(-0.15, 0.40, -0.15), max = V(0.15, 1.00, 0.15) },
			texture = T("redstone_redstone_block.png", { blend = "add", alpha = 0.85 }),
			glow = 12,
		},
	},

	-- ===== 8. Immortal — Badai Petir ==================================
	[8] = {
		-- Gold / glowstone lightning flashes
		{
			amount = 8,
			time = 0,
			exptime = { min = 0.15, max = 0.40 },
			size = { min = 0.15, max = 0.35 },
			pos = V(0, 1.20, 0),
			radius = { min = 0.50, max = 1.20 },
			vel = { min = V(-0.20, 0.00, -0.20), max = V(0.20, 0.30, 0.20) },
			collisiondetection = true,
			texpool = {
				T("default_gold_block.png",  { blend = "add", alpha = 0.95 }),
				T("mcl_nether_glowstone.png", { blend = "add", alpha = 0.95 }),
			},
			glow = 14,
		},
		-- Stone dust kicked up around the feet
		{
			amount = 12,
			time = 0,
			exptime = { min = 0.7, max = 1.4 },
			size = { min = 0.08, max = 0.18 },
			pos = V(0, 0.20, 0),
			radius = { min = 0.30, max = 0.70 },
			vel = { min = V(-0.80, 0.50, -0.80), max = V(0.80, 1.50, 0.80) },
			acc = { min = V(0, -2.5, 0), max = V(0, -2.5, 0) },
			collisiondetection = true,
			bounce = { min = 0.10, max = 0.40 },
			texture = T("default_stone.png", { alpha = 0.80 }),
			glow = 0,
		},
		-- Tiny sparks at shoulder height
		{
			amount = 6,
			time = 0,
			exptime = { min = 0.30, max = 0.70 },
			size = { min = 0.04, max = 0.10 },
			pos = V(0, 1.50, 0),
			radius = { min = 0.40, max = 0.90 },
			vel = { min = V(-0.30, 0.20, -0.30), max = V(0.30, 0.80, 0.30) },
			texture = T("mcl_nether_glowstone_dust.png", { blend = "add", alpha = 0.9 }),
			glow = 14,
		},
	},

	-- ===== 9. Untouchable — Aura Dewa =================================
	[9] = {
		-- Wide rotating crystal aura
		{
			amount = 10,
			time = 0,
			exptime = { min = 1.0, max = 2.0 },
			size = { min = 0.10, max = 0.25 },
			pos = V(0, 1.00, 0),
			radius = { min = 0.80, max = 1.40 },
			vel = { min = V(-0.20, 0.10, -0.20), max = V(0.20, 0.50, 0.20) },
			jitter = { min = V(-0.05, 0, -0.05), max = V(0.05, 0, 0.05) },
			texture = T("default_diamond_block.png", {
				blend = "add", alpha = 0.9, scale_tween = shrink(1.0, 0.35),
			}),
			glow = 14,
		},
		-- Emerald motes orbiting wider
		{
			amount = 6,
			time = 0,
			exptime = { min = 0.8, max = 1.5 },
			size = { min = 0.05, max = 0.10 },
			pos = V(0, 0.60, 0),
			radius = { min = 1.00, max = 1.50 },
			vel = { min = V(-0.10, 0.20, -0.10), max = V(0.10, 0.60, 0.10) },
			texture = T("mcl_core_emerald_block.png", { blend = "add", alpha = 0.85 }),
			glow = 14,
		},
	},

	-- ===== 10. Eternal — Supernova ====================================
	[10] = {
		-- 1. Core burst: large glowstone flare
		{
			amount = 8,
			time = 0,
			exptime = { min = 0.5, max = 1.0 },
			size = { min = 0.30, max = 0.60 },
			pos = V(0, 1.00, 0),
			radius = { min = 0.20, max = 0.60 },
			vel = { min = V(-0.30, 0.30, -0.30), max = V(0.30, 0.90, 0.30) },
			texture = T("mcl_nether_glowstone.png", {
				blend = "add", alpha = 0.9,
				alpha_tween = { 1.0, 0.0 },
				scale_tween = shrink(1.2, 0.2),
			}),
			glow = 14,
		},
		-- 2. Wide energy ring of gold / diamond
		{
			amount = 14,
			time = 0,
			exptime = { min = 1.0, max = 1.8 },
			size = { min = 0.08, max = 0.16 },
			pos = V(0, 1.20, 0),
			radius = { min = 1.20, max = 1.80 },
			vel = { min = V(-0.10, 0.10, -0.10), max = V(0.10, 0.40, 0.10) },
			texpool = {
				T("default_gold_block.png",    { blend = "add", alpha = 0.9 }),
				T("default_diamond_block.png", { blend = "add", alpha = 0.9 }),
			},
			glow = 14,
		},
		-- 3. Spark shower: small particles thrown in all directions
		{
			amount = 12,
			time = 0,
			exptime = { min = 0.8, max = 1.6 },
			size = { min = 0.05, max = 0.12 },
			pos = V(0, 0.80, 0),
			radius = { min = 0.30, max = 1.00 },
			vel = { min = V(-1.50, 0.50, -1.50), max = V(1.50, 2.00, 1.50) },
			acc = { min = V(0, -3.0, 0), max = V(0, -3.0, 0) },
			collisiondetection = true,
			bounce = { min = 0.30, max = 0.60 },
			texpool = {
				T("mcl_nether_glowstone_dust.png", { blend = "add", alpha = 0.9 }),
				T("mcl_ocean_sea_lantern.png", {
					blend = "add", alpha = 0.9,
					-- 16x64 texture = 4 vertical frames of 16x16
					animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1.25 },
				}),
			},
			glow = 14,
		},
	},
}

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local spawners = {} -- player name -> { rank, ids = {...}, private, visibility }

local function settings()
	local enabled = core.settings:get_bool("awards_mcl.rank_effects", true)
	local visibility = core.settings:get("awards_mcl.rank_effects_visibility") or "all"
	if visibility ~= "self" then
		visibility = "all"
	end
	return enabled, visibility
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function effects.is_enabled()
	return (settings())
end

-- Display name of the aura for a rank index (nil for "Nothing").
function effects.get_name(idx)
	local r = awards_mcl.ranks and awards_mcl.ranks[idx]
	return r and r.effect_name or nil
end

-- Raw definition list for a rank (used by tests; read-only).
function effects.definitions(idx)
	return EFFECTS[idx]
end

-- Build fresh spawner definitions for one player (adds attached/playername).
function effects.build(idx, player)
	local base = EFFECTS[idx]
	if not base then
		return nil
	end
	local _, visibility = settings()
	local private = (visibility == "self")
	local name = player:get_player_name()
	local out = {}
	for _, d in ipairs(base) do
		local def = table.copy(d)
		def.attached = player
		if private then
			def.playername = name
		end
		out[#out + 1] = def
	end
	return out
end

-- Remove every spawner belonging to this player.
function effects.clear(player)
	local name = type(player) == "string" and player or player:get_player_name()
	local st = spawners[name]
	if not st then
		return
	end
	spawners[name] = nil
	for _, id in ipairs(st.ids) do
		pcall(core.delete_particlespawner, id, st.private and name or nil)
	end
end

-- Apply the effect for rank index `idx` (1 = Nothing -> clears).
-- No-op when the right effect is already active, so this is cheap to call
-- from the existing 0.5 s rank poll.
function effects.update(player, idx)
	local enabled, visibility = settings()
	local name = player:get_player_name()

	if not enabled or not idx or idx < 2 or not EFFECTS[idx] then
		effects.clear(player)
		return false
	end

	local st = spawners[name]
	if st and st.rank == idx and st.visibility == visibility then
		return true
	end

	effects.clear(player)

	local private = (visibility == "self")
	local ids = {}
	for _, def in ipairs(effects.build(idx, player) or {}) do
		local id = core.add_particlespawner(def)
		if id then
			ids[#ids + 1] = id
		end
	end
	if #ids == 0 then
		return false
	end

	spawners[name] = {
		rank = idx,
		ids = ids,
		private = private,
		visibility = visibility,
	}
	return true
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Player died / respawned: the attached object may have been recreated, so
-- drop the old spawners and let the next rank poll re-attach them.
core.register_on_respawnplayer(function(player)
	pcall(effects.clear, player)
end)

core.register_on_leaveplayer(function(player)
	pcall(effects.clear, player)
end)

-- Server shutdown: nothing to clean up (spawners are client-side), but drop
-- the bookkeeping so a /reload starts clean.
core.register_on_shutdown(function()
	spawners = {}
end)
