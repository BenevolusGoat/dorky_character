--Full credit to Epiphany for this easy and flexible EID system

--luacheck: no max line length
-- Markdown guide https://github.com/wofsauge/External-Item-Descriptions/wiki
local Mod = DorkyMod
local DORKY_EID = {}

DorkyMod.EID_Support = DORKY_EID

if not EID then
	return
end

local hasDorky = false
local hasVoid = false

if EID.SpecialHeartPlayers then
	local black_heart_table = EID.SpecialHeartPlayers["Black"]
	for _, healthPlayerType in ipairs(black_heart_table) do
		if healthPlayerType == Mod.PLAYER_DORKY then
			hasDorky = true
		elseif healthPlayerType == Mod.PLAYER_DORKY_B then
			hasVoid = true
		end
		if hasDorky and hasVoid then break end
	end
	if not hasDorky then
		black_heart_table[#black_heart_table + 1] = Mod.PLAYER_DORKY
	end
	if not hasVoid then
		black_heart_table[#black_heart_table + 1] = Mod.PLAYER_DORKY_B
	end
end

if EID.CharacterToHeartType then
	EID.CharacterToHeartType[Mod.PLAYER_DORKY] = "Black"
	EID.CharacterToHeartType[Mod.PLAYER_DORKY_B] = "Black"
end

if EID.NoRedHeartsPlayerIDs then
	EID.NoRedHeartsPlayerIDs[Mod.PLAYER_DORKY] = true
	EID.NoRedHeartsPlayerIDs[Mod.PLAYER_DORKY_B] = true
end

---@param entity Entity
---@return EntityPlayer
function DORKY_EID:ClosestPlayerTo(entity) --This seems to error for some people sooo yeah
	if not entity then return EID.player end

	if EID.ClosestPlayerTo then
		return EID:ClosestPlayerTo(entity)
	else
		return EID.player
	end
end

--#region Icons

local player_icons = Sprite("gfx/ui/eid_dorky_players_icon.anm2", true)

local offsetX, offsetY = 2, 1

EID:addIcon("Dorky", "Dorky", 0, 18, 12, offsetX, offsetY, player_icons)
EID:addIcon("DorkyB", "DorkyB", 0, 18, 12, offsetX, offsetY, player_icons)

-- Assign Player Icons for Birthright
EID.InlineIcons["Player" .. Mod.PLAYER_DORKY] = EID.InlineIcons["Dorky"]
EID.InlineIcons["Player" .. Mod.PLAYER_DORKY_B] = EID.InlineIcons["DorkyB"]

--#endregion

--#region Helper functions

---@function
function DORKY_EID:GetTranslatedString(strTable)
	local lang = EID.getLanguage() or "en_us"
	local desc = strTable[lang] or strTable["en_us"] -- default to english description if there's no translation

	if desc == '' then                            --Default to english if the corresponding translation doesn't exist and is blank
		desc = strTable["en_us"];
	end

	return desc
end

--#endregion

--#region Changing mod's name and indicator for EID

local modName = DorkyMod.Name
EID._currentMod = modName
EID:setModIndicatorName(modName)
local customSprite = Sprite()
customSprite:Load("gfx/ui/eid_dorky_mod_icon.anm2", true)
EID:addIcon(modName .. " ModIcon", "Main", 0, 8, 8, 6, 6, customSprite)
EID:setModIndicatorIcon(modName .. " ModIcon")

--#endregion

--#region Dynamic Descriptions functions

local function containsFunction(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "function" then
			return true
		end
	end
	return false
end

local DynamicDescriptions = {
	[EntityType.ENTITY_PICKUP] = {
		[PickupVariant.PICKUP_COLLECTIBLE] = {},
		[PickupVariant.PICKUP_TAROTCARD] = {},
	}
}

local DD = {} ---@class DynamicDescriptions

function DD:ContainsFunction(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "function" then
			return true
		end
	end
	return false
end

---@generic K, V
---@param tab table<K,V>
---@param func fun(val: V): any
---@function
local function map(tab, func)
	local out = {}

	for k, v in pairs(tab) do
		out[k] = func(v)
	end

	return out
end

---@param descTab table
---@return {Func: fun(descObj: table): (string), AppendToEnd: boolean}
function DD:CreateCallback(descTab, appendToEnd)
	return {
		Func = function(descObj)
			return table.concat(
				map(
					descTab,
					function(val)
						if type(val) == "function" then
							local ret = val(descObj)
							if type(ret) == "table" then
								return table.concat(ret, "")
							elseif type(ret) == "string" then
								return ret
							else
								return ""
							end
						end

						return val or ""
					end
				),
				""
			)
		end,
		AppendToEnd = appendToEnd or false
	}
end

---@param modFunc { Func: function } | fun(descObj: table): string
---@param type integer
---@param variant integer
---@param subtype integer
---@param language string
function DD:SetCallback(modFunc, type, variant, subtype, language)
	if not DynamicDescriptions[type] then
		DynamicDescriptions[type] = {}
	end

	if not DynamicDescriptions[type][variant] then
		DynamicDescriptions[type][variant] = {}
	end

	if not DynamicDescriptions[type][variant][subtype] then
		DynamicDescriptions[type][variant][subtype] = {}
	end

	if not DynamicDescriptions[type][variant][subtype][language] then
		DynamicDescriptions[type][variant][subtype][language] = modFunc
	else
		error("Description modifier already exists for " .. type .. " " .. variant .. " " .. subtype .. " " .. language,
			2)
	end
end

---@param type integer
---@param variant integer
---@param subtype integer
---@param language string
---@return {Func: fun(descObj: table): (string?), AppendToEnd: boolean}?
function DD:GetCallback(type, variant, subtype, language)
	if not DynamicDescriptions[type] then
		return nil
	end

	if not DynamicDescriptions[type][variant] then
		return nil
	end

	if not DynamicDescriptions[type][variant][subtype] then
		return nil
	end

	if not DynamicDescriptions[type][variant][subtype][language] then
		return DynamicDescriptions[type][variant][subtype]
			["en_us"] -- fallback to english if no translation is available
	end

	return DynamicDescriptions[type][variant][subtype][language]
end

-- concat all subsequent string elements of a dynamic description
-- into one string so we have to concat less stuff at runtime
--
-- this is very much a micro optimization but at worst it does nothing
---@param desc (string | function)[] | function
---@return (string | function)[]
function DD:MakeMinimizedDescription(desc)
	if type(desc) == "function" then
		return { desc }
	end

	local out = {}
	local builder = {}

	for _, strOrFunc in ipairs(desc) do
		if type(strOrFunc) == "string" then
			builder[#builder + 1] = strOrFunc
		elseif type(strOrFunc) == "function" then
			out[#out + 1] = table.concat(builder, "")
			builder = {}
			out[#out + 1] = strOrFunc
		end
	end

	out[#out + 1] = table.concat(builder, "")

	return out
end

---@param desc (string | function)[] | function
---@return boolean
function DD:IsValidDescription(desc)
	if type(desc) == "function" then
		return true
	elseif type(desc) == "table" then
		for _, val in ipairs(desc) do
			if type(val) ~= "string" and type(val) ~= "function" then
				return false
			end
		end
	end

	return true
end

DORKY_EID.DynamicDescriptions = DD

--#endregion

local characters = {
	[Mod.PLAYER_DORKY] = {
		en_us = {
			Name = "Dorky",
			Description = {
				"#Can't have Red Hearts",
				"#{{BlackHeart}} Health ups grant Black Hearts"
			}
		}
	},
	[Mod.PLAYER_DORKY_B] = {
		en_us = {
			Name = "The Void",
			Description = {
				"#Can't have any hearts except for Black and Gold Hearts",
				"#{{BlackHeart}} Health ups grant Black Hearts",
			}
		}
	},
}

for playerId, charDescData in pairs(characters) do
	for lang, descData in pairs(charDescData) do
		if not DD:IsValidDescription(descData.Description) or containsFunction(descData.Description) then
			Mod:Log("Invalid character description for " .. descData.Name, "Language: " .. lang)
		else
			EID:addCharacterInfo(playerId, table.concat(descData.Description, ""), descData.Name, lang)
		end
	end
end

local birthrights = {
	[Mod.PLAYER_DORKY] = {
		en_us = {
			Name = "Dorky",
			Description = {
				"Grappled enemies will bounce off of Dorky up to 3 times before being released"
			}
		}
	},
	[Mod.PLAYER_DORKY_B] = {
		en_us = {
			Name = "The Void",
			Description = {
				"Doubles the health gain from {{Collectible" .. Mod.COLLECTIBLE_SOUL_DRAIN .. "}} Soul Drain"
			}
		}
	},
}

for playerId, brDescData in pairs(birthrights) do
	for lang, descData in pairs(brDescData) do
		if not DD:IsValidDescription(descData.Description) or containsFunction(descData.Description) then
			Mod:Log("Invalid birthright description for " .. descData.Name, "Language: " .. lang)
		else
			EID:addBirthright(playerId, table.concat(descData.Description, ""), descData.Name, lang)
		end
	end
end

local items = {
	[Mod.COLLECTIBLE_TONGUE_GRAPPLE] = {
		en_us = {
			Name = "Tongue Grapple",
			Description = {
				"Sends out an extendable tongue from Isaac that latches onto an enemy",
				"#The enemy will be pulled towards Isaac and then knocked back, taking 5 + Isaac's damage"
			}
		}
	},
	[Mod.COLLECTIBLE_SOUL_DRAIN] = {
		en_us = {
			Name = "Soul Drain",
			Description = {
				"Using the item and firing in a direction throws a black spike that sticks to Isaac",
				"#The spike will stick to an enemy, dealing x1.5 Isaac's damage and slowly damage them over time for x2 Isaac's damage + 1.5",
				"#Damage dealt will fill a bar that grants +1 {{BlackHeart}} Black Heart upon being filled"
			}
		}
	},
}

for id, collectibleDescData in pairs(items) do
	for language, descData in pairs(collectibleDescData) do
		if language:match('^_') then goto continue end -- skip helper private fields
		local name = descData.Name
		local description = descData.Description

		if not DD:IsValidDescription(description) then
			Mod:Log("Invalid collectible description for " .. name .. " (" .. id .. ")", "Language: " .. language)
			goto continue
		end

		local minimized = DD:MakeMinimizedDescription(description)

		if not containsFunction(minimized) and not collectibleDescData._AppendToEnd then
			EID:addCollectible(id, table.concat(minimized, ""), name, language)
		else
			-- don't add descriptions for vanilla items that already have one
			if not EID.descriptions[language].collectibles[id] then
				EID:addCollectible(id, "", name, language) -- description only contains name/language, the actual description is generated at runtime
			end

			DD:SetCallback(DD:CreateCallback(minimized, collectibleDescData._AppendToEnd), EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE, id, language)
		end

		::continue::
	end
end

EID:addDescriptionModifier(
	modName .. " Dynamic Description Manager",
	-- condition
	---@param descObj EID_DescObj
	function(descObj)
		local subtype = descObj.ObjSubType
		if descObj.ObjVariant == PickupVariant.PICKUP_TRINKET then
			subtype = subtype & ~TrinketType.TRINKET_GOLDEN_FLAG
		elseif descObj.ObjVariant == PickupVariant.PICKUP_PILL then
			subtype = Mod.Game:GetItemPool():GetPillEffect(subtype, DORKY_EID:ClosestPlayerTo(descObj.Entity))
		end

		return DD:GetCallback(descObj.ObjType, descObj.ObjVariant, subtype, EID.getLanguage() or "en_us") ~= nil
	end,
	-- modifier
	function(descObj)
		local subtype = descObj.ObjSubType
		if descObj.ObjVariant == PickupVariant.PICKUP_TRINKET then
			subtype = subtype & ~TrinketType.TRINKET_GOLDEN_FLAG
		elseif descObj.ObjVariant == PickupVariant.PICKUP_PILL then
			subtype = Mod.Game:GetItemPool():GetPillEffect(subtype, DORKY_EID:ClosestPlayerTo(descObj.Entity))
		end

		local callback = DD:GetCallback(descObj.ObjType, descObj.ObjVariant, subtype, EID.getLanguage() or "en_us")
		local descString = callback.Func(descObj) ---@diagnostic disable-line: need-check-nil

		if callback.AppendToEnd then ---@diagnostic disable-line: need-check-nil
			descObj.Description = descObj.Description .. descString
		else
			descObj.Description = descString .. descObj.Description
		end

		return descObj
	end
)

EID._currentMod = modName .. "_reserved" -- to prevent other mods overriding  mod items
