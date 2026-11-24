-- Headless test for the rewards system (awards_mcl)
local store = {}
local given_log = {}
local drop_log = {}
local chat_log = {}
local captured = {}

local mock_inv = {
	add_item = function(self, list, stack)
		given_log[#given_log + 1] = ItemStack(stack:to_string())
		return ItemStack("")
	end,
}

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
	get_inventory = function() return mock_inv end,
	get_string = function() return "" end,
}

local function last_pos(s, pat)
	local pos, p = 0, 1
	while true do
		local a, b = s:find(pat, p, true)
		if not a then break end
		pos, p = a, b + 1
	end
	return pos
end

core.after(3, function()
	-- patch globals used by the UI / claim flow
	local real_getpbn = core.get_player_by_name
	core.get_player_by_name = function(n)
		if n == "TestKiller" then return mock end
		return real_getpbn(n)
	end
	local real_level = mcl_experience.get_level
	mcl_experience.get_level = function(p)
		if p == mock then return mock.level or 0 end
		return real_level(p)
	end
	core.show_formspec = function(name, formname, fs)
		captured[#captured + 1] = fs
		return true
	end
	core.chat_send_player = function(name, msg)
		chat_log[#chat_log + 1] = msg
		return true
	end
	core.add_item = function(pos, stack)
		drop_log[#drop_log + 1] = ItemStack(stack:to_string())
		return nil
	end

	local R = awards_mcl.rewards
	local slayer = awards_mcl.slayer
	local ok, err = pcall(function()
		-- 1. every configured reward itemstring must exist in Mineclonia
		local function check(list, ctx)
			for _, rw in ipairs(list) do
				local spec = R.icon_spec(rw)
				local item = spec:match("^(%S+)")
				assert(core.registered_items[item],
					ctx .. ": missing item " .. tostring(item))
			end
		end
		for _, r in ipairs(awards_mcl.ranks) do check(r.rewards, "rank " .. r.name) end
		for _, t in ipairs(slayer.tiers) do check(t.rewards, "tier " .. t.name) end
		core.log("action", "[awards_test] 1. all reward itemstrings valid")

		-- 2. XP rank claims at level 100
		mock.level = 100
		local pend = R.pending_ranks(mock)
		assert(#pend == 9, "expected 9 pending ranks, got " .. #pend)

		local g = R.claim_rank(mock, 2)
		assert(g and #g == 3, "bronze should give 3 stacks")
		assert(store["awards_mcl:claim_rank_2"] == 1, "bronze flagged")
		assert(R.claim_rank(mock, 2) == nil, "no double claim")
		assert(#given_log == 3, "3 items given")
		assert(given_log[1]:get_name() == "mcl_core:emerald"
			and given_log[1]:get_count() == 5, "5 emeralds first")

		-- claim-all remaining: silver4+gold4+diamond5+netherite4+veteran4
		-- +immortal4+untouchable4+eternal5 = 34 stacks
		local g2 = R.claim_all_ranks(mock)
		assert(#g2 == 34, "expected 34 stacks from claim_all, got " .. #g2)
		assert(#R.pending_ranks(mock) == 0, "no pending ranks left")
		for i = 2, 10 do
			assert(store["awards_mcl:claim_rank_" .. i] == 1,
				"rank " .. i .. " flagged")
		end
		local has_elytra = false
		for _, st in ipairs(g2) do
			if st:get_name() == "mcl_armor:elytra" then has_elytra = true end
		end
		assert(has_elytra, "Eternal gives an Elytra")
		core.log("action", "[awards_test] 2. rank claims OK (9 ranks, 37 stacks)")

		-- 3. full inventory: leftover must drop at the player's feet
		local orig_add = mock_inv.add_item
		local calls = 0
		mock_inv.add_item = function(self, list, stack)
			calls = calls + 1
			given_log[#given_log + 1] = ItemStack(stack:to_string())
			if calls == 1 then return stack end -- pretend the inventory is full
			return ItemStack("")
		end
		store["awards_mcl:claim_rank_2"] = 0
		local g3 = R.claim_rank(mock, 2)
		assert(g3 and #g3 == 3, "re-claim bronze")
		assert(#drop_log == 1, "one stack dropped, got " .. #drop_log)
		assert(drop_log[1]:get_name() == "mcl_core:emerald"
			and drop_log[1]:get_count() == 5, "emerald dropped")
		mock_inv.add_item = orig_add
		store["awards_mcl:claim_rank_2"] = 1
		core.log("action", "[awards_test] 3. full-inventory drop OK")

		-- 4. slayer claims
		store["awards_mcl:slayer_creeper"] = 10 -- Bronze tier (10 kills)
		local creeper = slayer.entry_by_key.creeper
		local p1 = R.slayer_pending(mock, creeper)
		assert(#p1 == 1 and p1[1] == 1, "creeper pending = {1}, got " .. #p1)
		local gs = R.claim_slayer(mock, creeper)
		assert(gs and #gs == 3, "bronze trophy gives 3 stacks, got "
			.. (gs and #gs or "nil"))
		assert(store["awards_mcl:claim_slayer_creeper_1"] == 1, "creeper t1 flagged")
		assert(R.claim_slayer(mock, creeper) == nil, "no double slayer claim")

		-- Platinum tier special: Potion of Strength II via stack meta
		store["awards_mcl:slayer_zombie"] = 500 -- tiers 1..4 (25/75/150/500)
		local zombie = slayer.entry_by_key.zombie
		local gz = R.claim_slayer(mock, zombie)
		assert(gz and #gz == 15, "zombie tiers 1-4 = 3+4+4+4 = 15 stacks, got "
			.. (gz and #gz or "nil"))
		local str
		for _, st in ipairs(gz) do
			if st:get_name() == "mcl_potions:strength" then str = st end
		end
		assert(str, "strength potion given")
		assert(str:get_meta():get_int("mcl_potions:potion_potent") == 1,
			"potency 1 = Strength II")
		local desc = str:get_meta():get_string("description")
		assert(desc:find("II", 1, true), "description shows II, got: " .. desc)
		core.log("action", "[awards_test] 4. slayer claims OK (Strength II: '"
			.. desc .. "')")

		-- 5. claim-all slayer (remaining families + overall)
		store["awards_mcl:slayer_witch"] = 500
		store["awards_mcl:slayer_skeleton"] = 1500
		store["awards_mcl:slayer_spider"] = 1000
		store["awards_mcl:slayer_total"] = 5000
		assert(R.pending_slayer_count(mock) > 0, "pending slayer > 0")
		R.claim_all_slayer(mock)
		assert(R.pending_slayer_count(mock) == 0, "all slayer tiers claimed")
		for t = 1, 6 do
			assert(store["awards_mcl:claim_slayer_total_" .. t] == 1,
				"overall tier " .. t .. " flagged")
		end
		core.log("action", "[awards_test] 5. claim-all slayer OK (36 tier claims)")

		-- 6. find the collection handler
		local handler
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			captured = {}
			pcall(fn, mock, "awards_mcl:collection", { select_tab_slayer = "" })
			if captured[1] and captured[1]:find("AWARD COLLECTION", 1, true) then
				handler = fn
				break
			end
		end
		assert(handler, "collection handler found")

		-- 7. XP tab with everything claimed
		captured = {}
		handler(mock, "awards_mcl:collection", { select_tab_xp = "" })
		local xfs = captured[#captured]
		assert(xfs, "xp formspec shown")
		assert(xfs:find("REWARD CLAIMED", 1, true), "claimed label present")
		assert(not xfs:find("claim_all_ranks", 1, true),
			"no claim-all when nothing pending")
		assert(not xfs:find("claim_rank_", 1, true), "no rank claim buttons")
		assert(xfs:find("mcl_core:emeraldblock 4", 1, true),
			"Eternal reward icons shown")
		assert(xfs:find("mcl_armor:elytra 1", 1, true), "elytra icon shown")
		assert(xfs:find("close_ui", 1, true), "close button in header")
		core.log("action", "[awards_test] 6. XP tab (all claimed) OK")

		-- 8. one rank unclaimed: button appears, must be topmost, click works
		store["awards_mcl:claim_rank_10"] = 0
		captured = {}
		handler(mock, "awards_mcl:collection", { select_tab_xp = "" })
		xfs = captured[#captured]
		assert(xfs:find("claim_rank_10", 1, true), "eternal claim button shown")
		assert(xfs:find("claim_all_ranks", 1, true), "claim-all shown (1 pending)")
		assert(last_pos(xfs, "button[") > last_pos(xfs, "label["),
			"buttons drawn after labels")
		assert(last_pos(xfs, "button[") > last_pos(xfs, "item_image["),
			"buttons drawn after item images")
		assert(last_pos(xfs, "button[") > last_pos(xfs, "box["),
			"buttons drawn after boxes")

		captured = {}
		handler(mock, "awards_mcl:collection", { claim_rank_10 = "" })
		assert(store["awards_mcl:claim_rank_10"] == 1, "GUI rank claim works")
		xfs = captured[#captured]
		assert(xfs:find("REWARD CLAIMED", 1, true), "UI refreshed after claim")
		assert(not xfs:find("claim_all_ranks", 1, true), "claim-all gone")
		core.log("action", "[awards_test] 7. XP claim button + topmost OK")

		-- 9. slayer tab: one creeper tier unclaimed again
		store["awards_mcl:claim_slayer_creeper_1"] = 0
		captured = {}
		handler(mock, "awards_mcl:collection", { select_tab_slayer = "" })
		local sfs = captured[#captured]
		assert(sfs:find("claim_slayer_creeper", 1, true), "creeper claim button")
		assert(sfs:find("claim_all_slayer", 1, true), "claim-all slayer shown")
		assert(sfs:find("mcl_core:emerald 3", 1, true), "creeper bronze icons")
		assert(sfs:find("select_slayer_total", 1, true), "banner still present")
		assert(last_pos(sfs, "button[") > last_pos(sfs, "label["),
			"slayer buttons drawn after labels")

		captured = {}
		handler(mock, "awards_mcl:collection", { claim_slayer_creeper = "" })
		assert(store["awards_mcl:claim_slayer_creeper_1"] == 1,
			"GUI slayer claim works")
		sfs = captured[#captured]
		assert(sfs:find("REWARD CLAIMED", 1, true), "slayer UI refreshed")

		-- 10. subtitle advertises ready rewards
		store["awards_mcl:claim_rank_5"] = 0
		captured = {}
		handler(mock, "awards_mcl:collection", { select_tab_xp = "" })
		xfs = captured[#captured]
		-- translated strings wrap args in ESC markers (\x1bF1\x1bE), so
		-- match the marker-free part of the sentence
		assert(xfs:find("Rewards ready!", 1, true), "subtitle shows pending")

		-- 11. claim messages went to chat
		assert(#chat_log > 0, "claim chat messages sent")
		local found = false
		for _, m in ipairs(chat_log) do
			if m:find("claimed", 1, true) then found = true end
		end
		assert(found, "chat contains a claim message")
		core.log("action", "[awards_test] 8-11. GUI claim + subtitle + chat OK")
	end)

	if ok then
		core.log("action", "[awards_test] ALL REWARD TESTS PASSED")
	else
		core.log("error", "[awards_test] FAILED: " .. tostring(err))
	end
	core.after(1, function() core.request_shutdown() end)
end)
