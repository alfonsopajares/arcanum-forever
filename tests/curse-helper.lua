local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local now,raid,grouped=500,false,true
GetTime=function() return now end
IsInRaid=function() return raid end
IsInGroup=function() return grouped end
local units={player={name="Me",guid="me"},party1={name="Nix",guid="nix"}}
UnitExists=function(u) return units[u]~=nil end
UnitName=function(u) return units[u] and units[u].name end
UnitGUID=function(u) return units[u] and units[u].guid end
UnitIsDeadOrGhost=function(u) return units[u] and units[u].dead or false end
UnitIsConnected=function(u) return not (units[u] and units[u].offline) end
local auras,restrict={},false
C_UnitAuras={GetAuraDataByIndex=function(u,i)
    if restrict then error("restricted") end
    return auras[u] and auras[u][i]
end}
C_Spell.IsSpellInRange=function(_,u) if units[u] then return units[u].range end end
known[475]=true
addon.db.curseHelper=addon:Clone(addon.defaults.curseHelper)
local root=addon.curseHelper
local registerStateDriver=RegisterStateDriver
local function updateNativeVisibility(frame)
    for rule in frame.stateDrivers.visibility:gmatch("[^;]+") do
        local condition=rule:match("%[([^%]]+)%]")
        if not condition or (condition=="group:raid" and raid) or (condition=="group:party" and grouped and not raid)
            or (condition=="combat" and combat) then
            local wasSecure=secure
            secure=true
            frame:SetShown(rule:match("(%a+)%s*$")=="show")
            secure=wasSecure
            return
        end
    end
end
RegisterStateDriver=function(frame,state,rule)
    registerStateDriver(frame,state,rule)
    if frame==root or frame==root.party or frame==root.raid then updateNativeVisibility(frame) end
