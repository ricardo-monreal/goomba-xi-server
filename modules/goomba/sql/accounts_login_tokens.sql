-- Goomba XI: launch tokens
--
-- Single-use, short-lived (5 minute) tokens the website mints for a launcher that has
-- signed in. The launcher hands one to xiloader as "login_token" and the login server
-- (patches/0001-launch-token-login.patch) accepts it once in place of the password, then
-- deletes it. Only the SHA-256 of each token is stored. Same table as the Phoenix fork's,
-- so Phoenix's xiloader works unchanged.
--
-- No DROP TABLE: dbtool re-imports module SQL on every update, and the installer runs
-- this file too; both must leave existing tokens alone.
CREATE TABLE IF NOT EXISTS `accounts_login_tokens` (
  `token` CHAR(64) NOT NULL,
  `accid` INT UNSIGNED NOT NULL,
  `expires` DATETIME NOT NULL,
  PRIMARY KEY (`token`),
  INDEX `idx_accid` (`accid`),
  INDEX `idx_expires` (`expires`),
  CONSTRAINT `fk_login_accid` FOREIGN KEY (`accid`) REFERENCES `accounts`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
