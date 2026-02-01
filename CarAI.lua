local CarAI = {}

-- Wagi i biasy (resetowane w Train)
CarAI.Weights = {
	hidden = {
		n1 = {-0.501783, -0.087646, 0.289985, 0.969398, -0.321615},
		n2 = {-1.396804, -0.329464, 0.665467, 2.359482, -1.048838},
		n3 = {4.517115, 0.965133, -2.288625, -7.644924, 3.551037},
		n4 = {-2.372925, -0.502515, 1.164209, 3.949286, -1.853338},
		n5 = {1.184738, 0.213684, -0.594650, -1.972826, 0.877465},
		n6 = {-3.229441, -0.709594, 1.544120, 5.405722, -2.456560},
		n7 = {-0.631813, -0.127525, 0.290859, 1.130303, -0.413962},
		n8 = {0.821175, 0.145698, -0.409548, -1.412781, 0.607009},
		n9 = {1.664764, 0.392560, -0.769278, -2.871874, 1.292890},
		n10 = {1.291379, 0.236095, -0.603622, -2.195104, 1.014595},
	},
	biases = {
		hidden = {-0.047581, -0.246971, 0.902725, -0.425071, 0.235565, -0.622161, -0.019326, 0.088786, 0.308051, 0.244755},
		output = -0.351855
	},
	output = {-1.333430, -3.216342, 9.964897, -5.327979, 2.461710, -7.211698, -1.562051, 1.695864, 3.587675, 2.727840}
} 

-- Sigmoid
local function sigmoid(x)
	return 1 / (1 + math.exp(-x))
end

-- Normalizacja wejść
local function normalize(v1, v2, v3, v4, v5)
	return {
		math.clamp(v1 / 800, 0, 1),
		math.clamp(math.log(v2+1)/math.log(250000+1),0,1),
		math.clamp(v3 / 6.5, 0, 1),
		math.clamp(v4 / 5, 0, 1),
		math.clamp(math.log(v5+1)/math.log(2500000+1),0,1)
	}
end

-- Start procesu predykcji
function CarAI.StartProcess(v1, v2, v3, v4, v5)
	local inputs = normalize(v1, v2, v3, v4, v5)

	-- Pokazujemy inputy w UI
	for i = 1, 5 do 
		CarAI.ActivateNeutronUI(i, "info", inputs[i]) 
	end
	task.wait(0.5)

	-- Forward pass przez warstwę hidden
	local hiddenActivations = {}
	for i = 1, 10 do
		local sum = CarAI.Weights.biases.hidden[i] or 0
		local neuronWeights = CarAI.Weights.hidden["n"..i]

		for j = 1, 5 do
			sum = sum + inputs[j] * neuronWeights[j]
		end

		hiddenActivations[i] = sigmoid(sum)

		local sector = (i <= 5) and "hidden1" or "hidden2"
		local uiIndex = (i <= 5) and i or (i - 5)
		CarAI.ActivateNeutronUI(uiIndex, sector, hiddenActivations[i])
	end
	task.wait(0.5)

	-- Warstwa output
	local finalSum = CarAI.Weights.biases.output
	for i = 1, 10 do
		finalSum = finalSum + hiddenActivations[i] * CarAI.Weights.output[i]
	end
	local result = sigmoid(finalSum)
	local isSporty = result >= 0.5

	CarAI.ActivateNeutronUI(1, "output", tostring(isSporty))

	-- Wiadomość do chatu AI
	local messageText = string.format("network predicts: %s (%.2f probability)", 
		isSporty and "sporty" or "not sporty", result)
	CarAI.createmess("ai", messageText)
end

-- Funkcja aktywacji neuronów w UI
function CarAI.ActivateNeutronUI(nN, sector, val)
	local view = script.Parent.Parent.visualization
	local TS = game:GetService("TweenService")
	local infra = view.infrastruktura

	local sectorMap = {
		["info"] = view.infoneurons,
		["hidden1"] = view.HidenNeuronsLayer1,
		["hidden2"] = view.HidenNeuronsLayer2,
		["output"] = view.finalNeurons
	}

	local folder = sectorMap[sector]
	if not folder then return end

	local neuron = folder:FindFirstChild("n" .. nN)
	if neuron and neuron:FindFirstChild("TextLabel") then
		if sector == "output" then
			neuron.TextLabel.Text = "Value: " .. tostring(val):upper()
		else
			neuron.TextLabel.Text = "Value: " .. (typeof(val) == "number" and string.format("%.4f", val) or tostring(val))
		end

		TS:Create(neuron.Frame, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {
			BackgroundColor3 = Color3.new(0.196, 0.2, 0.223)
		}):Play()

		local connName = (sector == "info" and "n"..nN) or 
			(sector == "hidden1" and "n"..nN.."S") or 
			(sector == "hidden2" and "n"..nN.."SS") or ""

		local function spawnImpulse()
			if connName == "" then return end
			for _, conn in ipairs(infra:GetChildren()) do
				if conn.Name == connName then
					local impulse = script.impuls:Clone()
					impulse.Parent = conn
					impulse.Visible = true
					impulse.Position = UDim2.new(0.5, 0, 0, 0)

					local duration = conn.AbsoluteSize.Y / 300
					TS:Create(impulse, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
						Position = UDim2.new(0.5, 0, 1, 0)
					}):Play()

					task.delay(duration, function() impulse:Destroy() end)
				end
			end
		end

		task.spawn(function()
			for i = 1, 3 do
				spawnImpulse()
				task.wait(0.3)
			end
		end)
	end
