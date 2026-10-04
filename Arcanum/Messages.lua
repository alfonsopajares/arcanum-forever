local _, addon = ...

-- Original mage speeches. Messages are independent from reminder settings.
addon.messageEvents = {{"portal","Portals"}, {"polymorph","Polymorph"}, {"evocation","Evocation"}, {"trade","Completed trades"}}
local speeches = {
    portal = {
        useful = {start={"Opening a portal to {destination}."}, success={"Portal to {destination} is ready."}},
        funny = {
            start={"Opening a portal to {destination}. Please keep all limbs inside the magic.",
                "One shortcut to {destination}, coming right up. Geography is a suggestion.",
                "Calculating the route to {destination}. Roads are for people without robes.",
                "Opening a portal to {destination}. Please stand clear of the suspicious sparkles.",
                "Bending space toward {destination}. My map has filed a formal complaint."},
            success={"Portal to {destination} is ready. Return tickets sold separately.",
                "Next stop: {destination}. Any unexpected sheep are complimentary.",
                "Your portal to {destination} is ready. Please leave a five-star incantation.",
                "Portal to {destination}: zero walking, excessive glowing. Enjoy your trip.",
                "The portal to {destination} is open. Baggage may experience brief existential confusion."}},
    },
    polymorph = {
        useful = {start={"Polymorphing {target}. Please leave it alone."}, success={"{target} is polymorphed. Please don't break it."}},
        funny = {
            start={"{target}, your livestock application is being processed.",
                "Preparing a new career for {target}. Experience in grazing preferred.",
                "{target}, please hold still for your complimentary personality adjustment.",
                "Casting Polymorph on {target}. The farm has a vacancy.",
                "{target}, this meeting could have been a sheep."},
            success={"{target} has been reassigned to livestock. Please don't interfere.",
                "{target}: fewer responsibilities, considerably more wool.",
                "Please do not pet or attack {target}. This sheep is on the clock.",
                "{target} is taking a short grazing break. Please respect the work-life balance.",
                "{target}'s combat privileges have been replaced with a grass subscription."}},
    },
    evocation = {
        useful = {start={"Evocating. Recharging mana."}, success={"Evocation completed."}},
        funny = {
            start={"Please hold. Recharging my questionable decisions.",
                "Temporarily out of magic. Have you tried turning the mage off and on?",
                "Evocating. Please do not unplug the wizard.",
                "Running low on sparkles. Connecting to the arcane charger.",
                "Mana maintenance in progress. Complaints will be answered after the glowing stops."},
            success={"Mana restored. Good judgment still loading.",
                "Recharge complete. Back to making expensive sparkles.",
                "The wizard is charged. Please disconnect before storing.",
                "Arcane battery replenished. Sensible decisions remain optional.",
                "Evocation complete. I can afford to be dramatic again."}},
    },
    trade = {
        useful = {success={"Delivered {food} food and {water} water to {target}."}},
        funny = {success={"Refreshments delivered to {target}. Tips accepted in compliments.",
            "{target}, your order is ready: {food} food, {water} water, and absolutely no nutritional guarantees.",
            "{target}, thank you for choosing arcane catering. Please return any uneaten sparkles.",
            "Delivered {food} food and {water} water to {target}. Freshly conjured, vaguely edible.",
            "{target}'s refreshments are served. Today's secret ingredient is mana."}},
    },
}

function addon:MessageContext(id, target)
    id = self:Readable(id)
    if type(id) ~= "number" then return end
    for _, definition in ipairs(self.spells) do
        for _, rank in ipairs(definition.ranks) do
            if rank == id and self:KnownSpell(id) then
                local event = definition.category == "portals" and "portal"
                    or (definition.ranks[1] == 118 or definition.ranks[1] == 28271 or definition.ranks[1] == 28272) and "polymorph"
                    or id == 12051 and "evocation"
                if event then
                    local name = self:SpellInfo(id) or "unknown destination"
                    return event, {target=self:Readable(target) or "my target", destination=name:match(":%s*(.+)$") or name}
                end
            end
        end
    end
end

