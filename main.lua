local ESP = {
    Enabled = true,
    TeamCheck = false,
    AliveOnly = true,
    MaxDistance = 1500,

    Box = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Outline = true, Fill = false, FillTransparency = 0.75},
    Box3D = {Enabled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1},
    Name = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Size = 13, Font = Drawing.Fonts.Plex, Outline = true, Position = "Top"},
    HealthBar = {Enabled = true, Position = "Left", Width = 2, Outline = true, Gradient = true},
    HealthText = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Weapon = {Enabled = true, Color = Color3.fromRGB(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Distance = {Enabled = true, Color = Color3.fromRGB(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Skeleton = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5},
    Tracer = {Enabled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Origin = "Bottom"},
    Chams = {Enabled = true, FillColor = Color3.fromRGB(128, 0, 255), OutlineColor = Color3.fromRGB(255, 255, 255), FillTransparency = 0.6, OutlineTransparency = 0},
    Glow = {Enabled = false, Color = Color3.fromRGB(128, 0, 255), Transparency = 0.5, Size = 5},

    EnemyColor = Color3.fromRGB(255, 50, 50),
    TeamColor = Color3.fromRGB(50, 255, 50),
    UseTeamColors = false,

    Objects = {},
    Connections = {},
    HighlightCache = {}
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local C3 = Color3.fromRGB

local function NewDrawing(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local SKELETON_R15 = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local SKELETON_R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return V2(vec.X, vec.Y), onScreen, vec.Z
end

local function GetBoundingBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local pos, onScreen, depth = WorldToScreen(rootPart.Position)
    if depth <= 0 then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local rigType = humanoid.RigType == Enum.HumanoidRigType.R15

    local headPart = character:FindFirstChild("Head")
    if not headPart then return nil end

    local topPos = WorldToScreen((headPart.CFrame * CF(0, 0.75, 0)).Position)
    local bottomPos = WorldToScreen((rootPart.CFrame * CF(0, -3, 0)).Position)

    local height = math.abs(bottomPos.Y - topPos.Y)
    local width = height * 0.55

    local center = V2((topPos.X + bottomPos.X) / 2, (topPos.Y + bottomPos.Y) / 2)

    return {
        TopLeft = V2(center.X - width / 2, topPos.Y),
        TopRight = V2(center.X + width / 2, topPos.Y),
        BottomLeft = V2(center.X - width / 2, bottomPos.Y),
        BottomRight = V2(center.X + width / 2, bottomPos.Y),
        Width = width,
        Height = height,
        Center = center,
        Top = topPos,
        Bottom = bottomPos,
        OnScreen = onScreen,
        Depth = depth
    }
end

local function Get3DBoundingBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local cf = rootPart.CFrame
    local size = V3(4, 6, 2)

    local corners = {
        cf * CF( size.X/2,  size.Y/2,  size.Z/2).Position,
        cf * CF(-size.X/2,  size.Y/2,  size.Z/2).Position,
        cf * CF( size.X/2, -size.Y/2,  size.Z/2).Position,
        cf * CF(-size.X/2, -size.Y/2,  size.Z/2).Position,
        cf * CF( size.X/2,  size.Y/2, -size.Z/2).Position,
        cf * CF(-size.X/2,  size.Y/2, -size.Z/2).Position,
        cf * CF( size.X/2, -size.Y/2, -size.Z/2).Position,
        cf * CF(-size.X/2, -size.Y/2, -size.Z/2).Position
    }

    local screenCorners = {}
    for i, corner in ipairs(corners) do
        local sp, _, d = WorldToScreen(corner)
        if d <= 0 then return nil end
        screenCorners[i] = sp
    end

    return screenCorners
end

local function GetHealthColor(health, maxHealth)
    local ratio = math.clamp(health / maxHealth, 0, 1)
    if ratio > 0.5 then
        return Color3.fromRGB(255 * (1 - ratio) * 2, 255, 0)
    else
        return Color3.fromRGB(255, 255 * ratio * 2, 0)
    end
end

local function GetPlayerColor(player)
    if ESP.UseTeamColors and player.Team then
        return player.Team == LocalPlayer.Team and ESP.TeamColor or ESP.EnemyColor
    end
    return ESP.EnemyColor
end

local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return true
end

local function IsTeammate(player)
    if not ESP.TeamCheck then return false end
    if not player.Team or not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function GetTool(character)
    for _, v in ipairs(character:GetChildren()) do
        if v:IsA("Tool") then
            return v.Name
        end
    end
    return "None"
end

local function GetDistance(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not LocalPlayer.Character then return math.huge end
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return math.huge end
    return math.floor((root.Position - myRoot.Position).Magnitude)
end

function ESP:CreateESPObjects(player)
    if self.Objects[player] then return end

    local obj = {
        BoxOutline = NewDrawing("Square", {Visible = false, Color = C3(0, 0, 0), Thickness = 3, Filled = false, Transparency = 1}),
        Box = NewDrawing("Square", {Visible = false, Color = C3(255, 255, 255), Thickness = 1, Filled = false, Transparency = 1}),
        BoxFill = NewDrawing("Square", {Visible = false, Color = C3(255, 255, 255), Thickness = 1, Filled = true, Transparency = 0.75}),

        Box3DLines = {},

        NameText = NewDrawing("Text", {Visible = false, Center = true, Color = C3(255, 255, 255), Size = 13, Font = Drawing.Fonts.Plex, Outline = true, OutlineColor = C3(0, 0, 0)}),

        HealthBarOutline = NewDrawing("Line", {Visible = false, Color = C3(0, 0, 0), Thickness = 4}),
        HealthBarBG = NewDrawing("Line", {Visible = false, Color = C3(30, 30, 30), Thickness = 2}),
        HealthBar = NewDrawing("Line", {Visible = false, Color = C3(0, 255, 0), Thickness = 2}),
        HealthText = NewDrawing("Text", {Visible = false, Center = true, Color = C3(255, 255, 255), Size = 11, Font = Drawing.Fonts.Plex, Outline = true, OutlineColor = C3(0, 0, 0)}),

        WeaponText = NewDrawing("Text", {Visible = false, Center = true, Color = C3(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true, OutlineColor = C3(0, 0, 0)}),

        DistanceText = NewDrawing("Text", {Visible = false, Center = true, Color = C3(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true, OutlineColor = C3(0, 0, 0)}),

        TracerLine = NewDrawing("Line", {Visible = false, Color = C3(255, 255, 255), Thickness = 1}),

        SkeletonLines = {},

        Highlight = nil
    }

    for i = 1, 12 do
        obj.Box3DLines[i] = NewDrawing("Line", {Visible = false, Color = C3(255, 255, 255), Thickness = 1})
    end

    for i = 1, 14 do
        obj.SkeletonLines[i] = NewDrawing("Line", {Visible = false, Color = C3(255, 255, 255), Thickness = 1.5})
    end

    self.Objects[player] = obj
end

function ESP:RemoveESPObjects(player)
    local obj = self.Objects[player]
    if not obj then return end

    obj.BoxOutline:Remove()
    obj.Box:Remove()
    obj.BoxFill:Remove()
    obj.NameText:Remove()
    obj.HealthBarOutline:Remove()
    obj.HealthBarBG:Remove()
    obj.HealthBar:Remove()
    obj.HealthText:Remove()
    obj.WeaponText:Remove()
    obj.DistanceText:Remove()
    obj.TracerLine:Remove()

    for _, line in ipairs(obj.Box3DLines) do
        line:Remove()
    end

    for _, line in ipairs(obj.SkeletonLines) do
        line:Remove()
    end

    if obj.Highlight and obj.Highlight.Parent then
        obj.Highlight:Destroy()
    end

    self.Objects[player] = nil
end

function ESP:HideAll(obj)
    obj.BoxOutline.Visible = false
    obj.Box.Visible = false
    obj.BoxFill.Visible = false
    obj.NameText.Visible = false
    obj.HealthBarOutline.Visible = false
    obj.HealthBarBG.Visible = false
    obj.HealthBar.Visible = false
    obj.HealthText.Visible = false
    obj.WeaponText.Visible = false
    obj.DistanceText.Visible = false
    obj.TracerLine.Visible = false

    for _, line in ipairs(obj.Box3DLines) do
        line.Visible = false
    end

    for _, line in ipairs(obj.SkeletonLines) do
        line.Visible = false
    end

    if obj.Highlight and obj.Highlight.Parent then
        obj.Highlight.Enabled = false
    end
end

function ESP:UpdatePlayer(player)
    local obj = self.Objects[player]
    if not obj then return end

    if not self.Enabled or player == LocalPlayer or IsTeammate(player) or not IsAlive(player) then
        self:HideAll(obj)
        return
    end

    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local dist = GetDistance(character)

    if dist > self.MaxDistance then
        self:HideAll(obj)
        return
    end

    local bb = GetBoundingBox(character)
    if not bb then
        self:HideAll(obj)
        return
    end

    local color = GetPlayerColor(player)
    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local healthColor = GetHealthColor(health, maxHealth)

    if self.Box.Enabled and not self.Box3D.Enabled then
        obj.Box.Visible = true
        obj.Box.Position = bb.TopLeft
        obj.Box.Size = V2(bb.Width, bb.Height)
        obj.Box.Color = self.Box.Color == C3(255, 255, 255) and color or self.Box.Color
        obj.Box.Thickness = self.Box.Thickness

        if self.Box.Outline then
            obj.BoxOutline.Visible = true
            obj.BoxOutline.Position = bb.TopLeft
            obj.BoxOutline.Size = V2(bb.Width, bb.Height)
            obj.BoxOutline.Thickness = self.Box.Thickness + 2
        else
            obj.BoxOutline.Visible = false
        end

        if self.Box.Fill then
            obj.BoxFill.Visible = true
            obj.BoxFill.Position = bb.TopLeft
            obj.BoxFill.Size = V2(bb.Width, bb.Height)
            obj.BoxFill.Color = self.Box.Color == C3(255, 255, 255) and color or self.Box.Color
            obj.BoxFill.Transparency = self.Box.FillTransparency
        else
            obj.BoxFill.Visible = false
        end
    else
        obj.Box.Visible = false
        obj.BoxOutline.Visible = false
        obj.BoxFill.Visible = false
    end

    if self.Box3D.Enabled then
        local corners = Get3DBoundingBox(character)
        if corners then
            local edges = {
                {1, 2}, {1, 3}, {2, 4}, {3, 4},
                {5, 6}, {5, 7}, {6, 8}, {7, 8},
                {1, 5}, {2, 6}, {3, 7}, {4, 8}
            }
            for i, edge in ipairs(edges) do
                obj.Box3DLines[i].Visible = true
                obj.Box3DLines[i].From = corners[edge[1]]
                obj.Box3DLines[i].To = corners[edge[2]]
                obj.Box3DLines[i].Color = self.Box3D.Color == C3(255, 255, 255) and color or self.Box3D.Color
                obj.Box3DLines[i].Thickness = self.Box3D.Thickness
            end
        else
            for _, line in ipairs(obj.Box3DLines) do
                line.Visible = false
            end
        end
        obj.Box.Visible = false
        obj.BoxOutline.Visible = false
        obj.BoxFill.Visible = false
    else
        for _, line in ipairs(obj.Box3DLines) do
            line.Visible = false
        end
    end

    local bottomTextOffset = 2

    if self.Name.Enabled then
        obj.NameText.Visible = true
        obj.NameText.Text = player.DisplayName
        obj.NameText.Color = self.Name.Color == C3(255, 255, 255) and color or self.Name.Color
        obj.NameText.Size = self.Name.Size
        obj.NameText.Font = self.Name.Font
        obj.NameText.Outline = self.Name.Outline

        if self.Name.Position == "Top" then
            obj.NameText.Position = V2(bb.Center.X, bb.Top.Y - self.Name.Size - 4)
        else
            obj.NameText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomTextOffset)
            bottomTextOffset = bottomTextOffset + self.Name.Size + 2
        end
    else
        obj.NameText.Visible = false
    end

    if self.HealthBar.Enabled then
        local barHeight = bb.Height
        local healthRatio = math.clamp(health / maxHealth, 0, 1)
        local filledHeight = barHeight * healthRatio
        local barX

        if self.HealthBar.Position == "Left" then
            barX = bb.TopLeft.X - 5
        else
            barX = bb.TopRight.X + 5
        end

        if self.HealthBar.Outline then
            obj.HealthBarOutline.Visible = true
            obj.HealthBarOutline.From = V2(barX, bb.Top.Y - 1)
            obj.HealthBarOutline.To = V2(barX, bb.Bottom.Y + 1)
            obj.HealthBarOutline.Thickness = self.HealthBar.Width + 2
            obj.HealthBarOutline.Color = C3(0, 0, 0)
        else
            obj.HealthBarOutline.Visible = false
        end

        obj.HealthBarBG.Visible = true
        obj.HealthBarBG.From = V2(barX, bb.Top.Y)
        obj.HealthBarBG.To = V2(barX, bb.Bottom.Y)
        obj.HealthBarBG.Thickness = self.HealthBar.Width
        obj.HealthBarBG.Color = C3(30, 30, 30)

        obj.HealthBar.Visible = true
        obj.HealthBar.From = V2(barX, bb.Bottom.Y - filledHeight)
        obj.HealthBar.To = V2(barX, bb.Bottom.Y)
        obj.HealthBar.Thickness = self.HealthBar.Width
        obj.HealthBar.Color = healthColor
    else
        obj.HealthBarOutline.Visible = false
        obj.HealthBarBG.Visible = false
        obj.HealthBar.Visible = false
    end

    if self.HealthText.Enabled and health < maxHealth then
        local healthRatio = math.clamp(health / maxHealth, 0, 1)
        local barX
        if self.HealthBar.Position == "Left" then
            barX = bb.TopLeft.X - 5
        else
            barX = bb.TopRight.X + 5
        end
        local filledHeight = bb.Height * healthRatio
        obj.HealthText.Visible = true
        obj.HealthText.Text = tostring(math.floor(health))
        obj.HealthText.Position = V2(barX, bb.Bottom.Y - filledHeight - self.HealthText.Size - 2)
        obj.HealthText.Color = healthColor
        obj.HealthText.Size = self.HealthText.Size
        obj.HealthText.Font = self.HealthText.Font
        obj.HealthText.Outline = self.HealthText.Outline
    else
        obj.HealthText.Visible = false
    end

    if self.Weapon.Enabled then
        local tool = GetTool(character)
        obj.WeaponText.Visible = true
        obj.WeaponText.Text = "[" .. tool .. "]"
        obj.WeaponText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomTextOffset)
        obj.WeaponText.Color = self.Weapon.Color
        obj.WeaponText.Size = self.Weapon.Size
        obj.WeaponText.Font = self.Weapon.Font
        obj.WeaponText.Outline = self.Weapon.Outline
        bottomTextOffset = bottomTextOffset + self.Weapon.Size + 2
    else
        obj.WeaponText.Visible = false
    end

    if self.Distance.Enabled then
        obj.DistanceText.Visible = true
        obj.DistanceText.Text = tostring(dist) .. " studs"
        obj.DistanceText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomTextOffset)
        obj.DistanceText.Color = self.Distance.Color
        obj.DistanceText.Size = self.Distance.Size
        obj.DistanceText.Font = self.Distance.Font
        obj.DistanceText.Outline = self.Distance.Outline
        bottomTextOffset = bottomTextOffset + self.Distance.Size + 2
    else
        obj.DistanceText.Visible = false
    end

    if self.Tracer.Enabled then
        local screenSize = Camera.ViewportSize
        local from
        if self.Tracer.Origin == "Bottom" then
            from = V2(screenSize.X / 2, screenSize.Y)
        elseif self.Tracer.Origin == "Top" then
            from = V2(screenSize.X / 2, 0)
        else
            from = V2(screenSize.X / 2, screenSize.Y / 2)
        end

        obj.TracerLine.Visible = true
        obj.TracerLine.From = from
        obj.TracerLine.To = V2(bb.Center.X, bb.Bottom.Y)
        obj.TracerLine.Color = self.Tracer.Color == C3(255, 255, 255) and color or self.Tracer.Color
        obj.TracerLine.Thickness = self.Tracer.Thickness
    else
        obj.TracerLine.Visible = false
    end

    if self.Skeleton.Enabled then
        local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
        local bones = isR15 and SKELETON_R15 or SKELETON_R6

        for i, bone in ipairs(bones) do
            local part1 = character:FindFirstChild(bone[1])
            local part2 = character:FindFirstChild(bone[2])

            if part1 and part2 then
                local sp1, _, d1 = WorldToScreen(part1.Position)
                local sp2, _, d2 = WorldToScreen(part2.Position)

                if d1 > 0 and d2 > 0 then
                    obj.SkeletonLines[i].Visible = true
                    obj.SkeletonLines[i].From = sp1
                    obj.SkeletonLines[i].To = sp2
                    obj.SkeletonLines[i].Color = self.Skeleton.Color == C3(255, 255, 255) and color or self.Skeleton.Color
                    obj.SkeletonLines[i].Thickness = self.Skeleton.Thickness
                else
                    obj.SkeletonLines[i].Visible = false
                end
            else
                obj.SkeletonLines[i].Visible = false
            end
        end

        for i = #bones + 1, #obj.SkeletonLines do
            obj.SkeletonLines[i].Visible = false
        end
    else
        for _, line in ipairs(obj.SkeletonLines) do
            line.Visible = false
        end
    end

    if self.Chams.Enabled then
        if not obj.Highlight or not obj.Highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "ESPChams_" .. player.UserId
            hl.Adornee = character
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillColor = self.Chams.FillColor
            hl.OutlineColor = self.Chams.OutlineColor
            hl.FillTransparency = self.Chams.FillTransparency
            hl.OutlineTransparency = self.Chams.OutlineTransparency
            hl.Parent = character
            obj.Highlight = hl
        else
            obj.Highlight.Adornee = character
            obj.Highlight.FillColor = self.Chams.FillColor
            obj.Highlight.OutlineColor = self.Chams.OutlineColor
            obj.Highlight.FillTransparency = self.Chams.FillTransparency
            obj.Highlight.OutlineTransparency = self.Chams.OutlineTransparency
            obj.Highlight.Enabled = true
        end
    else
        if obj.Highlight and obj.Highlight.Parent then
            obj.Highlight.Enabled = false
        end
    end

    if self.Glow.Enabled then
        if not obj.Highlight or not obj.Highlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "ESPGlow_" .. player.UserId
            hl.Adornee = character
            hl.DepthMode = Enum.HighlightDepthMode.Occluded
            hl.FillColor = self.Glow.Color
            hl.OutlineColor = self.Glow.Color
            hl.FillTransparency = self.Glow.Transparency
            hl.OutlineTransparency = 0
            hl.Parent = character
            obj.Highlight = hl
        end
    end
end

function ESP:Init()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:CreateESPObjects(player)
        end
    end

    self.Connections[#self.Connections + 1] = Players.PlayerAdded:Connect(function(player)
        self:CreateESPObjects(player)
    end)

    self.Connections[#self.Connections + 1] = Players.PlayerRemoving:Connect(function(player)
        self:RemoveESPObjects(player)
    end)

    self.Connections[#self.Connections + 1] = RunService.RenderStepped:Connect(function()
        Camera = workspace.CurrentCamera
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and self.Objects[player] then
                self:UpdatePlayer(player)
            end
        end
    end)
end

function ESP:Toggle(state)
    self.Enabled = state
    if not state then
        for player, obj in pairs(self.Objects) do
            self:HideAll(obj)
        end
    end
end

function ESP:SetColor(color)
    self.EnemyColor = color
end

function ESP:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}

    for player, _ in pairs(self.Objects) do
        self:RemoveESPObjects(player)
    end
    self.Objects = {}
end

return ESP
