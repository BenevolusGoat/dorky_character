local mod = RegisterMod("TestMod", 1)
local g = require("src_dorky.dorkyGlobals")
local ccp = require("src_dorky.characterCostumeProtector")
ccp:Init(mod)
local dorkyStats = include("src_dorky.dorkyStats")
local dorkyMechanics = include("src_dorky.dorkyMechanics")
local dorkyMisc = include("src_dorky.dorkyMisc")
local modSupport = include("src_dorky.modSupport")
local spiritMechanics = include("src_dorky.spiritMechanics")
local spiritHUDRender = include("src_dorky.hudRender")

---@param player EntityPlayer
function mod:OnPlayerInit(player)
	local playerType = player:GetPlayerType()

	if playerType == g.PLAYER_DORKY or playerType == g.PLAYER_SPIRIT then
		modSupport:OnPlayerInit(player, ccp)
		dorkyMechanics:PocketActiveStart(player)
	end
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.OnPlayerInit, 0)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, dorkyStats.OnCache)

---@param player EntityPlayer
function mod:OnPlayerUpdate(player)
	local playerType = player:GetPlayerType()

	dorkyMisc:customAnm2Handling(player)

	if playerType == g.PLAYER_DORKY then
		dorkyMechanics:NoRedHealth(player)
		dorkyMisc:spawnBlackGoopOnDeath(player)
	elseif playerType == g.PLAYER_SPIRIT then
		spiritMechanics:onlyBlackHealth(player)
		spiritMechanics:healFromSpiritSpike(player)
		spiritMechanics:shouldThrowSpiritSpike(player)
		spiritMechanics:voidRegeneration(player)
		dorkyMisc:spiritDeathEffects(player)
	end
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.OnPlayerUpdate)

function mod:prePickupCollision(heart, collider, _)
	if collider:ToPlayer() then
		local playerType = collider:ToPlayer():GetPlayerType()

		if playerType == g.PLAYER_DORKY then
			return dorkyMechanics:IgnoreHeartPickups(heart)
		elseif playerType == g.PLAYER_SPIRIT then
			return spiritMechanics:ignoreMostHearts(heart, collider:ToPlayer())
		end
	end
end

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, mod.prePickupCollision, PickupVariant.PICKUP_HEART)

mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, dorkyMechanics.PreTongueUse, g.COLLECTIBLE_TONGUE_GRAPPLE)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, dorkyMechanics.OnTongueUse, g.COLLECTIBLE_TONGUE_GRAPPLE)
mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, dorkyMechanics.TongueUpdate, EntityType.ENTITY_VIS)
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, dorkyMechanics.TonguedNPCUpdate)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, dorkyMechanics.TongueHandlerUpdate, g.DORKY_TONGUE_ROPE_HANDLER)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, dorkyMisc.noDeadBodies, EffectVariant.DEVIL)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, dorkyMechanics.dummyTongueTargetAI, g.DORKY_TONGUE_DUMMY_TARGET)
mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, dorkyMechanics.IgnoreTonguedNPCCollision)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, dorkyMisc.dorkyDeathGoopUpdate, EffectVariant.PLAYER_CREEP_BLACK)

mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, spiritMechanics.evisCordSpikeUpdate, EntityType.ENTITY_VIS)
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, spiritMechanics.restoreFlashOnDamage)
mod:AddCallback(ModCallbacks.MC_USE_ITEM, spiritMechanics.onSoulStealUse, g.COLLECTIBLE_SOUL_DRAIN)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, spiritMechanics.onSpikeDamage)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, spiritMechanics.dummySpikeTargetAI,
	g.SPIRIT_SPIKE_DUMMY_TARGET)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, spiritMechanics.spiritSpikeHandlerUpdate, g.SPIRIT_SPIKE_ROPE_HANDLER)

mod:AddCallback(ModCallbacks.MC_POST_RENDER, dorkyMechanics.Debug)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, spiritHUDRender.OnRender)
