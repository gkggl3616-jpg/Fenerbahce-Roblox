--[[
	Theme
	Arayüzün tasarım dili: renkler, yazı tipleri, köşe ve çizgi ölçüleri.
	Bütün bileşenler buradan okur; ekranlarda sabit renk yazılmaz.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Theme = {}

Theme.Color = Config.Colors

local FAMILY = "rbxasset://fonts/families/GothamSSm.json"
Theme.Font = {
	Display = Font.new(FAMILY, Enum.FontWeight.Heavy),
	Title = Font.new(FAMILY, Enum.FontWeight.Bold),
	Body = Font.new(FAMILY, Enum.FontWeight.Medium),
	Number = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

Theme.Corner = { Small = 6, Medium = 10, Large = 14 }
Theme.Stroke = 1.5
Theme.PanelTransparency = 0.12
Theme.Skew = 12 -- eğik kesim açısı (derece)
Theme.MinTouch = 76 -- mobilde en küçük dokunma hedefi (piksel)

-- Büyük harf (Türkçe i/ı dahil)
local MAP = { ["i"] = "İ", ["ı"] = "I", ["ş"] = "Ş", ["ğ"] = "Ğ", ["ü"] = "Ü", ["ö"] = "Ö", ["ç"] = "Ç" }
function Theme.Upper(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		table.insert(out, MAP[ch] or string.upper(ch))
	end
	return table.concat(out)
end

-- 1234567 -> "1.234.567"
function Theme.FormatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = string.reverse(string.gsub(string.reverse(s), "(%d%d%d)", "%1."))
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return out
end

return Theme
