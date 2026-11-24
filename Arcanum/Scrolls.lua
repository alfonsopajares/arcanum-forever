local _, addon = ...
local spellID, skillID = 1296017, 3012

function addon:ComprehensionSkill()
    local query = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
    if not query then return end
    local ok, skill = pcall(query, skillID)
    skill = ok and self:Readable(skill)
    if type(skill) ~= "table" then return end
    local name, rank = self:Readable(skill.name), self:Readable(skill.rank)
    local temp, modifier = self:Readable(skill.tempPoints), self:Readable(skill.modifier)
    if type(name) == "string" and type(rank) == "number" then
        return name, math.max(0, rank + (type(temp) == "number" and temp or 0)
            + (type(modifier) == "number" and modifier or 0))
    end
end

-- Match a localized skill requirement on a Scroll item, never its name or
-- flavor text. Deciphered scrolls and ordinary stat scrolls are not candidates.
function addon:ComprehendRequirement(bag, slot, id, skillName)
    if not (C_Item and C_Item.GetItemInfoInstant and C_TooltipInfo and C_TooltipInfo.GetBagItem) then return end
    local ok, required, blocked = pcall(function()
        local info = {C_Item.GetItemInfoInstant(id)}
        if self:Readable(info[6]) ~= 0 or self:Readable(info[7]) ~= 4 then return end
        local tip = self:Readable(C_TooltipInfo.GetBagItem(bag, slot))
        local lines = tip and self:Readable(tip.lines)
        if type(lines) ~= "table" then return end
        local pattern = skillName:gsub("(%W)", "%%%1") .. "%s*%((%d+)%)"
        local rank, unmet
        local requirementType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UsageRequirement or 43
        for _, line in ipairs(lines) do
            line = self:Readable(line)
            if line and self:Readable(line.type) == requirementType then
                local text = self:Readable(line.leftText)
                if type(text) == "string" then
                    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    rank = tonumber(text:match(pattern)) or rank
                end
                local color = self:Readable(line.leftColor)
                if color then
                    local r, g, b = self:Readable(color.r), self:Readable(color.g), self:Readable(color.b)
                    if type(r) == "number" and type(g) == "number" and type(b) == "number"
                        and r > 0.8 and g < 0.3 and b < 0.3 then unmet = true end
                end
            end
        end
        return rank, unmet
    end)
    if ok then return required, blocked end
end

