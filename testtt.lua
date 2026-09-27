--==============================================================================--
--                   GEMINI 10 PRO ENGINE // ULTIMATE CORE v3                    --
--==============================================================================--

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global State & Konfigürasyon (VARSAYILAN: HEPSİ KAPALI)
local Config = {
    Aimbot = {
        Enabled = false,
        KnockCheck = false,
        WallCheck = false,
        TeamCheck = false,
        AimPart = "Head", -- "Head", "HumanoidRootPart"
        Priority = "Crosshair", -- "Crosshair", "Distance", "Health"
        Smoothness = 0.5, -- 0.1 (Hızlı) - 0.9 (Yumuşak)
        DynamicPrediction = false,
        Prediction = 0.138,
        FOV = 160,
        ShowFOV = false,
        TriggerKey = Enum.UserInputType.MouseButton2
    },
    ESP = {
        Enabled = false,
        TeamCheck = false,
        KnockCheck = false,
        Box2D = false,
        Box3D = false,
        Skeleton = false,
        HealthBar = false,
        NameDistance = false,
        WeaponESP = false,
        HeadDot = false,
        OffScreenArrows = false,
        Tracers = false,
        Chams = false,
        FillColor = Color3.fromRGB(0, 255, 170),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
        TracerTransparency = 0.8
    },
    Whitelist = {
        Names = ""
    },
    SkinChanger = {
        Enabled = false,
        Material = Enum.Material.ForceField,
        Color = Color3.fromRGB(0, 255, 200)
    },
    Misc = {
        Fullbright = false,
        MenuKey = Enum.KeyCode.RightControl
    }
}

local RuntimeState = {
    IsAiming = false,
    DrawingPool = {},
    Connections = {}
}

--==============================================================================--
--                            GİRDİ VE YARDIMCI MOTOR                            --
--==============================================================================--

local function GetInputName(key)
    if not key then return "None" end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then
            return key.Name
        elseif key.EnumType == Enum.UserInputType then
            local name = key.Name
            if name == "MouseButton1" then return "MB1" end
            if name == "MouseButton2" then return "MB2" end
            if name == "MouseButton3" then return "MB3" end
            if name == "MouseButton4" then return "MB4" end
            if name == "MouseButton5" then return "MB5" end
            return name:gsub("MouseButton", "MB")
        end
    end
    return "MB2"
end

local function IsInputMatch(inputObj, targetKey)
    if not targetKey then return false end
    if typeof(targetKey) == "EnumItem" then
        if targetKey.EnumType == Enum.KeyCode then
            return inputObj.UserInputType == Enum.UserInputType.Keyboard and inputObj.KeyCode == targetKey
        elseif targetKey.EnumType == Enum.UserInputType then
            return inputObj.UserInputType == targetKey
        end
    end
    return false
end

local function GetPing()
    pcall(function()
        local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
        if dataPing then
            return dataPing:GetValue() / 1000
        end
    end)
    return 0.05
end

local function IsWhitelisted(player)
    if not player or Config.Whitelist.Names == "" then return false end
    local pName = player.Name:lower()
    local dName = player.DisplayName:lower()
    
    for entry in string.gmatch(Config.Whitelist.Names:lower(), "([^,]+)") do
        local trimmed = entry:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            if pName:find(trimmed, 1, true) or dName:find(trimmed, 1, true) then
                return true
            end
        end
    end
    return false
end

local function IsTeamMate(player)
    if not player then return false end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

local function IsPlayerKnocked(player)
    if not player or not player.Character then return true end
    local char = player.Character
    local bodyEffects = char:FindFirstChild("BodyEffects")
    if bodyEffects then
        local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
        if ko and ko.Value == true then return true end
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    return false
end

local function GetHeldWeapon(player)
    if not player or not player.Character then return "None" end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return "None"
end

--==============================================================================--
--                            GUI KURULUMU & MİMARİSİ                            --
--==============================================================================--

local ParentTarget = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if gethui then ParentTarget = gethui()
    elseif syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        ParentTarget = sg
    elseif CoreGui then ParentTarget = CoreGui end
end)

if ParentTarget:FindFirstChild("Gemini10Core_UI") then
    ParentTarget:FindFirstChild("Gemini10Core_UI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Gemini10Core_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = ParentTarget

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 255, 170)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.4
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GEMINI 10 PRO // ENGINE v3 FIXED"
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Dragging Engine
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.Parent = Sidebar

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -140, 1, -50)
Container.Position = UDim2.new(0, 135, 0, 45)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local Tabs = {}
local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -8, 0, 32)
    tabBtn.Position = UDim2.new(0, 4, 0, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 11
    tabBtn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tabBtn

    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.ScrollBarThickness = 2
    tabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
    tabContent.Visible = false
    tabContent.Parent = Container

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = tabContent

    tabBtn.MouseButton1Click:Connect(function()
        for _, tab in pairs(Tabs) do
            tab.Content.Visible = false
            tab.Button.TextColor3 = Color3.fromRGB(160, 160, 170)
            tab.Button.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        end
        tabContent.Visible = true
        tabBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    end)

    local tabObj = { Button = tabBtn, Content = tabContent }
    table.insert(Tabs, tabObj)
    if #Tabs == 1 then
        tabContent.Visible = true
        tabBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    end
    return tabObj
end

local function addToggle(tab, text, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 34, 0, 18)
    btn.Position = UDim2.new(1, -40, 0.5, -9)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(55, 55, 65)
    btn.Text = ""
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn

    local state = defaultState
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(55, 55, 65)
        }):Play()
        if callback then callback(state) end
    end)
end

