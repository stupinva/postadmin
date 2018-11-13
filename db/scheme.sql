CREATE DATABASE mail DEFAULT CHARACTER SET UTF8 COLLATE UTF8_GENERAL_CI;

USE mail;

CREATE TABLE `domain` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `domain` varchar(255) character set latin1 NOT NULL,
  `transport` varchar(255) character set latin1 NOT NULL default 'dovecot:',
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain` (`domain`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;

CREATE TABLE `user` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `active` enum('Y','N') NOT NULL default 'Y',
  `email` varchar(255) character set latin1 NOT NULL,
  `password` varchar(255) character set latin1 NOT NULL default '',
  `surname` varchar(255) NOT NULL default '',
  `name` varchar(255) NOT NULL default '',
  `patronym` varchar(255) NOT NULL default '',
  `lastip` varchar(32) default NULL,
  `lasttime` datetime default NULL,
  `bytes` bigint(20) default NULL,
  `messages` int(11) default NULL,
  `max_bytes` bigint(20) unsigned NOT NULL default '1073741824',
  `max_messages` int(10) unsigned NOT NULL default '1000',
  `ad_login` varchar(255) character set latin1 NOT NULL default '',
  `phones` varchar(255) NOT NULL default '',
  `position` varchar(255) NOT NULL default '',
  `department` varchar(255) NOT NULL default '',
  `smtp_acl` varchar(255) character set latin1 NOT NULL default 'permit_whitelist_auth',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `fullname` (`surname`,`name`,`patronym`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE `subscription` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `direction` enum('I','O') NOT NULL default 'I',
  `email` varchar(255) character set latin1 NOT NULL,
  `recipient` varchar(255) character set latin1 NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `subscription` (`direction`,`email`,`recipient`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;

CREATE TABLE smtp_acl (
  id integer unsigned NOT NULL auto_increment,
  acl varchar(255) character set latin1 NOT NULL default 'permit_whitelist_auth',
  address varchar(255) character set latin1 NOT NULL,
  description varchar(255) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY acl_rule (acl, address)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
