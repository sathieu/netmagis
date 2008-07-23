------------------------------------------------------------------------------
-- Mise � jour de la base vers la version 1.5
--
--
-- $Id: upgrade.sql,v 1.1 2008-07-23 08:57:24 pda Exp $
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- ajout des profils dans les intervalles DHCP
------------------------------------------------------------------------------

ALTER TABLE dhcprange
	ADD COLUMN iddhcpprofil INTEGER ;

ALTER TABLE dhcprange
	ADD CONSTRAINT iddhcpprofilfk
	FOREIGN KEY(iddhcpprofil) REFERENCES dhcpprofil(iddhcpprofil) ;

------------------------------------------------------------------------------
-- ajout du champ "droitsmtp" dans la table RR
------------------------------------------------------------------------------

ALTER TABLE rr
	ADD COLUMN droitsmtp BOOLEAN ;
ALTER TABLE rr
	ALTER COLUMN droitsmtp
	SET DEFAULT FALSE ;

