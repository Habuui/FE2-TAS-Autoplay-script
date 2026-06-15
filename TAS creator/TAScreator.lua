-- [[
--    TAS CREATOR - FE2 (OVERDUB & SPLICE SYSTEM)
--    Captura e playback idênticos ao padrão nativo v15.9.
--    Sem slow motion. Velocidade de reprodução sempre igual à gravação.
-- ]]

local player = game.Players.LocalPlayer
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local vim = game:GetService("VirtualInputManager")
local mouse = player:GetMouse()

-- ========== ESTADO GLOBAL ==========
local state = {
    isRecording = false,
    isPaused = false,
    isPlaying = false,
    currentTAS = {},
    currentFrameIndex = 0,
    accumulatedTime = 0,

    savestates = {},
    futureBuffer = nil,

    isEditMode = false,
    isCutMode = false,
    cutStartFrameIndex = nil,
    undoStack = {},
    redoStack = {},

    holdAdvance = false,
    holdBack = false,
    holdTime = 0,
    holdTick = 0,
    lastStepTime = 0,

    playbackConnection = nil,
}

local KEYS = {
    W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S,
    D = Enum.KeyCode.D, Space = Enum.KeyCode.Space, E = Enum.KeyCode.E
}

local recordingConnection = nil
local pauseCamConnection = nil
local uiUpdateConnection = nil

-- ========== FORMATAÇÃO DE TEMPO ==========
local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 1000)
    return string.format("%01d:%02d.%03d", mins, secs, ms)
end

-- ========== HUD ==========
local targetGuiParent = pcall(function() return game:GetService("CoreGui").Name end) and game:GetService("CoreGui") or player:WaitForChild("PlayerGui")
if targetGuiParent:FindFirstChild("FE2_TAS_HUD") then targetGuiParent.FE2_TAS_HUD:Destroy() end

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "FE2_TAS_HUD"
hudGui.ResetOnSpawn = false
hudGui.Parent = targetGuiParent

local mainPanel = Instance.new("Frame")
mainPanel.Size = UDim2.new(0, 500, 0, 190)
mainPanel.Position = UDim2.new(0.02, 0, 0.62, 0)
mainPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
mainPanel.BackgroundTransparency = 0.18
mainPanel.BorderSizePixel = 0
mainPanel.Active = true
mainPanel.Parent = hudGui

local mainShadow = Instance.new("Frame")
mainShadow.Size = UDim2.new(1, 4, 1, 4)
mainShadow.Position = UDim2.new(0, -2, 0, -2)
mainShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainShadow.BackgroundTransparency = 0.55
mainShadow.BorderSizePixel = 0
mainShadow.ZIndex = mainPanel.ZIndex - 1
mainShadow.Parent = mainPanel
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 10)
shadowCorner.Parent = mainShadow

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainPanel

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.Position = UDim2.new(0, 0, 0, 0)
accentBar.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
accentBar.BorderSizePixel = 0
accentBar.ZIndex = mainPanel.ZIndex + 1
accentBar.Parent = mainPanel
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(0, 8)
accentCorner.Parent = accentBar

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -20, 0, 22)
headerLabel.Position = UDim2.new(0, 12, 0, 8)
headerLabel.BackgroundTransparency = 1
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
headerLabel.TextTransparency = 0.25
headerLabel.Text = "FE2  TAS  CREATOR"
headerLabel.TextSize = 10
headerLabel.ZIndex = mainPanel.ZIndex + 1
headerLabel.Parent = mainPanel

local headerDivider = Instance.new("Frame")
headerDivider.Size = UDim2.new(1, -24, 0, 1)
headerDivider.Position = UDim2.new(0, 12, 0, 30)
headerDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headerDivider.BackgroundTransparency = 0.88
headerDivider.BorderSizePixel = 0
headerDivider.ZIndex = mainPanel.ZIndex + 1
headerDivider.Parent = mainPanel

local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 170, 1, -35)
leftPanel.Position = UDim2.new(0, 0, 0, 34)
leftPanel.BackgroundTransparency = 1
leftPanel.ZIndex = mainPanel.ZIndex + 1
leftPanel.Parent = mainPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -12, 0, 18)
statusLabel.Position = UDim2.new(0, 12, 0, 6)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
statusLabel.Text = "●  IDLE"
statusLabel.TextSize = 12
statusLabel.ZIndex = mainPanel.ZIndex + 2
statusLabel.Parent = leftPanel

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -12, 0, 46)
timerLabel.Position = UDim2.new(0, 10, 0, 26)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.RobotoMono
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Text = "0:00.000"
timerLabel.TextSize = 34
timerLabel.ZIndex = mainPanel.ZIndex + 2
timerLabel.Parent = leftPanel

local timerDivider = Instance.new("Frame")
timerDivider.Size = UDim2.new(0.85, 0, 0, 1)
timerDivider.Position = UDim2.new(0, 12, 0, 76)
timerDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
timerDivider.BackgroundTransparency = 0.88
timerDivider.BorderSizePixel = 0
timerDivider.ZIndex = mainPanel.ZIndex + 2
timerDivider.Parent = leftPanel

