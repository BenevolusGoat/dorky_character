---Credit to Epiphany

local function getPrefix()
	if debug then
		local info = debug.getinfo(3)
		if info.func == DorkyMod.DebugLog or info.func == DorkyMod.DebugLogf then
			info = debug.getinfo(4)
		end
		local file = info.short_src
		file = file:match("^.+/(.+)$")
		if file then
			local funcName = info.name
			funcName = (funcName or tostring(info.func):gsub("^function: ", "f:")) .. ":" .. info.currentline
			return string.format("[%s:%s] ", file, info.currentline)
		end
	else
		return "[DorkyCharacter] "
	end
end

-- Prints a group of given strings/numbers to both console and log.txt.
-- If luadebug is on, the output is prefixed by name of current file
-- and function that called Log, as well as line Log was called from.
---@function
function DorkyMod:Log(...)
	local str = getPrefix()
	local args = { ... }
	for i = 1, #args do
		args[i] = tostring(args[i])
	end
	str = str .. table.concat(args, " ")
	print(str)
	Isaac.DebugString(str)
end

---@param str string
---@param ... any
function DorkyMod:Logf(str, ...)
	local str = getPrefix() .. string.format(str, ...)
	print(str)
	Isaac.DebugString(str)
end

---Equivalent to Eldritch:Log, but only prints if Mod.FLAGS.Debug is set to true.
---@function
function DorkyMod:DebugLog(...)
	if DorkyMod.FLAGS.Debug then
		DorkyMod:Log(...)
	end
end

function DorkyMod:DebugLogf(str, ...)
	if DorkyMod.FLAGS.Debug then
		DorkyMod:Logf(str, ...)
	end
end

---@function
function DorkyMod:Crash()
	Isaac.GetPlayer(0):AddNullCostume(-1) -- Crashes the game
end

DorkyMod.ShouldRenderID = false

function DorkyMod:RenderTypeVarSub()
	if not DorkyMod.ShouldRenderID then return end
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		local renderPos = Isaac.WorldToScreen(ent.Position)
		Isaac.RenderText(ent.Type .. ", " .. ent.Variant .. ", " .. ent.SubType, renderPos.X, renderPos.Y - 30, 1, 1, 1,
			1)
	end
end

DorkyMod:AddCallback(ModCallbacks.MC_POST_RENDER, DorkyMod.RenderTypeVarSub)
