# Employee Onboarding Automation — Airtable Schema

## Purpose and conventions

Airtable is the HR-facing workspace. HR prepares employee and case data, changes cases to Ready, and reviews outcomes. n8n changes processing statuses, creates tasks, and records exceptions.

Airtable record IDs identify records across systems. Display names and task titles are for people; they are not cross-system keys. All records contain synthetic data.

Each table has a readable primary field. Fields marked **HR** are maintained by HR or the project administrator. Fields marked **n8n** are written by the workflow. Formula and lookup fields are calculated by Airtable.

## Departments

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Department Name | Single line text; primary field | HR | Readable department name |
| Department Code | Single line text | HR | Short, stable code for display and reports |
| Active | Checkbox | HR | Whether the department is currently used |
| Employees | Linked records to Employees; reciprocal | Airtable | Employees in this department |
| Task Templates | Linked records to Task Templates; reciprocal | Airtable | Department-specific templates |

Each employee links to one department. A template may link to one department or have no department, meaning that it is global.

## Employees

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Employee Name | Single line text; primary field | HR | Synthetic display name |
| Employee Code | Single line text | HR | Readable synthetic reference |
| Department | Linked record to Departments; allow one record | HR | Employee's department |
| Manager | Linked record to Employees; allow one record | HR | Synthetic manager |
| Start Date | Date | HR | Basis for task deadlines |
| Onboarding Cases | Linked records to Onboarding Cases; reciprocal | Airtable | Employee's cases |

The Manager self-link may create a reciprocal field in Employees. Rename that reciprocal field **Direct Reports**. It is for navigation and is not a required input.

HR may initially leave Department, Manager, or Start Date empty. If the case is marked Ready without required information, the workflow records a clear failure.

## Onboarding Cases

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Case Name | Single line text; primary field | HR | Readable label, such as `ONB-001 — Alex Rivera` |
| Employee | Linked record to Employees; allow one record | HR | Employee being onboarded |
| Status | Single select: Draft, Ready, Processing, Completed, Failed | HR and n8n | Workflow state |
| Failure Reason | Long text | n8n | Current reason HR must address; cleared when a retry begins |
| Last Attempt At | Date with time | n8n | When the most recent attempt started |
| Completed At | Date with time | n8n | When task generation completed |
| Onboarding Tasks | Linked records to Onboarding Tasks; reciprocal | Airtable | Generated tasks |
| Automation Exceptions | Linked records to Automation Exceptions; reciprocal | Airtable | Errors and reconciliation issues |
| Employee Start Date | Lookup of Employees → Start Date | Airtable | HR-visible start date |
| Employee Department | Lookup of Employees → Department | Airtable | HR-visible department |
| Employee Manager | Lookup of Employees → Manager | Airtable | HR-visible manager |

HR creates cases in Draft and changes them to Ready. n8n changes Ready to Processing and Processing to Completed or Failed. After correcting a Failed case, HR changes it back to Ready. HR does not manually set Processing or Completed.

The Employee link may be empty so that a missing-employee validation failure can be demonstrated. The lookup fields help HR see missing information, but n8n validates the underlying linked records and employee fields.

Airtable does not enforce these state-transition rules by itself. The workflow and operating instructions enforce them for this portfolio project.

## Task Templates

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Template Name | Single line text; primary field | HR | Reusable task title |
| Description | Long text | HR | Instructions for the generated task |
| Department | Linked record to Departments; allow one record | HR | Optional scope; empty means global |
| Offset Days | Number; integer | HR | Calendar days relative to Start Date |
| Active | Checkbox | HR | Whether the template is selected for new cases |

An active template with no Department applies to every case. An active template with a Department applies only when it matches the employee's department. Inactive templates are ignored. n8n reads template records when it processes each case.

## Onboarding Tasks

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Task Name | Single line text; primary field | n8n | Title copied from the source template |
| Onboarding Case | Linked record to Onboarding Cases; allow one record | n8n | Case that generated the task |
| Task Template | Linked record to Task Templates; allow one record | n8n | Source template |
| Due Date | Date | n8n | Start Date plus Offset Days |
| Description | Long text | n8n | Instructions copied from the template |
| Generation Key | Single line text | n8n | Stable case-and-template key used to find an existing task |
| Created By Run ID | Single line text | n8n | PostgreSQL workflow-run identifier for the attempt that first created it |

The Generation Key is derived from the Airtable record IDs of the case and template, for example `recCase123:recTemplate456`. n8n searches for that key before creating a task. Airtable does not enforce uniqueness on this text field; PostgreSQL's unique case-and-template constraint provides a second guard.

A retry preserves an existing task and its original Created By Run ID. It creates only missing tasks.

## Automation Exceptions

| Field | Airtable type | Owner | Purpose |
|---|---|---|---|
| Exception Name | Single line text; primary field | n8n | Readable label, such as `ONB-001 — missing start date` |
| Onboarding Case | Linked record to Onboarding Cases; allow one record | n8n | Affected case |
| Workflow Run ID | Single line text | n8n | PostgreSQL attempt identifier, when available |
| Error Type | Single select: Validation, Templates, Task Write, Verification, Outbox, Reconciliation, Other | n8n | Category for HR review |
| Details | Long text | n8n | Specific explanation of what failed |
| Occurred At | Date with time | n8n | When the problem was recorded |
| Resolved | Checkbox | n8n | Whether the issue has been addressed |

An exception remains visible as history after a later successful retry. A Failed case also has a current Failure Reason so HR can quickly see what to correct.

## HR views

Create these views in **Onboarding Cases**:

| View | Filter | Fields to show first | HR action |
|---|---|---|---|
| Draft Cases | Status is Draft | Case Name, Employee, Employee Department, Employee Manager, Employee Start Date | Complete the information and mark Ready |
| Ready Cases | Status is Ready | Case Name, Employee, Employee Department, Employee Manager, Employee Start Date, Last Attempt At | Wait for the local workflow run |
| Processing Cases | Status is Processing | Case Name, Employee, Last Attempt At | Notice cases that remain Processing unexpectedly |
| Completed Cases | Status is Completed | Case Name, Employee, Completed At, Onboarding Tasks | Review generated tasks |
| Failed Cases | Status is Failed | Case Name, Employee, Failure Reason, Last Attempt At, Automation Exceptions | Correct the cause and mark Ready |

Also create an **Active Templates** view in Task Templates filtered to `Active` checked, and an **Open Exceptions** view in Automation Exceptions filtered to `Resolved` unchecked.

Views organize work but do not enforce permissions or state transitions.

## Checks before workflow integration

1. Create a Draft case with a complete employee, manager, department, and start date. Verify that the case lookups show the expected values.
2. Create another Draft case with a missing start date. Verify that the lookup appears empty.
3. Create one active global template, one active department template, one template for another department, and one inactive template. Verify their scope is visible.
4. Change a case to Ready and confirm that it appears in Ready Cases.
5. Confirm the total record count stays comfortably below Airtable Free's per-base limit.