local frameLabel = Instance.new("TextLabel")
frameLabel.Size = UDim2.new(1, -12, 0, 16)
frameLabel.Position = UDim2.new(0, 12, 0, 82)
frameLabel.BackgroundTransparency = 1
frameLabel.Font = Enum.Font.Gotham
frameLabel.TextXAlignment = Enum.TextXAlignment.Left
frameLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
frameLabel.Text = "Frame: 0 / 0"
frameLabel.TextSize = 11
frameLabel.ZIndex = mainPanel.ZIndex + 2
frameLabel.Parent = leftPanel

local savestateLabel = Instance.new("TextLabel")
savestateLabel.Size = UDim2.new(1, -12, 0, 16)
savestateLabel.Position = UDim2.new(0, 12, 0, 100)
savestateLabel.BackgroundTransparency = 1
savestateLabel.Font = Enum.Font.Gotham
savestateLabel.TextXAlignment = Enum.TextXAlignment.Left
savestateLabel.TextColor3 = Color3.fromRGB(200, 185, 80)
savestateLabel.Text = "Savestates: 0"
savestateLabel.TextSize = 11
savestateLabel.ZIndex = mainPanel.ZIndex + 2
savestateLabel.Parent = leftPanel

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 0.78, 0)
divider.Position = UDim2.new(0, 178, 0, 38)
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
divider.BackgroundTransparency = 0.86
divider.BorderSizePixel = 0
divider.ZIndex = mainPanel.ZIndex + 1
divider.Parent = mainPanel

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(1, -192, 1, -35)
rightPanel.Position = UDim2.new(0, 186, 0, 34)
rightPanel.BackgroundTransparency = 1
rightPanel.ZIndex = mainPanel.ZIndex + 1
rightPanel.Parent = mainPanel

local tipsLabel = Instance.new("TextLabel")
tipsLabel.Size = UDim2.new(1, -8, 1, -8)
tipsLabel.Position = UDim2.new(0, 4, 0, 4)
tipsLabel.BackgroundTransparency = 1
tipsLabel.Font = Enum.Font.Gotham
tipsLabel.TextXAlignment = Enum.TextXAlignment.Left
tipsLabel.TextYAlignment = Enum.TextYAlignment.Top
tipsLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
tipsLabel.TextSize = 10.5
tipsLabel.LineHeight = 1.45
tipsLabel.RichText = true
tipsLabel.Text =
    '<font color="#7878ff"><b>[G]</b></font> Gravar / Splice do meio\n' ..
    '<font color="#7878ff"><b>[0]</b></font> Reproduzir / Parar\n' ..
    '<font color="#7878ff"><b>[CapsLk]</b></font> Pausar gravação  <font color="#7878ff"><b>[8]</b></font> Edição\n' ..
    '<font color="#7878ff"><b>[5]/[4]</b></font> Avançar / Retroceder frame\n' ..
    '<font color="#7878ff"><b>[7]</b></font> Selecionar corte  <font color="#7878ff"><b>[Del]</b></font> Deletar\n' ..
    '<font color="#7878ff"><b>[Z]</b></font> Undo  <font color="#7878ff"><b>[X]</b></font> Redo\n' ..
    '<font color="#7878ff"><b>[1]</b></font> Savestate  <font color="#7878ff"><b>[3]</b></font> Carregar  <font color="#7878ff"><b>[2]</b></font> Deletar\n' ..
    '<font color="#7878ff"><b>[9]</b></font> Importar  <font color="#7878ff"><b>[6]</b></font> Exportar'
tipsLabel.ZIndex = mainPanel.ZIndex + 2
tipsLabel.Parent = rightPanel

-- Arrastar HUD
local dragging, dragInput, dragStart, startPos
mainPanel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainPanel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
mainPanel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
uis.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainPanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ========== TIMELINE ==========
local timelinePanel = Instance.new("Frame")
timelinePanel.Size = UDim2.new(0.62, 0, 0, 54)
timelinePanel.Position = UDim2.new(0.19, 0, 1, -80)
timelinePanel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
timelinePanel.BackgroundTransparency = 0.18
timelinePanel.BorderSizePixel = 0
timelinePanel.Visible = false
timelinePanel.Parent = hudGui

local tlCorner = Instance.new("UICorner")
tlCorner.CornerRadius = UDim.new(0, 8)
tlCorner.Parent = timelinePanel

local tlShadow = Instance.new("Frame")
tlShadow.Size = UDim2.new(1, 4, 1, 4)
tlShadow.Position = UDim2.new(0, -2, 0, -2)
tlShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
tlShadow.BackgroundTransparency = 0.55
tlShadow.BorderSizePixel = 0
tlShadow.ZIndex = timelinePanel.ZIndex - 1
tlShadow.Parent = timelinePanel
local tlShadowCorner = Instance.new("UICorner")
tlShadowCorner.CornerRadius = UDim.new(0, 10)
tlShadowCorner.Parent = tlShadow

local tlAccent = Instance.new("Frame")
tlAccent.Size = UDim2.new(1, 0, 0, 3)
tlAccent.Position = UDim2.new(0, 0, 0, 0)
tlAccent.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
tlAccent.BorderSizePixel = 0
tlAccent.ZIndex = timelinePanel.ZIndex + 1
tlAccent.Parent = timelinePanel
local tlAccentCorner = Instance.new("UICorner")
tlAccentCorner.CornerRadius = UDim.new(0, 8)
tlAccentCorner.Parent = tlAccent

