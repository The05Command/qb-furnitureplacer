Config = {}

Config.Debug = false
Config.PreviewAlphaValid = 170
Config.PreviewAlphaInvalid = 90
Config.PlaceDistance = 7.5
Config.MaxGroundSnapDistance = 8.0
Config.MaxFloatDistance = 0.15
Config.MaxPlaceDistanceFromPlayer = 10.0
Config.RotationStep = 5.0
Config.AllowAnyoneToPickup = false
Config.UseItemToPickup = true
Config.TargetDistance = 2.0
Config.PickupLabel = 'Pick Up'
Config.BlockPlacementInVehicle = true
Config.BlockIfPreviewCollides = false -- set true if stricter collision checking

Config.PlaceableItems = {
    table = {
        label = 'Dining Table',
        model = 'prop_table_03'
    },
    glasstable = {
        label = 'Glass Table',
        model = 'v_ilev_glass_side_table'
    }
}
