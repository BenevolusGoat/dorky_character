local Mod = DorkyMod

local DORKY = {}

DorkyMod.Character.DORKY = DORKY

DORKY.COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky.anm2")
DORKY.COSTUME_FLIGHT = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_flight.anm2")

DORKY.StatsTable = {
	[CacheFlag.CACHE_SPEED] = -0.25,
	[CacheFlag.CACHE_FIREDELAY] = 1,
	[CacheFlag.CACHE_DAMAGE] = 1,
	[CacheFlag.CACHE_RANGE] = 0,
	[CacheFlag.CACHE_SHOTSPEED] = -0.3,
	[CacheFlag.CACHE_LUCK] = -1,
	[CacheFlag.CACHE_TEARFLAG] = TearFlags.TEAR_SPECTRAL
}

local CREEP_SIZE = 0.1
local CREEP_GROWTH_RATE = 0.075

---@param player EntityPlayer
function DORKY:SpawnBlackGoopOnDeath(player)
	local sprite = player:GetSprite()

	if sprite:IsPlaying("Death")
		and sprite:GetFilename() == "gfx/characters/player_dorky.anm2"
		and sprite:IsEventTriggered("SpawnGoopy")
	then
		local goop = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_BLACK, 0, player.Position,
		Vector.Zero,
			player)
		goop:Update()
		goop.SpriteScale = Vector(player.SpriteScale.X * CREEP_SIZE, player.SpriteScale.Y * CREEP_SIZE)
		goop:GetData().DorkyDeathGoop = true
		goop:GetSprite():Play("BigBlood0" .. tostring(Mod:RandomNum(0, 6)), true)
		goop.Color = Color(0, 0, 0, 1, 0, 0, 0)
	end
end

---@param effect EntityEffect
function DORKY:GoopUpdate(effect)
	local data = effect:GetData()
	if not data.DorkyDeathGoop then return end
	local player = effect.SpawnerEntity and effect.SpawnerEntity:ToPlayer()
	if not player then return end
	local sprite = player:GetSprite()

	if sprite:IsPlaying("Death") and sprite:GetFrame() < 42 then
		effect.SpriteScale = effect.SpriteScale + Vector(CREEP_GROWTH_RATE, CREEP_GROWTH_RATE)
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, DORKY.GoopUpdate, EffectVariant.PLAYER_CREEP_BLACK)

---@param player EntityPlayer
function DORKY:NoRedHealth(player)
	local heartContainers = player:GetMaxHearts()
	local redHearts = player:GetHearts()
	if heartContainers > 0 then
		player:AddMaxHearts(-heartContainers)
		player:AddBlackHearts(heartContainers)
	end
	if redHearts > 0 then
		player:AddHearts(-redHearts)
	end
end

function DORKY:OnPeffectUpdate(player)
	DORKY:NoRedHealth(player)
	DORKY:SpawnBlackGoopOnDeath(player)
end

Mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, DORKY.OnPeffectUpdate, Mod.PLAYER_DORKY)

---@param heart EntityPickup
---@param collider Entity
function DORKY:IgnoreHeartPickups(heart, collider)
	local player = collider:ToPlayer()
	if player and player:GetPlayerType() == Mod.PLAYER_DORKY then
		if heart.SubType == HeartSubType.HEART_FULL or heart.SubType == HeartSubType.HEART_HALF then
			return false
		elseif heart.SubType == HeartSubType.HEART_BLENDED and player:CanPickSoulHearts() then
			heart:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL)
			local sprite = heart:GetSprite()
			local anim, frame = sprite:GetAnimation(), sprite:GetFrame()
			sprite:Load("gfx/005.019_blended heart.anm2", true)
			sprite:Play(anim)
			sprite:SetFrame(frame)
		end
	end
end

Mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, DORKY.IgnoreHeartPickups, PickupVariant.PICKUP_HEART)
