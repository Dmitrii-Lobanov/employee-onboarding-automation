# Employee Onboarding Automation — Requirements

## Business outcome

An HR user creates an employee and an onboarding case in Airtable. Once the required information is prepared, HR changes the case from `Draft` to `Ready`.

A locally running n8n workflow finds Ready cases, processes each case, and creates onboarding tasks from reusable templates. HR can see whether a case is `Processing`, `Completed`, or `Failed` in Airtable. A Completed case means that all expected onboarding tasks have been generated; it does not mean that the employee has finished those tasks.

The project demonstrates an HR workflow that is understandable in Airtable, reliable in PostgreSQL, and recoverable after errors.

## Scope and boundaries

The project uses Airtable Free as the HR-facing interface, self-hosted n8n Community Edition for orchestration, and local PostgreSQL for constraints, audit records, reconciliation, and reporting. It must work without paid subscriptions, paid hosting, or features available only during a trial. Automation runs only while the local computer and services are running.

All employee information is synthetic. Notifications are represented by records in `notification_outbox`; no real email or Slack messages are sent. Credentials must remain outside committed files and exported n8n workflows.

The project excludes authentication, file uploads, equipment inventory, offboarding, department transfers, cloud deployment, real account provisioning, and complex approval chains. The implementation should fit a portfolio schedule of no more than two hours per day for one month.

## Business rules and assumptions

- A task template may apply to every department or to one specific department. Only active, applicable templates are selected.
- A task deadline is calculated by adding the template's calendar-day offset to the employee's start date. Negative offsets produce deadlines before the start date.
- A case with no applicable active templates fails with a clear reason.
- The employee's start date and applicable templates are assumed to remain unchanged during processing and retries. Handling changes after tasks have been generated is outside this project's scope.
- Only one workflow execution processes Ready cases at a time. Changing a case's status is a claim for this demonstration, but the status change alone does not protect against simultaneous executions.
- An expected task is identified by its onboarding case and task template. Repeated attempts must preserve that identity.
- Airtable and PostgreSQL are separate systems. If an operation succeeds in one and fails in the other, the attempt fails and the difference must be detectable and repairable on retry.

## Workflow states

| Current state | Next state | Meaning |
|---|---|---|
| Draft | Ready | HR submits a prepared case for processing |
| Ready | Processing | The workflow claims the case |
| Processing | Completed | Every expected task exists in Airtable and PostgreSQL |
| Processing | Failed | Validation or processing cannot finish |
| Failed | Ready | HR corrects the problem and requests another attempt |

No other state transitions are part of this project. A failure in one case must not prevent the workflow from processing other Ready cases.

## Business requirements

**BR-01 — HR preparation:** HR can create an employee and onboarding case in Airtable, review the required information, and mark the case Ready.

**BR-02 — Case claiming:** The workflow retrieves Ready cases and marks each case Processing before generating its tasks.

**BR-03 — Validation:** Processing requires an employee, manager, department, and employee start date. A missing value produces a specific, understandable failure reason.

**BR-04 — Template selection:** The workflow selects active global templates and active templates for the employee's department. If none apply, it fails the case with a clear reason.

**BR-05 — Deadlines:** Each generated task receives a deadline calculated from the employee start date and its template's calendar-day offset.

**BR-06 — Idempotent task generation:** Processing or retrying the same case does not create another task for a case-and-template combination that already exists. A retry creates only missing tasks.

**BR-07 — Completion:** A case becomes Completed only when every expected task exists in both Airtable and PostgreSQL.

**BR-08 — Failure isolation:** A validation or processing error marks the affected case Failed without stopping other Ready cases from being processed.

**BR-09 — Retry:** After HR corrects a Failed case and marks it Ready, the workflow can make another attempt without deleting its earlier audit history or duplicating tasks.

**BR-10 — Attempt audit:** Every processing attempt has a distinct workflow-run record. Failures include an error record with the affected case, attempt, and reason.

**BR-11 — Simulated notifications:** The workflow records intended notifications in PostgreSQL's `notification_outbox`. The records are auditable, and no real message is delivered.

**BR-12 — Reconciliation:** SQL reports can identify case-status mismatches and expected tasks missing from either Airtable or PostgreSQL.

**BR-13 — HR visibility:** Airtable views make Ready, Processing, Completed, and Failed cases visible so HR can identify work needing attention.

**BR-14 — Secret handling:** API tokens and database credentials are stored outside committed project files and exported n8n workflows.

## Measurable acceptance criteria

**AC-01 — Valid case (BR-01, BR-02, BR-04, BR-07):**  
Given a Ready case with valid employee information and three applicable active templates, when the workflow processes it, then the case is Completed and exactly three corresponding tasks exist in Airtable and PostgreSQL.

**AC-02 — Required information (BR-03, BR-08, BR-10):**  
Given four separate Ready cases missing, respectively, an employee, manager, department, or start date, when each is processed, then each becomes Failed and has an error record naming the missing information.

**AC-03 — Case isolation (BR-08):**  
Given one valid Ready case and one invalid Ready case, when the workflow processes both, then the valid case becomes Completed and the invalid case becomes Failed.

**AC-04 — Template selection (BR-04):**  
Given active global templates, active templates for the employee's department, templates for another department, and inactive templates, when a case is processed, then tasks are generated only from the active global and matching-department templates.

**AC-05 — No applicable templates (BR-04, BR-10):**  
Given a valid Ready case with no applicable active templates, when the workflow processes it, then it becomes Failed and its error record states that no templates apply.

**AC-06 — Deadline calculation (BR-05):**  
Given a start date of `2026-11-10` and applicable templates with offsets of `-3`, `0`, and `+2` calendar days, when tasks are generated, then their deadlines are `2026-11-07`, `2026-11-10`, and `2026-11-12`.

**AC-07 — Repeated processing (BR-06):**  
Given a case with three expected tasks already generated, when processing is repeated for that same case, then exactly three tasks remain in each system, with one task per case-and-template combination.

**AC-08 — Partial failure and retry (BR-06, BR-09):**  
Given a case with three applicable templates and only one task successfully created before an attempt fails, when the case is marked Ready and retried, then the existing task is preserved, the two missing tasks are created, and no duplicates exist.

**AC-09 — Corrected validation failure (BR-03, BR-09):**  
Given a case that failed because its start date was missing, when HR supplies the start date and changes the case from Failed to Ready, then the next attempt can complete it.

**AC-10 — Attempt history (BR-10):**  
Given a case that fails once and succeeds on retry, when its audit history is inspected, then two distinct workflow runs are visible and the earlier failure remains recorded.

**AC-11 — Completion guard (BR-07):**  
Given an expected task missing from Airtable or PostgreSQL, when the workflow checks the case, then it does not mark the case Completed.

**AC-12 — Notification outbox (BR-11):**  
Given a case that completes, when its results are inspected, then an outbox record describes the intended notification and no email or Slack message has been sent.

**AC-13 — Reconciliation (BR-12):**  
Given a deliberately missing task or mismatched case status between Airtable and PostgreSQL, when the reconciliation report runs, then it identifies the affected case and the difference.

**AC-14 — HR visibility (BR-13):**  
Given cases in Ready, Processing, Completed, and Failed states, when HR opens the relevant Airtable views, then each case appears in the appropriate view and Failed cases show the reason requiring attention.

**AC-15 — Secrets (BR-14):**  
Given the committed project files and exported n8n workflows, when they are inspected, then no Airtable token, database password, or other connection secret appears.