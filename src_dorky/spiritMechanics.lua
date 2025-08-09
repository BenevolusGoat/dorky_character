local spiritMechanics = {}
local g = require("src_dorky.dorkyGlobals")
local VeeHelper = require("src_dorky.veeHelper")
local sfx = SFXManager()

local maxNPCAttachDuration = 120
local spikeCollisionRadius = 25
local maxDistanceFromNPCWhenAttached = 200
local spikeInitVelocity = 30

---@param player EntityPlayer
local function getSpiritSpikeSuccDuration(player)
	local maxSpikeFireDelay = 0.5
	local firedelay = player.MaxFireDelay >= maxSpikeFireDelay and player.MaxFireDelay or maxSpikeFireDelay
	return firedelay * 3
end

---@param player EntityPlayer
local function getSpiritSikeDamage(player)
	return player.Damage * 2 + 1.5
end

---@param player EntityPlayer
local function getSpiritSpikeSuccDamageRequirement(player)
	local baseDmg = 4.20
	local spikeDamage = getSpiritSikeDamage(player)
	local dmgRequirement = math.ceil(spikeDamage * (4 + (baseDmg / player.Damage * 4)))
	if dmgRequirement < spikeDamage * 4 then
		dmgRequirement = spikeDamage * 4
	end
	return dmgRequirement
end

---@param effect EntityEffect
local function RemoveSpiritSpike(effect)
	if effect.Child then
		effect.Child:Remove()
	end
	effect:Remove()
end

local function CountBits(mask)
	local count = 0
	while mask ~= 0 do
		count = count + 1
		mask = mask & mask - 1
	end

	return count
end

---@param player EntityPlayer
---@param heartSubType HeartSubType | nil
---@param numSoulHearts integer | nil
local function hasUnchargedAlabaster(player, heartSubType, numSoulHearts)
	local shouldGetSoul = false
	local boxes = VeeHelper.GetActiveItemCharges(player, CollectibleType.COLLECTIBLE_ALABASTER_BOX)
	local maxCharge = Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_ALABASTER_BOX).MaxCharges
	for _, charge in pairs(boxes) do
		if charge < maxCharge then
			if heartSubType and
				(
				(heartSubType == HeartSubType.HEART_HALF_SOUL and charge == maxCharge - 1)
					or (heartSubType == HeartSubType.HEART_SOUL and charge <= maxCharge - 2)
				)
				or numSoulHearts and
				(
				charge + numSoulHearts >= maxCharge
				) then
				shouldGetSoul = true
			end
		end
	end
	return shouldGetSoul
end

---@param player EntityPlayer
function spiritMechanics:onlyBlackHealth(player)
	local redHearts = player:GetMaxHearts()
	local redHealth = player:GetHearts()
	local boneHearts = player:GetBoneHearts()
	local blackHearts = CountBits(player:GetBlackHearts()) * 2
	local soulHearts = player:GetSoulHearts() - blackHearts
	local eternalHearts = player:GetEternalHearts()
	local heartLimit = player:GetHeartLimit()
	local hasMaxHearts = redHearts + (boneHearts * 2) + soulHearts + blackHearts == heartLimit

	if redHearts > 0 then
		player:AddMaxHearts(-redHearts, true)
	end
	if redHealth > 0 then
		player:AddHearts(-redHealth)
	end
	if boneHearts > 0 then
		player:AddBoneHearts(-boneHearts)
	end
	if not hasUnchargedAlabaster(player, nil, soulHearts) and soulHearts > 0 then
		player:AddSoulHearts(-soulHearts)
	end
	if eternalHearts > 0 then
		player:AddEternalHearts(-eternalHearts)
	end

	if hasMaxHearts then
		player:AddBlackHearts(heartLimit - blackHearts)
	end
end

---@param heart EntityPickup
---@param player EntityPlayer
function spiritMechanics:ignoreMostHearts(heart, player)
	if heart.SubType ~= HeartSubType.HEART_BLACK
		and heart.SubType ~= HeartSubType.HEART_GOLDEN
	then
		---@type boolean | nil
		local shouldCollide = false
		if heart.SubType == HeartSubType.HEART_SOUL
			or heart.SubType == HeartSubType.HEART_HALF_SOUL
		then
			local alabaster = hasUnchargedAlabaster(player, heart.SubType, nil)
			if alabaster == true then shouldCollide = nil end
		end

		return shouldCollide
	end
