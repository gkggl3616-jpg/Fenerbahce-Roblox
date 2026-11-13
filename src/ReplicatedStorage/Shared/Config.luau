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
	HoverSound = "",
	KickSound = "",
	PostSound = "",
	Whistle = "", -- hakem düdüğü ("rbxassetid://..."); boşsa yedek ses çalar
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
	-- Her zincirde yetenekler sırayla açılır; aynı tuş, açılan en üst hareketi oynatır.
	Sut = {
		Name = "Şut",
		Hint = "1-6 tuşlarıyla şut türü seçilir",
		Skills = {
			{ Id = "Shoot", Name = "Normal şut", Level = 1, Cost = 0, Info = "Dengeli, güvenilir vuruş" },
			{ Id = "Plase", Name = "Plase", Level = 2, Cost = 150, Info = "İç ayakla köşeye, isabetli" },
			{ Id = "Fuze", Name = "Füze", Level = 5, Cost = 400, Info = "Uzun gerilme, çok sert şut" },
			{ Id = "Asirtma", Name = "Aşırtma", Level = 8, Cost = 700, Info = "Kalecinin üstünden" },
			{ Id = "Vole", Name = "Vole", Level = 11, Cost = 1100, Info = "Havadaki topa gelişine" },
			{ Id = "Rovesata", Name = "Röveşata", Level = 15, Cost = 1800, Info = "Sırt üstü makas vuruşu" },
		},
	},
	Calim = {
		Name = "Çalım",
		Hint = "Q: açık olan en üst çalım",
		Skills = {
			{ Id = "VucutCalimi", Name = "Vücut çalımı", Level = 1, Cost = 0, Info = "Omuz ve kalça sahtesi" },
			{ Id = "Bisiklet", Name = "Bisiklet", Level = 3, Cost = 200, Info = "Topun üstünden çift ayak geçişi" },
			{ Id = "Marsilya", Name = "Marsilya", Level = 6, Cost = 450, Info = "Topla birlikte tam tur dönüş" },
			{ Id = "Elastico", Name = "Elastico", Level = 10, Cost = 900, Info = "Dış-iç ayak ani yön değişimi" },
			{ Id = "Gokkusagi", Name = "Gökkuşağı", Level = 15, Cost = 1800, Info = "Topu topukla rakibin üstünden aşır" },
		},
	},
	Hava = {
		Name = "Hava",
		Hint = "Boşluk: açık olan en üst hava hareketi",
		Skills = {
			{ Id = "Jump", Name = "Zıplama", Level = 1, Cost = 0, Info = "Yerinde yükselme" },
			{ Id = "Header", Name = "Kafa vuruşu", Level = 2, Cost = 150, Info = "Havadaki topa kafa" },
			{ Id = "GucluKafa", Name = "Güçlü kafa", Level = 6, Cost = 500, Info = "Gövdeyi yay gibi gerip sert kafa" },
			{ Id = "UcanKafa", Name = "Uçan kafa", Level = 10, Cost = 1000, Info = "Koşarken balıklama kafa" },
			{ Id = "Makas", Name = "Makas vuruşu", Level = 16, Cost = 2000, Info = "Koşarken havada yan makas" },
		},
	},
	Defans = {
		Name = "Defans",
		Hint = "C: müdahale · V: blok",
		Skills = {
			{ Id = "AyaktaMudahale", Name = "Ayakta müdahale", Level = 1, Cost = 0, Info = "Ayağı uzatıp topu çelme" },
			{ Id = "Omuz", Name = "Omuz mücadelesi", Level = 3, Cost = 200, Info = "Omuzla dengesini boz, topu al" },
			{ Id = "Kayma", Name = "Kayarak giriş", Level = 6, Cost = 450, Info = "Koşarken yerden kayarak" },
			{ Id = "Blok", Name = "Blok", Level = 10, Cost = 900, Info = "Şutun önüne gövdeyle gir" },
			{ Id = "UcanBlok", Name = "Uçan blok", Level = 15, Cost = 1800, Info = "Şuta doğru atlayarak kapat" },
		},
	},
	Kaleci = {
		Name = "Kaleci",
		OnlyPosition = "Kaleci",
		Hint = "Z / X: sola / sağa plonjon",
		Skills = {
			{ Id = "Plonjon", Name = "Plonjon", Level = 1, Cost = 0, Info = "Köşeye uzanma" },
		},
	},
}
Config.SkillChainOrder = { "Sut", "Calim", "Hava", "Defans", "Kaleci" }

