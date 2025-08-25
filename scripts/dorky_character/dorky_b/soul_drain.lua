local Mod = DorkyMod

local SOUL_DRAIN = {}

DorkyMod.Item.SOUL_DRAIN = {}

SOUL_DRAIN.DAMAGE_TRACKER = Isaac.GetItemIdByName("Soul Drain Damage Tracker")
SOUL_DRAIN.MOVEMENT_HANDLER = Isaac.GetEntityVariantByName("Soul Drain Rope Movement Handler")
SOUL_DRAIN.DUMMY_TARGET = Isaac.GetEntityVariantByName("Soul Drain Dummy Target")

SOUL_DRAIN.BASE_DMG = 4.20
SOUL_DRAIN.DMG_MULT = 4
SOUL_DRAIN.MAX_NPC_ATTACH_DURATION = 120
SOUL_DRAIN.COLLISION_RADIUS = 25
SOUL_DRAIN.MAX_SPIKE_DISTANCE = 200
SOUL_DRAIN.INIT_VELOCITY = 30

SOUL_DRAIN.DAMAGE_HEAL_THRESHOLD = 100
SOUL_DRAIN.DIRECT_DAMAGE_PERCENTAGE = 0.5
SOUL_DRAIN.DIRECT_DAMAGE_CAP = 10

SOUL_DRAIN.MAX_SPIKE_DURATION = 0.5

---@param player EntityPlayer
function SOUL_DRAIN:GetDrainDuration(player)
	return math.max(SOUL_DRAIN.MAX_SPIKE_DURATION, player.MaxFireDelay * 3)
end

---@param player EntityPlayer
function SOUL_DRAIN:GetDrainDamage(player)
	return player.Damage * 2 + 1.5
end

--[[ ---@param player EntityPlayer
function SOUL_DRAIN:GetDamageRequirement(player)
	local spikeDamage = SOUL_DRAIN:GetDrainDamage(player)
	local minDmg = spikeDamage * SOUL_DRAIN.DMG_MULT
	local mult = (SOUL_DRAIN.BASE_DMG / player.Damage * SOUL_DRAIN.DMG_MULT)
	local dmgRequirement = math.ceil(math.max(minDmg, minDmg * mult))
	return dmgRequirement
end ]]

---@param effect EntityEffect
local function RemoveSpiritSpike(effect)
	if effect.Child then
		effect.Child:Remove()
	end
	effect:Remove()
end

