ALTER TABLE person ADD COLUMN source_id integer;

CREATE TABLE service
(
  id integer NOT NULL DEFAULT nextval('fountain'::regclass),
  name character varying(64) NOT NULL,
  connector character varying(64),
  
  CONSTRAINT p_key_service PRIMARY KEY (id) -- comment
)
WITH (
  OIDS=FALSE
);
ALTER TABLE service
  OWNER TO raido;
GRANT ALL ON TABLE service TO raido;

CREATE TABLE credentials(
  id integer DEFAULT nextval('fountain'::regclass),
  person_id integer NOT NULL,
  service_id integer NOT NULL,
  username character varying(64),
  password character varying(1024),
  paramHash character varying(1024),
  CONSTRAINT p_key_credentials PRIMARY KEY (id) -- comment
)
WITH (
  OIDS=FALSE
);
ALTER TABLE credentials
  OWNER TO raido;
GRANT ALL ON TABLE credentials TO raido;

CREATE TABLE parameters(
  id integer DEFAULT nextval('fountain'::regclass),
  credential_id integer,
  name character varying(64) NOT NULL,
  value character varying(64) NOT NULL,
  CONSTRAINT p_key_parameters PRIMARY KEY (id) -- comment
)
WITH (
  OIDS=FALSE
);
ALTER TABLE credentials
  OWNER TO raido;
GRANT ALL ON TABLE credentials TO raido;


INSERT INTO service (name,connector) VALUES ('Raido Roster to ICS','Kyloe::Service::RaidoRosterToICS') ;
INSERT INTO service (name,connector) VALUES ('CWP Roster to ICS','Kyloe::Service::CWPRosterToICS') ;
INSERT INTO credentials (username,service_id,person_id,password) VALUES ('115', 'test') ;
INSERT INTO parameters (name,value) VALUES ('staffid',115);
INSERT INTO parameters (name,value) VALUES ('password','test);
INSERT INTO parameters (name,value) VALUES ('checkin','yes');
INSERT INTO parameters (name,value) VALUES ('altsummary','CODE');
INSERT INTO parameters (name,value) VALUES ('summary','\'CODE\',\' \',\'DEP\',\'-\',\'ARR\'');

UPDATE credentials SET person_id = q.id FROM (SELECT id FROM person WHERE staffid = 115) as q;
UPDATE credentials SET service_id = q.id FROM (SELECT id FROM service WHERE name = 'Raido Roster to ICS') as q;

UPDATE parameters SET credential_id_id = q.id FROM (SELECT id FROM credentials WHERE username = 115) as q;
