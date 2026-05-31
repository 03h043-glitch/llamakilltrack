local ADDON_NAME = ...

local DEFAULTS = {
    x = 0,
    y = 160,
    scale = 1,
    opacity = 0.85,
    locked = false,
    showTracker = true,
    showFloating = true,
    lastGain = nil,
    lastKills = nil,
    lastRemaining = nil,
}

local db
local events = CreateFrame("Frame")
local tracker
local trackerValue
local trackerDetail
local floatingText
local floatingAnimation
local settingsFrame
local controls = {}

local function CopyDefaults(target, defaults)
    target = target or {}

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function FormatNumber(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    local left, num, right = string.match(tostring(value), "^([^%d]*%d)(%d*)(.-)$")
    if not left then
        return tostring(value)
    end

    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function FormatKills(kills)
    if not kills then
        return "--"
    end

    if kills == 1 then
        return "1 kill"
    end

    return FormatNumber(kills) .. " kills"
end

local function FormatSliderValue(value, step)
    if step >= 1 then
        return tostring(Round(value))
    end

    return string.format("%.2f", value)
end

local function GetRemainingXP()
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0

    if maxXP <= 0 then
        return 0
    end

    return math.max(maxXP - currentXP, 0)
end

local function ApplyTrackerSettings()
    if not tracker or not db then
        return
    end

    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 160)
    tracker:SetScale(db.scale or 1)
    tracker:SetAlpha(db.opacity or 0.85)

    if db.showTracker then
        tracker:Show()
    else
        tracker:Hide()
    end
end

local function UpdateTracker()
    if not trackerValue or not trackerDetail or not db then
        return
    end

    if UnitXPMax("player") == 0 then
        trackerValue:SetText("Max level")
        trackerDetail:SetText("no XP left")
        return
    end

    if db.lastKills and db.lastGain then
        trackerValue:SetText(FormatKills(db.lastKills))
        trackerDetail:SetText("last " .. FormatNumber(db.lastGain) .. " XP")
    else
        trackerValue:SetText("-- kills")
        trackerDetail:SetText("waiting for kill XP")
    end
end

local function RecalculateFromLastGain()
    if not db.lastGain then
        UpdateTracker()
        return
    end

    local remaining = GetRemainingXP()
    db.lastRemaining = remaining

    if UnitXPMax("player") == 0 then
        db.lastKills = nil
    else
        db.lastKills = math.max(math.ceil(remaining / db.lastGain), 0)
    end

    UpdateTracker()
end

local function SaveTrackerPosition()
    local centerX, centerY = tracker:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not centerX or not centerY or not parentX or not parentY then
        return
    end

    db.x = Round(centerX - parentX)
    db.y = Round(centerY - parentY)

    if controls.xSlider then
        controls.xSlider:SetValue(db.x)
    end

    if controls.ySlider then
        controls.ySlider:SetValue(db.y)
    end
end

local function CreateTracker()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    tracker = CreateFrame("Frame", "XToLevelTracker", UIParent, template)
    tracker:SetSize(118, 38)
    tracker:SetClampedToScreen(true)
    tracker:SetMovable(true)
    tracker:EnableMouse(true)
    tracker:RegisterForDrag("LeftButton")

    if tracker.SetBackdrop then
        tracker:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        tracker:SetBackdropColor(0, 0, 0, 0.55)
        tracker:SetBackdropBorderColor(0.35, 0.85, 0.45, 0.65)
    end

    local title = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", tracker, "TOP", 0, -5)
    title:SetText("To level")

    trackerValue = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    trackerValue:SetPoint("TOP", title, "BOTTOM", 0, -1)
    trackerValue:SetJustifyH("CENTER")

    trackerDetail = tracker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    trackerDetail:SetPoint("TOP", trackerValue, "BOTTOM", 0, -1)
    trackerDetail:SetJustifyH("CENTER")

    tracker:SetScript("OnDragStart", function(self)
        if not db.locked then
            self:StartMoving()
        end
    end)

    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveTrackerPosition()
    end)

    tracker:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            if settingsFrame and settingsFrame:IsShown() then
                settingsFrame:Hide()
            else
                if settingsFrame then
                    settingsFrame:Show()
                end
            end
        end
    end)

    tracker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("XToLevel")
        GameTooltip:AddLine("Left-drag to move. Right-click or /xtl for settings.", 0.85, 0.85, 0.85, true)
        if db.lastGain and db.lastKills then
            GameTooltip:AddLine(FormatKills(db.lastKills) .. " at " .. FormatNumber(db.lastGain) .. " XP per kill.", 0.45, 1, 0.45, true)
        end
        GameTooltip:Show()
    end)

    tracker:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ApplyTrackerSettings()
    UpdateTracker()