-- Bir zincirde açık olan son yeteneğin sırası (ilk yetenek ücretsizse baştan açıktır)
function Config.SkillLevel(skills, chainId: string): number
	local chain = Config.SkillChains[chainId]
	local base = if chain and chain.Skills[1] and chain.Skills[1].Cost == 0 then 1 else 0
	return math.max(base, (skills and skills[chainId]) or 0)
end

-- Bir hareket açık mı? (hareket hiçbir zincirde yoksa her zaman açıktır)
function Config.ActionUnlocked(skills, action: string): boolean
	for id, chain in pairs(Config.SkillChains) do
		for i, sk in ipairs(chain.Skills) do
			if sk.Id == action then
				return Config.SkillLevel(skills, id) >= i
			end
		end
	end
	return true
end

-- Günlük görevler: her gün havuzdan üç tanesi seçilir (oyuncuya ve güne göre sabit)
Config.DailyTasks = {
	{ Id = "Gol2", Text = "Maçlarda 2 gol at", Stat = "goals", Goal = 2, Coins = 120, Xp = 60 },
	{ Id = "Gol4", Text = "Maçlarda 4 gol at", Stat = "goals", Goal = 4, Coins = 220, Xp = 110 },
	{ Id = "Mac2", Text = "2 maç oyna", Stat = "matches", Goal = 2, Coins = 100, Xp = 60 },
	{ Id = "Galibiyet", Text = "1 maç kazan", Stat = "wins", Goal = 1, Coins = 150, Xp = 80 },
	{ Id = "Kafa", Text = "Kafayla 1 gol at", Stat = "headers", Goal = 1, Coins = 180, Xp = 90 },
	{ Id = "Antrenman5", Text = "Antrenmanda 5 başarı", Stat = "training", Goal = 5, Coins = 90, Xp = 50 },
	{ Id = "Antrenman12", Text = "Antrenmanda 12 başarı", Stat = "training", Goal = 12, Coins = 160, Xp = 80 },
}
Config.DailyCount = 3

-- Mağaza: görünüm eşyaları (oyun dengesini etkilemez). Kind: Ball (top), Trail (şut izi), Celebration (gol sevinci)
Config.Shop = {
	{
		Id = "TopKlasik",
		Kind = "Ball",
		Name = "Klasik top",
		Price = 0,
		Level = 1,
		A = Color3.fromRGB(250, 250, 250),
		B = Color3.fromRGB(11, 23, 71),
	},
	{
		Id = "TopSari",
		Kind = "Ball",
		Name = "Sarı lacivert top",
		Price = 300,
		Level = 2,
		A = Color3.fromRGB(255, 230, 0),
		B = Color3.fromRGB(11, 23, 71),
	},
	{
		Id = "TopGece",
		Kind = "Ball",
		Name = "Gece topu",
		Price = 600,
		Level = 5,
		A = Color3.fromRGB(22, 26, 64),
		B = Color3.fromRGB(255, 230, 0),
	},
	{
		Id = "TopTuruncu",
		Kind = "Ball",
		Name = "Kış topu",
		Price = 900,
		Level = 8,
		A = Color3.fromRGB(255, 120, 30),
		B = Color3.fromRGB(20, 20, 24),
	},
	{
		Id = "TopAltin",
		Kind = "Ball",
		Name = "Altın top",
		Price = 2500,
		Level = 12,
		A = Color3.fromRGB(255, 200, 61),
		B = Color3.fromRGB(250, 250, 250),
	},
	{
		Id = "IzBeyaz",
		Kind = "Trail",
		Name = "Beyaz iz",
		Price = 0,
		Level = 1,
		A = Color3.fromRGB(255, 255, 255),
		B = Color3.fromRGB(255, 255, 255),
	},
	{
		Id = "IzSari",
		Kind = "Trail",
		Name = "Sarı iz",
		Price = 250,
		Level = 2,
		A = Color3.fromRGB(255, 230, 0),
		B = Color3.fromRGB(255, 255, 255),
	},
	{
		Id = "IzMavi",
		Kind = "Trail",
		Name = "Buz izi",
		Price = 450,
		Level = 4,
		A = Color3.fromRGB(96, 190, 235),
		B = Color3.fromRGB(255, 255, 255),
	},
	{
		Id = "IzAlev",
		Kind = "Trail",
		Name = "Alev izi",
		Price = 1200,
		Level = 8,
		A = Color3.fromRGB(255, 90, 40),
		B = Color3.fromRGB(255, 200, 80),
	},
	{ Id = "SevincKlasik", Kind = "Celebration", Name = "Kollar havada", Price = 0, Level = 1, Action = "Sevinc" },
	{ Id = "SevincDiz", Kind = "Celebration", Name = "Diz kayması", Price = 400, Level = 3, Action = "DizKaymasi" },
	{ Id = "SevincUcak", Kind = "Celebration", Name = "Uçak", Price = 900, Level = 6, Action = "Ucak" },
}
Config.ShopDefaults = { Ball = "TopKlasik", Trail = "IzBeyaz", Celebration = "SevincKlasik" }
function Config.ShopItem(id: string)
	for _, item in ipairs(Config.Shop) do
		if item.Id == id then
			return item
		end
	end
	return nil
