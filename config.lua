--[[
                                                    _______          __            __   ___  
                                                |__   __|        / _|          /_ | / _ \ 
                                        ___ _ __ | |_   _ _ __| |_ ___  __   _| || | | |
                                        / __| '_ \| | | | | '__|  _/ __| \ \ / / || | | |
                                        \__ \ | | | | |_| | |  | | \__ \  \ V /| || |_| |
                                        |___/_| |_|_|\__,_|_|  |_| |___/   \_/ |_(_)___/ 
                                                  
                                                  
]]

TurfsConfig  = {

    databaseTable = 'sn_turfs', -- cum se numeste tabelul in baza de date
    taxDatabaseTable = 'sn_taxe',
    historyDatabaseTable = 'sn_wars', -- tabelul pentru history-ul la war
    taxDays = 1, -- cate zile sa dureze o taxa
    buletinEvent = 'showBuletin', -- numele event-ului din plesIds; respect ples
    killfeedEvent = 'KillFeed:AnnounceKill',
    factionTypesForWar = {'Mafie'}, -- fType din vrp/cfg/factions, ce fType-uri pot juca la war
    killfeedColors = {'#ff2323','#00a500'}, -- primul este rosu, al doilea este verde
    sanitizeKillfeedNames = true, -- sterge cateva caractere din numele jucatorilor din killfeed, in caz ca killfeed-ul este vulnerabil la XSS
    warDays = {'Luni','Marti','Miercuri','Joi','Vineri','Sambata','Duminica'}, -- in ce zile se pot da war-uri
    timeInterval = {0,24}, -- interval orar, aici de exemplu este ora 20:00 intre 22:00
    minOnlinePlayers = 0,
    turfDefaultBlipColor = 37, -- culoarea la turf-urile nedetinute default
    attackCommandString = 'attack', -- cum sa se numeasca comanda de a ataca un turf 
    attackCooldown = 1, -- cooldown la attack in minute, -1 pentru nimic 
    changeOwnerCommandString =  'setowner', -- cum sa se numeasca comanda de a schimba owner-ul unui turf 
    stopAttackCommandString = 'cancelattack',
    showCurrentWarsCommandString = 'war',
    toggleTurfsCommandString = 'turfs',
    freeWeaponsCommandString = 'arme', 
    createTurfCommandString = 'createturf',
    showWarHistoryCommandString = 'wars',
    addTaxCommandString = 'tax',
    showTaxCommandString = 'taxe',
    spawnTurfsCommandString = 'spawnturfs',
    removeTaxCommandString = 'removetax',
    scoreboardKey = 'M', --tasta pentru scoreboard
    defaultDisplayClientBlips = true,-- daca sa apara pe harta blipurile ca default sau sa dai /turfs
    showClientCurrentTurf = true, -- daca sa apara un text cu turful actual
    useVirtualWorlds = true,
    centerBlip = false, -- daca sa fie un blip cu id-ul turfului pe mijloc
    effectOnKill = true, -- daca sa ai un efect pe ecran cand faci kil
    showTeammatesOnMap = false, -- daca sa apara coechipieri pe harta
    disableAdminWhenAttackActive = true, -- daca sa iti scoata admin-ul cand esti in war
    outOfTurfRevive = true, -- daca vrei ca cei care mor oot sa primeasca revive 
    defaultShowScore = true,  -- true = scorul apare din prima, false = scorul nu apare daca este 0-0
    defaultGetWeaponsWhenWarStarts = true, -- daca sa primesti arme cand incepe war-ul 
    outcomeWhenScoreIsEqual = "defender", -- 2 optiuni: attacker si defender, daca scorul este egal optiunea selectata va castiga turf-ul
    clientCurrentTurfDisplayText = '[~r~turf~w~] ',
    clientBorders = true, 
    clientBordersCommandString = 'turfborders', -- comanda de bordere
    freeTurfTimerInMinutes = 5, -- timp turf pentru turf nedetinut
    ownedTurfTimerInMinutes = 0, -- timp turf pentru mafie vs mafie
    bonusArmour = 20,
    bonusHealth = 0,
    teammateBlipScale = 0.5, -- cat de mare sa fie blip-ul de coechipioer pe harta
    adminLevelForTurfCreation = 5,-- admin level necesar pentru a crea un turf nou
    adminLevelForSpawnTurfsCommand = 5, -- admin level necesar pentru a folosi /spawnturfs
    comaThreshold = 105,
    turfPayday = 1500, -- 1500 per turf , -1 pentru nimic
    turfPaydayMinutes = 20,
    attackedTurfCooldown = 2, -- daca un turf a fost atacat recent, nimeni nu il mai poate ataca pentru X minute, in cazul asta 2 minute
    maxTurfs = 7, -- numarul maxim de turf-uri pe care le poate avea o mafie
    freeWeaponsTable = {'PISTOL50','CARBINERIFLE','KNIFE'} -- armele pe care le primesc jucatori la inceperea war-ului

}

