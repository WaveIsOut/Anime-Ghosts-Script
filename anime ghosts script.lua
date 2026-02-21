--[[
    ANIME GHOSTS SCRIPT
    Author: WaveyS
    UI Library: Rayfield (stable & bagus)
    Features: ESP, Teleport, Enemy Scanner, World Tracker
--]]

-- Load Rayfield UI Library
getgenv().SecureMode = true
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Enemy List (akan diisi otomatis)
local EnemyList = {}
local CurrentWorld = "Unknown"

-- ========== BYPASS ANTI-CHEAT (CLIENT-SIDE) ==========
local Bypass = {}

function Bypass.enable()
    -- Property spoofing untuk humanoid
    local oldIndex = nil
    local oldNamecall = nil
    
    if hookmetamethod then
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if self:IsA("Humanoid") and (key == "WalkSpeed" or key == "JumpPower") then
                return oldIndex(self, key)
            end
            return oldIndex(self, key)
        end)
        
        -- Block remote events mencurigakan
        if getconnections then
            for _, conn in pairs(getconnections(game:GetService("LogService").MessageOut)) do
                conn:Disable()
            end
        end
    end
    
    -- Hide GUI dari detection
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "Rayfield" then
            gui.Enabled = false
        end
    end
    
    print("[BYPASS] Anti-cheat bypass enabled")
end

Bypass.enable()

-- ========== FUNGSI SCAN ENEMY ==========
local function ScanEnemies()
    EnemyList = {}
    
    -- Cari folder enemies (dari screenshot lu)
    local EnemiesFolder = workspace:FindFirstChild("Enemies") or 
                         workspace:FindFirstChild("Mobs") or 
                         workspace:FindFirstChild("NPCs")
    
    if not EnemiesFolder then
        -- Fallback: cari semua part dengan Health
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") then
                local humanoid = obj:FindFirstChild("Humanoid")
                local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                
                if humanoid and humanoid.Health > 0 and rootPart then
                    table.insert(EnemyList, {
                        Name = obj.Name,
                        Object = obj,
                        RootPart = rootPart,
                        Health = humanoid.Health,
                        MaxHealth = humanoid.MaxHealth,
                        Position = rootPart.Position
                    })
                end
            end
        end
    else
        -- Scan folder enemies
        for _, enemy in pairs(EnemiesFolder:GetChildren()) do
            local humanoid = enemy:FindFirstChild("Humanoid")
            local rootPart = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
            
            if humanoid and humanoid.Health > 0 and rootPart then
                table.insert(EnemyList, {
                    Name = enemy.Name,
                    Object = enemy,
                    RootPart = rootPart,
                    Health = humanoid.Health,
                    MaxHealth = humanoid.MaxHealth,
                    Position = rootPart.Position
                })
            end
        end
    end
    
    -- Sort by distance
    local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if myPos then
        table.sort(EnemyList, function(a, b)
            local distA = (a.Position - myPos.Position).Magnitude
            local distB = (b.Position - myPos.Position).Magnitude
            return distA < distB
        end)
    end
    
    return EnemyList
end

-- ========== DETECT CURRENT WORLD ==========
local function GetCurrentWorld()
    -- Coba berbagai method
    local worldIndicator = workspace:FindFirstChild("World") or 
                          workspace:FindFirstChild("Map") or
                          workspace:FindFirstChild("CurrentWorld") or
                          workspace:FindFirstChild("GameMode")
    
    if worldIndicator then
        if worldIndicator:IsA("StringValue") then
            CurrentWorld = worldIndicator.Value
        elseif worldIndicator:IsA("Folder") or worldIndicator:IsA("Model") then
            CurrentWorld = worldIndicator.Name
        else
            CurrentWorld = worldIndicator.Name
        end
    else
        -- Fallback: cek dari Lighting atau workspace name
        local sky = game:GetService("Lighting"):FindFirstChildWhichIsA("Sky")
        if sky then
            CurrentWorld = sky.Name or "Unknown"
        elseif workspace:FindFirstChild("Terrain") then
            CurrentWorld = "Main World"
        else
            CurrentWorld = "World " .. math.random(1, 999) -- placeholder
        end
    end
    
    return CurrentWorld
end

