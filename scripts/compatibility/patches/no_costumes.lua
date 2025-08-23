local Mod = DorkyMod
local loader = Mod.PatchesLoader

local function noCostumesPatch()
	addCostumeToIgnoreList("gfx/characters/costume_dorky.anm2")
	addCostumeToIgnoreList("gfx/characters/costume_dorky_tongueout.anm2")
	addCostumeToIgnoreList("gfx/characters/costume_dorky_flight.anm2")
	addCostumeToIgnoreList("gfx/characters/costume_dorky_pog.anm2")
	addCostumeToIgnoreList("gfx/characters/costume_dorky_b.anm2")
end

loader:RegisterPatch("addCostumeToIgnoreList", noCostumesPatch, "No Costumes")
