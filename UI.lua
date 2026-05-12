-- Wick's Ledger
-- UI.lua: slim bar + expandable itemized panel

local ADDON, ns = ...
local WL = WicksLedger
WL.UI = WL.UI or {}
local UI = WL.UI

-- ============================================================
-- CONSTANTS
-- ============================================================
local BAR_W       = 260
local BAR_H       = 26
local PANEL_W     = 340
local PANEL_H_MAX = 480
local ROW_H       = 24
local ICON_SIZE   = 18
local HEADER_H    = 22
local PAD         = 8

-- Wick brand palette
local C_BG      = { 0.051, 0.039, 0.078, 0.97 }
local C_HEADER  = { 0.090, 0.067, 0.141, 1 }
local C_BORDER  = { 0.220, 0.188, 0.345, 1 }
local C_GREEN   = { 0.310, 0.780, 0.471, 1 }
local C_TEXT    = { 0.831, 0.784, 0.631, 1 }
local C_DIM     = { 0.42,  0.35,  0.54,  1 }

-- ============================================================
-- HELPERS
-- ============================================================
local function SetRGBA(tex, c)
    if c[4] then tex:SetColorTexture(c[1], c[2], c[3], c[4])
    else          tex:SetColorTexture(c[1], c[2], c[3], 1) end
end

local function NewTexture(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    if c then SetRGBA(t, c) end
    return t
end

local function NewText(parent, size, r, g, b, a)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetFont("Fonts\\FRIZQT__.TTF", (size or 11) + 1, "")
    f:SetTextColor(r or C_TEXT[1], g or C_TEXT[2], b or C_TEXT[3], a or 1)
    return f
end

local function AddBorder(frame)
    local r, g, b, a = C_BORDER[1], C_BORDER[2], C_BORDER[3], 1
    local e = {}
    e[1] = NewTexture(frame, "BORDER"); e[1]:SetColorTexture(r,g,b,a)
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2] = NewTexture(frame, "BORDER"); e[2]:SetColorTexture(r,g,b,a)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3] = NewTexture(frame, "BORDER"); e[3]:SetColorTexture(r,g,b,a)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4] = NewTexture(frame, "BORDER"); e[4]:SetColorTexture(r,g,b,a)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
    return e
end

local function AddCornerAccents(frame)
    local function Corner(f, h, v)
        local arm1 = NewTexture(f, "OVERLAY")
        arm1:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1)
        arm1:SetSize(10, 2)
        arm1:SetPoint(h .. v, f, h .. v, (h == "LEFT" and 0 or 0), (v == "TOP" and 0 or 0))

        local arm2 = NewTexture(f, "OVERLAY")
        arm2:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1)
        arm2:SetSize(2, 10)
        arm2:SetPoint(h .. v, f, h .. v, 0, 0)
    end
    Corner(frame, "LEFT",  "TOP")
    Corner(frame, "RIGHT", "TOP")
    Corner(frame, "LEFT",  "BOTTOM")
    Corner(frame, "RIGHT", "BOTTOM")
end

-- ============================================================
-- ELAPSED TICKER
-- ============================================================
local function FormatElapsed(secs)
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- ============================================================
-- ITEM ROWS (expandable panel)
-- ============================================================
local rowPool = {}

local function AcquireRow(parent)
    local row = table.remove(rowPool)
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(ROW_H)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON_SIZE, ICON_SIZE)
        row.icon:SetPoint("LEFT", row, "LEFT", PAD, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        row.name = NewText(row, 10)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -80, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.value = NewText(row, 10)
        row.value:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
        row.value:SetJustifyH("RIGHT")

        local sep = NewTexture(row, "BACKGROUND")
        sep:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.3)
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT")
        sep:SetPoint("BOTTOMRIGHT")
    end
    row:SetParent(parent)
    row:Show()
    return row
end

local function ReleaseRow(row)
    row:Hide()
    row:SetParent(nil)
    table.insert(rowPool, row)
end

-- ============================================================
-- SLIM BAR
-- ============================================================
local bar, panel, expandBtn, statusText, timerText, panelOpen

local activeRows = {}

