local Mod = DorkyMod
local loader = Mod.PatchesLoader

local function coopGhostPatch()
	CustomCoopGhost.ChangeSkin(Mod.PLAYER_DORKY, "dorky")
	CustomCoopGhost.AddCostume(Mod.PLAYER_DORKY, "dorky")
	CustomCoopGhost.ChangeSkin(Mod.PLAYER_DORKY_B, "dorky_b")
	CustomCoopGhost.AddCostume(Mod.PLAYER_DORKY_B, "dorky_b")
end

loader:RegisterPatch("CustomCoopGhost", coopGhostPatch)