end

local function CreateFloatingText()
    floatingText = UIParent:CreateFontString("XToLevelFloatingText", "OVERLAY", "CombatTextFont")
    floatingText:SetPoint("TOP", UIParent, "TOP", 0, -170)
    floatingText:SetTextColor(0.45, 1, 0.45)
    floatingText:SetAlpha(0)

    if floatingText.SetShadowColor then
        floatingText:SetShadowColor(0, 0, 0, 1)
        floatingText:SetShadowOffset(1, -1)
    end

    floatingAnimation = floatingText:CreateAnimationGroup()
    floatingAnimation:SetScript("OnFinished", function()
        floatingText:SetAlpha(0)
    end)
    floatingAnimation:SetScript("OnStop", function()
        floatingText:SetAlpha(0)
    end)

    local hold = floatingAnimation:CreateAnimation("Alpha")
    hold:SetOrder(1)
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(0.55)

    local rise = floatingAnimation:CreateAnimation("Translation")
    rise:SetOrder(2)
    rise:SetOffset(0, 42)
    rise:SetDuration(1.15)
    rise:SetSmoothing("OUT")

    local fade = floatingAnimation:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(1.15)
    fade:SetSmoothing("OUT")
end

local function ShowFloatingMessage(message)
    if not db.showFloating or not floatingText or not floatingAnimation then
        return
    end

    if floatingAnimation:IsPlaying() then
        floatingAnimation:Stop()
    end

    floatingText:ClearAllPoints()
    floatingText:SetPoint("TOP", UIParent, "TOP", 0, -170)
    floatingText:SetText(message)
    floatingText:SetAlpha(1)
    floatingAnimation:Play()
end

local function CreateCheckButton(parent, name, label, key, x, y)
    local check = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(label)
    check:SetChecked(db[key])
    check:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        ApplyTrackerSettings()
    end)

    return check
end

local function CreateSlider(parent, name, label, minValue, maxValue, step, value, x, y, onChanged)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(230)
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
        newValue = Round(newValue / step) * step
        onChanged(newValue)
        self.Value:SetText(FormatSliderValue(newValue, step))
    end)

    slider.Value = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.Value:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    slider.Value:SetText(FormatSliderValue(value, step))

    return slider
end

local function RefreshPositionSliderRanges()
    if not controls.xSlider or not controls.ySlider then
        return
    end

    local width = UIParent:GetWidth() or 1200
    local height = UIParent:GetHeight() or 800
    local xLimit = math.floor((width / 2) - 60)
    local yLimit = math.floor((height / 2) - 30)

    controls.xSlider:SetMinMaxValues(-xLimit, xLimit)
    controls.ySlider:SetMinMaxValues(-yLimit, yLimit)
    _G[controls.xSlider:GetName() .. "Low"]:SetText(tostring(-xLimit))
    _G[controls.xSlider:GetName() .. "High"]:SetText(tostring(xLimit))
    _G[controls.ySlider:GetName() .. "Low"]:SetText(tostring(-yLimit))
    _G[controls.ySlider:GetName() .. "High"]:SetText(tostring(yLimit))

    db.x = Clamp(db.x or 0, -xLimit, xLimit)
    db.y = Clamp(db.y or 160, -yLimit, yLimit)
    controls.xSlider:SetValue(db.x)
    controls.ySlider:SetValue(db.y)
end

