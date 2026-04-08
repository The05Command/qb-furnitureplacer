local QBCore = exports['qb-core']:GetCoreObject()

local spawnedFurniture = {}
local isPlacing = false

local function debugPrint(...)
    if Config.Debug then
        print('^3[qb-furniture-v3]^7', ...)
    end
end

local function notify(msg, nType)
    QBCore.Functions.Notify(msg, nType or 'primary')
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timeout then
            return nil
        end
    end

    return hash
end

local function rotationToDirection(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosX = math.cos(rotX)

    return vector3(
        -math.sin(rotZ) * cosX,
        math.cos(rotZ) * cosX,
        math.sin(rotX)
    )
end

local function raycastFromGameplayCam(distance)
    local camRot = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local direction = rotationToDirection(camRot)
    local destination = camCoord + (direction * distance)

    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        destination.x, destination.y, destination.z,
        -1,
        PlayerPedId(),
        0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, surfaceNormal, entityHit, destination
end

local function raycastDown(coords, ignoreEntity)
    local startPos = vector3(coords.x, coords.y, coords.z + 8.0)
    local endPos = vector3(coords.x, coords.y, coords.z - 15.0)

    local rayHandle = StartShapeTestRay(
        startPos.x, startPos.y, startPos.z,
        endPos.x, endPos.y, endPos.z,
        -1,
        ignoreEntity or 0,
        0
    )

    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, surfaceNormal, entityHit
end

local function getForwardFallbackCoords(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    return coords + (forward * distance)
end

local function getSurfacePlacementCoords(previewEntity, fallbackCoords)
    local hit, hitCoords = raycastFromGameplayCam(Config.PlaceDistance)
    local targetCoords = hit and hitCoords or fallbackCoords

    if not targetCoords then
        return false, nil, nil, 'No placement surface found'
    end

    local downStart = vector3(targetCoords.x, targetCoords.y, targetCoords.z + 1.5)
    local downHit, downCoords, surfaceNormal, entityHit = raycastDown(downStart, previewEntity)

    if not downHit then
        return false, nil, nil, 'Object needs support underneath'
    end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(previewEntity))
    local finalCoords = vector3(
        downCoords.x,
        downCoords.y,
        downCoords.z - minDim.z
    )

    return true, finalCoords, {
        hitCoords = downCoords,
        normal = surfaceNormal,
        entity = entityHit,
        minDim = minDim,
        maxDim = maxDim
    }, nil
end

local function validateSupport(previewEntity, finalCoords, surfaceData)
    if not finalCoords or not surfaceData then
        return false, 'Invalid placement'
    end

    SetEntityCoordsNoOffset(previewEntity, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
    Wait(0)

    local currentCoords = GetEntityCoords(previewEntity)
    local minDim = surfaceData.minDim or select(1, GetModelDimensions(GetEntityModel(previewEntity)))
    local objectBottomZ = currentCoords.z + minDim.z
    local supportZ = surfaceData.hitCoords.z
    local maxFloatDistance = Config.MaxFloatDistance or 0.15

    if math.abs(objectBottomZ - supportZ) > maxFloatDistance then
        return false, 'Object would float here'
    end

    return true, nil
end

local function canPlaceHere(entity, coords)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if Config.BlockPlacementInVehicle and IsPedInAnyVehicle(ped, false) then
        return false, 'Exit the vehicle first'
    end

    if #(pedCoords - coords) > Config.MaxPlaceDistanceFromPlayer then
        return false, 'Too far away'
    end

    if IsEntityInWater(entity) then
        return false, 'Cannot place in water'
    end

    return true, nil
end

local function drawPlacementHelp(itemLabel)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(('Placing %s~n~E - Place~n~Backspace - Cancel~n~Scroll Up/Down - Rotate'):format(itemLabel))
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function removeTarget(entity)
    if entity and DoesEntityExist(entity) then
        exports['qb-target']:RemoveTargetEntity(entity, Config.PickupLabel)
    end
end

local function addTargetForEntity(entity, furnitureId)
    exports['qb-target']:AddTargetEntity(entity, {
        options = {
            {
                type = 'client',
                event = 'qb-furniture:client:pickupEntity',
                icon = 'fas fa-box-open',
                label = Config.PickupLabel,
                furnitureId = furnitureId
            }
        },
        distance = Config.TargetDistance
    })
end

local function spawnFurnitureEntity(data)
    if not data or not data.id or not data.model or not data.coords then return end
    if spawnedFurniture[data.id] and DoesEntityExist(spawnedFurniture[data.id]) then return end

    local model = loadModel(data.model)
    if not model then
        debugPrint(('Failed to load placed furniture model %s for id %s'):format(data.model, tostring(data.id)))
        return
    end

    local entity = CreateObjectNoOffset(model, data.coords.x, data.coords.y, data.coords.z, false, false, false)
    if entity == 0 then
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityHeading(entity, data.heading + 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)

    spawnedFurniture[data.id] = entity
    addTargetForEntity(entity, data.id)

    SetModelAsNoLongerNeeded(model)
end

local function deleteFurnitureEntity(furnitureId)
    local entity = spawnedFurniture[furnitureId]
    if entity and DoesEntityExist(entity) then
        removeTarget(entity)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteObject(entity)
    end
    spawnedFurniture[furnitureId] = nil
end

RegisterNetEvent('qb-furniture:client:syncAll', function(placements)
    for id in pairs(spawnedFurniture) do
        deleteFurnitureEntity(id)
    end

    for _, placement in pairs(placements or {}) do
        spawnFurnitureEntity(placement)
    end
end)

RegisterNetEvent('qb-furniture:client:addFurniture', function(placement)
    spawnFurnitureEntity(placement)
end)

RegisterNetEvent('qb-furniture:client:removeFurniture', function(furnitureId)
    deleteFurnitureEntity(furnitureId)
end)

RegisterNetEvent('qb-furniture:client:startPlacement', function(itemName)
    if isPlacing then return end

    local cfg = Config.PlaceableItems[itemName]
    if not cfg then
        notify('This item is not configured as placeable', 'error')
        return
    end

    local model = loadModel(cfg.model)
    if not model then
        notify(('Failed to load model: %s'):format(cfg.model), 'error')
        return
    end

    isPlacing = true

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local preview = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)

    if preview == 0 then
        isPlacing = false
        SetModelAsNoLongerNeeded(model)
        notify('Failed to create preview object', 'error')
        return
    end

    SetEntityAlpha(preview, Config.PreviewAlphaValid, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetEntityInvincible(preview, true)

    local heading = GetEntityHeading(ped)
    local validPlacement = false
    local finalCoords = coords
    local failReason = 'Aim at a valid spot'

    CreateThread(function()
        while isPlacing and DoesEntityExist(preview) do
            Wait(0)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            drawPlacementHelp(cfg.label)

            if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
                heading = (heading + (Config.RotationStep or 5.0)) % 360.0
            elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
                heading = (heading - (Config.RotationStep or 5.0)) % 360.0
            end

            local fallbackCoords = getForwardFallbackCoords(math.min(Config.PlaceDistance or 5.0, 2.0))
            local found, placeCoords, surfaceData, err = getSurfacePlacementCoords(preview, fallbackCoords)

            if found and placeCoords then
                SetEntityHeading(preview, heading)
                SetEntityCoordsNoOffset(preview, placeCoords.x, placeCoords.y, placeCoords.z, false, false, false)

                local supported, supportErr = validateSupport(preview, placeCoords, surfaceData)
                local placeOkay, placeReason = canPlaceHere(preview, placeCoords)

                if supported and placeOkay then
                    validPlacement = true
                    finalCoords = placeCoords
                    failReason = nil
                else
                    validPlacement = false
                    finalCoords = placeCoords
                    failReason = supportErr or placeReason or 'Invalid placement'
                end
            else
                validPlacement = false
                failReason = err or 'No placement surface found'
            end

            SetEntityAlpha(preview, validPlacement and Config.PreviewAlphaValid or Config.PreviewAlphaInvalid, false)

            if IsControlJustPressed(0, 38) then
                if validPlacement then
                    isPlacing = false
                    TriggerServerEvent('qb-furniture:server:placeFurniture', itemName, {
                        x = finalCoords.x,
                        y = finalCoords.y,
                        z = finalCoords.z
                    }, heading)
                else
                    notify(failReason or 'Invalid placement', 'error')
                end
            elseif IsControlJustPressed(0, 177) then
                isPlacing = false
                notify('Placement cancelled', 'error')
            end
        end

        if DoesEntityExist(preview) then
            DeleteObject(preview)
        end
        SetModelAsNoLongerNeeded(model)
    end)
end)

RegisterNetEvent('qb-furniture:client:pickupEntity', function(data)
    if not data or not data.furnitureId then return end
    TriggerServerEvent('qb-furniture:server:pickupFurniture', data.furnitureId)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-furniture:server:requestSync')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(1000)
    TriggerServerEvent('qb-furniture:server:requestSync')
end)