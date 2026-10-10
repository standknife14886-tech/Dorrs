--[[
    T-F Doors ESP — standalone, no external loading
    Запуск: экзекутор (Xeno / Delta / Solara / Wave / Codex)
    Работает: мобилки, ПК, эмуляторы. Root не нужен.
    Меню: RIGHT SHIFT (или кнопка на экране)
]]

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")
local UserInput    = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local Camera       = Workspace.CurrentCamera

local LP = Players.LocalPlayer

-- ===================== CONFIG =====================
local C = {
    DoorESP       = true,
    LockedDoorESP = true,
    FakeDoorESP   = true,
    EntityESP     = true,
    ItemESP       = true,
    FullBright    = true,
    ShowDistance  = true,
    MaxDist       = 500,        -- рисуем только ближе этой дистанции (studs)

    DoorColor     = Color3.fromRGB(0, 255, 120),
    LockedColor   = Color3.fromRGB(255, 60, 60),
    FakeColor     = Color3.fromRGB(255, 200, 0),
    EntityColor   = Color3.fromRGB(255, 30, 30),
    ItemColor     = Color3.fromRGB(0, 180, 255),

    MenuKey       = Enum.KeyCode.RightShift,
}
-- =================================================

-- Fullbright
local function applyFullbright()
    if not C.FullBright then return end
    Lighting.Ambient = Color3.fromRGB(178,178,178)
    Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178)
    Lighting.Brightness = 3
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e6
    Lighting.GlobalShadows = false
end
applyFullbright()

-- Хранилище
local cache = {hl = {}, bb = {}}
local trackedEntities = {}

-- Highlight
local function setHighlight(part, color, name)
    if not part or not part.Parent then return end
    local existing = cache.hl[part]
    if existing and existing.Parent then
        existing.FillColor = color
        existing.OutlineColor = color
        existing.Enabled = true
        return
    end
    local hl = Instance.new("Highlight")
    hl.Name = "TF_" .. name
    hl.FillColor = color
    hl.FillTransparency = 0.45
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = part
    hl.Parent = part
    cache.hl[part] = hl
end

-- Billboard с текстом
local function setBillboard(part, text, color)
    if not part or not part.Parent then return end
    local bb = cache.bb[part]
    if bb and bb.Parent then
        bb.TextLabel.Text = text
        bb.TextLabel.TextColor3 = color
        bb.Enabled = true
        return
    end
    bb = Instance.new("BillboardGui")
    bb.Name = "TF_BB"
    bb.Size = UDim2.new(0, 140, 0, 32)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = part
    bb.Parent = part

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Text = text
    tl.TextColor3 = color
    tl.TextStrokeTransparency = 0
    tl.TextStrokeColor3 = Color3.new(0,0,0)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.Parent = bb
    cache.bb[part] = bb
end

-- Дистанция до игрока
local function distTo(part)
    local char = LP.Character
    if not char then return 0 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root or not part then return 0 end
    return (root.Position - part.Position).Magnitude
end

-- ===================== DOORS =====================
local function scanDoors()
    local container = Workspace:FindFirstChild("DoorModelNew")
    if not container then return end

    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local nm = obj.Name:lower()
            local isDoor = nm:find("door") ~= nil
            if isDoor then
                local color, label = C.DoorColor, "Door"
                local locked = nm:find("lock") ~= nil or nm:find("locked") ~= nil
                local fake   = nm:find("fake") ~= nil or nm:find("exit") ~= nil

                if locked and C.LockedDoorESP then
                    color, label = C.LockedColor, "LOCKED"
                elseif fake and C.FakeDoorESP then
                    color, label = C.FakeColor, "FAKE"
                elseif not C.DoorESP then
                    -- пропускаем обычные, если выключены
                    local skip = true
                    if not (locked and C.LockedDoorESP) and not (fake and C.FakeDoorESP) then
                        skip = false
                    end
                    if not skip then goto continue end
                end

                local num = nm:match("%d+")
                if num then label = label .. " #" .. num end

                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    local d = distTo(part)
                    if d <= C.MaxDist then
                        setHighlight(part, color, "door")
                        if C.ShowDistance then
                            label = string.format("%s [%dm]", label, math.floor(d))
                        end
                        setBillboard(part, label, color)
                    end
                end
            end
        end
        ::continue::
    end
end

-- ===================== ENTITIES =====================
local ENTITY_NAMES = {
    "rush","ambush","seek","halt","eyes","screech","glitch",
    "figure","hide","jack","window","shadow","dupe","snare",
    "timothy","jack","void","guiding","el goblino","halt"
}

local function isEntityName(n)
    n = n:lower()
    for _, e in ipairs(ENTITY_NAMES) do
        if n:find(e, 1, true) then return true end
    end
    return false
end