--TODO: ThrowableItemLib
--[[
---@param itemID CollectibleType
---@param player EntityPlayer
function SOUL_DRAIN:onSoulStealUse(itemID, _, player)
	local data = player:GetData()

	if itemID == g.COLLECTIBLE_SOUL_DRAIN
		and player:GetActiveItem(ActiveSlot.SLOT_POCKET) == g.COLLECTIBLE_SOUL_DRAIN
	then
		if not data.canThrowSpiritSpike then
			data.canThrowSpiritSpike = true
			player:AnimateCollectible(g.COLLECTIBLE_SOUL_DRAIN, "LiftItem")
		elseif data.canThrowSpiritSpike then
			data.canThrowSpiritSpike = false
			player:AnimateCollectible(g.COLLECTIBLE_SOUL_DRAIN, "HideItem")
		end
		return { Discharge = false, Remove = false, ShowAnim = false }
	else
		if data.canThrowSpiritSpike then
			data.canThrowSpiritSpike = false
		end
	end
end

---@param player EntityPlayer
function SOUL_DRAIN:shouldThrowSpiritSpike(player)
	local data = player:GetData()

	if data.canThrowSpiritSpike then
		if player:GetFireDirection() ~= Direction.NO_DIRECTION then
			SOUL_DRAIN:throwSpiritSpike(player)
			player:SetActiveCharge(0, ActiveSlot.SLOT_POCKET)
			player:AnimateCollectible(g.COLLECTIBLE_SOUL_DRAIN, "HideItem")
		end

		local allWalkAnims = {
			"WalkDown",
			"WalkRight",
			"WalkUp",
			"WalkLeft",
			"PickupWalkDown",
			"PickupWalkRight",
			"PickupWalkUp",
			"PickupWalkLeft",
		}
		if not VeeHelper.IsSpritePlayingAnims(player:GetSprite(), allWalkAnims) then
			data.canThrowSpiritSpike = false
			player:AnimateCollectible(g.COLLECTIBLE_SOUL_DRAIN, "HideItem")
		end
	end
end

---@param player EntityPlayer
function SOUL_DRAIN:ThrowSoulDrainSpike(player)
	local pData = player:GetData()
	local dir = VeeHelper.DirectionToVector(player:GetFireDirection()):Resized(SOUL_DRAIN.INIT_VELOCITY)
	local movementHandler = Isaac.Spawn(EntityType.ENTITY_EFFECT, SOUL_DRAIN.MOVEMENT_HANDLER, 0, player.Position, dir,
		player)
	local dummyTarget = Isaac.Spawn(EntityType.ENTITY_EFFECT, SOUL_DRAIN.DUMMY_TARGET, 0, player.Position, Vector.Zero,
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
	evisCord:GetData().IsSpiritSpike = true
	handlerData.spiritSpikeLifetime = 0
	evisCord:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_KNOCKBACK |
		EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
	evisCord:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	evisCord.DepthOffset = 300
	dummyTarget:Update()
	movementHandler:Update()
	pData.canThrowSpiritSpike = false
	pData.spiritSpike = movementHandler
	Mod.SFX:Play(SoundEffect.SOUND_WHIP)
end

---@param evisCord EntityNPC
function SOUL_DRAIN:evisCordSpikeUpdate(evisCord)
	local data = evisCord:GetData()
	if not data.IsSpiritSpike or evisCord.Variant ~= 10 or evisCord.SubType ~= 1 then return end
	if evisCord.Target.Type == EntityType.ENTITY_EFFECT and evisCord.Target.Variant == SOUL_DRAIN.DUMMY_TARGET then
		return false
	end
end

---@param ent Entity
---@param source EntityRef
function SOUL_DRAIN:onSpikeDamage(ent, amount, _, source, _)
	if source.Entity and source.Entity:ToEffect()
		and source.Entity.Variant == SOUL_DRAIN.MOVEMENT_HANDLER
	then
		local data = source.Entity.Parent:ToPlayer():GetData()
		if not data.checkNPCRemainingHealth then
			data.checkNPCRemainingHealth = {}
		end
		table.insert(data.checkNPCRemainingHealth, { ent:ToNPC(), ent.HitPoints, Mod.Game:GetRoom():GetFrameCount() })
	end
end

---@param npc EntityNPC|nil
local function shouldNPCGetSpiritSpiked(npc)
	if npc ~= nil
		and npc:Exists()
		and npc:IsVulnerableEnemy()
		and npc:IsActiveEnemy()
		and not npc:IsInvincible()
		and not npc:IsDead()
		and not npc:HasEntityFlags(EntityFlag.FLAG_CHARM)
		and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and Mod.Game:GetRoom():IsPositionInRoom(npc.Position, -30)
	then
		return true
	else
		return false
	end
end

---@param effect EntityEffect
function SOUL_DRAIN:tryStickToNPC(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not player then return end
	local pData = player:GetData()
	local data = effect:GetData()

	if not data.securedNPC and not data.hadCaughtNPC then
		local npc = pData.checkNPCNextFrame or Mod:GetClosestEnemy(effect.Position, SOUL_DRAIN.COLLISION_RADIUS)

		if npc and shouldNPCGetSpiritSpiked(npc) then
			if not pData.checkNPCNextFrame then
				npc:TakeDamage(player.Damage * 1.5, 0, EntityRef(effect), 10)
				pData.checkNPCNextFrame = npc
				data.hadDamagedNPC = true
			else
				data.securedNPC = true
				data.NPCTarget = npc
				data.hadCaughtNPC = true
				data.attachDuration = SOUL_DRAIN.MAX_NPC_ATTACH_DURATION
				npc:GetData().caughtOnSpiritSpike = true
				npc:GetData().spiritSpikeShouldFlash = npc:HasEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
				effect.Velocity = Vector.Zero
				npc:AddSlowing(EntityRef(player), SOUL_DRAIN.MAX_NPC_ATTACH_DURATION, 0.1, Color(0.2, 0.2, 0.2))
				Mod.SFX:Play(SoundEffect.SOUND_WHIP_HIT)
				pData.checkNPCNextFrame = nil
			end
		elseif pData.checkNPCNextFrame then
			pData.checkNPCNextFrame = nil
			SOUL_DRAIN:tryStickToNPC(effect)
		end
	end
end

---@param effect EntityEffect
function SOUL_DRAIN:drainAttachedNPC(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not player then return end
	local data = effect:GetData()

	---@type EntityNPC
	data.NPCTarget = data.NPCTarget

	if not shouldNPCGetSpiritSpiked(data.NPCTarget) then
		if not data.NPCTarget:IsDead() and data.NPCTarget:Exists() then
			data.NPCTarget:GetData().caughtOnSpiritSpike = nil
		end
		data.securedNPC = false
		return
	end

	effect.Position = data.NPCTarget.Position

	--Shoutouts to Warden from Fiend Folio
	local distance = player.Position:Distance(data.NPCTarget.Position)

	if player.Position:Distance(data.NPCTarget.Position) > SOUL_DRAIN.MAX_SPIKE_DISTANCE then
		player.Velocity = player.Velocity +
			(data.NPCTarget.Position - player.Position):Resized(math.min(10, distance - SOUL_DRAIN.MAX_SPIKE_DISTANCE))
		player.Position = data.NPCTarget.Position +
			(player.Position - data.NPCTarget.Position):Resized(SOUL_DRAIN.MAX_SPIKE_DISTANCE)
	end

	if data.NPCTarget:GetData().spiritSpikeShouldFlash
		and not data.NPCTarget:HasEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	then
		data.NPCTarget:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	end

	if not data.timeTillHealthDrain then
		data.timeTillHealthDrain = SOUL_DRAIN:GetDrainDuration(player)
	elseif data.timeTillHealthDrain > 0 then
		data.timeTillHealthDrain = data.timeTillHealthDrain - 1
	elseif not data.checkRemainingHealth then
		if data.NPCTarget:GetData().spiritSpikeShouldFlash then
			data.NPCTarget:ClearEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
		end
		data.NPCTarget:TakeDamage(SOUL_DRAIN:GetDrainDamage(player), 0, EntityRef(effect), 0)
		data.NPCTarget:SetColor(Color(0, 0, 0, data.NPCTarget.Color.A), 10, 6, true, false)
		Mod.SFX:Play(SoundEffect.SOUND_ROTTEN_HEART, 1.5, 2, false, 0.7, 0)
		data.timeTillHealthDrain = SOUL_DRAIN:GetDrainDuration(player)
	end

	if data.attachDuration then
		if data.attachDuration > 0 then
			data.attachDuration = data.attachDuration - 1
		else
			data.securedNPC = false
		end
	end
end

---@param effect EntityEffect
function SOUL_DRAIN:spiritSpikeHandlerUpdate(effect)
	local player = effect.Parent:ToPlayer()
	local data = effect:GetData()

	if data.spiritSpikeLifetime then
		data.spiritSpikeLifetime = data.spiritSpikeLifetime + 1
	else
		data.spiritSpikeLifetime = 0
	end

	if player and player:Exists() and not player:IsDead() then
		player:SetActiveCharge(0, ActiveSlot.SLOT_POCKET)
		SOUL_DRAIN:tryStickToNPC(effect)

		if data.spiritSpikeLifetime > 9 and not data.securedNPC then
			--Pulling spike back to player
			local targetVec = ((player.Position + player.Velocity) - effect.Position)
			if targetVec:Length() > 30 then
				targetVec = targetVec:Resized(30)
			end

			effect.Velocity = Mod:SmoothLerp(effect.Velocity, targetVec, math.min(0.1 + 8 / 10), 1)

			if effect.Position:Distance(player.Position) < 30 then
				RemoveSpiritSpike(effect)

				if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == g.COLLECTIBLE_SOUL_DRAIN
					and not data.hadCaughtNPC
				then
					player:FullCharge(ActiveSlot.SLOT_POCKET)
				end
			end
		elseif data.spiritSpikeLifetime > 6 then
			effect.Velocity = effect.Velocity * 0.3
		end
		if data.securedNPC then
			SOUL_DRAIN:drainAttachedNPC(effect)
		end
	else
		RemoveSpiritSpike(effect)
	end
end

---@param player EntityPlayer
function SOUL_DRAIN:healFromSpiritSpike(player)
	local data = player:GetData()
	local dmgRequirement = SOUL_DRAIN:GetDamageRequirement(player)
	local dmgToAdd = 0
	local entsToRemove = {}

	if data.checkNPCRemainingHealth then
		---@param npcTable table
		for i, npcTable in ipairs(data.checkNPCRemainingHealth) do
			---@type EntityNPC
			local npc = npcTable[1]
			local oldHitPoints = npcTable[2]
			local frameHit = npcTable[3]
			local hasBeenChecked = npcTable[4]

			if Mod.Game:GetRoom():GetFrameCount() >= frameHit + 2 and not hasBeenChecked then
				local npcHitPoints = npc:IsDead() and npc.HitPoints < 0 and 0 or npc.HitPoints
				local damageDone = oldHitPoints - npcHitPoints

				dmgToAdd = dmgToAdd + damageDone
				table.insert(npcTable, true)
				table.insert(entsToRemove, i)
			end
		end
		local numToShiftBy = 0
		for _, num in ipairs(entsToRemove) do
			table.remove(data.checkNPCRemainingHealth, num + numToShiftBy)
			numToShiftBy = numToShiftBy + 1
		end

		if dmgToAdd > 0 then
			dmgToAdd = math.floor(dmgToAdd * 100) / 100 --Round
			data.spikeDamageBank = data.spikeDamageBank and data.spikeDamageBank + dmgToAdd or dmgToAdd
			data.checkRemainingHealth = nil
		end
	end

	if data.spikeDamageBank and data.spikeDamageBank > dmgRequirement then
		local numHeartsAdded = 0
		for _ = 1, math.floor(data.spikeDamageBank / dmgRequirement) do
			local numToAdd = player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and 2 or 1
			player:AddBlackHearts(numToAdd)
			numHeartsAdded = numHeartsAdded + 1
		end
		spawnBlackHeartIndicator(player)
		Mod.SFX:Play(SoundEffect.SOUND_VAMP_GULP)
		data.spikeDamageBank = data.spikeDamageBank - (dmgRequirement * numHeartsAdded)
	end
end

---@param e EntityEffect
function SOUL_DRAIN:dummySpikeTargetAI(e)
	if not e.Child then
		e:Remove()
	elseif e.Parent then
		local p = e.Parent:ToPlayer()
		e.Position = p.Position
	else
		e:Remove()
	end
end

---@param npc EntityNPC
function SOUL_DRAIN:restoreFlashOnDamage(npc)
	if npc:GetData().spiritSpikeShouldFlash == nil then return end
	local notConnectedToSpike = true
	for _, spike in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, SOUL_DRAIN.MOVEMENT_HANDLER)) do
		if spike:GetData().securedNPC == false and GetPtrHash(spike:GetData().NPCTarget) == GetPtrHash(npc) then
			notConnectedToSpike = false
		end
	end
	if notConnectedToSpike then
		if npc:GetData().spiritSpikeShouldFlash == true then
			npc:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
		end
		npc:GetData().spiritSpikeShouldFlash = nil
	end
end
]]

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
	data.SoulDrainDamageTracker = (data.SoulDrainDamageTracker or effects:GetCollectibleEffectNum(SOUL_DRAIN.DAMAGE_TRACKER)) + amount
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
		local dmgDealt = math.min(ent.HitPoints, amount)
		SOUL_DRAIN:UpdateSoulDrainBar(player, math.min(SOUL_DRAIN.DIRECT_DAMAGE_CAP, dmgDealt * SOUL_DRAIN.DIRECT_DAMAGE_PERCENTAGE))
	end
end

Mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.LATE, SOUL_DRAIN.TrackDamageDealt)

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
		sprite:RenderLayer(1, position, Vector.Zero, Vector(BAR_LENGTH * math.min(threshold, (threshold - dmgDealt) / threshold), 0))
		if player:GetPlayerType() == Mod.PLAYER_DORKY_B and player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
			sprite:RenderLayer(2, position)
		end
	end
}, HudHelper.HUDType.EXTRA)
