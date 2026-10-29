-- Mini-Roblox-Engine zum Testen der Spielskripte außerhalb von Roblox Studio.
-- Bildet die genutzten APIs nach (Instanzen, Events, DataStores, Käufe, task-Scheduler mit virtueller Zeit).
-- Lesen einer unbekannten Eigenschaft wirft einen Fehler – so fallen Tippfehler und nil-Zugriffe auf.

H = { now = 0, errors = {}, warnings = {}, prompts = {}, ownedPasses = {}, datastore = {}, ordered = {}, closeHandlers = {}, renderSteps = {} }
local START_TIME = 1760000000

---------------------------------------------------------------------
-- Scheduler
---------------------------------------------------------------------
local queue = {}
local function report(err, co)
	local trace = co and debug.traceback(co, tostring(err)) or tostring(err)
	table.insert(H.errors, trace)
end

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		report(err, co)
	end
end

local function schedule(co, at, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end

task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(co, H.now, ...)
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	schedule(co, H.now + (t or 0), ...)
	return co
end
function task.wait(t)
	t = t or 0.03
	local co, isMain = coroutine.running()
	assert(not isMain, "task.wait called outside a coroutine")
	schedule(co, H.now + t)
	coroutine.yield()
	return t
end

os.clock = function()
	return H.now
end
local realTime = os.time
os.time = function(t)
	if t then
		return realTime(t)
	end
	return START_TIME + math.floor(H.now)
end
tick = function()
	return START_TIME + H.now
end
math.clamp = function(v, a, b)
	assert(type(v) == "number" and type(a) == "number" and type(b) == "number", "math.clamp: number expected")
	assert(a <= b, "math.clamp: max must be >= min")
	return math.max(a, math.min(b, v))
end
warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	table.insert(H.warnings, table.concat(parts, " "))
end

---------------------------------------------------------------------
-- Signale
---------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect expects a function")
	local conn = { Connected = true, fn = fn }
	function conn.Disconnect(c)
		c.Connected = false
	end
	table.insert(self.handlers, conn)
	return conn
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	local list = {}
	for i, c in ipairs(self.handlers) do
		list[i] = c
	end
	for _, c in ipairs(list) do
		if c.Connected then
			task.spawn(c.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in ipairs(waiting) do
		resume(co, ...)
	end
end
function Signal:Wait()
	table.insert(self.waiting, (coroutine.running()))
	return coroutine.yield()
end

---------------------------------------------------------------------
-- Datentypen
---------------------------------------------------------------------
local function typed(kind, mt)
	mt.__type = kind
	return mt
end

Vector3 = {}
local V3 = typed("Vector3", {})
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
local function isV3(v)
	return getmetatable(v) == V3
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	assert(isV3(a) and isV3(b), "Vector3 + expects two Vector3")
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	assert(isV3(a) and isV3(b), "Vector3 - expects two Vector3")
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	if type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	assert(isV3(a) and isV3(b), "invalid Vector3 multiplication")
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end
function Vector3.new(x, y, z)
	for _, n in ipairs({ x or 0, y or 0, z or 0 }) do
		assert(type(n) == "number", "Vector3.new expects numbers")
	end
	return v3(x, y, z)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)

Vector2 = {}
local V2 = typed("Vector2", { __index = function(_, k)
	error("Vector2 has no member " .. tostring(k), 2)
end })
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end

-- CFrame mit 3x3-Rotationsmatrix (Zeilen)
CFrame = {}
local CF = typed("CFrame", {})
local function mat(a, b)
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local function rotate(m, v)
	return v3(m[1][1] * v.X + m[1][2] * v.Y + m[1][3] * v.Z, m[2][1] * v.X + m[2][2] * v.Y + m[2][3] * v.Z, m[3][1] * v.X + m[3][2] * v.Y + m[3][3] * v.Z)
end
local IDENT = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
local function cf(p, r)
	return setmetatable({ p = p, r = r or IDENT }, CF)
end
local function isCF(c)
	return getmetatable(c) == CF
end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return rawget(c, "p")
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	elseif k == "RightVector" then
		return v3(c.r[1][1], c.r[2][1], c.r[3][1])
	elseif k == "UpVector" then
		return v3(c.r[1][2], c.r[2][2], c.r[3][2])
	elseif k == "LookVector" then
		return v3(-c.r[1][3], -c.r[2][3], -c.r[3][3])
	elseif k == "Inverse" then
		return function(self)
			local t = { { self.r[1][1], self.r[2][1], self.r[3][1] }, { self.r[1][2], self.r[2][2], self.r[3][2] }, { self.r[1][3], self.r[2][3], self.r[3][3] } }
			return cf(-rotate(t, self.p), t)
		end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	assert(isCF(a), "CFrame * : left side must be a CFrame")
	if isCF(b) then
		return cf(a.p + rotate(a.r, b.p), mat(a.r, b.r))
	elseif isV3(b) then
		return a.p + rotate(a.r, b)
	end
	error("CFrame * : invalid right side", 2)
end
CF.__add = function(a, b)
	assert(isCF(a) and isV3(b), "CFrame + expects CFrame + Vector3")
	return cf(a.p + b, a.r)
end
CF.__sub = function(a, b)
	assert(isCF(a) and isV3(b), "CFrame - expects CFrame - Vector3")
	return cf(a.p - b, a.r)
end
CF.__tostring = function(c)
	return "CFrame(" .. tostring(c.p) .. ")"
end
function CFrame.new(x, y, z)
	if x == nil then
		return cf(v3(0, 0, 0))
	end
	if isV3(x) then
		assert(y == nil, "CFrame.new(Vector3, lookAt) not supported in harness")
		return cf(x)
	end
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "CFrame.new expects numbers or a Vector3")
	return cf(v3(x, y, z))
