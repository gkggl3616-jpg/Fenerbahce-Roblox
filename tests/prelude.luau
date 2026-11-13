--[[
	Sınama düzeneği: Roblox ortamının oyun mantığını koşturmaya yetecek kadar taklidi.
	Vector3, CFrame, Color3, Enum, Instance, task, servisler ve require.
	Gerçek Roblox değildir: çizim, fizik motoru ve arayüz yoktur. Amaç, saf mantığın
	(top fiziği, animasyon verisi, bot zekası, sunucu doğrulaması) hatasız çalıştığını görmektir.
]]

local readFile, compile = __readFile, __compile

---------------------------------------------------------------- Vector3
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return V3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V3[k]
end
function V3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__add = function(a, b)
	return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return V3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return V3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return V3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return V3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return V3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
function V3:Dot(b)
	return self.X * b.X + self.Y * b.Y + self.Z * b.Z
end
function V3:Cross(b)
	return V3.new(self.Y * b.Z - self.Z * b.Y, self.Z * b.X - self.X * b.Z, self.X * b.Y - self.Y * b.X)
end
function V3:Lerp(b, t)
	return V3.new(self.X + (b.X - self.X) * t, self.Y + (b.Y - self.Y) * t, self.Z + (b.Z - self.Z) * t)
end
Vector3 = { new = V3.new, zero = V3.new(0, 0, 0), one = V3.new(1, 1, 1) }

local V2 = {}
V2.__index = V2
V2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2.__div = function(a, b)
	return Vector2.new(a.X / b, a.Y / b)
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)

---------------------------------------------------------------- CFrame (3x3 dönüş + konum)
local CF = {}
local function mk(p, r)
	return setmetatable({ p = p, r = r }, CF)
