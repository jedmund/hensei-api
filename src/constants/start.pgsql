-- Extensions ----------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Table Definition ----------------------------------------------

CREATE TABLE IF NOT EXISTS users(
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    username character varying(32) NOT NULL,
    granblue_id integer,
    email text NOT NULL,
    password text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE parties (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    hash character varying(10),
    weapons uuid[],
    characters uuid[],
    summons uuid[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE grid_weapons (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    weapon_id uuid REFERENCES weapons(id),
    grid_id uuid,
    uncap_level integer,
    weapon_key1_id uuid REFERENCES weapon_keys(id),
    weapon_key2_id uuid REFERENCES weapon_keys(id),
    position integer
);

CREATE TABLE weapons (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name_en text,
    rarity integer,
    element integer,
    weapon_type integer,
    granblue_id integer,
    name_jp text,
    max_level text,
    max_skill_level text,
    min_hp text,
    max_hp text,
    max_hp_flb text,
    max_hp_ulb text,
    min_atk text,
    max_atk text,
    max_atk_flb text,
    max_atk_ulb text,
    weapon_series text,
    flb boolean NOT NULL DEFAULT false,
    ulb boolean NOT NULL DEFAULT false
);

CREATE TABLE weapon_keys (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    name_en text,
    name_jp text,
    weapon_key_series integer,
    weapon_key_type integer
);

-- Indices -------------------------------------------------------

CREATE UNIQUE INDEX users_pkey ON users(id uuid_ops);
CREATE UNIQUE INDEX parties_pkey ON parties(id uuid_ops);
CREATE UNIQUE INDEX grid_weapons_pkey ON grid_weapons(id uuid_ops);
CREATE UNIQUE INDEX weapons_pkey ON weapons(id uuid_ops);
CREATE UNIQUE INDEX weapon_keys_pkey ON weapon_keys(id uuid_ops);
