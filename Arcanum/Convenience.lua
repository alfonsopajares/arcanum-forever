local _, addon = ...

-- Minimum recipient levels from the vanilla buff ranks. Unknown additional
-- Forever ranks keep their normal binding rather than guessing a level.
local recipientLevels = {
    [1459]={1,4,17,32,46},
    [604]={12,24,36,48,60},
    [1008]={18,30,42,54},
}

function addon:RecipientBuffSpell(action, combatRank)
    if not action or action.kind ~= "spell" or not self.db.recipientBuffRanks then return action and action.id end
    local levels = recipientLevels[action.baseSpell]
    if not levels then return action.id end
    local definition
    for _, spell in ipairs(self.spells) do if spell.ranks[1] == action.baseSpell then definition = spell; break end end
    if not definition then return action.id end
    local catalogued = false
    for _, id in ipairs(definition.ranks) do if id == action.id then catalogued = true end end
    if not catalogued then return action.id end
    local target = UnitCanAssist and self:Readable(UnitCanAssist("player", "target")) == true
    if not combatRank and not target then return action.id end
    local level = not combatRank and UnitLevel and self:Readable(UnitLevel("target"))
    local selected, lowest
    for index, id in ipairs(definition.ranks) do
        if self:KnownSpell(id) then
            lowest = lowest or id
            if type(level) == "number" and level > 0 and level >= levels[index] then selected = id end
        end
    end
    if combatRank or type(level) ~= "number" or level <= 0 then return lowest or action.id end
    return selected -- No rank is usable by this target: left-click is a no-op.
end

function addon:ConfigureRecipientBuff(button, action, prefix)
    prefix = prefix or ""
    local adaptive = action and action.kind == "spell" and recipientLevels[action.baseSpell] and self.db.recipientBuffRanks
    button:SetAttribute(prefix .. "buff-adaptive", adaptive and true or nil)
    button:SetAttribute(prefix .. "buff-peace-spell", adaptive and self:RecipientBuffSpell(action) or nil)
    button:SetAttribute(prefix .. "buff-combat-spell", adaptive and self:RecipientBuffSpell(action,true) or nil)
    button:SetAttribute(prefix .. "spell1", adaptive and (self:RecipientBuffSpell(action) or "") or (action and action.kind == "spell" and action.id or nil))
    if prefix == "" then
        button:SetAttribute("spell2", action and action.kind == "spell" and action.id or nil)
    end
    if adaptive and not button.buffWrapped then
        button.buffWrapped = true
        SecureHandlerWrapScript(button, "OnClick", button, [[
            if button ~= "LeftButton" then return end
            local prefix = IsShiftKeyDown() and self:GetAttribute("shift-buff-adaptive") and "shift-" or ""
            if self:GetAttribute(prefix .. "buff-adaptive") then
                local key = SecureCmdOptionParse("[combat] combat") and "buff-combat-spell" or "buff-peace-spell"
                self:SetAttribute(prefix .. "spell1", self:GetAttribute(prefix .. key) or "")
            end
        ]])
        button:HookScript("PreClick", function(_, _, down)
            if down or InCombatLockdown() then return end
            if button.categoryID and button.lastAction then
                self:ConfigureRecipientBuff(button, button.lastAction, "shift-")
            elseif button.action then self:ConfigureRecipientBuff(button, button.action) end
        end)
    end
end

function addon:UpdateMinimapButton()
    if not self.minimapButton then return end
    self.minimapButton:SetShown(self.db.minimap.enabled)
    local radius = (Minimap.GetWidth and Minimap:GetWidth() or 140) / 2 + 10
    local angle = math.rad(self.db.minimap.angle)
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle)*radius, math.sin(angle)*radius)
end

function addon:CreateMinimapButton()
    if not Minimap then return end
    local button = CreateFrame("Button", "ArcanumMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(32,32); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(20)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp"); button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil,"ARTWORK")
    icon:SetSize(24,24); icon:SetPoint("CENTER"); icon:SetTexture("Interface\\AddOns\\Arcanum\\Media\\Orb")
    local border = button:CreateTexture(nil,"OVERLAY")
    border:SetSize(54,54); border:SetPoint("TOPLEFT",0,0); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function() self:OpenSettings() end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button,"ANCHOR_LEFT"); GameTooltip:SetText("Arcanum Forever")
        GameTooltip:AddLine("Click: options. Drag: move around the minimap.",1,1,1,true); GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        button:SetScript("OnUpdate", function()
            local x,y = GetCursorPosition()
            local cx,cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            if cx and cy and scale and scale > 0 then
                self.db.minimap.angle = math.deg(math.atan2(y/scale-cy,x/scale-cx)) % 360
                self:UpdateMinimapButton()
            end
        end)
    end)
    button:SetScript("OnDragStop", function() button:SetScript("OnUpdate",nil) end)
    button:SetScript("OnHide", function() button:SetScript("OnUpdate",nil) end)
    self:UpdateMinimapButton()
end