end

---@param itemID CollectibleType
---@param player EntityPlayer
function spiritMechanics:onSoulStealUse(itemID, _, player)
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
function spiritMechanics:shouldThrowSpiritSpike(player)
	local data = player:GetData()

	if data.canThrowSpiritSpike then
		if player:GetFireDirection() ~= Direction.NO_DIRECTION then
			spiritMechanics:throwSpiritSpike(player)
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
function spiritMechanics:throwSpiritSpike(player)
	local pData = player:GetData()
	local dir = VeeHelper.DirectionToVector(player:GetFireDirection()):Resized(spikeInitVelocity)
	local movementHandler = Isaac.Spawn(EntityType.ENTITY_EFFECT, g.SPIRIT_SPIKE_ROPE_HANDLER, 0, player.Position, dir, player)
	local dummyTarget = Isaac.Spawn(EntityType.ENTITY_EFFECT, g.SPIRIT_SPIKE_DUMMY_TARGET, 0, player.Position, Vector.Zero,
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
	sfx:Play(SoundEffect.SOUND_WHIP)
end

---@param evisCord EntityNPC
function spiritMechanics:evisCordSpikeUpdate(evisCord)
	local data = evisCord:GetData()
	if not data.IsSpiritSpike or evisCord.Variant ~= 10 or evisCord.SubType ~= 1 then return end
	if evisCord.Target.Type == EntityType.ENTITY_EFFECT and evisCord.Target.Variant == g.SPIRIT_SPIKE_DUMMY_TARGET then
		return false
	end
end

---@param ent Entity
---@param source EntityRef
function spiritMechanics:onSpikeDamage(ent, amount, _, source, _)
	if source.Entity and source.Entity:ToEffect()
		and source.Entity.Variant == g.SPIRIT_SPIKE_ROPE_HANDLER
	then
		local data = source.Entity.Parent:ToPlayer():GetData()
		if not data.checkNPCRemainingHealth then
			data.checkNPCRemainingHealth = {}
		end
		table.insert(data.checkNPCRemainingHealth, { ent:ToNPC(), ent.HitPoints, g.game:GetRoom():GetFrameCount() })
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
		and g.game:GetRoom():IsPositionInRoom(npc.Position, -30)
	then
		return true
	else
		return false
	end
end

---@param effect EntityEffect
function spiritMechanics:tryStickToNPC(effect)
	local player = effect.Parent:ToPlayer()
	local pData = player:GetData()
	local data = effect:GetData()

	if not data.securedNPC and not data.hadCaughtNPC then
		local npc = pData.checkNPCNextFrame or VeeHelper.DetectNearestEnemy(effect, spikeCollisionRadius)

		if npc and shouldNPCGetSpiritSpiked(npc) then
			if not pData.checkNPCNextFrame then
				npc:TakeDamage(player.Damage * 1.5, 0, EntityRef(effect), 10)
				pData.checkNPCNextFrame = npc
				data.hadDamagedNPC = true
			else
				data.securedNPC = true
				data.NPCTarget = npc
				data.hadCaughtNPC = true
				data.attachDuration = maxNPCAttachDuration
				npc:GetData().caughtOnSpiritSpike = true
				npc:GetData().spiritSpikeShouldFlash = npc:HasEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
				effect.Velocity = Vector.Zero
				npc:AddSlowing(EntityRef(player), maxNPCAttachDuration, 0.1, Color(0.2, 0.2, 0.2))
				sfx:Play(SoundEffect.SOUND_WHIP_HIT)
				pData.checkNPCNextFrame = nil
			end
		elseif pData.checkNPCNextFrame then
			pData.checkNPCNextFrame = nil
			spiritMechanics:tryStickToNPC(effect)
		end
	end
end

---@param effect EntityEffect
function spiritMechanics:drainAttachedNPC(effect)
	local data = effect:GetData()
	local player = effect.Parent:ToPlayer()

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

	if player.Position:Distance(data.NPCTarget.Position) > maxDistanceFromNPCWhenAttached then
		player.Velocity = player.Velocity +
			(data.NPCTarget.Position - player.Position):Resized(math.min(10, distance - maxDistanceFromNPCWhenAttached))
		player.Position = data.NPCTarget.Position +
			(player.Position - data.NPCTarget.Position):Resized(maxDistanceFromNPCWhenAttached)
	end

	if data.NPCTarget:GetData().spiritSpikeShouldFlash
		and not data.NPCTarget:HasEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	then
		data.NPCTarget:AddEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
	end

	if not data.timeTillHealthDrain then
		data.timeTillHealthDrain = getSpiritSpikeSuccDuration(player)
	elseif data.timeTillHealthDrain > 0 then
		data.timeTillHealthDrain = data.timeTillHealthDrain - 1
	elseif not data.checkRemainingHealth then
		if data.NPCTarget:GetData().spiritSpikeShouldFlash then
			data.NPCTarget:ClearEntityFlags(EntityFlag.FLAG_NO_FLASH_ON_DAMAGE)
		end
		data.NPCTarget:TakeDamage(getSpiritSikeDamage(player), 0, EntityRef(effect), 0)
		data.NPCTarget:SetColor(Color(0, 0, 0, data.NPCTarget.Color.A), 10, 6, true, false)
		sfx:Play(SoundEffect.SOUND_ROTTEN_HEART, 1.5, 2, false, 0.7, 0)
		data.timeTillHealthDrain = getSpiritSpikeSuccDuration(player)
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
function spiritMechanics:spiritSpikeHandlerUpdate(effect)
	local player = effect.Parent:ToPlayer()
	local data = effect:GetData()

	if data.spiritSpikeLifetime then
		data.spiritSpikeLifetime = data.spiritSpikeLifetime + 1
	else
		data.spiritSpikeLifetime = 0
	end

	if player and player:Exists() and not player:IsDead() then

		player:SetActiveCharge(0, ActiveSlot.SLOT_POCKET)
		spiritMechanics:tryStickToNPC(effect)

		if data.spiritSpikeLifetime > 9 and not data.securedNPC then
			--Pulling spike back to player
			local targetVec = ((player.Position + player.Velocity) - effect.Position)
			if targetVec:Length() > 30 then
				targetVec = targetVec:Resized(30)
			end

			effect.Velocity = VeeHelper.SmoothLerp(effect.Velocity, targetVec, math.min(0.1 + 8 / 10), 1)

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
			spiritMechanics:drainAttachedNPC(effect)
		end
	else
		RemoveSpiritSpike(effect)
	end
end

---@param player EntityPlayer
local function spawnBlackHeartIndicator(player)
	local notify = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEART, 5, player.Position, Vector.Zero, player)
	notify:GetSprite().Offset = Vector(0, -24)
	notify.RenderZOffset = 1000