TurfsConfig.license = '0xff' -- licenta ta

TurfsConfig.squareTurfs = false -- turf-uri patrate

TurfsConfig.discordWebhook = '' -- lasa gol daca nu vrei loguri

TurfsConfig.latentEventPayloadInBytes = math.floor(2^10) -- 1024

TurfsConfig.useAchievements = false -- lasa false !

TurfsConfig.clientBordersColor = vec3(255,255,255) -- culoare bordere, default = alb

TurfsConfig.remoteConfigRequest = false 

TurfsConfig.clientShowDamage = false -- daca sa arate cat damage dai

TurfsConfig.adminExceptions = {69,62,1} 

TurfsConfig.blacklistedWeapons = {
    "sniperrifle",
    "heavysniper",
    "heavysniper_mk2",
    "marksmanrifle",
    "revolver",
    "marksmanrifle_mk2",
    "heavyshotgun",
    "bullpupshotgun",
    "pumpshotgun_mk2",
    "heavysniper_mk2", 
    "heavysniper",
    "revolver_mk2",
    "revolver",
    'marksmanrifle',
    "navyrevolver_mk2",
    "navyrevolver",
    "combatmg_mk2",
    "combatmg"
}

TurfsConfig.killfeedWeapons = { [-1569615261] = 'weapon_unarmed', [-1716189206] = 'weapon_knife', [1737195953] = 'weapon_nightstick', [1317494643] = 'weapon_hammer', [-1786099057] = 'weapon_bat', [-2067956739] = 'weapon_crowbar', [1141786504] = 'weapon_golfclub', [-102323637] = 'weapon_bottle', [-1834847097] = 'weapon_dagger', [-102973651] = 'weapon_hatchet', [940833800] = 'weapon_stone_hatchet', [-656458692] = 'weapon_knuckle', [-581044007] = 'weapon_machete', [-1951375401] = 'weapon_flashlight', [-538741184] = 'weapon_switchblade', [-1810795771] = 'weapon_poolcue', [419712736] = 'weapon_wrench', [-853065399] = 'weapon_battleaxe', [453432689] = 'weapon_pistol', [-1075685676] = 'weapon_pistol_mk2', [1593441988] = 'weapon_combatpistol', [-1716589765] = 'weapon_pistol50', [-1076751822] = 'weapon_snspistol', [-2009644972] = 'weapon_snspistol_mk2', [-771403250] = 'weapon_heavypistol', [137902532] = 'weapon_vintagepistol', [-598887786] = 'weapon_marksmanpistol', [-1045183535] = 'weapon_revolver', [-879347409] = 'weapon_revolver_mk2', [-1746263880] = 'weapon_doubleaction', [584646201] = 'weapon_appistol', [911657153] = 'weapon_stungun', [1198879012] = 'weapon_flaregun', [324215364] = 'weapon_microsmg', [-619010992] = 'weapon_machinepistol', [736523883] = 'weapon_smg', [2024373456] = 'weapon_smg_mk2', [-270015777] = 'weapon_assaultsmg', [171789620] = 'weapon_combatpdw', [-1660422300] = 'weapon_mg', [2144741730] = 'weapon_combatmg', [-608341376] = 'weapon_combatmg_mk2', [1627465347] = 'weapon_gusenberg', [-1121678507] = 'weapon_minismg', [-1074790547] = 'weapon_assaultrifle', [961495388] = 'weapon_assaultrifle_mk2', [-2084633992] = 'weapon_carbinerifle', [-86904375] = 'weapon_carbinerifle_mk2', [-1357824103] = 'weapon_advancedrifle', [-1063057011] = 'weapon_specialcarbine', [-1768145561] = 'weapon_specialcarbine_mk2', [2132975508] = 'weapon_bullpuprifle', [-2066285827] = 'weapon_bullpuprifle_mk2', [1649403952] = 'weapon_compactrifle', [100416529] = 'weapon_sniperrifle', [205991906] = 'weapon_heavysniper', [177293209] = 'weapon_heavysniper_mk2', [-952879014] = 'weapon_marksmanrifle', [1785463520] = 'weapon_marksmanrifle_mk2', [487013001] = 'weapon_pumpshotgun', [1432025498] = 'weapon_pumpshotgun_mk2', [2017895192] = 'weapon_sawnoffshotgun', [-1654528753] = 'weapon_bullpupshotgun', [-494615257] = 'weapon_assaultshotgun', [-1466123874] = 'weapon_musket', [984333226] = 'weapon_heavyshotgun', [-275439685] = 'weapon_dbshotgun', [317205821] = 'weapon_autoshotgun', [-1568386805] = 'weapon_grenadelauncher', [-1312131151] = 'weapon_rpg', [1119849093] = 'weapon_minigun', [2138347493] = 'weapon_firework', [1834241177] = 'weapon_railgun', [1672152130] = 'weapon_hominglauncher', [1305664598] = 'weapon_grenadelauncher_smoke', [125959754] = 'weapon_compactlauncher', [-1813897027] = 'weapon_grenade', [741814745] = 'weapon_stickybomb', [-1420407917] = 'weapon_proxmine', [-1600701090] = 'weapon_bzgas', [615608432] = 'weapon_molotov', [101631238] = 'weapon_fireextinguisher', [883325847] = 'weapon_petrolcan', [-544306709] = 'weapon_petrolcan', [1233104067] = 'weapon_flare', [600439132] = 'weapon_ball', [126349499] = 'weapon_snowball', [-37975472] = 'weapon_smokegrenade', [-1169823560] = 'weapon_pipebomb', [-72657034] = 'weapon_parachute', [-1238556825] = 'weapon_rayminigun', [-1355376991] = 'weapon_raypistol', [1198256469] = 'weapon_raycarbine' }
local remoteConfigHandler <const> = RegisterNetEvent('snTurfs:requestRemoteConfig', function() GlobalState.config = TurfsConfig end)