end
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function mvec(r, v)
	return V3.new(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function rx(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
CF.__index = function(c, k)
	if k == "Position" then
		return c.p
	elseif k == "LookVector" then
		return V3.new(-c.r[3], -c.r[6], -c.r[9])
	elseif k == "RightVector" then
		return V3.new(c.r[1], c.r[4], c.r[7])
	elseif k == "UpVector" then
		return V3.new(c.r[2], c.r[5], c.r[8])
	elseif k == "X" then
		return c.p.X
	elseif k == "Y" then
		return c.p.Y
	elseif k == "Z" then
		return c.p.Z
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return mvec(a.r, b) + a.p
	end
	return mk(mvec(a.r, b.p) + a.p, mmul(a.r, b.r))
end
CF.__add = function(a, v)
	return mk(a.p + v, a.r)
end
CF.__sub = function(a, v)
	return mk(a.p - v, a.r)
end
function CF:VectorToWorldSpace(v)
	return mvec(self.r, v)
end
function CF:Inverse()
	local r = self.r
	local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	return mk(-mvec(t, self.p), t)
end
CFrame = {
	new = function(x, y, z)
		if x == nil then
			return mk(V3.new(0, 0, 0), ID)
		elseif type(x) == "table" then
			return mk(x, ID)
		end
		return mk(V3.new(x, y, z), ID)
	end,
	Angles = function(a, b, c)
		return mk(V3.new(0, 0, 0), mmul(mmul(rx(a), ry(b)), rz(c)))
	end,
	fromEulerAnglesYXZ = function(a, b, c)
		return mk(V3.new(0, 0, 0), mmul(mmul(ry(b), rx(a)), rz(c)))
	end,
	fromAxisAngle = function(axis, ang)
		local x, y, z = axis.X, axis.Y, axis.Z
		local c, s = math.cos(ang), math.sin(ang)
		local t = 1 - c
		return mk(V3.new(0, 0, 0), {
			t * x * x + c,
			t * x * y - s * z,
			t * x * z + s * y,
			t * x * y + s * z,
			t * y * y + c,
			t * y * z - s * x,
			t * x * z - s * y,
			t * y * z + s * x,
			t * z * z + c,
		})
	end,
	lookAt = function(from, to)
		local f = (to - from).Unit
		local right = f:Cross(V3.new(0, 1, 0))
		if right.Magnitude < 1e-6 then
			right = V3.new(1, 0, 0)
		else
			right = right.Unit
		end
		local up = right:Cross(f)
		return mk(from, { right.X, up.X, -f.X, right.Y, up.Y, -f.Y, right.Z, up.Z, -f.Z })
	end,
}

---------------------------------------------------------------- Basit veri tipleri
local C3 = {}
C3.__index = C3
function C3:Lerp(b, t)
	return Color3.new(self.R + (b.R - self.R) * t, self.G + (b.G - self.G) * t, self.B + (b.B - self.B) * t)
end
function C3:ToHex()
	return string.format("%02x%02x%02x", self.R * 255, self.G * 255, self.B * 255)
end
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
	end,
	fromRGB = function(r, g, b)
		return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, C3)
	end,
	fromHex = function(h)
		h = string.gsub(h, "#", "")
		assert(#h == 6 and tonumber(h, 16), "geçersiz hex")
		return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
	end,
}
local U2 = {}
U2.__index = U2
U2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
UDim = {
	new = function(s, o)
		return { Scale = s or 0, Offset = o or 0 }
	end,
}
UDim2 = {
	new = function(a, b, c, d)
		return setmetatable({ X = UDim.new(a, b), Y = UDim.new(c, d) }, U2)
	end,
	fromScale = function(a, b)
		return UDim2.new(a, 0, b, 0)
	end,
	fromOffset = function(a, b)
		return UDim2.new(0, a, 0, b)
	end,
}
local function plain(name)
	return {
		new = function(...)
			return { __type = name, args = { ... } }
		end,
	}
end
NumberSequence, ColorSequence, NumberRange, TweenInfo, Font, NumberSequenceKeypoint, ColorSequenceKeypoint =
	plain("NumberSequence"),
	plain("ColorSequence"),
	plain("NumberRange"),
	plain("TweenInfo"),
	plain("Font"),
	plain("NumberSequenceKeypoint"),
	plain("ColorSequenceKeypoint")

-- Enum: Enum.A.B her zaman aynı belirteci verir
Enum = setmetatable({}, {
	__index = function(t, group)
		local g = setmetatable({
			GetEnumItems = function()
				return {}
			end,
		}, {
			__index = function(gt, item)
				local token = { Name = item, Value = 0, EnumType = group }
				rawset(gt, item, token)
				return token
			end,
		})
		rawset(t, group, g)
		return g
	end,
})

---------------------------------------------------------------- Zaman ve görevler
local vtime = 0
local queue = {}
local realOs = os
os = setmetatable({
	clock = function()
		return vtime
	end,
	time = function()
		return 1000000 + math.floor(vtime)
	end,
}, { __index = realOs })

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		__fail(tostring(err) .. "\n" .. debug.traceback(co))
	end
end
task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
	end,
	delay = function(t, fn, ...)
		local args = { ... }
		table.insert(queue, { at = vtime + (t or 0), co = coroutine.create(function()
			fn(table.unpack(args))
		end) })
	end,
	wait = function(t)
		local co = coroutine.running()
		table.insert(queue, { at = vtime + (t or 0.03), co = co })
		coroutine.yield()
		return t or 0.03
	end,
}
wait = task.wait
-- Sanal zamanı ilerletir, zamanı gelen görevleri çalıştırır
function __advance(dt)
	vtime += dt
	local again = true
	while again do
		again = false
		for i, item in ipairs(queue) do
			if item.at <= vtime then
				table.remove(queue, i)
				resume(item.co)
				again = true
				break
			end
		end
	end
end
function __now()
	return vtime
end

---------------------------------------------------------------- Sinyal ve Instance
local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		local conn = {}
		function conn.Disconnect()
			local i = table.find(s.handlers, fn)
			if i then
				table.remove(s.handlers, i)
			end
		end
		return conn
	end
	function s:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn.Disconnect()
			fn(...)
		end)
		return conn
	end
	function s:Wait() end
	function s:Fire(...)
		for _, fn in ipairs(table.clone(self.handlers)) do
			task.spawn(fn, ...)
		end
	end
	return s
end
__Signal = Signal

local SIGNALS = {
	Completed = true,
	Changed = true,
	Activated = true,
	Touched = true,
	OnClientEvent = true,
	OnServerEvent = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	AncestryChanged = true,
	Stepped = true,
	RenderStepped = true,
	Heartbeat = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	Focused = true,
	FocusLost = true,
}
local PARTS = { Part = true, MeshPart = true, SpawnLocation = true }

