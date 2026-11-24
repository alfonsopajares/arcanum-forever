local _, addon = ...

-- Each mage advertises coverage and cumulative, confirmed deliveries per recipient.
-- Replaying a snapshot after a reload or a missed packet only applies the difference.
local prefix = "ArcanumSupply1"
local automatic = "12345678"

local function channel(self)
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and self:Readable(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then return "INSTANCE_CHAT" end
    if IsInRaid and self:Readable(IsInRaid()) then return "RAID" end
    if GetNumSubgroupMembers and (self:Readable(GetNumSubgroupMembers()) or 0)>0 then return "PARTY" end
end

function addon:RegisterSupplyProtocol()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage) then return end
    local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,prefix)
    local codes=Enum and Enum.RegisterAddonMessagePrefixResult
    self.supplyProtocol=ok and result~=false and (result==true or not codes or result==codes.Success or result==codes.DuplicatePrefix)
end

function addon:SupplyCoverage()
    local scope=self.character.supplyScope or "all"
    if scope=="all" then return automatic end
    if scope=="custom" then return "0" end
    if scope=="mine" then
        if IsInRaid and self:Readable(IsInRaid()) and UnitInRaid and GetRaidRosterInfo then
            local index=self:Readable(UnitInRaid("player"))
            local subgroup=index and self:Readable(select(3,GetRaidRosterInfo(index)))
            return tostring(subgroup or 0)
        end
        return "1"
    end
    return scope
end

local function includes(mask,subgroup)
    return mask and mask:find(tostring(subgroup or 1),1,true)~=nil
end

function addon:SupplyAssignment(member)
    local request=self:GetGroupSupplyRequest(member)
    if not request then return end
    local order=request.order
    if order and order.mode=="D" then return "Declined" end
    if order and order.mode=="E" then return "Handled elsewhere" end
    local mine=self:SupplyCoverage()
    local localKey=UnitGUID and self:Readable(UnitGUID("player")) or self.characterKey
    if not (self.db.groupSupplies.coordinate and next(self.supplyPeers or {})) then
        if (order and order.mode=="C" and order.author==localKey) or includes(mine,member.subgroup) then return end
        return "Outside coverage"
    end
    local candidates={}
    local function candidate(key,name,coverage)
        local claim=order and order.mode=="C" and order.author==key or false
        if claim or includes(coverage,member.subgroup) then
            candidates[#candidates+1]={key=key,name=name,claim=claim,
                specific=coverage~=automatic}
        end
    end
    candidate(localKey,nil,mine)
    if self.db.groupSupplies.coordinate then
        for key,peer in pairs(self.supplyPeers or {}) do
            if member.key==key and not (order and order.mode=="C") then return "Preparing own supplies" end
            candidate(key,peer.name,peer.coverage)
        end
    end
    if #candidates==0 then return "Outside coverage" end
    -- Deterministic across clients, including when two mages claim at once.
    table.sort(candidates,function(a,b)
        if a.claim~=b.claim then return a.claim end
        if a.specific~=b.specific then return a.specific end
        return a.key<b.key
    end)
    local count=1
    while candidates[count+1] and candidates[count+1].claim==candidates[1].claim
        and candidates[count+1].specific==candidates[1].specific do count=count+1 end
    local hash=0
    for i=1,#member.key do hash=(hash*31+member.key:byte(i))%65521 end
    local owner=candidates[1+hash%count]
    if owner.name then return "With "..owner.name end
end

function addon:QueueSupplyState(key)
    self.supplyOutbox=self.supplyOutbox or {}
    self.supplyOutbox[key]=true
end

function addon:MarkSupplyState(member)
    local request=self:GetGroupSupplyRequest(member)
    self.character.supplySerial=(self.character.supplySerial or 0)+1
    request.revision=self.character.supplySerial
    request.generation=request.generation or request.revision
    self:QueueSupplyState(member.key)
end

