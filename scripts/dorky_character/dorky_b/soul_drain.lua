--#region Variables

local Mod = DorkyMod

local SOUL_DRAIN = {}

DorkyMod.Item.SOUL_DRAIN = {}

SOUL_DRAIN.DAMAGE_TRACKER = Isaac.GetItemIdByName("Soul Drain DMG")
SOUL_DRAIN.MOVEMENT_HANDLER = Isaac.GetEntityVariantByName("Soul Drain Rope Movement Handler")
SOUL_DRAIN.DUMMY_TARGET = Isaac.GetEntityVariantByName("Soul Drain Dummy Target")

SOUL_DRAIN.BASE_DMG = 4.20
SOUL_DRAIN.DMG_MULT = 4
SOUL_DRAIN.MAX_NPC_ATTACH_DURATION = 120
SOUL_DRAIN.COLLISION_RADIUS = 25
SOUL_DRAIN.MAX_SPIKE_DISTANCE = 200
SOUL_DRAIN.INIT_VELOCITY = 30
SOUL_DRAIN.MAX_SPIKE_DURATION = 0.5

SOUL_DRAIN.DAMAGE_HEAL_THRESHOLD = 100
SOUL_DRAIN.BAR_FILL_CAP = 20

SOUL_DRAIN.MAX_CHARGE = Isaac.GetItemConfig():GetCollectible(Mod.COLLECTIBLE_SOUL_DRAIN).MaxCharges

--#endregion

--#region Helpers

---@param player EntityPlayer
function SOUL_DRAIN:GetDrainCountdown(player)
	return math.max(SOUL_DRAIN.MAX_SPIKE_DURATION, player.MaxFireDelay * 3)
end

---@param player EntityPlayer
function SOUL_DRAIN:GetDrainDamage(player)
	return player.Damage * 2 + 1.5
end

---@param effect EntityEffect
function SOUL_DRAIN:RemoveSpike(effect)
	if effect.Child then
		effect.Child:Remove()
	end
	effect:Remove()
end

---@param ptr EntityPtr
local function getNPCFromPtr(ptr)
	if not ptr or not ptr.Ref then return end
	return ptr.Ref:ToNPC()
end

---@param effect EntityEffect
function SOUL_DRAIN:DetatchSpike(effect)
	local data = effect:GetData()
	data.AttachedToNPC = false
	data.NPCTarget = nil
end

--#endregion

--#region On Use

ThrowableItemLib:RegisterThrowableItem({
	ID = Mod.COLLECTIBLE_SOUL_DRAIN,
	Type = ThrowableItemLib.Type.ACTIVE,
	Identifier = "SoulDrain",
	ThrowFn = function(player, vect, slot, mimic)
		local pData = player:GetData()
		local dir = vect:Resized(SOUL_DRAIN.INIT_VELOCITY)
		local movementHandler = Isaac.Spawn(EntityType.ENTITY_EFFECT, SOUL_DRAIN.MOVEMENT_HANDLER, 0, player.Position,
			dir,
			player)
		local dummyTarget = Isaac.Spawn(EntityType.ENTITY_EFFECT, SOUL_DRAIN.DUMMY_TARGET, 0, player.Position,
			Vector.Zero,
			player)
		local evisCord = Isaac.Spawn(EntityType.ENTITY_EVIS, 10, 1, player.Position, Vector.Zero, player)
		local sprite = evisCord:GetSprite()
		local handlerData = movementHandler:GetData()

		dummyTarget.Parent = player
		dummyTarget.Child = evisCord
		dummyTarget.Visible = false
		movementHandler.Child = evisCord
		movementHandler.Parent = player
		movementHandler.Visible = false
		sprite:ReplaceSpritesheet(0, "gfx/effects/spirit_spike.png")
		sprite:ReplaceSpritesheet(1, "gfx/effects/spirit_spike.png")
		sprite:LoadGraphics()
		evisCord.Parent = movementHandler
		evisCord.Target = dummyTarget
		evisCord:GetData().DorkyIsSpiritSpike = true
		handlerData.spiritSpikeLifetime = 0
		local cordFlags = EntityFlag.FLAG_NO_STATUS_EFFECTS
			| EntityFlag.FLAG_NO_TARGET
			| EntityFlag.FLAG_NO_KNOCKBACK
			| EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK
		---@cast cordFlags EntityFlag
		evisCord:AddEntityFlags(cordFlags)
		evisCord:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		evisCord.DepthOffset = 300
		dummyTarget:Update()
		movementHandler:Update()
		movementHandler:GetData().ActiveSlot = slot
		pData.canThrowSpiritSpike = false
		pData.spiritSpike = movementHandler
		Mod.SFX:Play(SoundEffect.SOUND_WHIP)
	end,
})

