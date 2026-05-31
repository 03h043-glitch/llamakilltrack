local ADDON_NAME, LTL = ...

LTL.name = ADDON_NAME
LTL.maxSamples = 5
LTL.killXPGraceSeconds = 2.5
LTL.questDuplicateSeconds = 0.4
LTL.controls = {}
LTL.killGains = {}
LTL.questGains = {}
LTL.recentKillAt = 0
LTL.recentQuestGain = nil
LTL.recentQuestGainAt = 0
LTL.recentQuestTurnInAt = 0

LTL.defaults = {
    x = 0,
    y = 160,
    scale = 1,
    windowOpacity = 0.55,
    textOpacity = 1,
    bgR = 0,
    bgG = 0,
    bgB = 0,
    locked = false,
    showTracker = true,
    showFloating = true,
}

local events = CreateFrame("Frame")

function LTL.Now()
    if GetTime then
        return GetTime()
    end

    return 0
end

function LTL.CopyDefaults(target, defaults)
    target = target or {}

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function LTL.Round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end

    return math.ceil(value - 0.5)
end

function LTL.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

function LTL.FormatNumber(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end

    local left, num, right = string.match(tostring(value), "^([^%d]*%d)(%d*)(.-)$")
    if not left then
        return tostring(value)
    end

    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function LTL.FormatEstimate(value, singular, plural)
    if not value then
        return "-- " .. plural
    end

    if value == 1 then
        return "1 " .. singular
    end

    return LTL.FormatNumber(value) .. " " .. plural
end

function LTL.FormatProgressText()
    return LTL.FormatEstimate(LTL.killEstimate, "kill", "kills") .. " / " .. LTL.FormatEstimate(LTL.questEstimate, "quest", "quests")
end

function LTL.GetRemainingXP()
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0

    if maxXP <= 0 then
        return 0
    end

    return math.max(maxXP - currentXP, 0)
end

function LTL.AddSample(samples, gain)
    table.insert(samples, gain)

    while #samples > LTL.maxSamples do
        table.remove(samples, 1)
    end
end

function LTL.AverageSamples(samples)
    if #samples == 0 then
        return nil
    end

    local total = 0
    for _, gain in ipairs(samples) do
        total = total + gain
    end

    return total / #samples
end

function LTL.EstimateFromAverage(average)
    if not average or average <= 0 then
        return nil
    end

    return math.max(math.ceil(LTL.GetRemainingXP() / average), 0)
end

function LTL.RecalculateEstimates()
    if UnitXPMax("player") == 0 then
        LTL.killAverage = nil
        LTL.questAverage = nil
        LTL.killEstimate = nil
        LTL.questEstimate = nil
        return
    end

    LTL.killAverage = LTL.AverageSamples(LTL.killGains)
    LTL.questAverage = LTL.AverageSamples(LTL.questGains)
    LTL.killEstimate = LTL.EstimateFromAverage(LTL.killAverage)
    LTL.questEstimate = LTL.EstimateFromAverage(LTL.questAverage)
end

function LTL.ExtractXP(message)
    if not message or message == "" then
        return nil
    end

    local normalized = message:gsub(",", "")
    local amount = normalized:match("[Gg]ain%s+(%d+)%s+experience")
        or normalized:match("(%d+)%s+experience")
        or normalized:match("[Gg]ain%s+(%d+)%s+[Xx][Pp]")
        or normalized:match("(%d+)%s+[Xx][Pp]")
        or normalized:match("[Ee]xperience%s+[Gg]ained:%s*(%d+)")

    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return nil
    end

    return amount
end

function LTL.IsKillXPMessage(message)
    local lower = string.lower(message or "")

    if lower:find(" dies", 1, true) or lower:find("dies,", 1, true) or lower:find(" slain", 1, true) then
        return true
    end

    if (LTL.Now() - LTL.recentQuestTurnInAt) <= LTL.killXPGraceSeconds then
        return false
    end

    return (LTL.Now() - LTL.recentKillAt) <= LTL.killXPGraceSeconds
end

function LTL.ProcessQuestXP(gain)
    if LTL.recentQuestGain == gain and (LTL.Now() - LTL.recentQuestGainAt) <= LTL.questDuplicateSeconds then
        return
    end

    LTL.recentQuestGain = gain
    LTL.recentQuestGainAt = LTL.Now()
    LTL.AddSample(LTL.questGains, gain)

    if LTL.UpdateTracker then
        LTL.UpdateTracker()
    end
end

function LTL.ProcessKillXP(gain)
    LTL.AddSample(LTL.killGains, gain)

    if LTL.UpdateTracker then
        LTL.UpdateTracker()
    end

    if not LTL.ShowFloatingMessage then
        return
    end

    if UnitXPMax("player") == 0 then
        LTL.ShowFloatingMessage("Max level reached")
    else
        LTL.ShowFloatingMessage(LTL.FormatProgressText() .. " to level")
    end
end

function LTL.DelayProcess(callback, gain)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            callback(gain)
        end)
    else
        callback(gain)
    end
