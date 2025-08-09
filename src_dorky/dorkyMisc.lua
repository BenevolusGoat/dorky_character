local dorkyMisc = {}
local g = require("src_dorky.dorkyGlobals")
local VeeHelper = require("src_dorky.veeHelper")

local creepSize = 0.1
local creepGrowth = 0.075

---@param player EntityPlayer
function dorkyMisc:customAnm2Handling(player)
	local playerType = player:GetPlayerType()
	local data = player:GetData()
	local sprite = player:GetSprite()

	if playerType == g.PLAYER_DORKY or playerType == g.PLAYER_SPIRIT then
		if not player:IsCoopGhost()
			and not data.DorkyCustomAnm2Loaded
		then
			local name = {
				[g.PLAYER_DORKY] = "dorky",
				[g.PLAYER_SPIRIT] = "spirit"
			}
			sprite:Load("gfx/characters/player_" .. name[player:GetPlayerType()] .. ".anm2", true)
			sprite:Play(sprite:GetDefaultAnimation(), true)
			data.DorkyCustomAnm2Loaded = true
		elseif player:IsCoopGhost()
			and data.DorkyCustomAnm2Loaded
		then
			data.DorkyCustomAnm2Loaded = false
		end
	elseif data.DorkyCustomAnm2Loaded
		and not player:IsCoopGhost()
		and (
		sprite:GetFilename() == "gfx/characters/player_dorky.anm2"
			or sprite:GetFilename() == "gfx/characters/player_spirit.anm2"
		)
	then
		data.DorkyCustomAnm2Loaded = nil
		sprite:Load("gfx/001.000_player.anm2", true)
		if playerType < PlayerType.NUM_PLAYER_TYPES then
			local nameConversion = { --in case of non-English names
				[PlayerType.PLAYER_ISAAC] = "isaac",
				[PlayerType.PLAYER_MAGDALENE] = "magdalene",
				[PlayerType.PLAYER_CAIN] = "cain",
				[PlayerType.PLAYER_JUDAS] = "judas",
				[PlayerType.PLAYER_BLUEBABY] = "bluebaby",
				[PlayerType.PLAYER_EVE] = "eve",
				[PlayerType.PLAYER_SAMSON] = "samson",
				[PlayerType.PLAYER_AZAZEL] = "azazel",
				[PlayerType.PLAYER_LAZARUS] = "lazarus",
				[PlayerType.PLAYER_EDEN] = "Eden",
				[PlayerType.PLAYER_THELOST] = "thelost",
				[PlayerType.PLAYER_LAZARUS2] = "lazarus2",
				[PlayerType.PLAYER_BLACKJUDAS] = "blackjudas",
				[PlayerType.PLAYER_LILITH] = "lilith",
				[PlayerType.PLAYER_KEEPER] = "keeper",
				[PlayerType.PLAYER_APOLLYON] = "apollyon",
				[PlayerType.PLAYER_THEFORGOTTEN] = "theforgotten",
				[PlayerType.PLAYER_THESOUL] = "thesoul",
				[PlayerType.PLAYER_BETHANY] = "bethany",
				[PlayerType.PLAYER_JACOB] = "jacob",
				[PlayerType.PLAYER_ESAU] = "esau",
				[PlayerType.PLAYER_ISAAC_B] = "isaac",
				[PlayerType.PLAYER_MAGDALENE_B] = "magdalene",
				[PlayerType.PLAYER_CAIN_B] = "cain",
				[PlayerType.PLAYER_JUDAS_B] = "judas",
				[PlayerType.PLAYER_BLUEBABY_B] = "bluebaby",
				[PlayerType.PLAYER_EVE_B] = "eve",
				[PlayerType.PLAYER_SAMSON_B] = "samson",
				[PlayerType.PLAYER_AZAZEL_B] = "azazel",
				[PlayerType.PLAYER_LAZARUS_B] = "lazarus",
				[PlayerType.PLAYER_EDEN_B] = "eden",
				[PlayerType.PLAYER_THELOST_B] = "thelost",
				[PlayerType.PLAYER_LILITH_B] = "lilith",
				[PlayerType.PLAYER_KEEPER_B] = "keeper",
				[PlayerType.PLAYER_APOLLYON_B] = "apollyon",
				[PlayerType.PLAYER_THEFORGOTTEN_B] = "theforgotten",
				[PlayerType.PLAYER_BETHANY_B] = "bethany",
				[PlayerType.PLAYER_JACOB_B] = "jacob",
				[PlayerType.PLAYER_LAZARUS2_B] = "lazarus2",
				[PlayerType.PLAYER_JACOB2_B] = "jacob2",
				[PlayerType.PLAYER_THESOUL_B] = "thesoul",
			}
			local playerNumConversion = { --PlayerType and the number in their spritesheet are not the same
				[PlayerType.PLAYER_BLUEBABY] = "06",
				[PlayerType.PLAYER_EVE] = "05",
				[PlayerType.PLAYER_EDEN] = "09",
				[PlayerType.PLAYER_THELOST] = "12",
				[PlayerType.PLAYER_LAZARUS2] = "10",
				[PlayerType.PLAYER_BETHANY] = "01x",
				[PlayerType.PLAYER_JACOB] = "02x",
				[PlayerType.PLAYER_ESAU] = "03x",
				[PlayerType.PLAYER_EDEN_B] = "09",
				[PlayerType.PLAYER_THELOST_B] = "12",
				[PlayerType.PLAYER_LILITH_B] = "14",
				[PlayerType.PLAYER_KEEPER_B] = "15",
				[PlayerType.PLAYER_APOLLYON_B] = "16",
				[PlayerType.PLAYER_THEFORGOTTEN_B] = "16",
				[PlayerType.PLAYER_BETHANY] = "18",
				[PlayerType.PLAYER_JACOB] = "19",
				[PlayerType.PLAYER_LAZARUS2_B] = "09",
				[PlayerType.PLAYER_JACOB2_B] = "19",
				[PlayerType.PLAYER_THESOUL_B] = "17"
			}
			local playerNum = playerNumConversion[playerType] or
				playerType < PlayerType.PLAYER_BETHANY and tostring(playerType + 1) or
				playerType < PlayerType.PLAYER_EDEN_B and tostring(playerType - 20)
			local playerName = nameConversion[playerType] or string.lower(string.gsub(player:GetName(), " ", ""))
			if playerType < PlayerType.PLAYER_THELOST then
				playerNum = "0" .. playerNum
			elseif playerType >= PlayerType.PLAYER_ISAAC_B then
				playerNum = playerNum .. "b"
			end

			for spriteLayer = 0, PlayerSpriteLayer.NUM_SPRITE_LAYERS do
				if spriteLayer ~= PlayerSpriteLayer.SPRITE_GHOST then
					sprite:ReplaceSpritesheet(spriteLayer,
						"gfx/characters/costumes/character_0" .. tostring(playerType) .. playerName .. ".png")
				end
			end
		end
	end
