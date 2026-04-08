QBCore furniture system working with props from base game GTA and Custom props. 

This script is custom made to work with my own server/props. I thought i'd share it here free of charge. 

What it does?
- Places furniture via items.
- The script looks for any solid surface. So you are able to put things on top of eachother.
- Simple as that really.


Look up GTA props:
https://forge.plebmasters.de/ 

Install:

1. Place qb-furnitureplacer in a folder. Make sure to start it AFTER oxmysql, qb-core and qb-target
2. Import SQL file
3. Start server


How to configure:

Items are configured as such:

    table = { -- Item name. 
        label = 'Dining Table', -- Label
        model = 'prop_table_03' -- Prop
    },

It is important you have an item in ur items.lua so the script knows you want to place it. 
Example:
table = { name = 'table', label = 'Dining Table', weight = 2000, type = 'item', image = 'tabel.png', unique = false, useable = true, shouldClose = true, description = 'A sturdy dining table' },
