# ✦ Awards MCL

**Awards MCL** is an immersive rank and achievement collection mod designed specifically for **Mineclonia** (Luanti engine). It adds a rewarding sense of progression, cosmetic flair, and an MMORPG-style collection interface for your players!

---

## ✨ Features

- **XP-Level Rank Medals:** Automatically tracks player experience levels and assigns prestigious tier medals (from Bronze up to Eternal).
- **Head & Chat Badges:** Floats a crisp bitmap medal above each player's head that smoothly follows their movement, paired with colored custom nametags and chat tags (`[Level Rank] Name`).
- **Progressive Rank Auras:** Every rank from Bronze to Eternal has a particle aura that follows the player — from sparse dirt dust and sand splashes, through bouncing stone chips, glowing minerals, shrinking crystals, rising flames and thunderstorms, up to a three-spawner **Supernova** at Eternal. Auras are attached to the player object, so they follow every step without per-tick server work.
- **MMORPG-Style "Award Collection" GUI:** Browse all medals and trophies in a sleek dark-mode grid UI, inspect locked/unlocked statuses, requirements, aura names, reward previews and dynamic tag previews.
- **Quick Inventory Access:** An elegant AWARDS button is integrated into the character box of the player inventory for instant access.
- **Monster Slayer Statistics:** Kills of Creepers, Witches, Zombies, Skeletons and Spiders (including variants like Husk, Stray and Cave Spider) are counted per family plus an overall total, persisted in player meta. Each family has 6 trophy tiers (Bronze → Legendary) viewable in the **Monster Slayer** tab, with tier-up announcements in chat.
- **Claimable MMORPG Rewards:** Every XP rank (Bronze → Eternal) and every Monster Slayer trophy tier (per family **and** the overall entry) carries a one-time item reward — valuables (Emeralds, Diamonds, blocks), survival consumables (Golden Apples, Totems, potions), utility (Name Tags, Saddles, Ender Pearls) and endgame prestige gear (Elytra, Nether Star). Claim them with the per-item **CLAIM** button or grab everything at once with **CLAIM ALL**. Rewards go into the inventory and drop at your feet if it is full; the claimed state persists in player meta.
- **Rank-Up Celebrations:** Celebratory sound effects, global chat announcements, and particle fireworks when a player ranks up.

---

## 🌟 Rank & Aura Progression

| Rank | XP Level | Aura |
| --- | --- | --- |
| Bronze | 5 | **Debu Tanah** — sparse dirt dust at the feet |
| Silver | 10 | **Percikan Pasir** — sand & gravel splashes |
| Gold | 15 | **Serpihan Batu** — stone chips that bounce off the ground |
| Diamond | 20 | **Kilau Mineral** — additive iron & gold sparkle |
| Netherite | 30 | **Energi Kristal** — shrinking diamond/emerald energy |
| Veteran | 40 | **Aura Api** — rising magma & redstone embers |
| Immortal | 55 | **Badai Petir** — gold flashes, stone dust & sparks |
| Untouchable | 75 | **Aura Dewa** — wide rotating crystal aura |
| Eternal | 100 | **Supernova** — core burst + wide energy ring + spark shower |

Effect definitions live in `effects.lua`. The aura name for each rank is the `effect_name` field in the rank table (`init.lua`); it is also shown in the **XP Ranks** detail panel and by `/rank`.

---

## 🎁 XP Rank Rewards

| Rank | XP Level | One-time reward |
| --- | --- | --- |
| Bronze | 5 | 5× Emerald, 8× Iron Ingot, 4× Cooked Beef |
| Silver | 10 | 10× Emerald, 2× Diamond, 1× Golden Apple, 16× Lapis Lazuli |
| Gold | 15 | 16× Emerald, 4× Diamond, 2× Golden Apple, 8× XP Bottle |
| Diamond | 20 | 24× Emerald, 8× Diamond, 1× Name Tag, 1× Saddle, 16× XP Bottle |
| Netherite | 30 | 32× Emerald, 12× Diamond, 2× Netherite Scrap, 1× Potion of Fire Resistance |
| Veteran | 40 | 48× Emerald, 16× Diamond, 1× Totem of Undying, 4× Golden Apple |
| Immortal | 55 | 1× Emerald Block, 24× Diamond, 1× Netherite Ingot, 1× Totem of Undying |
| Untouchable | 75 | 2× Emerald Block, 4× Diamond Block, 1× Enchanted Golden Apple, 2× Netherite Ingot |
| Eternal | 100 | 4× Emerald Block, 8× Diamond Block, 1× Elytra, 2× Enchanted Golden Apple, 2× Totem of Undying |

Reward tables live in the `rewards` field of the rank table (`init.lua`); claiming logic is in `rewards.lua`.

---

## ⚔️ Monster Slayer

Kill credit follows Mineclonia's own Monster Hunter rule: the mob must die within **5 seconds** of the player's last hit. Progress is stored per family plus an overall total, so it survives relog and server restart.

### Trophy milestones

| Family | Bronze | Silver | Gold | Platinum | Crystal | Legendary |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Creeper | 10 | 25 | 75 | 150 | 300 | 500 |
| Witch | 10 | 25 | 75 | 150 | 300 | 500 |
| Zombie | 25 | 75 | 150 | 500 | 1000 | 1500 |
| Skeleton | 25 | 75 | 150 | 500 | 1000 | 1500 |
| Spider | 10 | 50 | 100 | 300 | 600 | 1000 |
| **Overall** | 50 | 250 | 750 | 1500 | 3000 | 5000 |

