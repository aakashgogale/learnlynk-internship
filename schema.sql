-- LEARNLYNK - SECTION 1 SCHEMA
-- Extension for UUIDs (Supabase usually already has it, but safe to keep)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1) LEADS TABLE
CREATE TABLE IF NOT EXISTS leads (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid        NOT NULL,
    full_name   text        NOT NULL,
    email       text,
    phone       text,
    owner_id    uuid,                  -- which counselor / user owns this lead
    stage       text        NOT NULL DEFAULT 'new',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 2) APPLICATIONS TABLE (references leads)
CREATE TABLE IF NOT EXISTS applications (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid        NOT NULL,
    lead_id     uuid        NOT NULL,
    program_name text,
    status      text        NOT NULL DEFAULT 'pending',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    
    CONSTRAINT applications_lead_fk
        FOREIGN KEY (lead_id) REFERENCES leads(id)
        ON DELETE CASCADE
);

-- 3) TASKS TABLE (references applications.id as related_id)
CREATE TABLE IF NOT EXISTS tasks (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid        NOT NULL,
    related_id  uuid        NOT NULL,          -- applications.id
    title       text        NOT NULL,
    task_type   text        NOT NULL,
    due_at      timestamptz NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    -- FK to applications
    CONSTRAINT tasks_application_fk
        FOREIGN KEY (related_id) REFERENCES applications(id)
        ON DELETE CASCADE,

    -- Constraint: due_at >= created_at
    CONSTRAINT tasks_due_at_after_created
        CHECK (due_at >= created_at),

    -- Check constraint: task_type in allowed list
    CONSTRAINT tasks_type_valid
        CHECK (task_type IN ('call', 'email', 'review'))
);

-- INDEXES FOR COMMON QUERIES

-- Fetch leads by owner, stage, created_at
CREATE INDEX IF NOT EXISTS idx_leads_owner_stage_created_at
    ON leads (tenant_id, owner_id, stage, created_at);

-- Fetch applications by lead
CREATE INDEX IF NOT EXISTS idx_applications_lead_id
    ON applications (lead_id);

-- Fetch tasks due today (index on due_at, tenant_id)
CREATE INDEX IF NOT EXISTS idx_tasks_due_at
    ON tasks (tenant_id, due_at);