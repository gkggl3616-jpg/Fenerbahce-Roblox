--[[
	Animator
	Kodla çalışan katmanlı animasyon motoru (R15).
	- Alt katman: duruş ve koşu döngüsü hızdan üretilir (yürüyüşten sprinte kesintisiz).
	- Üst katman: eylemler (şut, kafa, çalım, müdahale...) anahtar karelerden okunur ve yumuşak geçişle karışır.
	- "Upper" maskeli eylemler koşarken oynar; bacaklar koşmaya devam eder.
	- Olaylar (strike, jump, land, footstep...) tam zamanında bildirilir; top fiziği ve efektler buna bağlanır.
	- Toparlanma süresinde basılan tuş tamponda tutulur ve ilk fırsatta oynar.
	Varsayılan Roblox Animate betiği kapatılır.
]]

local Poses = require(script.Parent.Poses)

local Animator = {}
Animator.__index = Animator

local ZERO = Vector3.zero
local BLEND_IN, BLEND_OUT = 0.1, 0.16
local BUFFER_TIME = 0.35

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local MIRROR = {}
for _, j in ipairs(Poses.Joints) do
	if string.sub(j, 1, 4) == "Left" then
		MIRROR[j] = "Right" .. string.sub(j, 5)
	elseif string.sub(j, 1, 5) == "Right" then
		MIRROR[j] = "Left" .. string.sub(j, 6)
	else
		MIRROR[j] = j
	end
end

function Animator.new(character: Model)
	local self = setmetatable({}, Animator)
	self.Character = character
	self.Motors = {}
	self.Rest = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and table.find(Poses.Joints, d.Name) then
			self.Motors[d.Name] = d
		end
	end
	self.Phase = 0
	self.Time = 0
	self.Action = nil -- { def, name, t, mirror, fired = {} }
	self.Weight = 0
	self.LastPose = {} -- eylem bittikten sonra geçiş için son poz
	self.LastMask = "Full"
	self.Buffered = nil
	self.Listeners = {}
	self.LeanSmooth = 0
	self.SpeedSmooth = 0
	self.LastStep = 0

	-- Varsayılan animasyonları kapat
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local an = hum and hum:FindFirstChildOfClass("Animator")
	if an then
		for _, track in ipairs(an:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end
	return self
end

function Animator:OnEvent(fn: (string, string) -> ())
	table.insert(self.Listeners, fn)
end

function Animator:_fire(event: string, action: string)
	for _, fn in ipairs(self.Listeners) do
		task.spawn(fn, event, action)
	end
end

function Animator:IsBusy(): boolean
	return self.Action ~= nil
end

-- Eylem sırasında hareket hızı çarpanı (1 = serbest)
function Animator:SpeedFactor(): number
	local a = self.Action
	return if a then (a.def.Speed or 1) else 1
end

function Animator:Current(): string?
	return self.Action and self.Action.name
end

-- Eylemi başlatır. Meşgulse ve toparlanma başlamadıysa tampona alır. Dönüş: hemen başladı mı
function Animator:Play(name: string, opts)
	local def = Poses.Actions[name]
	if not def then
		return false
	end
	local a = self.Action
	if a then
		if a.t < (a.def.Recover or a.def.Duration) then
			self.Buffered = { name = name, opts = opts, at = self.Time }
			return false
		end
		self.LastPose = self:_sample(a)
		self.LastMask = a.def.Mask
	end
	self.Action = { def = def, name = name, t = 0, mirror = opts and opts.Mirror == true, fired = {} }
	self.Buffered = nil
	self:_fire("start", name)
	return true
end

function Animator:Stop()
	if self.Action then
		self.LastPose = self:_sample(self.Action)
		self.LastMask = self.Action.def.Mask
		self.Action = nil
	end
end

function Animator:_sample(a)
	local keys = a.def.Keys
	local t = a.t
	local k0, k1 = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i][1] and t <= keys[i + 1][1] then
			k0, k1 = keys[i], keys[i + 1]
			break
		end
	end
	local span = k1[1] - k0[1]
	local alpha = if span > 0 then smooth(math.clamp((t - k0[1]) / span, 0, 1)) else 1
	local out = {}
	for _, j in ipairs(Poses.Joints) do
		local src = if a.mirror then MIRROR[j] else j
		local v0, v1 = k0[2][src] or ZERO, k1[2][src] or ZERO
		local v = v0:Lerp(v1, alpha)
		if a.mirror then
			v = Vector3.new(v.X, -v.Y, -v.Z)
		end
		out[j] = v
	end
	local p0, p1 = k0[2].RootPos or ZERO, k1[2].RootPos or ZERO
	local p = p0:Lerp(p1, alpha)
	out.RootPos = if a.mirror then Vector3.new(-p.X, p.Y, p.Z) else p
	return out