local timelineTitle = Instance.new("TextLabel")
timelineTitle.Size = UDim2.new(1, 0, 0, 14)
timelineTitle.Position = UDim2.new(0, 12, 0, 4)
timelineTitle.BackgroundTransparency = 1
timelineTitle.Text = "LINHA DO TEMPO"
timelineTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
timelineTitle.TextTransparency = 0.35
timelineTitle.Font = Enum.Font.GothamBold
timelineTitle.TextSize = 9
timelineTitle.TextXAlignment = Enum.TextXAlignment.Left
timelineTitle.ZIndex = timelinePanel.ZIndex + 2
timelineTitle.Parent = timelinePanel

local timelineTrack = Instance.new("Frame")
timelineTrack.Size = UDim2.new(1, -24, 0, 14)
timelineTrack.Position = UDim2.new(0, 12, 0, 32)
timelineTrack.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
timelineTrack.BorderSizePixel = 0
timelineTrack.ZIndex = timelinePanel.ZIndex + 2
timelineTrack.Parent = timelinePanel
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 4)
trackCorner.Parent = timelineTrack

local timelineBar = Instance.new("Frame")
timelineBar.Size = UDim2.new(1, 0, 1, 0)
timelineBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
timelineBar.BorderSizePixel = 0
timelineBar.ZIndex = timelinePanel.ZIndex + 3
timelineBar.Parent = timelineTrack
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 4)
barCorner.Parent = timelineBar

local timelineSelection = Instance.new("Frame")
timelineSelection.BackgroundColor3 = Color3.fromRGB(255, 210, 0)
timelineSelection.BackgroundTransparency = 0.45
timelineSelection.BorderSizePixel = 0
timelineSelection.Visible = false
timelineSelection.ZIndex = timelinePanel.ZIndex + 4
timelineSelection.Parent = timelineBar
local selCorner = Instance.new("UICorner")
selCorner.CornerRadius = UDim.new(0, 3)
selCorner.Parent = timelineSelection

local timelineCursor = Instance.new("Frame")
timelineCursor.Size = UDim2.new(0, 2, 1, 0)
timelineCursor.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
timelineCursor.BorderSizePixel = 0
timelineCursor.ZIndex = timelinePanel.ZIndex + 5
timelineCursor.Parent = timelineBar

local cursorHead = Instance.new("Frame")
cursorHead.Size = UDim2.new(0, 8, 0, 8)
cursorHead.Position = UDim2.new(0.5, -4, 0, -5)
cursorHead.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
cursorHead.BorderSizePixel = 0
cursorHead.ZIndex = timelinePanel.ZIndex + 6
cursorHead.Parent = timelineCursor
local headCorner = Instance.new("UICorner")
headCorner.CornerRadius = UDim.new(0, 2)
headCorner.Parent = cursorHead

local tlTimeLabel = Instance.new("TextLabel")
tlTimeLabel.Size = UDim2.new(0.5, 0, 0, 14)
tlTimeLabel.Position = UDim2.new(0, 12, 0, 16)
tlTimeLabel.BackgroundTransparency = 1
tlTimeLabel.Font = Enum.Font.RobotoMono
tlTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
tlTimeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
tlTimeLabel.TextSize = 10
tlTimeLabel.Text = "0:00.000"
tlTimeLabel.ZIndex = timelinePanel.ZIndex + 2
tlTimeLabel.Parent = timelinePanel

local tlFrameLabel = Instance.new("TextLabel")
tlFrameLabel.Size = UDim2.new(0.5, -12, 0, 14)
tlFrameLabel.Position = UDim2.new(0.5, 0, 0, 16)
tlFrameLabel.BackgroundTransparency = 1
tlFrameLabel.Font = Enum.Font.RobotoMono
tlFrameLabel.TextXAlignment = Enum.TextXAlignment.Right
tlFrameLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
tlFrameLabel.TextSize = 10
tlFrameLabel.Text = "0 / 0"
tlFrameLabel.ZIndex = timelinePanel.ZIndex + 2
tlFrameLabel.Parent = timelinePanel

-- ========== JANELA DE IMPORTAÇÃO ==========
local importPanel = Instance.new("Frame")
importPanel.Size = UDim2.new(0, 420, 0, 320)
importPanel.Position = UDim2.new(0.5, -210, 0.5, -160)
importPanel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
importPanel.BackgroundTransparency = 0.08
importPanel.BorderSizePixel = 0
importPanel.Visible = false
importPanel.Parent = hudGui

local importCorner = Instance.new("UICorner")
importCorner.CornerRadius = UDim.new(0, 8)
importCorner.Parent = importPanel

local importShadow = Instance.new("Frame")
importShadow.Size = UDim2.new(1, 6, 1, 6)
importShadow.Position = UDim2.new(0, -3, 0, -3)
importShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
importShadow.BackgroundTransparency = 0.45
importShadow.BorderSizePixel = 0
importShadow.ZIndex = importPanel.ZIndex - 1
importShadow.Parent = importPanel
local importShadowCorner = Instance.new("UICorner")
importShadowCorner.CornerRadius = UDim.new(0, 10)
importShadowCorner.Parent = importShadow

