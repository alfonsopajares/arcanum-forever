local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local old=C_UnitAuras
local aura, other, exists, hostile, dead
exists,hostile,dead=true,true,false
UnitExists=function() return exists end
UnitCanAttack=function() return hostile end
UnitIsDeadOrGhost=function() return dead end
spellNames[12654]="Ignite"
C_UnitAuras={GetUnitAuraBySpellID=function(unit,id) if unit=="target" and id==12654 then return other or aura end end,
    GetAuraDataByIndex=function(unit,index) if unit=="target" and index==1 then return aura end end}
addon.db.showIgnite,addon.db.procs.enabled=true,true
addon:UpdateIgniteDisplay()
local card=addon.procDisplay.cards.ignite
check(not card:IsShown(),"no false Ignite without aura")
other={spellId=12654,applications=3,sourceUnit="party1"}; fire("UNIT_AURA","target")
check(not card:IsShown(),"another mage's Ignite cannot appear as yours")
aura={spellId=12654,sourceUnit="player",expirationTime=999999}
addon:UpdateIgniteDisplay()
check(card:IsShown(),"scan finds personal copy behind another mage's Ignite")
check(card.count.text=="" and card.callout.text=="YOUR TARGET IS BURNING","Ignite displays personal uptime, not fabricated stacks")
aura.sourceUnit=secretNumber(); addon:UpdateIgniteDisplay()
check(not card:IsShown(),"secret ownership is never assumed personal")
aura.sourceUnit="player"; aura.expirationTime=secretNumber(); combat=true
fire("UNIT_AURA","target")
check(card:IsShown() and card.timer.text=="Timer unavailable","secret timer never enters arithmetic")
addon.db.showIgnite=false; addon:SettingsChanged()
check(not card:IsShown(),"Ignite switch applies immediately in combat")
combat=false; addon.db.showIgnite=true; addon.db.visible=false; addon:UpdateIgniteDisplay()
check(card:IsShown(),"alerts remain independent of circle visibility")
hostile=false; fire("UNIT_FLAGS","target")
check(not card:IsShown(),"friendly targets hide Ignite")
hostile=true; dead=true; fire("UNIT_HEALTH","target")
check(not card:IsShown(),"dead targets hide Ignite")
dead=false; exists=false; fire("PLAYER_TARGET_CHANGED")
check(not card:IsShown(),"cleared target hides Ignite")
exists=true; aura=nil; other=nil; fire("PLAYER_TARGET_CHANGED")
check(not card:IsShown(),"new target without Ignite clears old display")
C_UnitAuras.GetUnitAuraBySpellID=function() return secretNumber() end
C_UnitAuras.GetAuraDataByIndex=function() error("restricted") end
addon:UpdateIgniteDisplay()
check(not card:IsShown() and addon.procStates.ignite=="unavailable","restricted aura object safely hides the alert")
C_UnitAuras=old
io.write("Passed ",checks," personal Ignite checks.\n")