local Inst = {}
local function newInstance(class)
	local o = { ClassName = class, Name = class, __children = {}, __attrs = {} }
	if PARTS[class] then
		o.Size = V3.new(2, 1, 4)
		o.CFrame = CFrame.new()
		o.AssemblyLinearVelocity = V3.new(0, 0, 0)
		o.Transparency = 0
	elseif class == "Motor6D" then
		o.Transform = CFrame.new()
	elseif
		string.find(class, "Label")
		or string.find(class, "Button")
		or string.find(class, "Frame")
		or string.find(class, "Box")
		or class == "CanvasGroup"
	then
		o.Position = UDim2.new(0, 0, 0, 0)
		o.Size = UDim2.new(0, 100, 0, 40)
		o.AbsolutePosition = Vector2.new(0, 0)
		o.AbsoluteSize = Vector2.new(200, 50)
		o.ZIndex = 1
		o.Visible = true
		o.Text = ""
	elseif class == "Humanoid" then
		o.HipHeight = 2
		o.WalkSpeed = 16
		o.Health = 100
		o.MoveDirection = V3.new(0, 0, 0)
		o.FloorMaterial = Enum.Material.Grass
	end
	return setmetatable(o, Inst)
end
Inst.__index = function(o, k)
	if k == "Parent" then
		return rawget(o, "__parent")
	end
	if k == "Position" and rawget(o, "CFrame") then
		return o.CFrame.Position
	end
	local m = Inst[k]
	if m ~= nil then
		return m
	end
	if SIGNALS[k] then
		local s = Signal()
		rawset(o, k, s)
		return s
	end
	for _, c in ipairs(o.__children) do
		if c.Name == k then
			return c
		end
	end
	return nil
end
Inst.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "__parent")
		if old then
			local i = table.find(old.__children, o)
			if i then
				table.remove(old.__children, i)
			end
		end
		rawset(o, "__parent", v)
		if v then
			table.insert(v.__children, o)
		end
	else
		rawset(o, k, v)
	end
end
function Inst:IsA(class)
	return self.ClassName == class
		or (class == "BasePart" and PARTS[self.ClassName])
		or (class == "GuiObject" and false)
		or (class == "LuaSourceContainer" and (self.ClassName == "Script" or self.ClassName == "LocalScript"))
		or class == "Instance"