local importAccent = Instance.new("Frame")
importAccent.Size = UDim2.new(1, 0, 0, 3)
importAccent.BackgroundColor3 = Color3.fromRGB(80, 80, 255)
importAccent.BorderSizePixel = 0
importAccent.ZIndex = importPanel.ZIndex + 1
importAccent.Parent = importPanel
local importAccentCorner = Instance.new("UICorner")
importAccentCorner.CornerRadius = UDim.new(0, 8)
importAccentCorner.Parent = importAccent

local importTitle = Instance.new("TextLabel")
importTitle.Size = UDim2.new(1, -50, 0, 36)
importTitle.Position = UDim2.new(0, 14, 0, 4)
importTitle.BackgroundTransparency = 1
importTitle.Text = "IMPORTAR TAS"
importTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
importTitle.Font = Enum.Font.GothamBold
importTitle.TextSize = 13
importTitle.TextXAlignment = Enum.TextXAlignment.Left
importTitle.ZIndex = importPanel.ZIndex + 2
importTitle.Parent = importPanel

local importCloseBtn = Instance.new("TextButton")
importCloseBtn.Size = UDim2.new(0, 28, 0, 28)
importCloseBtn.Position = UDim2.new(1, -36, 0, 4)
importCloseBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
importCloseBtn.BackgroundTransparency = 0.3
importCloseBtn.BorderSizePixel = 0
importCloseBtn.Text = "✕"
importCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
importCloseBtn.TextSize = 13
importCloseBtn.Font = Enum.Font.GothamBold
importCloseBtn.ZIndex = importPanel.ZIndex + 2
importCloseBtn.Parent = importPanel
local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = importCloseBtn
importCloseBtn.MouseButton1Click:Connect(function() importPanel.Visible = false end)

local importDivider = Instance.new("Frame")
importDivider.Size = UDim2.new(1, -28, 0, 1)
importDivider.Position = UDim2.new(0, 14, 0, 38)
importDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
importDivider.BackgroundTransparency = 0.88
importDivider.BorderSizePixel = 0
importDivider.ZIndex = importPanel.ZIndex + 1
importDivider.Parent = importPanel

local importScroll = Instance.new("ScrollingFrame")
importScroll.Size = UDim2.new(1, -28, 0, 220)
importScroll.Position = UDim2.new(0, 14, 0, 46)
importScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
importScroll.BackgroundTransparency = 0.1
importScroll.BorderSizePixel = 0
importScroll.ScrollBarThickness = 4
importScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 255)
importScroll.ZIndex = importPanel.ZIndex + 1
importScroll.Parent = importPanel
local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = importScroll

local importTextBox = Instance.new("TextBox")
importTextBox.Size = UDim2.new(1, -10, 0, 1000)
importTextBox.Position = UDim2.new(0, 5, 0, 5)
importTextBox.BackgroundTransparency = 1
importTextBox.MultiLine = true
importTextBox.ClearTextOnFocus = false
importTextBox.Text = ""
importTextBox.TextColor3 = Color3.fromRGB(210, 210, 230)
importTextBox.PlaceholderText = "Cole aqui os keyframes nativos do Github..."
importTextBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
importTextBox.Font = Enum.Font.Code
importTextBox.TextSize = 11
importTextBox.TextXAlignment = Enum.TextXAlignment.Left
importTextBox.TextYAlignment = Enum.TextYAlignment.Top
importTextBox.TextWrapped = true
importTextBox.ZIndex = importPanel.ZIndex + 2
importTextBox.Parent = importScroll

importTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    local bounds = importTextBox.TextBounds
    importScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(bounds.Y + 20, 210))
    importTextBox.Size = UDim2.new(1, -10, 0, math.max(bounds.Y + 20, 210))
end)

local runImportBtn = Instance.new("TextButton")
runImportBtn.Size = UDim2.new(1, -28, 0, 36)
runImportBtn.Position = UDim2.new(0, 14, 0, 274)
runImportBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 200)
runImportBtn.BackgroundTransparency = 0.15
runImportBtn.BorderSizePixel = 0
runImportBtn.Text = "⬇  CARREGAR NA MEMÓRIA"
runImportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
runImportBtn.Font = Enum.Font.GothamBold
runImportBtn.TextSize = 12
runImportBtn.ZIndex = importPanel.ZIndex + 2
runImportBtn.Parent = importPanel
local runBtnCorner = Instance.new("UICorner")
runBtnCorner.CornerRadius = UDim.new(0, 6)
runBtnCorner.Parent = runImportBtn

