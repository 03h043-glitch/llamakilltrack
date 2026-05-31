local _, LTL = ...

local settingsFrame

local function FormatSliderValue(value, step)
    if step >= 1 then
        return tostring(LTL.Round(value))
    end

    return string.format("%.2f", value)
end

local function CreateCheckButton(parent, name, label, key, x, y)
    local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(label)
    check:SetChecked(LTL.db[key])
    check:SetScript("OnClick", function(self)
        LTL.db[key] = self:GetChecked() and true or false
        LTL.ApplyTrackerSettings()
    end)

    return check
end

local function CreateSlider(parent, name, label, minValue, maxValue, step, value, x, y, onChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(250)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetValue(value)

    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    _G[name .. "Text"]:SetText(label)
    _G[name .. "Low"]:SetText(tostring(minValue))
    _G[name .. "High"]:SetText(tostring(maxValue))

    slider:SetScript("OnValueChanged", function(self, newValue)
        newValue = LTL.Round(newValue / step) * step
        onChanged(newValue)
        self.Value:SetText(FormatSliderValue(newValue, step))
    end)

    slider.Value = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.Value:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    slider.Value:SetText(FormatSliderValue(value, step))

    return slider
end

function LTL.SyncPositionControls()
    if LTL.controls.xSlider then
        LTL.controls.xSlider:SetValue(LTL.db.x)
    end
    if LTL.controls.ySlider then
        LTL.controls.ySlider:SetValue(LTL.db.y)
    end
end

function LTL.SyncSettingsControls()
    local controls = LTL.controls
    if controls.locked then
        controls.locked:SetChecked(LTL.db.locked)
    end
    if controls.scaleSlider then
        controls.scaleSlider:SetValue(LTL.db.scale)
    end
    if controls.windowOpacitySlider then
        controls.windowOpacitySlider:SetValue(LTL.db.windowOpacity)
    end
    if controls.textOpacitySlider then
        controls.textOpacitySlider:SetValue(LTL.db.textOpacity)
    end
    if controls.redSlider then
        controls.redSlider:SetValue(LTL.db.bgR)
    end
    if controls.greenSlider then
        controls.greenSlider:SetValue(LTL.db.bgG)
    end
    if controls.blueSlider then
        controls.blueSlider:SetValue(LTL.db.bgB)
    end
    LTL.SyncPositionControls()
end

local function RefreshPositionSliderRanges()
    if not LTL.controls.xSlider or not LTL.controls.ySlider then
        return
    end

    local width = UIParent:GetWidth() or 1200
    local height = UIParent:GetHeight() or 800
    local xLimit = math.floor((width / 2) - 60)
    local yLimit = math.floor((height / 2) - 30)

    LTL.controls.xSlider:SetMinMaxValues(-xLimit, xLimit)
    LTL.controls.ySlider:SetMinMaxValues(-yLimit, yLimit)
    _G[LTL.controls.xSlider:GetName() .. "Low"]:SetText(tostring(-xLimit))
    _G[LTL.controls.xSlider:GetName() .. "High"]:SetText(tostring(xLimit))
    _G[LTL.controls.ySlider:GetName() .. "Low"]:SetText(tostring(-yLimit))
    _G[LTL.controls.ySlider:GetName() .. "High"]:SetText(tostring(yLimit))

    LTL.db.x = LTL.Clamp(LTL.db.x or 0, -xLimit, xLimit)
    LTL.db.y = LTL.Clamp(LTL.db.y or 160, -yLimit, yLimit)
    LTL.SyncPositionControls()
end

function LTL.OpenSettings()
    if not settingsFrame then
        return
    end

    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

function LTL.CreateSettingsFrame()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    settingsFrame = CreateFrame("Frame", "LlamaToLevelSettingsFrame", UIParent, template)
    settingsFrame:SetSize(365, 620)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:Hide()

    if settingsFrame.SetBackdrop then
        settingsFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    settingsFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    settingsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    settingsFrame:SetScript("OnShow", RefreshPositionSliderRanges)

    local title = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", settingsFrame, "TOP", 0, -18)
    title:SetText("LlamaToLevel")

    local close = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -5, -5)

    local controls = LTL.controls
    controls.showTracker = CreateCheckButton(settingsFrame, "LlamaToLevelShowTrackerCheck", "Show tracker", "showTracker", 22, -52)
    controls.showFloating = CreateCheckButton(settingsFrame, "LlamaToLevelShowFloatingCheck", "Show floating text", "showFloating", 22, -82)
    controls.locked = CreateCheckButton(settingsFrame, "LlamaToLevelLockedCheck", "Lock tracker", "locked", 22, -112)

    controls.scaleSlider = CreateSlider(settingsFrame, "LlamaToLevelScaleSlider", "Tracker size", 0.60, 1.80, 0.05, LTL.db.scale, 58, -160, function(value)
        LTL.db.scale = value
        LTL.ApplyTrackerSettings()
    end)

    controls.windowOpacitySlider = CreateSlider(settingsFrame, "LlamaToLevelWindowOpacitySlider", "Background opacity", 0.00, 1.00, 0.05, LTL.db.windowOpacity, 58, -212, function(value)
        LTL.db.windowOpacity = value
        LTL.ApplyTrackerSettings()
    end)

    controls.textOpacitySlider = CreateSlider(settingsFrame, "LlamaToLevelTextOpacitySlider", "Text opacity", 0.20, 1.00, 0.05, LTL.db.textOpacity, 58, -264, function(value)
        LTL.db.textOpacity = value
        LTL.ApplyTrackerSettings()
    end)

    controls.redSlider = CreateSlider(settingsFrame, "LlamaToLevelRedSlider", "Background red", 0.00, 1.00, 0.05, LTL.db.bgR, 58, -316, function(value)
        LTL.db.bgR = value
        LTL.ApplyTrackerSettings()
    end)

    controls.greenSlider = CreateSlider(settingsFrame, "LlamaToLevelGreenSlider", "Background green", 0.00, 1.00, 0.05, LTL.db.bgG, 58, -368, function(value)
        LTL.db.bgG = value
        LTL.ApplyTrackerSettings()
    end)

    controls.blueSlider = CreateSlider(settingsFrame, "LlamaToLevelBlueSlider", "Background blue", 0.00, 1.00, 0.05, LTL.db.bgB, 58, -420, function(value)
        LTL.db.bgB = value
        LTL.ApplyTrackerSettings()
    end)

    controls.xSlider = CreateSlider(settingsFrame, "LlamaToLevelXSlider", "Horizontal position", -600, 600, 1, LTL.db.x, 58, -472, function(value)
        LTL.db.x = value
        LTL.ApplyTrackerSettings()
    end)

    controls.ySlider = CreateSlider(settingsFrame, "LlamaToLevelYSlider", "Vertical position", -400, 400, 1, LTL.db.y, 58, -524, function(value)
        LTL.db.y = value
        LTL.ApplyTrackerSettings()
    end)

    local reset = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    reset:SetSize(92, 22)
    reset:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 22, 16)
    reset:SetText("Reset")
    reset:SetScript("OnClick", function()
        for key, value in pairs(LTL.defaults) do
            if key ~= "showTracker" and key ~= "showFloating" then
                LTL.db[key] = value
            end
        end
        LTL.SyncSettingsControls()
        LTL.UpdateTracker()
    end)

    local test = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    test:SetSize(92, 22)
    test:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    test:SetText("Test")
    test:SetScript("OnClick", function()
        LTL.ShowFloatingMessage("12 kills / 3 quests to level")
    end)

    local hide = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    hide:SetSize(92, 22)
    hide:SetPoint("LEFT", test, "RIGHT", 10, 0)
    hide:SetText("Close")
    hide:SetScript("OnClick", function()
        settingsFrame:Hide()
    end)
end
