--[[
	Squads
	Kulüpler, teknik direktörler ve kadrolar. Rakip kulüplerin adı, renkleri ve arması hazırdır;
	oyuncunun kulübü kendi adını ve renklerini kullanır. Her futbolcunun kendi özellikleri vardır.
	Bütün adlar kurgudur; aynı kulüp her zaman aynı kadroyu verir (tohumlu üretim).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Squads = {}

local rgb = Color3.fromRGB

-- Kademe başına 5 rakip kulüp (lig 6 takımlı). Crest: 1 kalkan, 2 daire, 3 altıgen, 4 flama, 5 elmas
Squads.Clubs = {
	{
		{ Name = "Yeldeğirmeni Spor", Abbr = "YLD", Coach = "Rıfat Karaduman", A = rgb(196, 48, 48), B = rgb(250, 250, 250), Crest = 2 },
		{ Name = "Kuşdili Gücü", Abbr = "KŞD", Coach = "Sabri Yılmazer", A = rgb(34, 139, 90), B = rgb(20, 20, 24), Crest = 1 },
		{ Name = "Hasanpaşa İdman", Abbr = "HSP", Coach = "Nevzat Oktay", A = rgb(240, 140, 30), B = rgb(30, 30, 80), Crest = 4 },
		{ Name = "Acıbadem Gençlik", Abbr = "ACB", Coach = "Cemil Aydoğdu", A = rgb(120, 60, 160), B = rgb(245, 245, 245), Crest = 3 },
		{ Name = "Rasimpaşa SK", Abbr = "RSM", Coach = "Halit Erçetin", A = rgb(60, 140, 210), B = rgb(250, 250, 250), Crest = 5 },
	},
	{
		{ Name = "Karşıyaka Yıldızı", Abbr = "KYY", Coach = "Orhan Denizli", A = rgb(200, 40, 60), B = rgb(20, 110, 60), Crest = 1 },
		{ Name = "Bozkır Belediye", Abbr = "BZK", Coach = "Mümtaz Akın", A = rgb(230, 190, 40), B = rgb(140, 30, 30), Crest = 3 },
		{ Name = "Kıyı Demirspor", Abbr = "KDS", Coach = "Selahattin Uçar", A = rgb(40, 60, 130), B = rgb(160, 200, 240), Crest = 2 },
		{ Name = "Yayla Kartalları", Abbr = "YYK", Coach = "Bekir Tunalı", A = rgb(20, 20, 24), B = rgb(250, 250, 250), Crest = 4 },
		{ Name = "Ova Şekerspor", Abbr = "OVŞ", Coach = "İlhami Sezgin", A = rgb(30, 150, 110), B = rgb(250, 250, 250), Crest = 5 },
	},
	{
		{ Name = "Ege Limanspor", Abbr = "EGL", Coach = "Tayfun Özbek", A = rgb(30, 110, 190), B = rgb(250, 220, 60), Crest = 1 },
		{ Name = "Toros Şimşekleri", Abbr = "TRŞ", Coach = "Kenan Bozdağ", A = rgb(230, 90, 30), B = rgb(20, 20, 24), Crest = 5 },
		{ Name = "Kapadokya FK", Abbr = "KPD", Coach = "Adnan Güleryüz", A = rgb(170, 60, 80), B = rgb(250, 240, 220), Crest = 3 },
		{ Name = "Marmara Atletik", Abbr = "MRM", Coach = "Levent Soylu", A = rgb(20, 130, 130), B = rgb(250, 250, 250), Crest = 2 },
		{ Name = "Trakya Rüzgarı", Abbr = "TRK", Coach = "Ziya Kocabaş", A = rgb(90, 50, 140), B = rgb(240, 200, 60), Crest = 4 },
	},
	{
		{ Name = "Anadolu Kaplanları", Abbr = "AKP", Coach = "Ferit Aksoylu", A = rgb(230, 120, 20), B = rgb(20, 20, 24), Crest = 1 },
		{ Name = "Karadeniz Fırtına", Abbr = "KRF", Coach = "Temel Hacıoğlu", A = rgb(120, 20, 50), B = rgb(100, 180, 230), Crest = 3 },
		{ Name = "Başkent Birliği", Abbr = "BŞB", Coach = "Ercüment Sayın", A = rgb(200, 30, 40), B = rgb(250, 250, 250), Crest = 2 },
		{ Name = "Akdeniz Yelkenspor", Abbr = "AKY", Coach = "Bülent Karaca", A = rgb(20, 150, 200), B = rgb(250, 250, 250), Crest = 5 },
		{
			Name = "Güney Yıldırım",
			Abbr = "GNY",
			Coach = "Şükrü Altıntaş",
			A = rgb(30, 120, 60),
			B = rgb(240, 210, 60),
			Crest = 4,
		},
	},
	{
		{ Name = "Boğaziçi Kartal", Abbr = "BĞK", Coach = "Tuncay Sarıoğlu", A = rgb(24, 24, 28), B = rgb(250, 250, 250), Crest = 1 },
		{ Name = "Haliç Aslanları", Abbr = "HLÇ", Coach = "Fikret Uzunoğlu", A = rgb(190, 30, 40), B = rgb(250, 190, 40), Crest = 2 },
		{ Name = "Kuzey Fırtınası", Abbr = "KZF", Coach = "Şenol Akçay", A = rgb(110, 20, 50), B = rgb(90, 170, 230), Crest = 3 },
		{ Name = "İpekyolu FK", Abbr = "İPK", Coach = "Aykut Demirel", A = rgb(230, 110, 30), B = rgb(30, 60, 140), Crest = 5 },
		{
			Name = "Başakşehir Yıldızı",
			Abbr = "BŞY",
			Coach = "Abdullah Turan",
			A = rgb(240, 120, 30),
			B = rgb(20, 30, 70),
			Crest = 4,
		},
	},
}
Squads.Clubs[6] = Squads.Clubs[5]

local FIRST = {
	"Ahmet",
	"Mehmet",
	"Emre",
	"Burak",
	"Can",
	"Deniz",
	"Efe",
	"Furkan",
	"Gökhan",
	"Hakan",
	"İsmail",
	"Kerem",
	"Levent",
	"Mert",
	"Onur",
	"Ozan",
	"Polat",
	"Rüzgar",
	"Serkan",
	"Tolga",
	"Umut",
	"Volkan",
	"Yiğit",
	"Zafer",
	"Barış",
	"Çağan",
	"Doruk",
	"Eren",
	"Kaan",
	"Tuna",
	"Alper",
	"Berk",
	"Sinan",
	"Taylan",
	"Koray",
	"Batuhan",
}
local LAST = {
	"Yıldırım",
	"Kaya",
	"Demirci",
	"Aslan",
	"Çelik",
	"Şahin",
	"Öztürk",
	"Aydın",
	"Arslan",
	"Doğan",
	"Kılıç",
	"Çetin",
	"Koç",
	"Kurt",
	"Özkan",
	"Şimşek",
	"Polat",
	"Korkmaz",
	"Erdem",
	"Güneş",
	"Aktaş",
	"Bulut",
	"Yavuz",
	"Tekin",
	"Bozkurt",
	"Karaca",
	"Uysal",
	"Sönmez",
	"Ateş",
	"Duman",
	"Tuncer",
	"Eroğlu",
	"Akgül",
	"Savaş",
	"Ünal",
	"Toprak",
}

Squads.Roles = { "KL", "SLB", "STP", "STP", "SĞB", "SLO", "MO", "MO", "SĞO", "SF", "SF" }
local NUMBERS = { 1, 2, 4, 5, 3, 7, 6, 8, 11, 9, 10 }
-- Mevkiye göre özellik eğilimi: Hız, Şut, Pas, Top, Defans, Fizik
local BIAS = {
	KL = { -8, -30, -6, -10, 6, 6 },
	SLB = { 6, -12, 2, 0, 4, 0 },
	["SĞB"] = { 6, -12, 2, 0, 4, 0 },
	STP = { -4, -16, -4, -6, 10, 8 },
	SLO = { 8, 0, 4, 6, -8, -4 },
	["SĞO"] = { 8, 0, 4, 6, -8, -4 },
	MO = { 0, -2, 8, 6, 0, 0 },
	SF = { 4, 10, -2, 4, -16, 2 },
}
Squads.StatOrder = { "Hız", "Şut", "Pas", "Top", "Def", "Fiz" }

local function rng(seed: number): () -> number
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function()
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

local function hash(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return h
end

-- Adın baş harfi (Türkçe harfler birden çok bayt tutar; bayt olarak kesilmez)
local function initial(name: string): string
	for _, code in utf8.codes(name) do
		return utf8.char(code)
	end
	return ""
end

-- Bir kulübün 11'i. avg: ortalama güç (0-99)
function Squads.Build(club, avg: number)
	local R = rng(hash(club.Name) + 17)
	local players = {}
	for slot = 1, 11 do
		local role = Squads.Roles[slot]
		local rating = math.clamp(math.floor(avg + (R() - 0.5) * 12 + 0.5), 20, 99)
		local stats = {}
		local bias = BIAS[role]
		for i = 1, 6 do
			stats[i] = math.clamp(math.floor(rating + bias[i] + (R() - 0.5) * 10 + 0.5), 10, 99)
		end
		players[slot] = {
			slot = slot,
			number = NUMBERS[slot],
			name = initial(FIRST[1 + math.floor(R() * #FIRST)]) .. ". " .. LAST[1 + math.floor(R() * #LAST)],
			full = "",
			role = role,
			rating = rating,
			stats = stats,
			pace = math.clamp(1 + (stats[1] - avg) / 120, 0.9, 1.1), -- takım ortalamasına göre hız çarpanı
		}
	end
	return players
end

-- Sıradaki rakip: sezon içindeki maç sırasına göre döner
function Squads.Opponent(tier: number, seasonNumber: number, played: number)
	local list = Squads.Clubs[math.clamp(tier, 1, #Squads.Clubs)]
	return list[1 + (played + seasonNumber * 2) % #list]
end

-- Maç eşleşmesi: iki kulüp, kadrolar ve teknik direktörler
function Squads.Fixture(data)
	local tierId = if data.career and data.career.atFenerbahce then 6 else data.club.tier
	local tier = Config.Tiers[tierId]
	local avg = (tier.BotPower[1] + tier.BotPower[2]) / 2
	local season = data.club.season or { number = 1, played = 0 }
	local oppDef = Squads.Opponent(tierId, season.number, season.played)
	local homeName = if tierId == 6 then "Fenerbahçe" elseif data.club.name ~= "" then data.club.name else "Kulübüm"
	local homeDef = {
		Name = homeName,
		Abbr = if tierId == 6 then "FB" elseif data.club.abbr ~= "" then data.club.abbr else "EV",
		Coach = "",
		A = Config.Colors.Yellow,
		B = Config.Colors.Navy,
		Crest = data.club.crestShape or 1,
		CrestSpec = if tierId == 6 then nil else data.club.crest, -- oyuncunun tasarladığı arma
	}
	local R = rng(hash(homeName) + 99)
	homeDef.Coach = FIRST[1 + math.floor(R() * #FIRST)] .. " " .. LAST[1 + math.floor(R() * #LAST)]
	local home = Squads.Build(homeDef, avg + 1)
	local slot = Config.FormationSlot[data.position] or 11
	local me = home[slot]
	me.name = data.name
	me.number = data.number or me.number
	me.rating = math.clamp(data.power or 30, 1, 99)
	me.human = true
	local s = data.stats or {}
	local function pct(key: string): number
		return math.clamp(math.floor(25 + (s[key] or 1) / Config.StatMax * 70 + 0.5), 1, 99)
	end
	me.stats = { pct("Hiz"), pct("Sut"), pct("Pas"), pct("TopKontrolu"), pct("Defans"), pct("Fizik") }
	-- aynı forma numarası iki kişide olmasın
	for _, p in ipairs(home) do
		if p ~= me and p.number == me.number then
			p.number = NUMBERS[slot]
		end
	end
	return {
		tier = tierId,
		league = tier.League,
		stadium = tier.Stadium,
		avg = avg,
		matchNo = (season.played or 0) + 1,
		home = { club = homeDef, players = home },
		away = { club = oppDef, players = Squads.Build(oppDef, avg) },
	}
end

return Squads
