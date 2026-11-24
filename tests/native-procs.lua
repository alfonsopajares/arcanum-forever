local checks=0
local function check(v,m) assert(v,m); checks=checks+1 end
local methods=getmetatable(UIParent).__index
local originalSlot=methods.AddAuraSlot
local originalGroup=methods.AddAuraGroup
local oldAuras,oldTime=C_UnitAuras,GetTime
local engineButtons,selfButtons,registered,removed={},{},{},{}
local init=false
local function bind(self,region,options)
    assert(init,"native display configuration escaped initialization")
    self.bindings=self.bindings or {}; self.bindings[#self.bindings+1]={region=region,options=options}
end
methods.SetIcon=bind; methods.SetDurationText=bind; methods.SetApplicationCount=bind; methods.SetApplicationBar=bind; methods.SetSpellName=bind
methods.AddAuraSlot=function(self,key,filter,options)
    self.auraSlots={[key]={filter=filter,options=options}}
    local display=CreateFrame("Frame",nil,self)
    init=true; options.initializeFrame(display); init=false
    display.IsShown=function() error("native visibility must not be inspected") end
    display.Show=function() error("addon cannot show native aura child") end
    display.Hide=function() error("addon cannot hide native aura child") end
    engineButtons[#engineButtons+1]={display=display,filter=filter,ids=options.candidateFilters.includeSpellIDs,container=self}
end
methods.AddAuraGroup=function(self,key,filter,options)
    self.auraGroups={[key]={filter=filter,options=options}}
    check(filter=="HARMFUL" and options.candidateFilters.isFromPlayerOrPlayerPet==true,
        "self-effects native group selects player-applied harmful effects")
    check(options.candidateFilters.includeSpellIDs==nil,"self-effects group never uses forbidden self-debuff spell-ID matching")
    check(options.candidateFilters.maxDuration==60,"native duration filter excludes long-running camp and rest effects")
    check(options.maxFrameCount==6 and options.layout.elementWidth==80,"self-effects group has bounded compact native layout")
    for i=1,2 do
        local display=CreateFrame("Frame",nil,self)
        init=true; options.initializeFrame(display); init=false
        display.IsShown=function() error("self-debuff visibility is protected") end
        display.Show=function() error("addon cannot show native self-debuff") end
        display.Hide=function() error("addon cannot hide native self-debuff") end
        selfButtons[#selfButtons+1]=display
    end
end
GetTime=function() return 100 end
C_UnitAuras={
    GetUnitAuraBySpellID=function() error("Auras cannot be accessed when secret while tainted") end,
    GetAuraDataBySpellName=function() error("restricted") end,
    GetAuraDataByIndex=function() error("restricted") end,
    AddAuraSound=function(trigger,info)
        assert(not combat,"sound registration deferred outside combat")
        check(trigger==0 and info.unitToken=="player" and info.throttleSeconds==1.5,"native gain sound uses client trigger and throttle")
        registered[#registered+1]=info; return #registered
    end,
    RemoveAuraSound=function(id) removed[#removed+1]=id end,
}
combat=false
addon.db.procs=addon:Clone(addon.defaults.procs)
addon.procTest=nil; addon.procNativeSounds={}
local frame=addon.procDisplay
for _,def in ipairs(addon.procTypes) do frame.native[def.key]=addon:CreateNativeProc(def) end
frame.selfEffects=addon:CreateNativeSelfProcs()
check(#engineButtons==6,"six helpful/player-owned enemy proc slots initialize despite restricted Lua aura reads")
check(engineButtons[2].ids[400589] and engineButtons[2].filter=="HELPFUL","Missile Barrage slot filters the actual buff ID natively")
check(frame.native.arcane==nil and frame.selfEffects~=nil,"Arcane Blast uses a generic self-effects group instead of a spell-ID slot")
check(engineButtons[5].container.nativeUnit=="target" and engineButtons[5].filter=="HARMFUL|PLAYER" and engineButtons[5].ids[12579],"Winter's Chill uses native target ownership and ID filters")
check(engineButtons[6].container.nativeUnit=="target" and engineButtons[6].filter=="HARMFUL|PLAYER" and engineButtons[6].ids[12654],"Ignite uses native target ownership and ID filters")
check(#selfButtons[1].bindings==4,"self-effect identity, icon, stack count, and timer all bind through native setters")
addon:ConfigureNativeProcSounds()
check(#registered==3 and addon.procNativeSounds.missiles,"native gain sounds registered for non-threshold player procs")
addon:ConfigureNativeProcSounds()
check(#registered==3 and #removed==0,"repeated settings application does not duplicate sounds")
combat=true; fire("UNIT_AURA","player")
check(frame.native.missiles:IsShown(),"combat parent stays available while engine owns protected Missile Barrage visibility")
check(not frame.cards.missiles:IsShown(),"legacy card cannot duplicate native combat card")
check(frame.selfEffects:IsShown(),"self-effects parent stays available with every Lua aura read blocked")
selfButtons[1].shown=true; selfButtons[2].shown=true
frame.scripts.OnUpdate(frame,.2)
check(selfButtons[1].shown and selfButtons[2].shown,"native engine can show multiple self-effects without addon visibility inspection")
selfButtons[1].shown=false; frame.scripts.OnUpdate(frame,.2)
check(not selfButtons[1].shown and selfButtons[2].shown,"engine consumption of one self-effect preserves another")
addon.db.showIgnite=false; addon:UpdateProcDisplay(false)
check(not frame.native.ignite:IsShown(),"existing Ignite visibility option also hides its native combat slot")
addon.db.showIgnite=true
addon.db.procs.effects.arcane.enabled=false; addon:UpdateProcDisplay(false)
check(not frame.selfEffects:IsShown(),"Arcane Blast effect switch hides the entire self-effects row")
addon.db.procs.effects.arcane.enabled=true; addon:UpdateProcDisplay(false)
check(frame.native.missiles.point[2]~=frame.native.clearcasting.point[2],"native slots have stable distinct positions without inspecting aura visibility")
local index=#engineButtons
-- The engine toggles the native child directly; the addon must not participate.
engineButtons[2].display.shown=true
frame.scripts.OnUpdate(frame,.2)
check(engineButtons[2].display.shown==true,"ticker does not hide a restricted active proc")
engineButtons[2].display.shown=false
frame.scripts.OnUpdate(frame,.2)
check(engineButtons[2].display.shown==false,"engine can remove a consumed proc while still in combat")
combat=false; addon:TestProc("all")
check(not frame.native.missiles:IsShown() and frame.cards.missiles:IsShown(),"preview uses simulated cards without native duplicates")
check(not frame.selfEffects:IsShown() and frame.selfPreview:IsShown() and frame.selfPreview.regions.count.text=="4",
    "preview uses matching compact Arcane Blast icon with simulated stack count")
check(not frame.cards.arcane:IsShown(),"compact self-effect preview does not duplicate the old Arcane Blast card")
check(#removed==3,"preview unregisters real proc sounds")
addon:HandleCommand("procs test arcane")
check(frame.selfPreview:IsShown() and frame.selfPreview.regions.name.text=="Arcane Blast" and not frame.cards.missiles:IsShown(),
    "Arcane-only test needs no learned spell and displays the new style")
addon:StopProcTest()
check(addon.procNativeSounds.missiles~=nil,"leaving preview restores native sounds")
check(frame.selfEffects:IsShown() and not frame.selfPreview:IsShown(),"leaving preview restores native self-effects without simulated duplicates")
addon.db.procs.effects.missiles.sound=false; addon:ApplyProcSettings()
check(addon.procNativeSounds.missiles==nil,"per-proc sound off removes native registration")
addon.db.procs.effects.missiles.enabled=false; combat=true; addon:UpdateProcDisplay(true)
check(not frame.native.missiles:IsShown(),"disabled effect hides native parent during combat")
combat=false; addon.db.procs.sound=false; addon:ApplyProcSettings()
check(next(addon.procNativeSounds)==nil,"master sound off removes all native registrations")
methods.AddAuraSlot=originalSlot
methods.AddAuraGroup=originalGroup
methods.SetIcon=nil; methods.SetDurationText=nil; methods.SetApplicationCount=nil; methods.SetApplicationBar=nil; methods.SetSpellName=nil
for _,holder in pairs(frame.native) do holder:Hide() end
frame.selfEffects:Hide(); frame.selfEffects=nil; frame.selfPreview:Hide()
frame.native={}; addon.procNativeSounds={}
C_UnitAuras,GetTime=oldAuras,oldTime
io.write("Passed ",checks," native proc initialization, restricted combat, sound, and preview checks.\n")
