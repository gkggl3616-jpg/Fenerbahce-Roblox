--[[
	Config
	Oyundaki bütün ayar sayıları, renkler, kademeler ve yetenek zincirleri burada durur.
	Başka hiçbir modül sabit sayı gömmez; hepsi buradan okur.
]]

local Config = {}

Config.Version = 1
Config.DataStoreName = "FenerKariyer_v1"
Config.LeaderboardName = "FenerKariyer_Guc_v1"

-- Topluluğun yükleyeceği görsel ve sesler. Boş bırakılırsa yer tutucu kullanılır.
Config.Assets = {
	Crest = "", -- "rbxassetid://..." (Fenerbahçe arması)
	ClickSound = "",
	ConfirmSound = "",
	ErrorSound = "",
	RewardSound = "",
	WhooshSound = "",
}

Config.Performance = {
	TargetFps = 90, -- cihaz ve Roblox izin verdiği kadar; çoğu telefonda üst sınır 60'tır
	LowDetailFps = 45, -- bunun altına düşerse düşük detay moduna geç
}

-- Renkler (arayüz teması bunları kullanır)
Config.Colors = {
	Yellow = Color3.fromRGB(255, 230, 0),
	Navy = Color3.fromRGB(11, 23, 71),
	Blue = Color3.fromRGB(26, 45, 134),
	Ground = Color3.fromRGB(5, 11, 38),
	Text = Color3.fromRGB(238, 241, 255),
	Muted = Color3.fromRGB(154, 166, 223),
	Good = Color3.fromRGB(61, 220, 132),
	Bad = Color3.fromRGB(255, 107, 107),
	Gold = Color3.fromRGB(255, 200, 61),
	White = Color3.fromRGB(255, 255, 255),
}

-- Arayüz hareket süreleri (saniye)
Config.Motion = {
	In = 0.3,
	Out = 0.18,
	Stagger = 0.04,
	Hover = 0.12,
	Press = 0.08,
	CountUp = 0.6,
	Wipe = 0.45,
	Toast = 3.2,
}

Config.Positions = { "Kaleci", "Defans", "OrtaSaha", "Forvet" }
Config.PositionNames = { Kaleci = "Kaleci", Defans = "Defans", OrtaSaha = "Orta Saha", Forvet = "Forvet" }

-- Özellikler
Config.Stats = { "Hiz", "TopKontrolu", "Pas", "Sut", "Defans", "Fizik" }
Config.StatNames = {
	Hiz = "Hız",
	TopKontrolu = "Top Kontrolü",
	Pas = "Pas",
	Sut = "Şut",
	Defans = "Defans",
	Fizik = "Fizik",
}
Config.StatMax = 10
-- Mevkiye göre başlangıç özellikleri
Config.StartStats = {
	Kaleci = { Hiz = 1, TopKontrolu = 1, Pas = 2, Sut = 1, Defans = 2, Fizik = 3 },
	Defans = { Hiz = 2, TopKontrolu = 1, Pas = 1, Sut = 1, Defans = 3, Fizik = 2 },
	OrtaSaha = { Hiz = 2, TopKontrolu = 2, Pas = 3, Sut = 1, Defans = 1, Fizik = 1 },
	Forvet = { Hiz = 3, TopKontrolu = 2, Pas = 1, Sut = 3, Defans = 1, Fizik = 1 },
}
function Config.StatCost(currentLevel: number): number
	return 60 * currentLevel * currentLevel
end

-- Seviye
Config.MaxLevel = 30
function Config.XpForLevel(level: number): number
	return 80 + level * 45
end