runImportBtn.MouseButton1Click:Connect(function()
    local text = importTextBox.Text
    if text == "" then return end
    if not text:match("^%s*return") and text:match("^%s*{") then text = "return " .. text end
    local func, err = loadstring(text)
    if func then
        local ok, result = pcall(func)
        if ok and type(result) == "table" then
            local parsedTAS = {}
            for k, v in pairs(result) do
                if type(v) == "table" and (v.type == "keyframe" or v.cframe) then
                    v.type = "keyframe"
                    table.insert(parsedTAS, v)
                elseif type(v) == "table" and v.type == "input" then
                    table.insert(parsedTAS, v)
                end
            end
            table.sort(parsedTAS, function(a, b) return a.time < b.time end)
            state.currentTAS = parsedTAS
            state.currentFrameIndex = 1
            state.accumulatedTime = 0
            if #parsedTAS > 0 then state.accumulatedTime = parsedTAS[#parsedTAS].time or 0 end
            local firstKF = parsedTAS[1]
            if firstKF and firstKF.cframe then
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = firstKF.cframe
                    char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                end
            end
            importPanel.Visible = false
            print("TAS importado com sucesso! (" .. #parsedTAS .. " frames)")
        end
    end
end)

-- ========== UNDO/REDO ==========
local function deepCopyTAS(tas)
    local copy = {}
    for i, frame in ipairs(tas) do
        local fCopy = {}
        for k, v in pairs(frame) do
            if k == "inputs" then
                fCopy.inputs = {}
                for ik, iv in pairs(v) do fCopy.inputs[ik] = iv end
            else fCopy[k] = v end
        end
        copy[i] = fCopy
    end
    return copy
end

local function saveStateToUndo()
    if #state.undoStack > 15 then table.remove(state.undoStack, 1) end
    table.insert(state.undoStack, deepCopyTAS(state.currentTAS))
    state.redoStack = {}
end

local function applyFrame(frame)
    if not frame then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = frame.cframe
    hrp.AssemblyLinearVelocity = frame.velocity
end

local function undoCut()
    if #state.undoStack > 0 then
        table.insert(state.redoStack, deepCopyTAS(state.currentTAS))
        state.currentTAS = table.remove(state.undoStack)
        state.currentFrameIndex = math.clamp(state.currentFrameIndex, 1, #state.currentTAS)
        if state.currentTAS[state.currentFrameIndex] then applyFrame(state.currentTAS[state.currentFrameIndex]) end
        state.isCutMode = false
        print("Undo!")
    end
end

local function redoCut()
    if #state.redoStack > 0 then
        table.insert(state.undoStack, deepCopyTAS(state.currentTAS))
        state.currentTAS = table.remove(state.redoStack)
        state.currentFrameIndex = math.clamp(state.currentFrameIndex, 1, #state.currentTAS)
        if state.currentTAS[state.currentFrameIndex] then applyFrame(state.currentTAS[state.currentFrameIndex]) end
        state.isCutMode = false
        print("Redo!")
    end
end

-- ========== HUD UPDATER ==========
if uiUpdateConnection then uiUpdateConnection:Disconnect() end
uiUpdateConnection = rs.Heartbeat:Connect(function()
    savestateLabel.Text = string.format("Savestates: %d", #state.savestates)

    if state.isPlaying then
        statusLabel.Text = "●  REPRODUZINDO"
        statusLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
        accentBar.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
        tlAccent.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
    elseif state.isEditMode then
        local cutTxt = state.isCutMode and "  ✂ " .. tostring(state.cutStartFrameIndex) or ""
        statusLabel.Text = "●  MODO EDIÇÃO" .. cutTxt
        statusLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
        accentBar.BackgroundColor3 = Color3.fromRGB(160, 60, 220)
        tlAccent.BackgroundColor3 = Color3.fromRGB(160, 60, 220)
    elseif state.isRecording then
        if state.isPaused then
            statusLabel.Text = "●  PAUSADO"
            statusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
            accentBar.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
            tlAccent.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        else
            statusLabel.Text = "●  GRAVANDO"
            statusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
            accentBar.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
            tlAccent.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
        end
    else
        statusLabel.Text = "●  IDLE"
        statusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
        accentBar.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
        tlAccent.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    end

    if #state.currentTAS > 0 then
        local idx = (state.isRecording and not state.isPaused) and #state.currentTAS or state.currentFrameIndex
        idx = math.clamp(idx, 1, #state.currentTAS)
        frameLabel.Text = string.format("Frame:  %d / %d", idx, #state.currentTAS)
        if state.currentTAS[idx] then
            local t = state.currentTAS[idx].time
            timerLabel.Text = formatTime(t)
            tlTimeLabel.Text = formatTime(t)
        end
        tlFrameLabel.Text = string.format("%d / %d", idx, #state.currentTAS)

        if state.isEditMode or state.isPlaying then
            timelinePanel.Visible = true
            local pct = idx / #state.currentTAS
            timelineCursor.Position = UDim2.new(pct, -1, 0, 0)
            if state.isCutMode and state.cutStartFrameIndex then
                timelineSelection.Visible = true
                local startPct = state.cutStartFrameIndex / #state.currentTAS
                local minPct = math.min(startPct, pct)
                local maxPct = math.max(startPct, pct)
                timelineSelection.Position = UDim2.new(minPct, 0, 0, 0)
                timelineSelection.Size = UDim2.new(maxPct - minPct, 0, 1, 0)
            else
                timelineSelection.Visible = false
            end
        else
            timelinePanel.Visible = false
        end
    else
        frameLabel.Text = "Frame:  — / —"
        timerLabel.Text = "0:00.000"
        tlTimeLabel.Text = "0:00.000"
        tlFrameLabel.Text = "— / —"
        timelinePanel.Visible = false
    end
end)

-- ========== NOCLIP SELETIVO ==========
local function toggleMouseTargetCollision()
    local target = mouse.Target
    if target and target:IsA("BasePart") then
        if target:GetAttribute("TAS_PartModificada") then
            target.CanCollide = target:GetAttribute("TAS_OriginalCollide")
            target.Transparency = target:GetAttribute("TAS_OriginalTrans")
            target:SetAttribute("TAS_PartModificada", nil)
        else
            target:SetAttribute("TAS_OriginalCollide", target.CanCollide)
            target:SetAttribute("TAS_OriginalTrans", target.Transparency)
            target:SetAttribute("TAS_PartModificada", true)
            target.CanCollide = false
            target.Transparency = 0.5
        end
    end
end

-- ========== CAPTURA DE FRAME ==========
local spaceHistoric = false
local function captureFrame()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return nil end

    local sliding = false
    if char:FindFirstChild("Sliding") or char:GetAttribute("Sliding") then sliding = true end

    local currentSpace = uis:IsKeyDown(Enum.KeyCode.Space)
    local wallhopTriggered = (currentSpace and not spaceHistoric and hum:GetState().Value == 8)
    spaceHistoric = currentSpace

    return {
        type = "keyframe",
        time = state.accumulatedTime,
        cframe = hrp.CFrame,
        velocity = hrp.AssemblyLinearVelocity,
        slideActive = sliding,
        wallhopFlick = wallhopTriggered,
        humanoidState = hum:GetState().Value,
        inputs = {
            W = uis:IsKeyDown(Enum.KeyCode.W),
            A = uis:IsKeyDown(Enum.KeyCode.A),
            S = uis:IsKeyDown(Enum.KeyCode.S),
            D = uis:IsKeyDown(Enum.KeyCode.D),
            Space = currentSpace,
            E = uis:IsKeyDown(Enum.KeyCode.E)
        }
    }
end

-- ========== PAUSA FÍSICA ==========
local function setPause(isPaused)
    state.isPaused = isPaused
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp then return end

    if isPaused then
        hrp.Anchored = true
        if hum then hum.AutoRotate = false end
        if pauseCamConnection then pauseCamConnection:Disconnect() end
        pauseCamConnection = rs.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            if hrp and cam then
                local camLook = cam.CFrame.LookVector
                local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
                if flatLook.Magnitude > 0 then
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatLook)
                end
            end
        end)
    else
        if not state.isEditMode then hrp.Anchored = false end
        if hum then hum.AutoRotate = true end
        if pauseCamConnection then pauseCamConnection:Disconnect() pauseCamConnection = nil end
    end
end

-- ========== SCRUBBING ==========
local function advanceOneFrame()
    if not state.currentTAS or #state.currentTAS == 0 then return end
    if state.currentFrameIndex < #state.currentTAS then
        state.currentFrameIndex = state.currentFrameIndex + 1
        applyFrame(state.currentTAS[state.currentFrameIndex])
    end
end

local function backOneFrame()
    if not state.currentTAS or #state.currentTAS == 0 then return end
    if state.currentFrameIndex > 1 then
        state.currentFrameIndex = state.currentFrameIndex - 1
        applyFrame(state.currentTAS[state.currentFrameIndex])
    end
end

-- ========== PLAYBACK ==========
local function stopPlayback(keepEditMode)
    state.isPlaying = false
    if state.playbackConnection then state.playbackConnection:Disconnect() state.playbackConnection = nil end
    for _, code in pairs(KEYS) do
        pcall(function() vim:SendKeyEvent(false, code, false, game) end)
    end
    if keepEditMode then
        state.isEditMode = true
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = true end
    end
end

local function startPlayback()
    if not state.currentTAS or #state.currentTAS == 0 then return end

    if state.isPlaying then
        stopPlayback(false)
        return
    end

    if state.isRecording then
        toggleRecording()
    end

    local startingIndex = 1
    if state.isEditMode then
        state.isEditMode = false
        startingIndex = math.clamp(state.currentFrameIndex, 1, #state.currentTAS)
    end

    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    char.HumanoidRootPart.Anchored = false

    state.isPlaying = true
    local playbackIndex = startingIndex
    local totalFrames = #state.currentTAS

    if state.playbackConnection then state.playbackConnection:Disconnect() end
    state.playbackConnection = rs.Stepped:Connect(function()
        if not state.isPlaying then return end
        local cc = player.Character
        if not cc or not cc:FindFirstChild("HumanoidRootPart") then
            stopPlayback(false); return
        end
        if playbackIndex > totalFrames then
            stopPlayback(false); return
        end

        local frame = state.currentTAS[playbackIndex]
        state.currentFrameIndex = playbackIndex
        applyFrame(frame)

        if cc:FindFirstChild("Humanoid") then
            pcall(function() cc.Humanoid:ChangeState(frame.humanoidState) end)
        end
        if frame.inputs then
            for keyName, pressed in pairs(frame.inputs) do
                local keyCode = KEYS[keyName]
                if keyCode then
                    pcall(function() vim:SendKeyEvent(pressed, keyCode, false, game) end)
                end
            end
        end

        playbackIndex = playbackIndex + 1
    end)
end

-- ========== SAVESTATES ==========
local function saveState()
    if not state.isRecording and not state.isEditMode then return end
    local copiaFrames = {}
    for i = 1, state.currentFrameIndex do
        local f = state.currentTAS[i]
        if f then
            table.insert(copiaFrames, {
                type="keyframe", time=f.time, cframe=f.cframe, velocity=f.velocity,
                slideActive=f.slideActive, wallhopFlick=f.wallhopFlick, humanoidState=f.humanoidState,
                inputs={W=f.inputs.W, A=f.inputs.A, S=f.inputs.S, D=f.inputs.D, Space=f.inputs.Space, E=f.inputs.E}
            })
        end
    end
    table.insert(state.savestates, {frames=copiaFrames, frameIndex=state.currentFrameIndex, accumulatedTime=state.accumulatedTime})
end

local function loadState()
    if #state.savestates == 0 then return end
    local checkpoint = state.savestates[#state.savestates]
    state.currentTAS = {}
    for _, f in ipairs(checkpoint.frames) do table.insert(state.currentTAS, f) end
    state.currentFrameIndex = checkpoint.frameIndex
    state.accumulatedTime = checkpoint.accumulatedTime
    for i = #state.currentTAS, state.currentFrameIndex + 1, -1 do
        table.remove(state.currentTAS, i)
    end
    if state.currentTAS[state.currentFrameIndex] then
        applyFrame(state.currentTAS[state.currentFrameIndex])
    end
    if state.isEditMode then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = true end
    end
    print(string.format("[Savestate] Carregado: frame %d / %d", state.currentFrameIndex, #state.currentTAS))
end

local function popState()
    if #state.savestates > 0 then table.remove(state.savestates, #state.savestates) end
end

-- ========== GRAVAÇÃO / OVERDUB (CORRIGIDO) ==========
function toggleRecording()
    if state.isPlaying then stopPlayback(true) end

    if state.isRecording then
        state.isRecording = false
        if recordingConnection then recordingConnection:Disconnect() recordingConnection = nil end
        if state.isPaused then setPause(false) end
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.Anchored = false end

        if state.futureBuffer and #state.futureBuffer > 0 then
            if #state.currentTAS > 0 then
                local ultimo = state.currentTAS[#state.currentTAS]
                local offset = (ultimo.time + 0.016666) - state.futureBuffer[1].time
                for _, f in ipairs(state.futureBuffer) do
                    f.time = f.time + offset
                    table.insert(state.currentTAS, f)
                end
            else
                for _, f in ipairs(state.futureBuffer) do
                    table.insert(state.currentTAS, f)
                end
            end
            state.futureBuffer = nil
            saveStateToUndo()
            print("Splice concluído!")
        end
    else
        if #state.currentTAS > 0 and (state.isEditMode or state.isPaused) then
            saveStateToUndo()

            if state.currentFrameIndex > 0 and state.currentFrameIndex < #state.currentTAS then
                state.futureBuffer = {}
                for i = state.currentFrameIndex + 1, #state.currentTAS do
                    table.insert(state.futureBuffer, state.currentTAS[i])
                end
                for i = #state.currentTAS, state.currentFrameIndex + 1, -1 do
                    table.remove(state.currentTAS, i)
                end
            else
                state.futureBuffer = nil
            end

            state.accumulatedTime = state.currentTAS[state.currentFrameIndex] and state.currentTAS[state.currentFrameIndex].time or 0
            state.isRecording = true
            state.isPaused = false
            state.isEditMode = false
            state.isCutMode = false
            state.cutStartFrameIndex = nil
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.Anchored = false end
        else
            state.currentTAS = {}
            state.futureBuffer = nil
            state.undoStack = {}
            state.redoStack = {}
            state.savestates = {}
            state.currentFrameIndex = 0
            state.accumulatedTime = 0
            state.isRecording = true
            state.isPaused = false
            state.isEditMode = false
            state.isCutMode = false
            state.cutStartFrameIndex = nil
        end

        recordingConnection = rs.Stepped:Connect(function(time, deltaTime)
            if not state.isRecording or state.isPaused then return end

            if state.currentFrameIndex < #state.currentTAS then
                for i = #state.currentTAS, state.currentFrameIndex + 1, -1 do
                    table.remove(state.currentTAS, i)
                end
            end

            state.accumulatedTime = state.accumulatedTime + deltaTime
            local frame = captureFrame()
            if frame then
                table.insert(state.currentTAS, frame)
                state.currentFrameIndex = state.currentFrameIndex + 1
            end
        end)
    end
end

-- ========== EXPORTADOR ==========
local function exportRun()
    if not state.currentTAS or #state.currentTAS == 0 then return end
    local sb = {}
    table.insert(sb, "return {\n")
    for _, ev in ipairs(state.currentTAS) do
        local c = {ev.cframe:GetComponents()}
        for idx, val in ipairs(c) do c[idx] = string.format("%.6f", val) end
        local cfStr = string.format("CFrame.new(%s)", table.concat(c, ","))
        local velStr = string.format("Vector3.new(%.6f, %.6f, %.6f)", ev.velocity.X, ev.velocity.Y, ev.velocity.Z)
        table.insert(sb, string.format(
            '    {type="keyframe",time=%f,cframe=%s,velocity=%s,slideActive=%s,wallhopFlick=%s,humanoidState=%d},\n',
            ev.time, cfStr, velStr, tostring(ev.slideActive), tostring(ev.wallhopFlick), tonumber(ev.humanoidState) or 8
        ))
    end
    table.insert(sb, "}\n")
    local output = table.concat(sb)
    if setclipboard then
        setclipboard(output)
        print("TAS exportado com sucesso!")
    else
        print(output)
    end
end

-- ========== CORTE ==========
local function executeCut()
    if state.isEditMode and state.isCutMode and state.cutStartFrameIndex then
        local startIdx = math.min(state.cutStartFrameIndex, state.currentFrameIndex)
        local endIdx   = math.max(state.cutStartFrameIndex, state.currentFrameIndex)
        if startIdx == endIdx then return end
        saveStateToUndo()
        local frameA = state.currentTAS[startIdx]
        local frameB = state.currentTAS[endIdx]
        local tempoDeletado = frameB.time - frameA.time
        local numFrames = endIdx - startIdx + 1
        for i = 1, numFrames do table.remove(state.currentTAS, startIdx) end
        for i = startIdx, #state.currentTAS do
            state.currentTAS[i].time = state.currentTAS[i].time - tempoDeletado
        end
        state.currentFrameIndex = math.clamp(startIdx, 1, #state.currentTAS)
        if state.currentTAS[state.currentFrameIndex] then applyFrame(state.currentTAS[state.currentFrameIndex]) end
        state.accumulatedTime = (#state.currentTAS > 0) and state.currentTAS[#state.currentTAS].time or 0
        state.isCutMode = false
        state.cutStartFrameIndex = nil
        print("Corte efetuado!")
    end
end

-- ========== INPUTS ==========
local function isTyping() return uis:GetFocusedTextBox() ~= nil end

uis.InputBegan:Connect(function(input, gpe)
    if isTyping() or gpe then return end

    if input.KeyCode == Enum.KeyCode.G then
        toggleRecording()
    elseif input.KeyCode == Enum.KeyCode.Zero then
        if state.isPlaying then stopPlayback(false) else startPlayback() end
    elseif input.KeyCode == Enum.KeyCode.CapsLock then
        if state.isPlaying then stopPlayback(true)
        elseif state.isRecording then setPause(not state.isPaused) end
    elseif input.KeyCode == Enum.KeyCode.Eight then
        if #state.currentTAS > 0 then
            state.isEditMode = not state.isEditMode
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = state.isEditMode end
            if state.isEditMode and state.isPlaying then stopPlayback(true) end
            state.isCutMode = false
        end
    elseif input.KeyCode == Enum.KeyCode.Five then
        if (state.isPaused and state.isRecording) or state.isEditMode then
            advanceOneFrame()
            state.holdAdvance = true state.holdTime = 0 state.holdTick = tick() state.lastStepTime = tick()
        end
    elseif input.KeyCode == Enum.KeyCode.Four then
        if (state.isPaused and state.isRecording) or state.isEditMode then
            backOneFrame()
            state.holdBack = true state.holdTime = 0 state.holdTick = tick() state.lastStepTime = tick()
        end
    elseif input.KeyCode == Enum.KeyCode.Seven then
        if state.isEditMode then
            state.isCutMode = not state.isCutMode
            if state.isCutMode then state.cutStartFrameIndex = state.currentFrameIndex else state.cutStartFrameIndex = nil end
        end
    elseif input.KeyCode == Enum.KeyCode.Delete then executeCut()
    elseif input.KeyCode == Enum.KeyCode.Z then undoCut()
    elseif input.KeyCode == Enum.KeyCode.X then redoCut()
    elseif input.KeyCode == Enum.KeyCode.One then saveState()
    elseif input.KeyCode == Enum.KeyCode.Two then popState()
    elseif input.KeyCode == Enum.KeyCode.Three then if state.isRecording or state.isEditMode then loadState() end
    elseif input.KeyCode == Enum.KeyCode.Six then exportRun()
    elseif input.KeyCode == Enum.KeyCode.Nine then importPanel.Visible = not importPanel.Visible
    elseif input.KeyCode == Enum.KeyCode.C then toggleMouseTargetCollision()
    end
end)

uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Five then state.holdAdvance = false end
    if input.KeyCode == Enum.KeyCode.Four then state.holdBack = false end
end)

-- ========== SCRUBBING ACELERADO ==========
rs.Heartbeat:Connect(function()
    if (state.isPaused and state.isRecording) or state.isEditMode then
        if state.holdBack or state.holdAdvance then
            state.holdTime = state.holdTime + (tick() - state.holdTick)
            state.holdTick = tick()
            local interval = 0.1
            local framesToMove = 1
            if state.holdTime > 1 then interval = 0.05 end
            if state.holdTime > 2 then interval = 0.02; framesToMove = 2 end
            if state.holdTime > 3 then interval = 0.01; framesToMove = 4 end
            if (tick() - state.lastStepTime) >= interval then
                state.lastStepTime = tick()
                for _ = 1, framesToMove do
                    if state.holdBack then backOneFrame() else advanceOneFrame() end
                end
            end
        end
    end
end)

print("TAS CREATOR carregado! Correção do splice aplicada. Gravação a partir do EditMode funciona perfeitamente.")
