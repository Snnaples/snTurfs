--[[
                                                    _______          __            __   ___  
                                                |__   __|        / _|          /_ | / _ \ 
                                        ___ _ __ | |_   _ _ __| |_ ___  __   _| || | | |
                                        / __| '_ \| | | | | '__|  _/ __| \ \ / / || | | |
                                        \__ \ | | | | |_| | |  | | \__ \  \ V /| || |_| |
                                        |___/_| |_|_|\__,_|_|  |_| |___/   \_/ |_(_)___/ 
                                                  
                                                  
]]


do return (function()

                                                                    ::snTurfs:: 

local tunnelTurfs <const> = {}

local FONT <const> = {}

local textFont,ownFaction,ownUserId,ownName,rawScoreboard,inWar,borders = nil,nil,nil,nil,nil,false,false

setmetatable(FONT, {__call = function (_,FONT) Citizen.CreateThread(function() RegisterFontFile(FONT[1]); textFont = RegisterFontId(FONT[2]) end) end})
FONT{'baloochettan2-semibold','Baloo Chettan 2'}

local vRP <const> = Proxy.getInterface[[vRP]]

Tunnel.bindInterface("snTurfs",tunnelTurfs); Proxy.addInterface("snTurfs", { isPlayerInWar = function() return inWar end } )

local remoteServerTurfs <const> = Tunnel.getInterface('snTurfs','snTurfs')

local SendNUI <const> = SendNUIMessage

Citizen.SetTimeout(5000, function() ownName = GetPlayerName(PlayerId()) end) 

local blipTable = {}

-- local Turf = {}
-- Turf.__index = Turf 

-- Turf.new = function (turf)
--     return setmetatable({color = turf.color, coords = turf.positionVector, alphaValue = turf.alphaValue }, Turf ) 
-- end

-- setmetatable(Turf, { __call = function(...) Turf.new(...) end })

local scores = {}

local dText <const> = function(x, y, scale, text, r,g,b, _, centered)
    SetTextFont(textFont)
	SetTextProportional(0)
	SetTextScale(scale, scale)
	if centered then SetTextCentre(true) end
	SetTextColour(r, g, b, 255)
	SetTextDropShadow(0, 0, 0, 0, 150)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextEntry"STRING"
	AddTextComponentString(text)
	DrawText(x, y)
end

local displayingTurfBlips = true 

local internalTurfs = {}

local turfOwners <const> = {}

local turfsSpawned = false 

local cTurf = nil;

local isWeaponBlacklisted <const> = function(weapon)
    for _, blacklistedWeapon in pairs(GlobalState.config.blacklistedWeapons) do if weapon == blacklistedWeapon then return true end end;
    return false
end

RegisterNetEvent('snTurfs:setTurf', function(...) 
    local args = {...}; local t = args[1]; local f = args[2];
    if t == nil then rawScoreboard = nil; SendNUI{ type = 'close'}; SendNUI{ type = 'reset' }; inWar = false; for _,handle in pairs(blipTable) do RemoveBlip(handle) end; end;
    cTurf = t; if f then ownFaction = f end;
 end)

tunnelTurfs.changeTurfBlipColor = function(turfId,newColor)
    for _, turf in pairs(internalTurfs) do if turf.turfId == turfId then SetBlipColour(turf.blipHandle,newColor) end end;
end

local min,sec = 20,59

tunnelTurfs.showTeammateBlips = function (teamTable)
    if type(teamTable) ~= 'table' then return end;

    if #blipTable > 0 then for _,handle in pairs(blipTable) do RemoveBlip(handle) end; blipTable = {} end;

    for _,player in pairs(teamTable) do 
        if player.name ~= ownName and player.faction == ownFaction then 
            local blip = AddBlipForCoord(player.x+0.001,player.y+0.001,player.z+0.001) 
            SetBlipSprite(blip, 2)
            SetBlipAsShortRange(blip, true)
            SetBlipColour(blip,69)
            SetBlipScale(blip, GlobalState.config.teammateBlipScale)
            BeginTextCommandSetBlipName"STRING"
            AddTextComponentString(player.name)
            EndTextCommandSetBlipName(blip)
            table.insert(blipTable,blip)
        end
    end  
end

tunnelTurfs.updateRemainingTurfTime = function(mins,secs) min = mins; sec = secs end;

tunnelTurfs.displayFreeTurfTimer = function(displayScores)

    if inWar and GlobalState.config.defaultGetWeaponsWhenWarStarts then 
        local p <const> = PlayerPedId()
        for _, weaponString in pairs(GlobalState.config.freeWeaponsTable) do GiveWeaponToPed(p,GetHashKey'WEAPON_' .. weaponString, 255, false, false); end;
    end

    local yOffset = 0.45
	local axisOffset = -0.01

    Citizen.CreateThread(function()
        if not GlobalState.config.defaultShowScore then while scores.attackerScore == 0 and scores.defenderScore == 0 do Citizen.Wait(1500) end  end
        while cTurf and scores and inWar do
            Citizen.Wait(4)
            local xOffset = 0
            if min and min >= 10 then xOffset = 0.01 end
            if min and min <= 1 then dText(0.477-axisOffset, 0.4848-yOffset, 0.8, tostring(min), 250, 45, 45, 0) if min == 1 then dText(0.494-axisOffset, 0.491-yOffset, 0.3, "minut", 250, 45, 45, 1) else dText(0.494-axisOffset, 0.491-yOffset, 0.3, "minute", 250, 45, 45, 1) end else dText(0.478-xOffset-axisOffset, 0.4848-yOffset, 0.8, tostring(min), 40, 143, 240, 0) dText(0.494-axisOffset, 0.491-yOffset, 0.3, "minute", 40, 143, 240, 1) end
            local d = sec if d then if d <= 9 then d = '0' .. d end; end
            dText(0.491-axisOffset, 0.502-yOffset, 0.45, ":", 255, 255, 255, 0); dText(0.494-axisOffset, 0.5-yOffset, 0.5, d, 255, 255, 255, 0)
            if scores and displayScores then dText(0.4, 0.0511, 0.45, tostring(scores.defenderScore), 41, 217, 65, 0, true); dText(0.6, 0.0511, 0.45,tostring(scores.attackerScore), 237, 55, 73, 0, true); dText(0.4, 0.04, 0.35, tostring(scores.defender), 41, 217, 65, 1, true) dText(0.6, 0.04, 0.35, scores.attacker, 237, 55, 73, 1, true);  end
        end
        StopScreenEffect"MP_race_crash"
    end)
end

tunnelTurfs.stopBlipFlash = function(turfId)
    for _, turf in pairs(internalTurfs) do if turf.turfId == turfId then turf.activeWar = false end end;
end

tunnelTurfs.updateScores = function(sScores) scores = sScores end;

local wasInTurf = false 
    
local onceEffect = false

local scoreboardFactions = {}

local stopEffectHandler <const> = function() StopScreenEffect"MP_race_crash"; onceEffect = false; wasInTurf = false; end;
local effectOnKillHandler <const> = function () StartScreenEffect("SuccessFranklin", 1000, 0); vRP.playSound{"DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", "Mission_Pass_Notify"} end
 
RegisterNetEvent('snTurfs:stopEffect', stopEffectHandler); RegisterNetEvent('snTurfs:effectOnKill',effectOnKillHandler);

tunnelTurfs.updateScoreboard = function (scoreboard,user_id,factions)
    if type(scoreboard) == 'table' then rawScoreboard = scoreboard ownUserId = user_id end if factions then scoreboardFactions = factions end
end

tunnelTurfs.startBlipFlash = function(color,turfId)
    local ped <const> = PlayerPedId()

    for _, turf in pairs(internalTurfs) do
        if turf.turfId == turfId then
            turf.activeWar = true
            local cycle = false
            local oldColor <const> = GetBlipColour(turf.blipHandle)

            Citizen.CreateThread(function() 
                while inWar and cTurf and cTurf.turfId == turf.turfId do
                    Wait(1000)
                    while cTurf and tunnelTurfs.isPlayerInsideTurf(cTurf) and  inWar do 
                       Citizen.Wait(0)
                       local _, weapon = GetCurrentPedWeapon(ped, true)

                        if isWeaponBlacklisted(weapon) then
                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, false)
                            vRP.notify{"Arma interzisa la war!",4}
                        end
                        DisableControlAction(0,48,true); DisableControlAction(0,20,true); if not cTurf then return end;
                    end
                end
            end)

            Citizen.CreateThread(function()
                while inWar and cTurf and cTurf.turfId == turf.turfId  do
                    Citizen.Wait(1000)
                    while cTurf and not tunnelTurfs.isPlayerInsideTurf(cTurf) and inWar do
                        Citizen.Wait(0)
                       
                        DisableControlAction(0,24,true)
                        DisableControlAction(0,25,true)
                        DisableControlAction(0,142,true)
                        DisableControlAction(0,223,true)
                        DisableControlAction(0,237,true)
                        DisableControlAction(0,257,true)
                        DisableControlAction(0,329,true)
                        DisableControlAction(0,229,true)
                        if not cTurf then return end;
                    end
                end
                StartScreenEffect("SuccessFranklin", 1000, 0)
                vRP.playSound{"DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", "Mission_Pass_Notify"}
            end)

            Citizen.CreateThread(function()
                while turf and turf.activeWar  do
                    if not cycle then SetBlipColour(turf.blipHandle,color) else SetBlipColour(turf.blipHandle,oldColor) end;
                    cycle = not cycle
                    if cTurf and cTurf.turfId == turf.turfId  then
                        if tunnelTurfs.isPlayerInsideTurf(cTurf) then
                            StopScreenEffect"MP_race_crash"
                            wasInTurf = true
                            onceEffect = false
                        else
                            if wasInTurf then
                                if not onceEffect then
                                    onceEffect = true 
                                    StartScreenEffect("MP_race_crash", 0, false)
                                end
                            end 
                        end
                    end
                    Citizen.Wait(1000)
                end
            end)
        end
    end