local function addArrowSelector(tab, text, options, defaultIdx, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 110, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local currentIndex = defaultIdx or 1

    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 140, 0, 24)
    container.Position = UDim2.new(1, -146, 0.5, -12)
    container.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    container.Parent = frame

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 4)
    cCorner.Parent = container

    local leftBtn = Instance.new("TextButton")
    leftBtn.Size = UDim2.new(0, 24, 1, 0)
    leftBtn.Position = UDim2.new(0, 0, 0, 0)
    leftBtn.BackgroundTransparency = 1
    leftBtn.Text = "<"
    leftBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextSize = 12
    leftBtn.Parent = container

    local rightBtn = Instance.new("TextButton")
    rightBtn.Size = UDim2.new(0, 24, 1, 0)
    rightBtn.Position = UDim2.new(1, -24, 0, 0)
    rightBtn.BackgroundTransparency = 1
    rightBtn.Text = ">"
    rightBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextSize = 12
    rightBtn.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(1, -48, 1, 0)
    valueLabel.Position = UDim2.new(0, 24, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = options[currentIndex]
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.TextSize = 10
    valueLabel.Parent = container

    local function updateVal(dir)
        currentIndex = currentIndex + dir
        if currentIndex > #options then currentIndex = 1 end
        if currentIndex < 1 then currentIndex = #options end
        valueLabel.Text = options[currentIndex]
        if callback then callback(options[currentIndex]) end
    end

    leftBtn.MouseButton1Click:Connect(function() updateVal(-1) end)
    rightBtn.MouseButton1Click:Connect(function() updateVal(1) end)
end

local function addKeybind(tab, text, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bindBtn = Instance.new("TextButton")
    bindBtn.Size = UDim2.new(0, 70, 0, 20)
    bindBtn.Position = UDim2.new(1, -76, 0.5, -10)
    bindBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    bindBtn.Text = GetInputName(defaultKey)
    bindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    bindBtn.Font = Enum.Font.GothamBold
    bindBtn.TextSize = 10
    bindBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = bindBtn

    local listening = false
    bindBtn.MouseButton1Click:Connect(function()
        listening = true
        bindBtn.Text = "..."
        bindBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if listening and not gpe then
            local selectedKey = nil
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                selectedKey = input.KeyCode
            elseif input.UserInputType.Name:find("MouseButton") then
                selectedKey = input.UserInputType
            end

            if selectedKey then
                bindBtn.Text = GetInputName(selectedKey)
                bindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
                listening = false
                if callback then callback(selectedKey) end
            end
        end
    end)
end

local function addTextBox(tab, text, defaultText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 110, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -125, 0, 22)
    box.Position = UDim2.new(0, 115, 0.5, -11)
    box.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    box.Text = defaultText or ""
    box.PlaceholderText = "Ahmet, Mehmet..."
    box.TextColor3 = Color3.fromRGB(0, 255, 170)
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
    end)
end

local function addActionButtons(tab, saveCb, loadCb)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 38)
    frame.BackgroundTransparency = 1
    frame.Parent = tab.Content

    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(0.48, 0, 1, 0)
    sBtn.Position = UDim2.new(0, 0, 0, 0)
    sBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
    sBtn.Text = "Config Kaydet"
    sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.Parent = frame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 6)
    sCorner.Parent = sBtn

    local lBtn = Instance.new("TextButton")
    lBtn.Size = UDim2.new(0.48, 0, 1, 0)
    lBtn.Position = UDim2.new(0.52, 0, 0, 0)
    lBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    lBtn.Text = "Config Yükle"
    lBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lBtn.Font = Enum.Font.GothamBold
    lBtn.TextSize = 11
    lBtn.Parent = frame

    local lCorner = Instance.new("UICorner")
    lCorner.CornerRadius = UDim.new(0, 6)
    lCorner.Parent = lBtn

    sBtn.MouseButton1Click:Connect(saveCb)
    lBtn.MouseButton1Click:Connect(loadCb)
end

-- SEKMELER
local combatTab = createTab("Combat")
local visualTab = createTab("Görsel (ESP)")
local settingsTab = createTab("Ayarlar & Config")

-- COMBAT TAB
addToggle(combatTab, "Aimbot Aktif", Config.Aimbot.Enabled, function(state) Config.Aimbot.Enabled = state end)
addToggle(combatTab, "KnockCheck (Baygın Es Geç)", Config.Aimbot.KnockCheck, function(state) Config.Aimbot.KnockCheck = state end)
addToggle(combatTab, "WallCheck (Duvar Kontrolü)", Config.Aimbot.WallCheck, function(state) Config.Aimbot.WallCheck = state end)
addToggle(combatTab, "Team Check (Takım Arkadaşı)", Config.Aimbot.TeamCheck, function(state) Config.Aimbot.TeamCheck = state end)
addToggle(combatTab, "Dinamik Ping Prediction", Config.Aimbot.DynamicPrediction, function(state) Config.Aimbot.DynamicPrediction = state end)
addArrowSelector(combatTab, "Hedef Önceliği", {"Crosshair", "Distance", "Health"}, 1, function(val) Config.Aimbot.Priority = val end)
addArrowSelector(combatTab, "Hedef Bölgesi", {"Head", "HumanoidRootPart"}, 1, function(val) Config.Aimbot.AimPart = val end)
addToggle(combatTab, "FOV Çemberi Göster", Config.Aimbot.ShowFOV, function(state) Config.Aimbot.ShowFOV = state end)
addKeybind(combatTab, "Aimbot Tuşu", Config.Aimbot.TriggerKey, function(key) Config.Aimbot.TriggerKey = key; RuntimeState.IsAiming = false end)

-- VISUAL TAB
addToggle(visualTab, "ESP Genel Aktif", Config.ESP.Enabled, function(state) Config.ESP.Enabled = state end)
addToggle(visualTab, "Takım ESP Es Geç", Config.ESP.TeamCheck, function(state) Config.ESP.TeamCheck = state end)
addToggle(visualTab, "Baygın ESP Es Geç", Config.ESP.KnockCheck, function(state) Config.ESP.KnockCheck = state end)
addToggle(visualTab, "2D Box ESP", Config.ESP.Box2D, function(state) Config.ESP.Box2D = state end)
addToggle(visualTab, "3D Box ESP", Config.ESP.Box3D, function(state) Config.ESP.Box3D = state end)
addToggle(visualTab, "Skeleton ESP (İskelet)", Config.ESP.Skeleton, function(state) Config.ESP.Skeleton = state end)
addToggle(visualTab, "Health Bar & Text", Config.ESP.HealthBar, function(state) Config.ESP.HealthBar = state end)
addToggle(visualTab, "Name & Distance ESP", Config.ESP.NameDistance, function(state) Config.ESP.NameDistance = state end)
addToggle(visualTab, "Held Weapon ESP", Config.ESP.WeaponESP, function(state) Config.ESP.WeaponESP = state end)
addToggle(visualTab, "Head Dot (Kafa Noktası)", Config.ESP.HeadDot, function(state) Config.ESP.HeadDot = state end)
addToggle(visualTab, "Off-Screen Indicators (Oklar)", Config.ESP.OffScreenArrows, function(state) Config.ESP.OffScreenArrows = state end)
addToggle(visualTab, "Tracers (Çizgi ESP)", Config.ESP.Tracers, function(state) Config.ESP.Tracers = state end)
addToggle(visualTab, "Chams (Glow Highlight)", Config.ESP.Chams, function(state) Config.ESP.Chams = state end)
addToggle(visualTab, "SkinChanger (Silah Efekti)", Config.SkinChanger.Enabled, function(state) Config.SkinChanger.Enabled = state end)
addToggle(visualTab, "Fullbright (Aydınlatma)", Config.Misc.Fullbright, function(state) Config.Misc.Fullbright = state end)

-- SETTINGS TAB
addTextBox(settingsTab, "Whitelist (İsimler)", Config.Whitelist.Names, function(val) Config.Whitelist.Names = val end)
addKeybind(settingsTab, "Menü Tuşu", Config.Misc.MenuKey, function(key) Config.Misc.MenuKey = key end)

-- CONFIG LOGIC
local function SaveConfig()
    if writefile then
        pcall(function()
            writefile("Gemini10Core_Config.json", HttpService:JSONEncode(Config))
        end)
    end
end