Zombie includes Husk, Drowned and Villager Zombie; Skeleton includes Stray and Wither Skeleton; Spider includes Cave Spider.

### Trophy tier rewards

| Tier | One-time reward |
| --- | --- |
| Bronze | 3× Emerald, 4× Gold Ingot, 4× XP Bottle |
| Silver | 8× Emerald, 1× Diamond, 1× Golden Apple, 8× Ender Pearl |
| Gold | 16× Emerald, 3× Diamond, 2× Golden Apple, 16× XP Bottle |
| Platinum | 24× Emerald, 6× Diamond, 1× Netherite Scrap, 1× **Potion of Strength II** |
| Crystal | 32× Emerald, 12× Diamond, 1× Totem of Undying, 1× Netherite Ingot |
| Legendary | 2× Emerald Block, 3× Diamond Block, 1× Enchanted Golden Apple, 1× **Nether Star** |

Each of the 5 families **and** the overall entry has its own 6-tier track — **36 claims** in total. Tier rewards live in `slayer.tiers` (`monster_slayer.lua`).

---

## 🖥️ Award Collection GUI

Open it with the **AWARDS** button in the inventory or with `/collection`.

- **XP Ranks tab** — grid of all 9 rank medals. The detail panel shows status, requirement, current level, **aura name**, tag preview and a reward preview. Claim with **CLAIM** (selected rank) or **CLAIM ALL (n)** (every unlocked, unclaimed rank).
- **Monster Slayer tab** — overall banner plus 5 mob cards. The detail panel shows kills, progress toward the next tier, trophy and reward preview. Claim with **CLAIM (n)** (all unclaimed tiers of the selected entry) or **CLAIM ALL (n)** (all entries).
- The header subtitle switches to a green **"N Rewards ready!"** whenever something can be claimed.
- Claimed rewards show a green **REWARD CLAIMED** label. Claim buttons are drawn last (topmost), so the first click always registers.

Reward delivery: items go into the `main` inventory list; anything that does not fit is dropped at the player's feet (never destroyed). Each claim also sends a private chat summary plus a sound and a small XP-orb burst at the player's position.

---

## ⚙️ Settings

| Setting | Default | Description |
| --- | --- | --- |
| `awards_mcl.chat_tag` | `true` | Show the `[Level Rank]` tag before chat messages |
| `awards_mcl.head_medal` | `true` | Float the rank medal above each player's head |
| `awards_mcl.rankup_fanfare` | `true` | Play sound + particles on rank-up |
| `awards_mcl.rank_effects` | `true` | Show the rank aura that follows each player |
| `awards_mcl.rank_effects_visibility` | `all` | `all` = every player sees auras; `self` = only the player sees their own aura |
| `awards_mcl.slayer_announce` | `true` | Announce Monster Slayer tier-ups in chat |

Settings can be changed in the world configuration or in `minetest.conf` using the full key, e.g. `awards_mcl.rank_effects = false`.

---

## 🎮 Commands

- **`/rank`** — show your current rank, level, aura and progress toward the next tier.
- **`/rank list`** — also list all ranks from highest to lowest.
- **`/collection`** — open the Award Collection UI manually.

---

## 📦 Installation

1. Place the `awards_mcl` folder in your Luanti `mods/` directory.
2. Enable the mod for your world (World → Configure → Mods), or add `load_mod_awards_mcl = true` to the world's `world.mt`.
3. Make sure the world uses the **Mineclonia** game.

---

## 🔧 Technical Notes

- **Persistence:** Slayer kills (`awards_mcl:slayer_*`) and claimed rewards (`awards_mcl:claim_rank_*`, `awards_mcl:claim_slayer_*`) are stored in player meta, so they survive relog and server restart. Rank itself is always derived from the live XP level.
- **Auras:** one `core.add_particlespawner` call per effect layer, created with `time = 0` and `attached = player`. The engine follows the player automatically — no per-tick particle calls. Auras are re-applied on join, rank change and respawn, and removed on logout. All particle textures are vanilla Mineclonia textures (node or item textures) already shipped to clients.
- **Click reliability:** clickable cards and claim buttons are always the last elements of their panel, so Luanti's topmost-element click routing never swallows the first click.
- **Potion metadata:** Mineclonia potions store their level in stack metadata. The Platinum trophy uses `mcl_potions:strength` with `mcl_potions:potion_potent = 1` to produce a real **Potion of Strength II**.

---

## 📁 File Structure

| File | Purpose |
| --- | --- |
| `init.lua` | Rank table, medals, nametags, chat tags, rank polling, inventory badge |
| `monster_slayer.lua` | Mob families, milestones, trophy tiers and their rewards |
| `rewards.lua` | Claim state, delivery, chat/sound/particle announcement |
| `effects.lua` | Nine progressive rank auras |
| `collection_ui.lua` | Award Collection formspec (XP Ranks + Monster Slayer tabs) |
| `docs/` | Design notes and headless test suites |
| `textures/` | Medals, icons, trophy tiers and UI textures |

---

## ⚙️ Dependencies

- `mcl_core`
- `mcl_experience`
- `mcl_player`
- `mcl_mobs`

---

## 📜 License

Distributed under the **CC-BY-3.0** license. See `LICENSE.txt` for details.
