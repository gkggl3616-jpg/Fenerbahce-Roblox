--[[
	TimeScale
	Oyunun kendi zaman çarpanı: yavaş çekim ve vuruş anı duraksaması (hit-stop).
	Animasyon, top ve oyuncu hızı bu çarpanla çalışır. Maç tek oyunculu ve istemcide
	benzetildiği için yavaş çekim kimseyi etkilemez.
]]

local TimeScale = { Value = 1 }

local token = 0

-- scale: 0-1, duration: gerçek saniye. Bitince 1'e döner.
function TimeScale.Set(scale: number, duration: number)
	token += 1
	local mine = token
	TimeScale.Value = scale
	task.delay(duration, function()
		if token == mine then
			TimeScale.Value = 1
		end
	end)
end

return TimeScale
