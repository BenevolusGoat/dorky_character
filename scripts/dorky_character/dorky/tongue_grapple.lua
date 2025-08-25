local Mod = DorkyMod
local min = math.min

local TONGUE_GRAPPLE = {}

DorkyMod.Item.TONGUE_GRAPPLE = TONGUE_GRAPPLE

TONGUE_GRAPPLE.COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_tongue_out.anm2")
TONGUE_GRAPPLE.MOVEMENT_HANDLER = Isaac.GetEntityVariantByName("Dorky Tongue Rope Movement Handler")
TONGUE_GRAPPLE.DUMMY_TARGET = Isaac.GetEntityVariantByName("Dorky Tongue Dummy Target")

TONGUE_GRAPPLE.DEFAULT_BIRTHRIGHT_PADDLES = 3
--Tongue starts pulling back after this point
TONGUE_GRAPPLE.MAX_TONGUE_DURATION = 8
--Tongue starts slowing down after this point
TONGUE_GRAPPLE.MAX_VELOCITY_DURATION = 4
TONGUE_GRAPPLE.MAX_RANGE = 400
TONGUE_GRAPPLE.INIT_VELOCITY = 35

--#region Helper

---@param player EntityPlayer
function TONGUE_GRAPPLE:GetMaxPaddles(player)
	local numBirthright = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
	if numBirthright == 0 then
		return 0
	end
	return TONGUE_GRAPPLE.DEFAULT_BIRTHRIGHT_PADDLES + (numBirthright - 1)
end

---@param player EntityPlayer
---@param handlerData table
function TONGUE_GRAPPLE:ShouldReleaseEnemy(player, handlerData)
	return not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or not handlerData.NPCSecured or handlerData.DorkyTongueBounces <= 0
end

---@param player EntityPlayer
---@param handlerData table
function TONGUE_GRAPPLE:CanRechargePocket(player, handlerData)
	--Don't want to recharge pocket if you successfully paddled an enemy that then died while retracting tongue.
	return not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or handlerData.DorkyTongueBounces == TONGUE_GRAPPLE:GetMaxPaddles(player)
end

---@param player EntityPlayer
---@param handlerData table
function TONGUE_GRAPPLE:CanKnockbackEnemy(player, handlerData)
	--Don't want to continuously knockback enemy right after paddling it, wait a bit
	return not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or handlerData.DorkyTongueLifetime > TONGUE_GRAPPLE.MAX_VELOCITY_DURATION
end

---@param player EntityPlayer
---@param handlerData table
function TONGUE_GRAPPLE:CanPullTongueBack(player, handlerData)
	--Missed enemy after a duration
	if handlerData.DorkyTongueLifetime >= TONGUE_GRAPPLE.MAX_TONGUE_DURATION then
		return true
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
		return handlerData.NPCSecured
			and (
				handlerData.DorkyTongueBounces == TONGUE_GRAPPLE:GetMaxPaddles(player)
				or handlerData.DorkyTongueLifetime >= 0
			)
	else
		return handlerData.NPCSecured
	end
end

---@param effect EntityEffect
---@param player EntityPlayer
function TONGUE_GRAPPLE:RemoveTongue(effect, player)
	player:ToPlayer():TryRemoveNullCostume(TONGUE_GRAPPLE.COSTUME)
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

--#endregion

--#region On Use

