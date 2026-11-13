--[[
	Ball
	Top fiziği ve topla oynama. Top ayrı bir nesnedir; oyuncuya yapışmaz, her dokunuşla itilir.
	- Fizik: yerçekimi, hava direnci, yuvarlanma sürtünmesi, sekme, falso, saha sınırları, kale ve direk.
	- Sürme: her adımda (ayak yere basınca) top öne itilir; sprintte daha uzağa gider.
	- İlk dokunuş, durdurma, şut (hedef + hata payı + falso), pas, kafa, vole, röveşata.
	- Düşüş tahmini: havadan gelen topun ineceği yer ve süre (zamanlama halkası için).
	Maç tek oyunculu olduğu için top istemcide benzetilir; ödüller sunucuda doğrulanır.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local B = Config.Ball
local T: any = Config.TestPitch
local S = Config.Shooting
local C = Config.Colors

local Ball = {}

local part: Part? = nil
local trail: Trail? = nil
local pos = Vector3.new(0, 1, 80)
local vel = Vector3.zero
local curve = 0
local inNet = false
local lastKick = -10
local lastKind = "Shoot"
local clock = 0
local listeners = { goal = {}, post = {}, out = {}, kick = {}, dead = {} }

-- Topa en son dokunan takım: "home" (oyuncunun takımı) ya da "away"
Ball.LastTeam = "home"

local function fire(name: string, ...)
	for _, fn in ipairs(listeners[name]) do
		task.spawn(fn, ...)
	end
end

function Ball.On(name: string, fn)
	table.insert(listeners[name], fn)
end

-- Saha değiştirir (deneme sahası ya da maç sahası)
function Ball.SetPitch(def)
	T = def
end
function Ball.Pitch()
	return T
end

function Ball.Init()
	if part and part.Parent then
		return
	end
	local p = Instance.new("Part")
	p.Name = "FK_Ball"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(B.Radius * 2, B.Radius * 2, B.Radius * 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Color = skinA
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	p.Parent = Workspace
	-- top deseni: klasik futbol topundaki 12 koyu beşgenin yerine, yüzeye yapışık 12 koyu yama
	-- (yirmi yüzlünün köşelerine dizilir; düz çıkartma gibi havada durmaz, topla birlikte döner)
	local phi = (1 + math.sqrt(5)) / 2
	local patch = B.Radius * 0.78
	for _, v in ipairs({
		Vector3.new(0, 1, phi),
		Vector3.new(0, 1, -phi),
		Vector3.new(0, -1, phi),
		Vector3.new(0, -1, -phi),
		Vector3.new(1, phi, 0),
		Vector3.new(1, -phi, 0),
		Vector3.new(-1, phi, 0),
		Vector3.new(-1, -phi, 0),
		Vector3.new(phi, 0, 1),
		Vector3.new(phi, 0, -1),
		Vector3.new(-phi, 0, 1),
		Vector3.new(-phi, 0, -1),
	}) do
		local n = v.Unit
		local d = Instance.new("Part")
		d.Name = "Patch"
		d.Size = Vector3.new(patch, B.Radius * 0.16, patch)
		d.Color = skinB
		d.Material = Enum.Material.SmoothPlastic
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.Massless = true
		d.CastShadow = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = d
		local at = p.Position + n * (B.Radius * 0.94)
		d.CFrame = CFrame.lookAt(at, at + n) * CFrame.Angles(-math.pi / 2, 0, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = d
		w.Parent = d
		d.Parent = p
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, B.Radius * 0.8, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -B.Radius * 0.8, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.28
	tr.LightEmission = 0.6
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	tr.Enabled = false
	tr.Parent = p
	p.Parent = Workspace
	part, trail = p, tr
end

function Ball.Position(): Vector3
	return pos
end
function Ball.Velocity(): Vector3
	return vel
end
function Ball.Speed(): number
	return vel.Magnitude
end
function Ball.InNet(): boolean
	return inNet
end
function Ball.SinceKick(): number
	return clock - lastKick
end

function Ball.Reset(at: Vector3)
	pos = Vector3.new(at.X, T.GroundY + B.Radius, at.Z)
	vel = Vector3.zero
	curve = 0
	inNet = false
	lastKick = -10 -- yeni top: dokunma beklemesi yok
	if trail then
		trail.Enabled = false
	end
end

local TRAIL_COLORS = {
	Fuze = ColorSequence.new(Color3.fromRGB(255, 90, 40), Color3.fromRGB(255, 200, 80)),
	Plase = ColorSequence.new(C.Yellow, C.White),
	Rovesata = ColorSequence.new(C.Gold, C.Yellow),
}

-- Mağazadan kuşanılan görünüm: top gövdesi / yamalar ve olağan şut izi
local skinA, skinB = Color3.fromRGB(250, 250, 250), C.Navy
local trailBase = ColorSequence.new(C.White)
function Ball.SetSkin(a: Color3, b: Color3)
	skinA, skinB = a, b
	if part then
		part.Color = a
		for _, d in ipairs(part:GetChildren()) do
			if d.Name == "Patch" and d:IsA("BasePart") then
				d.Color = b
			end
		end
	end
end
function Ball.SetTrail(a: Color3, b: Color3)
	trailBase = ColorSequence.new(a, b)
end

-- Topa hız verir. kind: iz rengi ve gol türü için
function Ball.Kick(v: Vector3, spin: number?, kind: string?)
	vel = v
	curve = spin or 0
	lastKick = clock
	lastKind = kind or "Shoot"
	inNet = false
	if trail then
		trail.Color = TRAIL_COLORS[lastKind] or trailBase
	end
	fire("kick", lastKind, v)
	-- vuruşta sıkışma
	if part then
		part.Size = Vector3.new(B.Radius * 2.5, B.Radius * 1.5, B.Radius * 2.5)
		TweenService:Create(
			part,
			TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = Vector3.new(B.Radius * 2, B.Radius * 2, B.Radius * 2) }
		):Play()
	end
end

-- Tek fizik adımı (durum değiştirmeden de kullanılabilsin diye değerleri alır ve döndürür)
local function integrate(p: Vector3, v: Vector3, cv: number, h: number, events: boolean)
	local ground = T.GroundY + B.Radius
	local onGround = p.Y <= ground + 0.02 and math.abs(v.Y) < 2
	if not onGround then
		v += Vector3.new(0, -B.Gravity * h, 0)
	end
	local flat = Vector3.new(v.X, 0, v.Z)
	local sp = flat.Magnitude
	if cv ~= 0 and sp > 5 and not onGround then
		local side = Vector3.new(-flat.Z, 0, flat.X) / sp
		v += side * cv * B.CurveAccel * h
	end
	local drag = if onGround then B.RollFriction else B.AirDrag
	v *= math.exp(-drag * h)
	if onGround and sp < 0.6 then
		v = Vector3.zero
	end
	local np = p + v * h
	-- zemin
	if np.Y < ground then
		np = Vector3.new(np.X, ground, np.Z)
		if v.Y < -6 then
			v = Vector3.new(v.X * 0.86, -v.Y * B.Bounce, v.Z * 0.86)
			cv *= 0.4
		else
			v = Vector3.new(v.X, 0, v.Z)
		end
	end
	local result: string? = nil
	-- kale çizgisi
	if p.Z < T.GoalZ and np.Z >= T.GoalZ and not inNet then
		local ax, w, hgt = math.abs(np.X), T.GoalHalfWidth, T.GoalHeight
		if ax < w - B.Radius and np.Y < hgt - B.Radius then
			result = "goal"
		elseif (math.abs(ax - w) < B.Radius + 0.35 and np.Y < hgt + 0.6) or (ax < w + 0.6 and math.abs(np.Y - hgt) < B.Radius + 0.35) then
			result = "post"
			np = Vector3.new(np.X, np.Y, T.GoalZ - 0.05)
			v = Vector3.new(v.X * 0.6 + (if np.X > 0 then 1 else -1) * (ax - w) * 30, v.Y * 0.6, -math.abs(v.Z) * 0.55)
		end
	end
	-- kendi kalemiz (yalnız maç sahasında)
	if T.GoalZBack and p.Z > T.GoalZBack and np.Z <= T.GoalZBack and not inNet then
		local ax, w, hgt = math.abs(np.X), T.GoalHalfWidth, T.GoalHeight
		if ax < w - B.Radius and np.Y < hgt - B.Radius then
			result = "goalBack"
		elseif (math.abs(ax - w) < B.Radius + 0.35 and np.Y < hgt + 0.6) or (ax < w + 0.6 and math.abs(np.Y - hgt) < B.Radius + 0.35) then
			result = "post"
			np = Vector3.new(np.X, np.Y, T.GoalZBack + 0.05)
			v = Vector3.new(v.X * 0.6, v.Y * 0.6, math.abs(v.Z) * 0.55)
		end
	end
	-- saha sınırları
	if T.Walls == false then
		-- duvar yok: top çizgiyi geçerse oyun durur
		if events and result == nil and not inNet then
			if np.X < T.MinX or np.X > T.MaxX then
				result = "side"
			elseif np.Z > T.MaxZ then
				result = "endFront"
			elseif np.Z < T.MinZ then
				result = "endBack"
			end
		end
		return np, v, cv, result
	end
	if np.X < T.MinX or np.X > T.MaxX then
		np = Vector3.new(math.clamp(np.X, T.MinX, T.MaxX), np.Y, np.Z)
		v = Vector3.new(-v.X * B.WallBounce, v.Y, v.Z)
	end
	if np.Z < T.MinZ then
		np = Vector3.new(np.X, np.Y, T.MinZ)
		v = Vector3.new(v.X, v.Y, math.abs(v.Z) * B.WallBounce)
	elseif np.Z > T.MaxZ then
		np = Vector3.new(np.X, np.Y, T.MaxZ)
		v = Vector3.new(v.X * 0.5, v.Y * 0.5, -math.abs(v.Z) * 0.12)
		if events and result == nil and not inNet then
			result = "out"
		end
	end
	return np, v, cv, result
end

function Ball.Step(dt: number)
	if not part then
		return
	end
	clock += dt
	local steps = math.clamp(math.ceil(dt / (1 / 120)), 1, 8)
	local h = dt / steps
	for _ = 1, steps do
		local np, nv, ncv, result = integrate(pos, vel, curve, h, true)
		pos, vel, curve = np, nv, ncv
		if result == "goal" or result == "goalBack" then
			inNet = true
			vel *= 0.18
			fire("goal", lastKind, if result == "goal" then "front" else "back")
		elseif result == "side" or result == "endFront" or result == "endBack" then
			inNet = true -- ölü top: yeniden başlatılana kadar kimse oynayamaz
			vel *= 0.3
			fire("dead", result, pos)
		elseif result == "post" then
			fire("post")
		elseif result == "out" then
			inNet = true
			fire("out")
		end
		if inNet and T.GoalZBack then
			-- maç sahası: top filenin arkasına geçmesin
			if pos.Z > T.GoalZ + 4.4 then
				pos = Vector3.new(pos.X, pos.Y, T.GoalZ + 4.4)
				vel = Vector3.new(vel.X * 0.3, vel.Y, 0)
			elseif pos.Z < T.GoalZBack - 4.4 then
				pos = Vector3.new(pos.X, pos.Y, T.GoalZBack - 4.4)
				vel = Vector3.new(vel.X * 0.3, vel.Y, 0)
			end
		end
		if inNet then
			-- filenin içinde kalsın
			local w = T.GoalHalfWidth - B.Radius
			if math.abs(pos.X) > w and pos.Z > T.GoalZ and pos.Y < T.GoalHeight then
				pos = Vector3.new(math.clamp(pos.X, -w, w), pos.Y, pos.Z)
				vel = Vector3.new(-vel.X * 0.2, vel.Y, vel.Z)
			end
		end
	end
	local sp = vel.Magnitude
	-- yuvarlanma dönüşü
	local rot = part.CFrame - part.CFrame.Position
	if sp > 0.5 then
		local axis = Vector3.new(vel.Z, 0, -vel.X)
		if axis.Magnitude > 0.01 then
			rot = CFrame.fromAxisAngle(axis.Unit, sp * dt / B.Radius) * rot
		end
	end
	part.CFrame = CFrame.new(pos) * rot
	if trail then
		trail.Enabled = sp > B.TrailSpeed
	end
end

-- Top şu anki hızıyla nereye ve kaç saniyede iner? Havada değilse nil.
function Ball.Predict(): (Vector3?, number?)
	local ground = T.GroundY + B.Radius
	if pos.Y < ground + 1.5 and vel.Y < 8 then
		return nil, nil
	end
	local p, v, cv, t = pos, vel, curve, 0
	local h = 1 / 60
	for _ = 1, 360 do
		local result
		p, v, cv, result = integrate(p, v, cv, h, false)
		t += h
		if p.Y <= ground + 0.05 or result then
			return p, t
		end
	end
	return nil, nil
end

-- Top z düzlemini nerede ve kaç saniyede geçer? (kalecinin kurtarış kararı için)
function Ball.PredictCross(z: number): (Vector3?, number?)
	local sign = if z > pos.Z then 1 else -1
	if vel.Z * sign <= 1 then
		return nil, nil
	end
	local p, v, cv, t = pos, vel, curve, 0
	local h = 1 / 90
	for _ = 1, 400 do
		p, v, cv = integrate(p, v, cv, h, false)
		t += h
		if (p.Z - z) * sign >= 0 then
			return p, t
		end
		if v.Z * sign <= 0.5 then
			return nil, nil
		end
	end
	return nil, nil
end

-- Topun hızını olay tetiklemeden değiştirir (sekme, çelme)
function Ball.Deflect(v: Vector3)
	vel = v
	curve = 0
	lastKick = clock
end

--------------------------------------------------------------------------------
-- Oyuncunun topla etkileşimi
--------------------------------------------------------------------------------
local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Her karede: durdurma, ilk dokunuş, topun üstüne basmama
-- ctx = { pos (ayak hizası), dir (hareket yönü), speed, control (1-10) }
function Ball.Carry(dt: number, ctx)
	if inNet then
		return
	end
	local d = flatDist(pos, ctx.pos)
	local low = pos.Y < T.GroundY + 2.6
	if not low or d > 3.2 or clock - lastKick < 0.3 then
		return
	end
	local sp = vel.Magnitude
	local moving = ctx.dir.Magnitude > 0.1
	if sp > 34 then
		Ball.LastTeam = "home"
		-- ilk dokunuş: Top Kontrolü yüksekse top ayağa yakın kalır
		local keep = math.clamp(0.42 - ctx.control * 0.035, 0.06, 0.42)
		vel = vel * keep + (if moving then ctx.dir * ctx.speed * 0.6 else Vector3.zero)
		lastKick = clock - 0.15
		return "first"
	end
	if not moving then
		if d < 2.6 then
			vel *= math.exp(-9 * dt) -- ayağının dibinde durdur
		end
		return
	end
	-- topun üstüne basma: çok yakındaysa ve geride kaldıysa hafifçe öne it
	local toBall = Vector3.new(pos.X - ctx.pos.X, 0, pos.Z - ctx.pos.Z)
	if d < 1.3 or (d < 2.6 and toBall:Dot(ctx.dir) < 0.2) then
		Ball.LastTeam = "home"
		local want = ctx.dir * math.max(ctx.speed * 1.05, 8)
		vel = Vector3.new(want.X, vel.Y, want.Z)
	end
	return
end

-- Ayak yere basınca: sürme dokunuşu. Sprintte top daha uzağa gider.
function Ball.Touch(ctx): boolean
	if inNet or clock - lastKick < 0.2 then
		return false
	end
	if flatDist(pos, ctx.pos) > 3.4 or pos.Y > T.GroundY + 2.4 or ctx.dir.Magnitude < 0.1 then
		return false
	end
	local push = ctx.speed * (if ctx.sprinting then 1.24 else 1.1) + 3
	local err = math.rad((11 - ctx.control) * (if ctx.sprinting then 1.6 else 0.8)) * (math.random() - 0.5) * 2
	local dir = CFrame.Angles(0, err, 0):VectorToWorldSpace(ctx.dir)
	vel = Vector3.new(dir.X * push, 0, dir.Z * push)
	curve = 0
	Ball.LastTeam = "home"
	return true
end

-- Şut hedefi: kale içinde bir nokta. aimX: -1..1 (yön girdisi), power: 0..MaxCharge
function Ball.AimPoint(aimX: number, power: number, lift: number): Vector3
	local w = T.GoalHalfWidth - 1.4
	local y
	if power > S.OverFrom then
		y = T.GoalHeight + 2 + (power - S.OverFrom) * 60 -- fazla tutuldu: üstten gider
	else
		y = (1 + power * power * 4.6) * lift
	end
	return Vector3.new(math.clamp(aimX, -1, 1) * w, math.max(0.8, y), T.GoalZ + 1)
end

--[[
	Vuruş. opts = {
		kind, from (oyuncu konumu), facing (bakış yönü), aimX, power, perfect, stat (Şut 1-10),
		minY, maxY (topun olması gereken yükseklik aralığı), reach
	}
	Dönüş: "perfect" | "good" | "miss", hedef nokta
]]
function Ball.Strike(opts): (string, Vector3?)
	local shot = Config.Shots[opts.kind] or Config.Shots.Shoot
	local d = flatDist(pos, opts.from)
	local h = pos.Y - T.GroundY
	if inNet or d > (opts.reach or S.Reach) or h < (opts.minY or 0) or h > (opts.maxY or 2.6) then
		return "miss", nil
	end
	local toGoal = Vector3.new(0, 0, T.GoalZ) - Vector3.new(pos.X, 0, pos.Z)
	local goalDist = toGoal.Magnitude
	local target: Vector3
	if goalDist < 190 and opts.facing:Dot(toGoal.Unit) > -0.2 then
		local aimX = opts.aimX
		if shot.Curve ~= 0 and math.abs(aimX) > 0.2 then
			aimX *= 1.25 -- falsolu şut direğin dışına nişan alır, içe kıvrılır
		end
		target = Ball.AimPoint(aimX, opts.power, shot.Lift)
		if opts.kind == "Asirtma" then
			target = Vector3.new(target.X, T.GoalHeight * 0.55, target.Z)
		end
	else
		target = pos + opts.facing * 80 + Vector3.new(0, 3 + opts.power * 6, 0)
		goalDist = 80
	end
	local speed = shot.Speed
		* (0.72 + math.min(opts.power, 1) * 0.28)
		* (if opts.perfect then S.PerfectSpeedBonus else 1)
		* (1 + (opts.stat - 1) * 0.022)
	local delta = target - pos
	local t = math.max(0.12, Vector3.new(delta.X, 0, delta.Z).Magnitude / speed)
	if opts.kind == "Asirtma" then
		t *= 1.9 -- yüksek yay
	end
	local v = Vector3.new(delta.X / t, delta.Y / t + 0.5 * B.Gravity * t, delta.Z / t)
	-- hata payı: Şut özelliği ve mükemmel vuruş daraltır
	local err = math.max(0.012, S.BaseError - opts.stat * S.ErrorPerStat) * shot.Error * (if opts.perfect then S.PerfectErrorFactor else 1)
	v = CFrame.Angles(0, (math.random() - 0.5) * 2 * err, 0):VectorToWorldSpace(v)
	v += Vector3.new(0, (math.random() - 0.5) * err * speed * 0.8, 0)
	local spin = 0
	if shot.Curve ~= 0 and math.abs(opts.aimX) > 0.2 then
		spin = (if opts.aimX > 0 then 1 else -1) * shot.Curve * 0.55
	end
	Ball.LastTeam = "home"
	Ball.Kick(v, spin, opts.kind)
	return if opts.perfect then "perfect" else "good", target
end

-- Pas: bakış yönüne, yakındaki pas hedefine hafifçe yönelir. power: 0..1
function Ball.Pass(from: Vector3, facing: Vector3, power: number, stat: number, targets: { Vector3 }): boolean
	if inNet or flatDist(pos, from) > S.Reach or pos.Y > T.GroundY + 2.6 then
		return false
	end
	local dir = Vector3.new(facing.X, 0, facing.Z).Unit
	local best, bestDot = nil, 0.9
	for _, tp in ipairs(targets) do
		local to = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
		if to.Magnitude > 6 then
			local dot = to.Unit:Dot(dir)
			if dot > bestDot then
				best, bestDot = to, dot
			end
		end
	end
	local speed = S.PassSpeed[1] + (S.PassSpeed[2] - S.PassSpeed[1]) * math.clamp(power, 0, 1)
	if best then
		dir = best.Unit
		speed = math.clamp(best.Magnitude * 1.5 + 18, S.PassSpeed[1] * 0.8, S.PassSpeed[2])
	end
	local err = math.rad(math.max(0.5, 7 - stat * 0.65)) * (math.random() - 0.5) * 2
	dir = CFrame.Angles(0, err, 0):VectorToWorldSpace(dir)
	Ball.LastTeam = "home"
	Ball.Kick(dir * speed + Vector3.new(0, if power > 0.75 then 14 else 0, 0), 0, "Pass")
	return true
end

-- Kanattan orta: topu from noktasından target'a yaklaşık time saniyede düşecek şekilde atar
function Ball.Cross(from: Vector3, target: Vector3, time: number)
	Ball.Reset(from)
	local delta = target - pos
	local v = Vector3.new(delta.X / time, delta.Y / time + 0.5 * B.Gravity * time, delta.Z / time)
	-- hava direncini kabaca telafi et
	Ball.Kick(Vector3.new(v.X, 0, v.Z) * (1 + B.AirDrag * time * 0.55) + Vector3.new(0, v.Y, 0), 0, "Cross")
end

return Ball
