local Mod = DorkyMod

local TONGUE_GRAPPLE = {}

DorkyMod.Item.TONGUE_GRAPPLE = TONGUE_GRAPPLE

TONGUE_GRAPPLE.COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/costume_dorky_tongue_out.anm2")
TONGUE_GRAPPLE.MOVEMENT_HANDLER = Isaac.GetEntityVariantByName("Dorky Tongue Rope Movement Handler")
TONGUE_GRAPPLE.DUMMY_TARGET = Isaac.GetEntityVariantByName("Dorky Tongue Dummy Target")
--[[
---@param effect EntityEffect
---@param player EntityPlayer
local function RemoveTongue(effect, player)
	player:ToPlayer():TryRemoveNullCostume(TONGUE_GRAPPLE.COSTUME)
	if effect.Child then
		effect.Child:Remove()
	end
	effect:Remove()
end

---@param player EntityPlayer
function TONGUE_GRAPPLE:PreTongueUse(_, _, player)
	local npc = Mod:GetClosestEnemy(player.Position, 400)

	if npc then
		local npcData = npc:GetData()
		if not npcData.IsDorkyTongued then
			local data = player:GetData()
			data.DorkyEnemyFound = npc
		end
	else
		return false
	end
end

---@param player EntityPlayer
function TONGUE_GRAPPLE:OnTongueUse(_, _, player)
	local data = player:GetData()
	local shouldDischarge = data.DorkyEnemyFound or false

	if data.DorkyEnemyFound then
		player:AddNullCostume(TONGUE_GRAPPLE.COSTUME)
		local npc = data.DorkyEnemyFound
		local npcData = npc:GetData()
		local movementHandler = Isaac.Spawn(EntityType.ENTITY_EFFECT, TONGUE_GRAPPLE.MOVEMENT_HANDLER, 0, player
		.Position,
			(npc.Position - player.Position):Normalized():Resized(35), nil)
		local dummyTarget = Isaac.Spawn(EntityType.ENTITY_EFFECT, TONGUE_GRAPPLE.DUMMY_TARGET, 0, player.Position,
			Vector.Zero
			, player)
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
		movementHandler:GetData().NPCTarget = npc
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
		handlerData.DorkyTongueBounces = 2 + (1 * player:GetCollectibleNum(CollectibleType.COLLECTIBLE_BIRTHRIGHT))
		evisCord:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS | EntityFlag.FLAG_NO_TARGET |
			EntityFlag.FLAG_NO_KNOCKBACK |
			EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
		evisCord:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
		evisCord.DepthOffset = 300
		dummyTarget:Update()
		movementHandler:Update()
		data.DorkyEnemyFound = nil
	end
	return { Discharge = shouldDischarge, Remove = false, ShowAnim = false }
end

---@param evisCord EntityNPC
function TONGUE_GRAPPLE:TongueUpdate(evisCord)
	local data = evisCord:GetData()
	if not data.IsDorkyTongue or evisCord.Variant ~= 10 or evisCord.SubType ~= 1 then return end
	if evisCord.Target.Type == EntityType.ENTITY_EFFECT and evisCord.Target.Variant == TONGUE_GRAPPLE.DUMMY_TARGET then
		return false
	end
end

---@param player EntityPlayer
---@param handlerData table
---@param numBounces integer
local function NoBirthrightOrNumBouncesLeft(player, handlerData, numBounces)
	if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or
		(
			player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
			and handlerData.DorkyTongueBounces == numBounces
		)
	then
		return true
	end
	return false
end

---@param player EntityPlayer
---@param handlerData table
---@param numBounces integer
---@param duration integer
local function NoBirthrightOrDurationDependent(player, handlerData, numBounces, duration)
	if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or
		(
			player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
			and (
				handlerData.DorkyTongueBounces == numBounces
				or (
					handlerData.DorkyTongueBounces < numBounces
					and handlerData.DorkyTongueLifetime > duration
				)
			)
		)
	then
		return true
	end
	return false
end

---@param effect EntityEffect
function TONGUE_GRAPPLE:TongueHandlerUpdate(effect)
	local player = effect.Parent:ToPlayer()
	local data = effect:GetData()

	if data.DorkyTongueLifetime then
		data.DorkyTongueLifetime = data.DorkyTongueLifetime + 1
	end

	if player and player:Exists() and not player:IsDead() then
		if data.NPCTarget and data.NPCTarget:Exists() and not data.NPCTarget:IsDead() then
			if effect.Position:DistanceSquared(data.NPCTarget.Position) <= 50 ^ 2 and not data.NPCSecured then
				data.NPCSecured = true
				data.NPCTarget:AddEntityFlags(EntityFlag.FLAG_FREEZE)
				data.NPCTarget:GetData().DorkyTonguedNPC = 10
				effect.Visible = true
			end
		elseif data.NPCSecured then
			effect.Visible = false
		end


		if (
				not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and
				(data.DorkyTongueLifetime > 7 or data.NPCSecured == true))
			or player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
			and (
				(
					data.DorkyTongueBounces == 3
					and (data.DorkyTongueLifetime > 7 or data.NPCSecured == true)
				)
				or data.DorkyTongueBounces < 3 and data.DorkyTongueLifetime >= 0
			) then
			--Pulling tongue back to player
			local targetVec = ((player.Position + player.Velocity) - effect.Position)
			if targetVec:Length() > 30 then
				targetVec = targetVec:Resized(30)
			end

			if data.DorkyTongueLifetime > 7 then
				data.DorkyTongueLifetime = 8
			end

			if NoBirthrightOrDurationDependent(player, data, 3, 0) then
				effect.Velocity = Mod:SmoothLerp(effect.Velocity, targetVec,
					math.min(0.1 + data.DorkyTongueLifetime / 10), 1)
			end

			if effect.Position:Distance(player.Position) < 30
				and NoBirthrightOrDurationDependent(player, data, 3, 4)
			then
				if data.DorkyTongueBounces then
					data.DorkyTongueBounces = data.DorkyTongueBounces - 1
				end

				if NoBirthrightOrNumBouncesLeft(player, data, 0) then
					data.NPCTarget:GetData().IsDorkyTongued = nil
					RemoveTongue(effect, player)
				end

				if data.NPCSecured and data.NPCTarget and data.NPCTarget:Exists() then
					data.NPCTarget.Velocity = Vector.Zero

					local direction = (player.Position - data.NPCTarget.Position):Normalized()
					local knockbackTear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.FIST, 0,
						data.NPCTarget.Position + direction:Resized(20), direction:Resized(-1), player):ToTear()
					---@diagnostic disable-next-line: param-type-mismatch
					knockbackTear:AddTearFlags(TearFlags.TEAR_PUNCH)
					knockbackTear.CollisionDamage = 5 + player.Damage
					knockbackTear.Visible = false
					data.NPCTarget.Velocity = Vector.Zero

					if NoBirthrightOrNumBouncesLeft(player, data, 0) then
						data.NPCTarget:ClearEntityFlags(EntityFlag.FLAG_FREEZE)
					end

					if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
						and data.DorkyTongueBounces > 0 then
						data.DorkyTongueLifetime = -7
						data.NPCTarget:GetData().DorkyTonguedNPC = 20
						effect.Velocity = Vector.Zero
						effect:AddVelocity(direction:Resized(-30))
					end
				elseif NoBirthrightOrNumBouncesLeft(player, data, 3) then
					if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == g.COLLECTIBLE_TONGUE_GRAPPLE then
						player:FullCharge(ActiveSlot.SLOT_POCKET)
					end
				end
			end
		elseif data.DorkyTongueLifetime > 4 then
			effect.Velocity = effect.Velocity * 0.3
		end
		if data.NPCSecured then
			data.NPCTarget.Position = effect.Position
			if data.NPCTarget:IsDead() or not data.NPCTarget:Exists() then
				RemoveTongue(effect, player)
			end
		end
	else
		RemoveTongue(effect, player)
	end
end

local headDirs = {
	[Direction.NO_DIRECTION] = Vector(0, 1),
	[Direction.LEFT]         = Vector(-10, 0),
	[Direction.UP]           = Vector(0, -11),
	[Direction.RIGHT]        = Vector(10, 0),
	[Direction.DOWN]         = Vector(0, 1),
}

function TONGUE_GRAPPLE:dummyTongueTargetAI(e)
	if not e.Child then
		e:Remove()
	elseif e.Parent then
		local p = e.Parent:ToPlayer()
		e.Position = p.Position + (headDirs[p:GetHeadDirection()] * p.SpriteScale)
	else
		e:Remove()
	end
end

function TONGUE_GRAPPLE:IgnoreTonguedNPCCollision(npc, collider)
	local data = npc:GetData()

	if data.DorkyTonguedNPC ~= nil
		and collider:ToPlayer() ~= nil
	then
		return false
	end
end

function TONGUE_GRAPPLE:TonguedNPCUpdate(npc)
	local data = npc:GetData()
	if not data.DorkyTonguedNPC then return end
	if data.DorkyTonguedNPC > 0 then
		data.DorkyTonguedNPC = data.DorkyTonguedNPC - 1
	else
		data.DorkyTonguedNPC = nil
	end
end

function TONGUE_GRAPPLE:Debug()
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
end ]]