---@param player EntityPlayer
function TONGUE_GRAPPLE:OnTongueUse(_, _, player)
	local npc = Mod:GetClosestEnemy(player.Position, TONGUE_GRAPPLE.MAX_RANGE)

	if npc then
		player:AddNullCostume(TONGUE_GRAPPLE.COSTUME)
		local npcData = npc:GetData()
		local movementHandler = Isaac.Spawn(EntityType.ENTITY_EFFECT, TONGUE_GRAPPLE.MOVEMENT_HANDLER, 0,
			player.Position, (npc.Position - player.Position):Normalized():Resized(TONGUE_GRAPPLE.INIT_VELOCITY), nil)
		local dummyTarget = Isaac.Spawn(EntityType.ENTITY_EFFECT, TONGUE_GRAPPLE.DUMMY_TARGET, 0,
			player.Position, Vector.Zero, player)
		local evisCord = Isaac.Spawn(EntityType.ENTITY_EVIS, 10, 1, player.Position, Vector.Zero, player)
		local sprite = evisCord:GetSprite()
		local handlerSprite = movementHandler:GetSprite()
		local handlerData = movementHandler:GetData()

		npcData.IsDorkyTongued = true
		dummyTarget.Parent = player
		dummyTarget.Child = evisCord
		dummyTarget.Visible = false
		movementHandler.Child = evisCord
		movementHandler.Parent = player
		movementHandler:GetData().NPCTarget = EntityPtr(npc)
		movementHandler.Visible = false
		movementHandler.DepthOffset = 301
		handlerSprite.Scale = Vector(1.5, 1.5)
		handlerSprite.Offset = Vector(0, -10)
		handlerSprite:ReplaceSpritesheet(0, "gfx/effects/dorky_tongue_wrap.png")
		handlerSprite:ReplaceSpritesheet(1, "gfx/effects/dorky_tongue_wrap.png")
		handlerSprite:LoadGraphics()
		handlerSprite:Stop()
		handlerSprite:SetFrame(1)
		sprite:ReplaceSpritesheet(0, "gfx/effects/dorky_tongue.png")
		sprite:ReplaceSpritesheet(1, "gfx/effects/dorky_tongue.png")
		sprite:LoadGraphics()
		evisCord.Parent = movementHandler
		evisCord.Target = dummyTarget
		evisCord:GetData().IsDorkyTongue = true
		handlerData.DorkyTongueLifetime = 0
		handlerData.DorkyTongueBounces = TONGUE_GRAPPLE:GetMaxPaddles(player)
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
	end
	return { Discharge = npc ~= nil, Remove = false, ShowAnim = false }
end

Mod:AddCallback(ModCallbacks.MC_USE_ITEM, TONGUE_GRAPPLE.OnTongueUse, Mod.COLLECTIBLE_TONGUE_GRAPPLE)

--#endregion

--#region Handler update

---@param player EntityPlayer
---@param effect EntityEffect
---@param npc EntityNPC
function TONGUE_GRAPPLE:KnockbackEnemy(player, effect, npc)
	local handlerData = effect:GetData()
	npc.Velocity = Vector.Zero

	local direction = (player.Position - npc.Position):Normalized()
	local knockbackTear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.FIST, 0,
		npc.Position + direction:Resized(20), direction:Resized(-1), player):ToTear()
	---@cast knockbackTear EntityTear
	knockbackTear:AddTearFlags(TearFlags.TEAR_PUNCH)
	knockbackTear.CollisionDamage = 5 + player.Damage
	knockbackTear.Visible = false
	npc.Velocity = Vector.Zero

	if TONGUE_GRAPPLE:ShouldReleaseEnemy(player, handlerData) then
		npc:ClearEntityFlags(EntityFlag.FLAG_FREEZE)
		npc:GetData().IsDorkyTongued = nil
	end

	if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
		and handlerData.DorkyTongueBounces > 0
	then
		handlerData.DorkyTongueLifetime = -4
		npc:GetData().DorkyTonguedNPC = 20
		effect.Velocity = Vector.Zero
		effect:AddVelocity(direction:Resized(-30))
	end
end

---@param effect EntityEffect
function TONGUE_GRAPPLE:TongueHandlerUpdate(effect)
	local player = effect.Parent:ToPlayer()
	if not player then return end
	local handlerData = effect:GetData()
	local npc = getNPCFromPtr(handlerData.NPCTarget)

	if not player
		or not player:Exists()
		or player:IsDead()
	then
		TONGUE_GRAPPLE:RemoveTongue(effect, player)
		return
	end

	if handlerData.DorkyTongueLifetime then
		handlerData.DorkyTongueLifetime = min(handlerData.DorkyTongueLifetime + 1, TONGUE_GRAPPLE.MAX_TONGUE_DURATION)
	end

	if npc and not npc:IsDead() then
		if effect.Position:DistanceSquared(npc.Position) <= (50 ^ 2) and not handlerData.NPCSecured then
			handlerData.NPCSecured = true
			npc:AddEntityFlags(EntityFlag.FLAG_FREEZE)
			npc:GetData().DorkyTonguedNPC = 10
			effect.Visible = true
		end
	elseif handlerData.NPCSecured then
		effect.Visible = false
	end

	if TONGUE_GRAPPLE:CanPullTongueBack(player, handlerData) then
		--Pulling tongue back to player
		local targetVec = ((player.Position + player.Velocity) - effect.Position)
		if targetVec:Length() > 30 then
			targetVec = targetVec:Resized(30)
		end

		effect.Velocity = Mod:SmoothLerp(effect.Velocity, targetVec,
			min(0.1 + handlerData.DorkyTongueLifetime / 10), 1)

		if effect.Position:DistanceSquared(player.Position) <= 50 ^ 2
			and TONGUE_GRAPPLE:CanKnockbackEnemy(player, handlerData)
		then
			if npc and not npc:IsDead() and handlerData.NPCSecured then
				if handlerData.DorkyTongueBounces then
					handlerData.DorkyTongueBounces = handlerData.DorkyTongueBounces - 1
				end
				TONGUE_GRAPPLE:KnockbackEnemy(player, effect, npc)
			elseif TONGUE_GRAPPLE:CanRechargePocket(player, handlerData) then
				if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == Mod.COLLECTIBLE_TONGUE_GRAPPLE then
					player:FullCharge(ActiveSlot.SLOT_POCKET)
				end
			end
			if TONGUE_GRAPPLE:ShouldReleaseEnemy(player, handlerData) then
				TONGUE_GRAPPLE:RemoveTongue(effect, player)
			end
		end
	elseif handlerData.DorkyTongueLifetime > TONGUE_GRAPPLE.MAX_VELOCITY_DURATION then
		effect.Velocity = effect.Velocity * 0.3
	end
	if handlerData.NPCSecured then
		if npc then
			npc.Position = effect.Position
		else
			TONGUE_GRAPPLE:RemoveTongue(effect, player)
		end
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, TONGUE_GRAPPLE.TongueHandlerUpdate, TONGUE_GRAPPLE.MOVEMENT_HANDLER)