end

local function ResetVisualSettings()
    local db = LTL.db
    local defaults = LTL.defaults

    db.x = defaults.x
    db.y = defaults.y
    db.scale = defaults.scale
    db.windowOpacity = defaults.windowOpacity
    db.textOpacity = defaults.textOpacity
    db.bgR = defaults.bgR
    db.bgG = defaults.bgG
    db.bgB = defaults.bgB
    db.locked = defaults.locked

    if LTL.SyncSettingsControls then
        LTL.SyncSettingsControls()
    end

    if LTL.UpdateTracker then
        LTL.UpdateTracker()
    end
end

local function RegisterSlashCommands()
    SLASH_LLAMATOLEVEL1 = "/llt"
    SLASH_LLAMATOLEVEL2 = "/llamatolevel"

    SlashCmdList.LLAMATOLEVEL = function(input)
        input = string.lower(strtrim(input or ""))

        if input == "reset" then
            ResetVisualSettings()
            print(ADDON_NAME .. ": tracker reset.")
        elseif input == "test" and LTL.ShowFloatingMessage then
            LTL.ShowFloatingMessage("12 kills / 3 quests to level")
        elseif LTL.OpenSettings then
            LTL.OpenSettings()
        end
    end
end

local function Initialize()
    LlamaToLevelDB = LlamaToLevelDB or {}

    if LlamaToLevelDB.windowOpacity == nil and LlamaToLevelDB.opacity ~= nil then
        LlamaToLevelDB.windowOpacity = LlamaToLevelDB.opacity
    end

    LTL.db = LTL.CopyDefaults(LlamaToLevelDB, LTL.defaults)
    LlamaToLevelDB = LTL.db

    if LTL.CreateTracker then
        LTL.CreateTracker()
    end
    if LTL.CreateFloatingText then
        LTL.CreateFloatingText()
    end
    if LTL.CreateSettingsFrame then
        LTL.CreateSettingsFrame()
    end

    RegisterSlashCommands()
end

local function RegisterAddonEvent(eventName)
    pcall(events.RegisterEvent, events, eventName)
end

RegisterAddonEvent("PLAYER_LOGIN")
RegisterAddonEvent("PLAYER_LEVEL_UP")
RegisterAddonEvent("PLAYER_XP_UPDATE")
RegisterAddonEvent("CHAT_MSG_COMBAT_XP_GAIN")
RegisterAddonEvent("CHAT_MSG_SYSTEM")
RegisterAddonEvent("QUEST_TURNED_IN")
RegisterAddonEvent("COMBAT_LOG_EVENT_UNFILTERED")

events:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        Initialize()
        return
    end

    if eventName == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent

        if CombatLogGetCurrentEventInfo then
            _, subEvent = CombatLogGetCurrentEventInfo()
        else
            _, subEvent = ...
        end

        if subEvent == "PARTY_KILL" then
            LTL.recentKillAt = LTL.Now()
        end
        return
    end

    if not LTL.db then
        return
    end

    if eventName == "PLAYER_LEVEL_UP" or eventName == "PLAYER_XP_UPDATE" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.10, LTL.UpdateTracker)
        elseif LTL.UpdateTracker then
            LTL.UpdateTracker()
        end
        return
    end

    if eventName == "QUEST_TURNED_IN" then
        local _, xpReward = ...
        xpReward = tonumber(xpReward)
        LTL.recentQuestTurnInAt = LTL.Now()

        if xpReward and xpReward > 0 then
            LTL.DelayProcess(LTL.ProcessQuestXP, xpReward)
        end
        return
    end

    if eventName == "CHAT_MSG_SYSTEM" then
        local gain = LTL.ExtractXP(...)

        if gain then
            LTL.DelayProcess(LTL.ProcessQuestXP, gain)
        end
        return
    end

    if eventName == "CHAT_MSG_COMBAT_XP_GAIN" then
        local message = ...
        local gain = LTL.ExtractXP(message)

        if gain then
            if LTL.IsKillXPMessage(message) then
                LTL.DelayProcess(LTL.ProcessKillXP, gain)
            else
                LTL.DelayProcess(LTL.ProcessQuestXP, gain)
            end
        end
    end
end)
