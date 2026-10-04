combat, secure = false, false
C_AddOns = {GetAddOnMetadata = function(_, field) if field == "Version" then return testAddonVersion end end}
known, inventory, allFrames, spellBook = {}, {}, {}, {}
local methods = {}
local objectMT = { __index = methods }
for _, name in ipairs({"SetClampedToScreen", "SetMovable", "RegisterForDrag", "StartMoving",
    "SetAllPoints", "SetTexCoord", "AddMaskTexture", "SetWidth", "SetJustifyH",
    "EnableMouse", "SetHideCountdownNumbers", "SetColorTexture", "SetOwner", "SetSpellByID",
    "SetItemByID", "AddLine", "SetTextColor", "SetStatusBarTexture", "SetStatusBarColor",
    "SetFrameStrata", "SetBlendMode", "RegisterEvent", "UnregisterEvent", "SetBackdrop",
    "SetAutoFocus", "SetMaxLetters", "SetMultiLine", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
    "ClearFocus", "SetAlpha", "SetVertexColor", "SetScrollChild"}) do
    methods[name] = function() end
end
local function object(parent, template)
    return setmetatable({parent = parent, template = template or "", attributes = {}, refs = {}, scripts = {}, shown = true}, objectMT)
end
UIParent = object()
function InCombatLockdown() return combat end
shiftHeld = false
function IsShiftKeyDown() return shiftHeld end
function SecureHandlerWrapScript(frame, script, header, snippet) frame.secureWrappers = frame.secureWrappers or {}; frame.secureWrappers[script] = snippet end
function issecretvalue(value) return type(value) == "table" and rawget(value, "secret") == true end
function secretNumber()
    return setmetatable({secret = true}, {
        __div = function() error("secret division") end,
        __mul = function() error("secret multiplication") end,
        __add = function() error("secret addition") end,
        __lt = function() error("secret comparison") end,
        __le = function() error("secret comparison") end,
        __tostring = function() error("secret formatting") end,
    })
end
local function restricted(frame)
    if combat and not secure and frame.protected then error("combat lockdown mutation") end
end
function CreateFrame(kind, name, parent, template)
    local frame = object(parent, template)
    frame.kind = kind
    if template and template:find("Secure") then
        local current = frame
        while current do current.protected = true; current = current.parent end
    end
    allFrames[#allFrames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:SetAttribute(key, value) restricted(self); self.attributes[key] = value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:RunAttribute(key, ...)
    local fn = assert(loadstring(self:GetAttribute(key)))
    setfenv(fn, setmetatable({self=self}, {__index=_G}))
    return fn(...)
end
function methods:SetFrameRef(key, value) self.refs[key] = value end
function methods:GetFrameRef(key) return self.refs[key] end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:HookScript(key, value)
    self.hooks = self.hooks or {}
    self.hooks[key] = value
end
function methods:SetShown(value) restricted(self); self.shown = value end
function methods:Show() restricted(self); self.shown = true end
function methods:Hide() restricted(self); self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetPoint(...) restricted(self); self.point = {...} end
function methods:GetPoint() return unpack(self.point or {"CENTER", UIParent, "CENTER", 0, 0}) end
function methods:ClearAllPoints() restricted(self); self.point = nil end
function methods:SetSize(w, h) restricted(self); self.width, self.height = w, h end
function methods:CreateTexture() return object(self) end
function methods:CreateMaskTexture() return object(self) end
function methods:CreateFontString() return object(self) end
function methods:SetTexture(value) self.texture = value end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:SetChecked(value) self.checked = value end
function methods:SetEnabled(value) self.enabled = value end
function methods:SetFont(path, size, flags) self.fontSize = size end
function methods:GetChecked() return self.checked end
function methods:SetScale(value) restricted(self); self.scale = value end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetFrameLevel(value) self.frameLevel = value end
function methods:SetFormattedText(fmt, ...) self.format, self.values = fmt, {...} end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValue(value) self.value = value end
function methods:SetCooldown(start, duration) self.start, self.duration = start, duration end
function methods:SetCooldownFromDurationObject(duration) self.durationObject = duration end
function methods:Clear() self.durationObject, self.start, self.duration = nil, nil, nil end
function methods:RegisterForClicks(...) self.clicks = {...} end
function methods:StopMovingOrSizing() restricted(self) end
function methods:RegisterAutoHide(delay) self.autoDelay, self.autoIdle, self.autoWatch = delay, 0, {} end
function methods:AddToAutoHide(frame) self.autoWatch[frame] = true end
function methods:UnregisterAutoHide() self.autoDelay, self.autoWatch = nil, nil end
function RegisterAutoHide(frame, delay) frame:RegisterAutoHide(delay) end
function AddToAutoHide(frame, watched) frame:AddToAutoHide(watched) end
function tickAutoHide(elapsed, hovered)
    for _, frame in ipairs(allFrames) do
        if frame.autoDelay and frame:IsShown() then
            if hovered == frame or frame.autoWatch[hovered] then
                frame.autoIdle = 0
            else
                frame.autoIdle = frame.autoIdle + elapsed
                if frame.autoIdle >= frame.autoDelay then
                    secure = true; frame:Hide(); secure = false
                end
            end
        end
    end
end
function UnitClass() return "Mage", "MAGE" end
manaCurrent, manaMaximum, manaPercent = secretNumber(), secretNumber(), secretNumber()
function UnitPower() return manaCurrent end
function UnitPowerMax() return manaMaximum end
function UnitPowerPercent() return manaPercent end
CurveConstants = {ScaleTo100 = {}}
Enum = {SpellBookSpellBank = {Player = 0}}
spellNames = {[1459]="Arcane Intellect", [1460]="Arcane Intellect", [1461]="Arcane Intellect",
    [168]="Frost Armor", [7300]="Frost Armor", [5504]="Conjure Water", [5505]="Conjure Water",
    [587]="Conjure Food", [597]="Conjure Food", [118]="Polymorph", [759]="Conjure Mana Agate"}
C_SpellBook = {
    IsSpellKnown = function(id) return known[id] or false end,
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset=0, numSpellBookItems=#spellBook} end,
    GetSpellBookItemInfo = function(index) return {spellID=spellBook[index]} end,
}
C_Spell = {
    GetSpellInfo = function(id) return {name=spellNames[id] or ("Spell " .. id), iconID=id} end,
    GetSpellCooldownDuration = function(id) return {id=id} end,
}
C_Item = {
    GetItemCount = function(id) return inventory[id] or 0 end,
    GetItemInfo = function(id) return "Item " .. id end,
    GetItemIconByID = function(id) return id end,
}
C_Container = {GetItemCooldown = function() return 12, 120 end}
GameTooltip = object()
SlashCmdList = {}
messages = {}
print = function(message) messages[#messages + 1] = message end

function fire(event, ...)
    for _, frame in ipairs(allFrames) do
        if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
function secureClick(frame, attribute)
    local snippet = assert(frame:GetAttribute(attribute or "_onclick"))
    local fn = assert(loadstring(snippet))
    setfenv(fn, setmetatable({self=frame}, {__index=_G}))
    secure = true
    local ok, err = pcall(fn)
    secure = false
    assert(ok, err)
end
