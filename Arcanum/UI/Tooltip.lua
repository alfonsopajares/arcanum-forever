local _, addon = ...

-- Keep Arcanum styling separate from the game's shared tooltip.
function addon:BeginTooltip(owner, title, anchor)
    if not self.tooltip then
        self.tooltip = CreateFrame("GameTooltip", "ArcanumTooltip", UIParent, "GameTooltipTemplate,BackdropTemplate")
        self.tooltip:SetFrameStrata("TOOLTIP")
        self.tooltip:SetClampedToScreen(true)
    end
    local tip = self.tooltip
    tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tip:ClearLines()
    tip:SetText(title or "Arcanum Forever", 0.75, 0.4, 1)
    return tip
end

function addon:FinishTooltip()
    local tip = self.tooltip
    tip:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=false, edgeSize=16, insets={left=4,right=4,top=4,bottom=4}})
    tip:SetBackdropColor(0.025, 0.035, 0.075, 0.97)
    tip:SetBackdropBorderColor(0.4, 0.5, 0.9, 1)
    tip:Show()
end

function addon:HideTooltip()
    if self.tooltip then self.tooltip:Hide() end
end

function addon:TooltipControl(label, action)
    self.tooltip:AddDoubleLine(label, action, 0.8, 0.85, 0.95, 1, 1, 1)
end

function addon:TooltipCount(label, count, low)
    local r, g, b = 1, 1, 1
    if count == 0 then r, g, b = 1, 0.3, 0.3
    elseif low then r, g, b = 1, 0.7, 0.25 end
    self.tooltip:AddDoubleLine(label, tostring(count), 0.8, 0.85, 0.95, r, g, b)
end

function addon:TooltipSupplies()
    local stock = self:SupplyStatus()
    local _, profile = self:ActiveProfile()
    self.tooltip:AddLine(" ")
    self:TooltipCount("Water", stock.water, stock.water < profile.water)
    self:TooltipCount("Food", stock.food, stock.food < profile.food)
    if stock.learnedGems > 0 then self:TooltipCount("Mana Gems", stock.gems, stock.missingGems > 0) end
end

function addon:ActionTooltip(button, action)
    local tip = self:BeginTooltip(button, action.name)
    if action.kind == "spell" then
        tip:SetSpellByID(self:RecipientBuffSpell(action, InCombatLockdown()) or action.id)
    else tip:SetItemByID(action.id) end
    tip:AddLine(" ")
    self:TooltipControl("Left-click", action.kind == "spell" and "Cast" or "Use")
    if action.friendly then self:TooltipControl("Right-click", "Cast on yourself") end
    if action.countItem then
        self:TooltipCount(action.conjure and "Carried" or (action.kind == "spell" and "Reagents" or "Carried"), self:ItemCount(action.countItem))
    end
    self:FinishTooltip()
end
