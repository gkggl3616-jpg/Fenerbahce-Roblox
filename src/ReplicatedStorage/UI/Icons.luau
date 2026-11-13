--[[
	Icons
	Çerçevelerden çizilen küçük simgeler (resim dosyası gerektirmez). Düğmelerde ve başlıklarda kullanılır.
	Icons.Build(name, pixels, color) -> Frame
	Adlar: Ball, Pitch, Star, Shield, Table, Cart, Calendar, Trophy, Building, Whistle
]]

local Icons = {}

local function box(parent: Instance, x: number, y: number, w: number, h: number, c: Color3, round: number?, rot: number?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = c
	f.BorderSizePixel = 0
	f.Rotation = rot or 0
	if round then
		local u = Instance.new("UICorner")
		u.CornerRadius = UDim.new(round, 0)
		u.Parent = f
	end
	f.Parent = parent
	return f
end

local function ring(parent: Instance, x: number, y: number, w: number, h: number, c: Color3, round: number, thickness: number): Frame
	local f = box(parent, x, y, w, h, c, round)
	f.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = c
	s.Thickness = thickness
	s.Parent = f
	return f
end

local DRAW: { [string]: (Frame, Color3, number) -> () } = {
	Ball = function(f, c, t)
		ring(f, 0.5, 0.5, 0.78, 0.78, c, 0.5, t)
		box(f, 0.5, 0.5, 0.3, 0.3, c, 0.25, 18)
	end,
	Pitch = function(f, c, t)
		ring(f, 0.5, 0.5, 0.86, 0.62, c, 0.12, t)
		box(f, 0.5, 0.5, 0.05, 0.62, c)
		ring(f, 0.5, 0.5, 0.26, 0.26, c, 0.5, t)
	end,
	Star = function(f, c)
		box(f, 0.5, 0.5, 0.56, 0.56, c, 0.12)
		box(f, 0.5, 0.5, 0.56, 0.56, c, 0.12, 45)
	end,
	Shield = function(f, c, t)
		ring(f, 0.5, 0.46, 0.62, 0.74, c, 0.3, t)
		box(f, 0.5, 0.46, 0.14, 0.9, c, nil, 28)
	end,
	Table = function(f, c)
		box(f, 0.24, 0.66, 0.16, 0.36, c, 0.2)
		box(f, 0.5, 0.52, 0.16, 0.64, c, 0.2)
		box(f, 0.76, 0.6, 0.16, 0.48, c, 0.2)
	end,
	Cart = function(f, c, t)
		ring(f, 0.54, 0.44, 0.6, 0.38, c, 0.18, t)
		box(f, 0.16, 0.24, 0.2, 0.07, c, 0.5)
		box(f, 0.4, 0.8, 0.14, 0.14, c, 0.5)
		box(f, 0.7, 0.8, 0.14, 0.14, c, 0.5)
	end,
	Calendar = function(f, c, t)
		ring(f, 0.5, 0.54, 0.74, 0.68, c, 0.14, t)
		box(f, 0.5, 0.3, 0.74, 0.16, c, 0.3)
		box(f, 0.36, 0.6, 0.12, 0.12, c, 0.3)
		box(f, 0.64, 0.6, 0.12, 0.12, c, 0.3)
	end,
	Trophy = function(f, c)
		box(f, 0.5, 0.34, 0.5, 0.42, c, 0.3)
		box(f, 0.5, 0.64, 0.12, 0.2, c)
		box(f, 0.5, 0.8, 0.44, 0.1, c, 0.4)
	end,
	Building = function(f, c, t)
		ring(f, 0.5, 0.56, 0.6, 0.66, c, 0.08, t)
		box(f, 0.38, 0.42, 0.12, 0.12, c)
		box(f, 0.62, 0.42, 0.12, 0.12, c)
		box(f, 0.5, 0.76, 0.16, 0.26, c)
	end,
	Whistle = function(f, c, t)
		ring(f, 0.4, 0.58, 0.5, 0.5, c, 0.5, t)
		box(f, 0.74, 0.4, 0.36, 0.16, c, 0.3)
	end,
}

function Icons.Build(name: string, pixels: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = "Icon"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(pixels, pixels)
	local draw = DRAW[name] or DRAW.Ball
	draw(f, color, math.max(1.5, pixels * 0.08))
	return f
end

return Icons
