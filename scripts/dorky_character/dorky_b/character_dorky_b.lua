local Mod = DorkyMod

local THE_VOID = {}

DorkyMod.Character.THE_VOID = THE_VOID

THE_VOID.COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_b.anm2")
THE_VOID.DEATH_EFFECT = Isaac.GetEntityVariantByName("Tainted Dorky Death Explosion")

THE_VOID.SOUL_HEART_CHARGE = 10

THE_VOID.StatsTable = {
	[CacheFlag.CACHE_SPEED] = 0,
	[CacheFlag.CACHE_FIREDELAY] = 1,
	[CacheFlag.CACHE_DAMAGE] = 1.2,
	[CacheFlag.CACHE_RANGE] = 0,
	[CacheFlag.CACHE_SHOTSPEED] = 0,
	[CacheFlag.CACHE_LUCK] = -2,
	[CacheFlag.CACHE_TEARFLAG] = TearFlags.TEAR_SPECTRAL,
	[CacheFlag.CACHE_TEARCOLOR] = Color(0,0,0,1),
	[CacheFlag.CACHE_FLYING] = true
}

---@param player EntityPlayer
function THE_VOID:VoidRegeneration(player)
	local stage = Mod.Game:GetLevel():GetStage()

	if stage == LevelStage.STAGE7 then
		if Mod.Game.TimeCounter % 60 == 0
			and Mod:RandomNum(1) == 1
		then
			player:AddBlackHearts(1)
			Mod:SpawnBlackHeartIndicator(player)
			player:SetColor(Color(0, 0, 0), 10, 0, true, false)
			Mod.SFX:Play(SoundEffect.SOUND_UNHOLY)
		end
	end
end

---@param player EntityPlayer
function THE_VOID:DeathEffects(player)
	local sprite = player:GetSprite()
	if not sprite:IsPlaying("Death")
		or sprite:GetFilename() ~= "gfx/characters/player_dorky_b.anm2"
	then
		return
	end
	if sprite:IsEventTriggered("FuckingExplode") then
		local goop = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_BLACK, 0,
			player.Position, Vector.Zero, player)
		goop:Update()
		goop.SpriteScale = player.SpriteScale

		local explosion = Isaac.Spawn(EntityType.ENTITY_EFFECT, THE_VOID.DEATH_EFFECT, 0,
			player.Position, Vector.Zero, player)
		explosion:GetSprite().Scale = Vector(1.5, 1.5)
		explosion.SpriteScale = player.SpriteScale

		local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector.Zero, player)
		poof:GetSprite().Scale = Vector(1.5, 1.5)
		poof.Color = Color(0, 0, 0)
		poof.SpriteScale = player.SpriteScale

		for _ = 1, 10 do
			local vel = Vector(5, 0):Rotated(Mod:RandomNum(0, 359))
			local goopBits = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_PARTICLE, 0, player.Position, vel,
				player)
			goopBits.Color = Color(0, 0, 0)
			goopBits.SplatColor = Color(0, 0, 0)
			goopBits.SpriteScale = player.SpriteScale
		end

		Mod.SFX:Play(SoundEffect.SOUND_DEMON_HIT)
	elseif sprite:IsEventTriggered("DeathSound") then
		for _, gib in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_PARTICLE, 0)) do
			if gib.Position:DistanceSquared(player.Position) <= 25 ^ 2 then
				local c = gib.Color
				if c.R ~= 0 and c.G ~= 0 and c.B ~= 0 then
					gib:Remove()
				end
			end
		end
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER)) do
		if type(ent) == "userdata" then
			---@cast ent Entity
			local player = ent:ToPlayer()
			if player then
				THE_VOID:DeathEffects(player)
			end
		end
	end
end)

---@param player EntityPlayer
local function getRealSoulHearts(player)
	local blackCount = 0
	local soulHearts = player:GetSoulHearts()
	local blackMask = player:GetBlackHearts()

	for i = 1, soulHearts do
		local bit = 2 ^ math.floor((i - 1) / 2)
		if blackMask | bit == blackMask then
			blackCount = blackCount + 1
		end
	end
	return soulHearts - blackCount
end

---@param player EntityPlayer
function THE_VOID:OnlyBlackHearts(player)
	local redHearts = player:GetMaxHearts()
	local redHealth = player:GetHearts()
	local boneHearts = player:GetBoneHearts()
	local eternalHearts = player:GetEternalHearts()
	local soulHearts = getRealSoulHearts(player)

	if redHearts > 0 then
		player:AddMaxHearts(-redHearts)
		player:AddBlackHearts(redHearts)
	end
	if redHealth > 0 then
		player:AddHearts(-redHealth)
	end
	if boneHearts > 0 then
		player:AddBoneHearts(-boneHearts)
	end
	if eternalHearts > 0 then
		player:AddEternalHearts(-eternalHearts)
	end
	if soulHearts > 0 then
		player:AddSoulHearts(-soulHearts)
		Mod.Item.SOUL_DRAIN:UpdateSoulDrainBar(player, THE_VOID.SOUL_HEART_CHARGE * soulHearts)
	end
