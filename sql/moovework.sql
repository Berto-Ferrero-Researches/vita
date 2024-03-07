#This file has been added to create the initial database required to run the vita program

DROP DATABASE IF EXISTS moovetemplate;
CREATE DATABASE moovetemplate TEMPLATE=postgis_21_sample;

DROP DATABASE IF EXISTS moovework;
CREATE DATABASE moovework TEMPLATE moovetemplate;

\c moovework;

CREATE TABLE IF NOT EXISTS item (item_id serial NOT NULL PRIMARY KEY, item_globalid varchar(50),item_name varchar(100)) WITH (OIDS=FALSE);
ALTER TABLE item OWNER TO postgres;

CREATE TABLE IF NOT EXISTS uploads (upload_id serial NOT NULL PRIMARY KEY,upload_file_name character varying(255) NOT NULL,upload_file_type character varying(255) NOT NULL,upload_binary_file bytea NOT NULL,upload_created timestamp DEFAULT 'now' NOT NULL,upload_edited timestamp NOT NULL,upload_description text);


CREATE TABLE IF NOT EXISTS building (
    item_id serial NOT NULL PRIMARY KEY,
    file_id integer,
    CONSTRAINT building_to_file_fkey FOREIGN KEY (file_id)
        REFERENCES uploads (upload_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (item);
ALTER TABLE building OWNER TO postgres;

CREATE TABLE IF NOT EXISTS floor (
    item_id serial NOT NULL PRIMARY KEY,
    building_id integer,
    CONSTRAINT floor_to_building_fkey FOREIGN KEY (building_id)
        REFERENCES building (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (item);
ALTER TABLE floor OWNER TO postgres;

CREATE TABLE IF NOT EXISTS partition (
    item_id serial NOT NULL PRIMARY KEY,
    flooritem_floorid integer,
    CONSTRAINT part_to_floor_fkey FOREIGN KEY (flooritem_floorid)
        REFERENCES floor (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (item);
ALTER TABLE partition OWNER TO postgres;
SELECT AddGeometryColumn('partition', 'part_geom', -1, 'POLYGON', 2 );
CREATE INDEX partition_geom_gist ON partition USING GIST (part_geom);

CREATE TABLE IF NOT EXISTS decomprel (
    deco_original integer NOT NULL,
    deco_decomp integer NOT NULL,
    CONSTRAINT deco_pkey PRIMARY KEY (deco_original, deco_decomp),
    CONSTRAINT deco_original_fk FOREIGN KEY (deco_original)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT deco_decomp_fk FOREIGN KEY (deco_decomp)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE decomprel OWNER TO postgres;

CREATE TABLE IF NOT EXISTS accesspoint (
    item_id serial NOT NULL PRIMARY KEY,
    flooritem_floorid integer,
    ap_type integer,
    CONSTRAINT ap_To_floor_fkey FOREIGN KEY (flooritem_floorid)
        REFERENCES floor (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (item);
ALTER TABLE accesspoint OWNER TO postgres;
SELECT AddGeometryColumn('accesspoint', 'ap_location', -1, 'POINT', 2 );
SELECT AddGeometryColumn('accesspoint', 'ap_line', -1, 'LINESTRING', 2 );
CREATE INDEX ap_location_gist ON accesspoint USING GIST (ap_location);
CREATE INDEX ap_line_gist ON accesspoint USING GIST (ap_line);

CREATE TABLE IF NOT EXISTS accesspoint (
    item_id serial NOT NULL PRIMARY KEY,
    flooritem_floorid integer,
    ap_type integer,
    CONSTRAINT ap_To_floor_fkey FOREIGN KEY (flooritem_floorid)
        REFERENCES floor (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (item);
ALTER TABLE accesspoint OWNER TO postgres;
SELECT AddGeometryColumn('accesspoint', 'ap_location', -1, 'POINT', 2 );
SELECT AddGeometryColumn('accesspoint', 'ap_line', -1, 'LINESTRING', 2 );
CREATE INDEX ap_location_gist ON accesspoint USING GIST (ap_location);
CREATE INDEX ap_line_gist ON accesspoint USING GIST (ap_line);

CREATE TABLE IF NOT EXISTS connector (
    item_id serial NOT NULL PRIMARY KEY,
    item_globalid varchar(50),
    item_name varchar(100),
    flooritem_floorid integer NOT NULL,
    ap_type integer,
    conn_upperfloor integer,
    CONSTRAINT conn_floor_fk FOREIGN KEY (flooritem_floorid)
        REFERENCES floor (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
) INHERITS (accesspoint);
ALTER TABLE connector OWNER TO postgres;
SELECT AddGeometryColumn('connector', 'ap_location', -1, 'POINT', 2);
SELECT AddGeometryColumn('connector', 'conn_upperpoint', -1, 'POINT', 2);

CREATE TABLE IF NOT EXISTS aptopart (
    ap_id integer NOT NULL,
    part_id integer NOT NULL,
    CONSTRAINT aptopart_pkey PRIMARY KEY (ap_id, part_id),
    CONSTRAINT aptopart_ap_fk FOREIGN KEY (ap_id)
        REFERENCES accesspoint (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT aptopart_part_fk FOREIGN KEY (part_id)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE aptopart OWNER TO postgres;

CREATE TABLE IF NOT EXISTS contopart (
    con_id integer NOT NULL,
    part_id integer NOT NULL,
    CONSTRAINT contopart_pkey PRIMARY KEY (con_id, part_id),
    CONSTRAINT contopart_con_fk FOREIGN KEY (con_id)
        REFERENCES connector (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT contopart_part_fk FOREIGN KEY (part_id)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE contopart OWNER TO postgres;

CREATE TABLE IF NOT EXISTS connectivity (
    con_apid integer NOT NULL,
    con_part1id integer NOT NULL,
    con_part2id integer NOT NULL,
    CONSTRAINT connectivity_pkey PRIMARY KEY (con_apid),
    CONSTRAINT connectivity_ap_fk FOREIGN KEY (con_apid)
        REFERENCES accesspoint (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT connectivity_part1_fk FOREIGN KEY (con_part1id)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT connectivity_part2_fk FOREIGN KEY (con_part2id)
        REFERENCES partition (item_id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE aptopart OWNER TO postgres;

CREATE TABLE IF NOT EXISTS accessrule (
    acc_id serial NOT NULL PRIMARY KEY,
    acc_name varchar(100),
    acc_conid integer NOT NULL,
    direction boolean NOT NULL,
    CONSTRAINT accessrule_aptopart_fk FOREIGN KEY (acc_conid)
        REFERENCES connectivity (con_apid) MATCH FULL
        ON UPDATE CASCADE ON DELETE CASCADE
);
ALTER TABLE accessrule OWNER TO postgres;

CREATE FUNCTION ins_connectivity() RETURNS trigger AS '
    BEGIN
        IF tg_op = ''INSERT'' THEN
            IF EXISTS (SELECT part_id AS partid FROM aptopart WHERE ap_id = NEW.ap_id ) THEN
                INSERT INTO connectivity( con_apid, con_part1id, con_part2id)
                SELECT NEW.ap_id, part_id, NEW.part_id FROM aptopart WHERE ap_id = NEW.ap_id;
            END IF;
            RETURN new;
        END IF;
    END
' LANGUAGE plpgsql;

CREATE TRIGGER trig_a2p_connectivity BEFORE INSERT
ON aptopart FOR each ROW
EXECUTE PROCEDURE ins_connectivity();