-- Edits describe a total order, including deliveries already credited at edit time.
-- This makes a fresh whisper for 20 mean 20 more, even if an old delivery is replayed.
function addon:RecordSupplyOrder(member,mode)
    local r=self:GetGroupSupplyRequest(member)
    local author=UnitGUID and self:Readable(UnitGUID("player")) or self.characterKey
    local revision=(r.order and r.order.clock or 0)+1
    r.order={clock=revision,author=author,mode=mode,food=r.food+(r.creditedFood or 0),water=r.water+(r.creditedWater or 0)}
    self:MarkSupplyState(member)
end

local function send(self,route,payload)
    if self.supplyRetryAt and GetTime()<self.supplyRetryAt then return false end
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,prefix,payload,route)
    local codes=Enum and Enum.SendAddonMessageResult
    local success=ok and result~=false and (result==true or not codes or result==codes.Success)
    self.supplyRetryAt=not success and GetTime()+5 or nil
    return success
end

local function sendRequest(self,route,key,r)
    local data=string.format("S %s %d %d %d %d",key,r.generation,r.revision,r.sentFood or 0,r.sentWater or 0)
    if r.order then
        local o=r.order
        data=data..string.format(" %d:%s:%s:%d:%d",o.clock,o.author,o.mode,o.food,o.water)
    end
    return send(self,route,data)
end

function addon:BroadcastSupplyDelivery(member)
    local route=channel(self)
    if self.supplyProtocol and self.db.groupSupplies.coordinate and route and not InCombatLockdown() then
        if sendRequest(self,route,member.key,self:GetGroupSupplyRequest(member)) then self.supplyOutbox[member.key]=nil end
    end
end

function addon:TickSupplyProtocol()
    if not (self.supplyProtocol and self.character) then return end
    local route=channel(self)
    if not route or not self.db.groupSupplies.coordinate then
        if route and self.supplyRoute then send(self,route,"B") end
        if self.supplyRoute then self.groupSupplyTradePending=true end
        self.supplyRoute,self.supplyPeers,self.supplyHelloAt,self.supplyOutbox=nil,nil,nil,nil
        return
    end
    if InCombatLockdown() then return end
    local now=GetTime()
    self.supplyPeers=self.supplyPeers or {}
    local online={}
    if next(self.supplyPeers) then
        for _,member in ipairs(self:GroupMembers()) do online[member.key]=true end
    end
    for key,peer in pairs(self.supplyPeers) do
        if now-peer.seen>65 or not online[key] then
            self.supplyPeers[key]=nil
            self.groupSupplyTradePending=true
        end
    end
    local coverage=self:SupplyCoverage()
    if route~=self.supplyRoute or self.lastSupplyCoverage~=coverage or now>=(self.supplyHelloAt or 0) then
        local hello=route~=self.supplyRoute and "J " or "H "
        if not send(self,route,hello..coverage) then return end
        self.supplyRoute,self.lastSupplyCoverage,self.supplyHelloAt=route,coverage,now+20
    end
    if not next(self.supplyPeers) then return end
    if now>=(self.supplySnapshotAt or 0) then
        for key,request in pairs(self.character.supplyRequests or {}) do
            if request.revision then self:QueueSupplyState(key) end
            -- A later arrival can catch up even if the delivering mage has left.
            for origin,record in pairs(request.received or {}) do
                if record.packet and not self.supplyPeers[origin] then
                    self.supplyOutbox=self.supplyOutbox or {}
                    self.supplyOutbox[key.." "..origin]={recipient=key,source=origin}
                end
            end
        end
        self.supplySnapshotAt=now+60
    end
    -- Bound traffic even when a full raid roster is replayed to a new mage.
    for i=1,3 do
        local key,entry=next(self.supplyOutbox or {})
        if not key then break end
        local requests=self.character.supplyRequests or {}
        if type(entry)=="table" then
            local r=requests[entry.recipient]
            local record=r and r.received and r.received[entry.source]
            if record and record.packet and not self.supplyPeers[entry.source] then
                if not send(self,route,"R "..entry.source.." "..record.packet) then break end
            end
        elseif requests[key] and requests[key].revision then
            if not sendRequest(self,route,key,requests[key]) then break end
        end
        self.supplyOutbox[key]=nil
    end
