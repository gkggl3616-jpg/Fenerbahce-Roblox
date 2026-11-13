--[[
	MeshBody
	Studio'da içe aktarılan gerçekçi futbolcu gövdesini (assets/modeller/FK_Oyuncu.glb) karaktere
	giydirir. İçe aktarılan model ReplicatedStorage/FK_Assets/FK_Oyuncu (ya da doğrudan
	ReplicatedStorage/FK_Oyuncu) olarak durur.

	Parçalar "<R15 parçası>__<rol>[__<desen>]" adlı MeshPart'lardır. Roller: Skin, Hair, Shirt,
	Stripe, Sleeve, Trim, Shorts, Sock, Boot. Desenli forma parçaları Cubuklu, Kusakli ve Duz
	olarak ayrıdır; karakterin forma desenine uyanlar takılır.
	FK_Origin, FK_AxisX ve FK_AxisY işaretleri, içe aktarıcının uyguladığı konum, dönme ve ölçeği
	geri çözmeye yarar. İskelet (eklem noktaları, kalça yüksekliği) MeshRig modülündedir.

	MeshBody.Build(character, look, kit, colors, k) -> boolean
		Model yoksa false döner; CharacterService o zaman kodla kurulan gövdeyi kullanır.
		k: ölçek (x ve z genişlik, y boy).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshRig = require(ReplicatedStorage.Shared.MeshRig)

local MeshBody = {}

export type Piece = {
	mesh: MeshPart,
	part: string,
	role: string,
	pattern: string?,
	size: Vector3,
	offset: CFrame,
}

local cache: any = nil

local function template(): Instance?
	local f = ReplicatedStorage:FindFirstChild("FK_Assets")
	return (f and f:FindFirstChild("FK_Oyuncu")) or ReplicatedStorage:FindFirstChild("FK_Oyuncu")
end

-- "UpperTorso__Shirt__Cubuklu" -> UpperTorso, Shirt, Cubuklu; "Head__Hair__S5" -> Head, Hair, S5
-- (içe aktarıcının eklediği ekler yok sayılır)
function MeshBody.ParseName(n: string): (string?, string?, string?)
	local part, role, pattern = string.match(n, "^(%a+)__(%a+)__(%w+)")
	if part then
		return part, role, pattern
	end
	part, role = string.match(n, "^(%a+)__(%a+)")
	return part, role, nil
end

function MeshBody.Reset()
	cache = nil
end

-- Şablonu okur ve parça listesini önbelleğe alır. Şablon yoksa nil.
function MeshBody.Load(): { pieces: { Piece } }?
	if cache ~= nil then
		return cache or nil
	end
	local tpl = template()
	if not tpl then
		cache = false
		return nil
	end
	local o, ax, ay
	for _, d in ipairs(tpl:GetDescendants()) do
		if d:IsA("BasePart") then
			if string.find(d.Name, "^FK_Origin") then
				o = d
			elseif string.find(d.Name, "^FK_AxisX") then
				ax = d
			elseif string.find(d.Name, "^FK_AxisY") then
				ay = d
			end
		end
	end
	if not (o and ax and ay) then
		warn("[MeshBody] FK_Oyuncu içinde FK_Origin / FK_AxisX / FK_AxisY işaretleri yok; kodla kurulan gövde kullanılacak")
		cache = false
		return nil
	end
	local xv = ax.Position - o.Position
	local scale = xv.Magnitude
	local frame = CFrame.fromMatrix(o.Position, xv.Unit, (ay.Position - o.Position).Unit)
	local pieces = {}
	for _, d in ipairs(tpl:GetDescendants()) do
		if d:IsA("MeshPart") and not string.find(d.Name, "^FK_") then
			local part, role, pattern = MeshBody.ParseName(d.Name)
			local info = part and MeshRig.Parts[part]
			if info and role then
				local rel = frame:ToObjectSpace(d.CFrame)
				local pos = rel.Position / scale
				table.insert(pieces, {
					mesh = d,
					part = part,
					role = role,
					pattern = pattern,
					size = d.Size / scale,
					offset = CFrame.new(pos - info.Center) * rel.Rotation,
				})
			end
		end
	end
	if #pieces == 0 then
		warn("[MeshBody] FK_Oyuncu içinde tanınan parça yok")
		cache = false
		return nil
	end
	cache = { pieces = pieces }
	return cache
end

-- Karakter eksenlerindeki ölçeği (genişlik, boy, derinlik) parçanın kendi eksenlerine çevirir;
-- içe aktarıcı parçayı döndürmüşse Size yanlış eksende ölçeklenmesin
local function localScale(cf: CFrame, kk: Vector3): Vector3
	local function along(axis: Vector3): number
		return math.abs(axis.X) * kk.X + math.abs(axis.Y) * kk.Y + math.abs(axis.Z) * kk.Z
	end
	return Vector3.new(along(cf.RightVector), along(cf.UpVector), along(cf.LookVector))
end

-- R15 iskeletini mesh gövdenin eklem noktalarına taşır
local function fitRig(character: Model, k: Vector3): boolean
	local centers: { [string]: Vector3 } = { HumanoidRootPart = MeshRig.RootCenter }
	for name, info in pairs(MeshRig.Parts) do
		centers[name] = info.Center
		local p = character:FindFirstChild(name)
		if not (p and p:IsA("BasePart")) then
			return false
		end
	end
	for name, j in pairs(MeshRig.Joints) do
		local p0, p1 = character:FindFirstChild(j.Part0), character:FindFirstChild(j.Part1)
		local motor = character:FindFirstChild(name, true)
		if p0 and p1 and motor and motor:IsA("Motor6D") then
			local c0 = (j.Pivot - centers[j.Part0]) * k
			local c1 = (j.Pivot - centers[j.Part1]) * k
			motor.C0 = CFrame.new(c0)
			motor.C1 = CFrame.new(c1)
			-- Humanoid eklemleri bu eklentilerden yeniden kurarsa aynı yere kursun
			local a0 = p0:FindFirstChild(name .. "RigAttachment")
			if a0 and a0:IsA("Attachment") then
				a0.Position = c0
			end
			local a1 = p1:FindFirstChild(name .. "RigAttachment")
			if a1 and a1:IsA("Attachment") then
				a1.Position = c1
			end
		end
	end
	for name, info in pairs(MeshRig.Parts) do
		local p = character:FindFirstChild(name) :: BasePart
		p.Size = info.Size * k
		p.Transparency = 1
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.HipHeight = MeshRig.HipHeight * k.Y
	end
	return true
end

-- Config.BeardNames: 0 Yok, 1 Kirli, 2 Bıyık, 3 Tam, 4 Keçi (kirli sakal, tam sakal kabuğunu açık renkle kullanır)
local BEARD = { [1] = "Tam", [2] = "Biyik", [3] = "Tam", [4] = "Keci" }

-- Yüzler (Config.Appearance.Faces = 6): kafa oranı (genişlik, boy, derinlik)
local FACES = {
	Vector3.new(1, 1, 1),
	Vector3.new(1.05, 0.98, 1.0), -- geniş çene
	Vector3.new(0.95, 1.04, 0.98), -- uzun yüz
	Vector3.new(1.03, 1.03, 1.03), -- iri
	Vector3.new(0.96, 0.97, 0.98), -- ince
	Vector3.new(1.06, 1.0, 1.04), -- yuvarlak
}
-- krampon modelleri: 1 Klasik (tek renk), 2 Hız (beyaz taban), 3 Kontrol (siyah örgü bilek),
-- 4 Retro (siyah gövde, beyaz taban)
local RETRO = Color3.fromRGB(16, 18, 22)
local SOLE_WHITE = Color3.fromRGB(242, 242, 242)
local SHIN_PAD = Color3.fromRGB(237, 237, 237)

local FABRIC = { Shirt = true, Stripe = true, Sleeve = true, Trim = true, Shorts = true, Sock = true, SockTop = true, SockBand = true }

--[[
	colors = { skin, hair, boot, glove, long (uzun kol), keeper, hairStyle, beard, face, bootModel, shortSocks }
]]
function MeshBody.Build(character: Model, look, kit, colors, k: Vector3): boolean
	local data = MeshBody.Load()
	if not data then
		return false
	end
	if not fitRig(character, k) then
		return false
	end
	local pattern = kit.Pattern or "Duz"
	-- saç: 1 Sıfır ve 8 Kel kafa derisi kabuğunu, diğerleri modelin saçını kullanır
	local style = colors.hairStyle or 2
	local shaved = style == 1 or style == 8
	local beardWant = BEARD[colors.beard or 0]
	-- yüz: kafa oranı ve kaş kalınlığı (çift sıradaki yüzlerde kalın kaş)
	local face = math.clamp(colors.face or 1, 1, #FACES)
	local fs = FACES[face]
	local brow = if face % 2 == 0 then "Kalin" else "Ince"
	local bootModel = colors.bootModel or 1
	local short = colors.shortSocks == true
	for _, pc in ipairs(data.pieces) do
		local r = pc.role
		if r == "Shirt" or r == "Stripe" then
			if pc.pattern ~= nil and pc.pattern ~= pattern then
				continue
			end
		elseif r == "Beard" then
			if pc.pattern ~= beardWant then
				continue
			end
		elseif r == "Hair" then
			-- saç modelleri S2..S7 (2 Kısa: modelin kendi saçı); Sıfır ve Kel kafa derisini kullanır
			if shaved or (pc.pattern ~= nil and pc.pattern ~= "S" .. tostring(style)) then
				continue
			end
		elseif r == "Brow" then
			if pc.pattern ~= nil and pc.pattern ~= brow then
				continue
			end
		elseif r == "Scalp" then
			if not shaved then
				continue
			end
		end
		local holder = character:FindFirstChild(pc.part) :: BasePart
		local color, tag = colors.skin, nil
		local role = pc.role
		local isArm = string.find(pc.part, "Arm") ~= nil
		if role == "Skin" then
			if colors.long and isArm then
				color, tag = kit.Sleeve, "Sleeve" -- uzun kol: kol derisi forma kolu olur
			elseif colors.keeper and string.find(pc.part, "Hand") then
				color = colors.glove
			end
		elseif role == "Hair" then
			color = colors.hair
		elseif role == "Scalp" then
			color = if style == 8 then colors.skin:Lerp(Color3.new(0, 0, 0), 0.06) else colors.hair:Lerp(colors.skin, 0.4)
		elseif role == "Beard" then
			color = if colors.beard == 1 then colors.hair:Lerp(colors.skin, 0.5) else colors.hair
		elseif role == "Brow" then
			color = colors.hair:Lerp(Color3.new(0, 0, 0), 0.1)
		elseif role == "Boot" then
			color = if bootModel == 4 then RETRO else colors.boot
		elseif role == "BootSole" then
			color = if bootModel == 2 or bootModel == 4 then SOLE_WHITE else colors.boot:Lerp(Color3.new(0, 0, 0), 0.35)
		elseif role == "BootCollar" then
			color = if bootModel == 3 or bootModel == 4 then RETRO else colors.boot
		elseif role == "SockTop" then
			-- kısa tozlukta tozluk aşağı katlanır, tekmelik görünür
			if short then
				color = SHIN_PAD
			else
				color, tag = kit.Sock, "Sock"
			end
		elseif role == "SockBand" then
			if short then
				color, tag = kit.Trim, "Trim"
			else
				color, tag = kit.Sock, "Sock"
			end
		elseif role == "Trim" and short and pc.part:find("LowerLeg") then
			color = colors.skin -- kısa tozlukta dizdeki bant yerine ten
		elseif kit[role] then
			color, tag = kit[role], role
		end
		local m = pc.mesh:Clone()
		m.Name = "FK_Mesh"
		m.Anchored = false
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.Massless = true
		m.CastShadow = true
		m.TextureID = ""
		local kk = if pc.part == "Head" then k * fs else k
		m.Size = pc.size * localScale(pc.offset, kk)
		m.Color = color
		m.Material = if FABRIC[role] or tag == "Sleeve" then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		m:SetAttribute("Role", role)
		if tag then
			m:SetAttribute("FK", tag)
		end
		m.CFrame = holder.CFrame * CFrame.new(pc.offset.Position * kk) * pc.offset.Rotation
		local w = Instance.new("WeldConstraint")
		w.Part0 = holder
		w.Part1 = m
		w.Parent = m
		m.Parent = character
	end
	return true
end

return MeshBody