local function LoadConfig()
    if readfile and isfile and isfile("Gemini10Core_Config.json") then
        pcall(function()
            local data = HttpService:JSONDecode(readfile("Gemini10Core_Config.json"))
            if data then
                for k, v in pairs(data) do
                    if Config[k] then
                        for subK, subV in pairs(v) do Config[k][subK] = subV end
                    end
                end
            end
        end)
    end
end

addActionButtons(settingsTab, SaveConfig, LoadConfig)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and IsInputMatch(input, Config.Misc.MenuKey) then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

--==============================================================================--
--                            ÇEKİRDEK AIMBOT & ESP MOTORU                      --
--==============================================================================--

local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(0, 255, 170)
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Visible = false
end)

local function IsPartVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local destination = targetPart.Position
    local direction = (destination - origin)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {LocalPlayer.Character, Camera}
    if targetPart.Parent then table.insert(ignoreList, targetPart.Parent) end
    raycastParams.FilterDescendantsInstances = ignoreList
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if not IsWhitelisted(player) and not (Config.Aimbot.TeamCheck and IsTeamMate(player)) then
                if not (Config.Aimbot.KnockCheck and IsPlayerKnocked(player)) then
                    local targetPart = player.Character:FindFirstChild(Config.Aimbot.AimPart) or player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if targetPart and humanoid and IsPartVisible(targetPart) then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if fovDist <= Config.Aimbot.FOV then
                                local score = math.huge
                                if Config.Aimbot.Priority == "Crosshair" then
                                    score = fovDist
                                elseif Config.Aimbot.Priority == "Distance" then
                                    score = (targetPart.Position - Camera.CFrame.Position).Magnitude
                                elseif Config.Aimbot.Priority == "Health" then
                                    score = humanoid.Health
                                end

                                if score < bestScore then
                                    bestScore = score
                                    bestTarget = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- HARİTADA TESPİT EDİLECEK R6 & R15 İSKELET BÖLGELERİ
local R15Joints = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local R6Joints = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local function GetPlayerDrawings(player)
    if not RuntimeState.DrawingPool[player] then
        RuntimeState.DrawingPool[player] = {
            Box2D = Drawing.new("Square"),
            HeadDot = Drawing.new("Circle"),
            Tracer = Drawing.new("Line"),
            NameText = Drawing.new("Text"),
            HealthText = Drawing.new("Text"),
            WeaponText = Drawing.new("Text"),
            HealthBarBg = Drawing.new("Square"),
            HealthBar = Drawing.new("Square"),
            Arrow = Drawing.new("Triangle"),
            SkeletonLines = {},
            Box3DLines = {}
        }
        for i = 1, 12 do table.insert(RuntimeState.DrawingPool[player].Box3DLines, Drawing.new("Line")) end
        for i = 1, 15 do table.insert(RuntimeState.DrawingPool[player].SkeletonLines, Drawing.new("Line")) end
    end
    return RuntimeState.DrawingPool[player]
end

local function HideAllDrawings(drawData)
    pcall(function()
        drawData.Box2D.Visible = false
        drawData.HeadDot.Visible = false
        drawData.Tracer.Visible = false
        drawData.NameText.Visible = false
        drawData.HealthText.Visible = false
        drawData.WeaponText.Visible = false
        drawData.HealthBarBg.Visible = false
        drawData.HealthBar.Visible = false
        drawData.Arrow.Visible = false
        for _, line in ipairs(drawData.Box3DLines) do line.Visible = false end
        for _, line in ipairs(drawData.SkeletonLines) do line.Visible = false end
    end)
end

local function ClearDrawings(player)
    if RuntimeState.DrawingPool[player] then
        local drawData = RuntimeState.DrawingPool[player]
        HideAllDrawings(drawData)
        pcall(function()
            drawData.Box2D:Remove(); drawData.HeadDot:Remove(); drawData.Tracer:Remove()
            drawData.NameText:Remove(); drawData.HealthText:Remove(); drawData.WeaponText:Remove()
            drawData.HealthBarBg:Remove(); drawData.HealthBar:Remove(); drawData.Arrow:Remove()
            for _, line in ipairs(drawData.Box3DLines) do line:Remove() end
            for _, line in ipairs(drawData.SkeletonLines) do line:Remove() end
        end)
        RuntimeState.DrawingPool[player] = nil
    end
end

Players.PlayerRemoving:Connect(ClearDrawings)

