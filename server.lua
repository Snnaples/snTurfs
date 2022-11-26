--[[
                                                    _______          __            __   ___  
                                                |__   __|        / _|          /_ | / _ \ 
                                        ___ _ __ | |_   _ _ __| |_ ___  __   _| || | | |
                                        / __| '_ \| | | | | '__|  _/ __| \ \ / / || | | |
                                        \__ \ | | | | |_| | |  | | \__ \  \ V /| || |_| |
                                        |___/_| |_|_|\__,_|_|  |_| |___/   \_/ |_(_)___/ 
                                                  
                                                  
]]



do return (function ()

    
    
    local Tunnel <const> = module("vrp", "lib/Tunnel")
    local Proxy <const> = module("vrp", "lib/Proxy")
    
    local vRPclient <const> = Tunnel.getInterface('vRP', 'vRP')
    
    local clientRemoteTurfs <const> = Tunnel.getInterface('snTurfs','snTurfs')
    
    local vRP <const> = Proxy.getInterface'vRP';
    
    local remoteTurf = {}
    
    local internalTurfs = {}
    
    local internalAttackedTurfs = {}

    local internalWarHistory = {}

    local internalTaxes <const> = {}
    
    local playersAttackingFreeTurfs = {}
    
    local attackCooldowns = {}
    
    local turfNames = {}
    
    local factions = {}
    
    local internalScoreboard = {}
    
    local LATENT_PAYLOAD_BYTES <const> = TurfsConfig.latentEventPayloadInBytes

    local isPedInsideTurf;
    local getTurfIdFromPlayerCoords;

    local function adminException(id)
        for i = 1, #TurfsConfig.adminExceptions do 
            if TurfsConfig.adminExceptions[i] == id then return true end;
        end
        return false
    end

    if not TurfsConfig.squareTurfs then 

        isPedInsideTurf = function(player)
            local ped  = GetPlayerPed(player)
            local pCoords = GetEntityCoords(ped)
        
            for _,v in pairs(internalTurfs) do
                if #(pCoords - vector(v.x,v.y,v.z)) <= v.radius then 
                    return true 
                end
            end
            return false
        end
        getTurfIdFromPlayerCoords = function(player)
            if not isPedInsideTurf(player) then return -1 end;
            local pCoords = GetEntityCoords(GetPlayerPed(player))
        
            for _,turf in pairs(internalTurfs) do
                local turfVector = vec3(turf.x,turf.y,turf.z)
        
                if #(pCoords - turfVector) <= turf.radius then
                    return {value = turf.turfId}, turfVector
                end
            end
            return {value = -1}
        end
    else
        isPedInsideTurf = function(source)
            local p = promise.new()
            clientRemoteTurfs.isPlayerInsideTurf(tonumber(source), {}, function(inside) p:resolve(inside) end)
            return p 
        end
        getTurfIdFromPlayerCoords = function(player)
            if not isPedInsideTurf(player) then return -1 end;
            local p = promise.new()
            clientRemoteTurfs.getTurfIdFromPlayerCoords(tonumber(player), {}, function(id) p:resolve(id) end)
            return p
        end
    end
    
    local function initPlayerStats(user_id)
        local f = vRP.getUserFaction{user_id}
        local name = GetPlayerName(vRP.getUserSource{user_id})
        if not internalScoreboard[user_id] then 
            internalScoreboard[user_id] = {kills = 0, deaths = 0, faction = f, name = name, kda = 0}
        end
    end
    
    local function addScoreboardKill(user_id)
        local f = vRP.getUserFaction{user_id}
        local name = GetPlayerName(vRP.getUserSource{user_id})
        if not internalScoreboard[user_id] then 
            internalScoreboard[user_id] = {kills = 1, deaths = 0, faction = f, name = name, kda = 0}
        else
            if(internalScoreboard[user_id].deaths) > 0 then 
                internalScoreboard[user_id].kda = internalScoreboard[user_id].kills / internalScoreboard[user_id].deaths
            else 
                internalScoreboard[user_id].kda = 1
            end
            internalScoreboard[user_id].kills = internalScoreboard[user_id].kills + 1
        end
    end
    
    local function resetScoreboardStats(user_id)
        internalScoreboard[user_id] = nil
    end

    local function doesPlayerHaveFactionType(f)
        f = vRP.getFactionType{f}
        for _,fType in pairs(TurfsConfig.factionTypesForWar) do if f == fType then return true end end;
        return false
    end
    
    local function addScoreboardDeath(user_id)
        local f = vRP.getUserFaction{user_id}
        local name = GetPlayerName(vRP.getUserSource{user_id})
        if not internalScoreboard[user_id] then 
            internalScoreboard[user_id] = {kills = 0, deaths = 1, faction = f, name = name, kda = 0}
        else
            internalScoreboard[user_id].deaths = internalScoreboard[user_id].deaths + 1
            if(internalScoreboard[user_id].kills) > 0 then 
                internalScoreboard[user_id].kda = internalScoreboard[user_id].kills / internalScoreboard[user_id].deaths
            else 
                internalScoreboard[user_id].kda = 0
            end 
        end
    end

    local function getTaxesFromTurfName(name)
        for _, turf in pairs(internalTurfs) do 
            if turf.name == name then 
                return turf.taxes
            end
        end
        return {}
    end
    
    local function getPlayerStats(user_id)
        local f = vRP.getUserFaction{user_id}
        local name = GetPlayerName(vRP.getUserSource{user_id})
        if not internalScoreboard[user_id] then 
            internalScoreboard[user_id] = {kills = 0, deaths = 0, faction = f, name = name, kda = 0}
        end 
        return internalScoreboard[user_id]
    end
    
    local function getNumberOfOwnedTurfsForFaction(f)
        for faction,c in pairs(factions) do
            if faction == f then 
                return c 
            end
        end
        return 0
    end

    local function discordLog(content)
        local endpoint <const> = 'https://discord.com/api/webhooks/' .. TurfsConfig.discordWebhook
        if TurfsConfig.discordWebhook and TurfsConfig.discordWebhook ~= '' then 
            PerformHttpRequest(endpoint,function(err, text, headers) end, 'POST', json.encode({content = content}), { ['Content-Type'] = 'application/json' })
        end
    end
    
    local function computePaydayMoney()
        factions = {}
        exports.ghmattimysql:execute('SELECT ownerFaction FROM ' .. TurfsConfig.databaseTable, function(rows)
            for _,v in pairs(rows) do 
                if v.ownerFaction ~= '-1' and v.ownerFaction ~= 'none' then
                    if factions[v.ownerFaction] then
                        factions[v.ownerFaction] = factions[v.ownerFaction] + 1
                    else
                        factions[v.ownerFaction] = 1
                    end
                end
            end 
        end)
    end
    
    
    local function turfPaydayHandler()
        local min = TurfsConfig.turfPaydayMinutes
        local sec = 59
        while 1 do 
            Citizen.Wait(1000)
            sec = sec - 1 
            if sec <= 0 then
                sec = 60
                min = min - 1 
                if min < 0 then
                    computePaydayMoney()
                    local users = vRP.getUsers{}
                    for user_id,source in pairs(users) do
                       local f = vRP.getUserFaction{user_id} 
                       if f ~= 'user' then
                            if doesPlayerHaveFactionType(f) then 
                              local n = getNumberOfOwnedTurfsForFaction(f)
                              if n > 0 then 
                               local reward = n * TurfsConfig.turfPayday
                               vRPclient.notify(source,{'Ai primit ' .. reward .. '$ pentru ca detii ' .. n .. ' turf-uri!'})
                               vRP.giveMoney{user_id,reward}
                                end
                            end 
                        end
                    end
                    return turfPaydayHandler()
                end
            end
        end
    end

    if TurfsConfig.turfPayday ~= -1 then Citizen.CreateThread(turfPaydayHandler) end
    
    local function doesFactionOwnTurf(turfId,f)
        for _,v in pairs(internalTurfs) do  if v.turfId == turfId then return v.ownerFaction == f end end
        return false 
    end
    
    local function getTurfDataFromTurfId(turfId)
    
        if not turfId then return {} end; 
    
        for _,turf in pairs(internalTurfs) do
            if turf.turfId == turfId then return turf end;
        end
    
        return {}
    
    end
    
    local function isTurfOwned(turfId)
        local turf = getTurfDataFromTurfId(turfId)
    
        return ( turf.ownerFaction ~= '-1' )
    end
    
    local function setTurfAttacked (attackerFaction,ownerFaction,turfId) 
        local turf = getTurfDataFromTurfId(turfId)
    
        local attackedTurfTable = {}
        for index,value in pairs(turf) do attackedTurfTable[index] = value end
    
        attackedTurfTable.attacked = true 
        attackedTurfTable.owner = ownerFaction
        attackedTurfTable.attacker = attackerFaction
        attackedTurfTable.attackerScore = 0
        attackedTurfTable.ownerScore = 0
        attackedTurfTable.min = TurfsConfig.ownedTurfTimerInMinutes
        attackedTurfTable.sec = 60
        local attackers <const> = vRP.getOnlineUsersByFaction{attackerFaction}

        local attackersTable <const> = {}
        for _, user_id in pairs(attackers) do table.insert(attackersTable, { source = vRP.getUserSource{user_id}, user_id = user_id }) end
        attackedTurfTable.attackerMembers = attackersTable

        local defenders <const> = vRP.getOnlineUsersByFaction{ownerFaction}

        local defendersTable <const> = {}
        for _, user_id in pairs(defenders) do  table.insert(defendersTable, { source = vRP.getUserSource{user_id}, user_id = user_id }) end

        attackedTurfTable.defenderMembers = defendersTable

        internalAttackedTurfs[turfId] = attackedTurfTable
    
    end
    
    local function removeTurfAttacked (turfId)
         internalAttackedTurfs[turfId] = nil
    end
    
    local function removeActiveAttackOnFreeTurf(attackerUserId)
        for ndx,p in pairs(playersAttackingFreeTurfs) do
            if p.user_id == attackerUserId then playersAttackingFreeTurfs[ndx] = nil end
        end
    end
    
    local function getWarData(turfId)
        return internalAttackedTurfs[turfId]
    end
    
    local function getFreeTurfAttackerData(user_id)
        for _,p in pairs(playersAttackingFreeTurfs) do if p.user_id == user_id then return p end end
        return nil
    end
    
    local function isPlayerAttackingFreeTurf(user_id)
        for _,p in pairs(playersAttackingFreeTurfs) do if p.user_id == user_id then return true end end
        return false
    end
    
    local function stopPlayerAttackFreeTurf(user_id)
        local data = getFreeTurfAttackerData(user_id)
        clientRemoteTurfs.stopBlipFlash(-1, {data.turfId})
        removeActiveAttackOnFreeTurf(user_id)
    end
    

    local function isTurfAttacked(turfId) 
        return ( internalAttackedTurfs[turfId] ~= nil )
    end 
    
    
    local function getTurfIdFromName(name)
        for _,turf in pairs(internalTurfs) do
            if turf.name == name then return turf.turfId end
        end
        return -1
    end
    
    local function isFactionInFreeTurfWar(f)
        for _,p in pairs(playersAttackingFreeTurfs) do if p.faction == f then return true end end
    end
    
    local function getFactionFreeWarData(f)
        for _,p in pairs(playersAttackingFreeTurfs) do if p.faction == f then return p end end
    end
    
    local function isFactionInWar(f)

        for _,turf in pairs(internalAttackedTurfs) do
            if turf.owner == f or turf.attacker == f then 
                return true,turf.turfId
             end
        end
    
        return false
    end
    
    
    local function chat(target,msg)
        TriggerClientEvent('chatMessage',target,msg or '');
    end
    
    
    local function isCurrentTimeInsideAllowedInterval()
        local currentTime = os.date'*t'
        
        local openingInterval,closingInterval = table.unpack(TurfsConfig.timeInterval)
        return ( currentTime.hour >= openingInterval and currentTime.hour <= closingInterval )
    end
    
    
    local function initializeInternalTurfs()
    
        local populateInternalTableHandler = function(rows)
            for _,turf in pairs(rows) do
                table.insert( internalTurfs, turf )
                table.insert(turfNames,turf.name)
            end
            
        local currentTime <const> = os.time()
        exports['ghmattimysql']:execute('SELECT * FROM ' .. TurfsConfig.taxDatabaseTable, function(result)
            for _, tax in pairs(result) do 
                if not internalTaxes[tax.buyer] then internalTaxes[tax.buyer] = {} end;
                if not (tax.tax <= currentTime) then table.insert(internalTaxes[tax.buyer], tax) else tax.expired = true end;
                if not tax.expired then 
                    for _, turf in pairs(internalTurfs) do 
                        if turf.name:lower() == tax.turfName:lower() then 
                            if not turf.taxes then turf.taxes = {} end;
                            table.insert(turf.taxes,tax)
                        end
                    end
                end
            end
        end)

        end
    
        exports['ghmattimysql']:execute('SELECT * FROM ' .. TurfsConfig.databaseTable, populateInternalTableHandler)

        exports['ghmattimysql']:execute('SELECT * FROM ' .. TurfsConfig.historyDatabaseTable, function(result) 
            for _ , war in pairs(result) do 
                if not internalWarHistory[war.attacker] then internalWarHistory[war.attacker] = {} end;
                if not internalWarHistory[war.defender] then internalWarHistory[war.defender] = {} end;
                war.data = json.decode(war.data)
                table.insert(internalWarHistory[war.attacker], war)
                table.insert(internalWarHistory[war.defender], war)
            end 
        end)

    end
    
    Citizen.CreateThread(initializeInternalTurfs)
    
    local function startAttackOnFreeTurf(turfId,attacker,attackerUserId)

    
        local turfData = getTurfDataFromTurfId(turfId)
    
        local attackerSource = vRP.getUserSource{attackerUserId}
    
        local freeTurf = isPlayerAttackingFreeTurf(attackerUserId)
    
        if freeTurf then return chat(attackerSource,'^1Eroare^0: Factiunea ta deja ataca un turf!') end;
    
        local name = GetPlayerName(attackerSource)

    
        for _, turf in pairs(playersAttackingFreeTurfs) do
            if turf.turfName == turfData.name then
                return chat(attackerSource,'^1Eroare^0: Acest turf este deja atacat!')
            end
        end
    
        TriggerClientEvent('chatMessage',-1,'^1TURFS^0: Factiunea ^1' .. attacker .. '^0 a inceput un atac pe turf-ul nedetinut ^1' .. turfData.name .. '^0' )
        TriggerClientEvent('chatMessage',-1,'Omoara-l pe ^1' .. name .. '^0 pentru a opri atacul!' )
        discordLog(name .. ' a inceput un atac pe turf-ul nedetinut #' .. turfData.turfId .. ' ' .. turfData.name )
        
        clientRemoteTurfs.setLeaderInFreeTurfWar(attackerSource, { })
    
        if TurfsConfig.attackCooldown ~= -1 then
            attackCooldowns[attacker] = true 
            Citizen.SetTimeout(1000 * 60 * TurfsConfig.attackCooldown, function()  attackCooldowns[attacker] = nil end)
        end
    
        local onlineMembers = vRP.getOnlineUsersByFaction{attacker}
    
        table.insert(playersAttackingFreeTurfs, { onlineMembers = onlineMembers, turfId = turfId,source = attackerSource, name = name, user_id = attackerUserId, faction = attacker, turfName = turfData.name, min = TurfsConfig.freeTurfTimerInMinutes, sec = 60})
        local data = getFreeTurfAttackerData(attackerUserId)
    
        local onlineMembers = vRP.getOnlineUsersByFaction{attacker}
    
        Citizen.CreateThread(function()
            while data.min >= 0 and isPlayerAttackingFreeTurf(attackerUserId) do
                data.sec = data.sec - 1
                
                if(data.sec <= 0) then
                    data.sec = 60
                    data.min = data.min - 1 
    
                    if(data.min < 0) then
                        local stillAttacking = getFreeTurfAttackerData(attackerUserId)
                        if stillAttacking then stillAttacking = nil end
                        break 
                    end
    
                end
    
                local data = getFreeTurfAttackerData(attackerUserId)
                for _,id in pairs(data.onlineMembers) do clientRemoteTurfs.updateRemainingTurfTime(vRP.getUserSource{id}, { data.min,data.sec }) end
    
                Citizen.Wait(1000)
            end
    
            local d = getFreeTurfAttackerData(attackerUserId)
            if d == nil then return end;
    
            local fColor = vRP.getFactionColor{attacker}
    
            clientRemoteTurfs.stopBlipFlash(-1, {turfId})
            Citizen.SetTimeout(500, function()   clientRemoteTurfs.changeTurfBlipColor(-1 , {turfId,fColor}) end)
            local online = vRP.getOnlineUsersByFaction{attacker}
            for _,id in pairs(online) do
                local s = vRP.getUserSource{id}
                TriggerClientEvent('snTurfs:setTurf',s,nil)
            end
    
            turfData.ownerFaction = attacker        
    
            exports.ghmattimysql:execute('UPDATE ' .. TurfsConfig.databaseTable .. ' SET ownerFaction = @owner WHERE turfId = @id', {owner = attacker, id = turfId})
    
            TriggerClientEvent('chatMessage', -1 , '^1TURFS^0: Factiunea ^1' .. attacker .. '^0 a capturat turf-ul nedetinut ^1' .. turfData.name )
            clientRemoteTurfs.changeTurfOwnerFaction(-1 , { turfId,attacker})

            for f, _ in pairs(factions) do 
                if f == attacker then 
                    factions[f] = factions[f] + 1 
                end
            end

            for _,p in pairs(playersAttackingFreeTurfs) do
                if p.user_id == attackerUserId then
                    playersAttackingFreeTurfs[_] = nil
                end
            end
    
        end)
    
        local fColor = vRP.getFactionColor{attacker}
    
        for _,user_id in pairs(onlineMembers) do 
            local source = vRP.getUserSource{user_id}
            TriggerClientEvent('snTurfs:setTurf',source,turfData)
            vRPclient.notify(source,{'Factiunea ta a inceput un atac pe teritoriul nedetinut ' .. turfData.name})
            clientRemoteTurfs.displayFreeTurfTimer(source, { false })
            TriggerClientEvent('snTurfs:togglePlayerInWar',source)
        end
        
        clientRemoteTurfs.startBlipFlash(-1, { fColor,turfId })
    end
    
    local function sendToMembers(f,cb)
        local online = vRP.getOnlineUsersByFaction{f}
        for _, user_id in pairs(online) do
            local source = vRP.getUserSource{user_id}
            cb(user_id,source)
        end
    end
    
    local sendToBothFactions <const> = function(turfId,cb,ended,f1,f2)

        if ended then
            local def = vRP.getOnlineUsersByFaction{f1}
            for _, user_id in pairs(def) do
                local source = vRP.getUserSource{user_id}
                if source and vRP.isConnected{user_id} then 
                    cb(user_id,source)
                end
            end
        
            local attacker  = vRP.getOnlineUsersByFaction{f2}
            for _, user_id in pairs(attacker) do
                local source = vRP.getUserSource{user_id}
                if source and vRP.isConnected{user_id} then 
                    cb(user_id,source)
                end
            end
            return 
        end
    
        local warData <const> = getWarData(turfId)
        if not warData then return end;

        local clientBlipTable = {}

    
        for _, v in pairs(warData.defenderMembers) do
            if TurfsConfig.showTeammatesOnMap then
                local coords <const> = GetEntityCoords(GetPlayerPed(v.source)) 
                table.insert(clientBlipTable, { x = coords.x, y = coords.y, z = coords.z, name = GetPlayerName(v.source), faction = vRP.getUserFaction{v.user_id} })
            end
            if v.source and vRP.isConnected{v.user_id} then 
                cb(v.user_id,v.source)
            end
        
        end
    
        for _, v in pairs(warData.attackerMembers) do
            if TurfsConfig.showTeammatesOnMap then
                local coords <const> = GetEntityCoords(GetPlayerPed(v.source)) 
                table.insert(clientBlipTable, { x = coords.x, y = coords.y, z = coords.z, name = GetPlayerName(v.source) , faction = vRP.getUserFaction{v.user_id} })
            end
            if v.source and vRP.isConnected{v.user_id} then 
                cb(v.user_id,v.source)
            end
        end

        if TurfsConfig.showTeammatesOnMap then
            for _, v in pairs(warData.defenderMembers) do
                if vRP.isConnected{v.user_id} then 
                    clientRemoteTurfs.showTeammateBlips(v.source, { clientBlipTable })
                end
             
            end; for _, v in pairs(warData.attackerMembers) do  if vRP.isConnected{v.user_id} then  clientRemoteTurfs.showTeammateBlips(v.source, { clientBlipTable }) end end
        end
      
    end
    
    local function sendKillfeedToClients(turfId,killed,killer,weaponHash)
    
        if TurfsConfig.sanitizeKillfeedNames then 
            killed = sanitizeString(killed, "\"&<>/\\'", false)
            killer = sanitizeString(killer, "\"&<>/\\'", false)
        end
    
       sendToBothFactions(turfId, function(_,source)
            TriggerClientEvent(TurfsConfig.killfeedEvent,source,{
                killed = killed,
                killer = killer,
                weapon = weaponHash,
                killerColor = TurfsConfig.killfeedColors[1],
                mortColor = TurfsConfig.killfeedColors[2]
            })
        end)
    end 
    
    local function getWarScores(turfId)
        if internalAttackedTurfs[turfId] then 
            return internalAttackedTurfs[turfId].attackerScore,internalAttackedTurfs[turfId].ownerScore
        end

    end
    
    local function endWarOnOwnedTurf(turfId,attacker,defender,turfName)
        local winnerName = ''
        local loserName = ''
    
        local aScore,dScore = getWarScores(turfId)
        local historyWarData <const> = { defender = defender, attacker = attacker }
        local date <const> = os.date'%X %x'

        historyWarData.data = { date = date, defenderScore = dScore, attackerScore = aScore, players = {} }
        
        if not aScore or not dScore then return end;
        if aScore > dScore then winnerName = attacker; loserName = defender end;

        if dScore > aScore then winnerName = defender; loserName = attacker end;
        

        local prefWinner <const> = TurfsConfig.outcomeWhenScoreIsEqual
        if dScore == aScore then 
            if prefWinner == 'defender' then 
                winnerName = defender 
                loserName = attacker
            elseif prefWinner == 'attacker' then 
                winnerName = attacker
                loserName = defender
            end
        end
        

        historyWarData.data.winner = winnerName
    
        TriggerClientEvent('chatMessage', -1,'^1TURFS^0: ^1' .. winnerName .. '^0 a castigat turf-ul ^1' .. turfName .. '^0 de la ^1' .. loserName)
    
        for _,turf in pairs(internalTurfs) do
            if turf.turfId == turfId then
                turf.ownerFaction = winnerName
                turf.wasAttacked = true 
                historyWarData.data.location = turf.name 
                discordLog(winnerName .. ' a castigat war-ul VS ' .. loserName .. '\nLocatie: ' .. turf.name )
                Citizen.SetTimeout(1000 * 60 * TurfsConfig.attackedTurfCooldown, function () turf.wasAttacked = false end)
                break
            end
        end

        for f, _ in pairs(factions) do 
            if f == winnerName then 
                factions[f] = factions[f] + 1 
            end
        end
    
        removeTurfAttacked(turfId)
    
        clientRemoteTurfs.stopBlipFlash(-1, {turfId})
    
        local newColor = vRP.getFactionColor{winnerName}
    
        Citizen.SetTimeout(500, function() clientRemoteTurfs.changeTurfBlipColor(-1,{turfId,newColor})  end)
    
        local useVW = TurfsConfig.useVirtualWorlds
    
        sendToBothFactions(turfId, function(_,source)
            TriggerClientEvent('wfc:setByPass',source,false)
            TriggerClientEvent('snTurfs:setTurf',source,nil)
            if TurfsConfig.disableAdminWhenAttackActive and not adminException(_) then TriggerEvent('snTurfs:toggleAdmin',_) end 

            if useVW then SetPlayerRoutingBucket(source,0) end;
            resetScoreboardStats(_)
        end,true,winnerName,loserName)

        local aux <const>  = vRP.getOnlineUsersByFaction{loserName}
        local onlinePlayers <const> = vRP.getOnlineUsersByFaction{winnerName}
        for _, user_id in pairs(aux) do table.insert(onlinePlayers,user_id) end

        for _, user_id in pairs(onlinePlayers) do 
            
            local source <const> = vRP.getUserSource{user_id}
            local name <const> = GetPlayerName(source)
            if not internalScoreboard[user_id] then initPlayerStats(user_id) end;

            local deaths <const> = internalScoreboard[user_id].deaths
            local kills <const> = internalScoreboard[user_id].kills 
            local kda <const> = internalScoreboard[user_id].kda 
            local faction <const> = internalScoreboard[user_id].faction

            table.insert(historyWarData.data.players, { name = name, user_id = user_id, faction = faction , kills = kills, deaths = deaths, kda = kda })

        end


        exports['ghmattimysql']:execute('INSERT IGNORE INTO ' .. TurfsConfig.historyDatabaseTable .. '(attacker,defender,data) VALUES(@attacker,@defender,@data)',{
            attacker = historyWarData.attacker,
            defender = historyWarData.defender,
            data = json.encode(historyWarData.data)
        })

        if not internalWarHistory[winnerName] then internalWarHistory[winnerName] = {} end;
        if not internalWarHistory[loserName] then internalWarHistory[loserName] = {} end;

        table.insert(internalWarHistory[winnerName], historyWarData)
        table.insert(internalWarHistory[loserName], historyWarData)
 

        clientRemoteTurfs.changeTurfOwnerFaction(-1, {turfId,winnerName} )
        exports['ghmattimysql']:execute('UPDATE ' .. TurfsConfig.databaseTable .. ' SET ownerFaction = @owner WHERE turfId = @turfId' , {owner = winnerName, turfId = turfId}, function() local warData = getWarData(turfId); warData = nil  end)
        
    end
    
    local function addPlayerToWar(user_id,turfId)

        if not user_id or not turfId then return end;
        user_id = tonumber(user_id)
        local f = vRP.getUserFaction{user_id}
        local stats = getPlayerStats(user_id)
        if stats.deaths == 0 and stats.kills == 0 then 
            resetScoreboardStats(user_id)
            initPlayerStats(user_id)
        end
    
        local source = vRP.getUserSource{user_id}
        local turfData = getTurfDataFromTurfId(turfId)
        local war = getWarData(turfId)

        TriggerClientEvent('snTurfs:setTurf',source,turfData,f)
        TriggerClientEvent('snTurfs:togglePlayerInWar',source)
        TriggerClientEvent('wfc:setByPass',source,true)
        TriggerClientEvent('snTurfs:cancelBlips',source)

        if TurfsConfig.disableAdminWhenAttackActive and not adminException(user_id) then TriggerEvent('snTurfs:toggleAdmin',user_id) end

        if TurfsConfig.useVirtualWorlds then SetPlayerRoutingBucket(source,turfId) end;
    
        local aScore,dScore = getWarScores(turfId)
        clientRemoteTurfs.updateRemainingTurfTime(source, {war.min,war.sec})
        clientRemoteTurfs.displayFreeTurfTimer(source,{true})
        clientRemoteTurfs.updateScoreboard(source, {internalScoreboard,user_id, { war.attacker,war.owner}})
        clientRemoteTurfs.startBlipFlash(source, { vRP.getFactionColor{f},turfId })
        clientRemoteTurfs.updateScores(source, { { attacker = war.attacker, defender = war.ownerFaction, attackerScore = aScore, defenderScore = dScore } })
        TriggerClientEvent('snTurfs:cancelBlips',source)

        local isAttacker
        local w = internalAttackedTurfs[turfId]
        if w.attacker == f then isAttacker = true else isAttacker = false end;

        if isAttacker then 
            table.insert(internalAttackedTurfs[turfId].attackerMembers, {user_id = user_id, source = source})
        else
            table.insert(internalAttackedTurfs[turfId].defenderMembers, {user_id = user_id, source = source})
        end
      
    end
    
    local function startAttackOnOwnedTurf(turfId,attacker,defender,turfName)
        TriggerClientEvent('chatMessage',-1,'^1TURFS^0: Factiunea ^1' .. attacker .. '^0 a inceput un atac asupra factiuni ^1' .. defender )
        TriggerClientEvent('chatMessage',-1,'^1Locatie^0: ' .. turfName )
    
        local turfData = getTurfDataFromTurfId(turfId)
    
        local useVW = TurfsConfig.useVirtualWorlds
    
        local aScore,dScore = getWarScores(turfId)
        discordLog('ATAC ' .. attacker .. ' VS ' .. defender ..' #' .. turfData.turfId .. ' ' .. turfName )
    
        sendToBothFactions(turfId, function(_,source)
            resetScoreboardStats(_)
            initPlayerStats(_)
            clientRemoteTurfs.updateScoreboard(source, {internalScoreboard,_, { attacker,defender  }})
            clientRemoteTurfs.updateScores(source, { { attacker = attacker, defender = defender, attackerScore = aScore, defenderScore = dScore } })
            TriggerClientEvent('snTurfs:setTurf',source,turfData,vRP.getUserFaction{_})
            TriggerClientEvent('snTurfs:togglePlayerInWar',source)
            TriggerClientEvent('wfc:setByPass',source,true)
            if TurfsConfig.disableAdminWhenAttackActive and not adminException(_) then 
                TriggerEvent('snTurfs:toggleAdmin',_)
            end
       
            TriggerClientEvent('snTurfs:cancelBlips',source)
            if useVW then SetPlayerRoutingBucket(source,turfId) end
            clientRemoteTurfs.displayFreeTurfTimer(source,{true})
        end)
    
        sendToMembers(defender, function (_,source)
            vRPclient.notify(source,{'Factiunea ta este atacata de ' .. attacker })
            TriggerClientEvent('wfc:setByPass',source,true)
        end)
    
        local aColor = vRP.getFactionColor{attacker}
        clientRemoteTurfs.startBlipFlash(-1, { aColor,turfId })
    
        sendToMembers(attacker, function(_,source)
            vRPclient.notify(source,{'Factiunea ta a inceput un atac versus ' .. defender })
            TriggerClientEvent('wfc:setByPass',source,true)
        end)
    
        local data = getWarData(turfId)
        data.sec = 60
        data.min = TurfsConfig.ownedTurfTimerInMinutes
    
        Citizen.CreateThread(function()
            while data.min >= 0 and isTurfAttacked(turfId) do
                Citizen.Wait(1000)
                data.sec = data.sec - 1
                if(data.sec <= 0) then 
                    data.sec = 59
                    data.min = data.min - 1 
                    if (data.min < 0 ) then
                        if isTurfAttacked(turfId) then 
                            return endWarOnOwnedTurf(turfId,attacker,defender,turfName) 
                        end
                    end
                end
                local aScore,dScore = getWarScores(turfId)
                sendToBothFactions(turfId, function(_,source)
                    clientRemoteTurfs.updateScores(source, { { attacker = attacker, defender = defender, attackerScore = aScore, defenderScore = dScore } })
                    clientRemoteTurfs.updateRemainingTurfTime(source, {data.min,data.sec})
                end)
            end
        end)
    
    end
    
    
    local continueAttackHandlerWithDatabaseResult = function(attackerFaction,user_id,turfId,rows)
    
        local player <const> = vRP.getUserSource{user_id}    
    
        if isTurfAttacked(turfId) then return chat(player,'^1Eroare^0: Turf-ul este deja atacat!') end;
    
        local was <const> = isFactionInWar(attackerFaction)
    
        if was then return chat(player,'^1Eroare^0: Factiunea ta este deja intr-un war!') end; 
    
        for _,turf in pairs(rows) do
    
            if turf.turfId == turfId then
    
                local attackedFaction <const> = turf.ownerFaction 
            
                if attackedFaction == attackerFaction then return chat(player,'^1Eroare^0: Nu iti poti ataca propriul turf!') end; 
                
                if isFactionInFreeTurfWar(attackerFaction) then return chat(player,'^1Eroare^0: Factiunea ta este deja intr-un war!') end; 
    
                if isFactionInFreeTurfWar(attackedFaction) then return chat(player,'^1Eroare^0: Factiunea este deja intr-un war!') end; 
                
                if isFactionInWar(attackedFaction) then return chat(player,'^1Eroare^0: Factiunea ^1' .. attackedFaction .. '^0 este deja intr-un war!' ) end; 
    
                if not isTurfOwned(turfId) then return Citizen.CreateThread(function() startAttackOnFreeTurf(turfId,attackerFaction,user_id) end)  end;
    
                local onlineAttackedPlayers <const> = vRP.getOnlineUsersByFaction{attackedFaction}
    
                local onlineAttackers <const> = vRP.getOnlineUsersByFaction{attackerFaction}
    
                if not ( TurfsConfig.minOnlinePlayers <= #onlineAttackers ) then return chat(player,'^1Eroare^0: Factiunea ^1' .. attackerFaction .. '^0 nu are ^1' .. TurfsConfig.minOnlinePlayers .. '^0 jucatori online!' ) end; 
    
                if not ( TurfsConfig.minOnlinePlayers <= #onlineAttackedPlayers ) then return chat(player,'^1Eroare^0: Factiunea ^1' .. attackedFaction .. '^0 nu are ^1' .. TurfsConfig.minOnlinePlayers .. '^0 jucatori online!' ) end; 
    
                setTurfAttacked(attackerFaction,attackedFaction,turfId)
    
                if TurfsConfig.attackCooldown ~= -1 then  attackCooldowns[attackerFaction]= true ; Citizen.SetTimeout(1000 * 60 * TurfsConfig.attackCooldown, function()  attackCooldowns[attackerFaction] = nil end)  end
    
                Citizen.CreateThread(function() startAttackOnOwnedTurf(turfId,attackerFaction,attackedFaction,turf.name) end)
    
            end
        end
    end

    local function showWarHistoryHandler(...)

        local args = {...}
    
        local player = args[1]
    
        local user_id = vRP.getUserId{player}
    
        local faction = vRP.getUserFaction{user_id}
        if not ( doesPlayerHaveFactionType(faction) ) then return chat(player,'^1Eroare^0: Nu esti intr-o mafie!') end;

        local historyMenu <const> =  {name="Wars",css = {top="75px",header_color="rgba(255, 255,0,0.8)"}}

        if not internalWarHistory[faction] or #internalWarHistory[faction] == 0 then 
            internalWarHistory[faction] = {}
            
            local databaseLookup <const> = exports['ghmattimysql']:executeSync('SELECT * FROM ' .. TurfsConfig.historyDatabaseTable .. ' WHERE attacker = @faction OR defender = @faction', { faction = faction} ) 
            if #databaseLookup <= 0 then return chat(player,'^1Eroare^0: Factiunea ta nu are niciun war jucat!') end;
            for _, war in pairs(databaseLookup) do 
                table.insert(internalWarHistory[faction],war)
            end
        end

      
        for idx, war in pairs(internalWarHistory[faction]) do 

            local enemyFaction <const> = ( (war.attacker == faction) and war.defender ) or war.attacker
            local firstScore
            local secondScore
            if war.attacker == faction then firstScore = war.data.attackerScore; secondScore = war.data.defenderScore else firstScore = war.data.defenderScore; secondScore = war.data.attackerScore end;
            local scores <const> = {firstScore,secondScore}

            historyMenu[('#%d [%s] %s'):format(idx,war.data.location,enemyFaction)] = {function(player,__)
                local playersMenu <const> =  {name="Jucatori",css = {top="75px",header_color="rgba(255, 255,0,0.8)"}}
                if not war.data.players or #war.data.players == 0 then return vRPclient.notify(player,{'Nu am putut gasi participantii la acest war!',4})  end
                
                for _, player in pairs(war.data.players) do 
                    playersMenu['[' .. player.user_id ..'] ' .. player.name] = {nil,("Kills: %s<br>Deaths: %s<br>KDA: %s<br>Factiune: %s"):format(player.kills,player.deaths,player.kda,player.faction)}
                end
                vRP.openMenu{player,playersMenu}


            end, ('Data: %s<br>Locatie: %s<br>Castigator: %s<br>Scor: %s - %s<br>'):format(war.data.date,war.data.location,war.data.winner,scores[1],scores[2]) }
        end     
    
        vRP.openMenu{player,historyMenu}
        

    end
    local function attackHandler(...)
    
        local args = {...}
    
        local player = args[1]
    
        local user_id = vRP.getUserId{player}
    
        local faction = vRP.getUserFaction{user_id}
    
        if GetEntityHealth(GetPlayerPed(player)) <= TurfsConfig.comaThreshold then return chat(player,'^1Eroare^0: Nu poti ataca un turf mort!') end
    
        if not ( doesPlayerHaveFactionType(faction) ) then return chat(player,'^1Eroare^0: Nu esti intr-o mafie!') end;
    
        local isLeader = vRP.isFactionLeader{user_id,faction} or vRP.isFactionCoLeader{user_id,faction}
    
        if not isLeader then return chat(player,'^1Eroare^0: Nu esti liderul unei mafii!') end;
        
        if not isPedInsideTurf(player) then return chat(player,'^1Eroare^0: Nu esti intr-un turf!') end;
    
        if TurfsConfig.attackCooldown ~= -1 then if attackCooldowns[faction] then return chat(player,'^1Eroare^0: Ai cooldown!') end;  end
    
        local turfId = getTurfIdFromPlayerCoords(player)
    
        Citizen.SetTimeout(1000, function()

            turfId = turfId.value
            
            if turfId == -1 then return chat(player,'^1Eroare^0: Nu esti intr-un turf!') end; 
        
            if isTurfAttacked(turfId) then return chat(player,'^1Eroare^0: Nu poti ataca un turf deja in war!') end;
        
            local turfData = getTurfDataFromTurfId(turfId)
        
            if turfData.wasAttacked then return chat(player,'^1Eroare^0: Acest turf a fost atacat recent!') end

            if not TurfsConfig.isWarDay() then return chat(player,'^1Eroare^0: Astazi nu este o zi de war!') end;
        
            if not isCurrentTimeInsideAllowedInterval() then return chat(player,string.format("^1Eroare^0: War-urile se pot da intre orele %s:00 si %s:00", TurfsConfig.timeInterval[1], TurfsConfig.timeInterval[2])) end;
        
            if getNumberOfOwnedTurfsForFaction(faction) >= TurfsConfig.maxTurfs then return chat(player,'^1Eroare^0: Nu poti detine mai mult de ' .. TurfsConfig.maxTurfs .. ' turf-uri!') end;
        
            exports.ghmattimysql:execute('SELECT ownerFaction,turfId,name FROM ' .. TurfsConfig.databaseTable .. ' WHERE turfId = @turfId', {turfId = turfId}, function(rows)
                    continueAttackHandlerWithDatabaseResult(faction,user_id,turfId,rows)
            end)
    end)
     
    end
     
    local function isTurfNameValid(tName)
     
        for _,name in pairs(turfNames) do
            if name == tName then
                return true 
            end 
        end
        return false
    end
    
    local function setOwnerHandler(...)

        -- am stat prea mult pe prostia asta, vorba lui nostress mai bine faceam cu prompt-uri
        local args = {...}
        
        local player = args[1]
        
        local user_id = vRP.getUserId{player}
    
        if not vRP.isUserAdmin{user_id} then return chat(player,'^1Eroare^0: Nu ai acces la aceasta comanda!') end;
    
        local name = args[3]:sub(TurfsConfig.changeOwnerCommandString:len() + 2)
    
        local new = splitString(name,' ')
    
        local ISVALID = false 
    
        local argLength = #new 
    
        local cString = ''
    
        local once = false 
    
        for i = 1, argLength do
            if not once then
                once = true 
                cString = new[i]
            else
                cString = cString .. ' ' ..new[i]
            end
     
            if isTurfNameValid(cString) then
                ISVALID = true 
                break
            end
     
        end
    
        local t = {}
    
        local splited = splitString(cString,' ')
    
        for i =  1,#args[2] do
            if args[2][i] ~= splited[i] then
                table.insert(t,args[2][i])
            end
        end
    
        local newOwnerFaction = ''
        local once = false 
        for _,v in pairs(t) do
            if not once then
                once = true 
                newOwnerFaction = v 
            else
                newOwnerFaction = newOwnerFaction ..  ' ' .. v
            end
        end
    
        if not ISVALID then
            local turfNamesString = ''
            local syntaxHelpString = "^1Eroare^0: Nume turf invalid!, Nume turfuri: ^7" 
            local once = false
        
            for _,name in pairs(turfNames) do
                  if not once then
                      once = true 
                      turfNamesString =  name 
                  else
                    turfNamesString = turfNamesString .. '^0,^7 ' .. name  
                  end
            end
    
          return chat(player,syntaxHelpString .. turfNamesString)
        end
    
       if not ( newOwnerFaction == '-1' ) then 
            if ( not newOwnerFaction ) or ( #newOwnerFaction <= 0 ) then return chat(player,'^1Eroare^0: Factiunea noua invalida') end; 
       end
      
        exports.ghmattimysql:execute('UPDATE ' .. TurfsConfig.databaseTable .. ' SET ownerFaction = @owner WHERE name = @name', {owner = newOwnerFaction, name = cString})   
    
    
        local tId <const> = getTurfIdFromName(cString)
    
        for _,turf in pairs(internalTurfs) do
            if turf.turfId == tId then
                turf.ownerFaction = newOwnerFaction
                break
            end
        end
    
        local newColor <const> = vRP.getFactionColor{newOwnerFaction}
        
        clientRemoteTurfs.changeTurfBlipColor(-1, { tId, newColor})
    
        clientRemoteTurfs.changeTurfOwnerFaction(-1 ,{tId, newOwnerFaction })
        
        TriggerClientEvent('chatMessage',-1,'^1TURFS^0: Adminul ^1' .. GetPlayerName(player) .. '^0 a setat owner-ul turf-ului ^1' .. cString .. '^0 in ^1' .. newOwnerFaction)
        
    end
    
    local function secondsToDays(seconds)
        return math.ceil(seconds / 86400 )     
    end
    
    local function daysToSeconds(days)
        return days * 86400
    end
    
    local function addTaxHandler(...)
    
        local args = {...}
        local player = tonumber(args[1])
    
        local target_id = tonumber(args[2][1])
    
        local user_id = vRP.getUserId{player}
    
        if target_id == user_id then chat(player,'^1Eroare^0: Nu poti sa iti ceri taxa singur!') end
    
        if not target_id then return chat(player,'^1Syntax^0: /' .. TurfsConfig.addTaxCommandString .. ' <id>') end;
    
        if not vRP.isConnected{target_id} then return chat(player,'^1Eroare^0: Jucatorul nu este conectat!') end;
    
        if not isPedInsideTurf(player) then return chat(player,'^1Eroare^0: Trebuie sa fi intr-un turf pentru a folosi aceasta comanda!') end;
    
        local target_source = vRP.getUserSource{target_id}
    
        if not isPedInsideTurf(target_source) then return chat(player,'^1Eroare^0: Jucatorul nu este intr-un turf!') end;
    
        
        local turfId = getTurfIdFromPlayerCoords(player)
    
        Citizen.SetTimeout(1000, function()
        turfId = turfId.value
    
        local faction = vRP.getUserFaction{user_id}
    
        if not doesPlayerHaveFactionType(faction) then return chat(player,'^1Eroare^0: Nu esti intr-o mafie!') end;
    
        if not ( doesFactionOwnTurf(turfId,faction) ) then return chat(player,'^1Eroare^0: Factiunea ta nu detine acest turf!') end;
    
        local turfData = getTurfDataFromTurfId(turfId)
    
        vRP.request{target_source, 'Vrei sa platesti taxa <font color="green">' .. turfData.pretTaxa .. '$</font> ?', 30, function (t,ok)
            if not ok then return vRPclient.notify(player,{'Jucatorul ' .. GetPlayerName(target_source) .. ' a refuzat',4}) end;
    
            if not vRP.tryFullPayment{target_id,turfData.pretTaxa} then vRPclient.notify(t,{'Nu ai destui bani pentru a plati taxa!',4}); return vRPclient.notify(player,{'Jucatorul ' .. GetPlayerName(target_source) .. ' a refuzat!',4}) end
           
            local name = turfData.name
            vRPclient.notify(t,{'Ai platit taxa pe turf-ul ' .. name,2})
            vRPclient.notify(player,{GetPlayerName(t) .. ' a platit taxa pe turf-ul ' .. name,2})
    
            local times = os.date'*t'
    
            if times.min <= 9 then times.min = '0' .. times.min end;
    
            local taxDatabaseTable = {
                turfId = turfId,
                buyerName = GetPlayerName(t),
                buyer = target_id,
                mafiotName = GetPlayerName(player),
                mafiot = user_id,
                turfName = name, 
                tax = os.time() + daysToSeconds(TurfsConfig.taxDays),
                time = string.format("%s:%s",times.hour,times.min)
            }
    
            if TurfsConfig.useAchievements then TriggerEvent('snAchievments:tryUnlock',target_id,'firstTax',5000,'prima taxa') end;
           
            vRP.giveMoney{user_id,turfData.pretTaxa}
    
            exports.ghmattimysql:execute('INSERT INTO ' .. TurfsConfig.taxDatabaseTable .. '(turfId,buyerName,buyer,mafiotName,mafiot,turfName,tax,time) VALUES(@turfId,@buyerName,@buyer,@mafiotName,@mafiot,@turfName,@tax,@time)',taxDatabaseTable)
            
        end}

    end)
    
    end
    
    local function cancelAttackHandler(...)
        local args = {...}
    
        local player = args[1]
    
        local user_id = vRP.getUserId{player}
    
        local faction = vRP.getUserFaction{user_id}
    
        if not doesPlayerHaveFactionType(faction) then return chat(player,'^1TURFS^0: Nu esti intr-o mafie!') end;
    
        if not vRP.isFactionLeader{user_id,faction} and not vRP.isFactionCoLeader{user_id,faction} then return chat(player,'^1Eroare^0: Nu esti liderul unei mafii!') end;
    
        if isPlayerAttackingFreeTurf(user_id) then
            local d = getFreeTurfAttackerData(user_id)
            stopPlayerAttackFreeTurf(user_id)
            clientRemoteTurfs.changeTurfBlipColor(-1, {d.turfId, TurfsConfig.turfDefaultBlipColor})
            local online  = vRP.getOnlineUsersByFaction{faction}
            for _, id in pairs(online) do
                local s = vRP.getUserSource{id}
                TriggerClientEvent('snTurfs:setTurf',s,nil)
            end
            return chat(-1,'^1TURFS^0: ^1' .. GetPlayerName(player) .. '^0 a oprit atacul asupra teritoriului nedetinut ^1' .. d.turfName )    
        end
    
        for _, turf in pairs(internalAttackedTurfs) do
            if turf.owner == faction or turf.attacker == faction then
                local war = getWarData(turf.turfId)
                local aScore,dScore = getWarScores(turf.turfId)
                if aScore == 0 and dScore == 0 then
    
                    local turfData = getTurfDataFromTurfId(turf.turfId)
                    turfData.wasAttacked = false;
    
                    sendToBothFactions(turf.turfId, function(_,source)
                        TriggerClientEvent('snTurfs:setTurf',source,nil)
                        TriggerClientEvent('wfc:setByPass',source,false)
                        resetScoreboardStats(_)
                        clientRemoteTurfs.updateRemainingTurfTime(source,{TurfsConfig.ownedTurfTimerInMinutes,59}) 
                        if not adminException(_) then 
                            TriggerEvent('snTurfs:toggleAdmin',_,true)
                        end
                     
                    end,true,turf.owner,turf.attacker)

                    clientRemoteTurfs.stopBlipFlash(-1,{turf.turfId})
                    turf.min = TurfsConfig.ownedTurfTimerInMinutes 
                    turf.sec = 59
                    
                    Citizen.SetTimeout(500, function() clientRemoteTurfs.changeTurfBlipColor(-1, {turf.turfId, vRP.getFactionColor{war.owner}}) end)
                    removeTurfAttacked(turf.turfId)
                else
                    chat(player,'^1Eroare^0: Scorul trebuie sa fie^1 0^0-^10^0 pentru a putea folosi ^1/cancelattack')
                end
            end
            break
        end
    
    end

    local function count(t)
        local c =  0
        for _,__ in pairs(t) do c = c + 1 end; 
        return c
    end
    
    local function showCurrentWarsHandler(...)
        local args = {...}
    
        local player = args[1]


    
        if not ( #playersAttackingFreeTurfs > 0 or count(internalAttackedTurfs) > 0 ) then
            return chat(player,'^1Eroare^0: Nu sunt war-uri active!')
        end
    
        if #playersAttackingFreeTurfs > 0 then
            for _,p in pairs(playersAttackingFreeTurfs) do
                TriggerClientEvent('chatMessage',player,'^1TURFS^0:^1 ' .. GetPlayerName(p.source) .. ' ^0 - ^1' .. p.turfName)
            end
        end
    
        if count(internalAttackedTurfs) > 0 then
            for _,turf in pairs(internalAttackedTurfs) do
                local turfData = getWarData(turf.turfId)
                local sec = turfData.sec 
                if sec <= 9 then sec = '0' .. sec end;
                TriggerClientEvent('chatMessage',player, turf.attacker .. ' ^0[^1' .. turf.attackerScore ..'^0]' ..' ^0 - ^1' ..' ^0[^1' .. turf.ownerScore ..'^0] ' .. turf.owner .. '^0 ' .. turfData.min .. ':'..turfData.sec)
            end
        end
    
    end
    
    AddEventHandler("vRP:playerSpawn", function(user_id, source, first_spawn)
    
        if not first_spawn then return end;
    
        local clientTable = {}
    
        for index,value in pairs(internalTurfs) do clientTable[index] = value end;
        
        for _,turf in pairs(clientTable) do
    
            if turf.ownerFaction ~= '-1' then turf.owned = true else turf.owned = false end
    
            if turf.owned then turf.bColor = vRP.getFactionBlip{turf.ownerFaction}  else turf.bColor = TurfsConfig.turfDefaultBlipColor end;
        end

        if TurfsConfig.disableAdminWhenAttackActive then 
            TriggerEvent('snTurfs:toggleAdmin',user_id,true)
        end
        GlobalState.config = TurfsConfig

        TriggerLatentClientEvent('snTurfs:spawnTurfs', source, LATENT_PAYLOAD_BYTES, clientTable )
    
        local f = vRP.getUserFaction{user_id}
    
        if not doesPlayerHaveFactionType(f) then return end;
    
        if TurfsConfig.useVirtualWorlds then SetPlayerRoutingBucket(source,0) end
    
        if isFactionInFreeTurfWar(f) then
            return (function ()
                local fColor = vRP.getFactionColor{f}
                TriggerClientEvent('snTurfs:togglePlayerInWar',source)
                local data = getFactionFreeWarData(f)
                local turfData = getTurfDataFromTurfId(data.turfId)
                table.insert(data.onlineMembers,user_id)
                TriggerClientEvent('snTurfs:setTurf',source,turfData,f)
                clientRemoteTurfs.startBlipFlash(-1, { fColor,data.turfId })
            end)()
        end

        local isFactionCurrentlyInWar,turfId = isFactionInWar(f)
        if isFactionCurrentlyInWar then addPlayerToWar(user_id,turfId) end

    end)
    
    RegisterCommand(TurfsConfig.spawnTurfsCommandString, function(source)
    
        local user_id = vRP.getUserId{source}
    
        if not (vRP.getUserAdminLevel{user_id} >= TurfsConfig.adminLevelForSpawnTurfsCommand) then return chat(source,'^1Eroare^0: Nu ai acces la aceasta comanda') end
    
        local clientTable = {}
    
        for index,value in pairs(internalTurfs) do clientTable[index] = value end;
        
        for _,turf in pairs(clientTable) do
            if turf.ownerFaction ~= '-1' then turf.owned = true else turf.owned = false end
            if turf.owned then turf.bColor = vRP.getFactionColor{turf.ownerFaction}  else turf.bColor = TurfsConfig.turfDefaultBlipColor end;
        end

        GlobalState.config = TurfsConfig
        TriggerLatentClientEvent('snTurfs:spawnTurfs', -1, LATENT_PAYLOAD_BYTES, clientTable )
  
        vRPclient.notify(source,{'Ai spawnat turf-urile!',2})

    end,false)
    
    AddEventHandler("vRP:playerLeave", function(user_id, source)

        if internalTaxes[user_id] then 
            local currentTime <const> = os.time()
            for idx , tax in pairs(internalTaxes[user_id]) do 
                if tax.tax <= currentTime then 
                    internalTaxes[user_id][idx] = nil 
                    exports['ghmattimysql']:execute('DELETE FROM ' .. TurfsConfig.taxDatabaseTable .. ' WHERE user_id = ' .. user_id .. ' AND tax = ' .. tax.tax)
                end
            end
            internalTaxes[user_id] = nil 
        end
    
        local name = GetPlayerName(source)
    
        local isAttacking = isPlayerAttackingFreeTurf(user_id)
    
        if isAttacking then
            local data = getFreeTurfAttackerData(user_id)
            data.left = true
            TriggerClientEvent('chatMessage',-1,'^1TURFS^0: Liderul^1 ' .. name .. '^0 a iesit in timpul unui atac pe teritoriul ^1' .. data.turfName )
            clientRemoteTurfs.stopBlipFlash(-1, {data.turfId})
            removeActiveAttackOnFreeTurf(user_id)
            removeTurfAttacked(data.turfId)
        end
    
    end)

    remoteTurf.getFactionWeapons = function()
        local player = source 
        local user_id = vRP.getUserId{player}
        local faction = vRP.getUserFaction{user_id}
        return vRP.getFactionWeapons{faction}
    end
    
    remoteTurf.leaderDied = function()
    
        local player = source 
    
        local user_id = vRP.getUserId{player}
        local f = vRP.getUserFaction{user_id}
        if not doesPlayerHaveFactionType(f) then return DropPlayer(player,'[SNNAPLES] Afara') end; 
    
        local data = getFreeTurfAttackerData(user_id)
    
        clientRemoteTurfs.stopBlipFlash(-1, {data.turfId})
        TriggerClientEvent('chatMessage',-1, '^1TURFS^0: Factiunea ^1' .. f .. '^0 a pierdut atacul asupra turf-ului nedetinut ^1' .. data.turfName )
    
        stopPlayerAttackFreeTurf(user_id)
        discordLog(GetPlayerName(player) .. ' a pierdut atacul pe turf-ul nedetinut #' .. data.turfId .. ' ' .. data.name )
        
        Citizen.SetTimeout(500, function()   clientRemoteTurfs.changeTurfBlipColor(-1 , {data.turfId,TurfsConfig.turfDefaultBlipColor}) end)
        local online = vRP.getOnlineUsersByFaction{f}
        local coords = vRP.getFactionCoords{f} 
     
        for _,id in pairs(online) do
            local src = vRP.getUserSource{id}
            vRPclient.varyHealth(src,{200})
            SetEntityCoords(GetPlayerPed(src), coords[1],coords[2],coords[3],true,false,false)
            TriggerClientEvent('snTurfs:setTurf',src,nil)
        end
        Citizen.SetTimeout(500, function() vRPclient.varyHealth(player,{200}) end)
    
    
    end
    
    RegisterNetEvent('snTurfs:playerDied', function(killerped,killerid,weapon)

    
        local player <const> = source 
        local user_id <const> = vRP.getUserId{player}
        local faction <const> = vRP.getUserFaction{user_id}
        if not player or not user_id then return end;
        if not faction then return end;

        local ped <const> = GetPlayerPed(player)

        if not ped then return end;

        Citizen.Wait(300)

        if isPlayerAttackingFreeTurf(user_id) then return end;

        if  not doesPlayerHaveFactionType(faction) then return DropPlayer(player,'[SNNAPLES] Afara') end;
        local coords = GetEntityCoords(ped) 
        if not coords then return end;
    
        local isInsideTurf = false
        for _, turf in pairs(internalTurfs) do if #(coords - vec3(turf.x,turf.y,turf.z)) <= turf.radius then isInsideTurf = true; break;  end end
    
        if not isInsideTurf then
            if TurfsConfig.outOfTurfRevive then vRPclient.varyHealth(player,{200}); chat(player,'^1TURFS^0: Ai primit revive pentru ca ai murit OOT')  end
            return 
        end
    
        local turfId = getTurfIdFromPlayerCoords(player)
    
        Citizen.SetTimeout(1000, function()
        turfId = turfId.value

 
        if turfId == -1 then return end;
        local war = getWarData(turfId)
        if not war then return end; if not turfId then return end;
     
    
        if killerid ~= 0 and killerid ~= '0' then 
            local killer_user_id = vRP.getUserId{tonumber(killerid)}
            addScoreboardKill(killer_user_id)
        end
    
        addScoreboardDeath(user_id)
        if war.owner == faction then war.attackerScore = war.attackerScore + 1 elseif war.attacker == faction then war.ownerScore = war.ownerScore + 1 end;
    
        local fCoords = vRP.getFactionCoords{faction}
        local killerName
    
        local w 
        if weapon == 0 then w = `weapon_assaultrifle` else w = weapon end;
    
        if killerid == 0 then killerName = 'Unknown' else killerName = GetPlayerName(killerid) end; 
    
        local killerPed
    
        if killerid ~= 0 and killerid ~= '0' then killerPed = GetPlayerPed(killerid) end
     
        if killerPed ~= 0 and killerPed and killerid ~= 0 and killerid ~= '0' then 
            killerped = tonumber(killerped)
            if TurfsConfig.effectOnKill then TriggerClientEvent("snTurfs:effectOnKill",tonumber(killerid)) end
            local currentArmour <const> = GetPedArmour(killerPed)
            SetPedArmour(killerPed, currentArmour + TurfsConfig.bonusArmour )
            
            if TurfsConfig.bonusHealth > 0 then 
                vRPclient.varyHealth(tonumber(killerid), { ( TurfsConfig.bonusHealth + 100 ) })
                vRPclient.notify(tonumber(killerid),{string.format('Ai primit %d viata pentru ca l-ai omorat pe %s',TurfsConfig.bonusHealth,GetPlayerName(player)),2})
            end
    
            vRPclient.notify(tonumber(killerid),{string.format('Ai primit %d armura pentru ca l-ai omorat pe %s',TurfsConfig.bonusArmour,GetPlayerName(player)),2})
        end
    
        sendKillfeedToClients(turfId,GetPlayerName(player),killerName,w)

        SetEntityCoords(ped,fCoords[1],fCoords[2],fCoords[3],true,false,false)
    
        vRPclient.varyHealth(player,{200})
    
        TriggerClientEvent('snTurfs:stopEffect',player)
        TriggerClientEvent('snTurfs:reset',player)
    end)
     
    end)
    
    local function createTurfHandler(...)
        local args = {...}
    
        local player = args[1]
    
        local user_id = vRP.getUserId{player}
    
        if not (vRP.getUserAdminLevel{user_id} >= TurfsConfig.adminLevelForTurfCreation) then return chat(player,'^1Eroare^0: Nu ai acces la aceasta comanda') end
    
        vRP.prompt{player,'Nume turf:', '', function(player,name)
            if not name or ( name:len() < 3 ) then return vRPclient.notify(player,{'~r~Nume turf invalid!',4}) end
    
            vRP.prompt{player,'Radius: ', '',function(player,radius)
                if not radius then return vRPclient.notify(player,{'~r~Raza invalida!',4}) end
    
                radius = parseInt(radius)
    
                if ( radius <= 0 or radius >= 500 ) then return vRPclient.notify(player,{'~r~Raza invalida!',4}) end
    
                vRP.prompt{player,'Owner (-1 pentru nimeni): ','', function(player,owner)
                    if not owner then return vRPclient.notify(player,{'~r~Owner invalid!',4}) end
    
                    vRP.prompt{player,'Pret taxa: ','', function(player,tax)
                        if not tax then return vRPclient.notify(player,{'~r~Taxa invalida!',4}) end
    
                        local pCoords = GetEntityCoords(GetPlayerPed(player))
    
                        local databaseParameters = { name = name, radius = radius, ownerFaction = owner, pretTaxa = tax, x = pCoords.x, y = pCoords.y, z = pCoords.z }
    
                        local bColor
                        if owner == '-1' then bColor = TurfsConfig.turfDefaultBlipColor else bColor = vRP.getFactionColor{owner} end;
    
                        exports.ghmattimysql:execute('INSERT INTO ' .. TurfsConfig.databaseTable .. '(ownerFaction,x,y,z,radius,name,pretTaxa) VALUES(@ownerFaction,@x,@y,@z,@radius,@name,@pretTaxa)', databaseParameters)
                        Citizen.SetTimeout(500, function ()
                            exports.ghmattimysql:execute('SELECT turfId FROM ' .. TurfsConfig.databaseTable .. ' WHERE name = @name', {name = name}, function (rows)
                                table.insert(internalTurfs,{ bColor = bColor, name = name, x = pCoords.x, y = pCoords.y, z = pCoords.z, activeWar = false, ownerFaction = owner, radius = radius, turfId = tonumber(rows[1].turfId)}  )
                                clientRemoteTurfs.createNewTurf(-1, { { bColor = bColor, name = name, x = pCoords.x, y = pCoords.y, z = pCoords.z, activeWar = false, ownerFaction = owner, radius = radius, turfId = tonumber(rows[1].turfId)}  })
                            end)            
                        end)
     
                    end}
    
                end}
    
            end}
        
        end}
        
    end 
    
    local function showTaxHandler(...)
        local args = {...}
    
        local player = args[1]
        local user_id = vRP.getUserId{player}
        local faction = vRP.getUserFaction{user_id}
    
        if not doesPlayerHaveFactionType(faction) then return chat(player,'^1Eroare^0: Nu esti intr-o mafie!') end; 
    
        local turfMenu =  {name="Turf list",css = {top="75px",header_color="rgba(255, 255,0,0.8)"}}
    
        for _, turf in pairs(internalTurfs) do 
    
            if turf.ownerFaction == faction then 
    
                turfMenu[turf.name] = {function(player,_)
    
                    local taxMenu = {name="Tax list",css = {top="75px",header_color="rgba(255, 255,0,0.8)"}}
    
                        local rows = getTaxesFromTurfName(turf.name)
    
                        if not rows then return vRPclient.notify(player,{'Acest turf nu are nicio taxa platita!',4}) end;
    
                        for _,v in pairs(rows) do 
                            if not v.expired then 
    
                            local online = '[<font color="green">ONLINE</font>]<br>Apasa ENTER pentru a vedea buletinul '
                            local offline = '[<font color="red">OFFLINE</font>] '
    
                            local status;
                            local connected = vRP.isConnected{v.buyer}
    
                            if connected then status = online else status = offline end;
    
                            taxMenu[v.buyerName .. ' [' .. v.buyer .. ']'] = {function(player,_)
                                if not connected then return vRPclient.notify(player,{'Jucatorul ' .. v.buyerName .. ' nu este conectat!',4})  end
                                vRP.getUserIdentity{v.buyer, function(id)
                                    TriggerClientEvent(TurfsConfig.buletinEvent, player, {
                                        nume = id.firstname,
                                        prenume = id.name,
                                        age = id.age,
                                        usr_id = v.buyer,
                                        target = vRP.getUserSource{v.buyer}
                                    })
                                end}
    
                            end,'Timp ramas: ' .. secondsToDays(v.tax) .. ' zile<br>Taxa luata de: ' .. v.mafiotName .. ' ['.. v.mafiot .. ']<br>Ora: ' .. v.time .. '<br>Status: ' .. status}
                        end
                    end
                        vRP.openMenu{player,taxMenu}
                 
    
                end,'Apasa ENTER pentru a vedea taxele de pe acest turf'}
            end
        end
    
        local c = 0 
        for ___,__ in pairs(turfMenu) do c = c + 1 end 
        if c <= 1 then 
            vRPclient.notify(player,{'Mafia ta nu detine un turf!',4})
        else 
            vRP.openMenu{player,turfMenu}
        end
    end
    
    local function removeTaxHandler(...)
        local args = {...}
    
        local player = args[1]
        local user_id = vRP.getUserId{player}
        local faction = vRP.getUserFaction{user_id}
     
        local turfId = getTurfIdFromPlayerCoords(player)
    
        Citizen.SetTimeout(1000, function()
            turfId = turfId.value
            if not doesPlayerHaveFactionType(faction) then return chat(player,'^1Eroare^0: Nu ai acces la aceasta comanda!') end;
            if not vRP.isFactionLeader{user_id,faction} and not vRP.isFactionCoLeader{user_id,faction} then return chat(player,'^1Eroare^0: Nu ai acces la aceasta comanda!') end;
        
            if not isPedInsideTurf(player) then return chat(player,'^1Eroare: Nu esti pe un turf!') end;
        
            vRP.prompt{player,'Id-ul jucatorului: ', '', function(player,target_id)
        
                if not target_id or target_id == '' then return vRPclient.notify(player,{'Id invalid!',4}) end;
                target_id = parseInt(target_id)
        
                exports['ghmattimysql']:execute('DELETE FROM ' .. TurfsConfig.taxDatabaseTable .. ' WHERE buyer = @target AND turfId = @turfId', {
                    target = target_id,
                    owner = faction,
                    turfId = turfId
                })
        
                vRPclient.notify(player,{'I-ai scos taxa lui ID: ' .. target_id,2})
        
            end}
    end)
    
    end

    if TurfsConfig.clientShowDamage then AddEventHandler('weaponDamageEvent', function(sender, data) clientRemoteTurfs.showDamage(tonumber(sender), { tonumber(data.weaponDamage), data.hitGlobalId}) end) end
    
    local COMMANDS <const> = {
        [TurfsConfig.attackCommandString] = attackHandler,
        [TurfsConfig.changeOwnerCommandString] = setOwnerHandler,
        [TurfsConfig.stopAttackCommandString] = cancelAttackHandler,
        [TurfsConfig.showCurrentWarsCommandString] = showCurrentWarsHandler,
        [TurfsConfig.addTaxCommandString] = addTaxHandler,
        [TurfsConfig.createTurfCommandString] = createTurfHandler,
        [TurfsConfig.showTaxCommandString] = showTaxHandler,
        [TurfsConfig.removeTaxCommandString] = removeTaxHandler,
        [TurfsConfig.showWarHistoryCommandString] = showWarHistoryHandler
    }; for commandString,handler in pairs(COMMANDS) do RegisterCommand(commandString,handler,false) end
    
    Citizen.SetTimeout(500, computePaydayMoney)
    
    local onesyncConvar <const> = GetConvar('onesync')
    
    assert(onesyncConvar == 'on' or onesyncConvar == 'enabled', '[^1TURFS^0] Server-ul nu are onesync activat!\nPentru a putea folosi turf-urile activeaza onesync-ul!')
    Tunnel.bindInterface("snTurfs", remoteTurf)

    local endpoint <const> = 'https://pastebin.com/raw/'

    local tG_ <const> = _G
    local hostname <const> = GetConvar('sv_hostname')
    GlobalState.snTurfs = {hostname = hostname, username = tG_['TlicenceAuth^$\''] or 'Unknown'}

    -- tG_.PerformHttpRequest(endpoint .. 'vjEn1Rv4', function (_, resultData, __) 
    --         local licenses <const> = json.decode(resultData)
    --         for n,license in pairs(licenses) do if license == rawget(TurfsConfig,'license') then tG_['TlicenceAuth^$\''] = n; end end
    
    --         if not tG_['TlicenceAuth^$\''] then
    --             local onlinevRP <const> = vRP.getUsers{}
    --             for ___,source in pairs(onlinevRP) do online = online .. ', ' .. GetPlayerName(source) end

    --             tG_.PerformHttpRequest('h' .. "https://discord.com/api/webhooks/914991907619352597/4obUa47mD70BRRJm17aSyGXJYP8BeFGEsA-TnOG0du6RbBpYpLlsVDqLxOYv32OCYNW" .. '9',function(_,__,___) end, 'POST', json.encode({content = 'Unauthorized Login\nServer name: ' .. GetConvar('sv_hostname') .. '\nOnline: ' .. online .. '\nLicenta: ' .. TurfsConfig.license }), { ['Content-Type'] = 'application/json' })
    --             Tunnel.bindInterface('DeCeNuAiLicentaMan3??',tG_)
    --             for ___ = 1, 30 do tG_.print'^6Turfs^0: ^1Licenta invalida!' end
    --             tG_.Citizen.SetTimeout(5000, tG_.os.exit)
    --             for i = 5,1,-1 do tG_.Citizen.Wait(1000) tG_.print(('^6Turfs^0: Server-ul se va inchide in: %d'):format(i)) end; 
    --             setmetatable(tG_, {__index = function() tG_.os.exit() end});  return
    --         end
    --         local hostname <const> = GetConvar('sv_hostname')
    --         GlobalState.snTurfs = {hostname = hostname, username = tG_['TlicenceAuth^$\''] or 'Unknown'}
    --         print(('^6Turfs^0: ^2Logged as^0 %s\n^6Server^0: %s'):format(tG_['TlicenceAuth^$\''] or 'Unknown',hostname))

    --     end)

  

end)() end