-- Yetenek zincirleri: sırayla açılır. { ad, seviye şartı, bakiye }
Config.SkillChains = {
	Sut = {
		Name = "Şut",
		Skills = {
			{ Id = "Normal", Name = "Normal şut", Level = 1, Cost = 0 },
			{ Id = "Plase", Name = "Plase", Level = 2, Cost = 150 },
			{ Id = "Fuze", Name = "Füze", Level = 5, Cost = 400 },
			{ Id = "Asirtma", Name = "Aşırtma", Level = 8, Cost = 700 },
			{ Id = "Vole", Name = "Vole", Level = 11, Cost = 1100 },
			{ Id = "Rovesata", Name = "Röveşata", Level = 15, Cost = 1800 },
			{ Id = "SerbestVurus", Name = "Serbest vuruş ustası", Level = 20, Cost = 2800 },
		},
	},
	Calim = {
		Name = "Çalım",
		Skills = {
			{ Id = "VucutCalimi", Name = "Vücut çalımı", Level = 1, Cost = 0 },
			{ Id = "TopSurukleme", Name = "Top sürükleme", Level = 3, Cost = 200 },
			{ Id = "Marsilya", Name = "Marsilya", Level = 6, Cost = 450 },
			{ Id = "Nutmeg", Name = "Nutmeg", Level = 9, Cost = 800 },
			{ Id = "Elastico", Name = "Elastico", Level = 13, Cost = 1300 },
			{ Id = "Rabona", Name = "Rabona", Level = 17, Cost = 2000 },
			{ Id = "Gokkusagi", Name = "Gökkuşağı", Level = 22, Cost = 3000 },
		},
	},
	Hava = {
		Name = "Hava",
		Skills = {
			{ Id = "Ziplama", Name = "Zıplama", Level = 1, Cost = 0 },
			{ Id = "Kafa", Name = "Kafa vuruşu", Level = 3, Cost = 200 },
			{ Id = "GucluKafa", Name = "Güçlü kafa", Level = 7, Cost = 600 },
			{ Id = "UcanKafa", Name = "Uçan kafa", Level = 12, Cost = 1200 },
			{ Id = "Makas", Name = "Makas vuruşu", Level = 18, Cost = 2200 },
		},
	},
	Defans = {
		Name = "Defans",
		Skills = {
			{ Id = "AyaktaMudahale", Name = "Ayakta müdahale", Level = 1, Cost = 0 },
			{ Id = "PasArasi", Name = "Pas arası", Level = 3, Cost = 200 },
			{ Id = "Omuz", Name = "Omuz mücadelesi", Level = 6, Cost = 450 },
			{ Id = "Kayma", Name = "Kayarak müdahale", Level = 9, Cost = 800 },
			{ Id = "Blok", Name = "Blok", Level = 13, Cost = 1300 },
			{ Id = "SonAdam", Name = "Son adam", Level = 18, Cost = 2200 },
		},
	},
	OzelGuc = {
		Name = "Özel güç",
		Skills = {
			{ Id = "Turbo", Name = "Turbo", Level = 4, Cost = 300 },
			{ Id = "DemirAdam", Name = "Demir adam", Level = 10, Cost = 900 },
			{ Id = "KaptanLider", Name = "Kaptan lider", Level = 16, Cost = 1800 },
			{ Id = "EfsaneAn", Name = "Efsane an", Level = 25, Cost = 4000 },
		},
	},
	Kaleci = {
		Name = "Kaleci",
		OnlyPosition = "Kaleci",
		Skills = {
			{ Id = "Plonjon", Name = "Plonjon", Level = 1, Cost = 0 },
			{ Id = "Yumruk", Name = "Yumruk", Level = 4, Cost = 300 },
			{ Id = "BireBir", Name = "Bire bir çıkış", Level = 8, Cost = 700 },
			{ Id = "UzunDegaj", Name = "Uzun degaj", Level = 12, Cost = 1200 },
			{ Id = "PenaltiUzmani", Name = "Penaltı uzmanı", Level = 18, Cost = 2200 },
		},
	},
}
Config.SkillChainOrder = { "Sut", "Calim", "Hava", "Defans", "OzelGuc", "Kaleci" }

-- Kulüp kademeleri
Config.Tiers = {
	{
		Id = 1,
		League = "Amatör Lig",
		Stadium = "Mahalle Sahası",
		Capacity = 150,
		Light = "BulutluGunduz",
		BotPower = { 30, 40 },
		MatchIncome = 50,
	},
	{
		Id = 2,
		League = "3. Lig",
		Stadium = "İlçe Stadı",
		Capacity = 1800,
		Light = "OgledenSonra",
		BotPower = { 40, 52 },
		MatchIncome = 150,
	},
	{
		Id = 3,
		League = "2. Lig",
		Stadium = "Şehir Stadı",
		Capacity = 8500,
		Light = "GunBatimi",
		BotPower = { 52, 64 },
		MatchIncome = 400,
	},
	{
		Id = 4,
		League = "1. Lig",
		Stadium = "Modern Stadyum",
		Capacity = 21000,
		Light = "Alacakaranlik",
		BotPower = { 64, 75 },
		MatchIncome = 900,
	},
	{ Id = 5, League = "Süper Lig", Stadium = "Arena", Capacity = 34000, Light = "Gece", BotPower = { 75, 86 }, MatchIncome = 1800 },
	{
		Id = 6,
		League = "Fenerbahçe",
		Stadium = "Şükrü Saracoğlu",
		Capacity = 47800,
		Light = "GeceMaci",
		BotPower = { 86, 95 },
		MatchIncome = 3500,
	},
}
Config.Season = { Teams = 6, Matches = 10, PromoteTop = 2 }
Config.FenerbahceOffer = { Level = 25, Power = 85 }

-- Tesis modülleri (en yüksek seviye)
Config.Facilities = {
	Cim = { Name = "Çim kalitesi", Max = 3, Cost = { 500, 900, 1500 } },
	TribunEki = { Name = "Tribün eki", Max = 2, Cost = { 1200, 1800 } },
	Aydinlatma = { Name = "Aydınlatma", Max = 2, Cost = { 700, 1100 } },
	Soyunma = { Name = "Soyunma odası", Max = 2, Cost = { 500, 700 } },
	Antrenman = { Name = "Antrenman sahası", Max = 2, Cost = { 600, 1000 } },
	Saglik = { Name = "Sağlık merkezi", Max = 2, Cost = { 800, 1200 } },
}

-- Görünüm sınırları (sunucu bu aralıkları doğrular)
Config.Appearance = {
	HeightMin = 165,
	HeightMax = 195,
	Builds = { "Ince", "Atletik", "Guclu" },
	SkinTones = 6,
	Faces = 6,
	HairStyles = 8,
	Beards = 4,
	BootModels = 4,
	KitPatterns = { "Cubuklu", "Duz", "Kusakli" },
	CrestShapes = 4,
}

Config.Name = { Min = 3, Max = 16 }
Config.ClubName = { Min = 3, Max = 20 }
Config.Economy = { StartCoins = 100, StartClubFunds = 0 }
Config.Remote = { MinInterval = 0.2 } -- aynı oyuncudan iki istek arası en az süre
Config.Data = { AutoSave = 90, Retries = 4, LockTimeout = 600 }

-- Genel güç (sıralama ve teklif şartı için)
function Config.Power(stats: { [string]: number }, level: number): number
	local sum = 0
	for _, key in ipairs(Config.Stats) do
		sum += stats[key] or 1
	end
	return math.floor(20 + sum * 1.0 + level * 1.2 + 0.5)
end

return Config
