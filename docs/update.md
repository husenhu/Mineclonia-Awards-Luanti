Biar sistem reward-nya terasa seperti game MMORPG (progresif, memuaskan, tapi tetap *balanced* dan tidak merusak ekonomi *survival* di Mineclonia), item hadiahnya sebaiknya dibagi menjadi 4 kategori: **Currency/Valuables**, **Consumables/Buffs**, **Utility/Exploration**, dan **Endgame/Prestige**.

Berikut referensi item Mineclonia (*itemstring* standar `mcl_*`) beserta skema pembagian hadiah untuk kedua sistem tersebut:

---

### 1. Rekomendasi Pool Item Mineclonia (Selain Diamond & Emerald)

* **Currency & Mineral Langka:**
* `mcl_core:gold_ingot` / `mcl_core:goldblock` (bahan Golden Apple & barter Piglin)
* `mcl_nether:netherite_scrap` & `mcl_nether:netherite_ingot` (untuk tier atas)
* `mcl_core:emeraldblock` & `mcl_core:diamondblock` (pengganti stack besar agar hemat slot inventory)


* **Consumables & Survival Buffs (Sangat berguna untuk mempertahankan streak level):**
* `mcl_core:apple_gold` (Golden Apple biasa)
* `mcl_core:apple_gold_enchanted` (Enchanted Golden Apple / Notch Apple — hadiah puncak)
* `mcl_potions:healing_2` / `mcl_potions:regeneration` / `mcl_potions:fire_resistance`
* `mcl_totems:totem` (Totem of Undying — krusial agar XP Rank tidak reset saat hampir mati!)


* **Enchanting & Upgrade:**
* `mcl_experience:bottle` (Bottle o' Enchanting)
* `mcl_core:lapis` (Lapis Lazuli untuk enchanting)
* `mcl_anvil:anvil` atau buku enchanted (misal Mending / Unbreaking III via Lua `mcl_enchanting`)


* **Utility & Prestige (Rasa MMORPG):**
* `mcl_mobitems:name_tag` & `mcl_mobitems:saddle`
* `mcl_end:ender_eye` / `mcl_throwing:ender_pearl`
* `mcl_armor:elytra` atau `mcl_nether:beacon` / `mcl_mobitems:nether_star` (khusus tier tertinggi)
* `mcl_heads:wither_skeleton` / kepala mob (dekorasi base)



---

### 2. Skema Reward: XP Rank (Bertahan Hidup)

Fokus hadiah di sini adalah **survival sustain** (membantu player agar tidak mati dan bisa terus naik ke level 100) plus prestise.

| Rank | Level | Valuables (Emerald & Diamond) | Bonus Item MMORPG |
| --- | --- | --- | --- |
| **Bronze** | 5 | 5x Emerald | 8x Iron Ingot, 4x Cooked Beef (`mcl_mobitems:cooked_beef`) |
| **Silver** | 10 | 10x Emerald, 2x Diamond | 1x Golden Apple, 16x Lapis Lazuli |
| **Gold** | 15 | 16x Emerald, 4x Diamond | 2x Golden Apple, 8x Bottle o' Enchanting |
| **Diamond** | 20 | 24x Emerald, 8x Diamond | 1x Name Tag, 1x Saddle, 16x Bottle o' Enchanting |
| **Netherite** | 30 | 32x Emerald, 12x Diamond | 2x Netherite Scrap, 1x Potion of Fire Resistance |
| **Veteran** | 40 | 48x Emerald, 16x Diamond | **1x Totem of Undying**, 4x Golden Apple |
| **Immortal** | 55 | 1x Emerald Block (9), 24x Diamond | 1x Netherite Ingot, 1x Totem of Undying |
| **Untouchable** | 75 | 2x Emerald Block, 4x Diamond Block | **1x Enchanted Golden Apple**, 2x Netherite Ingot |
| **Eternal** | 100 | 4x Emerald Block, 8x Diamond Block | **1x Elytra** (atau Nether Star), 2x Enchanted Golden Apple, 2x Totem |

---

### 3. Skema Reward: Monster Slayer (Per Tipe Monster)

Karena tier ini berlaku **untuk setiap jenis monster** (Zombie, Skeleton, Creeper, Enderman, dll.), jumlahnya harus sedikit lebih terkontrol dibanding XP Rank agar tidak *inflasi* jika player rajin *grinding* mob farm.

| Tier Trophy | Valuables (Emerald & Diamond) | Bonus Item MMORPG |
| --- | --- | --- |
| **Bronze** | 3x Emerald | 4x Gold Ingot, 4x Bottle o' Enchanting |
| **Silver** | 8x Emerald, 1x Diamond | 1x Golden Apple, 8x Ender Pearl |
| **Gold** | 16x Emerald, 3x Diamond | 2x Golden Apple, 16x Bottle o' Enchanting |
| **Platinum** | 24x Emerald, 6x Diamond | 1x Netherite Scrap, 1x Potion of Strength II |
| **Crystal** | 32x Emerald, 12x Diamond | 1x Totem of Undying, 1x Netherite Ingot |
| **Legendary** | 2x Emerald Block, 3x Diamond Block | **1x Enchanted Golden Apple**, **1x Nether Star** (atau 2x Netherite Ingot) |

---

### 4. Contoh Struktur Tabel Lua (Siap Pakai di Mod)

Supaya gampang di-loop saat player menekan tombol **Claim Reward** di formspec (atau otomatis masuk inventory + jatuh ke tanah jika penuh), kamu bisa menambahkan field `rewards` langsung di tabel `ranks` dan `slayer.tiers`:

```lua
local ranks = {
	{ name = "Nothing", level = 0, color = "#FFFFFF", texture = nil, rewards = {} },
	{
		name = "Bronze",
		level = 5,
		color = "#DA9A3C",
		texture = "awards_mcl_bronze.png",
		rewards = {
			"mcl_core:emerald 5",
			"mcl_core:iron_ingot 8",
			"mcl_mobitems:cooked_beef 4",
		},
	},
	{
		name = "Silver",
		level = 10,
		color = "#D8DCE0",
		texture = "awards_mcl_silver.png",
		rewards = {
			"mcl_core:emerald 10",
			"mcl_core:diamond 2",
			"mcl_core:apple_gold 1",
		},
	},
	-- ... lanjutkan sesuai tabel di atas
}

```

**Tips mekanik ala MMORPG untuk mod ini:**

* **Sistem Claim via GUI (Formspec):** Simpan status klaim di form Awards Collection >> tab XP Ranks dan Monster Slayer. sediakan tombol claimnya di form itu. maksud saya di XP Ranks ada tombol claim khusus XP Ranks dan di Monster Slayer ada tombol Claim untuk rewards monster slayer. 