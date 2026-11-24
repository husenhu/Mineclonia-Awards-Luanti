-- collection_ui.lua — MMORPG Style Award Collection GUI
-- Two tabs: "XP Ranks" (medals per XP level) and "Monster Slayer"
-- (trophy tiers per monster family, see monster_slayer.lua).
local S = core.get_translator(core.get_current_modname())

local selected_tab = {}      -- player name -> "xp" | "slayer"
local selected_rank_idx = {} -- player name -> selected medal card index (XP tab)
local selected_slayer_key = {} -- player name -> selected entry key (Slayer tab)

-- Number formatting with thousands separator: 5000 -> "5.000"
local function fmt(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	out = out:gsub("^%.", "")
	return out
end

local function progress_color(frac)
	if frac >= 1 then
		return "#48BB78"
	elseif frac >= 0.5 then
		return "#FFD74A"
	else
		return "#2B6CB0"
	end
end

-- Horizontal progress bar: dark trough + colored fill (pure [fill boxes)
local function progress_bar(x, y, w, frac, color)
	frac = math.max(0, math.min(1, frac))
	local parts = {
		string.format("box[%.2f,%.2f;%.2f,0.30;#0D111A]", x, y, w),
	}
	if frac > 0 then
		parts[#parts + 1] = string.format("box[%.2f,%.2f;%.2f,0.30;%s]",
			x + 0.02, y + 0.02, math.max(0.05, (w - 0.04) * frac), color)
	end
	return table.concat(parts)
end

-- Transparent style for all interactive buttons (Mineclonia's default button
-- background would otherwise cover our card/tab colors).
--
-- `hover`/`pressed` are optional colours with alpha (e.g. "#FFFFFF14"). They
-- give instant client-side feedback: a formspec click needs a server round
-- trip, so without a hover state the GUI feels unresponsive.
local function style_block(names, hover, pressed)
	if #names == 0 then
		return ""
	end
	local props = {
		"bgimg=awards_mcl_blank.png",
		"border=false",
	}
	if hover then
		-- Two-argument [fill form: only that one accepts an alpha channel
		props[#props + 1] = "bgimg_hovered=[fill:64x64:" .. hover
	end
	if pressed then
		props[#props + 1] = "bgimg_pressed=[fill:64x64:" .. pressed
	end
	return "style[" .. table.concat(names, ",") .. ";" ..
		table.concat(props, ";") .. "]"
end

-- Button colours used for the clickable cards
local CARD_HOVER = "#FFFFFF14"
local CARD_PRESSED = "#FFFFFF2A"

local rewards = awards_mcl.rewards

-- Solid style for the claim action buttons (instant hover/pressed feedback)
local function action_style(name, bg, hover, pressed)
	return string.format(
		"style[%s;border=false;font_color=#FFFFFF;bgimg=[fill:64x64:0,0:%s;"
		.. "bgimg_hovered=[fill:64x64:0,0:%s;bgimg_pressed=[fill:64x64:0,0:%s]",
		name, bg, hover, pressed)
end

local CLAIM_BG = "#2F855A"
local CLAIM_HOVER = "#38A169"
local CLAIM_PRESSED = "#276749"
local CLAIM_ALL_BG = "#2B6CB0"
local CLAIM_ALL_HOVER = "#3B74C8"
local CLAIM_ALL_PRESSED = "#1E4A7A"

-- Reward preview row inside a detail-panel display box (8.3 wide, 4.7):
-- one item_image per reward (the engine renders the stack count) plus a
-- rect tooltip with the full name. `dim` adds the locked silhouette.
local function reward_row(fs, list, y, size, gap, dim)
	local n = #list
	if n == 0 then
		return
	end
	local w = n * size + (n - 1) * gap
	local x = 8.3 + (4.7 - w) / 2
	for i, rw in ipairs(list) do
		local rx = x + (i - 1) * (size + gap)
		fs[#fs + 1] = string.format("item_image[%.2f,%.2f;%.2f,%.2f;%s]",
			rx, y, size, size, rewards.icon_spec(rw))
		if dim then
			fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]",
				rx, y, size, size)
		end
		fs[#fs + 1] = string.format("tooltip[%.2f,%.2f;%.2f,%.2f;%s]",
			rx, y, size, size, core.formspec_escape(rewards.reward_label(rw)))
	end
end

-- ---------------------------------------------------------------------------
-- Shared window frame (header + tabs); returns fs table and tab rects
-- ---------------------------------------------------------------------------

local function build_frame(name, active_tab, subtitle)
	local fs = {
		"formspec_version[6]",
		"size[13.5,8.8]",
		"bgcolor[#0B0E14EE;true]",
		-- Override Mineclonia's bright default theme background (injected via
		-- the formspec prepend) so this GUI's dark theme stays consistent and
		-- the text colors don't clash with the light gray background
		"box[0,0;13.5,8.8;#0B0E14]",

		-- HEADER
		"box[0.3,0.3;12.9,0.9;#151B26]",
		"label[0.6,0.75;", core.formspec_escape(core.colorize("#FFD74A", "✦ AWARD COLLECTION")), "]",
		"label[8.3,0.75;", core.formspec_escape(core.colorize("#A0AEC0", subtitle)), "]",
		-- Close lives in the header: the bottom row of the detail panel is
		-- reserved for the reward claim buttons
		"style[close_ui;border=false;font_color=#B8C4D8;bgimg=[fill:64x64:0,0:#1A202C;"
			.. "bgimg_hovered=[fill:64x64:0,0:#2B3A55;bgimg_pressed=[fill:64x64:0,0:#151B26]",
		"button_exit[11.95,0.45;1.15,0.55;close_ui;Close]",
		"tooltip[close_ui;Tutup Award Collection]",

		-- CATEGORY TABS
	}
	local tabs = {
		{ id = "xp",     title = "XP Ranks",       w = 2.0 },
		{ id = "slayer", title = "Monster Slayer", w = 2.4 },
	}
	local x = 0.3
	for _, tab in ipairs(tabs) do
		local active = tab.id == active_tab
		-- Tabs are real buttons: colored fill + hover/pressed states so they
		-- clearly look clickable (the old gray box looked disabled).
		local bg = active and "#2B6CB0" or "#1A202C"
		local bg_hover = active and "#3B74C8" or "#2B3A55"
		local bg_pressed = active and "#1E4A7A" or "#151B26"
		local text_color = active and "#FFFFFF" or "#B8C4D8"
		fs[#fs + 1] = string.format(
			"style[select_tab_%s;border=false;font_color=%s;bgimg=[fill:64x64:0,0:%s;"
			.. "bgimg_hovered=[fill:64x64:0,0:%s;bgimg_pressed=[fill:64x64:0,0:%s]",
			tab.id, text_color, bg, bg_hover, bg_pressed)
		fs[#fs + 1] = string.format("button[%.2f,1.35;%.2f,0.55;select_tab_%s;%s]",
			x, tab.w, tab.id, tab.title)
		x = x + tab.w + 0.10
	end
	fs[#fs + 1] = "tooltip[select_tab_xp;Lihat medali XP Rank]"
	fs[#fs + 1] = "tooltip[select_tab_slayer;Lihat statistik Monster Slayer]"
	return fs
end

-- ---------------------------------------------------------------------------
-- TAB: XP Ranks
-- ---------------------------------------------------------------------------

local function build_xp_panel(fs, name, player, level, selected_idx)
	local ranks = awards_mcl.ranks
	local total_medals = #ranks - 1
	local unlocked_count = 0

	for i = 2, #ranks do
		if level >= ranks[i].level then
			unlocked_count = unlocked_count + 1
		end
	end

	local sel_rank = ranks[selected_idx]
	local is_sel_unlocked = level >= sel_rank.level

	-- LEFT PANEL: MEDAL CARD GRID
	fs[#fs + 1] = "box[0.3,2.05;7.6,6.45;#111622]"

	-- Transparent styles for the card buttons
	local style_names = {}
	for i = 2, #ranks do
		style_names[#style_names + 1] = "select_rank_" .. i
	end
	fs[#fs + 1] = style_block(style_names, CARD_HOVER, CARD_PRESSED)

	local col_count = 3
	local card_w = 2.25
	local card_h = 1.90
	local start_x = 0.55
	local start_y = 2.25
	local gap_x = 0.20
	local gap_y = 0.18

	for i = 2, #ranks do
		local r = ranks[i]
		local grid_pos = i - 2
		local col = grid_pos % col_count
		local row = math.floor(grid_pos / col_count)

		local cx = start_x + col * (card_w + gap_x)
		local cy = start_y + row * (card_h + gap_y)

		local unlocked = level >= r.level
		local is_selected = (i == selected_idx)

		local border_color = is_selected and "#FFD74A" or (unlocked and "#2D3748" or "#1A202C")
		local bg_color = is_selected and "#1E293B" or (unlocked and "#171E2E" or "#0D111A")

		-- Card frame and background
		fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;%s]", cx, cy, card_w, card_h, border_color)
		fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;%s]", cx + 0.05, cy + 0.05, card_w - 0.10, card_h - 0.10, bg_color)

		-- Render the medal item at the asset's native 40x80 (1:2) ratio, no squashing
		if r.texture then
			local img_w = 0.50
			local img_h = 1.00
			local img_x = cx + (card_w - img_w) / 2
			local img_y = cy + 0.10
			local item_name = "awards_mcl:item_" .. r.name:lower()

			fs[#fs + 1] = string.format("item_image[%.2f,%.2f;%.2f,%.2f;%s]", img_x, img_y, img_w, img_h, item_name)
			-- When locked, add a dark overlay for a silhouette effect
			if not unlocked then
				fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]", img_x, img_y, img_w, img_h)
			end
		end

		-- Rank name below the medal
		local title_color = unlocked and r.color or "#4A5568"
		local title_text = unlocked and r.name or "???"
		fs[#fs + 1] = string.format("label[%.2f,%.2f;%s]", cx + 0.22, cy + 1.32,
			core.formspec_escape(core.colorize(title_color, title_text)))

		-- Small level requirement
		fs[#fs + 1] = string.format("label[%.2f,%.2f;%s]", cx + 0.22, cy + 1.60,
			core.formspec_escape(core.colorize("#718096", "Lv. " .. r.level)))

		-- The clickable button must be the LAST element of the card. Luanti
		-- hands a mouse click to the topmost element under the cursor, so an
		-- image/label drawn on top would swallow it (clicks then seem to need
		-- several tries). The button background is transparent, so the medal
		-- and the labels stay visible underneath.
		fs[#fs + 1] = string.format("button[%.2f,%.2f;%.2f,%.2f;select_rank_%d;]",
			cx, cy, card_w, card_h, i)
	end

	-- ================= RIGHT PANEL: MEDAL DETAILS =================
	fs[#fs + 1] = "box[8.1,2.05;5.1,6.45;#151B26]"
	fs[#fs + 1] = "box[8.3,2.25;4.7,2.40;#0D111A]"

	if sel_rank.texture then
		local big_item = "awards_mcl:item_" .. sel_rank.name:lower()
		-- Native asset ratio 40x80 → width = height / 2
		local bx_w = 1.0
		local bx_h = 2.0
		local bx_pos = 8.3 + (4.7 - bx_w) / 2
		local bx_y = 2.32
		fs[#fs + 1] = string.format("item_image[%.2f,%.2f;%.2f,%.2f;%s]", bx_pos, bx_y, bx_w, bx_h, big_item)
		if not is_sel_unlocked then
			fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]", bx_pos, bx_y, bx_w, bx_h)
		end
	end

	local sel_title = is_sel_unlocked and sel_rank.name or (sel_rank.name .. " (Locked)")
	fs[#fs + 1] = string.format("label[8.4,4.85;%s]",
		core.formspec_escape(core.colorize(sel_rank.color, "★ " .. sel_title)))

	local status_str = is_sel_unlocked
		and core.colorize("#48BB78", "STATUS: UNLOCKED")
		or core.colorize("#F56565", "STATUS: LOCKED")
	fs[#fs + 1] = string.format("label[8.4,5.28;%s]", core.formspec_escape(status_str))

	fs[#fs + 1] = string.format("label[8.4,5.60;%s]",
		core.formspec_escape(core.colorize("#CBD5E0", S("Requirement: Reach XP Level @1", sel_rank.level))))
	fs[#fs + 1] = string.format("label[8.4,5.92;%s]",
		core.formspec_escape(core.colorize("#A0AEC0", S("Your Current Level: @1", level))))

	-- Rank aura (the particle effect that follows the player)
	if sel_rank.effect_name then
		local eff_color = is_sel_unlocked and sel_rank.color or "#4A5568"
		local eff_text = is_sel_unlocked and sel_rank.effect_name
			or S("@1 (Locked)", sel_rank.effect_name)
		fs[#fs + 1] = string.format("label[8.4,6.24;%s]",
			core.formspec_escape(core.colorize("#718096", S("Aura: ")) ..
				core.colorize(eff_color, eff_text)))
	end

	local preview_tag = core.colorize(sel_rank.color, "[" .. sel_rank.level .. " " .. sel_rank.name .. "]") .. " " .. name
	fs[#fs + 1] = string.format("label[8.4,6.56;%s]",
		core.formspec_escape(core.colorize("#718096", "Tag Preview: ") .. preview_tag))

	-- ---- Reward preview + claim controls -----------------------------
	local rw_list = sel_rank.rewards or {}
	local rw_state = rewards.rank_state(player, selected_idx)

	if #rw_list > 0 then
		local head_color = rw_state == "claimable" and "#FFD74A" or "#718096"
		fs[#fs + 1] = string.format("label[8.4,6.92;%s]",
			core.formspec_escape(core.colorize(head_color, "REWARDS:")))
		reward_row(fs, rw_list, 7.12, 0.42, 0.10, not is_sel_unlocked)
	end

	-- Claim controls MUST stay the last elements of this panel: Luanti
	-- hands the click to the topmost element (see note in the card grid).
	local pending = rewards.pending_ranks(player)
	if rw_state == "claimable" then
		local fname = "claim_rank_" .. selected_idx
		fs[#fs + 1] = action_style(fname, CLAIM_BG, CLAIM_HOVER, CLAIM_PRESSED)
		fs[#fs + 1] = "tooltip[" .. fname .. ";" ..
			core.formspec_escape(S("Klaim reward @1", sel_rank.name)) .. "]"
		fs[#fs + 1] = string.format("button[8.40,7.85;2.15,0.50;%s;CLAIM]", fname)
	elseif rw_state == "claimed" then
		fs[#fs + 1] = string.format("label[8.50,7.98;%s]",
			core.formspec_escape(core.colorize("#48BB78", "REWARD CLAIMED")))
	end
	if #pending > 0 then
		fs[#fs + 1] = action_style("claim_all_ranks",
			CLAIM_ALL_BG, CLAIM_ALL_HOVER, CLAIM_ALL_PRESSED)
		fs[#fs + 1] = "tooltip[claim_all_ranks;" ..
			core.formspec_escape(S("Klaim semua reward XP Rank yang belum diambil (@1)", #pending)) .. "]"
		fs[#fs + 1] = string.format("button[10.70,7.85;2.25,0.50;claim_all_ranks;CLAIM ALL (%d)]",
			#pending)
	end
end

-- ---------------------------------------------------------------------------
-- TAB: Monster Slayer
-- ---------------------------------------------------------------------------

local function build_slayer_panel(fs, name, player, selected_key)
	local slayer = awards_mcl.slayer
	local total_kills = slayer.get_total_kills(player)
	local total_entry = slayer.total
	local total_tier = slayer.tier_for(total_entry, total_kills)
	local max_total = total_entry.milestones[#total_entry.milestones]

	-- Trophy count across all 6 tiers x (5 mobs + overall)
	local trophies = 0
	for _, e in ipairs(slayer.entries) do
		trophies = trophies + slayer.tier_for(e, slayer.get_kills(player, e.key))
	end
	local trophy_max = slayer.TIER_COUNT * #slayer.entries

	-- LEFT PANEL
	fs[#fs + 1] = "box[0.3,2.05;7.6,6.45;#111622]"

	-- Banner: overall progress card with the current overall trophy
	-- (clickable: opens the Overall details on the right)
	local banner_border = total_tier > 0 and "#FFD74A" or "#2D3748"
	fs[#fs + 1] = style_block({ "select_slayer_total" }, CARD_HOVER, CARD_PRESSED)
	fs[#fs + 1] = "tooltip[select_slayer_total;Lihat rincian kill semua monster]"
	fs[#fs + 1] = string.format("box[0.55,2.25;7.1,1.00;%s]", banner_border)
	fs[#fs + 1] = "box[0.60,2.30;7.00,0.90;#0D111A]"

	local banner_tex = "awards_mcl_trophy_" .. math.max(1, total_tier) .. ".png"
	fs[#fs + 1] = "image[0.80,2.35;0.80,0.80;" .. banner_tex .. "]"
	if total_tier == 0 then
		fs[#fs + 1] = "box[0.80,2.35;0.80,0.80;#000000AA]"
	end
	fs[#fs + 1] = "label[1.75,2.62;"
		.. core.formspec_escape(core.colorize("#FFD74A", "⚔ " .. total_entry.title)) .. "]"
	fs[#fs + 1] = "label[1.75,3.02;"
		.. core.formspec_escape(core.colorize("#A0AEC0",
			S("@1 / @2 Kills", fmt(total_kills), fmt(max_total)))) .. "]"
	fs[#fs + 1] = "label[5.20,3.02;"
		.. core.formspec_escape(core.colorize("#718096",
			S("Trophies: @1/@2", trophies, trophy_max))) .. "]"
	-- Clickable button last: it must be the topmost element, otherwise the
	-- boxes/labels above would swallow the click (see note in the XP tab)
	fs[#fs + 1] = "button[0.55,2.25;7.1,1.00;select_slayer_total;]"

	-- MOB CARD GRID (5 mobs, 3 columns x 2 rows)
	local style_names = {}
	for _, e in ipairs(slayer.mobs) do
		style_names[#style_names + 1] = "select_slayer_" .. e.key
	end
	fs[#fs + 1] = style_block(style_names, CARD_HOVER, CARD_PRESSED)

	local col_count = 3
	local card_w = 2.25
	local card_h = 2.30
	local start_x = 0.55
	local start_y = 3.45
	local gap_x = 0.20
	local gap_y = 0.20

	for grid_pos, m in ipairs(slayer.mobs) do
		local col = (grid_pos - 1) % col_count
		local row = math.floor((grid_pos - 1) / col_count)
		local cx = start_x + col * (card_w + gap_x)
		local cy = start_y + row * (card_h + gap_y)

		local kills = slayer.get_kills(player, m.key)
		local tier = slayer.tier_for(m, kills)
		local is_selected = (m.key == selected_key)

		local border_color = is_selected and "#FFD74A" or (tier > 0 and "#2D3748" or "#1A202C")
		local bg_color = is_selected and "#1E293B" or (tier > 0 and "#171E2E" or "#0D111A")

		fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;%s]", cx, cy, card_w, card_h, border_color)
		fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;%s]",
			cx + 0.05, cy + 0.05, card_w - 0.10, card_h - 0.10, bg_color)

		-- Current trophy (Bronze silhouette while tier 0)
		local tex = "awards_mcl_trophy_" .. math.max(1, tier) .. ".png"
		local img_s = 0.80
		local img_x = cx + (card_w - img_s) / 2
		local img_y = cy + 0.12
		fs[#fs + 1] = string.format("image[%.2f,%.2f;%.2f,%.2f;%s]", img_x, img_y, img_s, img_s, tex)
		if tier == 0 then
			fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]", img_x, img_y, img_s, img_s)
		end

		-- Mob name + kill count
		local title_color = tier > 0 and m.color or "#4A5568"
		fs[#fs + 1] = string.format("label[%.2f,%.2f;%s]", cx + 0.22, cy + 1.18,
			core.formspec_escape(core.colorize(title_color, m.title)))
		fs[#fs + 1] = string.format("label[%.2f,%.2f;%s]", cx + 0.22, cy + 1.52,
			core.formspec_escape(core.colorize("#A0AEC0", fmt(kills) .. " Kills")))
		fs[#fs + 1] = string.format("label[%.2f,%.2f;%s]", cx + 0.22, cy + 1.85,
			core.formspec_escape(core.colorize("#718096",
				S("Tier @1/@2", tier, slayer.TIER_COUNT))))

		-- Clickable button last (topmost), see note in the XP tab
		fs[#fs + 1] = string.format("button[%.2f,%.2f;%.2f,%.2f;select_slayer_%s;]",
			cx, cy, card_w, card_h, m.key)
	end

	-- ================= RIGHT PANEL: SLAYER DETAILS =================
	fs[#fs + 1] = "box[8.1,2.05;5.1,6.45;#151B26]"
	fs[#fs + 1] = "box[8.3,2.25;4.7,2.50;#0D111A]"

	local sel = slayer.entry_by_key[selected_key] or total_entry
	local sel_kills = (sel.key == total_entry.key) and total_kills or slayer.get_kills(player, sel.key)
	local sel_tier = slayer.tier_for(sel, sel_kills)

	local big_s = 1.40
	fs[#fs + 1] = string.format("image[%.2f,%.2f;%.2f,%.2f;%s]",
		8.3 + (4.7 - big_s) / 2, 2.42, big_s, big_s,
		"awards_mcl_trophy_" .. math.max(1, sel_tier) .. ".png")
	if sel_tier == 0 then
		fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]",
			8.3 + (4.7 - big_s) / 2, 2.42, big_s, big_s)
	end

	-- Reward preview for the current trophy tier (dimmed silhouette while
	-- no trophy has been reached yet — it shows what the Bronze tier gives)
	local rw_tier = sel_tier > 0 and slayer.tiers[sel_tier] or slayer.tiers[1]
	reward_row(fs, rw_tier.rewards or {}, 3.90, 0.45, 0.10, sel_tier == 0)
	local rw_head
	if sel_tier > 0 then
		rw_head = core.colorize("#718096", S("Rewards: ")) ..
			core.colorize(rw_tier.color, rw_tier.name)
	else
		rw_head = core.colorize("#718096", S("Next reward: ")) ..
			core.colorize(rw_tier.color, rw_tier.name)
	end
	fs[#fs + 1] = string.format("label[8.4,4.42;%s]", core.formspec_escape(rw_head))

	local tier_name = sel_tier > 0 and slayer.tiers[sel_tier].name or S("No Trophy Yet")
	local tier_color = sel_tier > 0 and slayer.tiers[sel_tier].color or "#4A5568"

	fs[#fs + 1] = string.format("label[8.4,5.05;%s]",
		core.formspec_escape(core.colorize(sel.color, "⚔ " .. sel.title)))
	fs[#fs + 1] = string.format("label[8.4,5.50;%s]",
		core.formspec_escape(core.colorize(tier_color,
			S("Trophy: @1 (@2/@3)", tier_name, sel_tier, slayer.TIER_COUNT))))

	local milestone = sel.milestones[sel_tier + 1]
	if milestone then
		local prev = sel_tier > 0 and sel.milestones[sel_tier] or 0
		local frac = (sel_kills - prev) / (milestone - prev)
		fs[#fs + 1] = string.format("label[8.4,5.95;%s]",
			core.formspec_escape(core.colorize("#A0AEC0",
				S("Kills: @1  —  Next tier: @2", fmt(sel_kills), fmt(milestone)))))
		fs[#fs + 1] = progress_bar(8.4, 6.20, 4.30, frac, progress_color(frac))
	else
		fs[#fs + 1] = string.format("label[8.4,5.95;%s]",
			core.formspec_escape(core.colorize("#48BB78",
				S("Kills: @1  —  Max tier reached!", fmt(sel_kills)))))
		fs[#fs + 1] = progress_bar(8.4, 6.20, 4.30, 1, "#48BB78")
	end

	-- Overall entry: breakdown of kills per mob family (2 per line so it
	-- never overflows the 5.1-wide right panel)
	if sel.key == total_entry.key then
		local items = {}
		for _, m in ipairs(slayer.mobs) do
			items[#items + 1] = core.colorize(m.color, m.title) ..
				core.colorize("#718096", " " .. fmt(slayer.get_kills(player, m.key)))
		end
		for row = 1, 3 do
			local a = items[(row - 1) * 2 + 1]
			local b = items[(row - 1) * 2 + 2]
			if a then
				local text = a .. (b and ("    " .. b) or "")
				fs[#fs + 1] = string.format("label[8.4,%.2f;%s]",
					6.75 + (row - 1) * 0.30, core.formspec_escape(text))
			end
		end
	else
		-- Family entry: overall standing as extra info
		fs[#fs + 1] = string.format("label[8.4,6.95;%s]",
			core.formspec_escape(core.colorize("#718096",
				S("Overall: @1 / @2 Kills", fmt(total_kills), fmt(max_total)))))
		fs[#fs + 1] = string.format("label[8.4,7.45;%s]",
			core.formspec_escape(core.colorize("#718096",
				S("Trophies: @1 / @2", trophies, trophy_max))))
	end

	-- ---- Claim controls: LAST elements of the panel (topmost, receives
	-- the click — see note in the XP tab's card grid) -----------------
	local pending_sel = rewards.slayer_pending(player, sel)
	if #pending_sel > 0 then
		local fname = "claim_slayer_" .. sel.key
		fs[#fs + 1] = action_style(fname, CLAIM_BG, CLAIM_HOVER, CLAIM_PRESSED)
		fs[#fs + 1] = "tooltip[" .. fname .. ";" ..
			core.formspec_escape(S("Klaim reward trofi @1 (@2 belum diambil)",
				sel.title, #pending_sel)) .. "]"
		fs[#fs + 1] = string.format("button[8.40,7.85;2.15,0.50;%s;CLAIM (%d)]",
			fname, #pending_sel)
	elseif sel_tier > 0 then
		fs[#fs + 1] = string.format("label[8.50,7.98;%s]",
			core.formspec_escape(core.colorize("#48BB78", "REWARD CLAIMED")))
	end
	local all_pending = rewards.pending_slayer_count(player)
	if all_pending > 0 then
		fs[#fs + 1] = action_style("claim_all_slayer",
			CLAIM_ALL_BG, CLAIM_ALL_HOVER, CLAIM_ALL_PRESSED)
		fs[#fs + 1] = "tooltip[claim_all_slayer;" ..
			core.formspec_escape(S("Klaim semua reward trofi yang belum diambil (@1)",
				all_pending)) .. "]"
		fs[#fs + 1] = string.format("button[10.70,7.85;2.25,0.50;claim_all_slayer;CLAIM ALL (%d)]",
			all_pending)
	end
end

-- ---------------------------------------------------------------------------
-- Main entry
-- ---------------------------------------------------------------------------

function awards_mcl.show_collection_ui(player, selected_idx, tab, slayer_key)
	local name = player:get_player_name()
	local ok, level = pcall(mcl_experience.get_level, player)
	if not ok or type(level) ~= "number" then
		level = 0
	end

	tab = tab or selected_tab[name] or "xp"
	selected_tab[name] = tab

	local ranks = awards_mcl.ranks
	local unlocked_count = 0
	local current_highest_idx = 2
	for i = 2, #ranks do
		if level >= ranks[i].level then
			unlocked_count = unlocked_count + 1
			current_highest_idx = i
		end
	end

	local subtitle
	if tab == "slayer" then
		local slayer = awards_mcl.slayer
		slayer_key = slayer_key or selected_slayer_key[name]
		if not slayer.entry_by_key[slayer_key] then
			-- Default to the first family that already has kills, else Creeper
			slayer_key = "creeper"
			for _, m in ipairs(slayer.mobs) do
				if slayer.get_kills(player, m.key) > 0 then
					slayer_key = m.key
					break
				end
			end
		end
		selected_slayer_key[name] = slayer_key

		-- Trophy count across all 6 tiers x (5 mobs + overall)
		local trophies = 0
		for _, e in ipairs(slayer.entries) do
			trophies = trophies + slayer.tier_for(e, slayer.get_kills(player, e.key))
		end
		local trophy_max = slayer.TIER_COUNT * #slayer.entries
		local pending = rewards.pending_slayer_count(player)
		if pending > 0 then
			subtitle = core.colorize("#48BB78", S("@1 Rewards ready!", pending))
		else
			subtitle = S("Trophies: @1 / @2", fmt(trophies), fmt(trophy_max))
		end
	else
		slayer_key = nil
		local pending = #rewards.pending_ranks(player)
		if pending > 0 then
			subtitle = core.colorize("#48BB78", S("@1 Rewards ready!", pending))
		else
			subtitle = S("Unlocked: @1 / @2 Medals", unlocked_count, #ranks - 1)
		end
	end

	local fs = build_frame(name, tab, subtitle)

	if tab == "slayer" then
		build_slayer_panel(fs, name, player, slayer_key)
	else
		selected_idx = selected_idx or selected_rank_idx[name] or current_highest_idx
		selected_rank_idx[name] = selected_idx
		build_xp_panel(fs, name, player, level, selected_idx)
	end

	core.show_formspec(name, "awards_mcl:collection", table.concat(fs))
end

-- Handle button clicks from the inventory button as well as the collection GUI
core.register_on_player_receive_fields(function(player, formname, fields)
	if fields["awards_mcl_open_collection"] then
		awards_mcl.show_collection_ui(player)
		return true
	end

	if formname ~= "awards_mcl:collection" then
		return false
	end

	if fields.select_tab_slayer then
		awards_mcl.show_collection_ui(player, nil, "slayer")
		return true
	end
	if fields.select_tab_xp then
		awards_mcl.show_collection_ui(player, nil, "xp")
		return true
	end

	-- Reward claiming (re-show the same view so the state updates instantly)
	if fields.claim_all_ranks then
		rewards.claim_all_ranks(player)
		awards_mcl.show_collection_ui(player, nil, "xp")
		return true
	end
	for i = 2, #awards_mcl.ranks do
		if fields["claim_rank_" .. i] then
			rewards.claim_rank(player, i)
			awards_mcl.show_collection_ui(player, i, "xp")
			return true
		end
	end
	if fields.claim_all_slayer then
		rewards.claim_all_slayer(player)
		awards_mcl.show_collection_ui(player, nil, "slayer")
		return true
	end
	local slayer = awards_mcl.slayer
	for _, e in ipairs(slayer.entries) do
		if fields["claim_slayer_" .. e.key] then
			rewards.claim_slayer(player, e)
			awards_mcl.show_collection_ui(player, nil, "slayer", e.key)
			return true
		end
	end

	for i = 2, #awards_mcl.ranks do
		if fields["select_rank_" .. i] then
			awards_mcl.show_collection_ui(player, i, "xp")
			return true
		end
	end

	if fields.select_slayer_total then
		awards_mcl.show_collection_ui(player, nil, "slayer", "total")
		return true
	end
	for _, m in ipairs(slayer.mobs) do
		if fields["select_slayer_" .. m.key] then
			awards_mcl.show_collection_ui(player, nil, "slayer", m.key)
			return true
		end
	end

	return true
end)

-- ---------------------------------------------------------------------------
-- Chat command
-- ---------------------------------------------------------------------------

core.register_chatcommand("collection", {
	description = S("Open the Award Collection UI"),
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("You must be online to open the Award Collection.")
		end
		awards_mcl.show_collection_ui(player)
		return true
	end,
})