end
function CFrame.Angles(rx, ry, rz)
	assert(type(rx) == "number" and type(ry) == "number" and type(rz) == "number", "CFrame.Angles expects 3 numbers")
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local Y = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local Z = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	return cf(v3(0, 0, 0), mat(mat(X, Y), Z))
end
CFrame.identity = cf(v3(0, 0, 0))

Color3 = {}
local C3 = typed("Color3", { __index = function(_, k)
	error("Color3 has no member " .. tostring(k), 2)
end })
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	for _, n in ipairs({ r, g, b }) do
		assert(type(n) == "number" and n >= 0 and n <= 255, "Color3.fromRGB expects 0-255")
	end
	return Color3.new(r / 255, g / 255, b / 255)
end

UDim = {}
local UD = typed("UDim", {})
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
UDim2 = {}
local UD2 = typed("UDim2", {})
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2)
end
UD2.__add = function(a, b)
	return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UD2.__sub = function(a, b)
	return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
end
function UDim2.new(xs, xo, ys, yo)
	return udim2(xs or 0, xo or 0, ys or 0, yo or 0)
end
function UDim2.fromOffset(x, y)
	return udim2(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
	return udim2(x or 0, 0, y or 0, 0)
end

local function opaque(kind)
	return function(...)
		return setmetatable({ args = { ... } }, typed(kind, {}))
	end
end
NumberSequence = { new = opaque("NumberSequence") }
ColorSequence = { new = opaque("ColorSequence") }
NumberRange = { new = opaque("NumberRange") }
TweenInfo = { new = opaque("TweenInfo") }
RaycastParams = {
	new = function()
		return { FilterType = nil, FilterDescendantsInstances = {} }
	end,
}

Random = {}
function Random.new()
	local r = {}
	function r.NextNumber(_, a, b)
		a, b = a or 0, b or 1
		return a + math.random() * (b - a)
	end
	function r.NextInteger(_, a, b)
		assert(a <= b, "NextInteger: min > max")
		return math.random(a, b)
	end
	return r
end

-- Enums: jedes Enum.X.Y ist ein eindeutiges Objekt
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumType)
		enumCache[enumType] = enumCache[enumType] or setmetatable({}, {
			__index = function(t, item)
				local e = setmetatable({ Name = item, EnumType = enumType, Value = 0 }, { __tostring = function()
					return "Enum." .. enumType .. "." .. item
				end })
				rawset(t, item, e)
				return e
			end,
		})
		return enumCache[enumType]
	end,
})
H.usedEnums = {}
setmetatable(enumCache, {
	__newindex = function(t, k, v)
		rawset(t, k, v)
		-- Zugriffe protokollieren
		setmetatable(v, {
			__index = function(tt, item)
				H.usedEnums[k .. "." .. item] = true
				local e = setmetatable({ Name = item, EnumType = k, Value = 0 }, { __tostring = function()
					return "Enum." .. k .. "." .. item
				end })
				rawset(tt, item, e)
				return e
			end,
		})
	end,
})