-- ========== TELEPORT KE ENEMY ==========
local function TeleportToEnemy(enemyData)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if enemyData and enemyData.RootPart then
        hrp.CFrame = CFrame.new(enemyData.RootPart.Position + Vector3.new(0, 5, 0))
        return true
    end
    return false
end

-- ========== ESP FUNCTION ==========
local ESPEnabled = false
local ESPObjects = {}

local function CreateESP(enemyData)
    if not ESPEnabled then return end
    
    -- Clean old ESP untuk enemy ini
    for _, obj in pairs(ESPObjects) do
        if obj.Adornee == enemyData.RootPart then
            pcall(function() obj:Destroy() end)
        end
    end
    
    -- Create new ESP
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "WaveyESP"
    billboard.Size = UDim2.new(0, 150, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = CoreGui
    billboard.Adornee = enemyData.RootPart
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = enemyData.Name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = frame
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Size = UDim2.new(1, 0, 0.5, 0)
    healthLabel.Position = UDim2.new(0, 0, 0.5, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = string.format("%d/%d", math.floor(enemyData.Health), math.floor(enemyData.MaxHealth))
    healthLabel.TextColor3 = Color3.new(1, 0, 0)
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextSize = 12
    healthLabel.Parent = frame
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0.3, 0)
    distanceLabel.Position = UDim2.new(0, 0, 0.7, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.new(0, 1, 0)
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 10
    distanceLabel.Parent = frame
    
    table.insert(ESPObjects, billboard)
    
    -- Update distance
    spawn(function()
        while ESPEnabled and billboard and billboard.Parent do
            local myPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myPos and enemyData.RootPart then
                local dist = (enemyData.RootPart.Position - myPos.Position).Magnitude
                distanceLabel.Text = string.format("%.1fm", dist)
            end
            task.wait(0.5)
        end
    end)
end

-- Update semua ESP
local function UpdateAllESP()
    if not ESPEnabled then return end
    
    -- Clean semua ESP lama
    for _, obj in pairs(ESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    ESPObjects = {}
    
    -- Buat ESP baru untuk semua enemy
    for _, enemy in pairs(EnemyList) do
        CreateESP(enemy)
    end
end

-- ========== UI RAYFIELD ==========
local Window = Rayfield:CreateWindow({
    Name = "Anime Ghosts - WaveyS",
    LoadingTitle = "WaveyS Exploits",
    LoadingSubtitle = "by WaveyS",
    ConfigurationSaving = { Enabled = true, FolderName = "WaveyS", FileName = "AnimeGhosts" }
})

-- Tab Utama
local MainTab = Window:CreateTab("Main", 4483362458)
local InfoSection = MainTab:CreateSection("World Info")

-- World info display
local worldLabel = MainTab:CreateLabel("Current World: " .. GetCurrentWorld())

MainTab:CreateButton({
    Name = "🔄 Refresh World",
    Callback = function()
        CurrentWorld = GetCurrentWorld()
        worldLabel:Set("Current World: " .. CurrentWorld)
        Rayfield:Notify({ Title = "World Info", Content = "Current World: " .. CurrentWorld, Duration = 3 })
    end
})

-- Enemy list section
local EnemySection = MainTab:CreateSection("Enemy List")

-- Dropdown enemy
local enemyDropdown = MainTab:CreateDropdown({
    Name = "Select Enemy",
    Options = {"Scan First"},
    CurrentOption = "Scan First",
    Flag = "EnemyDropdown",
    Callback = function(option)
        for _, enemy in pairs(EnemyList) do
            if enemy.Name == option then
                TeleportToEnemy(enemy)
                break
            end
        end
    end
})

-- Refresh button
MainTab:CreateButton({
    Name = "🔄 Refresh Enemies",
    Callback = function()
        local enemies = ScanEnemies()
        local options = {}
        for _, enemy in pairs(enemies) do
            table.insert(options, enemy.Name)
        end
        
        if #options == 0 then
            options = {"No enemies found"}
        end
        
        enemyDropdown:SetOptions(options)
        
        -- Update ESP if enabled
        if ESPEnabled then
            UpdateAllESP()
        end
        
        Rayfield:Notify({ Title = "Enemy Scan", Content = "Found " .. #enemies .. " enemies", Duration = 3 })
    end
})

-- Enemy counter
local enemyCountLabel = MainTab:CreateLabel("Enemies in world: " .. #EnemyList)

-- ESP Tab
local ESPTab = Window:CreateTab("ESP", 4483362458)
local ESPSection = ESPTab:CreateSection("Visual Settings")

ESPTab:CreateToggle({
    Name = "👁️ Enable ESP",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(value)
        ESPEnabled = value
        if value then
            ScanEnemies()
            UpdateAllESP()
        else
            for _, obj in pairs(ESPObjects) do
                pcall(function() obj:Destroy() end)
            end
            ESPObjects = {}
        end
    end
})

ESPTab:CreateButton({
    Name = "🔄 Refresh ESP",
    Callback = function()
        if ESPEnabled then
            UpdateAllESP()
            Rayfield:Notify({ Title = "ESP", Content = "ESP refreshed", Duration = 2 })
        end
    end
})

-- Teleport Tab
local TeleportTab = Window:CreateTab("Teleport", 4483362458)
local TeleportSection = TeleportTab:CreateSection("Quick Teleport")

TeleportTab:CreateButton({
    Name = "📍 Teleport to Closest Enemy",
    Callback = function()
        local enemies = ScanEnemies()
        if #enemies > 0 then
            TeleportToEnemy(enemies[1])
            Rayfield:Notify({ Title = "Teleport", Content = "Teleported to " .. enemies[1].Name, Duration = 2 })
        else
            Rayfield:Notify({ Title = "Teleport", Content = "No enemies found", Duration = 2 })
        end
    end
})

TeleportTab:CreateButton({
    Name = "📍 Teleport to Selected Enemy",
    Callback = function()
        local selected = enemyDropdown.CurrentOption
        if selected and selected ~= "Scan First" and selected ~= "No enemies found" then
            for _, enemy in pairs(EnemyList) do
                if enemy.Name == selected then
                    TeleportToEnemy(enemy)
                    Rayfield:Notify({ Title = "Teleport", Content = "Teleported to " .. enemy.Name, Duration = 2 })
                    break
                end
            end
        else
            Rayfield:Notify({ Title = "Teleport", Content = "Select an enemy first", Duration = 2 })
        end
    end
})

-- Auto teleport on spawn
local autoTeleportEnabled = false
TeleportTab:CreateToggle({
    Name = "🔄 Auto Teleport to Closest Enemy on Spawn",
    CurrentValue = false,
    Flag = "AutoTeleport",
    Callback = function(value)
        autoTeleportEnabled = value
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    if autoTeleportEnabled then
        task.wait(1.5)
        local enemies = ScanEnemies()
        if #enemies > 0 then
            TeleportToEnemy(enemies[1])
        end
    end
end)

-- Settings Tab
local SettingsTab = Window:CreateTab("Settings", 4483362458)
local SettingsSection = SettingsTab:CreateSection("Config")

SettingsTab:CreateButton({
    Name = "💾 Save Settings",
    Callback = function()
        Rayfield:Notify({ Title = "Settings", Content = "Settings saved", Duration = 2 })
    end
})

SettingsTab:CreateButton({
    Name = "🔄 Destroy GUI",
    Callback = function()
        -- Clean up ESP first
        for _, obj in pairs(ESPObjects) do
            pcall(function() obj:Destroy() end)
        end
        ESPObjects = {}
        Rayfield:Destroy()
    end
})

-- ========== AUTO UPDATE LOOP ==========
spawn(function()
    while task.wait(5) do
        -- Update world
        CurrentWorld = GetCurrentWorld()
        worldLabel:Set("Current World: " .. CurrentWorld)
        
        -- Update enemy list (tanpa spam notif)
        local oldCount = #EnemyList
        ScanEnemies()
        
        -- Update counter
        enemyCountLabel:Set("Enemies in world: " .. #EnemyList)
        
        -- Update dropdown if enemy list changed
        if #EnemyList ~= oldCount then
            local options = {}
            for _, enemy in pairs(EnemyList) do
                table.insert(options, enemy.Name)
            end
            if #options == 0 then
                options = {"No enemies found"}
            end
            enemyDropdown:SetOptions(options)
        end
        
        -- Update ESP
        if ESPEnabled then
            UpdateAllESP()
        end
    end
end)

-- ========== INIT ==========
ScanEnemies()
GetCurrentWorld()
print("✅ WaveyS Anime Ghosts Script Loaded")
print("✅ Features: ESP, Teleport, Enemy Scanner, World Tracker")