--#endregion

--#region Dealing/healing damage

---@param player EntityPlayer
local function spawnBlackHeartIndicator(player)
	local notify = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEART, 5, player.Position, Vector.Zero, player)
	notify:GetSprite().Offset = Vector(0, -24)
	notify.RenderZOffset = 1000
end

---@param player EntityPlayer
function SOUL_DRAIN:UpdateSoulDrainBar(player, amount)
	local effects = player:GetEffects()
	local data = player:GetData()
	data.SoulDrainDamageTracker = (data.SoulDrainDamageTracker or effects:GetCollectibleEffectNum(SOUL_DRAIN.DAMAGE_TRACKER)) +
		amount
	local healAmount = 1
	if player:GetPlayerType() == Mod.PLAYER_DORKY_B and player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
		healAmount = 2
	end
	local totalHealAmount = 0
	while data.SoulDrainDamageTracker >= SOUL_DRAIN.DAMAGE_HEAL_THRESHOLD do
		totalHealAmount = totalHealAmount + healAmount
		data.SoulDrainDamageTracker = math.max(0, data.SoulDrainDamageTracker - SOUL_DRAIN.DAMAGE_HEAL_THRESHOLD)
	end
	if totalHealAmount > 0 then
		spawnBlackHeartIndicator(player)
		Mod.SFX:Play(SoundEffect.SOUND_VAMP_GULP)
		player:AddBlackHearts(totalHealAmount)
	end
	effects:RemoveCollectibleEffect(SOUL_DRAIN.DAMAGE_TRACKER, -1)
	effects:AddCollectibleEffect(SOUL_DRAIN.DAMAGE_TRACKER, false, math.floor(data.SoulDrainDamageTracker))
end

---@param source EntityRef
local function tryGetPlayerFromSource(source)
	local ent = source.Entity
	if not ent then return end
	if ent:ToPlayer() then
		return ent:ToPlayer()
	end
	local spawnEnt = ent.SpawnerEntity
	if not spawnEnt then return end
	if spawnEnt:ToPlayer() then
		return spawnEnt:ToPlayer()
	elseif spawnEnt:ToFamiliar() then
		return spawnEnt:ToFamiliar().Player
	end
end

---@param ent Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdown integer
function SOUL_DRAIN:TrackDamageDealt(ent, amount, flags, source, countdown)
	local player = tryGetPlayerFromSource(source)
	if player and player:HasCollectible(Mod.COLLECTIBLE_SOUL_DRAIN) and ent:IsActiveEnemy(false) then
		local barAmount = math.min(ent.HitPoints, amount)

		if source.Entity and source.Entity:ToEffect() and source.Variant == SOUL_DRAIN.MOVEMENT_HANDLER then
			SOUL_DRAIN:UpdateSoulDrainBar(player, math.min(SOUL_DRAIN.BAR_FILL_CAP, barAmount))
		else
			for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
				local maxCharge = SOUL_DRAIN.MAX_CHARGE
				local charge = player:GetActiveCharge(slot)
				if player:HasCollectible(CollectibleType.COLLECTIBLE_BATTERY) then
					maxCharge = maxCharge * 2
				end
				if player:GetActiveItem(slot) == Mod.COLLECTIBLE_SOUL_DRAIN and charge < maxCharge then
					player:SetActiveCharge(math.min(maxCharge, math.floor(charge + barAmount)), slot)
					break
				end
			end
		end
	end
end

Mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.LATE, SOUL_DRAIN.TrackDamageDealt)

--#endregion

--#region Handler update

