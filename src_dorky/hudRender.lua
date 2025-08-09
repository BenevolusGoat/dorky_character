local spiritHUDRender = {}
local VeeHelper = require("src_dorky.veeHelper")
local g = require("src_dorky.dorkyGlobals")

---@param player EntityPlayer
local function getSpiritSikeDamage(player)
	return player.Damage * 2 + 1.5
end

---@param player EntityPlayer
local function getSpiritSpikeSuccDamageRequirement(player)
	local baseDmg = 4.20
	return math.ceil(getSpiritSikeDamage(player) * (4 + (baseDmg / player.Damage * 4)))
end

local function GetScreenBottomRight()
	local hudOffset = Options.HUDOffset
	local offset = Vector(-hudOffset * 16, -hudOffset * 6)

	return Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight()) + offset
end

local function GetScreenBottomLeft()
	local hudOffset = Options.HUDOffset
	local offset = Vector(hudOffset * 22, -hudOffset * 6)

	return Vector(0, Isaac.GetScreenHeight()) + offset
end

local function GetScreenTopRight()
	local hudOffset = Options.HUDOffset
	local offset = Vector(-hudOffset * 24, hudOffset * 12)

	return Vector(Isaac.GetScreenWidth(), 0) + offset
end

local function GetScreenTopLeft()
	local hudOffset = Options.HUDOffset
	local offset = Vector(hudOffset * 20, hudOffset * 12)

	return Vector.Zero + offset
end

local numHUDPlayers = 1

---@type table<integer, {Player: EntityPlayer | nil, ScreenPos: function, Offset: table<ActiveSlot, Vector>}>
local IndexedPlayers = {
	[1] = {
		Player = nil,
		ScreenPos = function() return GetScreenTopLeft() end,
		Offset = Vector(71, 35),
	},
	[2] = {
		Player = nil,
		ScreenPos = function() return GetScreenTopRight() end,
		Offset = Vector(-70, 22),
	},
	[3] = {
		Player = nil,
		ScreenPos = function() return GetScreenBottomLeft() end,
		Offset = Vector(120, -17),
	},
	[4] = {
		Player = nil,
		ScreenPos = function() return GetScreenBottomRight() end,
		Offset = Vector(-150, -17),
	}
}

---@param i integer
---@param player EntityPlayer
local function AddActivePlayers(i, player)

	IndexedPlayers[i].Player = player

	if i == 1
		and player:GetOtherTwin() ~= nil
		and player:GetOtherTwin():GetPlayerType() == PlayerType.PLAYER_ESAU
		and IndexedPlayers[4].Player == nil then
		IndexedPlayers[4].Player = player
	end
end

function spiritHUDRender:UpdatePlayers()
	local players = VeeHelper.GetAllMainPlayers()

	if #players ~= numHUDPlayers
		or (g.game:GetFrameCount() == 0 and IndexedPlayers[1].Player ~= nil)
	then
		numHUDPlayers = #players
		for i = 1, 4 do
			IndexedPlayers[i].Player = nil
		end
	end

	for i = 1, #players do
		if i > 4 then break end

		local player = players[i]

		if IndexedPlayers[i].Player == nil then
			AddActivePlayers(i, player)
		end
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
end

---@param player EntityPlayer
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

---@param sprite Sprite
---@param playerSlot integer
local function checkOrientation(sprite, playerSlot)
	local name = sprite:GetFilename()

	if name == "gfx/render_spiritbar_vertical.anm2" and playerSlot ~= 2 then
		sprite:Load("gfx/render_spiritbar_horizontal.anm2", true)
		sprite:Play("Main", true)
	elseif name == "gfx/render_spiritbar_horizontal.anm2" and playerSlot == 2 then
		sprite:Load("gfx/render_spiritbar_vertical.anm2", true)
		sprite:Play("Main", true)
	end
end

---@param player EntityPlayer
---@param sprite Sprite
local function checkBirthright(player, sprite)
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and not sprite:IsPlaying("Birthright") then
		sprite:Play("Birthright", true)
	elseif not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and not sprite:IsPlaying("Main") then
		sprite:Play("Main", true)
	end
end

function spiritHUDRender:renderAmountNeeded()
	for i = 1, #IndexedPlayers do
		local hudPlayer = IndexedPlayers[i]

		if hudPlayer
			and hudPlayer.Player ~= nil
			and g.game:GetHUD():IsVisible()
		then
			local player = hudPlayer.Player
			if player and player:Exists() then
				local playerType = player:GetPlayerType()
				if playerType ~= g.PLAYER_SPIRIT then return end
				local data = player:GetData()

				if not data.spiritDamageBar then
					data.spiritDamageBar = {
						Sprite = Sprite(),
						Color = 1,
						LastKnownDamage = 0,
						Alpha = player.Parent and 0.3 or 1,
						VisibilityDuration = 0,
						ShouldMakeBarSolid = false
					}
					local orientation = (i == 2 or i == 3) and "_vertical" or "_horizontal"
					data.spiritDamageBar.Sprite:Load("gfx/render_spiritbar" .. orientation .. ".anm2", true)
					data.spiritDamageBar.Sprite:Play("Main", true)
				else
					checkOrientation(data.spiritDamageBar.Sprite, i)
					checkBirthright(player, data.spiritDamageBar.Sprite)
					updateSpiritBarColor(player)

					local pos = hudPlayer.ScreenPos() + hudPlayer.Offset
					local screenpos = g.game:GetRoom():WorldToScreenPosition(player.Position)
					local posToRender = player.Parent and Vector(screenpos.X, screenpos.Y - 50) or pos
					local curFrame = data.spikeDamageBank and
						math.ceil((data.spikeDamageBank / getSpiritSpikeSuccDamageRequirement(player)) * 100) or 1
					data.spiritDamageBar.Sprite:SetFrame(curFrame)
					data.spiritDamageBar.Sprite.Color = Color(data.spiritDamageBar.Color, data.spiritDamageBar.Color,
						data.spiritDamageBar.Color, 1)
					data.spiritDamageBar.Sprite:Render(posToRender)

					spiritBarColorUpdate(player)
				end
			end
		end
	end
end

function spiritHUDRender:OnRender()
	spiritHUDRender:UpdatePlayers()
	spiritHUDRender:renderAmountNeeded()
end

function spiritHUDRender:ResetOnGameStart()
	for i = 1, 4 do
		IndexedPlayers[i].Player = nil
	end
end

return spiritHUDRender
