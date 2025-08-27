---@class ModReference
_G.DorkyMod = RegisterMod("Dorky", 1)

DorkyMod.Version = "1.2"

---@class ModReference
local Mod = DorkyMod

DorkyMod.Game = Game()
DorkyMod.SFX = SFXManager()

DorkyMod.GENERIC_RNG = RNG()

DorkyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
	local seed = DorkyMod.Game:GetSeeds():GetStartSeed()
	DorkyMod.GENERIC_RNG:SetSeed(seed)
end)

DorkyMod.RANGE_BASE_MULT = 40

DorkyMod.Character = {}
DorkyMod.Item = {}
DorkyMod.Misc = {}

DorkyMod.PLAYER_DORKY = Isaac.GetPlayerTypeByName("Dorky", false)
DorkyMod.PLAYER_DORKY_B = Isaac.GetPlayerTypeByName("The Void", true)
DorkyMod.COLLECTIBLE_TONGUE_GRAPPLE = Isaac.GetItemIdByName("Tongue Grapple")
DorkyMod.COLLECTIBLE_SOUL_DRAIN = Isaac.GetItemIdByName("Soul Drain")

DorkyMod.FileLoadError = false
DorkyMod.InvalidPathError = false

---Mimics include() but with a pcall safety wrapper and appropriate error codes if any are found
---
---VSCode users: Go to Settings > Lua > Runtime:Special and link Eldritch.Include to require, just like you would regular include!
---@return unknown
function DorkyMod.Include(path)
	Isaac.DebugString(string.format("[%s] Loading " .. path, Mod.Name))
	local wasLoaded, result = pcall(include, path)
	local errMsg = ""
	local foundError = false
	if not wasLoaded then
		DorkyMod.FileLoadError = true
		foundError = true
		errMsg = 'Error in path "' .. path .. '":\n' .. result .. '\n'
	elseif result and type(result) == "string" and string.find(result, "no file '") then
		foundError = true
		DorkyMod.InvalidPathError = true
		errMsg = 'Unable to locate file in path "' .. path .. '"\n'
	end
	if foundError then
		DorkyMod:Log(errMsg)
	end
	return result
end

function DorkyMod.LoopInclude(tab, path)
	for _, fileName in pairs(tab) do
		DorkyMod.Include(path .. "." .. fileName)
	end
end

local tools = {
	"debug_tools",
	"hud_helper",
}

local helpers = {
	"misc_util"
}

Mod.LoopInclude(tools, "scripts.tools")
Mod.LoopInclude(helpers, "scripts.helpers")
Mod.Include("flags")
Mod.Include("scripts.tools.vendor.throwableitemlib").Init()

local characters = {
	"dorky.character_dorky",
	"dorky.tongue_grapple",
	"dorky_b.character_dorky_b",
	"dorky_b.soul_drain",
	"character_setup"
}

Mod.LoopInclude(characters, "scripts.dorky_character")

--[[

---@param player EntityPlayer
function mod:OnPlayerUpdate(player)
	spiritMechanics:healFromSpiritSpike(player)
	spiritMechanics:shouldThrowSpiritSpike(player)
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.OnPlayerUpdate)


mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, spiritMechanics.evisCordSpikeUpdate, EntityType.ENTITY_VIS)
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, spiritMechanics.restoreFlashOnDamage)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, spiritMechanics.onSoulStealUse, g.COLLECTIBLE_SOUL_DRAIN)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, spiritMechanics.onSpikeDamage)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, spiritMechanics.dummySpikeTargetAI,
	g.SPIRIT_SPIKE_DUMMY_TARGET)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, spiritMechanics.spiritSpikeHandlerUpdate, g.SPIRIT_SPIKE_ROPE_HANDLER)

mod:AddCallback(ModCallbacks.MC_POST_RENDER, dorkyMechanics.Debug)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, spiritHUDRender.OnRender) ]]

--!End of file

Mod.Include("scripts.compatibility.patches.eid_support")
Mod.Include("scripts.compatibility.patches_loader")

if Mod.FileLoadError then
	Mod:Log("Mod failed to load! Report this to Benny in the dev server!")
elseif Mod.InvalidPathError then
	Mod:Log("One or more files were unable to be loaded. Report this to Benny in the dev server!")
else
	Mod:Log("v" .. Mod.Version .. " successfully loaded!")
end

DorkyMod.Include = nil
DorkyMod.LoopInclude = nil
