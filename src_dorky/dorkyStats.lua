local dorkyStats = {}
local g = require("src_dorky.dorkyGlobals")

local dorky = {
	[CacheFlag.CACHE_SPEED] = -0.25,
	[CacheFlag.CACHE_FIREDELAY] = 1,
	[CacheFlag.CACHE_DAMAGE] = 1,
	[CacheFlag.CACHE_RANGE] = 0,
	[CacheFlag.CACHE_SHOTSPEED] = -0.3,
	[CacheFlag.CACHE_LUCK] = -1,
	[CacheFlag.CACHE_TEARFLAG] = TearFlags.TEAR_SPECTRAL
}

local spirit = {
	[CacheFlag.CACHE_SPEED] = 0,
	[CacheFlag.CACHE_FIREDELAY] = 1,
	[CacheFlag.CACHE_DAMAGE] = 1.2,
	[CacheFlag.CACHE_RANGE] = 0,
	[CacheFlag.CACHE_SHOTSPEED] = 0,
	[CacheFlag.CACHE_LUCK] = -2,
	[CacheFlag.CACHE_TEARFLAG] = TearFlags.TEAR_SPECTRAL
}

local stats = {
	[g.PLAYER_DORKY] = dorky,
	[g.PLAYER_SPIRIT] = spirit
}

---@param player EntityPlayer
---@param cacheFlag CacheFlag
function dorkyStats:OnCache(player, cacheFlag)
	local playerType = player:GetPlayerType()
	if playerType ~= g.PLAYER_DORKY and playerType ~= g.PLAYER_SPIRIT then return end

	if cacheFlag == CacheFlag.CACHE_SPEED then
		player.MoveSpeed = player.MoveSpeed + stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
		player.MaxFireDelay = player.MaxFireDelay * stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
		player.Damage = player.Damage * stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_RANGE then
		player.TearRange = player.TearRange + (stats[playerType][cacheFlag] * 40)

	elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
		player.ShotSpeed = player.ShotSpeed + stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_LUCK then
		player.Luck = player.Luck + stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
		---@diagnostic disable-next-line: assign-type-mismatch
		player.TearFlags = player.TearFlags | stats[playerType][cacheFlag]

	elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
		player.TearColor = Color(0, 0, 0, 1, 0, 0, 0)

	elseif cacheFlag == CacheFlag.CACHE_FLYING then
		if playerType == g.PLAYER_SPIRIT then
			player.CanFly = true

		end
	end
end

return dorkyStats
