-- V1__init.sql — Streamora baseline schema (PostgreSQL)
-- Notes:
-- 1) Do NOT create the database inside a migration; connect to the DB first, then run this.
-- 2) Requires PostgreSQL extensions: pgcrypto (for gen_random_uuid) and citext (case-insensitive text).

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE OR REPLACE FUNCTION set_updated_at()
RETUERN TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

-- Enumerated types
DO $$ BEGIN
    CREATE TYPE event_status_type AS ENUM ('DRAFT', 'SCHEDULE', 'LIVE', 'ENDED', 'CENCELLED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE stream_mode_type AS ENUM ('EMBED', 'RTMP', 'EXTERNAL');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE visibility_scope_type AS ENUM ('PUBLIC', 'UNLISTED', 'PRIVATE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE ticket_type AS ENUM ('FREE', 'PAID');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE event_role_type AS ENUM ('HOST', 'SPEAKER', 'MODERATOR', 'ATTENDEE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT gen_random_uuid(),
    email CITEXT NOT NULL UNIQUE,
    username CITEXT NOT NULL UNIQUE,
    full_name CITEXT NOT NULL,
    avatar_url TEXT,
    phone_number TEXT UNIQUE,
    password_hash TEXT,
    twofa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    disabled_reason TEXT,
    email_verified_at TIMESTAMPTZ,
    phone_verified_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    PRIMARY KEY (id)
);

CREATE TRIGGER trg_user_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ORGANIZATIONS
CREATE TABLE IF NOT EXISTS organizations (
    id UUID DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    slug CITEXT NOT NULL UNIQUE,
    logo_url TEXT,
    cover_url TEXT,
    description TEXT,
    website_url TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TRIGGER trg_organizations_set_updated_at
BEFORE UPDATE ON organizations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- INDUSTRIES
CREATE TABLE IF NOT EXISTS industries(
    id UUID DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    parent_id UUID NULL REFERENCES industries(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TRIGGER trg_industries_set_updated_at
BEFORE UPDATE ON industries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- EVENTS
CREATE TABLE IF NOT EXISTS events (
    id UUID DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organizations(id),
    owner_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    cover_url TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    time_zone TIMESTAMPTZ NOT NULL,
    status event_status_type NOT NULL DEFAULT 'DRAFT',
    stream_mode stream_mode_type NOT NULL DEFAULT 'EMBED',
    visibility_scope visibility_scope_type NOT NULL DEFAULT 'PUBLIC',
    registration_required BOOLEAN NOT NULL DEFAULT FALSE,
    language varchar(16),
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    CONTRAINT event_time_check CHECK (end_time >= start_time)
);

CREATE TRIGGER trg_event_set_updated_at
BEFORE UPDATE ON events
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- TICKETS
CREATE TABLE IF NOT EXISTS tickets (
    id UUID DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id),
    name TEXT NOT NULL,
    type ticket_type NOT NULL DEFAULT 'FREE',
    price_cents INTEGER NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'VND',
    qty_total INTEGER NOT NULL DEFAULT 0 CHECK (qty_total >= 0),
    qty_sold INTEGER NOT NULL DEFAULT 0 CHECK (qty_sold >= 0 AND qty_sold <= qty_total),
    sales_start TIMESTAMPTZ NOT NULL,
    sales_end TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    CONTRAINT tickets_sales_window_chk CHECK (
        sales_start IS NULL OR sales_end IS NULL or sales_end >= sales_start
    )
);

CREATE TRIGGER trg_tickets_set_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ATTENDEES
CREATE TABLE IF NOT EXISTS attendees (
    id UUID DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    ticket_id UUID NOT NULL REFERENCES tickes(id) ON DELETE SET NULL,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    checkin_at TIMESTAMPTZ,
    role_in_event event_role_type NOT NULL DEFAULT 'ATTENDEE',
    allow_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    CONTRAINT attendees_unique_registration UNIQUE (event_id, user_id)
);

CREATE TRIGGER trig_attendess_set_updated_at
BEFORE UPDATE ON attendees
FOR EACH ROW EXECUTE FUNCTION updated_at();