local function scanEntities()
    local containers = {
        Workspace:FindFirstChild("Entities"),
        Workspace:FindFirstChild("Entity"),
        Workspace:FindFirstChild("Monsters"),
        Workspace,
    }
    for _, cont in ipairs(containers) do
        if cont then
            for _, obj in ipairs(cont:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart")) and isEntityName(obj.Name) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part and part:IsDescendantOf(Workspace) then
                        local d = distTo(part)
                        if d <= C.MaxDist * 2 then
                            setHighlight(part, C.EntityColor, "entity")
                            local label = obj.Name
                            if C.ShowDistance then
                                label = string.format("%s [%dm]", label, math.floor(d))
                            end
                            setBillboard(part, label, C.EntityColor)
                            trackedEntities[obj] = true
                        end
                    end
                end
            end
        end
    end
end

-- ===================== ITEMS =====================
local ITEM_NAMES = {"key","gold","coin","lighter","flashlight","lockpick","vitamin","crucifix","candle","bandage"}

local function isItemName(n)
    n = n:lower()
    for _, e in ipairs(ITEM_NAMES) do
        if n:find(e, 1, true) then return true end
    end
    return false
end

local function scanItems()
    local containers = {
        Workspace:FindFirstChild("Items"),
        Workspace:FindFirstChild("Item"),
        Workspace:FindFirstChild("Pickups"),
    }
    for _, cont in ipairs(containers) do
        if cont then
            for _, obj in ipairs(cont:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart")) and isItemName(obj.Name) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local d = distTo(part)
                        if d <= C.MaxDist then
                            setHighlight(part, C.ItemColor, "item")
                            local label = obj.Name
                            if C.ShowDistance then
                                label = string.format("%s [%dm]", label, math.floor(d))
                            end
                            setBillboard(part, label, C.ItemColor)
                        end
                    end
                end
            end
        end
    end
end

-- ===================== CLEANUP =====================
local function cleanup()
    for part, hl in pairs(cache.hl) do
        if hl and hl.Parent then hl:Destroy() end
    end
    for part, bb in pairs(cache.bb) do
        if bb and bb.Parent then bb:Destroy() end
    end
    cache.hl = {}
    cache.bb = {}
end

-- ===================== MAIN LOOP =====================
local running = true

RunService.Heartbeat:Connect(function()
    if not running then return end
    pcall(function()
        if C.DoorESP or C.LockedDoorESP or C.FakeDoorESP then scanDoors() end
    end)
    pcall(function()
        if C.EntityESP then scanEntities() end
    end)
    pcall(function()
        if C.ItemESP then scanItems() end
    end)
end)

-- ===================== MENU =====================
local function buildMenu()
    if CoreGui:FindFirstChild("TF_DoorsMenu") then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "TF_DoorsMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = CoreGui

    -- Кнопка-открывашка
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = UDim2.new(0, 20, 0.4, 0)
    btn.BackgroundColor3 = Color3.fromRGB(20,20,25)
    btn.TextColor3 = Color3.fromRGB(0,255,120)
    btn.Text = "TF"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 22
    btn.BorderSizePixel = 0
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    -- Главное окно
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 380)
    frame.Position = UDim2.new(0.5, -140, 0.5, -190)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,22)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30,30,38)
    title.Text = "T-F  DOORS ESP"
    title.TextColor3 = Color3.fromRGB(0,255,120)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = frame
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 14)

    -- drag
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInput.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- тогглы
    local y = 55
    local function addToggle(name, key)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -20, 0, 38)
        row.Position = UDim2.new(0, 10, 0, y)
        row.BackgroundColor3 = Color3.fromRGB(28,28,34)
        row.TextColor3 = Color3.fromRGB(230,230,230)
        row.Font = Enum.Font.Gotham
        row.TextSize = 14
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = "  " .. name .. ":  " .. (C[key] and "ON" or "OFF")
        row.TextColor3 = C[key] and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,80,80)
        row.BorderSizePixel = 0
        row.Parent = frame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        row.MouseButton1Click:Connect(function()
            C[key] = not C[key]
            row.Text = "  " .. name .. ":  " .. (C[key] and "ON" or "OFF")
            row.TextColor3 = C[key] and Color3.fromRGB(0,255,120) or Color3.fromRGB(255,80,80)
            if key == "FullBright" then applyFullbright() end
        end)
        y = y + 44
    end

    addToggle("Door ESP", "DoorESP")
    addToggle("Locked Doors", "LockedDoorESP")
    addToggle("Fake Doors", "FakeDoorESP")
    addToggle("Entity ESP", "EntityESP")
    addToggle("Item ESP", "ItemESP")
    addToggle("Show Distance", "ShowDistance")
    addToggle("Fullbright", "FullBright")

    -- close button
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -36, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(255,60,60)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    close.Parent = frame
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
    close.MouseButton1Click:Connect(function() frame.Visible = false end)

    btn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    UserInput.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == C.MenuKey then
            frame.Visible = not frame.Visible
        end
    end)
end

buildMenu()

print("[T-F] Doors ESP loaded. Меню — кнопка TF слева или RIGHT SHIFT.")
print("[T-F] Правишь настройки — блок CONFIG в начале файла.")