local function BuildBar()
    bar = CreateFrame("Frame", "WicksLedgerBar", UIParent)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) self:StartMoving() end)
    bar:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)

    local bg = NewTexture(bar, "BACKGROUND", C_BG)
    bg:SetAllPoints()

    AddBorder(bar)
    AddCornerAccents(bar)

    -- Session active indicator (small dot, left side)
    local dot = NewTexture(bar, "OVERLAY")
    dot:SetSize(6, 6)
    dot:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1)
    dot:SetPoint("LEFT", bar, "LEFT", PAD + 1, 0)
    bar.dot = dot
    dot:Hide()

    -- "LEDGER" label
    local label = NewText(bar, 9, C_DIM[1], C_DIM[2], C_DIM[3])
    label:SetText("LEDGER")
    label:SetPoint("LEFT", bar, "LEFT", PAD + 14, 0)

    -- Status text (total value)
    statusText = NewText(bar, 11)
    statusText:SetPoint("LEFT", label, "RIGHT", 6, 0)
    statusText:SetPoint("RIGHT", bar, "RIGHT", -28, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("|cff888888idle|r")

    -- Timer text (top-right of bar, very small)
    timerText = NewText(bar, 9, C_DIM[1], C_DIM[2], C_DIM[3])
    timerText:SetPoint("RIGHT", bar, "RIGHT", -26, 0)
    timerText:SetJustifyH("RIGHT")

    -- Expand button (right side)
    expandBtn = CreateFrame("Button", nil, bar)
    expandBtn:SetSize(20, BAR_H)
    expandBtn:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    local expandTex = NewText(expandBtn, 9, C_DIM[1], C_DIM[2], C_DIM[3])
    expandTex:SetAllPoints()
    expandTex:SetJustifyH("CENTER")
    expandTex:SetJustifyV("MIDDLE")
    expandTex:SetText("+")
    expandBtn.label = expandTex

    expandBtn:SetScript("OnClick", function()
        if panelOpen then
            UI:ClosePanel()
        else
            UI:OpenPanel()
        end
    end)
    expandBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff4FC778Wick's Ledger|r")
        GameTooltip:AddLine("Click to expand itemized breakdown", 1, 1, 1)
        GameTooltip:Show()
    end)
    expandBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    bar.dot = dot
    bar.statusText = statusText
    bar.timerText  = timerText

    -- Ticker OnUpdate
    local tickAcc = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        tickAcc = tickAcc + elapsed
        if tickAcc < 0.5 then return end
        tickAcc = 0
        local S = WL.Session
        if S and S.active then
            bar.dot:Show()
            timerText:SetText(FormatElapsed(S:Elapsed()))
        else
            bar.dot:Hide()
            timerText:SetText("")
        end
    end)

    bar:Hide()
end

-- ============================================================
-- ITEMIZED PANEL
-- ============================================================
local function BuildPanel()
    panel = CreateFrame("Frame", "WicksLedgerPanel", UIParent)
    panel:SetSize(PANEL_W, 200)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)

    local bg = NewTexture(panel, "BACKGROUND", C_BG)
    bg:SetAllPoints()

    -- Header strip
    local header = CreateFrame("Frame", nil, panel)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    local hbg = NewTexture(header, "BACKGROUND", C_HEADER)
    hbg:SetAllPoints()

    local title = NewText(header, 10, C_GREEN[1], C_GREEN[2], C_GREEN[3])
    title:SetText("Wick's Ledger")
    title:SetPoint("LEFT", header, "LEFT", PAD, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    local closeTex = NewText(closeBtn, 10, C_DIM[1], C_DIM[2], C_DIM[3])
    closeTex:SetAllPoints()
    closeTex:SetJustifyH("CENTER")
    closeTex:SetJustifyV("MIDDLE")
    closeTex:SetText("x")
    closeBtn:SetScript("OnClick", function() UI:ClosePanel() end)

    AddBorder(panel)
    AddCornerAccents(panel)

    -- Scroll frame for rows
    local scroll = CreateFrame("ScrollFrame", "WicksLedgerScroll", panel)
    scroll:SetPoint("TOPLEFT",     panel, "TOPLEFT",     1, -HEADER_H - 2)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 30)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PANEL_W - 2, 1)
    scroll:SetScrollChild(content)

    panel.scroll   = scroll
    panel.content  = content
    panel.header   = header

    -- Footer: totals row
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetHeight(28)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    local fbg = NewTexture(footer, "BACKGROUND", C_HEADER)
    fbg:SetAllPoints()
    local ftop = NewTexture(footer, "BORDER")
    ftop:SetColorTexture(C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)
    ftop:SetHeight(1)
    ftop:SetPoint("TOPLEFT"); ftop:SetPoint("TOPRIGHT")

    local totalLabel = NewText(footer, 10, C_DIM[1], C_DIM[2], C_DIM[3])
    totalLabel:SetText("Total")
    totalLabel:SetPoint("LEFT", footer, "LEFT", PAD, 0)

    local totalValue = NewText(footer, 11)
    totalValue:SetPoint("RIGHT", footer, "RIGHT", -PAD, 0)
    totalValue:SetJustifyH("RIGHT")
    panel.totalValue = totalValue

    panel:Hide()
    return panel
