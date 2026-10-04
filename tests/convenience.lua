local checks=0
local function check(value,message) assert(value,message); checks=checks+1 end
combat=false
known,inventory,spellBook = {[1459]=true,[1460]=true,[1461]=true,[10156]=true,[10157]=true,
    [604]=true,[8450]=true,[8451]=true,[10173]=true,[10174]=true,
    [1008]=true,[8455]=true,[10169]=true,[10170]=true,[12051]=true,[759]=true}, {[6948]=1,[5514]=1}, {}
local helpful, level=true,1
UnitCanAssist=function() return helpful end
UnitLevel=function() return level end
addon.db.recipientBuffRanks=true
addon:RefreshActions()
local function buff(base)
    for _,button in ipairs(addon.menus.buffs.rows) do
        if button.action and button.action.baseSpell == base then return button end
    end
end
local intellect,dampen,amplify=buff(1459),buff(604),buff(1008)
check(intellect:GetAttribute("spell1") == 1459 and intellect:GetAttribute("spell2") == 10157,
    "low-level target gets learned rank one while self-cast retains highest rank")
for _, entry in ipairs({{4,1460},{17,1461},{32,10156},{46,10157}}) do
    level=entry[1]; intellect.hooks.PreClick(intellect,"LeftButton",false)
    check(intellect:GetAttribute("spell1") == entry[2], "Intellect follows recipient-level rank thresholds")
end
level=16; intellect.hooks.PreClick(intellect,"LeftButton",false)
check(intellect:GetAttribute("spell1") == 1460, "rank selection stays below the next threshold")
known[1460]=nil
level=10; addon:RefreshActions(); intellect=buff(1459)
check(intellect:GetAttribute("spell1") == 1459, "rank picker never binds an unlearned rank")
level=42; fire("PLAYER_TARGET_CHANGED")
check(dampen:GetAttribute("spell1") == 8451 and amplify:GetAttribute("spell1") == 10169,
    "Dampen and Amplify have independent rank thresholds")
level=1; fire("UNIT_LEVEL","target")
check(amplify:GetAttribute("spell1") == "", "target below available rank requirements gets an explicit no-op")
level=secretNumber(); intellect.hooks.PreClick(intellect,"LeftButton",false)
check(intellect:GetAttribute("spell1") == 1459, "protected target level falls back without secret arithmetic")
helpful=false; intellect.hooks.PreClick(intellect,"LeftButton",false)
check(intellect:GetAttribute("spell1") == 10157, "no friendly target preserves normal highest-rank self buff")
helpful=true; level=60; intellect.hooks.PreClick(intellect,"LeftButton",false)
SecureCmdOptionParse=function() return combat and "combat" or nil end
local function rankClick(button,shift)
    local fn=assert(loadstring(button.secureWrappers.OnClick))
    setfenv(fn,setmetatable({self=button,button="LeftButton",down=false},{__index=_G}))
    shiftHeld=shift or false
    secure=true; local ok,err=pcall(fn); secure=false; shiftHeld=false; assert(ok,err)
end
combat=true
level=1
intellect.hooks.PreClick(intellect,"LeftButton",false)
rankClick(intellect)
check(intellect:GetAttribute("spell1") == 1459 and intellect:GetAttribute("spell2") == 10157,
    "secure combat click chooses conservative rank without changing right-click self rank")
