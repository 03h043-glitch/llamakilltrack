local _, LTL = ...

local tracker
local trackerTitle
local trackerValue
local floatingText
local floatingAnimation
local floatingHold
local floatingFade

local function ResizeTrackerToText()
    if not tracker or not trackerTitle or not trackerValue then
        return
    end

    local titleWidth = trackerTitle:GetStringWidth() or 0
    local valueWidth = trackerValue:GetStringWidth() or 0
    local width = math.max(98, math.ceil(math.max(titleWidth, valueWidth) + 18))
    tracker:SetSize(width, 34)
end

function LTL.ApplyTrackerSettings()
    local db = LTL.db
    if not tracker or not db then
        return
    end

    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 160)
    tracker:SetScale(db.scale or 1)

    if tracker.SetBackdrop then
        local r = db.bgR or 0
        local g = db.bgG or 0
        local b = db.bgB or 0
        local alpha = db.windowOpacity or 0.55
        tracker:SetBackdropColor(r, g, b, alpha)
        tracker:SetBackdropBorderColor(LTL.Clamp(r + 0.35, 0, 1), LTL.Clamp(g + 0.35, 0, 1), LTL.Clamp(b + 0.35, 0, 1), LTL.Clamp(alpha + 0.2, 0, 1))
    end

    local textAlpha = db.textOpacity or 1
    trackerTitle:SetAlpha(textAlpha)
    trackerValue:SetAlpha(textAlpha)

    if db.showTracker then
        tracker:Show()
    else
        tracker:Hide()
    end
end

function LTL.UpdateTracker()
    if not trackerTitle or not trackerValue or not LTL.db then
        return
    end

    LTL.RecalculateEstimates()
    trackerTitle:SetText("To level")

    if UnitXPMax("player") == 0 then
        trackerValue:SetText("Max level")
    else
        trackerValue:SetText(LTL.FormatProgressText())
    end

    ResizeTrackerToText()
    LTL.ApplyTrackerSettings()
end

local function SaveTrackerPosition()
    local centerX, centerY = tracker:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if not centerX or not centerY or not parentX or not parentY then
        return
    end

    LTL.db.x = LTL.Round(centerX - parentX)
    LTL.db.y = LTL.Round(centerY - parentY)

    if LTL.SyncPositionControls then
        LTL.SyncPositionControls()
    end
end

function LTL.CreateTracker()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    tracker = CreateFrame("Frame", "LlamaToLevelTracker", UIParent, template)
    tracker:SetSize(118, 34)
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
    end

    trackerTitle = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trackerTitle:SetPoint("TOP", tracker, "TOP", 0, -5)
    trackerTitle:SetJustifyH("CENTER")

    trackerValue = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    trackerValue:SetPoint("TOP", trackerTitle, "BOTTOM", 0, -1)
    trackerValue:SetJustifyH("CENTER")

    tracker:SetScript("OnDragStart", function(self)
        if not LTL.db.locked then
            self:StartMoving()
        end
    end)

    tracker:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveTrackerPosition()
    end)

    tracker:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and LTL.OpenSettings then
            LTL.OpenSettings()
        end
    end)

    tracker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("LlamaToLevel")
        GameTooltip:AddLine("Left-drag to move. Right-click or /llt for settings.", 0.85, 0.85, 0.85, true)
        if LTL.killAverage then
            GameTooltip:AddLine("Kill average: " .. LTL.FormatNumber(LTL.Round(LTL.killAverage)) .. " XP from " .. #LTL.killGains .. " sample(s).", 0.45, 1, 0.45, true)
        end
        if LTL.questAverage then
            GameTooltip:AddLine("Quest average: " .. LTL.FormatNumber(LTL.Round(LTL.questAverage)) .. " XP from " .. #LTL.questGains .. " sample(s).", 0.45, 1, 0.45, true)
        end
        GameTooltip:Show()
    end)

    tracker:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    LTL.UpdateTracker()
end

function LTL.CreateFloatingText()
    floatingText = UIParent:CreateFontString("LlamaToLevelFloatingText", "OVERLAY", "CombatTextFont")
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

    floatingHold = floatingAnimation:CreateAnimation("Alpha")
    floatingHold:SetOrder(1)
    floatingHold:SetDuration(0.55)

    local rise = floatingAnimation:CreateAnimation("Translation")
    rise:SetOrder(2)
    rise:SetOffset(0, 42)
    rise:SetDuration(1.15)
    rise:SetSmoothing("OUT")

    floatingFade = floatingAnimation:CreateAnimation("Alpha")
    floatingFade:SetOrder(2)
    floatingFade:SetToAlpha(0)
    floatingFade:SetDuration(1.15)
    floatingFade:SetSmoothing("OUT")
end

function LTL.ShowFloatingMessage(message)
    if not LTL.db.showFloating or not floatingText or not floatingAnimation then
        return
    end

    if floatingAnimation:IsPlaying() then
        floatingAnimation:Stop()
    end

    local textAlpha = LTL.db.textOpacity or 1
    floatingHold:SetFromAlpha(textAlpha)
    floatingHold:SetToAlpha(textAlpha)
    floatingFade:SetFromAlpha(textAlpha)

    floatingText:ClearAllPoints()
    floatingText:SetPoint("TOP", UIParent, "TOP", 0, -170)
    floatingText:SetText(message)
    floatingText:SetAlpha(textAlpha)
    floatingAnimation:Play()
end
