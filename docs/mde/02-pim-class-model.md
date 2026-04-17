# 02. PIM Domain Class Model

The platform independent class model focuses on domain semantics, not implementation details such as controllers, framework hooks, or SQL column syntax.

```mermaid
classDiagram
  direction LR

  class User {
    +UUID id
    +String email
    +String phone
    +UserStatus status
    +DateTime createdAt
    +verifyIdentity()
    +deactivate()
  }

  class Role {
    +UUID id
    +RoleName name
    +String description
  }

  class Patient {
    +UUID id
    +String medicalRecordNumber
    +Date dateOfBirth
    +String sexAtBirth
    +String preferredLanguage
    +recordConsent()
    +requestAppointment()
  }

  class Clinician {
    +UUID id
    +String providerNumber
    +ClinicalSpecialty specialty
    +Boolean acceptingAppointments
    +openEncounter()
    +signEncounter()
  }

  class CareCoordinator {
    +UUID id
    +String team
    +assignTask()
    +escalateAlert()
  }

  class Consent {
    +UUID id
    +ConsentType type
    +ConsentStatus status
    +DateTime grantedAt
    +DateTime revokedAt
    +isActive()
  }

  class Appointment {
    +UUID id
    +DateTime scheduledStart
    +DateTime scheduledEnd
    +AppointmentType type
    +AppointmentStatus status
    +String reason
    +confirm()
    +checkIn()
    +cancel()
    +reschedule()
  }

  class Encounter {
    +UUID id
    +DateTime startedAt
    +DateTime endedAt
    +EncounterStatus status
    +String chiefComplaint
    +start()
    +document()
    +sign()
    +amend()
  }

  class ClinicalNote {
    +UUID id
    +NoteType type
    +String subjective
    +String objective
    +String assessment
    +String plan
    +DateTime signedAt
  }

  class CarePlan {
    +UUID id
    +CarePlanStatus status
    +Date startDate
    +Date reviewDate
    +addGoal()
    +completeGoal()
  }

  class CareGoal {
    +UUID id
    +String description
    +GoalStatus status
    +Date targetDate
  }

  class Prescription {
    +UUID id
    +PrescriptionStatus status
    +DateTime issuedAt
    +DateTime expiresAt
    +sign()
    +cancel()
  }

  class MedicationOrder {
    +UUID id
    +String medicationName
    +String dose
    +String route
    +String frequency
    +Int quantity
    +Int repeats
    +validateDose()
  }

  class DispenseRecord {
    +UUID id
    +DateTime dispensedAt
    +Int quantityDispensed
    +String pharmacistNote
  }

  class AdherenceLog {
    +UUID id
    +DateTime takenAt
    +AdherenceStatus status
    +String note
  }

  class LabOrder {
    +UUID id
    +String testCode
    +String testName
    +LabOrderStatus status
    +DateTime orderedAt
    +cancel()
    +markCollected()
  }

  class LabResult {
    +UUID id
    +String value
    +String unit
    +String referenceRange
    +ResultFlag flag
    +DateTime resultedAt
    +acknowledge()
  }

  class VitalObservation {
    +UUID id
    +VitalType type
    +Decimal value
    +String unit
    +DateTime observedAt
    +ObservationSource source
    +isOutOfRange()
  }

  class ClinicalAlert {
    +UUID id
    +AlertType type
    +AlertSeverity severity
    +AlertStatus status
    +String message
    +DateTime raisedAt
    +acknowledge()
    +resolve()
    +escalate()
  }

  class SecureMessageThread {
    +UUID id
    +ThreadStatus status
    +String subject
    +open()
    +close()
  }

  class SecureMessage {
    +UUID id
    +String body
    +DateTime sentAt
    +DateTime readAt
    +MessagePriority priority
    +markRead()
  }

  class AuditEvent {
    +UUID id
    +String actorId
    +String action
    +String resourceType
    +String resourceId
    +DateTime occurredAt
    +String ipAddress
  }

  User "1" -- "0..1" Patient : profile
  User "1" -- "0..1" Clinician : profile
  User "1" -- "0..1" CareCoordinator : profile
  User "0..*" -- "1..*" Role : assigned
  Patient "1" -- "0..*" Consent : grants
  Patient "1" -- "0..*" Appointment : books
  Clinician "1" -- "0..*" Appointment : attends
  Appointment "0..1" -- "0..1" Encounter : creates
  Encounter "1" -- "0..*" ClinicalNote : contains
  Encounter "1" -- "0..1" CarePlan : updates
  CarePlan "1" -- "1..*" CareGoal : includes
  Encounter "1" -- "0..*" Prescription : issues
  Prescription "1" -- "1..*" MedicationOrder : includes
  MedicationOrder "1" -- "0..*" DispenseRecord : dispensedAs
  MedicationOrder "1" -- "0..*" AdherenceLog : trackedBy
  Encounter "1" -- "0..*" LabOrder : orders
  LabOrder "1" -- "0..*" LabResult : returns
  Patient "1" -- "0..*" VitalObservation : records
  VitalObservation "0..1" -- "0..*" ClinicalAlert : raises
  LabResult "0..1" -- "0..*" ClinicalAlert : raises
  Patient "1" -- "0..*" SecureMessageThread : participates
  SecureMessageThread "1" -- "1..*" SecureMessage : contains
  User "1" -- "0..*" SecureMessage : sends
  User "1" -- "0..*" AuditEvent : performs
```

## Modeling Notes

- `User` is separated from clinical profiles so authentication can evolve independently from patient and clinician records.
- `Consent` and `AuditEvent` are modeled as domain concepts, not secondary infrastructure.
- `Prescription` is the legal clinical artifact. `MedicationOrder` represents one medication line inside the prescription.
- `ClinicalAlert` can originate from multiple clinical facts, such as vital observations or lab results.
- `SecureMessageThread` is modeled separately from `SecureMessage` so triage, escalation, and closure can occur at the conversation level.
