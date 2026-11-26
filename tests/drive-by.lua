local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local stamp=200
GetTime=function() return stamp end
local savedTimer=C_Timer
local timers={}
C_Timer={After=function(delay,callback) timers[#timers+1]={time=stamp+delay,callback=callback} end}
local function advance(delay)
    stamp=stamp+delay
    for index=#timers,1,-1 do
        if timers[index].time<=stamp then table.remove(timers,index).callback() end
    end
end
local function reported(fragment)
    local message=messages[#messages] or ""
    return message:find("Drive-by Intellect",1,true) and message:find(fragment,1,true)
end
combat=false
local units={mouseover={player=true,friendly=true,dead=false,level=20,power=0,name="Passing Mage"},
    target={player=true,friendly=true,dead=false,level=60,power=0,name="Friendly Target"}}
UnitIsPlayer=function(u) return units[u] and units[u].player or false end
UnitCanAssist=function(_,u) return units[u] and units[u].friendly or false end
UnitIsDeadOrGhost=function(u) if units[u] then return units[u].dead end end
UnitIsUnit=function(u,v) return u==v end
UnitLevel=function(u) return units[u] and units[u].level end
UnitPowerType=function(u) return units[u] and units[u].power end
UnitName=function(u) return units[u] and units[u].name end
local aura
C_UnitAuras={GetAuraDataByIndex=function(_,index) if index==1 then return aura end end}
known={[1459]=true,[1460]=true,[1461]=true,[10156]=true,[10157]=true}
addon.db.driveBy=addon:Clone(addon.defaults.driveBy)
local button=addon.keyButtons.DriveBy
local function click() button.hooks.PreClick(button,"LeftButton",false) end
click()
check(button:GetAttribute("spell1")==1461 and button:GetAttribute("unit1")=="mouseover","mouseover gets highest learned usable rank")
check(button:GetAttribute("type1")=="spell" and button:GetAttribute("checkselfcast")==false,"binding uses native secure spell action without self-cast override")
units.mouseover.level=4; click()
check(button:GetAttribute("spell1")==1460,"rank changes for a lower-level passerby at click time")
known[1460]=nil; click()
check(button:GetAttribute("spell1")==1459,"only learned ranks are eligible")
known[1460]=true; units.mouseover.level=secretNumber(); click()
check(button:GetAttribute("spell1")==1459,"protected level uses lowest learned rank without comparison")
units.mouseover.level=20; units.mouseover.player=false; click()
check(button:GetAttribute("type1")=="" and button:GetAttribute("unit1")=="none","NPC mouseover cannot trigger casting or self fallback")
check(reported("Hover a living, friendly player"),"missing mouseover explains how to aim the keybind")
addon.db.driveBy.targetFallback=true; click()
check(button:GetAttribute("unit1")=="target" and button:GetAttribute("spell1")==10157,"optional friendly target fallback chooses its own rank")
units.mouseover.player=true; click()
check(button:GetAttribute("unit1")=="mouseover","eligible mouseover always wins over target")
units.mouseover.dead=true; click()
check(button:GetAttribute("unit1")=="target","dead mouseover can fall back to eligible target")
units.mouseover.dead=false; units.mouseover.friendly=false; addon.db.driveBy.targetFallback=false; click()
check(button:GetAttribute("type1")=="","hostile players are rejected")
units.mouseover.friendly=true; addon.db.driveBy.manaOnly=true; units.mouseover.power=1; click()
check(button:GetAttribute("type1")=="","optional filter rejects non-mana players")
check(reported("mana-only filter"),"filtered players get a distinct explanation")
units.mouseover.power=secretNumber(); click()
check(button:GetAttribute("type1")=="","protected power information cannot pass mana-only filter")
local messagesBeforeRefresh=#messages
units.mouseover.power=0; aura={spellId=1461}; click()
check(button:GetAttribute("type1")=="spell" and button:GetAttribute("spell1")==1461,
    "equal Intellect can be refreshed")
check(#messages==messagesBeforeRefresh,"an equal-rank refresh does not print a skip reason")
aura={spellId=10157}; click()
check(button:GetAttribute("type1")=="","stronger Intellect is skipped")
check(reported("already has a stronger Arcane Intellect buff"),"skipping a stronger buff is explained in chat")
aura={spellId=23028}; click()
check(button:GetAttribute("type1")=="","Arcane Brilliance blocks a lower-rank cast")
units.mouseover.level=60; click()
check(button:GetAttribute("type1")=="spell" and button:GetAttribute("spell1")==10157,
    "equivalent Arcane Brilliance allows a rank-five cast")
units.mouseover.level=20
aura={spellId=1459}; click()
check(button:GetAttribute("spell1")==1461,"weaker Intellect can be upgraded")
aura={spellId=secretNumber()}; click()
check(button:GetAttribute("spell1")==1461,"unreadable aura identity does not block manual cast")
aura=secretNumber(); click()
check(button:GetAttribute("spell1")==1461,"secret aura object is never indexed")
C_UnitAuras.GetAuraDataByIndex=function() error("restricted") end; click()
check(button:GetAttribute("spell1")==1461,"restricted buff API does not silently block casting")
C_UnitAuras.GetAuraDataByIndex=function() return nil end
addon.db.driveBy.enabled=false; click()
check(button:GetAttribute("type1")=="" and not addon.driveByPending,"master switch clears action and confirmation state")
check(reported("disabled"),"disabled keybind still explains why it skipped the cast")
addon.db.driveBy.enabled=true; known={}; click()
check(button:GetAttribute("type1")=="","unlearned Intellect never casts")
check(reported("haven’t learned"),"unknown rank is explained in chat")
known[1459]=true; click()
check(button:GetAttribute("spell1")==1459,"newly learned Intellect is picked up")
local savedRange,savedUsable=C_Spell.IsSpellInRange,C_Spell.IsSpellUsable
C_Spell.IsSpellInRange=function(spell,unit)
    check(spell==1459 and unit=="mouseover","range check uses the chosen rank and recipient")
    return false
end
click()
check(button:GetAttribute("type1")=="" and reported("out of range"),"confirmed range failure is immediate")
C_Spell.IsSpellInRange=function() return secretNumber() end
C_Spell.IsSpellUsable=function() return false,true end
click()
check(button:GetAttribute("type1")=="" and reported("Not enough mana"),"confirmed lack of mana is immediate")
C_Spell.IsSpellUsable=function() return secretNumber(),secretNumber() end
click()
check(button:GetAttribute("type1")=="spell","secret range and mana values do not block a secure cast")
C_Spell.IsSpellInRange,C_Spell.IsSpellUsable=savedRange,savedUsable
-- Replay the actual secure pre-handler while the mock enforces lockdown.
local wrapper=assert(loadstring(button.secureWrappers.OnClick))
setfenv(wrapper,setmetatable({self=button,button="LeftButton",down=false},{__index=_G}))
SecureCmdOptionParse=function() return combat and "combat" or nil end
combat=true; click()
check(reported("outside combat"),"combat-blocked keybind explains the restriction")
secure=true; wrapper(); secure=false
check(button:GetAttribute("type1")=="","secure wrapper suppresses action armed before combat without taint")
combat=false; click()
check(button:GetAttribute("type1")=="spell","next out-of-combat click rearms normally")
local pending=addon.driveByPending
local before=#messages
addon:ConfigureDriveBy()
check(addon.driveByPending==pending and #messages==before,"background refresh preserves a pending keypress and does not report failures")
addon.driveByNotice:Hide()
fire("UNIT_SPELLCAST_SENT","player","Passing Mage","cast-one",1459)
fire("UNIT_SPELLCAST_SUCCEEDED","player","other-cast",1459)
check(not addon.driveByNotice:IsShown(),"unrelated cast GUID cannot show confirmation")
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast-one",1459)
check(addon.driveByNotice:IsShown() and addon.driveByNotice.text.text=="Intellect → Passing Mage","only matching successful cast confirms the recipient")
check(not addon.driveByPending,"success clears pending cast")
advance(3); addon.driveByNotice.scripts.OnUpdate()
check(not addon.driveByNotice:IsShown(),"confirmation automatically disappears")
check(#messages==before,"successful cast cancels all failure feedback")
addon:ConfigureDriveBy()
check(not addon.driveByPending,"background refresh cannot claim a manual buff as drive-by")
click(); fire("UNIT_SPELLCAST_SENT","player","Passing Mage","failed",1459)
fire("UNIT_SPELLCAST_FAILED","player","failed",1459)
local savedLos=SPELL_FAILED_LINE_OF_SIGHT
SPELL_FAILED_LINE_OF_SIGHT="Target not in line of sight"
fire("UI_ERROR_MESSAGE",0,SPELL_FAILED_LINE_OF_SIGHT)
advance(0.3)
check(not addon.driveByPending and not addon.driveByNotice:IsShown(),"failed cast produces no success notice")
check(reported(SPELL_FAILED_LINE_OF_SIGHT),"game error text arriving after a matched failure is reported")
click()
fire("UI_ERROR_MESSAGE",0,SPELL_FAILED_LINE_OF_SIGHT)
advance(0.3)
check(not addon.driveByPending and reported(SPELL_FAILED_LINE_OF_SIGHT),"client rejection without a sent cast is reported")
SPELL_FAILED_LINE_OF_SIGHT=savedLos
before=#messages
click()
fire("UI_ERROR_MESSAGE",0,"Inventory is full")
fire("UNIT_SPELLCAST_FAILED","player","unrelated-failure",10)
advance(0.3)
check(#messages==before,"unrelated UI messages and cast failures are ignored")
advance(3)
check(#messages==before+1 and reported("didn’t confirm"),"an unacknowledged cast explains that the game gave no confirmation")
click(); fire("UNIT_SPELLCAST_SENT","player","Passing Mage","interrupted",1459)
fire("UNIT_SPELLCAST_INTERRUPTED","player","interrupted",1459)
check(not addon.driveByPending and reported("interrupted"),"matching interrupted casts get a chat message")
local sounds=0; PlaySoundFile=function() sounds=sounds+1 end
click(); fire("UNIT_SPELLCAST_SENT","player","Passing Mage","quiet",1459)
fire("UNIT_SPELLCAST_SUCCEEDED","player","quiet",1459)
check(sounds==0,"confirmation sound is off by default")
addon.db.driveBy.sound=true; addon.db.driveBy.confirm=false; addon.driveByNotice:Hide()
click(); fire("UNIT_SPELLCAST_SENT","player","Passing Mage","audible",1459)
fire("UNIT_SPELLCAST_SUCCEEDED","player","audible",1459)
check(sounds==1 and not addon.driveByNotice:IsShown(),"visual and sound confirmations have independent controls")
check(not button:GetAttribute("macrotext1"),"drive-by never targets through a retargeting macro")
C_Timer=savedTimer
io.write("Passed ",checks," drive-by recipient, rank, filter, combat, and confirmation checks.\n")
