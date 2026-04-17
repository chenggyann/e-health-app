# 03. PIM State Models

These state diagrams are behavioral and business-facing. They show lifecycle, guards, and events without turning into implementation code.

## Appointment Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Draft: Patient selects slot
  Draft --> Requested: Submit request
  Draft --> Abandoned: Slot hold expires

  Requested --> Confirmed: Clinician or rules engine accepts
  Requested --> Rejected: No eligible clinician
  Requested --> Waitlisted: No slot available but waitlist accepted
  Waitlisted --> Requested: Slot released

  Confirmed --> ReminderPending: Reminder window reached
  ReminderPending --> Confirmed: Reminder sent
  Confirmed --> CheckedIn: Patient checks in
  Confirmed --> RescheduleRequested: Patient requests new time
  Confirmed --> Cancelled: Patient or clinic cancels
  Confirmed --> NoShow: Check-in deadline missed

  RescheduleRequested --> Confirmed: New slot accepted
  RescheduleRequested --> Cancelled: Reschedule rejected and patient cancels

  CheckedIn --> InConsultation: Clinician starts encounter
  CheckedIn --> NoShow: Clinician marks absent after grace period
  InConsultation --> Completed: Encounter closed
  InConsultation --> FollowUpRequired: Clinician requests follow-up
  FollowUpRequired --> Completed: Follow-up task created

  Completed --> [*]
  Cancelled --> [*]
  Rejected --> [*]
  NoShow --> [*]
  Abandoned --> [*]
```

## Encounter Lifecycle

```mermaid
stateDiagram-v2
  [*] --> NotStarted
  NotStarted --> Active: Clinician opens encounter

  Active --> CollectingHistory: Patient context reviewed
  CollectingHistory --> Examining: Symptoms and vitals captured
  Examining --> Assessing: Clinical assessment started
  Assessing --> Planning: Diagnosis and plan drafted

  Planning --> AwaitingOrders: Labs or prescriptions pending
  AwaitingOrders --> Planning: Orders completed or removed
  Planning --> ReadyToSign: Required sections complete

  ReadyToSign --> Active: Missing information discovered
  ReadyToSign --> Signed: Clinician signs
  Signed --> Amended: Addendum required after sign-off
  Amended --> Signed: Addendum signed

  Signed --> Closed: Billing, audit, and patient summary completed
  Closed --> [*]

  Active --> Cancelled: Encounter opened in error
  Cancelled --> [*]
```

## Prescription Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Draft
  Draft --> Validating: Clinician enters medication order
  Validating --> Draft: Dose, allergy, or interaction issue found
  Validating --> PendingSignature: Safety checks pass

  PendingSignature --> Signed: Clinician signs
  PendingSignature --> Cancelled: Clinician discards
  Signed --> SentToPharmacy: Patient chooses pharmacy
  SentToPharmacy --> AcceptedByPharmacy: Pharmacy validates prescription
  SentToPharmacy --> TransmissionFailed: Pharmacy endpoint unavailable
  TransmissionFailed --> SentToPharmacy: Retry transmission

  AcceptedByPharmacy --> PartiallyDispensed: Partial quantity supplied
  AcceptedByPharmacy --> Dispensed: Full quantity supplied
  PartiallyDispensed --> Dispensed: Remaining quantity supplied

  Dispensed --> ActiveMedication: Patient starts medication
  ActiveMedication --> RefillDue: Refill threshold reached
  RefillDue --> RenewalRequested: Patient requests repeat or renewal
  RenewalRequested --> Signed: Clinician approves renewal
  RenewalRequested --> Expired: Prescription no longer valid

  ActiveMedication --> Completed: Course finished
  ActiveMedication --> Stopped: Clinician discontinues
  Signed --> Cancelled: Safety recall or clinician cancellation
  Expired --> [*]
  Completed --> [*]
  Stopped --> [*]
  Cancelled --> [*]
```

## Clinical Alert Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Raised: Abnormal result, vital, or rule trigger
  Raised --> Routed: Severity and care team selected
  Routed --> Acknowledged: Responsible user accepts alert
  Routed --> Escalated: No acknowledgement within SLA
  Acknowledged --> InReview: Patient context reviewed
  InReview --> ActionRequired: Follow-up, medication change, or appointment needed
  InReview --> FalsePositive: Clinician marks not clinically relevant
  ActionRequired --> Resolved: Action completed and documented
  Escalated --> Acknowledged: Senior clinician accepts
  Escalated --> Resolved: Emergency workflow completed
  FalsePositive --> Closed: Rationale recorded
  Resolved --> Closed: Outcome audited
  Closed --> [*]
```

## Secure Message Thread Lifecycle

```mermaid
stateDiagram-v2
  [*] --> Open: Patient or care team starts thread
  Open --> AwaitingPatient: Care team replies with question
  Open --> AwaitingCareTeam: Patient sends message
  AwaitingPatient --> AwaitingCareTeam: Patient responds
  AwaitingCareTeam --> Triage: Priority or keyword rule triggered
  Triage --> AwaitingCareTeam: Routine message assigned
  Triage --> Escalated: Urgent symptoms or safety risk
  Escalated --> AwaitingCareTeam: Clinician accepts escalation
  AwaitingCareTeam --> Resolved: Care team answer accepted
  AwaitingPatient --> Resolved: Patient confirms issue resolved
  Resolved --> Closed: Retention and audit metadata complete
  Closed --> Reopened: New message before closure grace period ends
  Reopened --> AwaitingCareTeam
  Closed --> [*]
```

## State Model Implementation Guidance

| State model | Domain aggregate | Commands to derive | Tests to derive |
| --- | --- | --- | --- |
| Appointment lifecycle | Appointment | request, confirm, check in, reschedule, cancel, complete | invalid overlap, expired slot hold, no-show deadline |
| Encounter lifecycle | Encounter | open, save note, order item, sign, amend, close | cannot sign incomplete note, amendment requires signed encounter |
| Prescription lifecycle | Prescription | draft order, validate, sign, transmit, record dispense, renew | allergy block, expiry, repeat count, transmission retry |
| Clinical alert lifecycle | ClinicalAlert | raise, route, acknowledge, escalate, resolve, close | SLA escalation, false positive rationale, critical routing |
| Message thread lifecycle | SecureMessageThread | open, post message, triage, escalate, resolve, close, reopen | urgent keyword routing, closed thread grace period |
