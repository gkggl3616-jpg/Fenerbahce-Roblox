--[[
	Kits
	Forma tanımları. Bir oyuncunun verisinden hangi formayı giyeceğini hesaplar.
	Renkler sarı-lacivert ailesiyle sınırlıdır.
]]

local Config = require(script.Parent.Config)
local C = Config.Colors

local Kits = {}

Kits.Fenerbahce = {
	Pattern = "Cubuklu",
	Shirt = C.Yellow,
	Stripe = C.Navy,
	Sleeve = C.Navy,
	Trim = C.Yellow,
	Shorts = C.White,
	Sock = C.Navy,
	Ink = C.White,
	InkStroke = C.Navy,
}

-- Oyuncunun kendi kulübü: desene göre
Kits.Club = {
	Cubuklu = {
		Pattern = "Cubuklu",
		Shirt = C.Yellow,
		Stripe = C.Navy,
		Sleeve = C.Yellow,
		Trim = C.Navy,
		Shorts = C.Navy,
		Sock = C.Yellow,
		Ink = C.White,
		InkStroke = C.Navy,
	},
	Duz = {
		Pattern = "Duz",
		Shirt = C.Navy,
		Stripe = C.Yellow,
		Sleeve = C.Navy,
		Trim = C.Yellow,
		Shorts = C.Navy,
		Sock = C.Navy,
		Ink = C.Yellow,
		InkStroke = C.Navy,
	},
	Kusakli = {
		Pattern = "Kusakli",
		Shirt = C.White,
		Stripe = C.Navy,
		Sleeve = C.White,
		Trim = C.Yellow,
		Shorts = C.Navy,
		Sock = C.White,
		Ink = C.Navy,
		InkStroke = C.White,
	},
}

Kits.Keeper = {
	Pattern = "Duz",
	Shirt = Color3.fromRGB(25, 181, 106),
	Stripe = Color3.fromRGB(13, 122, 69),
	Sleeve = Color3.fromRGB(13, 122, 69),
	Trim = C.Navy,
	Shorts = Color3.fromRGB(13, 122, 69),
	Sock = Color3.fromRGB(25, 181, 106),
	Ink = C.White,
	InkStroke = C.Navy,
}
Kits.Rival = {
	Pattern = "Duz",
	Shirt = Color3.fromRGB(238, 243, 244),
	Stripe = Color3.fromRGB(15, 143, 128),
	Sleeve = Color3.fromRGB(15, 143, 128),
	Trim = C.White,
	Shorts = Color3.fromRGB(15, 143, 128),
	Sock = Color3.fromRGB(238, 243, 244),
	Ink = Color3.fromRGB(12, 90, 80),
	InkStroke = C.White,
}
Kits.Referee = {
	Pattern = "Duz",
	Shirt = Color3.fromRGB(22, 22, 26),
	Stripe = Color3.fromRGB(22, 22, 26),
	Sleeve = Color3.fromRGB(22, 22, 26),
	Trim = Color3.fromRGB(190, 255, 60),
	Shorts = Color3.fromRGB(22, 22, 26),
	Sock = Color3.fromRGB(22, 22, 26),
	Ink = C.White,
	InkStroke = Color3.fromRGB(22, 22, 26),
}
Kits.RivalKeeper = {
	Pattern = "Duz",
	Shirt = Color3.fromRGB(240, 138, 36),
	Stripe = Color3.fromRGB(184, 95, 16),
	Sleeve = Color3.fromRGB(184, 95, 16),
	Trim = Color3.fromRGB(34, 34, 34),
	Shorts = Color3.fromRGB(184, 95, 16),
	Sock = Color3.fromRGB(240, 138, 36),
	Ink = C.White,
	InkStroke = Color3.fromRGB(34, 34, 34),
}

function Kits.For(position: string, kitPattern: string, atFenerbahce: boolean?)
	if position == "Kaleci" then
		return Kits.Keeper
	end
	if atFenerbahce then
		return Kits.Fenerbahce
	end
	return Kits.Club[kitPattern] or Kits.Club.Cubuklu
end

return Kits
