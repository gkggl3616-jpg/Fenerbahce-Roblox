--[[
	MeshRig (otomatik üretildi: tools/meshgen/oyuncu_r15.py)
	FK_Oyuncu mesh gövdesinin iskeleti: parça merkezleri ve ölçüleri, eklem noktaları,
	kalça yüksekliği ve forma baskı yerleri. Karakter uzayı: ayaklar y=0, yüz -Z, sağ el +X.
	Elle düzenleme; betiği yeniden çalıştır.
]]

return {
	Height = 5.3000,
	HipHeight = 1.7560,
	Joints = {
		LeftAnkle = {
			Part0 = "LeftLowerLeg",
			Part1 = "LeftFoot",
			Pivot = Vector3.new(-0.5141, 0.3180, 0.1843),
		},
		LeftElbow = {
			Part0 = "LeftUpperArm",
			Part1 = "LeftLowerArm",
			Pivot = Vector3.new(-0.6787, 3.1985, -0.0000),
		},
		LeftHip = {
			Part0 = "LowerTorso",
			Part1 = "LeftUpperLeg",
			Pivot = Vector3.new(-0.2810, 2.6500, -0.0000),
		},
		LeftKnee = {
			Part0 = "LeftUpperLeg",
			Part1 = "LeftLowerLeg",
			Pivot = Vector3.new(-0.4354, 1.5105, 0.0541),
		},
		LeftShoulder = {
			Part0 = "UpperTorso",
			Part1 = "LeftUpperArm",
			Pivot = Vector3.new(-0.6307, 3.8849, -0.0000),
		},
		LeftWrist = {
			Part0 = "LeftLowerArm",
			Part1 = "LeftHand",
			Pivot = Vector3.new(-0.7181, 2.6369, -0.0000),
		},
		Neck = {
			Part0 = "UpperTorso",
			Part1 = "Head",
			Pivot = Vector3.new(0.0000, 4.4785, -0.0000),
		},
		RightAnkle = {
			Part0 = "RightLowerLeg",
			Part1 = "RightFoot",
			Pivot = Vector3.new(0.5174, 0.3180, 0.1776),
		},
		RightElbow = {
			Part0 = "RightUpperArm",
			Part1 = "RightLowerArm",
			Pivot = Vector3.new(0.6774, 3.2181, -0.0000),
		},
		RightHip = {
			Part0 = "LowerTorso",
			Part1 = "RightUpperLeg",
			Pivot = Vector3.new(0.2906, 2.6500, -0.0000),
		},
		RightKnee = {
			Part0 = "RightUpperLeg",
			Part1 = "RightLowerLeg",
			Pivot = Vector3.new(0.4430, 1.5105, 0.0412),
		},
		RightShoulder = {
			Part0 = "UpperTorso",
			Part1 = "RightUpperArm",
			Pivot = Vector3.new(0.6307, 3.8849, -0.0000),
		},
		RightWrist = {
			Part0 = "RightLowerArm",
			Part1 = "RightHand",
			Pivot = Vector3.new(0.7156, 2.6725, -0.0000),
		},
		Root = {
			Part0 = "HumanoidRootPart",
			Part1 = "LowerTorso",
			Pivot = Vector3.new(0.0000, 2.7560, -0.0000),
		},
		Waist = {
			Part0 = "LowerTorso",
			Part1 = "UpperTorso",
			Pivot = Vector3.new(0.0000, 3.1800, -0.0000),
		},
	},
	Landmarks = {
		ChinY = 4.5314,
		LeftShortsT = 0.8242,
		LeftSleeveT = 0.3125,
		LeftSockT = 0.1981,
		MouthY = 4.6473,
		NoseY = 4.7889,
		RightShortsT = 0.8242,
		RightSleeveT = 0.3125,
		RightSockT = 0.1981,
	},
	Parts = {
		Head = {
			Center = Vector3.new(0.0014, 4.8580, -0.0277),
			Size = Vector3.new(0.6410, 0.9225, 0.7107),
		},
		LeftFoot = {
			Center = Vector3.new(-0.6167, 0.2624, -0.0212),
			Size = Vector3.new(0.4908, 0.5432, 0.9028),
		},
		LeftHand = {
			Center = Vector3.new(-0.5736, 2.4072, 0.0474),
			Size = Vector3.new(0.4241, 0.7840, 0.2396),
		},
		LeftLowerArm = {
			Center = Vector3.new(-0.6907, 2.9147, 0.1350),
			Size = Vector3.new(0.2831, 0.7338, 0.3593),
		},
		LeftLowerLeg = {
			Center = Vector3.new(-0.4585, 0.9654, 0.1403),
			Size = Vector3.new(0.4748, 1.3742, 0.5507),
		},
		LeftUpperArm = {
			Center = Vector3.new(-0.7556, 3.7071, 0.1242),
			Size = Vector3.new(0.4130, 1.2512, 0.4731),
		},
		LeftUpperLeg = {
			Center = Vector3.new(-0.3211, 1.9884, 0.0141),
			Size = Vector3.new(0.7033, 1.1817, 0.7649),
		},
		LowerTorso = {
			Center = Vector3.new(-0.0017, 2.8326, -0.0062),
			Size = Vector3.new(1.1575, 0.9231, 0.8250),
		},
		RightFoot = {
			Center = Vector3.new(0.6128, 0.2420, -0.0218),
			Size = Vector3.new(0.4930, 0.5084, 0.9056),
		},
		RightHand = {
			Center = Vector3.new(0.5768, 2.4455, 0.0492),
			Size = Vector3.new(0.4489, 0.7812, 0.2418),
		},
		RightLowerArm = {
			Center = Vector3.new(0.6902, 2.9586, 0.1366),
			Size = Vector3.new(0.2838, 0.7177, 0.3659),
		},
		RightLowerLeg = {
			Center = Vector3.new(0.4548, 0.9658, 0.1401),
			Size = Vector3.new(0.4342, 1.2766, 0.5528),
		},
		RightUpperArm = {
			Center = Vector3.new(0.7571, 3.7301, 0.1377),
			Size = Vector3.new(0.4176, 1.2694, 0.4565),
		},
		RightUpperLeg = {
			Center = Vector3.new(0.3203, 1.9849, 0.0176),
			Size = Vector3.new(0.7680, 1.2076, 0.7609),
		},
		UpperTorso = {
			Center = Vector3.new(-0.0069, 3.7998, 0.0000),
			Size = Vector3.new(1.9280, 1.5011, 0.8610),
		},
	},
	Print = {
		BackNameY = 4.1075,
		BackNameZ = 0.4154,
		BackY = 3.7100,
		BackZ = 0.3752,
		ChestW = 0.9223,
		ChestY = 3.8690,
		ChestZ = -0.4268,
	},
	RootCenter = Vector3.new(0.0000, 2.7560, 0.0000),
}