end
-- Oyuncunun kuşandığı eşya (kayıtta yoksa ücretsiz olan)
function Config.Equipped(data, kind: string)
	local id = (data and data.equipped and data.equipped[kind]) or Config.ShopDefaults[kind]
	return Config.ShopItem(id) or Config.ShopItem(Config.ShopDefaults[kind])
end

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

-- Ten ve saç renk seçenekleri (istemci bu listeden seçer, sunucu indeks/hex doğrular)
Config.SkinColors = {
	Color3.fromRGB(245, 214, 190),
	Color3.fromRGB(232, 190, 160),
	Color3.fromRGB(205, 160, 125),
	Color3.fromRGB(170, 120, 88),
	Color3.fromRGB(125, 84, 60),
	Color3.fromRGB(84, 56, 42),
}
Config.HairColors = { "1B1410", "2E2118", "0C0C0E", "5A4326", "8A6A3A", "C9B27A" }
Config.BootColors = { "101216", "F4F4F4", "FFE600", "E33A3A", "22BBDD", "0B1747" }
Config.HairStyleNames = { "Sıfır", "Kısa", "Hacimli", "Uzun", "Kıvırcık", "Topuz", "Yanlar kısa", "Kel" }
Config.BeardNames = { [0] = "Yok", "Kirli", "Bıyık", "Tam", "Keçi" }
Config.BuildNames = { Ince = "İnce", Atletik = "Atletik", Guclu = "Güçlü" }
Config.KitPatternNames = { Cubuklu = "Çubuklu", Duz = "Düz", Kusakli = "Kuşaklı" }
Config.Accessories = { "UzunKol", "Bileklik", "SacBandi", "KisaTozluk" }
Config.AccessoryNames = { UzunKol = "Uzun kol içlik", Bileklik = "Bileklik", SacBandi = "Saç bandı", KisaTozluk = "Kısa tozluk" }
Config.CaptainBandLevel = 10

-- Gövde ölçekleri (HumanoidDescription). Boy yalnızca görünümdür.
Config.Body = {
	HeightScaleMin = 0.94,
	HeightScaleMax = 1.1,
	BodyTypeScale = 0.5, -- 0 klasik kısa gövde, 1 uzun ince gövde; ortası sporcu oranı verir
	ProportionScale = 0.25,
	HeadScale = 1,
	Width = { Ince = 0.82, Atletik = 0.92, Guclu = 1.03 },
	-- İskelet: standart R15. Görünen gövde (baş, kollar, bacaklar, forma) kodla kurulur ve
	-- hazır parçalar gizlenir; buraya gövde paketi kimliği yazmak yalnızca oranları değiştirir.
	Parts = { Head = 0, Torso = 0, RightArm = 0, LeftArm = 0, LeftLeg = 0, RightLeg = 0 },
}

Config.Name = { Min = 3, Max = 16 }
Config.ClubName = { Min = 3, Max = 20 }
Config.Economy = { StartCoins = 100, StartClubFunds = 0 }
Config.Remote = { MinInterval = 0.2 } -- aynı oyuncudan iki istek arası en az süre
Config.Data = { AutoSave = 90, Retries = 4, LockTimeout = 600 }

