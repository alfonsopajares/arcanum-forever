local checks=0
local function check(value,message) assert(value,message); checks=checks+1 end
local saved={db=addon.db,distribution=addon.distribution,known=known,inventory=inventory,character=addon.character,
    raid=IsInRaid,total=GetNumGroupMembers,party=GetNumSubgroupMembers,name=UnitName,
    guid=UnitGUID,class=UnitClass,level=UnitLevel,connected=UnitIsConnected,same=UnitIsUnit,time=GetTime,
    offer=addon.TradeOffer,trade=addon.trade,realm=GetRealmName,normalizedRealm=GetNormalizedRealmName,
    range=CheckInteractDistance,initiate=InitiateTrade,dead=UnitIsDeadOrGhost}
addon.db=addon:Clone(addon.defaults)
addon.db.preparation.profiles.solo={food=20,water=20}
addon.db.vending.reserveFood,addon.db.vending.reserveWater=20,20
addon.character={}; addon.distribution={}; addon.groupWhisperTimes={}
addon.trade={open=false,owned={}}
addon.groupSuppliesOpened=nil
known={[5504]=true,[5505]=true,[5506]=true,[587]=true,[597]=true,[990]=true}
inventory={[5350]=20,[5349]=20}
local raid=false
local roster={{name="Rogue",class="ROGUE",level=60},{name="Warrior",class="WARRIOR",level=60},
    {name="Priest",class="PRIEST",level=10},{name="Offline",class="PRIEST",level=60,offline=true}}
local function member(unit)
    if unit=="player" or raid and unit=="raid1" then return {name="Me",class="MAGE",level=60} end
    if unit=="NPC" then return roster[1] end
    local index=tonumber(unit:match("%d+"))
    return index and roster[index-(raid and 1 or 0)]
end
IsInRaid=function() return raid end
GetNumGroupMembers=function() return #roster+1 end
GetNumSubgroupMembers=function() return #roster end
UnitName=function(unit) local m=member(unit); return m and m.name,m and "Realm" end
UnitGUID=function(unit) local name=UnitName(unit); return name and "guid-"..name end
UnitClass=function(unit) local m=member(unit); return "Class",m and m.class end
UnitLevel=function(unit) local m=member(unit); return m and m.level or -1 end
UnitIsConnected=function(unit) local m=member(unit); return m and not m.offline end
UnitIsUnit=function(a,b) return UnitGUID(a)==UnitGUID(b) end
local clock=1000; GetTime=function() return clock end
addon.db.groupSupplies.autoShow=true -- Legacy preference from earlier local builds.
fire("GROUP_ROSTER_UPDATE")
local window=addon.groupSuppliesWindow
local shortcut=addon.groupSuppliesButton
check(not window:IsShown() and shortcut:IsShown(),"joining exposes the shortcut without opening Group Supplies, even with a legacy preference")
addon.db.preparation.showPrepare=false
addon:UpdateGroupSupplies()
check(not addon.prepareButton:IsShown() and shortcut:IsShown() and shortcut.point[4]==0,"group shortcut stays centered when personal Prepare is hidden")
addon.db.preparation.showPrepare=true
shortcut.scripts.OnClick()
check(addon:ActiveProfile()=="solo" and addon.prepareButton.text=="Prepared!","personal Prepared ignores other people's needs")
check(window:IsShown() and window.title.text=="Group Supplies (3)","circle shortcut opens the window with online pending recipients")
local coverage,menu=window.coverage,window.servingMenu
coverage.scripts.OnClick()
check(coverage.caption.text=="Whole group" and menu:IsShown() and menu.point[3]=="BOTTOMLEFT",
    "coverage shows the selected value and opens a list directly beneath the field")
menu.rows[2].scripts.OnClick(menu.rows[2])
check(coverage.caption.text=="Handpicked" and not menu:IsShown(),"choosing a coverage option updates the field and closes the list")
coverage.scripts.OnClick()
menu.rows[1].scripts.OnClick(menu.rows[1])
local p=addon:GroupPreparationProfile()
check(p.food==80 and p.water==60,"group plan keeps personal stock and adds online class requests")
check(p.nextSupply.water.id==5505,"group conjuring chooses a learned water rank usable at recipient level")
check(window.conjure:GetAttribute("spell1")==5505,"separate group button casts the exact needed rank")
check(window.conjure.secureWrappers.OnClick:find('[combat] combat',1,true),"group conjuring is securely blocked in combat")
local tradeUnit,tradeCount
tradeCount=0
InitiateTrade=function(unit) tradeUnit=unit; tradeCount=tradeCount+1 end
CheckInteractDistance=function(unit,distance) check(unit=="party1" and distance==2,"range check uses the live group unit and trade distance"); return false end
window.rows[1].trade.scripts.OnClick()
check(tradeCount==0 and window.need.text=="Out of range","distant name click explains range without starting a trade")
CheckInteractDistance=function() return true end
window.rows[1].trade.scripts.OnClick()
check(tradeCount==1 and tradeUnit=="party1" and window.need.text=="Requesting trade with Rogue",
    "nearby name click requests an outgoing trade with the correct roster member")
