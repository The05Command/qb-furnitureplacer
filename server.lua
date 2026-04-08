local QBCore = exports['qb-core']:GetCoreObject()
local placements = {}

local function notify(src, msg, nType)
    TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary')
end

local function getIdentifier(player)
    return player.PlayerData.citizenid
end

local function itemExists(player, itemName)
    local item = player.Functions.GetItemByName(itemName)
    return item ~= nil
end

local function loadPlacements()
    local rows = MySQL.query.await('SELECT id, item_name, model, citizenid, x, y, z, heading FROM player_furniture')
    placements = {}

    for _, row in ipairs(rows or {}) do
        placements[row.id] = {
            id = row.id,
            itemName = row.item_name,
            model = row.model,
            citizenid = row.citizenid,
            coords = vector3(row.x + 0.0, row.y + 0.0, row.z + 0.0),
            heading = row.heading + 0.0
        }
    end
end

local function registerUsableItems()
    for itemName in pairs(Config.PlaceableItems) do
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then return end
            if not itemExists(Player, item.name) then return end

            TriggerClientEvent('qb-furniture:client:startPlacement', source, item.name)
        end)
    end
end

RegisterNetEvent('qb-furniture:server:requestSync', function()
    local src = source
    TriggerClientEvent('qb-furniture:client:syncAll', src, placements)
end)

RegisterNetEvent('qb-furniture:server:placeFurniture', function(itemName, coords, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cfg = Config.PlaceableItems[itemName]

    if not Player or not cfg or type(coords) ~= 'table' then
        return
    end

    local item = Player.Functions.GetItemByName(itemName)
    if not item then
        notify(src, 'You do not have this item', 'error')
        return
    end

    if not Player.Functions.RemoveItem(itemName, 1, item.slot) then
        notify(src, 'Failed to remove item from inventory', 'error')
        return
    end

    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove', 1)

    local insertId = MySQL.insert.await('INSERT INTO player_furniture (item_name, model, citizenid, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        itemName,
        cfg.model,
        getIdentifier(Player),
        coords.x,
        coords.y,
        coords.z,
        heading
    })

    if not insertId then
        Player.Functions.AddItem(itemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', 1)
        notify(src, 'Could not save furniture placement, item returned', 'error')
        return
    end

    local placement = {
        id = insertId,
        itemName = itemName,
        model = cfg.model,
        citizenid = getIdentifier(Player),
        coords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
        heading = heading + 0.0
    }

    placements[insertId] = placement
    TriggerClientEvent('qb-furniture:client:addFurniture', -1, placement)
    notify(src, ('Placed %s'):format(cfg.label), 'success')
end)

RegisterNetEvent('qb-furniture:server:pickupFurniture', function(furnitureId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local placement = placements[tonumber(furnitureId)]
    if not Player or not placement then return end

    if not Config.AllowAnyoneToPickup and placement.citizenid ~= getIdentifier(Player) then
        notify(src, 'You do not own this furniture', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local placementCoords = placement.coords
    if #(playerCoords - placementCoords) > 3.0 then
        notify(src, 'You are too far away', 'error')
        return
    end

    MySQL.query.await('DELETE FROM player_furniture WHERE id = ?', { placement.id })
    placements[placement.id] = nil
    TriggerClientEvent('qb-furniture:client:removeFurniture', -1, placement.id)

    if Config.UseItemToPickup then
        Player.Functions.AddItem(placement.itemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[placement.itemName], 'add', 1)
    end

    notify(src, 'Furniture picked up', 'success')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    loadPlacements()
    registerUsableItems()
end)

AddEventHandler('QBCore:Server:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)
