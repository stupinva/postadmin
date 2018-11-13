USE mail;

CREATE TABLE `session` (
  `id` varchar(32) NOT NULL,
  `firsttime` datetime NOT NULL,
  `lasttime` datetime NOT NULL,
  `data` text NOT NULL,
  `user_id` int(11) NOT NULL,
  `ip` varchar(15) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
