-- 
-- Schema for the sqlite3 ThingFish metastore plugin
-- $Id$
-- 
PRAGMA default_cache_size = 7000;
PRAGMA user_version = $Rev: 185 $; -- Transformed by the plugin before insertion

CREATE TABLE
  'resources' (
  'id'   INTEGER PRIMARY KEY,
  'uuid' CHAR(36) UNIQUE
);

CREATE TABLE
  'metakey' (
  'id'  INTEGER PRIMARY KEY,
  'key' VARCHAR(255) UNIQUE
);

CREATE TABLE
  'metaval' (
  'r_id' INTEGER NOT NULL,
  'm_id' INTEGER NOT NULL,
  'val'  TEXT,
  PRIMARY KEY ('r_id', 'm_id')
);
CREATE INDEX 'r_id_index' ON 'metaval' ('r_id');
CREATE INDEX 'm_id_index' ON 'metaval' ('m_id');
CREATE INDEX 'val_index'  ON 'metaval' ('val');

CREATE TRIGGER 'metacleanup' DELETE ON 'resources'
BEGIN
  DELETE FROM metaval
    WHERE r_id = OLD.id;
END;