end

-- ============================================================
-- PANEL POPULATION
-- ============================================================
local function PopulatePanel()
    local content = panel.content
    -- Release existing rows
    for _, row in ipairs(activeRows) do ReleaseRow(row) end
    activeRows = {}

    local S = WL.Session
    if not S then return end

    local P = WL.Prices

    -- Sort loot by value desc
    local items = {}
    for _, entry in pairs(S.loot) do
        table.insert(items, entry)
    end
    table.sort(items, function(a, b)
        return (a.copper or 0) * (a.count or 1) > (b.copper or 0) * (b.count or 1)
    end)

    local y = 0

    -- Gold delta row
    if S.goldDelta ~= 0 then
        local row = AcquireRow(content)
        table.insert(activeRows, row)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
        row.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        row.icon:SetTexCoord(0, 1, 0, 1)
        row.name:SetText("|cffD4C8A1Raw gold|r")
        row.value:SetText(P:FormatCopper(S.goldDelta))
        y = y + ROW_H
    end

    -- Item rows
    for _, entry in ipairs(items) do
        local row = AcquireRow(content)
        table.insert(activeRows, row)
        row:SetPoint("TOPLEFT",  content, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)

        if entry.icon then
            row.icon:SetTexture(entry.icon)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local nameStr = entry.link or ("item:" .. entry.itemID)
        if entry.count > 1 then
            nameStr = nameStr .. " |cff888888x" .. entry.count .. "|r"
        end
        row.name:SetText(nameStr)

        local lineVal = (entry.copper or 0) * (entry.count or 1)
        local valStr = P:FormatCopper(lineVal)
        if entry.source == "vendor" then
            valStr = valStr .. " |cff888888v|r"
        elseif entry.source == "unknown" then
            valStr = "|cff888888?|r"
        end
        row.value:SetText(valStr)

        row:SetScript("OnEnter", function(self)
            if entry.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(entry.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        y = y + ROW_H
    end

    content:SetHeight(math.max(y, 1))

    -- Resize panel height to fit (capped)
    local panH = math.min(HEADER_H + 2 + y + 30, PANEL_H_MAX)
    panel:SetHeight(math.max(panH, HEADER_H + 32))

    -- Update footer total
    panel.totalValue:SetText(P:FormatCopper(S.totalCopper))
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function UI:OpenPanel()
    if not panel then BuildPanel() end
    -- Anchor below the bar
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
    PopulatePanel()
    panel:Show()
    panelOpen = true
    expandBtn.label:SetText("-")
end

function UI:ClosePanel()
    if panel then panel:Hide() end
    panelOpen = false
    if expandBtn then expandBtn.label:SetText("+") end
end

function UI:Toggle()
    if bar and bar:IsShown() then
        bar:Hide()
        UI:ClosePanel()
    else
        if not bar then BuildBar() end
        bar:Show()
    end
end

function UI:OnSessionStart()
    if not bar then BuildBar() end
    bar:Show()
    statusText:SetText("|cff4FC778session active|r")
    if panelOpen then PopulatePanel() end
end

function UI:OnSessionStop()
    local P = WL.Prices
    local S = WL.Session
    statusText:SetText(P and P:FormatCopper(S.totalCopper) or "stopped")
    if panelOpen then PopulatePanel() end
end

function UI:OnSessionReset()
    statusText:SetText("|cff888888idle|r")
    if panelOpen then PopulatePanel() end
end

function UI:OnUpdate()
    local P = WL.Prices
    local S = WL.Session
    if S and S.active then
        statusText:SetText(P and P:FormatCopper(S.totalCopper) or "")
    end
    if panelOpen then PopulatePanel() end
end

-- ============================================================
-- INIT
-- ============================================================
WL:On("LOGIN", function()
    -- bar created lazily on first Toggle or session start
end)