---------------------------------------------------------------------
-- JSON (verhält sich wie Roblox: gemischte Tabellen sind nicht speicherbar)
---------------------------------------------------------------------
local json = {}
local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		n = n + 1
	end
	for i = 1, n do
		if t[i] == nil then
			return false
		end
	end
	return true
end
function json.encode(v)
	local tv = type(v)
	if tv == "nil" then
		return "null"
	elseif tv == "boolean" then
		return tostring(v)
	elseif tv == "number" then
		assert(v == v and v ~= math.huge and v ~= -math.huge, "cannot store NaN/inf")
		if math.type and math.type(v) == "float" and v == math.floor(v) and math.abs(v) < 2 ^ 53 then
			return string.format("%d", v)
		end
		return string.format("%.17g", v)
	elseif tv == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			return string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif tv == "table" then
		assert(getmetatable(v) == nil, "cannot store Roblox datatypes / objects in JSON")
		if isArray(v) then
			local parts = {}
			for i = 1, #v do
				parts[i] = json.encode(v[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, val in pairs(v) do
			assert(type(k) == "string", "cannot store tables with mixed / non-string keys")
			table.insert(parts, json.encode(k) .. ":" .. json.encode(val))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("cannot store value of type " .. tv)
end
function json.decode(s)
	local pos = 1
	local function ws()
		pos = s:find("[^%s]", pos) or #s + 1
	end
	local value
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == '"' then
				pos = pos + 1
				return table.concat(out)
			elseif c == "\\" then
				local n = s:sub(pos + 1, pos + 1)
				if n == "u" then
					table.insert(out, utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)))
					pos = pos + 6
				else
					local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
					table.insert(out, map[n] or n)
					pos = pos + 2
				end
			else
				table.insert(out, c)
				pos = pos + 1
			end
		end
	end
	function value()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "}" then
				pos = pos + 1
				return t
			end
			while true do
				ws()
				local k = str()
				ws()
				pos = pos + 1 -- :
				t[k] = value()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then
					return t
				end
			end
		elseif c == "[" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "]" then
				pos = pos + 1
				return t
			end
			while true do
				table.insert(t, value())
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then
					return t
				end
			end
		elseif c == '"' then
			return str()
		elseif s:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif s:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		elseif s:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		end
		local num = s:match("^-?[%d%.eE+-]+", pos)
		assert(num, "JSON parse error at " .. pos)
		pos = pos + #num
		return tonumber(num)
	end
	return value()
end
H.json = json

---------------------------------------------------------------------
-- Instanzen
---------------------------------------------------------------------
local INHERITS = {
	Part = { "BasePart", "PVInstance" }, SpawnLocation = { "Part", "BasePart", "PVInstance" }, TrussPart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" }, Workspace = { "Model", "PVInstance" },
	TextLabel = { "GuiObject", "GuiBase2d" }, TextButton = { "GuiButton", "GuiObject", "GuiBase2d" }, Frame = { "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" }, ScreenGui = { "LayerCollector", "GuiBase2d" }, BillboardGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "LayerCollector", "GuiBase2d" }, IntValue = { "ValueBase" }, NumberValue = { "ValueBase" }, StringValue = { "ValueBase" },
	BoolValue = { "ValueBase" }, Color3Value = { "ValueBase" }, RemoteEvent = {}, Player = {}, Humanoid = {},
}

local NILV = {} -- Standardwert "nil"
local DEFAULTS = {
	Name = function(o)
		return o.__props.ClassName
	end,
	Parent = NILV, Archivable = true, Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Transparency = 0,
	Size = function()
		return v3(4, 1, 2)
	end,
	CFrame = function()
		return CFrame.new()
	end,
	AssemblyLinearVelocity = function()
		return v3(0, 0, 0)
	end,
	Enabled = true, Visible = true, Text = "", Rotation = 0, TextTransparency = 0, TextStrokeTransparency = 1, BackgroundTransparency = 0,
	Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, Character = NILV, RespawnLocation = NILV, Adornee = NILV, PrimaryPart = NILV, LocalPlayer = NILV,
	ActionText = "", ObjectText = "", HoldDuration = 0, MaxActivationDistance = 10,
	ClockTime = 14, Gravity = 196.2, FallenPartsDestroyHeight = -500, ResetOnSpawn = true,
}
local VALUE_DEFAULTS = { IntValue = 0, NumberValue = 0, StringValue = "", BoolValue = false, Color3Value = Color3.new() }
local EVENTS = {
	Touched = true, Changed = true, Triggered = true, MouseButton1Click = true, OnServerEvent = true, OnClientEvent = true, Died = true,
	PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, RenderStepped = true, Stepped = true, CharacterAdded = true,
	PromptGamePassPurchaseFinished = true, ChildAdded = true, ChildRemoved = true, Hit = true, Activated = true,
}

