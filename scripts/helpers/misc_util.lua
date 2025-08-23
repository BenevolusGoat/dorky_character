DorkyMod.RandomRNG = RNG()
DorkyMod.RandomRNG:SetSeed(Random() + 1)

---@param lower? integer
---@param upper? integer
function DorkyMod:RandomNum(lower, upper)
	if upper then
		return DorkyMod.RandomRNG:RandomInt((upper - lower) + 1) + lower
	elseif lower then
		return DorkyMod.RandomRNG:RandomInt(lower) + 1
	else
		return DorkyMod.RandomRNG:RandomFloat()
	end
end

---@param ent Entity?
function DorkyMod:IsValidEnemyTarget(ent)
	return ent
		and ent:ToNPC()
		and ent:IsActiveEnemy(false)
		and ent:IsVulnerableEnemy()
		and not ent:IsDead()
		and not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
		and ent.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE
		and (ent:ToNPC().CanShutDoors or ent.Type == EntityType.ENTITY_DUMMY)
end

--Thank you piber!
---@param pos Vector
---@param range? number
---@param filter? fun(npc: EntityNPC): boolean?
---@return EntityNPC | nil
function DorkyMod:GetClosestEnemy(pos, range, filter)
	---@type EntityNPC | nil
	local closestEnemy
	local closestDistance
	local entities
	if range then
		entities = Isaac.FindInRadius(pos, range, EntityPartition.ENEMY)
	else
		entities = Isaac.GetRoomEntities()
	end

	for _, ent in ipairs(entities) do
		local npc = ent:ToNPC()
		if npc and (not filter and DorkyMod:IsValidEnemyTarget(npc) or filter and filter(npc)) then
			---@cast npc EntityNPC
			local npcDistance = npc.Position:DistanceSquared(pos)

			if not closestEnemy or npcDistance < closestDistance then
				closestEnemy = npc
				closestDistance = npcDistance
			end
		end
	end
	return closestEnemy
end

---@param first Vector
---@param second Vector
---@param percent number
---@param smoothIn? number
---@param smoothOut? number
---@return Vector LerpedVector
function DorkyMod:SmoothLerp(first, second, percent, smoothIn, smoothOut)
	if smoothIn then
		percent = percent ^ smoothIn
	end

	if smoothOut then
		percent = 1 - percent
		percent = percent ^ smoothOut
		percent = 1 - percent
	end

	return (first + (second - first) * percent)
end

---@param dir integer
function DorkyMod:DirectionToVector(dir)
	return Vector(-1, 0):Rotated(90 * dir)
end

---@param player EntityPlayer
function DorkyMod:SpawnBlackHeartIndicator(player)
	local notify = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEART, 5, player.Position, Vector.Zero, player)
	notify:GetSprite().Offset = Vector(0, -24)
	notify.RenderZOffset = 1000
end