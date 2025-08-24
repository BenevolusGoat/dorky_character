local Mod = DorkyMod
local loader = Mod.PatchesLoader

local function pogCostumePatch()
	Poglite:AddPogCostume("DorkyPog", Mod.PLAYER_DORKY,
		Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_pog.anm2"))
	Poglite:AddPogCostume("DorkyBPog", Mod.PLAYER_DORKY_B,
		Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_b_pog.anm2"))
end

loader:RegisterPatch("Poglite", pogCostumePatch, "Pog For Good Items")
