local cache = {};
local achString = "ACH:[0-9]+";
local BUTTON_TEXT_PADDING = 15
local BUTTON_HEIGHT = 22
local EDITBOX_HEIGHT = 24
local ROW_TEXT_PADDING = 5
local fontHeight = select(2, GameFontNormal:GetFont())
local playerName = GetUnitName("player")
local playerNameWithGuild = playerName .. "-" .. GetRealmName();

local function TableLength(t)
    local z = 0
    for i, v in pairs(t) do
        z = z + 1
    end
    return z
end

local function getKeysSortedByValue(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        return sortFunction(tbl[a], tbl[b])
    end)

    return keys
end

local function StripString(s)
    return s:match("^%s*(.-)%s*$")
end

local function UpdatePublicNote(note, guildIndex, achievementPoints)
    local noteWithoutAchievements = StripString(string.gsub(note, achString, ""));
    local newNote = noteWithoutAchievements .. " ACH:" .. achievementPoints
    GuildRosterSetPublicNote(guildIndex, newNote);

    if (string.len(newNote) > 31) then
        print(
            "Unable to set your guild note to track Guild Achievement for leaderboard. Please shorten your previous message")
    end
end

local function GetAchievementPointsFromNote(note)
    local startIndex, endIndex = string.find(note, achString);
    local extractedAchString = string.sub(note, startIndex, endIndex);
    local achievementPoints = string.gsub(extractedAchString, "ACH:", "");

    return tonumber(achievementPoints)
end

local function SetAchievementPointsInCache(name, points, class)
    cache[name] = {
        ["points"] = points,
        ["class"] = class
    }
end

local function ProcessGuildData()
    local guildName, _, _, _ = GetGuildInfo("player")

    if guildName == nil or not IsInGuild() then
        return
    end

    local num = GetNumGuildMembers();
    local cn = playerNameWithGuild;

    for i = 1, num do
        local name, rank, _, _, _, _, pubNote, _, _, _, class, _, _, _, _, _, guid = GetGuildRosterInfo(i);
        if cn == name then
            -- You
            SetAchievementPointsInCache(name, GetTotalAchievementPoints(), class);
            UpdatePublicNote(pubNote, i, GetTotalAchievementPoints());
        elseif string.find(pubNote, achString) ~= nil then
            -- Others
            SetAchievementPointsInCache(name, GetAchievementPointsFromNote(pubNote), class);
        end
    end
end

-- ProcessGuildData()

