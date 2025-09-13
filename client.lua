local QBCore = exports['qb-core']:GetCoreObject()

-- Detect deaths
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]
        if DoesEntityExist(victim) and IsEntityDead(victim) then
            local pedType = GetPedType(victim)
            if pedType ~= 28 then -- skip animals
                local coords = GetEntityCoords(victim)
                TriggerServerEvent('ai-coroner:requestCoroner', coords, NetworkGetNetworkIdFromEntity(victim), IsPedAPlayer(victim))
            end
        end
    end
end)

-- Load anim dict
local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

-- Spawn coroner unit
RegisterNetEvent('ai-coroner:spawnCoroner', function(coords, victimNetId, isPlayer)
    local victim = NetworkGetEntityFromNetworkId(victimNetId)
    local pedModel, vehModel = Config.CoronerPed, Config.CoronerVan

    RequestModel(pedModel) while not HasModelLoaded(pedModel) do Wait(10) end
    RequestModel(vehModel) while not HasModelLoaded(vehModel) do Wait(10) end

    local spawnCoords = coords + vector3(15.0, 15.0, 0.0)
    local heading = GetEntityHeading(PlayerPedId())

    local vehicle = CreateVehicle(vehModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, true)
    local driver = CreatePedInsideVehicle(vehicle, 4, pedModel, -1, true, false)
    local helper = CreatePedInsideVehicle(vehicle, 4, pedModel, 0, true, false)

    SetEntityAsMissionEntity(vehicle, true, true)
    SetEntityAsMissionEntity(driver, true, true)
    SetEntityAsMissionEntity(helper, true, true)

    TaskVehicleDriveToCoord(driver, vehicle, coords.x, coords.y, coords.z, 15.0, 1, vehModel, 16777216, 2.0)

    CreateThread(function()
        -- Wait until arrival
        while #(GetEntityCoords(vehicle) - coords) > 8.0 do Wait(500) end

        TaskLeaveVehicle(driver, vehicle, 0)
        TaskLeaveVehicle(helper, vehicle, 0)
        Wait(4000)

        -- Animations
        LoadAnimDict("amb@medic@standing@kneel@base")
        LoadAnimDict("missfam4")

        TaskGoStraightToCoord(driver, coords.x+1.0, coords.y, coords.z, 1.0, -1, 0.0, 0.0)
        TaskGoStraightToCoord(helper, coords.x-1.0, coords.y, coords.z, 1.0, -1, 0.0, 0.0)
        Wait(3000)

        -- Driver kneels, helper writes notes
        TaskPlayAnim(driver, "amb@medic@standing@kneel@base", "base", 3.0, -1, -1, 1, 0, false, false, false)
        TaskPlayAnim(helper, "missfam4", "base", 3.0, -1, -1, 1, 0, false, false, false)

        -- Spawn stretcher/body bag
        local bag = CreateObject(`prop_ld_binbag_01`, coords.x, coords.y, coords.z, true, true, true)
        PlaceObjectOnGroundProperly(bag)
        Wait(6000)

        -- Remove body
        if DoesEntityExist(victim) and IsEntityDead(victim) then
            if isPlayer then
                TriggerServerEvent('ai-coroner:respawnPlayer', victimNetId)
            else
                DeleteEntity(victim)
            end
        end

        -- Load bag into van
        AttachEntityToEntity(bag, helper, GetPedBoneIndex(helper, 28422), 0.1, 0.0, -0.1, 0.0, 0.0, 90.0, true, true, false, true, 1, true)
        Wait(3000)
        DetachEntity(bag, true, true)
        DeleteEntity(bag)

        -- Clear anims
        ClearPedTasks(driver)
        ClearPedTasks(helper)
        Wait(1000)

        -- Return to van
        TaskEnterVehicle(driver, vehicle, -1, -1, 1.0, 1, 0)
        TaskEnterVehicle(helper, vehicle, -1, 0, 1.0, 1, 0)
        Wait(4000)

        -- Drive away + despawn
        TaskVehicleDriveWander(driver, vehicle, 25.0, 786603)
        Wait(15000)

        DeleteEntity(driver)
        DeleteEntity(helper)
        DeleteEntity(vehicle)

        -- Cleanup abandoned vehicles
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - coords) < Config.CleanupRadius and not IsPedAPlayer(GetPedInVehicleSeat(veh, -1)) then
                DeleteEntity(veh)
            end
        end
    end)
end)