end
function Inst:FindFirstChild(name)
	for _, c in ipairs(self.__children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function Inst:WaitForChild(name)
	return self:FindFirstChild(name)
end
function Inst:FindFirstChildOfClass(class)
	for _, c in ipairs(self.__children) do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function Inst:GetChildren()
	return table.clone(self.__children)
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(n.__children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:IsDescendantOf(other)
	local p = rawget(self, "__parent")
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "__parent")
	end
	return false
end
function Inst:Destroy()
	self.Parent = nil
end
function Inst:Clone()
	local c = newInstance(self.ClassName)
	for k, v in pairs(self) do
		if k ~= "__children" and k ~= "__parent" and k ~= "__attrs" and not (type(v) == "table" and v.handlers) then
			rawset(c, k, v)
		end
	end
	for k, v in pairs(self.__attrs) do
		c.__attrs[k] = v
	end
	for _, ch in ipairs(self.__children) do
		ch:Clone().Parent = c
	end
	return c
end
function Inst:SetAttribute(k, v)
	self.__attrs[k] = v
end
function Inst:GetAttribute(k)
	return self.__attrs[k]
end
function Inst:GetPropertyChangedSignal()
	return Signal()
end
-- Modeli kökünden taşır: bütün parçalar birlikte gider (gerçekteki gibi)
function Inst:PivotTo(cf)
	local hrp = self:FindFirstChild("HumanoidRootPart")
	if hrp then
		local delta = cf * hrp.CFrame:Inverse()
		for _, d in ipairs(self:GetDescendants()) do
			if PARTS[d.ClassName] and rawget(d, "CFrame") then
				d.CFrame = delta * d.CFrame
			end
		end
	end
end
-- Görünüm tanımı: sahte ortamda gövde değişmez, yalnızca çağrı kabul edilir
function Inst:ApplyDescription(desc)
	rawset(self, "__description", desc)
end
-- RemoteFunction: istemci çağrısı doğrudan sunucudaki işleve gider
function Inst:InvokeServer(...)
	local fn = rawget(self, "OnServerInvoke")
	if fn then
		return fn(__localPlayer, ...)
	end
	return nil
end
function Inst:GetAppliedDescription()
	return rawget(self, "__description") or newInstance("HumanoidDescription")
end
function Inst:Emit() end
function Inst:Play()
	local s = self
	local d = (s.__info and s.__info.args[1]) or 0
	task.delay(d, function()
		for k, v in pairs(s.__goal or {}) do
			s.__target[k] = v
		end
		s.Completed:Fire()
	end)
end
function Inst:Cancel() end
function Inst:Stop() end
function Inst:FireServer(...)
	self.OnServerEvent:Fire(__localPlayer, ...)
end
function Inst:FireClient(plr, ...)
	self.__sent = self.__sent or {}
	table.insert(self.__sent, { ... })
	self.OnClientEvent:Fire(...)
end
function Inst:FireAllClients(...)
	self.OnClientEvent:Fire(...)
end
function Inst:GetPlayingAnimationTracks()
	return {}
end
function Inst:ChangeState() end
function Inst:Kick(msg)
	self.__kicked = msg
end

Instance = { new = newInstance }

---------------------------------------------------------------- Servisler
local services = {}
local function service(name)
	if not services[name] then
		local s = newInstance(name)
		s.Name = name
		services[name] = s
	end
	return services[name]
end
game = newInstance("DataModel")
game.JobId = "test-job"
function game:GetService(name)
	return service(name)
end
function game:BindToClose() end
workspace = service("Workspace")
workspace.Gravity = 196.2
workspace.CurrentCamera = newInstance("Camera")
workspace.CurrentCamera.FieldOfView = 70
workspace.CurrentCamera.ViewportSize = Vector2.new(1600, 900)

local tween = service("TweenService")
function tween:Create(target, info, goal)
	local t = newInstance("Tween")
	t.__target, t.__info, t.__goal = target, info, goal
	return t
end
local run = service("RunService")
__isServer = false
function run:IsServer()
	return __isServer
end
function run:IsClient()
	return not __isServer
end
function run:IsStudio()
	return true
end
function run:BindToRenderStep() end
function run:UnbindFromRenderStep() end

local players = service("Players")
__localPlayer = newInstance("Player")
__localPlayer.Name = "Tester"
__localPlayer.UserId = 4242
__localPlayer.Parent = players
players.LocalPlayer = __localPlayer
function players:CreateHumanoidModelFromDescription()
	return __makeRig("Rig")
end
function players:GetPlayers()
	return self:GetChildren()
end
function players:GetPlayerByUserId(id)
	for _, p in ipairs(self:GetChildren()) do
		if p.UserId == id then
			return p
		end
	end
	return nil
end

local uis = service("UserInputService")
uis.TouchEnabled = false
function uis:GetMouseLocation()
	return Vector2.new(10, 10)
end
local guiService = service("GuiService")
function guiService:GetGuiInset()
	return Vector2.new(0, 36)
end
local sound = service("SoundService")
function sound:PlayLocalSound() end
local pg = newInstance("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = __localPlayer

local text = service("TextService")
function text:FilterStringAsync(str)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return if string.find(str, "kufur") then "#####" else str
		end,
	}
end

-- DataStore: bellekte, UpdateAsync/GetAsync/SetAsync davranışıyla
local dss = service("DataStoreService")
__stores = {}
local function store(name)
	if not __stores[name] then
		__stores[name] = {}
	end
	local data = __stores[name]
	local s = {}
	function s:GetAsync(key)
		return data[key]
	end
	function s:SetAsync(key, value)
		data[key] = value
	end
	function s:UpdateAsync(key, fn)
		local nv = fn(data[key])
		if nv ~= nil then
			data[key] = nv
		end
		return nv
	end
	function s:GetSortedAsync()
		return {
			GetCurrentPage = function()
				local out = {}
				for k, v in pairs(data) do
					table.insert(out, { key = k, value = v })
				end
				table.sort(out, function(a, b)
					return a.value > b.value
				end)
				return out
			end,
		}
	end
	return s
end
function dss:GetDataStore(name)
	return store(name)
end
function dss:GetOrderedDataStore(name)
	return store(name)
end

---------------------------------------------------------------- require ve modül ağacı
local cache = {}
local function moduleNode(name, path, parent)
	local n = newInstance("ModuleScript")
	n.Name = name
	n.__path = path
	n.Parent = parent
	return n
end
local function folder(name, parent)
	local f = newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
function require(node)
	assert(type(node) == "table" and rawget(node, "__path"), "require: modül değil: " .. tostring(node and node.Name))
	local path = node.__path
	if cache[path] == nil then
		local src = readFile(path)
		__current = node
		local fn = compile("local script = __current; " .. src, path)
		local result = fn()
		cache[path] = if result == nil then true else result
	end
	return cache[path]
end
function __resetModules()
	cache = {}
end

local SRC = "src/"
local rs = service("ReplicatedStorage")
local shared = folder("Shared", rs)
moduleNode("Config", SRC .. "ReplicatedStorage/Shared/Config.luau", shared)
moduleNode("Kits", SRC .. "ReplicatedStorage/Shared/Kits.luau", shared)
moduleNode("Crest", SRC .. "ReplicatedStorage/Shared/Crest.luau", shared)
moduleNode("Squads", SRC .. "ReplicatedStorage/Shared/Squads.luau", shared)
moduleNode("Stadium", SRC .. "ReplicatedStorage/Shared/Stadium.luau", shared)
moduleNode("Remotes", SRC .. "ReplicatedStorage/Shared/Remotes.luau", shared)
local uiF = folder("UI", rs)
for _, n in ipairs({ "Theme", "UIMotion", "Icons", "Components", "Forms" }) do
	moduleNode(n, SRC .. "ReplicatedStorage/UI/" .. n .. ".luau", uiF)
end
local server = folder("Server", service("ServerScriptService"))
for _, n in ipairs({ "DataService", "PlayerService", "CharacterService" }) do
	moduleNode(n, SRC .. "ServerScriptService/Server/" .. n .. ".luau", server)
end
local client = folder("Client", service("StarterPlayer"))
local CL = SRC .. "StarterPlayer/StarterPlayerScripts/Client/"
local anim = folder("Anim", client)
moduleNode("Poses", CL .. "Anim/Poses.luau", anim)
moduleNode("Animator", CL .. "Anim/Animator.luau", anim)
local match = folder("Match", client)
for _, n in ipairs({ "Ball", "Bots", "MatchAI", "Referee", "Training", "Commentary", "TimeScale" }) do
	moduleNode(n, CL .. "Match/" .. n .. ".luau", match)
end
moduleNode("MatchController", CL .. "Match/MatchController.luau", match)
moduleNode("RemoteAnim", CL .. "Match/RemoteAnim.luau", match)
local controllers = folder("Controllers", client)
moduleNode("PlayerController", CL .. "Controllers/PlayerController.luau", controllers)
local screens = folder("Screens", client)
moduleNode("Creator", CL .. "Screens/Creator.luau", screens)
moduleNode("SkillTree", CL .. "Screens/SkillTree.luau", screens)
moduleNode("Lineup", CL .. "Screens/Lineup.luau", screens)
moduleNode("CrestDesigner", CL .. "Screens/CrestDesigner.luau", screens)
moduleNode("League", CL .. "Screens/League.luau", screens)
moduleNode("Halftime", CL .. "Screens/Halftime.luau", screens)
moduleNode("Hub", CL .. "Screens/Hub.luau", screens)
moduleNode("Career", CL .. "Screens/Career.luau", screens)
moduleNode("Celebration", CL .. "Screens/Celebration.luau", screens)
__tree = { Shared = shared, UI = uiF, Server = server, Anim = anim, Match = match, Controllers = controllers, Screens = screens }
__tree.Client = client
moduleNode("Main", CL .. "Main.client.luau", client)

-- Gerçek ölçülü R15 karakter: 15 gövde parçası + kök, Motor6D eklemleri (C0/C1), yüz çıkartması.
-- Ölçüler Roblox'un standart köşeli R15 gövdesine yakındır; forma giydirme ve animasyon bu iskelette sınanır.
local R15_PARTS = {
	HumanoidRootPart = { 2, 2, 1 },
	LowerTorso = { 2, 0.4, 1 },
	UpperTorso = { 2, 1.6, 1 },
	Head = { 1.2, 1.2, 1.2 },
	LeftUpperArm = { 1, 1.169, 1 },
	LeftLowerArm = { 1, 1.052, 1 },
	LeftHand = { 1, 0.3, 1 },
	RightUpperArm = { 1, 1.169, 1 },
	RightLowerArm = { 1, 1.052, 1 },
	RightHand = { 1, 0.3, 1 },
	LeftUpperLeg = { 1, 1.217, 1 },
	LeftLowerLeg = { 1, 1.193, 1 },
	LeftFoot = { 1, 0.3, 1 },
	RightUpperLeg = { 1, 1.217, 1 },
	RightLowerLeg = { 1, 1.193, 1 },
	RightFoot = { 1, 0.3, 1 },
}
-- { eklem, Part0, Part1, C0, C1 }  (Part1 = Part0 * C0 * Transform * C1^-1)
local R15_JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", { 0, -1, 0 }, { 0, -0.2, 0 } },
	{ "Waist", "LowerTorso", "UpperTorso", { 0, 0.2, 0 }, { 0, -0.8, 0 } },
	{ "Neck", "UpperTorso", "Head", { 0, 0.8, 0 }, { 0, -0.5, 0 } },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", { -1, 0.563, 0 }, { 0.5, 0.394, 0 } },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", { 0, -0.334, 0 }, { 0, 0.259, 0 } },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", { 0, -0.501, 0 }, { 0, 0.125, 0 } },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", { 1, 0.563, 0 }, { -0.5, 0.394, 0 } },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", { 0, -0.334, 0 }, { 0, 0.259, 0 } },
	{ "RightWrist", "RightLowerArm", "RightHand", { 0, -0.501, 0 }, { 0, 0.125, 0 } },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", { -0.5, -0.2, 0 }, { 0, 0.421, 0 } },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", { 0, -0.401, 0 }, { 0, 0.379, 0 } },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", { 0, -0.547, 0 }, { 0, 0.102, 0 } },
	{ "RightHip", "LowerTorso", "RightUpperLeg", { 0.5, -0.2, 0 }, { 0, 0.421, 0 } },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", { 0, -0.401, 0 }, { 0, 0.379, 0 } },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", { 0, -0.547, 0 }, { 0, 0.102, 0 } },
}
__R15_JOINTS = R15_JOINTS
function __makeRig(name)
	local m = newInstance("Model")
	m.Name = name
	local parts = {}
	for partName, size in pairs(R15_PARTS) do
		local part = newInstance(if partName == "HumanoidRootPart" then "Part" else "MeshPart")
		part.Name = partName
		part.Size = V3.new(size[1], size[2], size[3])
		part.Color = Color3.fromRGB(163, 162, 165)
		parts[partName] = part
	end
	parts.HumanoidRootPart.CFrame = CFrame.new(0, 3, 0) -- kalça yüksekliği 2 + kök yarı boyu 1
	parts.HumanoidRootPart.Transparency = 1
	for _, j in ipairs(R15_JOINTS) do
		local motor = newInstance("Motor6D")
		motor.Name = j[1]
		motor.Part0 = parts[j[2]]
		motor.Part1 = parts[j[3]]
		motor.C0 = CFrame.new(j[4][1], j[4][2], j[4][3])
		motor.C1 = CFrame.new(j[5][1], j[5][2], j[5][3])
		parts[j[3]].CFrame = parts[j[2]].CFrame * motor.C0 * motor.C1:Inverse()
		motor.Parent = parts[j[3]]
	end
	local face = newInstance("Decal")
	face.Name = "face"
	face.Parent = parts.Head
	-- parçalar sabit sırayla eklenir (sınamalar kararlı olsun)
	parts.HumanoidRootPart.Parent = m
	for _, j in ipairs(R15_JOINTS) do
		parts[j[3]].Parent = m
	end
	local hum = newInstance("Humanoid")
	hum.Parent = m
	local animator = newInstance("Animator")
	animator.Parent = hum
	return m
end
