-- Wick's Ledger
-- Core.lua: namespace, saved variables, event dispatch

local ADDON, ns = ...
WicksLedger = WicksLedger or {}
local WL = WicksLedger
ns.WL = WL

WL.version = "0.2.0"

-- ============================================================
-- DEFAULTS
-- ============================================================
local DEFAULTS = {
    minimap     = { hide = false, position = 225 },
    lock        = false,
    autoMode    = true,
    hardLock    = false,  -- when true, zone changes never auto-stop the session
    priceSource = "auto",   -- "auto" | "TSM" | "Auctionator" | "Auctioneer" | "vendor"
    barPos      = nil,
    panelPos    = nil,
    panelSize   = nil,
    optPos      = nil,
    barShown    = false,
    panelShown  = false,
    optShown    = false,
}

-- ============================================================
-- CALLBACKS
-- ============================================================
local callbacks = {}

function WL:On(event, fn)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], fn)
end

local function Fire(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do fn(...) end
    end
end

-- ============================================================
-- EVENTS
-- ============================================================
local frame = CreateFrame("Frame")
WL.eventFrame = frame

local EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_MONEY",
    "CHAT_MSG_LOOT",
    "BAG_UPDATE",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_XP_UPDATE",
    "COMBAT_TEXT_UPDATE",
}
for _, e in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, e)
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Merge defaults into saved vars
        WicksLedgerDB = WicksLedgerDB or {}
        local db = WicksLedgerDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then
                if type(v) == "table" then
                    db[k] = {}
                    for k2, v2 in pairs(v) do db[k][k2] = v2 end
                else
                    db[k] = v
                end
            end
        end
        WL.db = db
        -- Per-character DB: active session + history
        WicksLedgerCharDB = WicksLedgerCharDB or {}
        WL.charDB = WicksLedgerCharDB
        WL.charDB.history = WL.charDB.history or {}
        Fire("LOGIN")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local isInstance, instanceType = IsInInstance()
        Fire("ZONE", isInstance, instanceType)
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        local isInstance, instanceType = IsInInstance()
        Fire("ZONE", isInstance, instanceType)
        return
    end

    if event == "PLAYER_MONEY" then
        Fire("MONEY")
        return
    end

    if event == "CHAT_MSG_LOOT" then
        Fire("LOOT_MSG", ...)
        return
    end

    if event == "BAG_UPDATE" then
        Fire("BAG_UPDATE", ...)
        return
    end

    if event == "PLAYER_XP_UPDATE" then
        Fire("XP")
        return
    end

    if event == "COMBAT_TEXT_UPDATE" then
        local combatType, factionName, amount = ...
        if combatType == "FACTION" and factionName and amount then
            Fire("REP", factionName, tonumber(amount) or 0)
        end
        return
    end
end)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_WICKSLEDGER1 = "/wicksledger"
SLASH_WICKSLEDGER2 = "/wledger"
SlashCmdList.WICKSLEDGER = function(input)
    input = input or ""
    local cmd = (input:match("^(%S*)") or ""):lower()

    if cmd == "start" then
        if WL.Session and WL.Session.Start then WL.Session:Start() end
    elseif cmd == "stop" then
        if WL.Session and WL.Session.Stop then WL.Session:Stop() end
    elseif cmd == "reset" then
        if WL.Session and WL.Session.Reset then WL.Session:Reset() end
    elseif cmd == "auto" then
        WL.db.autoMode = not WL.db.autoMode
        print(string.format("|cff4FC778Wick's Ledger|r: auto mode %s", WL.db.autoMode and "on" or "off"))
    elseif cmd == "lock" then
        WL.db.hardLock = not WL.db.hardLock
        print(string.format("|cff4FC778Wick's Ledger|r: hard lock %s", WL.db.hardLock and "on -- session persists across instance resets" or "off"))
    elseif cmd == "help" or cmd == "?" then
        print("|cff4FC778Wick's Ledger|r commands:")
        print("  /wledger            toggle panel")
        print("  /wledger start      start session manually")
        print("  /wledger stop       stop session manually")
        print("  /wledger reset      clear current session")
        print("  /wledger auto       toggle auto instance-detection")
        print("  /wledger lock       toggle hard lock (persist across resets)")
    else
        if WL.UI and WL.UI.Toggle then WL.UI:Toggle() end
    end
end