local function CreateSettingsFrame()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    settingsFrame = CreateFrame("Frame", "XToLevelSettingsFrame", UIParent, template)
    settingsFrame:SetSize(340, 430)
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
    title:SetText("XToLevel")

    local close = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -5, -5)

    controls.showTracker = CreateCheckButton(settingsFrame, "XToLevelShowTrackerCheck", "Show tracker", "showTracker", 22, -52)
    controls.showFloating = CreateCheckButton(settingsFrame, "XToLevelShowFloatingCheck", "Show floating text", "showFloating", 22, -82)
    controls.locked = CreateCheckButton(settingsFrame, "XToLevelLockedCheck", "Lock tracker", "locked", 22, -112)

    controls.scaleSlider = CreateSlider(settingsFrame, "XToLevelScaleSlider", "Tracker size", 0.60, 1.80, 0.05, db.scale, 55, -160, function(value)
        db.scale = value
        ApplyTrackerSettings()
    end)

    controls.opacitySlider = CreateSlider(settingsFrame, "XToLevelOpacitySlider", "Tracker opacity", 0.20, 1.00, 0.05, db.opacity, 55, -218, function(value)
        db.opacity = value
        ApplyTrackerSettings()
    end)

    controls.xSlider = CreateSlider(settingsFrame, "XToLevelXSlider", "Horizontal position", -600, 600, 1, db.x, 55, -276, function(value)
        db.x = value
        ApplyTrackerSettings()
    end)

    controls.ySlider = CreateSlider(settingsFrame, "XToLevelYSlider", "Vertical position", -400, 400, 1, db.y, 55, -334, function(value)
        db.y = value
        ApplyTrackerSettings()
    end)

    local reset = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    reset:SetSize(92, 22)
    reset:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 22, 16)
    reset:SetText("Reset")
    reset:SetScript("OnClick", function()
        db.x = DEFAULTS.x
        db.y = DEFAULTS.y
        db.scale = DEFAULTS.scale
        db.opacity = DEFAULTS.opacity
        db.locked = DEFAULTS.locked

        controls.locked:SetChecked(db.locked)
        controls.scaleSlider:SetValue(db.scale)
        controls.opacitySlider:SetValue(db.opacity)
        controls.xSlider:SetValue(db.x)
        controls.ySlider:SetValue(db.y)
        ApplyTrackerSettings()
    end)

    local test = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    test:SetSize(92, 22)
    test:SetPoint("LEFT", reset, "RIGHT", 10, 0)
    test:SetText("Test")
    test:SetScript("OnClick", function()
        ShowFloatingMessage("12 kills to level (last kill: 240 XP)")
    end)

    local hide = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    hide:SetSize(92, 22)
    hide:SetPoint("LEFT", test, "RIGHT", 10, 0)
    hide:SetText("Close")
    hide:SetScript("OnClick", function()
        settingsFrame:Hide()
    end)
end

local function ExtractXP(message)
    if not message or message == "" then
        return nil
    end

    local normalized = message:gsub(",", "")
    local amount = normalized:match("[Gg]ain%s+(%d+)%s+experience")

    if not amount then
        amount = normalized:match("(%d+)%s+experience")
    end

    if not amount then
        amount = normalized:match("[Gg]ain%s+(%d+)%s+XP")
    end

    if not amount then
        amount = normalized:match("(%d+)%s+XP")
    end

    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return nil
    end

    return amount
end

local function ProcessKillXP(gain)
    local remaining = GetRemainingXP()

    db.lastGain = gain
    db.lastRemaining = remaining

    if UnitXPMax("player") == 0 then
        db.lastKills = nil
        UpdateTracker()
        ShowFloatingMessage("Max level reached")
        return
    end

    db.lastKills = math.max(math.ceil(remaining / gain), 0)
    UpdateTracker()

    if db.lastKills <= 0 then
        ShowFloatingMessage("Level reached! Last kill gave " .. FormatNumber(gain) .. " XP")
    else
        ShowFloatingMessage(FormatKills(db.lastKills) .. " to level (last kill: " .. FormatNumber(gain) .. " XP)")
    end
end

local function DelayProcessKillXP(gain)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            ProcessKillXP(gain)
        end)
    else
        ProcessKillXP(gain)
    end
end

local function OpenSettings()
    if not settingsFrame then
        return
    end

    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end

local function RegisterSlashCommands()
    SLASH_XTOLEVEL1 = "/xtl"
    SLASH_XTOLEVEL2 = "/xtolevel"

    SlashCmdList.XTOLEVEL = function(input)
        input = string.lower(strtrim(input or ""))

        if input == "reset" then
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
            db.scale = DEFAULTS.scale
            db.opacity = DEFAULTS.opacity
            ApplyTrackerSettings()
            UpdateTracker()
            print(ADDON_NAME .. ": tracker reset.")
        elseif input == "test" then
            ShowFloatingMessage("12 kills to level (last kill: 240 XP)")
        else
            OpenSettings()
        end
    end
end

local function Initialize()
    XToLevelDB = CopyDefaults(XToLevelDB, DEFAULTS)
    db = XToLevelDB

    CreateTracker()
    CreateFloatingText()
    CreateSettingsFrame()
    RegisterSlashCommands()
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")

events:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        Initialize()
        return
    end

    if not db then
        return
    end

    if eventName == "PLAYER_LEVEL_UP" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, RecalculateFromLastGain)
        else
            RecalculateFromLastGain()
        end
        return
    end

    if eventName == "CHAT_MSG_COMBAT_XP_GAIN" then
        local message = ...
        local gain = ExtractXP(message)

        if gain then
            DelayProcessKillXP(gain)
        end
    end
end)
