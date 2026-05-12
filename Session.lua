-- Wick's Ledger
-- Session.lua: session lifecycle, loot tracking, gold delta

local ADDON, ns = ...
local WL = WicksLedger
WL.Session = WL.Session or {}
local S = WL.Session

-- ============================================================
-- STATE
-- ============================================================
S.active      = false
S.startTime   = nil
S.startMoney  = nil
S.goldDelta   = 0
S.loot        = {}   -- { [itemLink] = { itemID, name, icon, count, copper, source } }
S.totalCopper = 0    -- goldDelta + loot value
S.zoneName    = nil

-- ============================================================
-- HELPERS
-- ============================================================
local function ParseItemLink(link)
    if not link then return nil, nil end
    local itemID = link:match("item:(%d+)")
    if not itemID then return nil, nil end
    return tonumber(itemID), link
end

local function ItemIDFromLink(link)
    local id = link and link:match("item:(%d+)")
    return id and tonumber(id)
end

local function RecalcTotal()
    local total = S.goldDelta
    for _, entry in pairs(S.loot) do
        total = total + (entry.copper or 0) * (entry.count or 1)
    end
    S.totalCopper = total
end

-- ============================================================
-- LOOT PARSING
-- ============================================================
-- "You receive loot: |Hitem:...|h[Name]|h x3."
-- "You loot |Hitem:...|h[Name]|h."
local LOOT_PATTERNS = {
    "You receive loot: (.+)$",
    "You loot (.+)$",
}

local function ParseLootMessage(msg)
    local body
    for _, pat in ipairs(LOOT_PATTERNS) do
        body = msg:match(pat)
        if body then break end
    end
    if not body then return nil, nil, nil end

    -- Strip trailing period
    body = body:gsub("%.$", "")

    -- Count suffix " x<N>"
    local count = 1
    local suffix = body:match(" x(%d+)$")
    if suffix then
        count = tonumber(suffix)
        body  = body:gsub(" x%d+$", "")
    end

    -- Extract item link
    local link = body:match("|H(item:[^|]+)|h%[.-%]|h")
    if link then link = "|H" .. link .. "|h[" .. (body:match("|h%[(.-)%]|h") or "?") .. "]|h" end
    if not link then link = body end

    local itemID = ItemIDFromLink(link)
    return itemID, link, count
end

-- ============================================================
-- SESSION CONTROL
-- ============================================================
function S:Start()
    if S.active then return end
    S.active     = true
    S.startTime  = time()
    S.startMoney = GetMoney()
    S.goldDelta  = 0
    S.loot       = {}
    S.totalCopper = 0
    S.zoneName   = GetRealZoneText()
    if WL.UI and WL.UI.OnSessionStart then WL.UI:OnSessionStart() end
    print(string.format("|cff4FC778Wick's Ledger|r: session started in %s", S.zoneName or "?"))
end

function S:Stop()
    if not S.active then return end
    S.active = false
    -- Final gold delta
    local currentMoney = GetMoney()
    S.goldDelta = currentMoney - (S.startMoney or currentMoney)
    RecalcTotal()
    if WL.UI and WL.UI.OnSessionStop then WL.UI:OnSessionStop() end
    print(string.format("|cff4FC778Wick's Ledger|r: session ended -- %s earned",
        WL.Prices and WL.Prices:FormatCopper(S.totalCopper) or "?"))
end

function S:Reset()
    S.active      = false
    S.startTime   = nil
    S.startMoney  = nil
    S.goldDelta   = 0
    S.loot        = {}
    S.totalCopper = 0
    if WL.UI and WL.UI.OnSessionReset then WL.UI:OnSessionReset() end
end

function S:Elapsed()
    if not S.startTime then return 0 end
    return time() - S.startTime
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================
WL:On("LOGIN", function()
    -- nothing to restore yet -- sessions don't persist across logins
end)

WL:On("ZONE", function(isInstance, instanceType)
    if not WL.db or not WL.db.autoMode then return end
    if isInstance and not S.active then
        S:Start()
    elseif not isInstance and S.active then
        S:Stop()
    end
end)

WL:On("MONEY", function()
    if not S.active then return end
    local current = GetMoney()
    S.goldDelta   = current - (S.startMoney or current)
    RecalcTotal()
    if WL.UI and WL.UI.OnUpdate then WL.UI:OnUpdate() end
end)

WL:On("LOOT_MSG", function(msg)
    if not S.active then return end
    local itemID, link, count = ParseLootMessage(msg)
    if not itemID then return end

    local copper, source = WL.Prices and WL.Prices:GetPrice(itemID)
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)

    local key = tostring(itemID)
    if S.loot[key] then
        S.loot[key].count = S.loot[key].count + count
    else
        S.loot[key] = {
            itemID = itemID,
            link   = link,
            icon   = icon,
            count  = count,
            copper = copper or 0,
            source = source or "unknown",
        }
    end

    RecalcTotal()
    if WL.UI and WL.UI.OnUpdate then WL.UI:OnUpdate() end
end)