addon.trade.open=true
window.rows[1].trade.scripts.OnClick()
check(tradeCount==1 and window.need.text=="Finish the current trade first","name click preserves an existing trade")
addon.trade.open=false
combat=true
window.rows[1].trade.scripts.OnClick()
check(tradeCount==1,"click-to-trade is blocked in combat")
combat=false
UnitIsDeadOrGhost=function() return true end
window.rows[1].trade.scripts.OnClick()
check(tradeCount==1 and window.need.text=="Player unavailable","dead recipients cannot be traded")
UnitIsDeadOrGhost=saved.dead
addon.groupTradeNotice=nil
raid=true
check(addon:GroupPreparationProfile().food==80 and #addon:GroupMembers()==3,"raid calculation excludes self and offline members")
raid=false
local warrior=addon:FindGroupSupplyMember("Warrior")
addon:SetGroupSupplyAmount(warrior,"food",0)
check(addon:GetGroupSupplyRequest(warrior).food==0 and addon.db.vending.presets.WARRIOR.food==20,"skip warrior food without changing the class preset")
check(window.title.text=="Group Supplies (2)","skipped recipient disappears and is available to add back")
addon:RestoreGroupSupply(warrior)
check(addon:GetGroupSupplyRequest(warrior).food==20,"manual add back restores class defaults")
addon:SetGroupSupplyAmount(warrior,"food",37)
check(addon:GetGroupSupplyRequest(warrior).food==37,"custom per-recipient amount is supported")
addon:SetGroupSupplyAmount(warrior,"food",0)
local target=addon:GroupSupplyTradeTargets("Warrior",warrior.key)
check(target.food==0 and target.water==0,"vending honors a skipped group request")
addon:GroupSupplyWhisper("!water 40","Outsider-Realm")
check(addon:FindGroupSupplyMember("Outsider-Realm")==nil,"outsider whisper is ignored")
addon:GroupSupplyWhisper("!water 40","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).water==40,"current group member can request a custom amount by whisper")
addon:GroupSupplyWhisper("!food 40","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).food==0,"ten-second cooldown prevents repeated requests")
clock=clock+11
addon:GroupSupplyWhisper("!both 201","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).water==40,"oversized whisper request is rejected")
addon.db.groupSupplies.whispers=false
addon:GroupSupplyWhisper("!both 20","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).food==0,"whisper requests can be disabled")
addon.db.groupSupplies.whispers=true
addon:GroupSupplyWhisper("!both 20","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).food==20 and addon:GetGroupSupplyRequest(warrior).water==20,"both requests food and water")
addon:GroupSupplyDelivered({name="Warrior",key=warrior.key,food=10,water=20})
check(addon:GetGroupSupplyRequest(warrior).food==10 and addon:GetGroupSupplyRequest(warrior).water==0,"partial delivery leaves only remaining needs")
addon:GroupSupplyDelivered({name="Warrior",key=warrior.key,food=10,water=0})
check(addon:GetGroupSupplyRequest(warrior).food==0,"full delivery retires the request")
clock=clock+11
addon:GroupSupplyWhisper("!food","Warrior-Realm")
check(addon:GetGroupSupplyRequest(warrior).food==20,"a new whisper returns a supplied recipient to the list")
addon:GroupSupplyDelivered({name="Warrior",key=warrior.key,food=20,water=0})
addon.db.preparation.trackTrades=false
addon.distribution={}
addon:UpdateGroupSupplies()
check(addon:GetGroupSupplyRequest(warrior).food==0,"session requests remain fulfilled with distribution history off")
check(addon.character.supplyRequests[warrior.key].food==0,"fulfilled requests are stored with the character")
local priest=addon:FindGroupSupplyMember("Priest")
addon:SetGroupSupplyAmount(priest,"food",0); addon:SetGroupSupplyAmount(priest,"water",0)
inventory={[5350]=20,[5349]=40}
addon:RefreshActions()
check(addon:GroupPreparationProfile().food==40,"only rogue's outstanding stack adds to personal stock")
addon.TradeOffer=function() return {food=20,water=0},{1,2,3,4,5,6},{} end
fire("TRADE_SHOW")
check(addon.trade.targets.food==20 and addon.trade.targets.water==0,"trade opens with recipient's remaining request")
fire("TRADE_ACCEPT_UPDATE",1,1)
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).food==20,"acceptance is not counted as a completed delivery")
fire("TRADE_CLOSED"); inventory[5349]=20
fire("TRADE_PLAYER_ITEM_CHANGED",1); fire("TRADE_ACCEPT_UPDATE",0,0)
fire("UI_INFO_MESSAGE",0,ERR_TRADE_COMPLETE)
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).food==0,"confirmed trade retires the rogue even when optional history is disabled")
check(window.title.text=="Group Supplies (0)" and window.empty:IsShown(),"fully supplied people disappear automatically")
check(addon.prepareButton.text=="Prepared!" and addon:GroupPreparationProfile().food==20,"personal readiness remains prepared after the group trade")
check(window.conjure:GetAttribute("spell1")==nil,"ready group button clears its previous cast")
fire("UI_INFO_MESSAGE",0,ERR_TRADE_COMPLETE)
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).food==0,"duplicate confirmation cannot create negative requests")
addon:GroupSupplyWhisper("!food","Rogue-Realm")
check(window.title.text=="Group Supplies (1)","supplied rogue reappears after asking for another stack")
addon:GroupSupplyWhisper("!water 20","Rogue-WrongRealm")
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).water==0,"wrong realm cannot impersonate a roster recipient")
local realmName=UnitName
UnitName=function(unit) local name=realmName(unit); return name end
GetNormalizedRealmName=function() return "Realm" end
clock=clock+11
addon:GroupSupplyWhisper("!water 20","Rogue-Realm")
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).water==20,"same-realm whispers match when UnitName omits the realm")
UnitName=realmName
window.GetLeft=function() return 400 end; window.GetTop=function() return 700 end
window.collapse.scripts.OnClick()
check(window.height==30 and window.width==220 and not window.body:IsShown() and window.collapse.text=="+","collapse keeps only a short movable header")
check(addon.db.groupSupplies.collapsed and addon.db.groupSupplies.point=="TOPLEFT" and addon.db.groupSupplies.y==700,"collapse persists its state and anchors the title in place")
addon:UpdateGroupSupplies()
check(window.height==30 and not window.body:IsShown(),"periodic refresh preserves minimized state")
check(window.collapse:GetFrameLevel()>window.header:GetFrameLevel() and window.header.width<window.width-74,"minimize control is above and outside the title drag region")
window.collapse.scripts.OnClick()
check(window.body:IsShown() and window.height>30 and window.width==340,"expand restores the compact list")
window.GetLeft,window.GetTop=nil,nil
window.close.scripts.OnClick()
check(not window:IsShown(),"close dismisses the group window")
addon:UpdateGroupSupplies()
check(not window:IsShown(),"periodic refresh does not undo the user's dismissal")
addon:HandleCommand("supplies")
check(window:IsShown(),"supplies command reopens a dismissed window")
roster[1].offline=true; addon:UpdateGroupSupplies()
check(addon.character.supplyRequests["guid-Rogue"].water==20,"offline members retain their outstanding requests")
roster[1].offline=false
combat=true
addon:GroupSupplyWhisper("!water 40","Priest-Realm")
check(addon.groupSuppliesPending and addon:GetGroupSupplyRequest(priest).water==40,"combat whisper queues request without mutating protected UI")
addon:SetGroupSupplyAmount(priest,"water",0)
check(addon:GetGroupSupplyRequest(priest).water==40,"manual row edits are blocked in combat")
combat=false; fire("PLAYER_REGEN_ENABLED")
check(not addon.groupSuppliesPending,"queued group UI refreshes after combat")
roster={}; addon:UpdateGroupSupplies()
check(not window:IsShown() and not shortcut:IsShown() and next(addon.character.supplyRequests)==nil,"leaving the group hides the window and shortcut and clears session requests")
roster={{name="Rogue",class="ROGUE",level=60}}
addon.distribution["guid-Rogue"]={food=20,water=0,time=addon:EpochTime()}
addon:UpdateGroupSupplies()
check(not window:IsShown() and shortcut:IsShown(),"a new group requires opening the window again")
check(addon:GetGroupSupplyRequest(addon:FindGroupSupplyMember("Rogue")).food==20,"a new group session starts fresh independently of old delivery history")
addon.db,addon.distribution,known,inventory,addon.character=saved.db,saved.distribution,saved.known,saved.inventory,saved.character
IsInRaid,GetNumGroupMembers,GetNumSubgroupMembers=saved.raid,saved.total,saved.party
UnitName,UnitGUID,UnitClass,UnitLevel=saved.name,saved.guid,saved.class,saved.level
UnitIsConnected,UnitIsUnit,GetTime=saved.connected,saved.same,saved.time
GetRealmName,GetNormalizedRealmName=saved.realm,saved.normalizedRealm
CheckInteractDistance,InitiateTrade,UnitIsDeadOrGhost=saved.range,saved.initiate,saved.dead
addon.TradeOffer,addon.trade=saved.offer,saved.trade
addon.groupWhisperTimes={}; addon.groupSuppliesOpened=nil
addon:RefreshActions()
io.write("Passed ",checks," separate personal/group supplies checks.\n")