function addon:MessageText(event, phase, context, preview)
    local option = self.db.messages.events[event]
    if not option then return end
    local list = speeches[event] and speeches[event][option.style == "funny" and "funny" or "useful"]
    list = list and (list[phase] or list.success)
    local value
    if option.style == "custom" and option.custom ~= "" then value = option.custom
    elseif list then
        local index = 1
        if option.style == "funny" and preview then
            -- Preview has its own cursor: browse every line without consuming
            -- the live queue or changing its shuffle's random sequence.
            self.previewRotations = self.previewRotations or {}
            local key = event .. ":" .. phase
            index = (self.previewRotations[key] or 0) % #list + 1
            self.previewRotations[key] = index
        elseif option.style == "funny" then
            self.speechRotations = self.speechRotations or {}
            local key = event .. ":" .. phase
            local rotation = self.speechRotations[key] or {queue={}}
            self.speechRotations[key] = rotation
            if #rotation.queue == 0 then
                for i = 1, #list do rotation.queue[i] = i end
                for i = #list, 2, -1 do
                    local j = math.random(i)
                    rotation.queue[i], rotation.queue[j] = rotation.queue[j], rotation.queue[i]
                end
                if #list > 1 and rotation.queue[1] == rotation.last then
                    rotation.queue[1], rotation.queue[2] = rotation.queue[2], rotation.queue[1]
                end
            end
            index = table.remove(rotation.queue, 1)
            rotation.last = index
        end
        value = list[index]
    end
    if not value then return end
    local tokens = {player=self:Readable(UnitName("player")) or "Mage", target=context.target or "my target",
        destination=context.destination or "Stormwind", food=context.food or 0, water=context.water or 0,
        phase=phase == "start" and "casting" or "completed"}
    return (value:gsub("{([%a]+)}", function(key) return tostring(tokens[key] or ("{" .. key .. "}")) end))
end

function addon:SendMageMessage(event, phase, context)
    local settings, option = self.db.messages, self.db.messages.events[event]
    if not settings.enabled or not option or not option.enabled or
        (option.timing ~= phase and option.timing ~= "both") then return end
    local stamp = GetTime()
    self.messageTimes = self.messageTimes or {}
    -- Separate start/completion throttles allow a two-part speech to finish.
    local key = event .. ":" .. phase
    if self.messageTimes[key] and stamp - self.messageTimes[key] < settings.delay then return end
    local value = self:MessageText(event, phase, context or {})
    if not value then return end
    self.messageTimes[key] = stamp
    local channel
    if settings.channel == "group" then
        if LE_PARTY_CATEGORY_INSTANCE and IsInGroup and self:Readable(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) == true then channel = "INSTANCE_CHAT"
        elseif IsInRaid and self:Readable(IsInRaid()) == true then channel = "RAID"
        elseif #self:GroupMembers() > 0 then channel = "PARTY" end
    end
    local count = 0
    for line in value:gmatch("[^\r\n]+") do
        count = count + 1
        if count > 3 then break end
        -- Never pass oversized or markup-bearing user text to chat.
        line = line:gsub("|", "")
        if #line <= 255 then
            local sent = channel and SendChatMessage and pcall(SendChatMessage, line, channel)
            if not sent then print("|cff66bbffArcanum:|r " .. line) end
        end
    end
end

function addon:SpeechEvent(event, unit, second, third, fourth)
    if self:Readable(unit) ~= "player" then return end
    self.pendingSpeeches = self.pendingSpeeches or {}
    if event == "UNIT_SPELLCAST_SENT" then
        local guid = self:Readable(third)
        local kind, context = self:MessageContext(fourth, second)
        if guid and kind then
            local n = 0; for _ in pairs(self.pendingSpeeches) do n = n + 1 end
            if n > 20 then self.pendingSpeeches = {} end
            self.pendingSpeeches[guid] = {kind=kind, context=context}
        end
        return
    end
    local guid, id = self:Readable(second), self:Readable(third)
    if not guid then return end
    local speech = self.pendingSpeeches[guid]
    if not speech then
        local kind, context = self:MessageContext(id)
        if kind then speech = {kind=kind, context=context} end
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if speech then
            if speech.kind == "evocation" and UnitChannelInfo then
                local finish = self:Readable(select(5, UnitChannelInfo("player")))
                if type(finish) == "number" then speech.ends = finish / 1000 end
                self.pendingSpeeches[guid] = speech
            end
            self:SendMageMessage(speech.kind, "start", speech.context)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Evocation succeeds when the channel starts; announce completion only
        -- on CHANNEL_STOP and only if it was not interrupted.
        if speech and speech.kind == "evocation" then
            speech.channel = true; self.pendingSpeeches[guid] = speech
        else
            if speech then self:SendMageMessage(speech.kind, "success", speech.context) end
            self.pendingSpeeches[guid] = nil
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if speech and speech.channel and speech.ends and GetTime() >= speech.ends - 0.25 then self:SendMageMessage(speech.kind, "success", speech.context) end
        self.pendingSpeeches[guid] = nil
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        self.pendingSpeeches[guid] = nil
    end
end
