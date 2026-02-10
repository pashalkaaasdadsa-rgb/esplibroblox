local ESP = {
    Enabled = true,
    TeamCheck = false,
    AliveOnly = true,
    MaxDistance = 1500,

    Box = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Outline = true, Fill = false, FillTransparency = 0.75},
    Box3D = {Enabled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1},
    Name = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Size = 13, Font = Drawing.Fonts.Plex, Outline = true, Position = "Top"},
    HealthBar = {Enabled = true, Position = "Left", Width = 2, Outline = true},
    HealthText = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Weapon = {Enabled = true, Color = Color3.fromRGB(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Distance = {Enabled = true, Color = Color3.fromRGB(200, 200, 200), Size = 11, Font = Drawing.Fonts.Plex, Outline = true},
    Skeleton = {Enabled = true, Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5},
    Tracer = {Enabled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Origin = "Bottom"},

    Chams = {
        Enabled = true,
        FillColor = Color3.fromRGB(128, 0, 255),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.6,
        OutlineTransparency = 0
    },

    Glow = {
        Enabled = true,
        VisibleColor = Color3.fromRGB(128, 0, 255),
        HiddenColor = Color3.fromRGB(255, 50, 50),
        VisibleTransparency = 0.7,
        HiddenTransparency = 0.5,
        OutlineTransparency = 0
    },

    Objects = {},
    Connections = {}
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local C3 = Color3.fromRGB

local MAX_SKELETON = 24

local function NewDrawing(class, props)
    local obj = Drawing.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return V2(vec.X, vec.Y), onScreen, vec.Z
end

local function GetSkeletonLines(character)
    local result = {}
    local inMotor = {}
    local outMotors = {}

    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            local p0, p1 = desc.Part0, desc.Part1
            if p0 and p1 and p0.Parent == character and p1.Parent == character then
                inMotor[p1] = desc
                if not outMotors[p0] then
                    outMotors[p0] = {}
                end
                outMotors[p0][#outMotors[p0] + 1] = desc
            end
        end
    end

    for part, motor in pairs(inMotor) do
        if not motor.Part0 or not motor.Part0.Parent then break end

        local jointPos = (motor.Part0.CFrame * motor.C0).Position
        local children = outMotors[part]

        if children then
            for _, child in ipairs(children) do
                if child.Part0 and child.Part0.Parent then
                    local childPos = (child.Part0.CFrame * child.C0).Position
                    result[#result + 1] = {jointPos, childPos}
                end
            end
        else
            local name = part.Name
            if name == "Head" then
                result[#result + 1] = {jointPos, (part.CFrame * CF(0, part.Size.Y * 0.4, 0)).Position}
            elseif name:find("Hand") or name:find("Arm") then
                result[#result + 1] = {jointPos, (part.CFrame * CF(0, -part.Size.Y * 0.4, 0)).Position}
            elseif name:find("Foot") or name:find("Leg") then
                result[#result + 1] = {jointPos, (part.CFrame * CF(0, -part.Size.Y * 0.5, 0)).Position}
            end
        end
    end

    return result
end

local function GetBoundingBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local _, _, depth = WorldToScreen(rootPart.Position)
    if depth <= 0 then return nil end

    local minY, maxY = math.huge, -math.huge
    local minX, maxX = math.huge, -math.huge

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local cf = part.CFrame
            local sz = part.Size

            local corners = {
                cf * CF( sz.X/2,  sz.Y/2, 0),
                cf * CF(-sz.X/2,  sz.Y/2, 0),
                cf * CF( sz.X/2, -sz.Y/2, 0),
                cf * CF(-sz.X/2, -sz.Y/2, 0)
            }

            for _, c in ipairs(corners) do
                local sp, _, d = WorldToScreen(c.Position)
                if d > 0 then
                    if sp.X < minX then minX = sp.X end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end

    if minX == math.huge then return nil end

    local width = maxX - minX
    local height = maxY - minY

    local padX = width * 0.05
    local padY = height * 0.02

    minX = minX - padX
    maxX = maxX + padX
    minY = minY - padY
    maxY = maxY + padY

    width = maxX - minX
    height = maxY - minY

    return {
        TopLeft = V2(minX, minY),
        TopRight = V2(maxX, minY),
        BottomLeft = V2(minX, maxY),
        BottomRight = V2(maxX, maxY),
        Width = width,
        Height = height,
        Center = V2(minX + width / 2, minY + height / 2),
        Top = V2(minX + width / 2, minY),
        Bottom = V2(minX + width / 2, maxY),
        Depth = depth
    }
end

local function Get3DBoundingBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end

    local cf = rootPart.CFrame

    local minLocal = V3(math.huge, math.huge, math.huge)
    local maxLocal = V3(-math.huge, -math.huge, -math.huge)

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local rel = cf:PointToObjectSpace(part.Position)
            local sz = part.Size / 2

            local lo = rel - V3(sz.X, sz.Y, sz.Z)
            local hi = rel + V3(sz.X, sz.Y, sz.Z)

            minLocal = V3(math.min(minLocal.X, lo.X), math.min(minLocal.Y, lo.Y), math.min(minLocal.Z, lo.Z))
            maxLocal = V3(math.max(maxLocal.X, hi.X), math.max(maxLocal.Y, hi.Y), math.max(maxLocal.Z, hi.Z))
        end
    end

    if minLocal.X == math.huge then return nil end

    local corners = {}
    for _, sx in ipairs({minLocal.X, maxLocal.X}) do
        for _, sy in ipairs({minLocal.Y, maxLocal.Y}) do
            for _, sz in ipairs({minLocal.Z, maxLocal.Z}) do
                local wp = cf:PointToWorldSpace(V3(sx, sy, sz))
                local sp, _, d = WorldToScreen(wp)
                if d <= 0 then return nil end
                corners[#corners + 1] = sp
            end
        end
    end

    return corners
end

local function GetHealthColor(health, maxHealth)
    local r = math.clamp(health / maxHealth, 0, 1)
    if r > 0.5 then
        return C3(255 * (1 - r) * 2, 255, 0)
    end
    return C3(255, 255 * r * 2, 0)
end

local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function IsTeammate(player)
    if not ESP.TeamCheck then return false end
    if not player.Team or not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function GetTool(character)
    for _, v in ipairs(character:GetChildren()) do
        if v:IsA("Tool") then return v.Name end
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
        SkeletonOutlines = {},
        ChamsHighlight = nil,
        GlowVisible = nil,
        GlowHidden = nil
    }

    for i = 1, 12 do
        obj.Box3DLines[i] = NewDrawing("Line", {Visible = false, Color = C3(255, 255, 255), Thickness = 1})
    end

    for i = 1, MAX_SKELETON do
        obj.SkeletonOutlines[i] = NewDrawing("Line", {Visible = false, Color = C3(0, 0, 0), Thickness = 3.5})
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

    for _, l in ipairs(obj.Box3DLines) do l:Remove() end
    for _, l in ipairs(obj.SkeletonLines) do l:Remove() end
    for _, l in ipairs(obj.SkeletonOutlines) do l:Remove() end

    if obj.ChamsHighlight and obj.ChamsHighlight.Parent then obj.ChamsHighlight:Destroy() end
    if obj.GlowVisible and obj.GlowVisible.Parent then obj.GlowVisible:Destroy() end
    if obj.GlowHidden and obj.GlowHidden.Parent then obj.GlowHidden:Destroy() end

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

    for _, l in ipairs(obj.Box3DLines) do l.Visible = false end
    for _, l in ipairs(obj.SkeletonLines) do l.Visible = false end
    for _, l in ipairs(obj.SkeletonOutlines) do l.Visible = false end

    if obj.ChamsHighlight and obj.ChamsHighlight.Parent then obj.ChamsHighlight.Enabled = false end
    if obj.GlowVisible and obj.GlowVisible.Parent then obj.GlowVisible.Enabled = false end
    if obj.GlowHidden and obj.GlowHidden.Parent then obj.GlowHidden.Enabled = false end
end

function ESP:UpdateHighlights(obj, character)
    if self.Chams.Enabled then
        if not obj.ChamsHighlight or not obj.ChamsHighlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "_ch"
            hl.Adornee = character
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = character
            obj.ChamsHighlight = hl
        end
        obj.ChamsHighlight.Adornee = character
        obj.ChamsHighlight.FillColor = self.Chams.FillColor
        obj.ChamsHighlight.OutlineColor = self.Chams.OutlineColor
        obj.ChamsHighlight.FillTransparency = self.Chams.FillTransparency
        obj.ChamsHighlight.OutlineTransparency = self.Chams.OutlineTransparency
        obj.ChamsHighlight.Enabled = true
    else
        if obj.ChamsHighlight and obj.ChamsHighlight.Parent then obj.ChamsHighlight.Enabled = false end
    end

    if self.Glow.Enabled then
        if not obj.GlowVisible or not obj.GlowVisible.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "_gv"
            hl.Adornee = character
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = character
            obj.GlowVisible = hl
        end
        obj.GlowVisible.Adornee = character
        obj.GlowVisible.FillColor = self.Glow.VisibleColor
        obj.GlowVisible.OutlineColor = self.Glow.VisibleColor
        obj.GlowVisible.FillTransparency = 1
        obj.GlowVisible.OutlineTransparency = self.Glow.OutlineTransparency
        obj.GlowVisible.Enabled = true

        if not obj.GlowHidden or not obj.GlowHidden.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "_gh"
            hl.Adornee = character
            hl.DepthMode = Enum.HighlightDepthMode.Occluded
            hl.Parent = character
            obj.GlowHidden = hl
        end
        obj.GlowHidden.Adornee = character
        obj.GlowHidden.FillColor = self.Glow.HiddenColor
        obj.GlowHidden.OutlineColor = self.Glow.HiddenColor
        obj.GlowHidden.FillTransparency = self.Glow.HiddenTransparency
        obj.GlowHidden.OutlineTransparency = self.Glow.OutlineTransparency
        obj.GlowHidden.Enabled = true
    else
        if obj.GlowVisible and obj.GlowVisible.Parent then obj.GlowVisible.Enabled = false end
        if obj.GlowHidden and obj.GlowHidden.Parent then obj.GlowHidden.Enabled = false end
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

    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local healthColor = GetHealthColor(health, maxHealth)

    if self.Box.Enabled and not self.Box3D.Enabled then
        obj.Box.Visible = true
        obj.Box.Position = bb.TopLeft
        obj.Box.Size = V2(bb.Width, bb.Height)
        obj.Box.Color = self.Box.Color
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
            obj.BoxFill.Color = self.Box.Color
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
                {1,2},{1,3},{2,4},{3,4},
                {5,6},{5,7},{6,8},{7,8},
                {1,5},{2,6},{3,7},{4,8}
            }
            for i, edge in ipairs(edges) do
                obj.Box3DLines[i].Visible = true
                obj.Box3DLines[i].From = corners[edge[1]]
                obj.Box3DLines[i].To = corners[edge[2]]
                obj.Box3DLines[i].Color = self.Box3D.Color
                obj.Box3DLines[i].Thickness = self.Box3D.Thickness
            end
        else
            for _, l in ipairs(obj.Box3DLines) do l.Visible = false end
        end
    else
        for _, l in ipairs(obj.Box3DLines) do l.Visible = false end
    end

    local bottomOff = 2

    if self.Name.Enabled then
        obj.NameText.Visible = true
        obj.NameText.Text = player.DisplayName
        obj.NameText.Color = self.Name.Color
        obj.NameText.Size = self.Name.Size
        obj.NameText.Font = self.Name.Font

        if self.Name.Position == "Top" then
            obj.NameText.Position = V2(bb.Center.X, bb.Top.Y - self.Name.Size - 4)
        else
            obj.NameText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomOff)
            bottomOff = bottomOff + self.Name.Size + 2
        end
    else
        obj.NameText.Visible = false
    end

    if self.HealthBar.Enabled then
        local ratio = math.clamp(health / maxHealth, 0, 1)
        local filled = bb.Height * ratio
        local barX = self.HealthBar.Position == "Left" and (bb.TopLeft.X - 5) or (bb.TopRight.X + 5)

        if self.HealthBar.Outline then
            obj.HealthBarOutline.Visible = true
            obj.HealthBarOutline.From = V2(barX, bb.Top.Y - 1)
            obj.HealthBarOutline.To = V2(barX, bb.Bottom.Y + 1)
            obj.HealthBarOutline.Thickness = self.HealthBar.Width + 2
        else
            obj.HealthBarOutline.Visible = false
        end

        obj.HealthBarBG.Visible = true
        obj.HealthBarBG.From = V2(barX, bb.Top.Y)
        obj.HealthBarBG.To = V2(barX, bb.Bottom.Y)
        obj.HealthBarBG.Thickness = self.HealthBar.Width

        obj.HealthBar.Visible = true
        obj.HealthBar.From = V2(barX, bb.Bottom.Y - filled)
        obj.HealthBar.To = V2(barX, bb.Bottom.Y)
        obj.HealthBar.Thickness = self.HealthBar.Width
        obj.HealthBar.Color = healthColor
    else
        obj.HealthBarOutline.Visible = false
        obj.HealthBarBG.Visible = false
        obj.HealthBar.Visible = false
    end

    if self.HealthText.Enabled and health < maxHealth then
        local ratio = math.clamp(health / maxHealth, 0, 1)
        local barX = self.HealthBar.Position == "Left" and (bb.TopLeft.X - 5) or (bb.TopRight.X + 5)
        local filled = bb.Height * ratio
        obj.HealthText.Visible = true
        obj.HealthText.Text = tostring(math.floor(health))
        obj.HealthText.Position = V2(barX, bb.Bottom.Y - filled - self.HealthText.Size - 2)
        obj.HealthText.Color = healthColor
        obj.HealthText.Size = self.HealthText.Size
        obj.HealthText.Font = self.HealthText.Font
    else
        obj.HealthText.Visible = false
    end

    if self.Weapon.Enabled then
        obj.WeaponText.Visible = true
        obj.WeaponText.Text = "[" .. GetTool(character) .. "]"
        obj.WeaponText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomOff)
        obj.WeaponText.Color = self.Weapon.Color
        obj.WeaponText.Size = self.Weapon.Size
        obj.WeaponText.Font = self.Weapon.Font
        bottomOff = bottomOff + self.Weapon.Size + 2
    else
        obj.WeaponText.Visible = false
    end

    if self.Distance.Enabled then
        obj.DistanceText.Visible = true
        obj.DistanceText.Text = tostring(dist) .. "m"
        obj.DistanceText.Position = V2(bb.Center.X, bb.Bottom.Y + bottomOff)
        obj.DistanceText.Color = self.Distance.Color
        obj.DistanceText.Size = self.Distance.Size
        obj.DistanceText.Font = self.Distance.Font
        bottomOff = bottomOff + self.Distance.Size + 2
    else
        obj.DistanceText.Visible = false
    end

    if self.Tracer.Enabled then
        local sv = Camera.ViewportSize
        local from
        if self.Tracer.Origin == "Bottom" then
            from = V2(sv.X / 2, sv.Y)
        elseif self.Tracer.Origin == "Top" then
            from = V2(sv.X / 2, 0)
        else
            from = V2(sv.X / 2, sv.Y / 2)
        end
        obj.TracerLine.Visible = true
        obj.TracerLine.From = from
        obj.TracerLine.To = V2(bb.Center.X, bb.Bottom.Y)
        obj.TracerLine.Color = self.Tracer.Color
        obj.TracerLine.Thickness = self.Tracer.Thickness
    else
        obj.TracerLine.Visible = false
    end

    if self.Skeleton.Enabled then
        local lines = GetSkeletonLines(character)
        local count = math.min(#lines, MAX_SKELETON)

        for i = 1, count do
            local p1, p2 = lines[i][1], lines[i][2]
            local sp1, _, d1 = WorldToScreen(p1)
            local sp2, _, d2 = WorldToScreen(p2)

            if d1 > 0 and d2 > 0 then
                obj.SkeletonOutlines[i].Visible = true
                obj.SkeletonOutlines[i].From = sp1
                obj.SkeletonOutlines[i].To = sp2
                obj.SkeletonOutlines[i].Thickness = self.Skeleton.Thickness + 2
                obj.SkeletonOutlines[i].Color = C3(0, 0, 0)

                obj.SkeletonLines[i].Visible = true
                obj.SkeletonLines[i].From = sp1
                obj.SkeletonLines[i].To = sp2
                obj.SkeletonLines[i].Color = self.Skeleton.Color
                obj.SkeletonLines[i].Thickness = self.Skeleton.Thickness
            else
                obj.SkeletonOutlines[i].Visible = false
                obj.SkeletonLines[i].Visible = false
            end
        end

        for i = count + 1, MAX_SKELETON do
            obj.SkeletonOutlines[i].Visible = false
            obj.SkeletonLines[i].Visible = false
        end
    else
        for i = 1, MAX_SKELETON do
            obj.SkeletonOutlines[i].Visible = false
            obj.SkeletonLines[i].Visible = false
        end
    end

    self:UpdateHighlights(obj, character)
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
        for _, obj in pairs(self.Objects) do
            self:HideAll(obj)
        end
    end
end

function ESP:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
    for player in pairs(self.Objects) do
        self:RemoveESPObjects(player)
    end
    self.Objects = {}
end

return ESP
