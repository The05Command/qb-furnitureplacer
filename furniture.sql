CREATE TABLE IF NOT EXISTS `player_furniture` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `item_name` varchar(64) NOT NULL,
  `model` varchar(128) NOT NULL,
  `citizenid` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `heading` float NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