end

function addon:ReceiveSupplyMessage(tag,message,route,sender)
    if not self.supplyProtocol or not self.db.groupSupplies.coordinate or self:Readable(tag)~=prefix then return end
    route,message,sender=self:Readable(route),self:Readable(message),self:Readable(sender)
    if not route or route~=channel(self) or type(message)~="string" or #message>200 or type(sender)~="string" then return end
    local mage=self:FindGroupSupplyMember(sender)
    if not mage or mage.class~="MAGE" then return end
    self.supplyPeers=self.supplyPeers or {}
    local peer=self.supplyPeers[mage.key]
    local hello,mask=message:match("^([HJ]) ([0-8]+)$")
    if mask and #mask<=8 then
        if not peer then
            peer={name=mage.name}
            self.supplyPeers[mage.key]=peer
        end
        if not peer.seen or hello=="J" and GetTime()>=(peer.nextReply or 0) then
            self.supplyHelloAt,self.supplySnapshotAt=0,0
            peer.nextReply=GetTime()+2
        end
        peer.coverage,peer.seen=mask,GetTime()
    elseif not peer then return
    elseif message=="B" then self.supplyPeers[mage.key]=nil
    else
        local origin=mage.key
        if message:sub(1,2)=="R " then
            origin,message=message:match("^R ([%w%-]+) (S .+)$")
            if not origin or origin==self.characterKey or self.supplyPeers[origin] then return end
        end
        local key,generation,revision,food,water,extra=message:match("^S ([%w%-]+) (%d+) (%d+) (%d+) (%d+)(.*)$")
        if not key then return end
        generation,revision,food,water=tonumber(generation),tonumber(revision),tonumber(food),tonumber(water)
        if generation<1 or revision<generation or revision>2^52 or food>1000000 or water>1000000 then return end
        local member=self:FindGroupSupplyMember(nil,key)
        if not member then return end
        local request=self:GetGroupSupplyRequest(member)
        request.received=request.received or {}
        local old=request.received[origin]
        if old and (generation<old.generation or revision<=old.revision) then return end
        local order
        if extra~="" then
            local clock,author,mode,targetFood,targetWater=extra:match("^ (%d+):([%w%-]+):([ACDE]):(%d+):(%d+)$")
            if not clock then return end
            clock,targetFood,targetWater=tonumber(clock),tonumber(targetFood),tonumber(targetWater)
            if clock<1 or clock>2^52 or targetFood>1000000 or targetWater>1000000 then return end
            local current=request.order
            if not current or clock>current.clock or clock==current.clock and author>current.author then
                order={clock=clock,author=author,mode=mode,food=targetFood,water=targetWater}
            end
        end
        local previousFood,previousWater=0,0
        if old and generation==old.generation then previousFood,previousWater=old.food,old.water end
        if food<previousFood or water<previousWater then return end
        local deltaFood,deltaWater=food-previousFood,water-previousWater
        request.creditedFood=(request.creditedFood or 0)+deltaFood
        request.creditedWater=(request.creditedWater or 0)+deltaWater
        request.food=math.max(0,request.food-deltaFood)
        request.water=math.max(0,request.water-deltaWater)
        request.received[origin]={generation=generation,revision=revision,food=food,water=water,packet=message}
        if order then
            request.order=order
            request.food=math.max(0,order.food-request.creditedFood)
            request.water=math.max(0,order.water-request.creditedWater)
            self:MarkSupplyState(member)
        end
        peer.seen=GetTime()
    end
    -- The existing supplies refresh coalesces messages and defers protected UI in combat.
    self.groupSupplyTradePending=true
end