local Inst = {}
local InstMeta = { __type = "Instance" }
local services = {}
H.allInstances = setmetatable({}, { __mode = "k" })

local function newInstance(className)
	local o = setmetatable({ __props = { ClassName = className, Name = className }, __children = {}, __attrs = {}, __signals = {}, __attrSignals = {}, __propSignals = {}, __methods = {} }, InstMeta)
	if VALUE_DEFAULTS[className] ~= nil then
		o.__props.Value = VALUE_DEFAULTS[className]
	end
	H.allInstances[o] = true
	return o
end
H.newInstance = newInstance

local function signalFor(o, name)
	o.__signals[name] = o.__signals[name] or newSignal()
	return o.__signals[name]
end

InstMeta.__index = function(o, k)
	if type(k) == "string" and k:sub(1, 2) == "__" then
		return nil -- interne Felder
	end
	local m = o.__methods[k] or Inst[k]
	if m then
		return m
	end
	local props = o.__props
	if k == "Position" then
		return (props.CFrame or CFrame.new()).p
	end
	local v = props[k]
	if v ~= nil then
		return v
	end
	for _, child in ipairs(o.__children) do
		if child.__props.Name == k then
			return child
		end
	end
	if EVENTS[k] then
		return signalFor(o, k)
	end
	local d = DEFAULTS[k]
	if d ~= nil then
		if type(d) == "function" then
			return d(o)
		end
		if d == NILV then
			return nil
		end
		return d
	end
	error(tostring(k) .. " is not a valid member of " .. props.ClassName .. ' "' .. tostring(props.Name or props.ClassName) .. '"', 2)
end

local function setParent(o, parent)
	local old = o.__props.Parent
	if old == parent then
		return
	end
	if o.__destroyed then
		error("The Parent property of " .. tostring(o.__props.Name) .. " is locked (destroyed)", 3)
	end
	if old then
		for i, c in ipairs(old.__children) do
			if c == o then
				table.remove(old.__children, i)
				break
			end
		end
		if old.__signals.ChildRemoved then
			old.__signals.ChildRemoved:Fire(o)
		end
	end
	o.__props.Parent = parent or nil
	if parent then
		table.insert(parent.__children, o)
		if parent.__signals.ChildAdded then
			parent.__signals.ChildAdded:Fire(o)
		end
	end
end

InstMeta.__newindex = function(o, k, v)
	if type(k) == "string" and k:sub(1, 2) == "__" then
		return rawset(o, k, v)
	end
	local props = o.__props
	if k == "Parent" then
		return setParent(o, v)
	elseif k == "Position" then
		local old = props.CFrame or CFrame.new()
		props.CFrame = cf(v, old.r)
		return
	elseif k == "ClassName" then
		error("ClassName is read-only", 2)
	end
	if k == "Health" and o.__props.ClassName == "Humanoid" then
		local max = props.MaxHealth or 100
		v = math.max(0, math.min(v, max))
		props.Health = v
		if v <= 0 and not o.__dead then
			o.__dead = true
			signalFor(o, "Died"):Fire()
		end
		return
	end
	if k == "Shape" or k == "Size" then
		-- wie Roblox: Kugeln haben immer gleich lange Seiten
		props[k] = v
		local shape = props.Shape
		if shape and shape.Name == "Ball" and props.Size then
			local s = props.Size
			local m = math.min(s.X, s.Y, s.Z)
			props.Size = v3(m, m, m)
		end
	else
		props[k] = v
	end
	if k == "Value" and o.__signals.Changed then
		o.__signals.Changed:Fire(v)
	end
	if o.__propSignals[k] then
		o.__propSignals[k]:Fire()
	end
end
InstMeta.__tostring = function(o)
	return tostring(o.__props.Name or o.__props.ClassName)
end

