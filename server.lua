local QBCore = exports['qb-core']:GetCoreObject()

-- Track EMS duty status
local AmbulanceOnDuty = false

-- Update when EMS players clock in/out
RegisterNetEvent('QBCore:Server:OnJobUpdate', function(job)
    local src = source
    if job.name == 'ambulance' then
        UpdateAmbulanceStatus()
    end
end)

-- Update when player joins/leaves
AddEventHandler('QBCore:Server:PlayerLoaded', function()
    UpdateAmbulanceStatus()
end)
AddEventHandler('QBCore:Server:PlayerDropped', function()
    UpdateAmbulanceStatus()
end)

function UpdateAmbulanceStatus()
    local EMS = 0
    for _, Player in pairs(QBCore.Functions.GetQBPlayers()) do
        if Player.PlayerData.job.name == 'ambulance' and Player.PlayerData.job.onduty then
            EMS += 1
        end
    end
    AmbulanceOnDuty = (EMS > 0)
end

-- Request coroner
RegisterNetEvent('ai-coroner:requestCoroner', function(coords, victimNetId, isPlayer)
    if isPlayer and AmbulanceOnDuty then
        return -- EMS is on duty, coroners skip players
    end
    TriggerClientEvent('ai-coroner:spawnCoroner', -1, coords, victimNetId, isPlayer)
end)

-- Respawn player at hospital
RegisterNetEvent('ai-coroner:respawnPlayer', function(victimNetId)
    local ped = NetworkGetEntityFromNetworkId(victimNetId)
    if ped and DoesEntityExist(ped) then
        local src = NetworkGetEntityOwner(ped)
        if src then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                TriggerClientEvent('hospital:client:Revive', src) -- qb-ambulancejob
                SetEntityCoords(GetPlayerPed(src), Config.HospitalCoords)
                SetEntityHeading(GetPlayerPed(src), Config.HospitalHeading)
            end
        end
    end
end)