-- ESP VE GÖRSEL YÖNETİCİSİ
local function ProcessVisuals()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local isKnocked = Config.ESP.KnockCheck and IsPlayerKnocked(player)
            local isTeam = Config.ESP.TeamCheck and IsTeamMate(player)
            local isWhite = IsWhitelisted(player)

            if Config.ESP.Enabled and not isKnocked and not isTeam and not isWhite then
                local draw = GetPlayerDrawings(player)
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")

                -- Chams Highlight
                local highlight = char:FindFirstChild("GeminiChams")
                if Config.ESP.Chams then
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "GeminiChams"
                        highlight.Parent = char
                    end
                    highlight.FillColor = Config.ESP.FillColor
                    highlight.OutlineColor = Config.ESP.OutlineColor
                    highlight.FillTransparency = Config.ESP.FillTransparency
                    highlight.OutlineTransparency = Config.ESP.OutlineTransparency
                    highlight.Enabled = true
                else
                    if highlight then highlight:Destroy() end
                end

                if hrp and head and humanoid then
                    local hrpPos, hrpOnScreen = Camera:WorldToViewportPoint(hrp.Position)
                    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                    local legPos, legOnScreen = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                    -- KESİN EKRAN VE DEPTH DOĞRULAMASI (Bozulmaları Önler)
                    local isValidViewport = hrpOnScreen and headOnScreen and hrpPos.Z > 0 and headPos.Z > 0

                    if isValidViewport then
                        local boxHeight = math.abs(headPos.Y - legPos.Y)
                        local boxWidth = boxHeight * 0.65

                        -- 2D Box ESP
                        if Config.ESP.Box2D then
                            draw.Box2D.Size = Vector2.new(boxWidth, boxHeight)
                            draw.Box2D.Position = Vector2.new(hrpPos.X - boxWidth / 2, headPos.Y)
                            draw.Box2D.Color = Config.ESP.FillColor
                            draw.Box2D.Thickness = 1.5
                            draw.Box2D.Filled = false
                            draw.Box2D.Visible = true
                        else draw.Box2D.Visible = false end

                        -- Health Bar & Text
                        if Config.ESP.HealthBar then
                            local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            local barHeight = boxHeight * healthPercent

                            draw.HealthBarBg.Size = Vector2.new(4, boxHeight)
                            draw.HealthBarBg.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 8, headPos.Y)
                            draw.HealthBarBg.Color = Color3.fromRGB(30, 30, 30)
                            draw.HealthBarBg.Filled = true
                            draw.HealthBarBg.Visible = true

                            draw.HealthBar.Size = Vector2.new(2, barHeight)
                            draw.HealthBar.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 7, headPos.Y + (boxHeight - barHeight))
                            draw.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            draw.HealthBar.Filled = true
                            draw.HealthBar.Visible = true

                            draw.HealthText.Text = string.format("%%%d", math.floor(healthPercent * 100))
                            draw.HealthText.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 28, headPos.Y + (boxHeight - barHeight) - 6)
                            draw.HealthText.Color = Color3.fromRGB(255, 255, 255)
                            draw.HealthText.Size = 10
                            draw.HealthText.Center = true
                            draw.HealthText.Outline = true
                            draw.HealthText.Visible = true
                        else
                            draw.HealthBarBg.Visible = false
                            draw.HealthBar.Visible = false
                            draw.HealthText.Visible = false
                        end

                        -- Name & Distance ESP (Tam Olarak Baş Üstüne Hizalandı)
                        if Config.ESP.NameDistance then
                            local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                            draw.NameText.Text = string.format("%s [%dm]", player.DisplayName, dist)
                            draw.NameText.Position = Vector2.new(hrpPos.X, headPos.Y - 16)
                            draw.NameText.Color = Color3.fromRGB(255, 255, 255)
                            draw.NameText.Size = 11
                            draw.NameText.Center = true
                            draw.NameText.Outline = true
                            draw.NameText.Visible = true
                        else draw.NameText.Visible = false end

                        -- Held Weapon ESP
                        if Config.ESP.WeaponESP then
                            draw.WeaponText.Text = GetHeldWeapon(player)
                            draw.WeaponText.Position = Vector2.new(hrpPos.X, legPos.Y + 2)
                            draw.WeaponText.Color = Color3.fromRGB(0, 255, 170)
                            draw.WeaponText.Size = 10
                            draw.WeaponText.Center = true
                            draw.WeaponText.Outline = true
                            draw.WeaponText.Visible = true
                        else draw.WeaponText.Visible = false end

                        -- Head Dot ESP
                        if Config.ESP.HeadDot then
                            local hPos = Camera:WorldToViewportPoint(head.Position)
                            draw.HeadDot.Position = Vector2.new(hPos.X, hPos.Y)
                            draw.HeadDot.Radius = math.clamp(boxHeight / 12, 2, 6)
                            draw.HeadDot.Color = Config.ESP.FillColor
                            draw.HeadDot.Filled = true
                            draw.HeadDot.Visible = true
                        else draw.HeadDot.Visible = false end

                        -- Tracers ESP
                        if Config.ESP.Tracers then
                            draw.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            draw.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y)
                            draw.Tracer.Color = Config.ESP.FillColor
                            draw.Tracer.Thickness = 1.2
                            draw.Tracer.Visible = true
                        else draw.Tracer.Visible = false end

                        -- Skeleton ESP (R6 ve R15 Karakter Destekli)
                        if Config.ESP.Skeleton then
                            local joints = (humanoid.RigType == Enum.HumanoidRigType.R6) and R6Joints or R15Joints
                            for idx, pair in ipairs(joints) do
                                local p1 = char:FindFirstChild(pair[1])
                                local p2 = char:FindFirstChild(pair[2])
                                local line = draw.SkeletonLines[idx]
                                if p1 and p2 and line then
                                    local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
                                    local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
                                    if vis1 and vis2 and pos1.Z > 0 and pos2.Z > 0 then
                                        line.From = Vector2.new(pos1.X, pos1.Y)
                                        line.To = Vector2.new(pos2.X, pos2.Y)
                                        line.Color = Config.ESP.OutlineColor
                                        line.Thickness = 1
                                        line.Visible = true
                                    else line.Visible = false end
                                else if line then line.Visible = false end end
                            end
                        else
                            for _, line in ipairs(draw.SkeletonLines) do line.Visible = false end
                        end

                        -- 3D Box ESP
                        if Config.ESP.Box3D then
                            local size = char:GetExtentsSize()
                            local cf = hrp.CFrame
                            local corners = {
                                cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.Aimbot ve ESP sisteminde tespit edilen sorunlar (arkadaki oyuncuların ekranın ortasına yansıması, Aimbot'un arkadaki hedeflere kilitlenmesi ve çizimlerin sapıtması) giderildi ve arayüze ok tuşlu seçici eklendi.

### 🛠️ Yapılan Düzeltmeler ve İyileştirmeler:

1. **Ekran Ortasındaki Bozukluk (Z-Index / Depth Bug Fix):**
   * Roblox'un `WorldToViewportPoint` fonksiyonu kameranın arkasındaki nesnelerin de koordinatlarını verir (ancak Z değeri negatif olur). Eski kodda Z derinlik kontrolü eksik olduğu için kameranın arkasındaki oyuncular ekranın tam ortasında `(0,0)` yakınında çiziliyordu. Tüm ESP ve Aimbot hesaplamalarına **`Z > 0` (Kamera Önünde Olma)** şartı eklendi.
2. **Aimbot Kilitlenme Hatası Düzeltildi:**
   * Arkadaki oyuncuların FOV çemberine girmesi engellendi.
   * `Lerp` yumuşatma algoritması (Smoothness) yeniden kalibre edildi; kamera titremeleri ve aniden arkaya dönme sorunları çözüldü.
3. **Seçenek Okları (`<` Seçenek `>`):**
   * Hedef Önceliği (Priority) ve Hedef Bölgesi gibi seçicilere sol ve sağ ok butonları eklendi. Böylece seçenekler arasında rahatça geçiş yapabilirsin.
4. **Çizim Temizleme (Ghost Drawing Prevention):**
   * Görüş açısından çıkan veya ölen oyuncuların nesneleri anında gizlenir (`Visible = false`), ekranda hayalet çizgi/yazı kalmaz.
5. **Varsayılan Durum:** Tüm özellikler kapalı (`false`) durumdadır.

---

```lua
--==============================================================================--
--                   GEMINI 10 PRO ENGINE // ULTIMATE CORE v3                    --
--==============================================================================--

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global State & Konfigürasyon (TÜM ÖZELLİKLER VARSAYILAN OLARAK KAPALI)
local Config = {
    Aimbot = {
        Enabled = false,
        KnockCheck = false,
        WallCheck = false,
        TeamCheck = false,
        AimPart = "Head", -- "Head" veya "HumanoidRootPart"
        Priority = "Crosshair", -- "Crosshair", "Distance", "Health"
        Smoothness = 0.2,
        DynamicPrediction = false,
        Prediction = 0.138,
        FOV = 160,
        ShowFOV = false,
        TriggerKey = Enum.UserInputType.MouseButton2
    },
    ESP = {
        Enabled = false,
        TeamCheck = false,
        KnockCheck = false,
        Box2D = false,
        Box3D = false,
        Skeleton = false,
        HealthBar = false,
        NameDistance = false,
        WeaponESP = false,
        HeadDot = false,
        OffScreenArrows = false,
        Tracers = false,
        Chams = false,
        FillColor = Color3.fromRGB(0, 255, 170),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
        TracerTransparency = 0.8
    },
    Whitelist = {
        Names = ""
    },
    SkinChanger = {
        Enabled = false,
        Material = Enum.Material.ForceField,
        Color = Color3.fromRGB(0, 255, 200)
    },
    Misc = {
        Fullbright = false,
        MenuKey = Enum.KeyCode.RightControl
    }
}

local RuntimeState = {
    IsAiming = false,
    DrawingPool = {}
}

--==============================================================================--
--                            YARDIMCI MOTOR VE FONKSİYONLAR                   --
--==============================================================================--

local function GetInputName(key)
    if not key then return "None" end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then
            return key.Name
        elseif key.EnumType == Enum.UserInputType then
            local name = key.Name
            if name == "MouseButton1" then return "MB1" end
            if name == "MouseButton2" then return "MB2" end
            if name == "MouseButton3" then return "MB3" end
            if name == "MouseButton4" then return "MB4" end
            if name == "MouseButton5" then return "MB5" end
            return name:gsub("MouseButton", "MB")
        end
    end
    return "MB2"
end

local function IsInputMatch(inputObj, targetKey)
    if not targetKey then return false end
    if typeof(targetKey) == "EnumItem" then
        if targetKey.EnumType == Enum.KeyCode then
            return inputObj.UserInputType == Enum.UserInputType.Keyboard and inputObj.KeyCode == targetKey
        elseif targetKey.EnumType == Enum.UserInputType then
            return inputObj.UserInputType == targetKey
        end
    end
    return false
end

local function GetPing()
    pcall(function()
        local dataPing = Stats.Network.ServerStatsItem["Data Ping"]
        if dataPing then
            return dataPing:GetValue() / 1000
        end
    end)
    return 0.05
end

local function IsWhitelisted(player)
    if not player or Config.Whitelist.Names == "" then return false end
    local pName = player.Name:lower()
    local dName = player.DisplayName:lower()
    
    for entry in string.gmatch(Config.Whitelist.Names:lower(), "([^,]+)") do
        local trimmed = entry:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            if pName:find(trimmed, 1, true) or dName:find(trimmed, 1, true) then
                return true
            end
        end
    end
    return false
end

local function IsTeamMate(player)
    if not player then return false end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team == player.Team
    end
    return false
end

local function IsPlayerKnocked(player)
    if not player or not player.Character then return true end
    local char = player.Character
    local bodyEffects = char:FindFirstChild("BodyEffects")
    if bodyEffects then
        local ko = bodyEffects:FindFirstChild("K.O") or bodyEffects:FindFirstChild("KO")
        if ko and ko.Value == true then return true end
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return true end
    return false
end

local function GetHeldWeapon(player)
    if not player or not player.Character then return "None" end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return "None"
end

--==============================================================================--
--                            GUI KURULUMU & ARAYÜZ                             --
--==============================================================================--

local ParentTarget = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if gethui then ParentTarget = gethui()
    elseif syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        ParentTarget = sg
    elseif CoreGui then ParentTarget = CoreGui end
end)

if ParentTarget:FindFirstChild("Gemini10Core_UI") then
    ParentTarget:FindFirstChild("Gemini10Core_UI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Gemini10Core_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = ParentTarget

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 255, 170)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.4
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GEMINI 10 PRO // ULTIMATE SUITE v3"
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Sürükleme Mantığı
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.Parent = Sidebar

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -140, 1, -50)
Container.Position = UDim2.new(0, 135, 0, 45)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local Tabs = {}
local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -8, 0, 32)
    tabBtn.Position = UDim2.new(0, 4, 0, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 11
    tabBtn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tabBtn

    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.ScrollBarThickness = 2
    tabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
    tabContent.Visible = false
    tabContent.Parent = Container

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = tabContent

    tabBtn.MouseButton1Click:Connect(function()
        for _, tab in pairs(Tabs) do
            tab.Content.Visible = false
            tab.Button.TextColor3 = Color3.fromRGB(160, 160, 170)
            tab.Button.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        end
        tabContent.Visible = true
        tabBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    end)

    local tabObj = { Button = tabBtn, Content = tabContent }
    table.insert(Tabs, tabObj)
    if #Tabs == 1 then
        tabContent.Visible = true
        tabBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    end
    return tabObj
end

local function addToggle(tab, text, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 34, 0, 18)
    btn.Position = UDim2.new(1, -40, 0.5, -9)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(55, 55, 65)
    btn.Text = ""
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn

    local state = defaultState
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(55, 55, 65)
        }):Play()
        if callback then callback(state) end
    end)
end

local function addKeybind(tab, text, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 34)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bindBtn = Instance.new("TextButton")
    bindBtn.Size = UDim2.new(0, 70, 0, 20)
    bindBtn.Position = UDim2.new(1, -76, 0.5, -10)
    bindBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    bindBtn.Text = GetInputName(defaultKey)
    bindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    bindBtn.Font = Enum.Font.GothamBold
    bindBtn.TextSize = 10
    bindBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = bindBtn

    local listening = false
    bindBtn.MouseButton1Click:Connect(function()
        listening = true
        bindBtn.Text = "..."
        bindBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if listening and not gpe then
            local selectedKey = nil
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                selectedKey = input.KeyCode
            elseif input.UserInputType.Name:find("MouseButton") then
                selectedKey = input.UserInputType
            end

            if selectedKey then
                bindBtn.Text = GetInputName(selectedKey)
                bindBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
                listening = false
                if callback then callback(selectedKey) end
            end
        end
    end)
end

-- OKLU SEÇİCİ WIDGET'I (< SEÇENEK >)
local function addArrowSelector(tab, text, options, defaultIndex, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 110, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local index = defaultIndex or 1

    local leftBtn = Instance.new("TextButton")
    leftBtn.Size = UDim2.new(0, 22, 0, 22)
    leftBtn.Position = UDim2.new(1, -145, 0.5, -11)
    leftBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    leftBtn.Text = "<"
    leftBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextSize = 12
    leftBtn.Parent = frame

    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 4)
    leftCorner.Parent = leftBtn

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 90, 0, 22)
    valueLabel.Position = UDim2.new(1, -120, 0.5, -11)
    valueLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    valueLabel.Text = options[index]
    valueLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 10
    valueLabel.Parent = frame

    local valCorner = Instance.new("UICorner")
    valCorner.CornerRadius = UDim.new(0, 4)
    valCorner.Parent = valueLabel

    local rightBtn = Instance.new("TextButton")
    rightBtn.Size = UDim2.new(0, 22, 0, 22)
    rightBtn.Position = UDim2.new(1, -26, 0.5, -11)
    rightBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    rightBtn.Text = ">"
    rightBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextSize = 12
    rightBtn.Parent = frame

    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 4)
    rightCorner.Parent = rightBtn

    local function updateVal()
        valueLabel.Text = options[index]
        if callback then callback(options[index]) end
    end

    leftBtn.MouseButton1Click:Connect(function()
        index = index - 1
        if index < 1 then index = #options end
        updateVal()
    end)

    rightBtn.MouseButton1Click:Connect(function()
        index = index + 1
        if index > #options then index = 1 end
        updateVal()
    end)
end

local function addTextBox(tab, text, defaultText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    frame.Parent = tab.Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 110, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 225)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -125, 0, 22)
    box.Position = UDim2.new(0, 115, 0.5, -11)
    box.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    box.Text = defaultText or ""
    box.PlaceholderText = "Ahmet, Mehmet..."
    box.TextColor3 = Color3.fromRGB(0, 255, 170)
    box.Font = Enum.Font.Gotham
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
    end)
end

local function addActionButtons(tab, saveCb, loadCb)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -6, 0, 38)
    frame.BackgroundTransparency = 1
    frame.Parent = tab.Content

    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(0.48, 0, 1, 0)
    sBtn.Position = UDim2.new(0, 0, 0, 0)
    sBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
    sBtn.Text = "Config Kaydet"
    sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.Parent = frame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 6)
    sCorner.Parent = sBtn

    local lBtn = Instance.new("TextButton")
    lBtn.Size = UDim2.new(0.48, 0, 1, 0)
    lBtn.Position = UDim2.new(0.52, 0, 0, 0)
    lBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    lBtn.Text = "Config Yükle"
    lBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lBtn.Font = Enum.Font.GothamBold
    lBtn.TextSize = 11
    lBtn.Parent = frame

    local lCorner = Instance.new("UICorner")
    lCorner.CornerRadius = UDim.new(0, 6)
    lCorner.Parent = lBtn

    sBtn.MouseButton1Click:Connect(saveCb)
    lBtn.MouseButton1Click:Connect(loadCb)
end

-- SEKMELER
local combatTab = createTab("Combat")
local visualTab = createTab("Görsel (ESP)")
local settingsTab = createTab("Ayarlar & Config")

-- COMBAT TAB
addToggle(combatTab, "Aimbot Aktif", Config.Aimbot.Enabled, function(state) Config.Aimbot.Enabled = state end)
addToggle(combatTab, "KnockCheck (Baygın Es Geç)", Config.Aimbot.KnockCheck, function(state) Config.Aimbot.KnockCheck = state end)
addToggle(combatTab, "WallCheck (Duvar Kontrolü)", Config.Aimbot.WallCheck, function(state) Config.Aimbot.WallCheck = state end)
addToggle(combatTab, "Team Check (Takım Arkadaşı)", Config.Aimbot.TeamCheck, function(state) Config.Aimbot.TeamCheck = state end)
addToggle(combatTab, "Dinamik Ping Prediction", Config.Aimbot.DynamicPrediction, function(state) Config.Aimbot.DynamicPrediction = state end)
addArrowSelector(combatTab, "Hedef Önceliği", {"Crosshair", "Distance", "Health"}, 1, function(val) Config.Aimbot.Priority = val end)
addArrowSelector(combatTab, "Hedef Bölgesi", {"Head", "HumanoidRootPart"}, 1, function(val) Config.Aimbot.AimPart = val end)
addToggle(combatTab, "FOV Çemberi Göster", Config.Aimbot.ShowFOV, function(state) Config.Aimbot.ShowFOV = state end)
addKeybind(combatTab, "Aimbot Tuşu", Config.Aimbot.TriggerKey, function(key) Config.Aimbot.TriggerKey = key; RuntimeState.IsAiming = false end)

-- VISUAL TAB
addToggle(visualTab, "ESP Genel Aktif", Config.ESP.Enabled, function(state) Config.ESP.Enabled = state end)
addToggle(visualTab, "Takım ESP Es Geç", Config.ESP.TeamCheck, function(state) Config.ESP.TeamCheck = state end)
addToggle(visualTab, "Baygın ESP Es Geç", Config.ESP.KnockCheck, function(state) Config.ESP.KnockCheck = state end)
addToggle(visualTab, "2D Box ESP", Config.ESP.Box2D, function(state) Config.ESP.Box2D = state end)
addToggle(visualTab, "3D Box ESP", Config.ESP.Box3D, function(state) Config.ESP.Box3D = state end)
addToggle(visualTab, "Skeleton ESP (İskelet)", Config.ESP.Skeleton, function(state) Config.ESP.Skeleton = state end)
addToggle(visualTab, "Health Bar & Text", Config.ESP.HealthBar, function(state) Config.ESP.HealthBar = state end)
addToggle(visualTab, "Name & Distance ESP", Config.ESP.NameDistance, function(state) Config.ESP.NameDistance = state end)
addToggle(visualTab, "Held Weapon ESP", Config.ESP.WeaponESP, function(state) Config.ESP.WeaponESP = state end)
addToggle(visualTab, "Head Dot (Kafa Noktası)", Config.ESP.HeadDot, function(state) Config.ESP.HeadDot = state end)
addToggle(visualTab, "Off-Screen Indicators (Oklar)", Config.ESP.OffScreenArrows, function(state) Config.ESP.OffScreenArrows = state end)
addToggle(visualTab, "Tracers (Çizgi ESP)", Config.ESP.Tracers, function(state) Config.ESP.Tracers = state end)
addToggle(visualTab, "Chams (Glow Highlight)", Config.ESP.Chams, function(state) Config.ESP.Chams = state end)
addToggle(visualTab, "SkinChanger (Silah Efekti)", Config.SkinChanger.Enabled, function(state) Config.SkinChanger.Enabled = state end)
addToggle(visualTab, "Fullbright (Aydınlatma)", Config.Misc.Fullbright, function(state) Config.Misc.Fullbright = state end)

-- SETTINGS TAB
addTextBox(settingsTab, "Whitelist (İsimler)", Config.Whitelist.Names, function(val) Config.Whitelist.Names = val end)
addKeybind(settingsTab, "Menü Tuşu", Config.Misc.MenuKey, function(key) Config.Misc.MenuKey = key end)

-- CONFIG YÖNETİCİSİ
local function SaveConfig()
    if writefile then
        pcall(function()
            local data = HttpService:JSONEncode(Config)
            writefile("Gemini10Core_Config.json", data)
        end)
    end
end

local function LoadConfig()
    if readfile and isfile and isfile("Gemini10Core_Config.json") then
        pcall(function()
            local data = HttpService:JSONDecode(readfile("Gemini10Core_Config.json"))
            if data then
                for category, tbl in pairs(data) do
                    if Config[category] then
                        for k, v in pairs(tbl) do
                            Config[category][k] = v
                        end
                    end
                end
            end
        end)
    end
end

addActionButtons(settingsTab, SaveConfig, LoadConfig)

--==============================================================================--
--                            GÜÇLENDİRİLMİŞ AIMBOT ENGINE                       --
--==============================================================================--

local FOVCircle = nil
pcall(function()
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(0, 255, 170)
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Visible = false
end)

local function IsPartVisible(targetPart)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local destination = targetPart.Position
    local direction = (destination - origin)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {LocalPlayer.Character, Camera}
    if targetPart.Parent then table.insert(ignoreList, targetPart.Parent) end
    raycastParams.FilterDescendantsInstances = ignoreList
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestScore = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if not IsWhitelisted(player) and not (Config.Aimbot.TeamCheck and IsTeamMate(player)) then
                if not (Config.Aimbot.KnockCheck and IsPlayerKnocked(player)) then
                    local targetPart = player.Character:FindFirstChild(Config.Aimbot.AimPart)
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    
                    if targetPart and humanoid and humanoid.Health > 0 then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        
                        -- CRITICAL FIX: Z > 0 Kontrolü (Arka Tarafı Kilitlenmeden Engeller)
                        if onScreen and screenPos.Z > 0 then
                            local fovDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if fovDist <= Config.Aimbot.FOV and IsPartVisible(targetPart) then
                                local score = math.huge
                                if Config.Aimbot.Priority == "Crosshair" then
                                    score = fovDist
                                elseif Config.Aimbot.Priority == "Distance" then
                                    score = (targetPart.Position - Camera.CFrame.Position).Magnitude
                                elseif Config.Aimbot.Priority == "Health" then
                                    score = humanoid.Health
                                end

                                if score < bestScore then
                                    bestScore = score
                                    bestTarget = targetPart
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

--==============================================================================--
--                            GÜÇLENDİRİLMİŞ ESP ENGINE                          --
--==============================================================================--

local function GetPlayerDrawings(player)
    if not RuntimeState.DrawingPool[player] then
        RuntimeState.DrawingPool[player] = {
            Box2D = Drawing.new("Square"),
            HeadDot = Drawing.new("Circle"),
            Tracer = Drawing.new("Line"),
            NameText = Drawing.new("Text"),
            HealthText = Drawing.new("Text"),
            WeaponText = Drawing.new("Text"),
            HealthBarBg = Drawing.new("Square"),
            HealthBar = Drawing.new("Square"),
            Arrow = Drawing.new("Triangle"),
            SkeletonLines = {},
            Box3DLines = {}
        }
        for i = 1, 12 do
            table.insert(RuntimeState.DrawingPool[player].Box3DLines, Drawing.new("Line"))
        end
        for i = 1, 15 do
            table.insert(RuntimeState.DrawingPool[player].SkeletonLines, Drawing.new("Line"))
        end
    end
    return RuntimeState.DrawingPool[player]
end

local function HideAllDrawings(drawData)
    if not drawData then return end
    pcall(function()
        drawData.Box2D.Visible = false
        drawData.HeadDot.Visible = false
        drawData.Tracer.Visible = false
        drawData.NameText.Visible = false
        drawData.HealthText.Visible = false
        drawData.WeaponText.Visible = false
        drawData.HealthBarBg.Visible = false
        drawData.HealthBar.Visible = false
        drawData.Arrow.Visible = false
        for _, line in ipairs(drawData.Box3DLines) do line.Visible = false end
        for _, line in ipairs(drawData.SkeletonLines) do line.Visible = false end
    end)
end

local function ClearDrawings(player)
    if RuntimeState.DrawingPool[player] then
        HideAllDrawings(RuntimeState.DrawingPool[player])
        pcall(function()
            local d = RuntimeState.DrawingPool[player]
            d.Box2D:Remove()
            d.HeadDot:Remove()
            d.Tracer:Remove()
            d.NameText:Remove()
            d.HealthText:Remove()
            d.WeaponText:Remove()
            d.HealthBarBg:Remove()
            d.HealthBar:Remove()
            d.Arrow:Remove()
            for _, line in ipairs(d.Box3DLines) do line:Remove() end
            for _, line in ipairs(d.SkeletonLines) do line:Remove() end
        end)
        RuntimeState.DrawingPool[player] = nil
    end
end

Players.PlayerRemoving:Connect(ClearDrawings)

local function ProcessVisuals()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local isKnocked = Config.ESP.KnockCheck and IsPlayerKnocked(player)
            local isTeam = Config.ESP.TeamCheck and IsTeamMate(player)
            local isWhite = IsWhitelisted(player)

            if Config.ESP.Enabled and char and not isKnocked and not isTeam and not isWhite then
                local draw = GetPlayerDrawings(player)
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("Head")
                local humanoid = char:FindFirstChildOfClass("Humanoid")

                -- Chams Highlight
                local highlight = char:FindFirstChild("GeminiChams")
                if Config.ESP.Chams then
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "GeminiChams"
                        highlight.Parent = char
                    end
                    highlight.FillColor = Config.ESP.FillColor
                    highlight.OutlineColor = Config.ESP.OutlineColor
                    highlight.FillTransparency = Config.ESP.FillTransparency
                    highlight.OutlineTransparency = Config.ESP.OutlineTransparency
                    highlight.Enabled = true
                else
                    if highlight then highlight:Destroy() end
                end

                if hrp and head and humanoid and humanoid.Health > 0 then
                    local hrpPos, hrpOnScreen = Camera:WorldToViewportPoint(hrp.Position)
                    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos, legOnScreen = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                    -- CRITICAL FIX: Z > 0 Kontrolü (Ekran Ortasındaki Bozuklukları Engeller)
                    local isFullyOnScreen = hrpOnScreen and headOnScreen and legOnScreen and hrpPos.Z > 0 and headPos.Z > 0 and legPos.Z > 0

                    if isFullyOnScreen then
                        local boxHeight = math.abs(headPos.Y - legPos.Y)
                        local boxWidth = boxHeight * 0.6

                        -- 2D Box ESP
                        if Config.ESP.Box2D then
                            draw.Box2D.Size = Vector2.new(boxWidth, boxHeight)
                            draw.Box2D.Position = Vector2.new(hrpPos.X - boxWidth / 2, headPos.Y)
                            draw.Box2D.Color = Config.ESP.FillColor
                            draw.Box2D.Thickness = 1.5
                            draw.Box2D.Filled = false
                            draw.Box2D.Visible = true
                        else draw.Box2D.Visible = false end

                        -- Health Bar & Text ESP
                        if Config.ESP.HealthBar then
                            local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            local barHeight = boxHeight * healthPercent

                            draw.HealthBarBg.Size = Vector2.new(4, boxHeight)
                            draw.HealthBarBg.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 7, headPos.Y)
                            draw.HealthBarBg.Color = Color3.fromRGB(30, 30, 30)
                            draw.HealthBarBg.Filled = true
                            draw.HealthBarBg.Visible = true

                            draw.HealthBar.Size = Vector2.new(2, barHeight)
                            draw.HealthBar.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 6, headPos.Y + (boxHeight - barHeight))
                            draw.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                            draw.HealthBar.Filled = true
                            draw.HealthBar.Visible = true

                            draw.HealthText.Text = string.format("%%%d", math.floor(healthPercent * 100))
                            draw.HealthText.Position = Vector2.new(hrpPos.X - boxWidth / 2 - 24, headPos.Y + (boxHeight - barHeight) - 6)
                            draw.HealthText.Color = Color3.fromRGB(255, 255, 255)
                            draw.HealthText.Size = 10
                            draw.HealthText.Center = true
                            draw.HealthText.Outline = true
                            draw.HealthText.Visible = true
                        else
                            draw.HealthBarBg.Visible = false
                            draw.HealthBar.Visible = false
                            draw.HealthText.Visible = false
                        end

                        -- Name & Distance ESP
                        if Config.ESP.NameDistance then
                            local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                            draw.NameText.Text = string.format("%s [%dm]", player.DisplayName, dist)
                            draw.NameText.Position = Vector2.new(hrpPos.X, headPos.Y - 16)
                            draw.NameText.Color = Color3.fromRGB(255, 255, 255)
                            draw.NameText.Size = 11
                            draw.NameText.Center = true
                            draw.NameText.Outline = true
                            draw.NameText.Visible = true
                        else draw.NameText.Visible = false end

                        -- Held Weapon ESP
                        if Config.ESP.WeaponESP then
                            draw.WeaponText.Text = GetHeldWeapon(player)
                            draw.WeaponText.Position = Vector2.new(hrpPos.X, legPos.Y + 2)
                            draw.WeaponText.Color = Color3.fromRGB(0, 255, 170)
                            draw.WeaponText.Size = 10
                            draw.WeaponText.Center = true
                            draw.WeaponText.Outline = true
                            draw.WeaponText.Visible = true
                        else draw.WeaponText.Visible = false end

                        -- Head Dot ESP
                        if Config.ESP.HeadDot then
                            local hPos = Camera:WorldToViewportPoint(head.Position)
                            draw.HeadDot.Position = Vector2.new(hPos.X, hPos.Y)
                            draw.HeadDot.Radius = math.clamp(boxHeight / 12, 2, 6)
                            draw.HeadDot.Color = Config.ESP.FillColor
                            draw.HeadDot.Filled = true
                            draw.HeadDot.Visible = true
                        else draw.HeadDot.Visible = false end

                        -- Tracers ESP
                        if Config.ESP.Tracers then
                            draw.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            draw.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y)
                            draw.Tracer.Color = Config.ESP.FillColor
                            draw.Tracer.Thickness = 1.2
                            draw.Tracer.Visible = true
                        else draw.Tracer.Visible = false end

                        -- Skeleton ESP
                        if Config.ESP.Skeleton then
                            local joints = {
                                {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
                                {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
                                {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
                                {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
                                {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
                            }
                            for idx, pair in ipairs(joints) do
                                local p1 = char:FindFirstChild(pair[1])
                                local p2 = char:FindFirstChild(pair[2])
                                local line = draw.SkeletonLines[idx]
                                if p1 and p2 and line then
                                    local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
                                    local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
                                    if vis1 and vis2 and pos1.Z > 0 and pos2.Z > 0 then
                                        line.From = Vector2.new(pos1.X, pos1.Y)
                                        line.To = Vector2.new(pos2.X, pos2.Y)
                                        line.Color = Config.ESP.OutlineColor
                                        line.Thickness = 1
                                        line.Visible = true
                                    else line.Visible = false end
                                else if line then line.Visible = false end end
                            end
                        else
                            for _, line in ipairs(draw.SkeletonLines) do line.Visible = false end
                        end

                        -- 3D Box ESP
                        if Config.ESP.Box3D then
                            local size = char:GetExtentsSize()
                            local cf = hrp.CFrame
                            local corners = {
                                cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
                                cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
                                cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)
                            }
                            local connections = {
                                {1,2}, {2,3}, {3,4}, {4,1},
                                {5,6}, {6,7}, {7,8}, {8,5},
                                {1,5}, {2,6}, {3,7}, {4,8}
                            }
                            for i, conn in ipairs(connections) do
                                local line = draw.Box3DLines[i]
                                local p1, vis1 = Camera:WorldToViewportPoint(corners[conn[1]].Position)
                                local p2, vis2 = Camera:WorldToViewportPoint(corners[conn[2]].Position)
                                if vis1 and vis2 and p1.Z > 0 and p2.Z > 0 and line then
                                    line.From = Vector2.new(p1.X, p1.Y)
                                    line.To = Vector2.new(p2.X, p2.Y)
                                    line.Color = Config.ESP.FillColor
                                    line.Thickness = 1.2
                                    line.Visible = true
                                else if line then line.Visible = false end end
                            end
                        else
                            for _, line in ipairs(draw.Box3DLines) do line.Visible = false end
                        end

                        draw.Arrow.Visible = false
                    else
                        -- Ekran Dışındaki Oyuncular için Ok ESP
                        HideAllDrawings(draw)
                        if Config.ESP.OffScreenArrows then
                            local relativeVector = Camera.CFrame:PointToObjectSpace(hrp.Position)
                            local angle = math.atan2(-relativeVector.X, -relativeVector.Z)
                            local radius = 180
                            local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                            
                            local p1 = center + Vector2.new(math.sin(angle) * radius, -math.cos(angle) * radius)
                            local p2 = p1 + Vector2.new(math.sin(angle + 2.5) * 12, -math.cos(angle + 2.5) * 12)
                            local p3 = p1 + Vector2.new(math.sin(angle - 2.5) * 12, -math.cos(angle - 2.5) * 12)

                            draw.Arrow.PointA = p1
                            draw.Arrow.PointB = p2
                            draw.Arrow.PointC = p3
                            draw.Arrow.Color = Config.ESP.FillColor
                            draw.Arrow.Filled = true
                            draw.Arrow.Visible = true
                        end
                    end
                else
                    if RuntimeState.DrawingPool[player] then
                        HideAllDrawings(RuntimeState.DrawingPool[player])
                    end
                end
            else
                if RuntimeState.DrawingPool[player] then
                    HideAllDrawings(RuntimeState.DrawingPool[player])
                end
            end
        end
    end
end

local function ProcessSkinChanger()
    if not Config.SkinChanger.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            for _, obj in ipairs(tool:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                    obj.Material = Config.SkinChanger.Material
                    obj.Color = Config.SkinChanger.Color
                end
            end
        end
    end
end



UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not Config.Aimbot.Enabled then return end
    if IsInputMatch(input, Config.Aimbot.TriggerKey) then
        RuntimeState.IsAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if IsInputMatch(input, Config.Aimbot.TriggerKey) then
        RuntimeState.IsAiming = false
    end
end)

RunService.RenderStepped:Connect(function(deltaTime)
    -- FOV Çemberi Güncelleme
    if FOVCircle then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
    end

    
    ProcessVisuals()
    ProcessSkinChanger()


    if Config.Aimbot.Enabled and RuntimeState.IsAiming then
        local targetPart = GetClosestTarget()
        if targetPart then
            local velocity = targetPart.Velocity or Vector3.zero
            local predTime = Config.Aimbot.Prediction
            if Config.Aimbot.DynamicPrediction then
                predTime = GetPing()
            end
            local predictedPosition = targetPart.Position + (velocity * predTime)
            local currentCam = Camera.CFrame
            local targetCFrame = CFrame.new(currentCam.Position, predictedPosition)
            
            -- Smoothness Yumuşatma
            local alpha = math.clamp((1 - Config.Aimbot.Smoothness) * (deltaTime * 60), 0.01, 1)
            Camera.CFrame = currentCam:Lerp(targetCFrame, alpha)
        end
    end

    if Config.Misc.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
    end
end)