rankClick(intellect,true)
check(intellect:GetAttribute("spell1") == 1459, "modifier clicks on ordinary buff icons retain conservative combat selection")
combat=false
level=46
addon:RememberSelection("buffs",intellect.action)
local toggle=addon.toggles.buffs
check(toggle:GetAttribute("shift-spell1") == 10157, "last-selection shortcut uses recipient-level binding")
combat=true; level=1; rankClick(toggle,true)
check(toggle:GetAttribute("shift-spell1") == 1459, "secure Shift shortcut also downranks in combat")
combat=false
fire("PLAYER_REGEN_ENABLED")
check(intellect:GetAttribute("spell1") == 1459, "combat end reselects rank for current recipient")
addon.db.recipientBuffRanks=false
addon:SettingsChanged()
check(intellect:GetAttribute("spell1") == 10157 and not intellect:GetAttribute("buff-adaptive"), "rank adjustment can be disabled")
addon.db.recipientBuffRanks=true
addon.db.centerAction="gem"
addon:RefreshActions()
local hearth=addon.toggles.hearthstone
check(hearth:IsShown() and hearth:GetAttribute("type1") == "item" and hearth:GetAttribute("item1") == "item:6948",
    "standalone outer button securely uses a carried Hearthstone")
check(addon.sphere:GetAttribute("*type3") == "" and addon.sphere:GetAttribute("*item3") == nil,
    "orb middle-click no longer uses Hearthstone")
secureClick(hearth,"_onenter"); secureClick(hearth)
check(not addon.menus.hearthstone:IsShown() and #addon.menus.hearthstone.rows == 0, "Hearthstone never opens a flyout on hover or click")
check(hearth.directCooldown.start == 12 and hearth.directCooldown.duration == 120, "standalone Hearthstone button shows its actual item cooldown")
check(addon.sphere:GetAttribute("item1") == "item:5514" and addon.sphere:GetAttribute("shift-spell1") == 12051
    and addon.sphere:GetAttribute("*type2") == "", "Hearthstone does not replace orb actions or right-click options")
inventory[6948]=0; fire("BAG_UPDATE_DELAYED")
check(not hearth:IsShown() and hearth:GetAttribute("item1") == nil, "missing Hearthstone hides the outer button and clears its action")
inventory[6948]=1; addon.db.categoryEnabled.hearthstone=false; addon:SettingsChanged()
check(not hearth:IsShown(), "Hearthstone button can be disabled with the other circle buttons")
addon.db.categoryEnabled.hearthstone=true; addon:SettingsChanged()
addon:MoveCategory("hearthstone",-1)
check(addon:OrderedCategories()[#addon.categories-1].id == "hearthstone", "Hearthstone participates in saved circle ordering")
combat=true; inventory[6948]=0; fire("BAG_UPDATE_DELAYED")
check(hearth:GetAttribute("item1") == "item:6948" and addon.refreshPending, "Hearthstone bag changes defer protected rebinding during combat")
combat=false; fire("PLAYER_REGEN_ENABLED")
check(hearth:GetAttribute("item1") == nil and not hearth:IsShown(), "Hearthstone bag change applies after combat")
Minimap=CreateFrame("Frame","Minimap",UIParent)
Minimap.GetWidth=function() return 140 end
Minimap.GetCenter=function() return 100,100 end
Minimap.GetEffectiveScale=function() return 1 end
GetCursorPosition=function() return 100,180 end
addon:CreateMinimapButton()
local minimap=addon.minimapButton
check(minimap:IsShown() and minimap.parent == Minimap, "optional minimap button is shown on the minimap")
addon.settings:Hide(); minimap.scripts.OnClick()
check(addon.settings:IsShown(), "minimap click opens options")
minimap.scripts.OnDragStart(); minimap.scripts.OnUpdate()
check(math.abs(addon.db.minimap.angle-90)<0.001 and math.abs(minimap.point[4])<0.001,
    "dragging saves angle and anchors the button around minimap center")
minimap.scripts.OnDragStop()
check(not minimap.scripts.OnUpdate, "drag stop ends the positioning update")
addon.db.minimap.enabled=false; addon:SettingsChanged()
check(not minimap:IsShown(), "minimap button can be hidden in Circle settings")
addon.db.minimap.enabled=true; addon:SettingsChanged()
check(minimap:IsShown() and addon.db.minimap.angle == 90, "showing minimap button preserves its saved position")
io.write("Passed ",checks," recipient-rank, Hearthstone, and minimap checks.\n")