function Inst.IsA(o, cls)
	local own = o.__props.ClassName
	if own == cls or cls == "Instance" then
		return true
	end
	for _, c in ipairs(INHERITS[own] or {}) do
		if c == cls then
			return true
		end
	end
	return false
end
function Inst.GetChildren(o)
	local t = {}
	for i, c in ipairs(o.__children) do
		t[i] = c
	end
	return t
end
function Inst.GetDescendants(o)
	local t = {}
	local function walk(x)
		for _, c in ipairs(x.__children) do
			table.insert(t, c)
			walk(c)
		end
	end
	walk(o)
	return t
end
function Inst.FindFirstChild(o, name, recursive)
	for _, c in ipairs(o.__children) do
		if c.__props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(o.__children) do
			local f = Inst.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst.FindFirstChildOfClass(o, cls)
	for _, c in ipairs(o.__children) do
		if c.__props.ClassName == cls then
			return c
		end
	end
	return nil
end
function Inst.FindFirstChildWhichIsA(o, cls)
	for _, c in ipairs(o.__children) do
		if Inst.IsA(c, cls) then
			return c
		end
	end
	return nil
end
function Inst.FindFirstAncestorOfClass(o, cls)
	local p = o.__props.Parent
	while p do
		if p.__props.ClassName == cls then
			return p
		end
		p = p.__props.Parent
	end
	return nil
end
function Inst.IsDescendantOf(o, anc)
	local p = o.__props.Parent
	while p do
		if p == anc then
			return true
		end
		p = p.__props.Parent
	end
	return false
end
function Inst.WaitForChild(o, name, timeout)
	local deadline = H.now + (timeout or 10)
	while true do
		local c = Inst.FindFirstChild(o, name)
		if c then
			return c
		end
		if H.now >= deadline then
			if not timeout then
				warn("Infinite yield possible on " .. tostring(o) .. ":WaitForChild(\"" .. name .. "\")")
				table.insert(H.errors, "WaitForChild never found '" .. name .. "' under " .. tostring(o))
				coroutine.yield() -- bleibt hängen wie in Roblox
			end
			return nil
		end
		task.wait(0.1)
	end
end
function Inst.Destroy(o)
	for _, c in ipairs(Inst.GetChildren(o)) do
		Inst.Destroy(c)
	end
	if o.__props.Parent then
		setParent(o, nil)
	end
	o.__destroyed = true
	for _, s in pairs(o.__signals) do
		for _, c in ipairs(s.handlers) do
			c.Connected = false
		end
	end
end
function Inst.ClearAllChildren(o)
	for _, c in ipairs(Inst.GetChildren(o)) do
		Inst.Destroy(c)
	end
end
function Inst.SetAttribute(o, k, v)
	local t = type(v)
	assert(v == nil or t == "number" or t == "string" or t == "boolean" or (t == "table" and getmetatable(v) and (getmetatable(v).__type == "Color3" or getmetatable(v).__type == "Vector3")), "SetAttribute: unsupported attribute type " .. t .. " for " .. k)
	local old = o.__attrs[k]
	o.__attrs[k] = v
	if old ~= v and o.__attrSignals[k] then
		o.__attrSignals[k]:Fire()
	end
end
function Inst.GetAttribute(o, k)
	return o.__attrs[k]
end
function Inst.GetAttributeChangedSignal(o, k)
	o.__attrSignals[k] = o.__attrSignals[k] or newSignal()
	return o.__attrSignals[k]
end
function Inst.GetPropertyChangedSignal(o, k)
	o.__propSignals[k] = o.__propSignals[k] or newSignal()
	return o.__propSignals[k]
end
function Inst.PivotTo(o, c)
	assert(isCF(c), "PivotTo expects a CFrame")
	if o.__props.ClassName == "Model" then
		local root = Inst.FindFirstChild(o, "HumanoidRootPart") or o.__props.PrimaryPart
		if root then
			root.CFrame = c
		end
	else
		o.CFrame = c
	end
end
function Inst.TakeDamage(o, amount)
	assert(o.__props.ClassName == "Humanoid", "TakeDamage is only valid on Humanoid")
	assert(type(amount) == "number", "TakeDamage expects a number")
	o.Health = o.Health - amount
end
function Inst.GetMass(o)
	local s = o.Size
	return s.X * s.Y * s.Z * 0.7
end
function Inst.SetNetworkOwner(o, owner)
	assert(not o.Anchored, "SetNetworkOwner: cannot be called on anchored parts")
	assert(o:IsDescendantOf(services.Workspace), "SetNetworkOwner: part must be in workspace")
	o.__owner = owner