-- Hareket (stud/saniye). Özellikler bu değerleri sonraki adımlarda ölçekler.
Config.Movement = {
	Run = 17,
	Sprint = 25,
	AccelTime = 0.3, -- 0'dan tam hıza
	DecelTime = 0.25,
	TurnLoss = 0.8, -- ani dönüşte kalan hız oranı
	TurnDot = -0.25, -- bu değerin altındaki yön değişimi "ani dönüş" sayılır
	StaminaMax = 100,
	SprintDrain = 12, -- saniyede
	Regen = 16,
	TiredFactor = 1, -- dayanıklılık bitince hız çarpanı
	TiredUntil = 25, -- bu değere dolana kadar yorgun kalır
	FovBase = 70,
	FovSprint = 75,
	JumpHeight = 6.5,
}

-- Tuşlar (PC). Mobilde aynı eylemler ekrandaki butonlardadır.
Config.Keys = {
	Sprint = Enum.KeyCode.LeftShift,
	Shoot = Enum.KeyCode.F,
	Pass = Enum.KeyCode.E,
	Dribble = Enum.KeyCode.Q,
	Jump = Enum.KeyCode.Space,
	Tackle = Enum.KeyCode.C,
	Special = Enum.KeyCode.R,
	Celebrate = Enum.KeyCode.G,
}

-- Geliştirme ayarları. Yayından önce UnlockAllActions kapatılır.
Config.Debug = {
	-- Yalnızca Roblox Studio'da geçerlidir; yayınlanan oyunda yetenek kilitleri her zaman çalışır
	UnlockAllActionsInStudio = false,
}

-- Yüklenmiş animasyon dosyaları (isteğe bağlı). Bir eylemin kimliği yazılırsa kodla üretilen poz yerine o oynar.
-- Örnek: Config.Animations.Shoot = "rbxassetid://123456"
Config.Animations = {}

-- Top fiziği (stud ve saniye)
Config.Ball = {
	Radius = 0.55,
	Gravity = 85,
	AirDrag = 0.1,
	RollFriction = 0.95,
	Bounce = 0.55,
	WallBounce = 0.45,
	CurveAccel = 30,
	TrailSpeed = 60, -- bu hızın üstünde iz bırakır
}

-- Şut türleri: hız, isabet çarpanı (küçük = isabetli), falso, yükseklik eğilimi
Config.Shots = {
	Shoot = { Speed = 95, Error = 1, Curve = 0, Lift = 1 },
	Plase = { Speed = 78, Error = 0.45, Curve = 1, Lift = 0.8 },
	Fuze = { Speed = 138, Error = 1.7, Curve = 0, Lift = 0.9 },
	Asirtma = { Speed = 66, Error = 0.8, Curve = 0, Lift = 3.2 },
	Vole = { Speed = 112, Error = 1.3, Curve = 0, Lift = 0.9 },
	Rovesata = { Speed = 108, Error = 1.2, Curve = 0, Lift = 1.1 },
	Header = { Speed = 74, Error = 0.9, Curve = 0, Lift = 0.35 },
	UcanKafa = { Speed = 92, Error = 1.1, Curve = 0, Lift = 0.4 },
	GucluKafa = { Speed = 98, Error = 0.8, Curve = 0, Lift = 0.35 },
	Makas = { Speed = 120, Error = 1.1, Curve = 0, Lift = 0.9 },
}
Config.Shooting = {
	ChargeTime = 0.9, -- barın dolma süresi
	PerfectFrom = 0.7, -- yeşil pencere başlangıcı (0-1)
	PerfectTo = 0.96,
	OverFrom = 1.0, -- bunun üstü topu havaya diker
	MaxCharge = 1.18,
	BaseError = 0.12, -- radyan; Şut özelliği 1 iken
	ErrorPerStat = 0.009,
	PerfectErrorFactor = 0.3,
	PerfectSpeedBonus = 1.12,
	Reach = 4.6, -- topa vurabilme mesafesi
	PassSpeed = { 52, 88 }, -- kısa ve uzun basış
	SlowMo = 0.35,
	SlowMoTime = 0.9,
	HitStop = 0.06,
}

