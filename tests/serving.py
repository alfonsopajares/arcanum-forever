"""Run independent mage clients against one simulated raid and addon channel."""


def check_coordination(create_client):
    clients = {}
    packets = []

    def join(name):
        client = create_client()
        client.globals().player = name
        client.globals().send_packet = lambda *args: packets.append((name, *args))
        client.execute("""
            names={"Alba","Beryl","Rogue","Warrior"}
            local function index(unit)
                if unit=="player" then
                    for i,name in ipairs(names) do if name==player then return i end end
                end
                return tonumber(unit:match("^raid(%d+)$"))
            end
            function UnitName(unit) return names[index(unit)],"Realm" end
            function UnitGUID(unit) local n=UnitName(unit); return n and "guid-"..n end
            function UnitClass(unit) local i=index(unit); return "class",i==3 and "ROGUE" or i==4 and "WARRIOR" or "MAGE" end
            function UnitIsUnit(a,b) return UnitGUID(a)==UnitGUID(b) end
            function UnitLevel() return 60 end
            function IsInRaid() return true end
            function GetNumGroupMembers() return #names end
            function UnitInRaid(unit) return index(unit) end
            function GetRaidRosterInfo(i) return names[i],0,i%2==0 and 2 or 1 end
            clock=100; function GetTime() return clock end
            function CheckInteractDistance(unit) return unit=="raid4" end
            Enum.SendAddonMessageResult={Success=0}
            Enum.RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1}
            C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,
                SendAddonMessage=function(...) send_packet(...); return 0 end}
            known[587],known[5504]=true,true
            free=1; partial=nil
            C_Container.GetContainerNumFreeSlots=function(bag) return bag==0 and free or 0,0 end
            C_Container.GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end
            C_Container.GetContainerItemInfo=function() return partial end
            if player=="Cora" then names[5]=player end
            fire("ADDON_LOADED","Arcanum")
            function member(name) return addon:FindGroupSupplyMember(name) end
            function request(name) return addon:GetGroupSupplyRequest(member(name)) end
            function owner(name) return addon:SupplyAssignment(member(name)) end
        """)
        clients[name] = client
        return client

    def exchange():
        for _ in range(3):
            for client in clients.values():
                client.execute("clock=clock+1; addon:TickSupplyProtocol()")
            while packets:
                sender, prefix, message, channel = packets.pop(0)
                for client in clients.values():
                    client.globals().fire("CHAT_MSG_ADDON", prefix, message, channel, sender+"-Realm")

    a, b = join("Alba"), join("Beryl")
    exchange()
    for name in ("Rogue", "Warrior"):
        assert (a.eval("owner")(name) is None) != (b.eval("owner")(name) is None)
    a.execute('addon.character.supplyScope="mine"')
    b.execute('addon.character.supplyScope="2"')
    exchange()
    assert a.eval('owner("Rogue")==nil and owner("Warrior")=="With Beryl"')
    assert b.eval('owner("Warrior")==nil and owner("Rogue")=="With Alba"')
    a.execute('request("Warrior").food=40')
    b.execute('addon:GroupSupplyDelivered({name="Warrior",key="guid-Warrior",food=20,water=0})')
    exchange()
    assert a.eval('request("Warrior").food==0')
    a.execute('addon:SetSupplyDisposition(member("Rogue"),"elsewhere")')
    exchange()
    assert b.eval('owner("Rogue")=="Handled elsewhere"')
    b.execute('addon:RestoreGroupSupply(member("Rogue"))')
    exchange()
    assert a.eval('owner("Rogue")=="With Beryl"')
    b.execute('addon:GroupSupplyDelivered({name="Rogue",key="guid-Rogue",food=8,water=0})')
    delivered = packets[-1]
    exchange()
    assert a.eval('request("Rogue").food==12')
    packets.append(delivered)
    exchange()
    assert a.eval('request("Rogue").food==12')
    a.execute('combat=true; addon:GroupSupplyWhisper("!food 21","Rogue-Realm"); combat=false')
    exchange()
    assert b.eval('request("Rogue").food==21 and owner("Rogue")=="With Alba"')
    b.execute('addon:GroupSupplyDelivered({name="Rogue",key="guid-Rogue",food=21,water=0})')
    exchange()
    assert a.eval('request("Rogue").food==0')
    a.execute('addon.supplyPeers=nil; addon.supplyHelloAt=0; addon.supplyRoute=nil')
    exchange()
    assert a.eval('request("Rogue").food==0')
    a.execute('addon:RestoreGroupSupply(member("Rogue")); addon:SetSupplyDisposition(member("Rogue"),"declined")')
    exchange()
    assert b.eval('owner("Rogue")=="Declined"')
    b.execute('addon.db.groupSupplies.coordinate=false')
    exchange()
    assert a.eval('next(addon.supplyPeers)==nil')
    a.execute("""
        addon:ReceiveSupplyMessage("ArcanumSupply1","H 1","RAID","Stranger-Realm")
        addon:ReceiveSupplyMessage("ArcanumSupply1","H 1","GUILD","Beryl-Realm")
        addon:ReceiveSupplyMessage("ArcanumSupply1","H 1","RAID","Warrior-Realm")
        assert(next(addon.supplyPeers)==nil)
        addon.character.supplyScope="custom"
        addon:RestoreGroupSupply(member("Warrior"))
        addon.db.preparation.profiles.solo={food=20,water=20}
        inventory={[5349]=40,[5350]=20}
        addon:OpenGroupSupplies()
        assert(addon.groupSuppliesWindow.need.text=="Can serve 1 of 1 waiting")
        addon:RestoreGroupSupply(member("Rogue"))
        addon:UpdateGroupSupplies()
        assert(addon.groupSuppliesWindow.rows[1].member.name=="Warrior")
        assert(addon.groupSuppliesWindow.need.text=="Can serve 1 of 2 waiting")
        free=0; fire("BAG_UPDATE_DELAYED")
        assert(addon.groupSuppliesWindow.conjure:GetAttribute("spell1")==nil)
        assert(addon.groupSuppliesWindow.need.text:find("Bags full"))
        partial={itemID=5349,isLocked=false,stackCount=10}; fire("BAG_UPDATE_DELAYED")
        assert(addon.groupSuppliesWindow.conjure:GetAttribute("spell1")==587)
        partial=nil; free=1; fire("BAG_UPDATE_DELAYED")
        assert(addon.groupSuppliesWindow.conjure:GetAttribute("spell1")==587)
    """)
    a.execute('names[5]="Cora"; addon:UpdateGroupSupplies()')
    c = join("Cora")
    exchange()
    assert c.eval('request("Rogue").creditedFood==29 and request("Rogue").food==20')
    assert c.eval('owner("Rogue")=="With Alba"')
    print("Passed multi-client assignment, delivery, refill, late-join, reserve, and bag capacity scenarios.")