if not TurfsConfig.remoteConfigRequest then RemoveEventHandler(remoteConfigHandler) end

setmetatable(TurfsConfig, { ['__call'] = function ()
    
        if not rawget(TurfsConfig,'license') then return error'Licenta invalida!' end 

         -- imi da erori in vscode daca folosesc `` pentru hash-uri si nu-mi place asa ca asta este:)!
        for indx,n in pairs(TurfsConfig.blacklistedWeapons) do TurfsConfig.blacklistedWeapons[indx] = Citizen.InvokeNative(0x98EFF6F1,("weapon_%s"):format(n)) end;

        local weekDays <const> = { ['Monday'] = 'Luni', ['Tuesday'] = 'Marti', ['Wednesday'] = 'Miercuri', ['Thursday'] = 'Joi', ['Friday'] = 'Vineri', ['Saturday'] = 'Sambata', ['Sunday'] = 'Duminica' }

        local isWarDay <const> = function()
            if TurfsConfig.warDays[1] == '*' then return true end;
            local currentDay <const> = weekDays[os.date"%A"]:lower()

            for _,day in pairs(TurfsConfig.warDays) do  if day:lower() == currentDay then return true end; end
            return false
        end

        rawset(TurfsConfig,'isWarDay',isWarDay)

end, __index = os}); TurfsConfig()