-- İkili mücadele: çalım, müdahale, kombo
Config.Duel = {
	TackleWindup = 0.45, -- savunmacının müdahale hazırlığı; çalım bu sürede atılırsa savunmacı sendeler
	TackleCooldown = 1.8,
	DefenderSpeed = 15,
	JockeyDistance = 4.5, -- savunmacının topla arasında bıraktığı mesafe
	TackleRange = 5.5,
	StealRange = 3.6,
	FeintRange = 9,
	StaggerTime = 0.8,
	ComboForTurbo = 3,
	TurboTime = 4,
	TurboBoost = 1.18,
	AttackerSpeed = 14,
	StandReach = 3.4, -- ayakta müdahalenin topa erişimi
	SlideReach = 5.6, -- kayarak müdahalenin topa erişimi
	FoulRange = 2.8, -- topa değmeden bu kadar yakına girilirse faul
	EscapeZ = 62, -- hücumcu bu çizgiyi geçerse kaçmış sayılır
}

-- Kaleci botu
Config.Keeper = {
	Reaction = 0.22, -- şutu fark etme süresi
	DiveSpeed = 17, -- stud/saniye
	BaseReach = 2.8, -- yerinden kıpırdamadan uzanabildiği mesafe
	ShuffleSpeed = 9, -- çizgi üzerinde kayma hızı
	FumbleChance = 0.3, -- füze şutunda topu elinden kaçırma olasılığı
	ErrorChance = 0.1, -- yetişebileceği topu kaçırma olasılığı (kademeyle azalır)
	MinShotSpeed = 42, -- bundan yavaş toplar şut sayılmaz
}

-- Deneme sahası ölçüleri (CharacterService bu sayılarla kurar, top bu sınırlarla çarpışır)
Config.TestPitch = {
	GroundY = -0.02,
	MinX = -118,
	MaxX = 118,
	MinZ = 42,
	MaxZ = 199.4,
	GoalZ = 194,
	GoalHalfWidth = 12,
	GoalHeight = 8,
	Reward = { Coins = 10, Xp = 6, Cooldown = 3, HeaderBonus = 5 },
}

-- Maç sahası (iki kaleli). Oyuncunun takımı +Z yönüne hücum eder.
Config.MatchPitch = {
	GroundY = -0.02,
	MinX = -105,
	MaxX = 105,
	MinZ = 440,
	MaxZ = 760,
	GoalZ = 760, -- rakip kale
	GoalZBack = 440, -- kendi kalemiz
	GoalHalfWidth = 12,
	GoalHeight = 8,
	Walls = false, -- top dışarı çıkar: taç, korner, aut
}

Config.Match = {
	HalfSeconds = 180, -- bir devrenin gerçek süresi
	IntroTime = 3.2,
	GoalPause = 3.4,
	RestartPause = 1.3,
	-- Bot becerisi 0-1 arası; kademenin bot gücünden hesaplanır
	BotSpeed = { 13.5, 18.5 }, -- beceri 0 ve 1 için koşu hızı
	ShootRange = 88,
	PassMin = 18,
	PassMax = 115,
	DecideEvery = 0.45,
	Reward = { Win = 150, Draw = 70, Loss = 30, Goal = 40, HeaderGoal = 60, Xp = { Win = 90, Draw = 55, Loss = 35, Goal = 25 } },
	Points = { Win = 3, Draw = 1, Loss = 0 },
	PromotePoints = 19, -- 10 maçta bu puana ulaşan kulüp lig atlar
	MaxGoals = 15, -- sunucu bundan büyük skoru kabul etmez
}

-- Diziliş (4-4-2): { yan konum -1..1, kendi kalesinden uzaklık 0..1 }
Config.Formation = {
	{ 0, 0.02 },
	{ -0.72, 0.2 },
	{ -0.26, 0.16 },
	{ 0.26, 0.16 },
	{ 0.72, 0.2 },
	{ -0.76, 0.44 },
	{ -0.26, 0.4 },
	{ 0.26, 0.42 },
	{ 0.76, 0.44 },
	{ -0.2, 0.6 },
	{ 0.2, 0.64 },
}
-- Oyuncunun mevkisine göre dizilişteki yeri
Config.FormationSlot = { Kaleci = 1, Defans = 3, OrtaSaha = 7, Forvet = 11 }

-- Genel güç (sıralama ve teklif şartı için)
function Config.Power(stats: { [string]: number }, level: number): number
	local sum = 0
	for _, key in ipairs(Config.Stats) do
		sum += stats[key] or 1
	end
	return math.floor(20 + sum * 1.0 + level * 1.2 + 0.5)
end

return Config