end

---@param player EntityPlayer
function dorkyMisc:spawnBlackGoopOnDeath(player)
	local sprite = player:GetSprite()

	if sprite:IsPlaying("Death")
		and sprite:GetFilename() == "gfx/characters/player_dorky.anm2"
		and sprite:IsEventTriggered("SpawnGoopy")
	then
		local goop = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_BLACK, 0, player.Position, Vector.Zero,
			player)
		goop:Update()
		goop.SpriteScale = Vector(player.SpriteScale.X * creepSize, player.SpriteScale.Y * creepSize)
		goop:GetData().DorkyDeathGoop = true
	end
end

---@param effect EntityEffect
function dorkyMisc:dorkyDeathGoopUpdate(effect)
	local data = effect:GetData()
	if not data.DorkyDeathGoop then return end
	local player = effect.SpawnerEntity:ToPlayer()
	local sprite = player:GetSprite()

	if not data.dorkyDeathGoopKill then
		for _, goops in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_BLACK)) do
			if goops:GetData().DorkyDeathGoop
				and goops.Position:Distance(effect.Position) == 0
				and GetPtrHash(goops) ~= GetPtrHash(effect)
			then
				effect:GetSprite():Play("BigBlood0" .. tostring(VeeHelper.RandomNum(0, 6)), true)
				effect.Color = Color(0, 0, 0, 1, 0, 0, 0)
				goops:Remove()
				data.dorkyDeathGoopKill = true
			end
		end
	end

	if sprite:IsPlaying("Death") and sprite:GetFrame() < 42 then
		effect.SpriteScale = effect.SpriteScale + Vector(creepGrowth, creepGrowth)
	end
end

---@param player EntityPlayer
function dorkyMisc:spiritDeathEffects(player)
	local sprite = player:GetSprite()
	if not sprite:IsPlaying("Death") or sprite:GetFilename() ~= "gfx/characters/player_spirit.anm2" then return end
	if sprite:IsEventTriggered("FuckingExplode") then
		local goop = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_BLACK, 0, player.Position, Vector.Zero,
			player)
		goop:Update()
		goop.SpriteScale = player.SpriteScale

		local explosion = Isaac.Spawn(EntityType.ENTITY_EFFECT, g.SPIRIT_DEATH_EXPLOSION, 0, player.Position, Vector.Zero,
			player)
		explosion:GetSprite().Scale = Vector(1.5, 1.5)
		explosion.SpriteScale = player.SpriteScale

		local poof = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector.Zero, player)
		poof:GetSprite().Scale = Vector(1.5, 1.5)
		poof.Color = Color(0, 0, 0)
		poof.SpriteScale = player.SpriteScale

		for _ = 1, 10 do
			local vel = Vector(5, 0):Rotated(VeeHelper.RandomNum(0, 359))
			local goopBits = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_PARTICLE, 0, player.Position, vel, player)
			goopBits.Color = Color(0, 0, 0)
			goopBits.SplatColor = Color(0, 0, 0)
			goopBits.SpriteScale = player.SpriteScale
		end

		SFXManager():Play(SoundEffect.SOUND_DEMON_HIT)

	elseif sprite:IsEventTriggered("DeathSound") then
		for _, gibs in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_PARTICLE, 0)) do
			if gibs.Position:Distance(player.Position) <= 25 then
				local c = gibs.Color
				if c.R ~= 0 and c.G ~= 0 and c.B ~= 0 then
					gibs:Remove()
				end
			end
		end
	end
end

---@param effect EntityEffect
function dorkyMisc:noDeadBodies(effect)
	local sprite = effect:GetSprite()

	if sprite:GetFilename() == "gfx/characters/player_dorky.anm2"
	or sprite:GetFilename() == "gfx/characters/player_spirit.anm2"
		and sprite:IsPlaying("Death")
	then
		effect:Remove()
	end
end

return dorkyMisc