end

Instance = {}
local CREATABLE = {
	Part = true, SpawnLocation = true, TrussPart = true, Model = true, Folder = true, Configuration = true, RemoteEvent = true,
	IntValue = true, NumberValue = true, StringValue = true, BoolValue = true, Color3Value = true, ScreenGui = true, Frame = true,
	TextLabel = true, TextButton = true, ScrollingFrame = true, UICorner = true, UIStroke = true, UIListLayout = true,
	BillboardGui = true, SurfaceGui = true, ProximityPrompt = true, SpecialMesh = true, PointLight = true, ParticleEmitter = true,
	Attachment = true, VectorForce = true, Explosion = true, Fire = true, Smoke = true, Humanoid = true, Camera = true,
}
H.createdClasses = {}
function Instance.new(className, parent)
	assert(CREATABLE[className], "Instance.new: unknown/unsupported class '" .. tostring(className) .. "'")
	H.createdClasses[className] = true
	local o = newInstance(className)
	if className == "Explosion" then
		o.__methods = {}
	end
	if parent then
		o.Parent = parent
	end
	return o
end

---------------------------------------------------------------------
-- Services
---------------------------------------------------------------------
game = newInstance("DataModel")
game.Name = "Game"
local function service(name)
	local s = newInstance(name)
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end
workspace = service("Workspace")
local camera = newInstance("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
function workspace.__methods.Raycast()
	return nil
end
function workspace.__methods.GetPartsInPart()
	return {}
end
local Players = service("Players")
local ReplicatedStorage = service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
local Lighting = service("Lighting")
Lighting.ClockTime = 14
local RunService = service("RunService")
local DataStoreService = service("DataStoreService")
local MarketplaceService = service("MarketplaceService")
local HttpService = service("HttpService")
local Debris = service("Debris")
local TweenService = service("TweenService")
service("StarterPlayer")

function game.__methods.GetService(_, name)
	return services[name] or error("Unknown service " .. tostring(name))
end
function game.__methods.BindToClose(_, fn)
	table.insert(H.closeHandlers, fn)
end

function RunService.__methods.BindToRenderStep(_, name, prio, fn)
	assert(type(name) == "string" and type(prio) == "number" and type(fn) == "function", "BindToRenderStep: bad arguments")
	H.renderSteps[name] = fn
end
function RunService.__methods.IsServer()
	return true
end

function Debris.__methods.AddItem(_, obj, t)
	task.delay(t or 10, function()
		if not obj.__destroyed then
			obj:Destroy()
		end
	end)
end

function TweenService.__methods.Create(_, obj, info, props)
	assert(obj and info and type(props) == "table", "TweenService:Create bad arguments")
	return {
		Play = function()
			for k, v in pairs(props) do
				obj[k] = v
			end
		end,
		Cancel = function() end,
	}
end

function HttpService.__methods.JSONEncode(_, v)
	return json.encode(v)
end
function HttpService.__methods.JSONDecode(_, s)
	assert(type(s) == "string", "JSONDecode expects a string")
	return json.decode(s)
end

local function deepCopy(v)
	if v == nil then
		return nil
	end
	return json.decode(json.encode(v))
end
H.failDataStore = false
function DataStoreService.__methods.GetDataStore(_, name)
	assert(type(name) == "string", "GetDataStore expects a name")
	H.datastore[name] = H.datastore[name] or {}
	local data = H.datastore[name]
	return {
		GetAsync = function(_, key)
			task.wait(0.05)
			if H.failDataStore then
				error("DataStore request failed (simulated)")
			end
			return deepCopy(data[key])
		end,
		SetAsync = function(_, key, value)
			task.wait(0.05)
			if H.failDataStore then
				error("DataStore request failed (simulated)")
			end
			local encoded = json.encode(value)
			assert(#encoded < 4000000, "DataStore value too large")
			data[key] = json.decode(encoded)
		end,
	}
end
function DataStoreService.__methods.GetOrderedDataStore(_, name)
	H.ordered[name] = H.ordered[name] or {}
	local data = H.ordered[name]
	return {
		SetAsync = function(_, key, value)
			assert(type(value) == "number" and math.floor(value) == value, "OrderedDataStore values must be integers")
			data[key] = value
		end,
		GetSortedAsync = function(_, ascending, pageSize)
			local list = {}
			for k, v in pairs(data) do
				table.insert(list, { key = k, value = v })
			end
			table.sort(list, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #list) do
				page[i] = list[i]
			end
			return { GetCurrentPage = function()
				return page
			end }
		end,
	}
end

function MarketplaceService.__methods.UserOwnsGamePassAsync(_, userId, passId)
	assert(type(userId) == "number" and type(passId) == "number", "UserOwnsGamePassAsync bad args")
	return H.ownedPasses[userId .. ":" .. passId] == true
end
function MarketplaceService.__methods.PromptGamePassPurchase(_, player, id)
	assert(id ~= 0, "PromptGamePassPurchase called with id 0")
	table.insert(H.prompts, { kind = "pass", player = player, id = id })
end
function MarketplaceService.__methods.PromptProductPurchase(_, player, id)
	assert(id ~= 0, "PromptProductPurchase called with id 0")
	table.insert(H.prompts, { kind = "product", player = player, id = id })
end

function Players.__methods.GetPlayers()
	return Players:GetChildren()
end
function Players.__methods.GetPlayerByUserId(_, id)
	for _, p in ipairs(Players:GetChildren()) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
function Players.__methods.GetPlayerFromCharacter(_, model)
	for _, p in ipairs(Players:GetChildren()) do
		if p.Character == model and model ~= nil then
			return p
		end
	end
	return nil
end
function Players.__methods.GetNameFromUserIdAsync(_, id)
	return "User" .. tostring(id)
end

---------------------------------------------------------------------
-- Spieler & Charaktere
---------------------------------------------------------------------
local function spawnPoint(player)
	local spawnLoc = player.RespawnLocation
	if not spawnLoc then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.__props.ClassName == "SpawnLocation" then
				spawnLoc = d
				break
			end
		end
	end
	return spawnLoc and (spawnLoc.CFrame + v3(0, 4, 0)) or CFrame.new(0, 10, 0)
end

local function loadCharacter(player)
	local old = player.Character
	if old and not old.__destroyed then
		old:Destroy()
	end
	local model = newInstance("Model")
	model.Name = player.Name
	local humanoid = newInstance("Humanoid")
	humanoid.Parent = model
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Size = v3(2, 2, 1)
	root.CFrame = spawnPoint(player)
	root.Parent = model
	for _, n in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local p = newInstance("Part")
		p.Name = n
		p.Size = v3(1, 1, 1)
		p.Parent = model
	end
	model.PrimaryPart = root
	model.Parent = workspace
	player.Character = model
	humanoid.Died:Connect(function()
		task.delay(5, function()
			if player.Parent and player.Character == model then
				loadCharacter(player)
			end
		end)
	end)
	signalFor(player, "CharacterAdded"):Fire(model)
	return model
end

local nextUserId = 1000
function H.addPlayer(name)
	nextUserId = nextUserId + 1
	local p = newInstance("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = nextUserId
	local pg = newInstance("PlayerGui")
	pg.Name = "PlayerGui"
	pg.Parent = p
	function p.__methods.LoadCharacter(self)
		loadCharacter(self)
	end
	function p.__methods.Kick() end
	p.Parent = Players
	signalFor(Players, "PlayerAdded"):Fire(p)
	task.delay(0.2, function()
		if p.Parent then
			loadCharacter(p)
		end
	end)
	return p
end

function H.removePlayer(p)
	signalFor(Players, "PlayerRemoving"):Fire(p)
	H.run(0.5)
	if p.Character then
		p.Character:Destroy()
	end
	p.Parent = nil
	H.run(0.2)
end

function H.shutdown()
	for _, fn in ipairs(H.closeHandlers) do
		task.spawn(fn)
	end
	H.run(5)
end

-- Remotes: Client und Server teilen sich hier eine Welt
H.localPlayer = nil
local remoteMethods = {}
function remoteMethods.FireServer(r, ...)
	assert(H.localPlayer, "FireServer without LocalPlayer")
	signalFor(r, "OnServerEvent"):Fire(H.localPlayer, ...)
end
function remoteMethods.FireClient(r, player, ...)
	assert(player and player.__props.ClassName == "Player", "FireClient: first argument must be a Player")
	table.insert(H.clientMessages, { remote = r.Name, player = player, args = { ... } })
	if player == H.localPlayer then
		signalFor(r, "OnClientEvent"):Fire(...)
	end
end
function remoteMethods.FireAllClients(r, ...)
	table.insert(H.clientMessages, { remote = r.Name, all = true, args = { ... } })
	if H.localPlayer then
		signalFor(r, "OnClientEvent"):Fire(...)
	end
end
H.clientMessages = {}
local origNew = Instance.new
function Instance.new(className, parent)
	local o = origNew(className, parent)
	if className == "RemoteEvent" then
		for k, f in pairs(remoteMethods) do
			o.__methods[k] = f
		end
	end
	return o
end

---------------------------------------------------------------------
-- Zeit laufen lassen
---------------------------------------------------------------------
function H.run(seconds, dt)
	dt = dt or 0.1
	local target = H.now + seconds
	while H.now < target - 1e-9 do
		H.now = H.now + dt
		if RunService.__signals.Heartbeat then
			RunService.__signals.Heartbeat:Fire(dt)
		end
		if RunService.__signals.RenderStepped then
			RunService.__signals.RenderStepped:Fire(dt)
		end
		for _, fn in pairs(H.renderSteps) do
			task.spawn(fn, dt)
		end
		local guard = 0
		while true do
			table.sort(queue, function(a, b)
				return a.at < b.at
			end)
			local item = queue[1]
			if not item or item.at > H.now + 1e-9 then
				break
			end
			table.remove(queue, 1)
			if coroutine.status(item.co) == "suspended" then
				resume(item.co, table.unpack(item.args, 1, item.args.n))
			end
			guard = guard + 1
			if guard > 200000 then
				error("scheduler: too many resumes in one step (infinite loop?)")
			end
		end
	end
end

function H.runScript(key, asClientOf, patches)
	local src = assert(SRC[key], "no source for " .. key)
	for from, to in pairs(patches or {}) do
		local n
		src, n = src:gsub(from:gsub("%p", "%%%0"), (to:gsub("%%", "%%%%")))
		assert(n > 0, "patch not found in " .. key .. ": " .. from)
	end
	local f = assert(load(src, "@" .. key))
	if asClientOf then
		H.localPlayer = asClientOf
		Players.LocalPlayer = asClientOf
	end
	task.spawn(f)
end

-- Hilfen für Tests
function H.find(root, predicate)
	for _, d in ipairs(root:GetDescendants()) do
		if predicate(d) then
			return d
		end
	end
	return nil
end
function H.findAll(root, predicate)
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if predicate(d) then
			table.insert(out, d)
		end
	end
	return out
end
function H.touch(part, character)
	assert(part and part.__signals, "touch: part missing")
	local limb = character:FindFirstChild("Left Leg") or character.HumanoidRootPart
	signalFor(part, "Touched"):Fire(limb)
end
function H.fire(obj, eventName, ...)
	signalFor(obj, eventName):Fire(...)
end
function H.buyProduct(player, id)
	assert(id ~= 0, "product id not configured")
	local cb = MarketplaceService.ProcessReceipt
	assert(type(cb) == "function", "ProcessReceipt not set")
	local result
	task.spawn(function()
		result = cb({ PlayerId = player.UserId, ProductId = id, PurchaseId = tostring(math.random(1, 1e9)), CurrencySpent = 10 })
	end)
	H.run(0.5)
	return result
end
function H.buyPass(player, id)
	H.ownedPasses[player.UserId .. ":" .. id] = true
	signalFor(MarketplaceService, "PromptGamePassPurchaseFinished"):Fire(player, id, true)
	H.run(0.3)
end
function H.lastMessage(remoteName)
	for i = #H.clientMessages, 1, -1 do
		local m = H.clientMessages[i]
		if m.remote == remoteName then
			return m.args[1]
		end
	end
	return nil
end

local checks, failures = 0, {}
function H.check(cond, message)
	checks = checks + 1
	if not cond then
		table.insert(failures, message)
		print("  ✗ " .. message)
	else
		print("  ✓ " .. message)
	end
end
function H.finish()
	print(string.format("\n%d checks, %d failed, %d runtime errors", checks, #failures, #H.errors))
	for _, e in ipairs(H.errors) do
		print("RUNTIME ERROR:\n" .. e)
	end
	for _, w in ipairs(H.warnings) do
		print("warn: " .. w)
	end
	if #failures > 0 or #H.errors > 0 or #H.warnings > 0 then
		error("TEST FAILED", 0)
	end
end

return H
