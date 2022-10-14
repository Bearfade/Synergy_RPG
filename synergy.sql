-- --------------------------------------------------------
-- 호스트:                          127.0.0.1
-- 서버 버전:                        10.6.7-MariaDB - mariadb.org binary distribution
-- 서버 OS:                        Win64
-- HeidiSQL 버전:                  11.3.0.6295
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- synergy 데이터베이스 구조 내보내기
CREATE DATABASE IF NOT EXISTS `synergy` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;
USE `synergy`;

-- 테이블 synergy.player 구조 내보내기
CREATE TABLE IF NOT EXISTS `player` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `steam` varchar(50) DEFAULT '없음',
  `nickname` varchar(50) DEFAULT '없음',
  `level` int(10) DEFAULT 0,
  `exp` int(10) DEFAULT 0,
  `skp` int(11) DEFAULT 0,
  `connect` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4;

-- 테이블 데이터 synergy.player:~11 rows (대략적) 내보내기
DELETE FROM `player`;
/*!40000 ALTER TABLE `player` DISABLE KEYS */;
INSERT INTO `player` (`id`, `steam`, `nickname`, `level`, `exp`, `skp`, `connect`) VALUES
	(1, 'STEAM_0:0:91695869', 'Bearfade', 36, 2563, 0, 0),
	(2, 'STEAM_0:0:169250573', '废物赘婿', 1, 9, 1, 0),
	(3, 'STEAM_0:1:49587674', 'qwe', 40, 3906, 0, 0),
	(4, 'STEAM_0:0:45214905', '오리', 15, 1170, 15, 0),
	(5, 'STEAM_0:1:200333944', 'Hya-24', 1, 0, 1, 0),
	(6, 'STEAM_0:0:108990659', 'Gus Fring Gaming', 1, 0, 1, 1),
	(7, 'STEAM_0:1:710758329', 'gonzaloe12', 1, 0, 1, 0),
	(8, 'STEAM_0:0:561683122', 'nine999_9', 5, 279, 0, 0),
	(9, 'STEAM_0:1:50491258', 'PizzaDrummer', 3, 54, 3, 0),
	(10, 'STEAM_0:0:553249580', 'Andre_Ars0726', 3, 32, 3, 0),
	(11, 'STEAM_0:0:65502131', 'Entropy zero 2', 1, 0, 1, 0);
/*!40000 ALTER TABLE `player` ENABLE KEYS */;

-- 테이블 synergy.skill 구조 내보내기
CREATE TABLE IF NOT EXISTS `skill` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `steamid` varchar(50) DEFAULT '없음',
  `nickname` varchar(50) DEFAULT '없음',
  `skillid` int(11) DEFAULT 0,
  `count` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COMMENT='스킬';

-- 테이블 데이터 synergy.skill:~12 rows (대략적) 내보내기
DELETE FROM `skill`;
/*!40000 ALTER TABLE `skill` DISABLE KEYS */;
INSERT INTO `skill` (`id`, `steamid`, `nickname`, `skillid`, `count`) VALUES
	(1, 'STEAM_0:0:91695869', 'Bearfade', 1, 5),
	(2, 'STEAM_0:0:91695869', 'Bearfade', 2, 10),
	(3, 'STEAM_0:0:91695869', 'Bearfade', 6, 10),
	(4, 'STEAM_0:0:91695869', 'Bearfade', 4, 10),
	(5, 'STEAM_0:1:49587674', 'qwe', 1, 5),
	(6, 'STEAM_0:1:49587674', 'qwe', 6, 10),
	(7, 'STEAM_0:1:49587674', 'qwe', 4, 10),
	(8, 'STEAM_0:1:49587674', 'qwe', 9, 3),
	(9, 'STEAM_0:1:49587674', 'qwe', 8, 10),
	(10, 'STEAM_0:1:49587674', 'qwe', 2, 10),
	(11, 'STEAM_0:0:91695869', 'Bearfade', 8, 1),
	(12, 'STEAM_0:0:91695869', 'Bearfade', 7, 2);
/*!40000 ALTER TABLE `skill` ENABLE KEYS */;

-- 테이블 synergy.test 구조 내보내기
CREATE TABLE IF NOT EXISTS `test` (
  `msg` text NOT NULL,
  PRIMARY KEY (`msg`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='sd';

-- 테이블 데이터 synergy.test:~0 rows (대략적) 내보내기
DELETE FROM `test`;
/*!40000 ALTER TABLE `test` DISABLE KEYS */;
/*!40000 ALTER TABLE `test` ENABLE KEYS */;

/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