end

-- Duruş ve koşu: ctx = { speed, maxSpeed, sprinting, tired, grounded, turn (-1..1), vy }
function Animator:_locomotion(dt: number, ctx)
	local pose = {}
	local speed = ctx.speed
	self.SpeedSmooth += (speed - self.SpeedSmooth) * math.min(1, dt * 10)
	local s = self.SpeedSmooth
	local run = math.clamp(s / 17, 0, 1) -- 0 duruş, 1 koşu
	local sprint = math.clamp((s - 17) / 8, 0, 1)
	self.LeanSmooth += ((ctx.turn or 0) - self.LeanSmooth) * math.min(1, dt * 6)

	if not ctx.grounded then
		-- havada: bacaklar hafif toplanır, kollar açılır
		local up = math.clamp((ctx.vy or 0) / 30, -1, 1)
		pose.LeftHip = Vector3.new(20 + up * 10, 0, 0)
		pose.RightHip = Vector3.new(-6 + up * 10, 0, 0)
		pose.LeftKnee = Vector3.new(-45, 0, 0)
		pose.RightKnee = Vector3.new(-25, 0, 0)
		pose.LeftShoulder = Vector3.new(30, 0, -45)
		pose.RightShoulder = Vector3.new(30, 0, 45)
		pose.Root = Vector3.new(-4, 0, 0)
		return pose
	end

	if run < 0.05 then
		-- duruş: nefes ve ağırlık aktarma
		local b = math.sin(self.Time * (if ctx.tired then 5 else 1.8))
		local sway = math.sin(self.Time * 0.7)
		local amp = if ctx.tired then 2.2 else 1
		pose.Waist = Vector3.new(b * 1.5 * amp - (if ctx.tired then 14 else 0), 0, sway * 1.2)
		pose.Neck = Vector3.new(-b * 1 - (if ctx.tired then 10 else 0), sway * 3, 0)
		pose.LeftShoulder = Vector3.new(b * 2 + (if ctx.tired then 25 else 0), 0, -6 - b)
		pose.RightShoulder = Vector3.new(b * 2 + (if ctx.tired then 25 else 0), 0, 6 + b)
		pose.LeftElbow = Vector3.new(if ctx.tired then 40 else 8, 0, 0)
		pose.RightElbow = Vector3.new(if ctx.tired then 40 else 8, 0, 0)
		pose.LeftHip = Vector3.new(if ctx.tired then 14 else 0, 0, -3)
		pose.RightHip = Vector3.new(if ctx.tired then 14 else 0, 0, 3)
		pose.LeftKnee = Vector3.new(if ctx.tired then -22 else -2, 0, 0)
		pose.RightKnee = Vector3.new(if ctx.tired then -22 else -2, 0, 0)
		pose.RootPos = Vector3.new(0, b * 0.02 * amp - (if ctx.tired then 0.18 else 0), 0)
		return pose
	end

	-- koşu döngüsü: adım sıklığı hızla artar
	local cadence = 7 + run * 5 + sprint * 3.5
	local prev = self.Phase
	self.Phase += dt * cadence
	local ph = self.Phase
	local sn, cs = math.sin(ph), math.cos(ph)
	local legAmp = 26 + run * 22 + sprint * 14
	local armAmp = 22 + run * 30 + sprint * 22
	local lean = 4 + run * 6 + sprint * 9
	-- sol bacak öne giderken sağ kol öne gider
	pose.LeftHip = Vector3.new(sn * legAmp + 6, 0, 0)
	pose.RightHip = Vector3.new(-sn * legAmp + 6, 0, 0)
	-- diz: bacak geriden öne gelirken bükülür
	pose.LeftKnee = Vector3.new(-(14 + math.max(0, -cs) * (55 + sprint * 35) * run), 0, 0)
	pose.RightKnee = Vector3.new(-(14 + math.max(0, cs) * (55 + sprint * 35) * run), 0, 0)
	pose.LeftAnkle = Vector3.new(math.max(0, sn) * 14, 0, 0)
	pose.RightAnkle = Vector3.new(math.max(0, -sn) * 14, 0, 0)
	pose.RightShoulder = Vector3.new(sn * armAmp, 0, 6)
	pose.LeftShoulder = Vector3.new(-sn * armAmp, 0, -6)
	local elbow = 45 + run * 35
	pose.RightElbow = Vector3.new(elbow + sn * 12, 0, 0)
	pose.LeftElbow = Vector3.new(elbow - sn * 12, 0, 0)
	pose.Waist = Vector3.new(-lean * 0.5, -sn * (5 + run * 5), -self.LeanSmooth * 6)
	pose.Neck = Vector3.new(lean * 0.4, sn * 3, 0)
	pose.Root = Vector3.new(-lean * 0.5, 0, -self.LeanSmooth * (8 + sprint * 8))
	pose.RootPos = Vector3.new(0, math.abs(cs) * (0.06 + run * 0.1) - 0.08 * run, 0)
	if ctx.tired then
		pose.Waist += Vector3.new(-8, 0, 0)
		pose.Neck += Vector3.new(-8, 0, 0)
	end
	-- ayak yere basma olayı
	if math.floor(prev / math.pi) ~= math.floor(ph / math.pi) and self.Time - self.LastStep > 0.12 then
		self.LastStep = self.Time
		self:_fire(if math.floor(ph / math.pi) % 2 == 0 then "footL" else "footR", if sprint > 0.4 then "sprint" else "run")
	end
	return pose