end

tunnelTurfs.changeTurfOwnerFaction = function(turfId,newOwnerFaction)
    for _, turf in pairs(internalTurfs) do if turf.turfId == turfId then turf.ownerFaction = newOwnerFaction turfOwners[turfId] = newOwnerFaction end end;
end

local setLeaderInWarHandler <const> = function ()
    while inWar do
        Citizen.Wait(1500)
        if GetEntityHealth(PlayerPedId()) <= GlobalState.config.comaThreshold then remoteServerTurfs.leaderDied{}; break end;
    end
end

tunnelTurfs.setLeaderInFreeTurfWar = function() Citizen.CreateThread(setLeaderInWarHandler) end

RegisterNetEvent('snTurfs:togglePlayerInWar', function() inWar = not inWar end )

tunnelTurfs.createNewTurf = function(turf)
    local blipVector <const> = vec3(turf.x,turf.y,turf.z)
    local turfBlip
    if not GlobalState.config.squareTurfs then turfBlip = AddBlipForRadius(blipVector,( turf.radius + 0.01 ) ) else turfBlip = AddBlipForArea(blipVector,v.radius + .1, v.radius + .1); SetBlipRotation(turfBlip,0); SetBlipAsShortRange(turfBlip,true) end

    if GlobalState.config.centerBlip then
        local start = 501 
        vRP.addBlip{blipVector[1],blipVector[2],blipVector[3],start + turf.turfId,turf.bColor , '[TURF] ' .. turf.name}
    end
 

    SetBlipColour(turfBlip,turf.bColor)

    local alphaValue = ( GlobalState.config.defaultDisplayClientBlips and 150 ) or 0

    SetBlipAlpha(turfBlip,alphaValue)

    turf.blipHandle = turfBlip
    turf.blipAlpha = alphaValue

    table.insert(internalTurfs, turf )