function addon:ComprehendCandidates()
    local entries, byID = {}, {}
    self.scrollPendingItems = self.scrollPendingItems or {}
    self.scrollRequestedItems = self.scrollRequestedItems or {}
    if not self:KnownSpell(spellID) then return entries end
    local skillName, rank = self:ComprehensionSkill()
    if not skillName or not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return entries end
    for bag = 0, 4 do
        local slots = self:Readable(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local info = self:Readable(C_Container.GetContainerItemInfo(bag, slot))
            if info then
                local id, count = self:Readable(info.itemID), self:Readable(info.stackCount)
                if type(id) == "number" and type(count) == "number" and count > 0 then
                    local required, blocked = self:ComprehendRequirement(bag, slot, id, skillName)
                    if required then
                        local entry = byID[id]
                        if not entry then
                            local name = C_Item.GetItemInfo and self:Readable(C_Item.GetItemInfo(id))
                            entry = {id=id, name=name or ("Scroll " .. id), count=0, required=required, eligible=rank >= required and not blocked,
                                icon=self:Readable(info.iconFileID)}
                            byID[id] = entry; entries[#entries+1] = entry
                        end
                        entry.count = entry.count + count
                        if not entry.bag and self:Readable(info.isLocked) == false then entry.bag, entry.slot = bag, slot end
                    elseif not required and C_Item and C_Item.RequestLoadItemDataByID and not self.scrollRequestedItems[id]
                        and C_Item.GetItemInfo and not self:Readable(C_Item.GetItemInfo(id)) then
                        self.scrollRequestedItems[id] = true
                        self.scrollPendingItems[id] = true
                        C_Item.RequestLoadItemDataByID(id)
                    end
                end
            end
        end
    end
    table.sort(entries, function(a,b) if a.required ~= b.required then return a.required < b.required end; return a.id < b.id end)
    return entries
end

function addon:ResetScrollPosition()
    for _, key in ipairs({"point", "relativePoint", "x", "y"}) do self.db.scrolls[key] = self.defaults.scrolls[key] end
    self.scrollDismissed = nil
    self:UpdateScrollWindow()
end

function addon:CreateScrollWindow()
    if self.scrollWindow then return end
    local frame = CreateFrame("Frame", "ArcanumScrollWindow", UIParent, "BackdropTemplate,SecureHandlerStateTemplate")
    frame:SetSize(344, 160); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:SetMovable(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    frame:SetBackdropBorderColor(0.65,0.49,0.26,1)
    local header=frame:CreateTexture(nil,"BACKGROUND")
    header:SetPoint("TOPLEFT",8,-7); header:SetSize(328,26)
    header:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    header:SetVertexColor(0.38,0.24,0.1)
    local emblem=frame:CreateTexture(nil,"ARTWORK")
    emblem:SetSize(30,30); emblem:SetPoint("TOPLEFT",12,-6)
    local _,spellIcon=self:SpellInfo(spellID)
    emblem:SetTexture(spellIcon or "Interface\\Icons\\INV_Scroll_03")
    emblem:SetTexCoord(0.08,0.92,0.08,0.92)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 12, -13); title:SetText("Arcanum • Comprehend")
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 8, -2); drag:SetSize(294, 30); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not InCombatLockdown() then self.scrollDragging = true; frame:StartMoving() end end)
    drag:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing(); self.scrollDragging = nil
        local point, _, relative, x, y = frame:GetPoint()
        local cfg = self.db.scrolls; cfg.point, cfg.relativePoint, cfg.x, cfg.y = point, relative, x, y
    end)
    frame.dragHandle = drag
    local close = frame.CloseButton or CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetSize(22,22)
    close:SetScript("OnClick", function() if not InCombatLockdown() then self.scrollDismissed = self.scrollSignature; frame:Hide() end end)
    frame.skill = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.skill:SetPoint("TOPLEFT", 16, -44); frame.skill:SetTextColor(0.85,0.75,0.5)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -65); scroll:SetSize(296, 62)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(296, 62); scroll:SetScrollChild(content)
    frame.scroll, frame.content, frame.rows = scroll, content, {}
    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetPoint("BOTTOM", 0, 12); frame.footer:SetText("Drag to move • Disable: /arc → Prep")
    frame.footer:SetTextColor(0.6,0.6,0.6)
    frame:SetAttribute("_onstate-combat", [[if newstate == "1" then self:Hide() end]])
    RegisterStateDriver(frame, "combat", "[combat] 1; 0")
    frame:Hide(); self.scrollWindow = frame
    local events = CreateFrame("Frame")
    local function refreshAfterQuietPeriod(_, elapsed)
        events.refreshDelay = events.refreshDelay - elapsed
        if events.refreshDelay > 0 then return end
        events:SetScript("OnUpdate", nil); events.refreshDelay = nil
        self:UpdateScrollWindow()
    end
    for _, event in ipairs({"BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "SKILL_LINES_CHANGED", "SPELLS_CHANGED",
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UNIT_AURA", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, id)
        if event == "UNIT_AURA" and id ~= "player" then return end
        if event == "PLAYER_REGEN_ENABLED" and self.scrollDragging then frame:StopMovingOrSizing(); self.scrollDragging = nil end
        if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
            id = self:Readable(id)
            if not id or not self.scrollPendingItems or not self.scrollPendingItems[id] then return end
            self.scrollPendingItems[id] = nil
        end
        -- Sorting emits a burst of lock/unlock and bag events. Scan only once
        -- after 200ms without another event, rather than once per moved item.
        -- PreClick still validates the actual bag item before every cast.
        if event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "UNIT_AURA"
            or event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
            if InCombatLockdown() or not self.db.scrolls.enabled then return end
            events.refreshDelay = 0.2
            events:SetScript("OnUpdate", refreshAfterQuietPeriod)
            return
        end
        self:UpdateScrollWindow()
    end)
    self.scrollEvents = events
    self:UpdateScrollWindow()
end

function addon:UpdateScrollWindow()
    -- Explicit refreshes (options, skills, /arc scrolls, combat end) supersede
    -- pending work. No background ticker is left running while idle.
    if self.scrollEvents then
        self.scrollEvents:SetScript("OnUpdate", nil); self.scrollEvents.refreshDelay = nil
    end
    local frame = self.scrollWindow
    if not frame or InCombatLockdown() then return end
    if not self.db.scrolls.enabled then frame:Hide(); return end
    local entries = self:ComprehendCandidates()
    local signature, eligible, readyCount = {}, false, 0
    for _, entry in ipairs(entries) do
        signature[#signature+1] = entry.id .. ":" .. entry.count .. ":" .. tostring(entry.eligible)
        eligible = eligible or entry.eligible
        if entry.eligible then readyCount = readyCount + entry.count end
    end
    local currentSignature = table.concat(signature, ";")
    if currentSignature ~= self.scrollSignature then
        self.scrollDismissed = nil
        if frame.scroll.SetVerticalScroll then frame.scroll:SetVerticalScroll(0) end
    end
    self.scrollSignature = currentSignature
    local cfg = self.db.scrolls
    local skillName, rank = self:ComprehensionSkill()
    frame.skill:SetText(string.format("%s %d · %d ready",skillName or "Comprehension",rank or 0,readyCount))
    if not self.scrollDragging then frame:ClearAllPoints(); frame:SetPoint(cfg.point, UIParent, cfg.relativePoint, cfg.x, cfg.y) end
    for index, entry in ipairs(entries) do
        local row = frame.rows[index]
        if not row then
            row = CreateFrame("Button", nil, frame.content, "SecureActionButtonTemplate")
            row:SetSize(296, 62); row:SetPoint("TOPLEFT", 0, -(index-1)*66)
            row.fill = row:CreateTexture(nil,"BACKGROUND")
            row.fill:SetAllPoints(row)
            row.separator = row:CreateTexture(nil,"ARTWORK")
            row.separator:SetPoint("BOTTOMLEFT",0,0); row.separator:SetSize(296,1)
            row.separator:SetColorTexture(0.65,0.52,0.3,0.5)
            row.separator:Show()
            local highlight = row:CreateTexture(nil,"HIGHLIGHT")
            highlight:SetAllPoints(row); highlight:SetColorTexture(1,0.82,0.35,0.18)
            row.icon=row:CreateTexture(nil,"ARTWORK")
            row.icon:SetPoint("LEFT",8,0); row.icon:SetSize(32,32); row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            if row.SetMotionScriptsWhileDisabled then row:SetMotionScriptsWhileDisabled(true) end
            row:RegisterForClicks("AnyDown", "AnyUp"); row:SetAttribute("useOnKeyDown", false)
            row.name = row:CreateFontString(nil,"OVERLAY","GameFontNormal")
            row.name:SetPoint("TOPLEFT",49,-10); row.name:SetWidth(237); row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
            row.detail = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.detail:SetPoint("TOPLEFT",49,-34); row.detail:SetWidth(237); row.detail:SetJustifyH("LEFT")
            row:SetAttribute("spell1", spellID)
            row:SetScript("PreClick", function(button)
                if InCombatLockdown() then return end
                local item = button.entry
                local info = item and item.bag and self:Readable(C_Container.GetContainerItemInfo(item.bag, item.slot))
                local skillName, rank = self:ComprehensionSkill()
                local required, blocked
                if info and skillName then required, blocked = self:ComprehendRequirement(item.bag, item.slot, self:Readable(info.itemID), skillName) end
                local valid = self.db.scrolls.enabled and self:KnownSpell(spellID) and info and self:Readable(info.itemID) == item.id
                    and self:Readable(info.isLocked) == false and required and not blocked and rank >= required
                    and not (GetCursorInfo and GetCursorInfo()) and not (SpellIsTargeting and SpellIsTargeting())
                button:SetAttribute("type1", valid and "spell" or "")
            end)
            row:SetScript("OnEnter", function(button)
                local item = button.entry
                GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
                if item.bag then GameTooltip:SetBagItem(item.bag,item.slot) else GameTooltip:SetItemByID(item.id) end
                GameTooltip:AddLine(item.eligible and "Left-click: Comprehend one scroll" or "Comprehension requirement not met",0.4,0.85,1,true); GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            frame.rows[index] = row
        end
        row.entry = entry
        row.fill:SetColorTexture(0.01,0.12,0.2,entry.eligible and 0.88 or 0.35)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Scroll_03")
        row.icon:SetAlpha(entry.eligible and 1 or 0.4)
        row.name:SetText(entry.name .. (entry.count > 1 and (" ×" .. entry.count) or ""))
        row.name:SetTextColor(0.5,entry.eligible and 0.82 or 0.5,entry.eligible and 1 or 0.5)
        row.detail:SetText(string.format("Requires %d · %s",entry.required,
            not entry.eligible and "Locked" or entry.bag and "Click to comprehend" or "Busy"))
        row.detail:SetTextColor(0.65,0.65,0.65)
        row:SetAttribute("target-bag1",entry.bag); row:SetAttribute("target-slot1",entry.slot)
        row:SetAttribute("type1",entry.eligible and entry.bag and "spell" or "")
        row:SetEnabled(entry.eligible and entry.bag ~= nil); row:Show()
    end
    for index = #entries+1, #frame.rows do
        local row = frame.rows[index]; row:SetAttribute("type1", ""); row.entry = nil; row:Hide()
    end
    frame.scroll:SetSize(296, math.max(1,math.min(6,#entries))*66)
    frame.content:SetSize(296,math.max(1,#entries)*66)
    frame:SetSize(344, 100+math.min(6,#entries)*66)
    frame:SetShown(eligible and self.scrollDismissed ~= self.scrollSignature)
end