end

-- Chat z efektem typowania
local plr = game.Players.LocalPlayer
function CarAI.createmess(sender, text)
	local temp
	if sender == "ai" then
		temp = script.Parent.aiTemp:Clone()
		temp.name.Text = "Neuron Network"
		temp.desc.Text = "The neuron network is analyzing..."
	elseif sender == "user" then
		temp = script.Parent.plrTemp:Clone()
		temp.name.Text = plr.DisplayName
		temp.desc.Text = ""
	end

	temp.Parent = script.Parent.Parent.chat
	temp.Visible = true

	if sender == "ai" then
		task.wait(math.random(1, 3))
		temp.desc.Text = ""
		local speed = math.clamp(1 / #text, 0.03, 0.08)
		for i = 1, #text do
			temp.desc.Text = string.sub(text, 1, i)
			task.wait(speed)
		end
	else
		temp.desc.Text = text
	end
end

-- Trening sieci
function CarAI.Train(TrainingData)
	local lr = 0.01
	local epochs = 5000

	-- Reset wag i biasów
	for i = 1, 10 do
		CarAI.Weights.hidden["n"..i] = {}
		for j = 1, 5 do
			CarAI.Weights.hidden["n"..i][j] = math.random() * 0.1 - 0.05
		end
		CarAI.Weights.biases.hidden[i] = math.random() * 0.1 - 0.05
		CarAI.Weights.output[i] = math.random() * 0.1 - 0.05
	end
	CarAI.Weights.biases.output = math.random() * 0.1 - 0.05

	for epoch = 1, epochs do
		local totalError = 0
		for _, data in ipairs(TrainingData) do
			local inputs = normalize(data[1], data[2], data[3], data[4], data[5])
			local target = data[6]

			local h = {}
			for n = 1, 10 do
				local sum = CarAI.Weights.biases.hidden[n]
				for j = 1, 5 do
					sum = sum + inputs[j] * CarAI.Weights.hidden["n"..n][j]
				end
				h[n] = sigmoid(sum)
			end

			local finalSum = CarAI.Weights.biases.output
			for n = 1, 10 do
				finalSum = finalSum + h[n] * CarAI.Weights.output[n]
			end
			local final = sigmoid(finalSum)

			local error_val = target - final
			totalError = totalError + error_val^2

			local d_final = error_val * (final * (1 - final))
			CarAI.Weights.biases.output = CarAI.Weights.biases.output + d_final * lr
			for n = 1, 10 do
				local hidden_grad = d_final * CarAI.Weights.output[n] * (h[n]*(1-h[n]))
				CarAI.Weights.output[n] = CarAI.Weights.output[n] + d_final * h[n] * lr
				CarAI.Weights.biases.hidden[n] = CarAI.Weights.biases.hidden[n] + hidden_grad * lr
				for j = 1, 5 do
					CarAI.Weights.hidden["n"..n][j] = CarAI.Weights.hidden["n"..n][j] + hidden_grad * inputs[j] * lr
				end
			end
		end
		if epoch % 1000 == 0 then task.wait(); print("🎄 Trening... Błąd: "..(totalError/#TrainingData)) end
	end
	print("✅ Trening zakończony!")
	CarAI.ExportWeights()
end

-- Eksport wag
function CarAI.ExportWeights()
	local s = "CarAI.Weights = {\n"
	s = s.."	hidden = {\n"
	for i=1,10 do
		local w = CarAI.Weights.hidden["n"..i]
		s = s..string.format("		n%d = {%f, %f, %f, %f, %f},\n", i, w[1], w[2], w[3], w[4], w[5])
	end
	s = s.."	},\n"

	s = s.."	biases = {\n"
	s = s.."		hidden = {"
	for i=1,10 do
		s = s..string.format("%f", CarAI.Weights.biases.hidden[i])..(i==10 and "" or ", ")
	end
	s = s.."},\n"
	s = s..string.format("		output = %f\n", CarAI.Weights.biases.output)
	s = s.."	},\n"

	s = s.."	output = {"
	for i=1,10 do
		s = s..string.format("%f", CarAI.Weights.output[i])..(i==10 and "" or ", ")
	end
	s = s.."}\n}"

	print(s)
end

return CarAI
