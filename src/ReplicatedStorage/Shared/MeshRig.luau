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
			Pivot = Vector3.new(-0.7862, 2.6560, -0.1054),
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
			Pivot = Vector3.new(0.7818, 2.6911, -0.1024),
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
		LeftShortsT = 0.6367,
		LeftSleeveT = 0.3125,
		LeftSockT = 0.1981,
		MouthY = 4.6473,
		NoseY = 4.7889,
		RightShortsT = 0.6367,
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
			Center = Vector3.new(-0.6447, 2.3738, -0.1143),
			Size = Vector3.new(0.4212, 0.8469, 0.3480),
		},
		LeftLowerArm = {
			Center = Vector3.new(-0.7036, 2.9184, 0.0784),
			Size = Vector3.new(0.3088, 0.7195, 0.4724),
		},
		LeftLowerLeg = {
			Center = Vector3.new(-0.4585, 0.9654, 0.1403),
			Size = Vector3.new(0.4791, 1.3742, 0.5507),
		},
		LeftUpperArm = {
			Center = Vector3.new(-0.7557, 3.6860, 0.1242),
			Size = Vector3.new(0.4128, 1.2934, 0.4731),
		},
		LeftUpperLeg = {
			Center = Vector3.new(-0.3013, 1.9884, 0.0141),
			Size = Vector3.new(0.6594, 1.1817, 0.7649),
		},
		LowerTorso = {
			Center = Vector3.new(-0.0016, 2.8326, -0.0062),
			Size = Vector3.new(1.0764, 0.9231, 0.8250),
		},
		RightFoot = {
			Center = Vector3.new(0.6128, 0.2420, -0.0218),
			Size = Vector3.new(0.4930, 0.5084, 0.9056),
		},
		RightHand = {
			Center = Vector3.new(0.6464, 2.4139, -0.1023),
			Size = Vector3.new(0.4224, 0.8314, 0.3569),
		},
		RightLowerArm = {
			Center = Vector3.new(0.7060, 2.9639, 0.0820),
			Size = Vector3.new(0.3059, 0.7288, 0.4828),
		},
		RightLowerLeg = {
			Center = Vector3.new(0.4548, 0.9658, 0.1401),
			Size = Vector3.new(0.4342, 1.2766, 0.5528),
		},
		RightUpperArm = {
			Center = Vector3.new(0.7595, 3.7163, 0.1377),
			Size = Vector3.new(0.4129, 1.3117, 0.4565),
		},
		RightUpperLeg = {
			Center = Vector3.new(0.3005, 1.9849, 0.0176),
			Size = Vector3.new(0.7194, 1.2076, 0.7609),
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