end


local spawnTurfsHandler <const> = RegisterNetEvent('snTurfs:spawnTurfs', function(turfsTable)

 
    if turfsSpawned then return end;

    if not (type(turfsTable) == 'table') then return end;

    if GlobalState.config.clientShowDamage then 
        local damageCache <const> = {}
        local damageYOffset = -1
        function tunnelTurfs.showDamage(dmg,sender); if not inWar then return end;
                if damageCache[sender] then 
                    damageCache[sender].time = damageCache[sender].time + 1000
                    damageCache[sender].totalDamage = math.min(damageCache[sender].totalDamage + dmg,200)
                    return 
                end
                damageCache[sender] = {time = GetGameTimer() + 1500, totalDamage = math.min(dmg,200)}
                damageYOffset = damageYOffset + 1
                local yText = 0.49 + (damageYOffset * 0.011)
                while GetGameTimer() < damageCache[sender].time do 
                    Citizen.Wait(2)
                    dText(0.53, yText, 0.3,damageCache[sender].totalDamage, 252, 78, 66, 2, 1)
                end 
                damageCache[sender] = nil 
                damageYOffset = damageYOffset - 1
            end
    end

    if GlobalState.config.squareTurfs then 
        tunnelTurfs.isPlayerInsideTurf = function(v); local pCoords <const> = GetEntityCoords(PlayerPedId())
            if v then return IsPointInAngledArea(pCoords[1],pCoords[2],pCoords[3],v.x,v.y+v.radius/2,v.z,  v.x,v.y-v.radius/2,v.y,  v.radius, 0, false)  end
            for _, v in pairs(internalTurfs) do if IsPointInAngledArea(pCoords[1],pCoords[2],pCoords[3],v.x,v.y+v.radius/2,v.z,  v.x,v.y-v.radius/2,v.y,  v.radius, 0, false) then return true  end end
            return false
        end; tunnelTurfs.getTurfIdFromPlayerCoords = function() for _,v in pairs(internalTurfs) do  if tunnelTurfs.isPlayerInsideTurf(v) then  return v.turfId end end return -1
        end
    else
        tunnelTurfs.isPlayerInsideTurf = function(v); local pCoords <const> = GetEntityCoords(PlayerPedId())
            if v then return #(pCoords - vector3(v.x,v.y,v.z)) <= v.radius end
            for _, v in pairs(internalTurfs) do  if #(pCoords - vector3(v.x,v.y,v.z)) <= v.radius then  return true  end end
            return false
        end
    end

    turfsSpawned = true 

    for _,turf in pairs(turfsTable) do

        local blipVector <const> = vec3(turf.x,turf.y,turf.z)
        local turfBlip;
        if not GlobalState.config.squareTurfs  then turfBlip =  AddBlipForRadius(blipVector,( turf.radius + 0.01 ) ) else turfBlip = AddBlipForArea(blipVector,turf.radius + .1, turf.radius + .1); SetBlipRotation(turfBlip,0); SetBlipAsShortRange(turfBlip,true) end
        if GlobalState.config.centerBlip then
            local start = 501 
            vRP.addBlip{blipVector[1],blipVector[2],blipVector[3],start + turf.turfId, turf.bColor, '[TURF] ' .. turf.name}
        end
        SetBlipColour(turfBlip,turf.bColor)

        local alphaValue <const> = ( GlobalState.config.defaultDisplayClientBlips and 150 ) or 0

        SetBlipAlpha(turfBlip,alphaValue)

        turf.blipHandle = turfBlip; turf.blipAlpha = alphaValue

        table.insert(internalTurfs, turf )

    end

    local toggleDisplayTurfs <const> = function()

        displayingTurfBlips = not displayingTurfBlips 
        local alphaValue
    
        local status = 'activat'

        if displayingTurfBlips then alphaValue = 150 else alphaValue = 0; status = 'dez' .. status end;
    
        for _,turf in pairs(internalTurfs) do SetBlipAlpha(turf.blipHandle,alphaValue) end
    
        vRP.notify{('Ai %s turf-urile'):format(status)}
    
    end

    local killfeedHandler <const> = function (t)
        t.weapon = GlobalState.config.killfeedWeapons[t.weapon]; t.type = 'newKill'; SendNUI(t)
    end; RegisterNetEvent(GlobalState.config.killfeedEvent, killfeedHandler)

    local scoreboardActive = false

    local showScoreboardHandler <const> = function (); CancelEvent()

    if scoreboardActive then  scoreboardActive = false; return SendNUI {type = 'close'} end

    if rawScoreboard ~= nil then 

        local once = false;
        scoreboardActive = true 

        local serialScoreboard <const> = {}

        for k,v in pairs(rawScoreboard) do
            if k == ownUserId then 
                if not once then 
                    v.name = ('<font color="green">%s</font>'):format(ownName)
                    once = true 
                end
            end
            if scoreboardFactions[1] == v.faction or scoreboardFactions[2] == v.faction then 
                table.insert(serialScoreboard, { html =  ('<tr><td>%s</td><td><span style="color:white;">%s</span></td><td>%s</td><td>%s</td><td>%s</td>'):format(v.name, v.kills, v.deaths,v.faction,v.kda), kills = v.kills, user_id = k })
            end
        end
        table.sort(serialScoreboard,function (a,b)  return a.kills > b.kills end); SendNUI{ type = 'show', scoreboard = serialScoreboard }
        end
    end

    RegisterCommand('showScoreboard',showScoreboardHandler,false)
    RegisterKeyMapping('showScoreboard','Turfs Scoreboard','keyboard',GlobalState.config.scoreboardKey)
    RegisterCommand(GlobalState.config.toggleTurfsCommandString,toggleDisplayTurfs,false)
    exports("toggleTurfs",toggleDisplayTurfs)


    SetTimeout(500, function() Citizen.Trace(('Started as ^6%s^0 on ^6%s^0 [%s]\n'):format(GetCurrentResourceName(), GlobalState.snTurfs.hostname,GlobalState.snTurfs.username)) end )   
     

    if GlobalState.config.freeWeaponsCommandString ~= 'none' and GlobalState.config.freeWeaponsCommandString then
        local function freeWeaponsHandler()
            if not inWar then return end;
            local p <const> = PlayerPedId()

            remoteServerTurfs.getFactionWeapons({}, function(weapons)
                if #weapons < 1 then return end;
                
                for _, weaponString in pairs(weapons) do GiveWeaponToPed(p,GetHashKey('WEAPON_' .. weaponString), 255, false, false); end
                vRP.notify{'Ai primit armele de la war!',2}
                
            end)

         
        end; RegisterCommand(GlobalState.config.freeWeaponsCommandString,freeWeaponsHandler,false)
    end

    if GlobalState.config.clientBorders then 
        local function bordersHandler()
            if GlobalState.config.squareTurfs then return end;
            if not inWar or not cTurf then return vRP.notify{'Nu esti intr-un war!'} end;

            borders = not borders
            local status = 'activat'
            if not borders then status = 'dez' .. status end;
            vRP.notify{('Ai %s borderele'):format(status)}

            local colorVector <const> = GlobalState.config.clientBordersColor
                Citizen.CreateThread(function()
                    while cTurf and borders do 
                        Citizen.Wait(2)
                        local scale <const> = (cTurf.radius + 0.0) * 2
                        DrawMarker(1, cTurf.x, cTurf.y, cTurf.z - cTurf.radius, 0, 0, 0, 0, 0, 0, scale, scale, (100 + 0.0) + cTurf.radius * 2, colorVector[1], colorVector[2], colorVector[3], 220, 0, 0, 2, 0)
                    end
                end)

        end; RegisterCommand(GlobalState.config.clientBordersCommandString,bordersHandler,false)
    end

    if not GlobalState.config.showClientCurrentTurf then return end;

    for _,turf in pairs(turfsTable) do turfOwners[turf.turfId] = turf.ownerFaction end

    Citizen.CreateThread(function()
        while 1 do
            Citizen.Wait(1500)
            for _,turf in pairs(internalTurfs) do
                 if tunnelTurfs.isPlayerInsideTurf(turf) then
                        while tunnelTurfs.isPlayerInsideTurf(turf) do
                                Citizen.Wait(4)    
                                local turfName <const> = turf.name
                                local owner = '~n~' .. ( ( (turfOwners[turf.turfId] == '-1') and '~r~Nedetinut' ) or turf.ownerFaction ) 
                                local dText <const> = GlobalState.config.clientCurrentTurfDisplayText .. turfName .. owner
                                SetTextFont(textFont)
                                SetTextCentre(1)
                                SetTextProportional(0)
                                SetTextScale(0.3, 0.3)
                                SetTextDropShadow(30, 5, 5, 5, 255)
                                SetTextEntry"STRING"
                                SetTextColour(255, 255, 255, 255)
                                AddTextComponentString(dText)
                                DrawText(0.255,0.92)
                        end
                 end
            end
        end
    end)
end)

print(GetPlayerName(32))

end)() end

