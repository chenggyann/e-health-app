# 04. PIM Sequence Models

Sequence diagrams add dynamic richness to the state models by showing cross-boundary collaboration. Participants represent responsibilities, not specific libraries.

## Appointment Booking And Check-In

```mermaid
sequenceDiagram
  autonumber
  actor Patient
  participant App as Patient App
  participant Scheduling as Scheduling Service
  participant Clinician as Clinician Calendar
  participant Notify as Notification Service
  participant Audit as Audit Log

  Patient->>App: Search for appointment by reason and preference
  App->>Scheduling: Request available slots
  Scheduling->>Clinician: Query eligible clinician availability
  Clinician-->>Scheduling: Return matching slots
  Scheduling-->>App: Present available slots
  Patient->>App: Select slot and submit booking
  App->>Scheduling: Create appointment request
  Scheduling->>Scheduling: Validate eligibility, consent, slot hold
  alt Slot accepted
    Scheduling->>Clinician: Reserve slot
    Scheduling->>Notify: Send confirmation and reminders
    Scheduling->>Audit: Record appointment creation
    Scheduling-->>App: Appointment confirmed
  else Slot no longer available
    Scheduling-->>App: Offer alternate slots or waitlist
  end
  Patient->>App: Check in before appointment
  App->>Scheduling: Mark appointment checked in
  Scheduling->>Audit: Record patient check-in
```

## Telehealth Encounter And Care Plan

```mermaid
sequenceDiagram
  autonumber
  actor Clinician
  actor Patient
  participant App as Care Team App
  participant Encounter as Encounter Service
  participant Chart as Patient Chart
  participant Rules as Clinical Rules
  participant Notify as Notification Service
  participant Audit as Audit Log

  Clinician->>App: Start consultation
  App->>Encounter: Open encounter for appointment
  Encounter->>Chart: Load problems, medications, allergies, recent results
  Chart-->>Encounter: Return patient context
  Encounter-->>App: Encounter active
  Clinician->>Patient: Conduct consultation
  Clinician->>App: Record notes, diagnosis, and plan
  App->>Encounter: Save draft clinical note
  Encounter->>Rules: Check required sections and risk triggers
  alt High-risk finding detected
    Rules-->>Encounter: Raise alert recommendation
    Encounter->>Notify: Notify care coordinator
  else No alert
    Rules-->>Encounter: Continue
  end
  Clinician->>App: Sign encounter
  App->>Encounter: Sign and close encounter
  Encounter->>Chart: Persist signed note and care plan
  Encounter->>Audit: Record clinical sign-off
  Encounter->>Notify: Send patient summary
```

## Prescription Safety And Dispensing

```mermaid
sequenceDiagram
  autonumber
  actor Clinician
  actor Pharmacist
  participant App as Care Team App
  participant Rx as Prescription Service
  participant Chart as Patient Chart
  participant Safety as Medication Safety Rules
  participant Pharmacy as Pharmacy Gateway
  participant Audit as Audit Log

  Clinician->>App: Add medication order
  App->>Rx: Create draft prescription
  Rx->>Chart: Fetch allergies, conditions, active medications
  Chart-->>Rx: Return medication context
  Rx->>Safety: Validate dose, duplication, allergy, interaction
  alt Safety issue found
    Safety-->>Rx: Return blocking or warning issue
    Rx-->>App: Require edit or override rationale
  else Safety checks pass
    Safety-->>Rx: Approve for signature
    Clinician->>App: Sign prescription
    App->>Rx: Apply clinician signature
    Rx->>Pharmacy: Transmit signed prescription
    Pharmacy-->>Rx: Accepted
    Rx->>Audit: Record prescription transmission
    Pharmacist->>Pharmacy: Dispense medication
    Pharmacy->>Rx: Submit dispense record
    Rx->>Chart: Update active medication and repeats
  end
```

## Abnormal Vital Sign Alert

```mermaid
sequenceDiagram
  autonumber
  actor Patient
  actor Coordinator as Care Coordinator
  actor Clinician
  participant Device as Home Device
  participant Vitals as Vitals Service
  participant Rules as Clinical Rules
  participant Alerts as Alert Service
  participant Notify as Notification Service
  participant Chart as Patient Chart

  Patient->>Device: Take blood pressure reading
  Device->>Vitals: Submit observation
  Vitals->>Rules: Evaluate against patient-specific thresholds
  alt Reading within expected range
    Rules-->>Vitals: Store only
    Vitals->>Chart: Add observation to chart
  else Reading abnormal
    Rules-->>Vitals: Trigger alert with severity
    Vitals->>Alerts: Create clinical alert
    Alerts->>Notify: Notify coordinator
    Coordinator->>Alerts: Acknowledge alert
    Coordinator->>Chart: Review context
    alt Emergency symptoms present
      Coordinator->>Alerts: Escalate to clinician
      Alerts->>Notify: Notify clinician immediately
      Clinician->>Alerts: Resolve with emergency action
    else Routine follow-up
      Coordinator->>Alerts: Create follow-up task
      Alerts->>Chart: Record alert outcome
    end
  end
```

## Patient Secure Messaging Triage

```mermaid
sequenceDiagram
  autonumber
  actor Patient
  actor Coordinator as Care Coordinator
  actor Clinician
  participant App as Patient App
  participant Msg as Messaging Service
  participant Triage as Triage Rules
  participant Alerts as Alert Service
  participant Audit as Audit Log

  Patient->>App: Send message to care team
  App->>Msg: Create message in thread
  Msg->>Triage: Evaluate priority, symptoms, and keywords
  alt Urgent clinical risk
    Triage-->>Msg: Escalate
    Msg->>Alerts: Create message-derived clinical alert
    Msg->>Audit: Record urgent message event
    Alerts->>Clinician: Notify clinician
  else Routine request
    Triage-->>Msg: Assign routine queue
    Msg->>Coordinator: Add to triage work queue
  end
  Coordinator->>Msg: Reply or assign clinician
  Clinician->>Msg: Provide clinical response when needed
  Msg->>Audit: Record message access and response
```