local function CreateTableRow(parent, rowHeight, texts, widths, justifiesH)
    local row = CreateFrame("Button", nil, parent)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetHeight(rowHeight)
    row:SetPoint("LEFT")
    row:SetPoint("RIGHT")

    row.cells = {}
    for i, w in ipairs(widths) do
        local c = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

        c:SetHeight(rowHeight)
        c:SetWidth(w - (2 * ROW_TEXT_PADDING))
        c:SetJustifyH(justifiesH[i])

        if #row.cells == 0 then
            c:SetPoint("LEFT", row, "LEFT", ROW_TEXT_PADDING, 0)
        else
            c:SetPoint("LEFT", row.cells[#row.cells], "RIGHT", 2 * ROW_TEXT_PADDING, 0)
        end

        table.insert(row.cells, c)
        c:SetText(w)
    end

    return row
end

local function CreateTable(parent, texts, widths, justfiesH, rightPadding)
    assert(#texts == #widths and #texts == #justfiesH, "All specification tables must be the same size")

    local totalFixedWidths = rightPadding or 0
    local numDynamicWidths = 0

    for i, w in ipairs(widths) do
        if w > 0 then
            totalFixedWidths = totalFixedWidths + w
        else
            numDynamicWidths = numDynamicWidths + 1
        end
    end

    local remainingWidthSpace = parent:GetWidth() - totalFixedWidths
    assert(remainingWidthSpace >= 0, "Widths specified exceed parent width")

    local dynamicWidth = math.floor(remainingWidthSpace / numDynamicWidths)
    local leftoverWidth = remainingWidthSpace % numDynamicWidths

    for i, w in ipairs(widths) do
        if w <= 0 then
            numDynamicWidths = numDynamicWidths - 1

            if numDynamicWidths then
                widths[i] = dynamicWidth
            else
                widths[i] = dynamicWidth + leftoverWidth
            end
        end
    end

    -- Make a frame for the rows
    local rowFrame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate");
    rowFrame:SetPoint("TOP", nil, "TOP")
    rowFrame:SetPoint("BOTTOMLEFT")
    rowFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightPadding, 0)
    parent.rowFrame = rowFrame

    -- Compute number of rows
    local fontHeight = select(2, GameFontNormalSmall:GetFont())
    local rowHeight = fontHeight + 4
    rowFrame.rowHeight = rowHeight
    rowFrame.texts = texts
    rowFrame.widths = widths
    rowFrame.justfiesH = justfiesH
    local numRows = TableLength(cache)
    local sortedKeys = getKeysSortedByValue(cache, function(a, b)
        return a.points > b.points
    end)

    rowFrame.rows = {}

    for i, key in ipairs(sortedKeys) do
        local r = CreateTableRow(rowFrame, rowHeight, texts, widths, justfiesH)

        if #rowFrame.rows == 0 then
            r:SetPoint("TOP")
        else
            r:SetPoint("TOP", rowFrame.rows[#rowFrame.rows], "BOTTOM")
        end

        table.insert(rowFrame.rows, r)
    end
end

local main = CreateFrame("Frame", "AchLeaderboard", UIParent, "BasicFrameTemplateWithInset"); -- "BasicFrameTemplateWithInset")
local guildName, _, _, _ = GetGuildInfo("player")
local title = "Achievement Leaderboard" .. " - " .. guildName

if string.len(title) > 50 then
    title = string.sub(title, 0, 50) .. "..."
end

main:EnableMouse(true)
main:SetMovable(true)
main:SetScript("OnMouseDown", function(self)
    self:StartMoving()
end)
main:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
end)

main:SetSize(384, 512)
main:SetPoint("TOPLEFT", nil, "TOPLEFT")
main.title = main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
main.title:SetPoint("CENTER", main.TitleBg, "CENTER", 5, 0)
main.title:SetText(title)

local scrollFrame = CreateFrame("ScrollFrame", nil, main, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 3, -54)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 10)

local scrollChild = CreateFrame("Frame")
scrollFrame:SetScrollChild(scrollChild)
scrollChild:SetWidth(384 - 18)
scrollChild:SetHeight(1)
scrollChild:SetPoint("TOPLEFT")

local title = scrollFrame:CreateFontString("ARTWORK", nil, "GameFontNormal")
title:SetPoint("TOPLEFT", 4, 24)
title:SetText("Name")

local title = scrollFrame:CreateFontString("ARTWORK", nil, "GameFontNormal")
title:SetPoint("TOPLEFT", 186, 24)
title:SetText("Points")

local title = scrollFrame:CreateFontString("ARTWORK", nil, "GameFontNormal")
title:SetPoint("TOPLEFT", 286, 24)
title:SetText("Rank")

CreateTable(scrollChild, {"Name", "Points", "Rank"}, {0, 100, 100}, {"LEFT", "CENTER", "CENTER"}, 12)

local rowFrame = scrollChild.rowFrame
rowFrame:SetPoint("TOP", 0, -24)
rowFrame.needUpdate = true
main:Hide()

local function UpdateCellsForRow(data, row)
    for i = 1, 3 do
        local c = row.cells[i]

        c:SetText(data[i])

        if i == 1 then
            if (data[i] == playerNameWithGuild) then
                row:LockHighlight()
            end

            row.cells[1]:SetText(Ambiguate(data[i], "short"))

            local c = _G.RAID_CLASS_COLORS[cache[data[i]].class]

            row.cells[1]:SetTextColor(c.r, c.g, c.b)
        end
    end

    row:Show()
end

local function LoopRowsToFill()
    local sortedValues = getKeysSortedByValue(cache, function(a, b)
        return a.points > b.points
    end)

    for index = 1, #rowFrame.rows do
        local rank = index

        if cache[sortedValues[index]] ~= nil and cache[sortedValues[index - 1]] ~= nil then
            if index > 1 and cache[sortedValues[index]].points == cache[sortedValues[index - 1]].points then
                rank = rowFrame.rows[index - 1].cells[3]:GetText()
            end
        end

        local data = {
            sortedValues[index], 
            cache[sortedValues[index]].points,
            rank
        }
        local row = rowFrame.rows[index];

        if (row:IsShown()) then
            UpdateCellsForRow(data, row)
        end
    end
end

local function UpdateRows()
    ProcessGuildData()
    local prevRows = TableLength(rowFrame.rows)
    local newRows = TableLength(cache)

    if (prevRows == newRows) then
        -- Fill in rows
        LoopRowsToFill()
    elseif prevRows < newRows then
        -- Add required number of rows, then fill in
        local rowsToCreate = newRows - prevRows
        for i = 1, rowsToCreate do
            local r = CreateTableRow(rowFrame, rowFrame.rowHeight, rowFrame.texts, rowFrame.widths, rowFrame.justfiesH)

            if #rowFrame.rows == 0 then
                r:SetPoint("TOP")
            else
                r:SetPoint("TOP", rowFrame.rows[#rowFrame.rows], "BOTTOM")
            end

            table.insert(rowFrame.rows, r)
        end

        LoopRowsToFill()
    elseif prevRows > newRows then
        -- Hide certain rows then fill in
        local rowsToDelete = prevRows - newRows

        for i = 1, #rowFrame.rows do
            if rowsToDelete ~= 0 then
                local row = rowFrame.rows[#rowFrame.rows + 1 - i]
                row:Hide()
                rowsToDelete = rowsToDelete - 1
            end
        end

        LoopRowsToFill()
    end
end

local function ToggleView()
    if not IsInGuild() then
        return
    end

    if (main:IsShown()) then
        main:Hide()
    else
        UpdateRows()
        main:Show()
    end
end

SLASH_GACH1 = "/gach"
SLASH_GACH2 = "/leaderboard"
SlashCmdList["GACH"] = ToggleView;

main:RegisterEvent("PLAYER_ENTERING_WORLD")
main:RegisterEvent("ACHIEVEMENT_EARNED")

main:SetScript("OnEvent", function()
    ProcessGuildData()
end)

tinsert(UISpecialFrames, main:GetName())
