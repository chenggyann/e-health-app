# 01. CIM Context Model

The computation independent model describes the healthcare problem and stakeholder goals without committing to a framework, database, or deployment platform.

## Stakeholders

| Stakeholder | Goal | Primary concerns |
| --- | --- | --- |
| Patient | Access care, appointments, medications, results, and secure messages | Ease of use, privacy, reminders, continuity of care |
| Clinician | Review patient context, conduct consultations, prescribe, and follow up | Clinical safety, complete records, decision support |
| Care coordinator | Triage messages, coordinate follow-ups, monitor alerts | Work queue clarity, escalation paths |
| Pharmacist | Fulfill prescriptions and report dispensing status | Prescription validity, dosage clarity |
| Lab provider | Receive lab orders and return results | Correct patient matching, result integrity |
| System administrator | Manage users, access, configuration, and audit obligations | Security, role-based access control, compliance |

## Capability Map

```mermaid
flowchart LR
  PatientCare["Patient care"]
  Identity["Identity and consent"]
  Scheduling["Scheduling"]
  Consultation["Consultation"]
  Medication["Medication management"]
  Diagnostics["Diagnostics and vitals"]
  Messaging["Secure messaging"]
  Audit["Audit and governance"]

  PatientCare --> Identity
  PatientCare --> Scheduling
  PatientCare --> Consultation
  PatientCare --> Medication
  PatientCare --> Diagnostics
  PatientCare --> Messaging
  PatientCare --> Audit

  Scheduling --> ApptBook["Book appointment"]
  Scheduling --> ApptChange["Reschedule or cancel"]
  Scheduling --> Reminders["Send reminders"]

  Consultation --> Telehealth["Run telehealth session"]
  Consultation --> Encounter["Record encounter"]
  Consultation --> CarePlan["Maintain care plan"]

  Medication --> Prescribe["Issue prescription"]
  Medication --> Dispense["Track dispensing"]
  Medication --> Adherence["Monitor adherence"]

  Diagnostics --> LabOrders["Order labs"]
  Diagnostics --> LabResults["Review lab results"]
  Diagnostics --> Vitals["Capture vitals"]
  Diagnostics --> Alerts["Escalate clinical alerts"]
```

## Use Case Diagram

```mermaid
flowchart LR
  Patient((Patient))
  Clinician((Clinician))
  Coordinator((Care coordinator))
  Pharmacist((Pharmacist))
  Lab((Lab provider))
  Admin((Administrator))

  Register["Register and manage profile"]
  Consent["Manage consent"]
  Book["Book appointment"]
  Attend["Attend telehealth consultation"]
  Message["Send secure message"]
  ViewResults["View lab results"]
  TrackMeds["Track medications"]

  ReviewChart["Review patient chart"]
  Conduct["Conduct consultation"]
  Prescribe["Create prescription"]
  OrderLabs["Order lab tests"]
  ReviewAlerts["Review clinical alerts"]

  Triage["Triage patient messages"]
  Escalate["Escalate alert"]
  Dispense["Dispense medication"]
  SubmitResult["Submit lab result"]
  ManageUsers["Manage users and roles"]
  AuditLogs["Review audit logs"]

  Patient --> Register
  Patient --> Consent
  Patient --> Book
  Patient --> Attend
  Patient --> Message
  Patient --> ViewResults
  Patient --> TrackMeds

  Clinician --> ReviewChart
  Clinician --> Conduct
  Clinician --> Prescribe
  Clinician --> OrderLabs
  Clinician --> ReviewAlerts

  Coordinator --> Triage
  Coordinator --> Escalate
  Pharmacist --> Dispense
  Lab --> SubmitResult
  Admin --> ManageUsers
  Admin --> AuditLogs
```

## Business Rules At CIM Level

- A patient must grant active consent before telehealth care can start.
- A clinical action must be attributable to an authenticated user or trusted system actor.
- A patient cannot have two confirmed appointments that overlap.
- A clinician cannot sign a prescription if a blocking allergy or interaction is unresolved.
- Critical lab results and out-of-range vitals must create a reviewable clinical alert.
- Clinical records must preserve audit history when viewed, changed, signed, or transmitted.