end

---@param player EntityPlayer
function spiritMechanics:healFromSpiritSpike(player)
	local data = player:GetData()
	local dmgRequirement = getSpiritSpikeSuccDamageRequirement(player)
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

			if g.game:GetRoom():GetFrameCount() >= frameHit + 2 and not hasBeenChecked then
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
		sfx:Play(SoundEffect.SOUND_VAMP_GULP)
		data.spikeDamageBank = data.spikeDamageBank - (dmgRequirement * numHeartsAdded)
	end
end

---@param e EntityEffect
function spiritMechanics:dummySpikeTargetAI(e)
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
function spiritMechanics:restoreFlashOnDamage(npc)
	if npc:GetData().spiritSpikeShouldFlash == nil then return end
	local notConnectedToSpike = true
	for _, spike in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, g.SPIRIT_SPIKE_ROPE_HANDLER)) do
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

---@param player EntityPlayer
function spiritMechanics:voidRegeneration(player)
	local stage = g.game:GetLevel():GetStage()

	if stage == LevelStage.STAGE7 then
		if g.game.TimeCounter % 60 == 0
			and VeeHelper.RandomNum(1) == 1
		then
			player:AddBlackHearts(1)
			spawnBlackHeartIndicator(player)
			player:SetColor(Color(0, 0, 0), 10, 0, true, false)
			sfx:Play(SoundEffect.SOUND_UNHOLY)
		end
	end
end

return spiritMechanics
