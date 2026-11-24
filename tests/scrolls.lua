local checks = 0
local function check(value, message) assert(value, message); checks=checks+1 end
local oldContainer, oldItem, oldTip, oldSkill = C_Container, C_Item, C_TooltipInfo, C_SkillInfo
local oldCursor, oldTargeting = GetCursorInfo, SpellIsTargeting
local rank, bonus, skillName, cursor = 10, 0, "Comprehension", nil
local bags = {[0]={
    {itemID=211780,stackCount=2,isLocked=false},
    {itemID=211780,stackCount=3,isLocked=false},
    {itemID=211784,stackCount=1,isLocked=false},
    {itemID=1180,stackCount=1,isLocked=false},
    {itemID=215257,stackCount=1,isLocked=false},
}}
local requirements = {[211780]=1,[211784]=15}
local red, missing, requested = false, false, 0
C_SkillInfo = {GetSkillLineInfoByID=function(id)
    assert(id==3012)
    return {name=skillName,rank=rank,tempPoints=bonus,modifier=0}
end}
C_Item = {
    GetItemInfoInstant=function(id) return id,nil,nil,nil,123,0,4 end,
    GetItemInfo=function(id) if not missing then return "Scroll "..id end end,
    RequestLoadItemDataByID=function() requested=requested+1 end,
}
C_Container = {
    GetContainerNumSlots=function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemInfo=function(bag,slot) return bags[bag] and bags[bag][slot] end,
}
C_TooltipInfo = {GetBagItem=function(bag,slot)
    local item=bags[bag][slot]
    local required=requirements[item.itemID]
    if missing then return nil end
    return {lines={
        {type=37,leftText="A Mage can decipher this with their Comprehension skill."},
        {type=required and 43 or 44,leftText=required and ("Requires "..skillName.." ("..required..")") or "Use: Comprehension (25)",
            leftColor=red and {r=1,g=0.1,b=0.1} or {r=1,g=1,b=1}},
    }}
end}
GetCursorInfo=function() return cursor end
SpellIsTargeting=function() return false end
combat=false; known[1296017]=true; addon.db.scrolls.enabled=true
addon.scrollDismissed=nil
addon:UpdateScrollWindow()
local frame=addon.scrollWindow
check(frame:IsShown(),"eligible scroll automatically reveals popup")
check(frame.rows[1].entry.count==5 and #frame.rows==2 and not frame.rows[2].enabled,"duplicates aggregate; higher skill scrolls are dimmed; translated/stat scrolls are omitted")
check(frame.rows[1]:GetAttribute("spell1")==1296017 and frame.rows[1]:GetAttribute("target-bag1")==0
    and frame.rows[1]:GetAttribute("target-slot1")==1,"native secure action casts Comprehend on actual bag slot")
frame.rows[1].scripts.PreClick(frame.rows[1])
check(frame.rows[1]:GetAttribute("type1")=="spell","valid click retains secure cast")
cursor="item"; frame.rows[1].scripts.PreClick(frame.rows[1])
check(frame.rows[1]:GetAttribute("type1")=="","held item cannot be accidentally used as the spell target")
cursor=nil
bags[0][1].itemID=1180; frame.rows[1].scripts.PreClick(frame.rows[1])
check(frame.rows[1]:GetAttribute("type1")=="","stale button never casts on replacement item")
addon:UpdateScrollWindow()
check(frame.rows[1]:GetAttribute("target-slot1")==2,"bag movement refreshes target slot")
bonus=5; addon.scrollEvents.scripts.OnEvent(nil,"SKILL_LINES_CHANGED")
check(frame.rows[2] and frame.rows[2].enabled,"temporary skill bonus admits newly eligible scroll")
bonus=0; addon:UpdateScrollWindow()
check(not frame.rows[2].enabled and frame.rows[2]:GetAttribute("type1")=="","losing skill removes stale secure action")
skillName="Compréhension"; addon:UpdateScrollWindow()
check(frame:IsShown(),"localized skill requirement matches localized skill name")
red=true; addon:UpdateScrollWindow()
check(not frame:IsShown(),"unmet red usage requirement suppresses popup")
red=false; known[1296017]=false; addon:UpdateScrollWindow()
check(not frame:IsShown(),"unlearned Comprehend never shows popup")
known[1296017]=true; addon:UpdateScrollWindow()
addon.scrollDismissed=addon.scrollSignature; addon:UpdateScrollWindow()
check(not frame:IsShown(),"dismissed inventory stays dismissed")
addon:HandleCommand("scrolls")
check(frame:IsShown(),"scroll command reopens eligible inventory")
addon.db.scrolls.enabled=false; addon:UpdateScrollWindow()
check(not frame:IsShown(),"popup option disables visibility")
addon.db.scrolls.enabled=true; addon:UpdateScrollWindow()
frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",123,-234)
frame.dragHandle.scripts.OnDragStop()
addon:UpdateScrollWindow()
check(addon.db.scrolls.x==123 and addon.db.scrolls.y==-234 and frame.point[4]==123,"drag position persists across refresh")
addon:HandleCommand("scrolls reset")
check(addon.db.scrolls.x==addon.defaults.scrolls.x,"position reset restores defaults")
local previous=frame.rows[1]:GetAttribute("target-slot1")
combat=true; bags[0][2].itemID=1180
addon:UpdateScrollWindow()
check(frame.rows[1]:GetAttribute("target-slot1")==previous,"combat bag changes never mutate secure attributes")
check(frame.stateDrivers.combat=="[combat] 1; 0","native state driver hides window in combat")
combat=false; addon:UpdateScrollWindow()
check(not frame:IsShown(),"post-combat refresh hides window without eligible scrolls")
bags[0][2].itemID=211780; bags[0][2].isLocked=true; addon:UpdateScrollWindow()
check(frame:IsShown() and not frame.rows[1].enabled,"locked scroll is listed without a clickable stale target")
bags[0][2].isLocked=false; addon:UpdateScrollWindow()
check(frame.rows[1].enabled,"item unlock restores click action")
missing=true; addon.scrollRequestedItems={}; addon:UpdateScrollWindow()
local requests=requested
addon.scrollEvents.scripts.OnEvent(nil,"ITEM_DATA_LOAD_RESULT",211780)
check(not frame:IsShown() and requested==requests,"uncached data stays hidden and load events cannot trigger a request loop")
missing=false; addon:UpdateScrollWindow()
local scans, tooltipReads = 0, 0
local originalCandidates, originalTooltip = addon.ComprehendCandidates, C_TooltipInfo.GetBagItem
addon.ComprehendCandidates=function(self) scans=scans+1; return originalCandidates(self) end
C_TooltipInfo.GetBagItem=function(...) tooltipReads=tooltipReads+1; return originalTooltip(...) end
local events=addon.scrollEvents
for index=1,100 do events.scripts.OnEvent(nil,"ITEM_LOCK_CHANGED",0,1) end
events.scripts.OnEvent(nil,"BAG_UPDATE_DELAYED")
check(scans==0 and tooltipReads==0,"sort event burst performs no synchronous scans or tooltip queries")
events.scripts.OnUpdate(events,0.15)
events.scripts.OnEvent(nil,"ITEM_LOCK_CHANGED",0,2)
events.scripts.OnUpdate(events,0.1)
check(scans==0,"new sort activity extends the quiet period")
-- Move the eligible scroll while a refresh is pending. Existing click safety
-- must reject its old slot, then the settled list must use the new location.
bags[0][2],bags[0][4]=bags[0][4],bags[0][2]
frame.rows[1].scripts.PreClick(frame.rows[1])
check(frame.rows[1]:GetAttribute("type1")=="","pending refresh cannot cast on a stale slot during sorting")
tooltipReads=0
events.scripts.OnUpdate(events,0.11)
check(scans==1 and tooltipReads==5,"settled sort performs exactly one scan instead of one per lock event")
check(frame.rows[1]:GetAttribute("target-slot1")==4,"settled refresh follows the scroll's new bag slot")
check(events.scripts.OnUpdate==nil,"refresh ticker stops after pending work completes")
events.scripts.OnEvent(nil,"BAG_UPDATE_DELAYED")
addon.db.scrolls.enabled=false; addon:UpdateScrollWindow()
check(events.scripts.OnUpdate==nil and scans==1,"disabling popup cancels pending work without scanning")
for index=1,100 do events.scripts.OnEvent(nil,"ITEM_LOCK_CHANGED",0,1) end
check(events.scripts.OnUpdate==nil and scans==1,"disabled popup never schedules sort work")
addon.db.scrolls.enabled=true
events.scripts.OnEvent(nil,"BAG_UPDATE_DELAYED")
combat=true; events.scripts.OnUpdate(events,0.21)
check(scans==1 and events.scripts.OnUpdate==nil,"combat starting before pending refresh prevents secure updates and scans")
events.scripts.OnEvent(nil,"ITEM_LOCK_CHANGED",0,1)
check(events.scripts.OnUpdate==nil,"combat bag events do not schedule scans")
combat=false; events.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
check(scans==2 and frame.rows[1].enabled,"combat end immediately restores current inventory actions")
addon.ComprehendCandidates=originalCandidates; C_TooltipInfo.GetBagItem=originalTooltip
C_Container,C_Item,C_TooltipInfo,C_SkillInfo=oldContainer,oldItem,oldTip,oldSkill
GetCursorInfo,SpellIsTargeting=oldCursor,oldTargeting
io.write("Passed ",checks," scroll eligibility, secure bag targeting, position, cache, and combat checks.\n")