end

---@param player EntityPlayer
function THE_VOID:OnPeffectUpdate(player)
	THE_VOID:OnlyBlackHearts(player)
	THE_VOID:VoidRegeneration(player)
end

Mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, THE_VOID.OnPeffectUpdate, Mod.PLAYER_DORKY_B)

---@param heart EntityPickup
---@param collider Entity
function THE_VOID:IgnoreMostHearts(heart, collider)
	local player = collider:ToPlayer()
	if heart.SubType ~= HeartSubType.HEART_BLACK
		and heart.SubType ~= HeartSubType.HEART_SOUL
		and heart.SubType ~= HeartSubType.HEART_GOLDEN
		and player
		and player:GetPlayerType() == Mod.PLAYER_DORKY_B
	then
		return false
	end
end

Mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, THE_VOID.IgnoreMostHearts, PickupVariant.PICKUP_HEART)

local soulDrainBar = Sprite()
soulDrainBar:Load("gfx/soul_drain_horizontal.anm2", true)
soulDrainBar:Play("Main", true)

--[[ ---@param player EntityPlayer
local function spiritBarColorUpdate(player)
	local data = player:GetData()

	if data.spiritDamageBar.Color < 1 then
		data.spiritDamageBar.Color = data.spiritDamageBar.Color + 0.05
	end

	if data.spiritDamageBar.ShouldMakeBarSolid then
		if data.spiritDamageBar.Alpha < 1 then
			data.spiritDamageBar.Alpha = data.spiritDamageBar.Alpha + 0.05
		else
			if data.spiritDamageBar.Alpha > 1 then
				data.spiritDamageBar.Alpha = 1
			end
			data.spiritDamageBar.ShouldMakeBarSolid = false
		end
	elseif data.spiritDamageBar.VisibilityDuration > 0 then
		data.spiritDamageBar.VisibilityDuration = data.spiritDamageBar.VisibilityDuration - 1
	elseif data.spiritDamageBar.Alpha > 0.3 then
		data.spiritDamageBar.Alpha = data.spiritDamageBar.Alpha - 0.025
	end
end

---@param player EntityPlayer
local function updateSpiritBarColor(player)
	local data = player:GetData()

	if data.spikeDamageBank then
		if data.spiritDamageBar.LastKnownDamage ~= data.spikeDamageBank
			or (data.spiritSpike and data.spiritSpike:Exists() and data.spiritSpike:GetData().securedNPC)
			or (player.Parent and Input.IsActionPressed(ButtonAction.ACTION_MAP, player.ControllerIndex))
		then
			if player.Parent then
				data.spiritDamageBar.ShouldMakeBarSolid = true
				if player.Parent and Input.IsActionPressed(ButtonAction.ACTION_MAP, player.ControllerIndex) then
					data.spiritDamageBar.VisibilityDuration = 1
				else
					data.spiritDamageBar.VisibilityDuration = 90
				end
			end
			if data.spiritDamageBar.LastKnownDamage ~= data.spikeDamageBank then
				if player.Parent then
					if data.spiritDamageBar.Alpha == 0.3 or data.spiritDamageBar.Alpha == 1 then
						data.spiritDamageBar.Color = 0.3
					end
				else
					data.spiritDamageBar.Color = 0.3
				end
				data.spiritDamageBar.LastKnownDamage = data.spikeDamageBank
			end
		end
	end
end ]]

HudHelper.RegisterHUDElement({
	Name = "Spirit Black HP Bar",
	Priority = HudHelper.Priority.NORMAL,
	XPadding = 0,
	YPadding = 0,
	Condition = function(player, playerHUDIndex, hudLayout)
		return player:GetPlayerType() == Mod.PLAYER_DORKY_B
	end,
	OnRender = function(player, playerHUDIndex, hudLayout, position)
		--[[ if not data.spiritDamageBar then
			data.spiritDamageBar = {
				Sprite = Sprite(),
				Color = 1,
				LastKnownDamage = 0,
				Alpha = player.Parent and 0.3 or 1,
				VisibilityDuration = 0,
				ShouldMakeBarSolid = false
			}
		else
			updateSpiritBarColor(player)

			local curFrame = data.spikeDamageBank and
				math.ceil((data.spikeDamageBank / getSpiritSpikeSuccDamageRequirement(player)) * 100) or 1
			data.spiritDamageBar.Sprite:SetFrame(curFrame)
			data.spiritDamageBar.Sprite.Color = Color(data.spiritDamageBar.Color, data.spiritDamageBar.Color,
				data.spiritDamageBar.Color, 1)
			data.spiritDamageBar.Sprite:Render(posToRender)

			spiritBarColorUpdate(player)
		end ]]
	end
}, HudHelper.HUDType.EXTRA)
