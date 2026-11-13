--[[
	Commentary
	Maç spikeri: skor tabelasının altında akan kısa anlatım satırları. Olaylara (başlama, şut,
	kurtarış, gol, faul, kart, ofsayt, korner, taç, değişiklik, devre arası, maç sonu) göre
	her seferinde farklı bir cümle seçer.

	Commentary.Attach(root)            maç arayüzüne bağlanır
	Commentary.Say(kind, ctx)          ctx = { player, club, minute, other }
	Commentary.Detach()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(ReplicatedStorage.UI.Components)
local Icons = require(ReplicatedStorage.UI.Icons)
local Theme = require(ReplicatedStorage.UI.Theme)
local UIMotion = require(ReplicatedStorage.UI.UIMotion)

local Commentary = {}

local C = Theme.Color

local LINES: { [string]: { string } } = {
	kickoff = {
		"Hakemin düdüğüyle maç başlıyor!",
		"Ve top yuvarlanıyor, {club} santrayı yaptı.",
		"İki takım da sahada, haydi bakalım!",
	},
	second = { "İkinci yarı başladı, {club} santrada.", "Soyunma odasından dönen takımlar yeniden sahada." },
	shot = {
		"{player} şutunu çekiyor!",
		"Bir şut denemesi {player} ile!",
		"{player} kaleyi yokluyor!",
		"Uzaktan bir deneme {player} ile!",
	},
	save = { "Kaleci yerinde! Gol yok.", "Müthiş bir kurtarış!", "Kaleci gole izin vermiyor.", "Top kalecide, tehlike geçti." },
	fumble = { "Kaleci topu elinden kaçırdı! Tehlike sürüyor!" },
	goal = {
		"GOOOL! {player} ağları sarstı! {club} {score}",
		"İnanılmaz! {player} topu filelere gönderiyor! {score}",
		"Ve gol! {player} affetmedi! {score}",
		"Ağlar havalandı! {player}! Skor {score}",
	},
	owngoal = { "Talihsiz an! Top kendi kalesine gitti. {score}" },
	assist = { "Asist {other}'den, harika pas!", "{other} ölçülü pasla golü hazırladı." },
	foul = { "Hakem düdüğü çaldı, faul.", "Sert bir müdahale, oyun duruyor.", "Faul kararı, serbest vuruş." },
	yellow = { "Sarı kart! {player} kitaba yazılıyor.", "Hakem sarı kartını çıkardı: {player}." },
	red = { "KIRMIZI KART! {player} oyun dışında!", "Hakem tereddüt etmedi, kırmızı kart: {player}." },
	penalty = { "PENALTI! Hakem beyaz noktayı gösteriyor!" },
	offside = { "Bayrak havada, ofsayt.", "Yan hakem ofsaytı gördü: {player}." },
	corner = { "Korner atışı.", "Top kornere çıktı." },
	throw = { "Taç atışı.", "Top taça çıktı." },
	goalkick = { "Aut, kale vuruşu." },
	sub = { "Oyuncu değişikliği: {player} oyuna giriyor.", "Teknik direktör hamlesini yaptı: {player} sahada." },
	halftime = { "Devre arası! Skor {score}.", "İlk yarının sonu: {score}." },
	fulltime = { "Maç sona erdi! Skor {score}.", "Son düdük! {score}." },
	steal = { "Top kaybı! Rakip araya girdi.", "{player} topu kaptı." },
	rain = { "Yağmur altında oynanan bir maç; top zeminde hızlı kayıyor." },
}

local ui: any = nil
local recent: { [string]: number } = {}

function Commentary.Attach(root: Instance)
	Commentary.Detach()
	local box = Instance.new("CanvasGroup")
	box.Name = "Commentary"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 84)
	box.Size = UDim2.fromOffset(620, 36)
	box.BackgroundColor3 = C.Ground
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	box.GroupTransparency = 1
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, 8)
	u.Parent = box
	local icon = Icons.Build("Whistle", 22, C.Yellow)
	icon.Position = UDim2.fromOffset(10, 7)
	icon.Parent = box
	local label = Components.Label({ Text = "", Size = 15, Font = Theme.Font.Title, Color = C.White, Frame = UDim2.new(1, -48, 1, 0) })
	label.Position = UDim2.fromOffset(40, 0)
	label.Parent = box
	box.Parent = root
	ui = { box = box, label = label, token = 0 }
end

function Commentary.Detach()
	if ui and ui.box then
		ui.box:Destroy()
	end
	ui = nil
end

-- {player}, {club}, {score}, {other} yerleri doldurulur; aynı cümle art arda gelmez
function Commentary.Line(kind: string, ctx: any?): string?
	local list = LINES[kind]
	if not list then
		return nil
	end
	local i = math.random(1, #list)
	if #list > 1 and recent[kind] == i then
		i = i % #list + 1
	end
	recent[kind] = i
	local line = list[i]
	ctx = ctx or {}
	for key, value in pairs({ player = ctx.player or "Oyuncu", club = ctx.club or "", score = ctx.score or "", other = ctx.other or "" }) do
		line = string.gsub(line, "{" .. key .. "}", (string.gsub(tostring(value), "%%", "%%%%")))
	end
	return line
end

function Commentary.Say(kind: string, ctx: any?)
	local line = Commentary.Line(kind, ctx)
	if not line or not ui then
		return line
	end
	ui.token += 1
	local token = ui.token
	ui.label.Text = (if ctx and ctx.minute then tostring(ctx.minute) .. "'   " else "") .. line
	UIMotion.Tween(ui.box, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { GroupTransparency = 0 })
	UIMotion.Pop(ui.label, 0.94)
	task.delay(4.5, function()
		if ui and ui.token == token then
			UIMotion.Tween(ui.box, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { GroupTransparency = 1 })
		end
	end)
	return line
end

return Commentary