---@param effect EntityEffect
function SOUL_DRAIN:TryStickToNPC(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not player then return end
	local data = effect:GetData()

	if not data.AttachedToNPC and not data.HadAttachedToNPC then
		local npc = Mod:GetClosestEnemy(effect.Position, SOUL_DRAIN.COLLISION_RADIUS)

		if npc and Mod:IsValidEnemyTarget(npc) then
			data.AttachedToNPC = true
			data.NPCTarget = EntityPtr(npc)
			data.HadAttachedToNPC = true
			data.AttachDuration = SOUL_DRAIN.MAX_NPC_ATTACH_DURATION
			data.HealthDrainCountdown = SOUL_DRAIN:GetDrainCountdown(player)
			effect.Velocity = Vector.Zero
			npc:AddSlowing(EntityRef(player), SOUL_DRAIN.MAX_NPC_ATTACH_DURATION, 0.1, Color(0.2, 0.2, 0.2))
			Mod.SFX:Play(SoundEffect.SOUND_WHIP_HIT)
		end
	end
end

---@param npc EntityNPC
---@param player EntityPlayer
function SOUL_DRAIN:DrainEnemy(npc, player, source)
	local shouldFlash = not npc:HasEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	if shouldFlash then
		npc:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	end
	npc:TakeDamage(SOUL_DRAIN:GetDrainDamage(player), 0, source, 0)
	if shouldFlash then
		npc:ClearEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	end
	npc:SetColor(Color(0, 0, 0, npc.Color.A), 10, 6, true, false)
	Mod.SFX:Play(SoundEffect.SOUND_ROTTEN_HEART, 1.5, 2, false, 0.7, 0)
end

---@param effect EntityEffect
function SOUL_DRAIN:DrainAttachedNPC(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not player then return end
	local data = effect:GetData()
	local npc = getNPCFromPtr(data.NPCTarget)
	if not npc then
		SOUL_DRAIN:DetatchSpike(effect)
		return
	end
	effect.Position = npc.Position

	local distance = player.Position:Distance(npc.Position)

	if distance > SOUL_DRAIN.MAX_SPIKE_DISTANCE then
		--Too far or out of bounds
		if distance > SOUL_DRAIN.MAX_SPIKE_DISTANCE * 2 or not Mod.Game:GetRoom():IsPositionInRoom(npc.Position, -30) then
			SOUL_DRAIN:DetatchSpike(effect)
		else
			--Shoutouts to Warden from Fiend Folio
			player.Velocity = player.Velocity +
				(npc.Position - player.Position):Resized(math.min(10, distance - SOUL_DRAIN.MAX_SPIKE_DISTANCE))
			player.Position = npc.Position +
				(player.Position - npc.Position):Resized(SOUL_DRAIN.MAX_SPIKE_DISTANCE)
		end
	end

	if (data.HealthDrainCountdown or 1) > 0 then
		data.HealthDrainCountdown = (data.HealthDrainCountdown or 0) - 1
	else
		SOUL_DRAIN:DrainEnemy(npc, player, EntityRef(effect))
		data.HealthDrainCountdown = SOUL_DRAIN:GetDrainCountdown(player)
	end

	if data.AttachDuration then
		if data.AttachDuration > 0 then
			data.AttachDuration = data.AttachDuration - 1
		else
			SOUL_DRAIN:DetatchSpike(effect)
		end
	end
end

---@param effect EntityEffect
function SOUL_DRAIN:SpikeHandlerUpdate(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	local data = effect:GetData()
	local slot = data.ActiveSlot

	if data.SoulDrainLifetime then
		data.SoulDrainLifetime = data.SoulDrainLifetime + 1
	else
		data.SoulDrainLifetime = 0
	end

	if player and player:Exists() and not player:IsDead() then
		local updateSlot = slot ~= -1 and player:GetActiveItem(slot) == Mod.COLLECTIBLE_SOUL_DRAIN
		if updateSlot then
			player:SetActiveCharge(0, slot)
		end

		SOUL_DRAIN:TryStickToNPC(effect)

		if data.SoulDrainLifetime > 9 and not data.AttachedToNPC then
			--Pulling spike back to player
			local targetVec = ((player.Position + player.Velocity) - effect.Position)
			if targetVec:Length() > 30 then
				targetVec = targetVec:Resized(30)
			end

			effect.Velocity = Mod:SmoothLerp(effect.Velocity, targetVec, math.min(0.1 + 8 / 10), 1)

			if effect.Position:Distance(player.Position) < 30 then
				SOUL_DRAIN:RemoveSpike(effect)

				if updateSlot
					and player:GetActiveItem(slot) == Mod.COLLECTIBLE_SOUL_DRAIN
					and not data.HadAttachedToNPC
				then
					player:FullCharge(slot, true)
				end
			end
		elseif data.SoulDrainLifetime > 6 then
			effect.Velocity = effect.Velocity * 0.3
		end
		if data.AttachedToNPC then
			SOUL_DRAIN:DrainAttachedNPC(effect)
		end
	else
		SOUL_DRAIN:RemoveSpike(effect)
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, SOUL_DRAIN.SpikeHandlerUpdate, SOUL_DRAIN.MOVEMENT_HANDLER)

--#endregion

--#region Dummy update

---@param effect EntityEffect
function SOUL_DRAIN:DummySpikeTargetAI(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not effect.Child then
		effect:Remove()
	elseif player then
		effect.Position = player.Position
	else
		effect:Remove()
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, SOUL_DRAIN.DummySpikeTargetAI, SOUL_DRAIN.DUMMY_TARGET)

--#endregion

--#region NPC update

---@param evisCord EntityNPC
function SOUL_DRAIN:EvisGutsUpdate(evisCord)
	local data = evisCord:GetData()
	if data.DorkyIsSpiritSpike
		and evisCord.Variant == 10
		and evisCord.SubType == 1
		and evisCord.Target.Type == EntityType.ENTITY_EFFECT
		and evisCord.Target.Variant == SOUL_DRAIN.DUMMY_TARGET
	then
		return false
	end
end

Mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, SOUL_DRAIN.EvisGutsUpdate, EntityType.ENTITY_VIS)

--#endregion

--#region HUD

local BAR_LENGTH = 50

local soulDrainBar = {}
for _ = 1, 4 do
	local sprite = Sprite()
	sprite:Load("gfx/soul_drain_horizontal.anm2", true)
	sprite:SetFrame("Main", 0)
	soulDrainBar[#soulDrainBar + 1] = sprite
end

HudHelper.RegisterHUDElement({
	Name = "Soul Drain Black HP Bar",
	Priority = HudHelper.Priority.NORMAL,
	XPadding = 0,
	YPadding = 0,
	Condition = function(player, playerHUDIndex, hudLayout)
		return player:HasCollectible(Mod.COLLECTIBLE_SOUL_DRAIN)
	end,
	OnRender = function(player, playerHUDIndex, hudLayout, position)
		local sprite = soulDrainBar[playerHUDIndex]
		local dmgDealt = player:GetEffects():GetCollectibleEffectNum(SOUL_DRAIN.DAMAGE_TRACKER)
		local threshold = SOUL_DRAIN.DAMAGE_HEAL_THRESHOLD

		sprite:RenderLayer(0, position)
		sprite:RenderLayer(1, position, Vector.Zero,
			Vector(BAR_LENGTH * math.min(threshold, (threshold - dmgDealt) / threshold), 0))
		if player:GetPlayerType() == Mod.PLAYER_DORKY_B and player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
			sprite:RenderLayer(2, position)
		end
	end
}, HudHelper.HUDType.EXTRA)

--#endregion

--#region Detatch spike

---@param player EntityPlayer
function SOUL_DRAIN:DetatchSpikeOnUseItem(player)
	for i = 1, 2 do
		local slot = i == 1 and ActiveSlot.SLOT_PRIMARY or ActiveSlot.SLOT_POCKET
		if player:GetActiveItem(slot) == Mod.COLLECTIBLE_SOUL_DRAIN
			and Input.IsActionTriggered(ButtonAction.ACTION_PILLCARD, player.ControllerIndex)
			and player:GetActiveCharge(slot) < SOUL_DRAIN.MAX_CHARGE
		then
			local playerPtrHash = GetPtrHash(player)
			for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, SOUL_DRAIN.MOVEMENT_HANDLER)) do
				local effect = ent:ToEffect()
				---@cast effect EntityEffect
				if GetPtrHash(effect.SpawnerEntity) == playerPtrHash then
					SOUL_DRAIN:DetatchSpike(effect)
				end
			end
		end
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, SOUL_DRAIN.DetatchSpikeOnUseItem)

--#endregion