end

function Animator:Update(dt: number, ctx)
	self.Time += dt
	local base = self:_locomotion(dt, ctx)
	local actPose, mask = nil, "Full"
	local a = self.Action
	if a then
		a.t += dt
		for i, ev in ipairs(a.def.Events or {}) do
			if not a.fired[i] and a.t >= ev[1] then
				a.fired[i] = true
				self:_fire(ev[2], a.name)
			end
		end
		actPose = self:_sample(a)
		mask = a.def.Mask
		self.Weight = math.min(1, self.Weight + dt / BLEND_IN)
		if a.t >= a.def.Duration then
			self.LastPose = if a.def.Snap then {} else actPose
			self.LastMask = mask
			if a.def.Snap then
				self.Weight = 0
			end
			self.Action = nil
			self:_fire("end", a.name)
		elseif self.Buffered and a.t >= (a.def.Recover or a.def.Duration) then
			local b = self.Buffered
			if self.Time - b.at <= BUFFER_TIME then
				self:Play(b.name, b.opts)
			else
				self.Buffered = nil
			end
		end
	else
		self.Weight = math.max(0, self.Weight - dt / BLEND_OUT)
		actPose = self.LastPose
		mask = self.LastMask
		if self.Buffered then
			local b = self.Buffered
			self.Buffered = nil
			if self.Time - b.at <= BUFFER_TIME then
				self:Play(b.name, b.opts)
			end
		end
	end

	local w = smooth(self.Weight)
	for _, j in ipairs(Poses.Joints) do
		local motor = self.Motors[j]
		if motor then
			local v = base[j] or ZERO
			if actPose and w > 0 and (mask == "Full" or Poses.Upper[j]) then
				v = v:Lerp(actPose[j] or ZERO, w)
			end
			local cf = CFrame.fromEulerAnglesYXZ(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
			if j == "Root" then
				local p = base.RootPos or ZERO
				if actPose and w > 0 and mask == "Full" then
					p = p:Lerp(actPose.RootPos or ZERO, w)
				end
				cf = CFrame.new(p) * cf
			end
			motor.Transform = cf
		end
	end
end

function Animator:Destroy()
	self.Listeners = {}
	self.Action = nil
end

return Animator