end
addon:ApplyCurseSettings()
updateNativeVisibility(root)
local p=root.buttons[2]
check(root.width==160 and root.height==52,"locked two-player helper fits only its compact tiles")
addon.db.curseHelper.locked=false; addon:ApplyCurseSettings()
check(root.width==160 and root.height==74 and root.handle.width==148,"unlocked helper adds only a compact roster-width drag header")
addon.db.curseHelper.locked=true; addon:ApplyCurseSettings()
check(#root.buttons==45,"party and all forty raid unit slots are precreated")
check(root:IsShown(),"learned decurse and enabled option show controller")
check(p.unit=="party1" and p:GetAttribute("unit")=="party1" and p:GetAttribute("spell1")==475,"each square casts decurse on its fixed unit")
check(p:GetAttribute("type1")=="spell" and p.unitWatch,"native unit watch controls slot visibility without combat mutations")
check(p:GetAttribute("checkselfcast")==false and not p:GetAttribute("type2"),"self-cast modifiers and right click cannot redirect cleansing")
check(root.party.stateDrivers.visibility:find("group:raid",1,true) and root.raid.stateDrivers.visibility=="[group:raid] show; hide","native state drivers switch group layouts even during combat")
local native
for _,f in ipairs(allFrames) do if f.kind=="AuraContainer" and f.nativeUnit=="party1" then native=f; break end end
check(native and p.native,"native restricted aura display is configured")
local slot=native.auraSlots.ARCANUM_CURSE
check(slot.filter=="HARMFUL" and slot.options.candidateFilters.includeDispelTypes.Curse,"native indicator only requests curses, not diseases or magic")
check(p.curseState=="clear" and p.status.text=="","readable curse-free unit has no false alert")
auras.party1={{dispelName="Magic"},{dispelName="Poison"}}; addon:UpdateCurseHelper(true)
check(p.curseState=="clear","non-curse debuffs are ignored")
local played=0; PlaySoundFile=function() played=played+1 end
auras.party1={{dispelName="Curse"}}; addon:UpdateCurseHelper(true)
check(p.curseState=="curse" and p.status.text=="CURSE","readable curse gets explicit status")
check(played==0,"curse sound defaults to disabled")
addon.db.curseHelper.sound=true; auras.party1={}; addon:UpdateCurseHelper(true)
auras.party1={{dispelName="Curse"}}; addon:UpdateCurseHelper(true)
check(played==1,"a new readable curse can sound")
addon:UpdateCurseHelper(true)
check(played==1,"persistent curse does not repeat sound")
auras.party1={}; addon:UpdateCurseHelper(true); auras.party1={{dispelName="Curse"}}; addon:UpdateCurseHelper(true)
check(played==1,"rapid gains are globally throttled")
auras.party1={}; addon:UpdateCurseHelper(true); now=504; auras.party1={{dispelName="Curse"}}; addon:UpdateCurseHelper(true)
check(played==2,"genuine later gains can alert again")
combat=true; auras.party1={{dispelName=secretNumber()}}; addon:UpdateCurseHelper(true)
check(p.curseState=="unknown" and p.status.text=="?","protected curse type is explicitly unknown")
check(played==2,"restricted type cannot trigger sounds")
auras.party1={secretNumber()}; addon:UpdateCurseHelper(true)
check(p.curseState=="unknown","secret aura table is never indexed")
restrict=true; addon:UpdateCurseHelper(true)
check(p.curseState=="unknown" and p.native,"unavailable Lua aura data does not dismantle native combat highlight")
restrict=false; now=508; auras.party1={{dispelName="Curse"}}; addon:UpdateCurseHelper(true)
check(played==2,"temporarily unknown status does not re-arm sound for an existing curse")
local unit,spell=p:GetAttribute("unit"),p:GetAttribute("spell1")
local width,height=root.width,root.height
addon.db.curseHelper.scale=120; addon.db.curseHelper.enabled=false; addon:ApplyCurseSettings()
check(root.width==width and root.height==height,"compact frame geometry is never changed during combat")
check(addon.curseSettingsPending and p:GetAttribute("unit")==unit and p:GetAttribute("spell1")==spell,"combat settings defer protected actions and layout")
check(p:GetAttribute("type1")=="spell","previously enabled square stays securely usable until deferred disable applies")
combat=false; addon:ApplyCurseSettings()
check(not root:IsShown() and p:GetAttribute("type1")=="" and not addon.curseSettingsPending,"deferred disable clears actions outside combat")
addon.db.curseHelper.enabled=true; addon:ApplyCurseSettings()
check(root.scale==1.2,"deferred scale applies without changing circle scale")
combat=true; units.party1.range=false; addon:UpdateCurseHelper(false)
check(p.status.text=="Far" and p.alpha<1,"a confirmed far unit has a dimmed square and a range label")
check(p.curseState=="curse","the far target still has its curse indicator")
units.party1.range=true; addon:UpdateCurseHelper(false)
check(p.alpha==1 and p.status.text=="CURSE" and p:GetAttribute("spell1")==475,
    "moving into range restores full brightness without rebinding the combat click")
units.party1.range=false; addon:UpdateCurseHelper(false)
combat=false
units.party1.dead=true; addon:UpdateCurseHelper(false)
check(p.status.text=="Dead","dead state is distinguished")
units.party1.offline=true; addon:UpdateCurseHelper(false)
check(p.status.text=="Offline","offline state is distinguished")
units.party1.offline=false; units.party1.dead=false; units.party1.range=secretNumber(); auras.party1={}; addon:UpdateCurseHelper(false)
check(p.status.text=="" and p.alpha==1,"unreadable range clears stale dimming without classifying the target as far")
raid=true; units.raid1={name="Raid Mage",guid="r1"}; auras.raid1={{dispelName="Curse"}}; addon:UpdateCurseHelper(false)
check(root.buttons[6].curseState=="curse" and root.buttons[6]:GetAttribute("unit")=="raid1","raid slot keeps correct identity and curse status")
units.raid6={name="Sixth",guid="r6"}; addon:ApplyCurseSettings()
check(root.width==388 and root.height==96 and root.buttons[11].point[3]==-50,"raid footprint includes the last occupied row without moving secure unit identities")
units.raid6=nil
raid=false; units.party1.guid="replacement"; units.party1.name="New Member"; addon:UpdateCurseHelper(false)
check(p.member=="replacement" and p.name.text=="New Member","party member replacement refreshes identity without reassigning tokens")
grouped=false; units.party1=nil
fire("GROUP_ROSTER_UPDATE")
updateNativeVisibility(root)
check(not root:IsShown() and root.width==96,"leaving the group collapses to a hidden solo helper")
addon:OpenSettings("Curses")
addon.db.curseHelper.locked=false; addon:ApplyCurseSettings()
check(root:IsShown() and root.handle:IsShown(),"an unlocked solo helper can still be positioned from its settings page")
addon.settings:Hide(); addon:UpdateCurseHelper(false)
check(not root:IsShown(),"closing settings hides a curse-free solo helper again")
addon.db.curseHelper.locked=true; addon:ApplyCurseSettings()
auras.player={{dispelName="Magic"}}
fire("UNIT_AURA","player")
check(not root:IsShown(),"solo non-curse debuffs do not open the helper")
auras.player={{dispelName="Curse"}}
fire("UNIT_AURA","player")
local solo=root.buttons[1]
check(root:IsShown() and solo.status.text=="CURSE" and solo:GetAttribute("unit")=="player"
    and solo:GetAttribute("spell1")==475,"a solo curse reveals a clickable self square")
auras.player={}
fire("UNIT_AURA","player")
check(not root:IsShown(),"clearing the solo curse hides the helper")
combat=true
updateNativeVisibility(root)
fire("PLAYER_REGEN_DISABLED")
check(root:IsShown() and solo:GetAttribute("type1")=="spell","native visibility keeps self-decurse clickable during solo combat")
auras.player={secretNumber()}
fire("UNIT_AURA","player")
check(solo.status.text=="?" and solo.native,"solo combat retains the native curse indicator with restricted aura data")
combat=false; auras.player={}
fire("PLAYER_REGEN_ENABLED")
updateNativeVisibility(root)
check(not root:IsShown(),"a curse-free solo player returns to a hidden helper after combat")
addon.db.curseHelper.hideWhenSolo=true
addon:ApplyCurseSettings()
auras.player={{dispelName="Curse"}}
fire("UNIT_AURA","player")
check(not root:IsShown(),"Hide when solo suppresses the helper even while cursed")
combat=true
updateNativeVisibility(root)
check(not root:IsShown(),"Hide when solo also suppresses the combat fallback")
combat=false; grouped=true
units.party1={name="New Member",guid="replacement"}
fire("GROUP_ROSTER_UPDATE")
updateNativeVisibility(root)
check(root:IsShown() and root.width==160,"the grouped helper stays available with the solo opt-out enabled")
known[475]=nil; addon:ApplyCurseSettings()
check(not root:IsShown() and p:GetAttribute("type1")=="","unknown decurse keeps live grid hidden and actions empty")
addon:HandleCommand("curses test")
check(addon.cursePreview:IsShown() and not addon.cursePreview.protected,"preview works without learning decurse and uses no secure spell buttons")
addon:HandleCommand("curses stop")
check(not addon.cursePreview:IsShown(),"preview stop command closes it")
combat=true; addon:PreviewCurseHelper()
check(not addon.cursePreview:IsShown(),"cannot start preview during combat")
combat=false; addon:HandleCommand("curses")
check(addon.settings.pages.Curses:IsShown() and addon.settings.tabs.Support.point[3]<addon.settings.tabs.Curses.point[3],"settings page opens and Support stays last")
RegisterStateDriver=registerStateDriver
io.write("Passed ",checks," curse helper, native display, combat, sound, roster, and preview checks.\n")
