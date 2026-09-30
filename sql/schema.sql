CREATE TABLE departments (
    airtable_id TEXT PRIMARY KEY,
    department_name TEXT NOT NULL CHECK (btrim(department_name) <> ''),
    department_code TEXT NOT NULL UNIQUE CHECK (btrim(department_code) <> ''),
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE employees (
    airtable_id TEXT PRIMARY KEY,
    employee_name TEXT NOT NULL CHECK (btrim(employee_name) <> ''),
    employee_code TEXT NOT NULL UNIQUE CHECK (btrim(employee_code) <> ''),
    department_id TEXT REFERENCES departments(airtable_id),
    manager_id TEXT REFERENCES employees(airtable_id),
    start_date DATE
);

CREATE TABLE task_templates (
    airtable_id TEXT PRIMARY KEY,
    template_name TEXT NOT NULL CHECK (btrim(template_name) <> ''),
    description TEXT,
    department_id TEXT REFERENCES departments(airtable_id),
    offset_days INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE onboarding_cases (
    airtable_id TEXT PRIMARY KEY,
    case_name TEXT NOT NULL CHECK (btrim(case_name) <> ''),
    employee_id TEXT REFERENCES employees(airtable_id),
    status TEXT NOT NULL DEFAULT 'Draft'
        CHECK (status IN ('Draft', 'Ready', 'Processing', 'Completed', 'Failed')),
    failure_reason TEXT,
    last_attempt_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE TABLE workflow_runs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id TEXT NOT NULL REFERENCES onboarding_cases(airtable_id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    outcome TEXT NOT NULL DEFAULT 'Running'
        CHECK (outcome IN ('Running', 'Succeeded', 'Failed', 'Reconciliation Needed'))
);

CREATE TABLE onboarding_tasks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    airtable_id TEXT UNIQUE,
    case_id TEXT NOT NULL REFERENCES onboarding_cases(airtable_id),
    template_id TEXT NOT NULL REFERENCES task_templates(airtable_id),
    task_name TEXT NOT NULL CHECK (btrim(task_name) <> ''),
    description TEXT,
    due_date DATE NOT NULL,
    created_by_run_id BIGINT NOT NULL REFERENCES workflow_runs(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (case_id, template_id)
);

CREATE TABLE workflow_errors (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    airtable_id TEXT UNIQUE,
    run_id BIGINT NOT NULL REFERENCES workflow_runs(id),
    error_type TEXT NOT NULL
        CHECK (error_type IN (
            'Validation', 'Templates', 'Task Write', 'Verification',
            'Outbox', 'Reconciliation', 'Other'
        )),
    details TEXT NOT NULL CHECK (btrim(details) <> ''),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notification_outbox (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id TEXT NOT NULL REFERENCES onboarding_cases(airtable_id),
    run_id BIGINT NOT NULL REFERENCES workflow_runs(id),
    event_type TEXT NOT NULL DEFAULT 'Tasks Generated'
        CHECK (event_type = 'Tasks Generated'),
    recipient_label TEXT NOT NULL CHECK (btrim(recipient_label) <> ''),
    message TEXT NOT NULL CHECK (btrim(message) <> ''),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (case_id, event_type)
);