--#endregion

--#region Dummy update

local headDirs = {
	[Direction.NO_DIRECTION] = Vector(0, 1),
	[Direction.LEFT]         = Vector(-10, 0),
	[Direction.UP]           = Vector(0, -11),
	[Direction.RIGHT]        = Vector(10, 0),
	[Direction.DOWN]         = Vector(0, 1),
}

---@param effect EntityEffect
function TONGUE_GRAPPLE:DummyTongueTargetAI(effect)
	local player = effect.Parent and effect.Parent:ToPlayer()
	if not effect.Child then
		effect:Remove()
	elseif player then
		effect.Position = player.Position + (headDirs[player:GetHeadDirection()] * player.SpriteScale)
	else
		effect:Remove()
	end
end

Mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, TONGUE_GRAPPLE.DummyTongueTargetAI, TONGUE_GRAPPLE.DUMMY_TARGET)

--#endregion

--#region NPC update

---@param npc EntityNPC
---@param collider Entity
function TONGUE_GRAPPLE:IgnoreTonguedNPCCollision(npc, collider)
	local data = npc:GetData()

	if data.DorkyTonguedNPC ~= nil
		and collider:ToPlayer() ~= nil
	then
		return false
	end
end

Mod:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION, TONGUE_GRAPPLE.IgnoreTonguedNPCCollision)

---@param npc EntityNPC
function TONGUE_GRAPPLE:TonguedNPCUpdate(npc)
	local data = npc:GetData()
	if not data.DorkyTonguedNPC then return end
	if data.DorkyTonguedNPC > 0 then
		data.DorkyTonguedNPC = data.DorkyTonguedNPC - 1
	else
		data.DorkyTonguedNPC = nil
	end
end

--On PRE as to work with mods that override vanilla behavior
Mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, TONGUE_GRAPPLE.TonguedNPCUpdate)


---@param evisCord EntityNPC
function TONGUE_GRAPPLE:TongueUpdate(evisCord)
	local data = evisCord:GetData()
	if data.IsDorkyTongue
		and evisCord.Variant == 10
		and evisCord.SubType == 1
		and evisCord.Target.Type == EntityType.ENTITY_EFFECT
		and evisCord.Target.Variant == TONGUE_GRAPPLE.DUMMY_TARGET
	then
		return false
	end
end

Mod:AddCallback(ModCallbacks.MC_PRE_NPC_UPDATE, TONGUE_GRAPPLE.TongueUpdate, EntityType.ENTITY_VIS)

--#endregion

--#region Debug

function TONGUE_GRAPPLE:Debug()
	if not DorkyMod.FLAGS.Debug then return end
	local duration = 0
	local bounces = "nil"

	for _, h in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, TONGUE_GRAPPLE.MOVEMENT_HANDLER, 0)) do
		local data = h:GetData()

		if data.DorkyTongueBounces then
			bounces = data.DorkyTongueBounces
		end
		if data.DorkyTongueLifetime then
			duration = data.DorkyTongueLifetime
		end
	end

	Isaac.RenderText("Tongue Duration: " .. tostring(duration), 50, 50, 1, 1, 1, 1)
	Isaac.RenderText("Tongue Bounces: " .. tostring(bounces), 50, 70, 1, 1, 1, 1)
end

Mod:AddCallback(ModCallbacks.MC_POST_RENDER, TONGUE_GRAPPLE.Debug)

--#endregion