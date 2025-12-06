
-- SECTION 1 — SCHEMA

-- TABLE: leads
CREATE TABLE leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    owner_id UUID NOT NULL,   
    team_id UUID,             
    name TEXT,
    stage TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- TABLE: applications
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    status TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- TABLE: tasks
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    related_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    due_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    -- DUE DATE MUST BE FUTURE
    CONSTRAINT due_after_created CHECK (due_at >= created_at),

    -- VALID TASK TYPES
    CONSTRAINT valid_task_type CHECK (type IN ('call', 'email', 'review'))
);

-- TEAM TABLES (needed for RLS)
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

CREATE TABLE user_teams (
    user_id UUID NOT NULL,
    team_id UUID NOT NULL,
    PRIMARY KEY (user_id, team_id),
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
);

-- ADD team_id TO LEADS
ALTER TABLE leads
ADD CONSTRAINT leads_team_fk FOREIGN KEY (team_id) REFERENCES teams(id);

-- INDEXES

-- For leads (owner, stage, created_at)
CREATE INDEX idx_leads_owner ON leads(owner_id);
CREATE INDEX idx_leads_stage ON leads(stage);
CREATE INDEX idx_leads_created ON leads(created_at);

-- For applications by lead
CREATE INDEX idx_applications_lead ON applications(lead_id);

-- Tasks due today
CREATE INDEX idx_tasks_due ON tasks(due_at);

-- SECTION 2 — RLS POLICIES
-- Enable RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- Helper function to check role
CREATE FUNCTION current_role() RETURNS text AS $$
    SELECT auth.jwt()->>'role';
$$ LANGUAGE sql STABLE;

-- POLICY: SELECT on leads
CREATE POLICY leads_select_policy ON leads
FOR SELECT
USING (
    current_role() = 'admin'
    OR owner_id = auth.uid()
    OR team_id IN (
        SELECT team_id FROM user_teams WHERE user_id = auth.uid()
    )
);

-- POLICY: INSERT on leads
CREATE POLICY leads_insert_policy ON leads
FOR INSERT
WITH CHECK (
    current_role() = 'admin'
    OR owner_id = auth.uid()
);