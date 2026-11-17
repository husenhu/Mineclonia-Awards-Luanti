-- collection_ui.lua — MMORPG Style Award Collection GUI
local S = core.get_translator(core.get_current_modname())

local selected_rank_idx = {}

function awards_mcl.show_collection_ui(player, selected_idx)
	local name = player:get_player_name()
	local ok, level = pcall(mcl_experience.get_level, player)
	if not ok or type(level) ~= "number" then
		level = 0
	end

	local ranks = awards_mcl.ranks
	local total_medals = #ranks - 1
	local unlocked_count = 0
	local current_highest_idx = 2

	for i = 2, #ranks do
		if level >= ranks[i].level then
			unlocked_count = unlocked_count + 1
			current_highest_idx = i
		end
	end

	selected_idx = selected_idx or selected_rank_idx[name] or current_highest_idx
	selected_rank_idx[name] = selected_idx

	local sel_rank = ranks[selected_idx]
	local is_sel_unlocked = level >= sel_rank.level

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
		"label[8.8,0.75;", core.formspec_escape(core.colorize("#A0AEC0",
			S("Unlocked: @1 / @2 Medals", unlocked_count, total_medals))), "]",

		-- CATEGORY TABS
		"box[0.3,1.35;2.2,0.55;#2B6CB0]",
		"label[0.65,1.62;", core.formspec_escape(core.colorize("#FFFFFF", "XP Ranks")), "]",
		"box[2.6,1.35;2.4,0.55;#1A202C]",
		"label[2.9,1.62;", core.formspec_escape(core.colorize("#718096", "Quests (Soon)")), "]",

		-- LEFT PANEL: MEDAL CARD GRID
		"box[0.3,2.05;7.6,6.45;#111622]",
	}

	-- Card buttons are made transparent: Mineclonia's default style gives
	-- every button a light gray background (mcl_inventory_button9.png) that
	-- covers the card colors and makes the medal text look washed out
	local style_names = {}
	for i = 2, #ranks do
		style_names[#style_names + 1] = "select_rank_" .. i
	end
	fs[#fs + 1] = "style[" .. table.concat(style_names, ",") ..
		";bgimg=awards_mcl_blank.png;bgimg_pressed=awards_mcl_blank.png;border=false]"

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

		-- Interactive button is drawn FIRST so the medal image and labels
		-- are not covered by the button's default background
		fs[#fs + 1] = string.format("button[%.2f,%.2f;%.2f,%.2f;select_rank_%d;]", cx, cy, card_w, card_h, i)

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
	end

	-- ================= RIGHT PANEL: MEDAL DETAILS =================
	fs[#fs + 1] = "box[8.1,2.05;5.1,6.45;#151B26]"
	fs[#fs + 1] = "box[8.3,2.25;4.7,2.80;#0D111A]"

	if sel_rank.texture then
		local big_item = "awards_mcl:item_" .. sel_rank.name:lower()
		-- Native asset ratio 40x80 → width = height / 2
		local bx_w = 1.0
		local bx_h = 2.0
		local bx_pos = 8.3 + (4.7 - bx_w) / 2
		local bx_y = 2.40
		fs[#fs + 1] = string.format("item_image[%.2f,%.2f;%.2f,%.2f;%s]", bx_pos, bx_y, bx_w, bx_h, big_item)
		if not is_sel_unlocked then
			fs[#fs + 1] = string.format("box[%.2f,%.2f;%.2f,%.2f;#000000AA]", bx_pos, bx_y, bx_w, bx_h)
		end
	end

	local sel_title = is_sel_unlocked and sel_rank.name or (sel_rank.name .. " (Locked)")
	fs[#fs + 1] = string.format("label[8.4,5.40;%s]",
		core.formspec_escape(core.colorize(sel_rank.color, "★ " .. sel_title)))

	local status_str = is_sel_unlocked
		and core.colorize("#48BB78", "STATUS: UNLOCKED")
		or core.colorize("#F56565", "STATUS: LOCKED")
	fs[#fs + 1] = string.format("label[8.4,5.85;%s]", core.formspec_escape(status_str))

	fs[#fs + 1] = string.format("label[8.4,6.35;%s]",
		core.formspec_escape(core.colorize("#CBD5E0", S("Requirement: Reach XP Level @1", sel_rank.level))))
	fs[#fs + 1] = string.format("label[8.4,6.75;%s]",
		core.formspec_escape(core.colorize("#A0AEC0", S("Your Current Level: @1", level))))

	local preview_tag = core.colorize(sel_rank.color, "[" .. sel_rank.level .. " " .. sel_rank.name .. "]") .. " " .. name
	fs[#fs + 1] = string.format("label[8.4,7.25;%s]",
		core.formspec_escape(core.colorize("#718096", "Tag Preview: ") .. preview_tag))

	fs[#fs + 1] = "button_exit[10.8,7.80;2.2,0.50;close_ui;Close]"

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

	for i = 2, #awards_mcl.ranks do
		if fields["select_rank_" .. i] then
			awards_mcl.show_collection_ui(player, i)
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