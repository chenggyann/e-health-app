# 05. PIM ER Model

The ER model derives from the domain class model but is normalized for storage. Audit and consent are first-class because they are not optional in clinical systems.

```mermaid
erDiagram
  USERS {
    uuid id PK
    string email UK
    string phone
    string status
    datetime created_at
    datetime updated_at
  }

  ROLES {
    uuid id PK
    string name UK
    string description
  }

  USER_ROLES {
    uuid user_id FK
    uuid role_id FK
  }

  PATIENTS {
    uuid id PK
    uuid user_id FK
    string medical_record_number UK
    date date_of_birth
    string sex_at_birth
    string preferred_language
  }

  CLINICIANS {
    uuid id PK
    uuid user_id FK
    string provider_number UK
    string specialty
    boolean accepting_appointments
  }

  CARE_COORDINATORS {
    uuid id PK
    uuid user_id FK
    string team
  }

  CONSENTS {
    uuid id PK
    uuid patient_id FK
    string type
    string status
    datetime granted_at
    datetime revoked_at
  }

  APPOINTMENTS {
    uuid id PK
    uuid patient_id FK
    uuid clinician_id FK
    datetime scheduled_start
    datetime scheduled_end
    string type
    string status
    string reason
    datetime created_at
  }

  ENCOUNTERS {
    uuid id PK
    uuid appointment_id FK
    uuid patient_id FK
    uuid clinician_id FK
    datetime started_at
    datetime ended_at
    string status
    string chief_complaint
  }

  CLINICAL_NOTES {
    uuid id PK
    uuid encounter_id FK
    string type
    text subjective
    text objective
    text assessment
    text plan
    datetime signed_at
  }

  CARE_PLANS {
    uuid id PK
    uuid patient_id FK
    uuid encounter_id FK
    string status
    date start_date
    date review_date
  }

  CARE_GOALS {
    uuid id PK
    uuid care_plan_id FK
    text description
    string status
    date target_date
  }

  PRESCRIPTIONS {
    uuid id PK
    uuid encounter_id FK
    uuid patient_id FK
    uuid clinician_id FK
    string status
    datetime issued_at
    datetime expires_at
  }

  MEDICATION_ORDERS {
    uuid id PK
    uuid prescription_id FK
    string medication_name
    string dose
    string route
    string frequency
    int quantity
    int repeats
  }

  DISPENSE_RECORDS {
    uuid id PK
    uuid medication_order_id FK
    datetime dispensed_at
    int quantity_dispensed
    text pharmacist_note
  }

  ADHERENCE_LOGS {
    uuid id PK
    uuid medication_order_id FK
    uuid patient_id FK
    datetime taken_at
    string status
    text note
  }

  LAB_ORDERS {
    uuid id PK
    uuid encounter_id FK
    uuid patient_id FK
    uuid clinician_id FK
    string test_code
    string test_name
    string status
    datetime ordered_at
  }

  LAB_RESULTS {
    uuid id PK
    uuid lab_order_id FK
    string value
    string unit
    string reference_range
    string flag
    datetime resulted_at
    datetime acknowledged_at
  }

  VITAL_OBSERVATIONS {
    uuid id PK
    uuid patient_id FK
    string type
    decimal value
    string unit
    string source
    datetime observed_at
  }

  CLINICAL_ALERTS {
    uuid id PK
    uuid patient_id FK
    uuid vital_observation_id FK
    uuid lab_result_id FK
    string type
    string severity
    string status
    text message
    datetime raised_at
    datetime resolved_at
  }

  MESSAGE_THREADS {
    uuid id PK
    uuid patient_id FK
    string subject
    string status
    datetime created_at
    datetime closed_at
  }

  MESSAGES {
    uuid id PK
    uuid thread_id FK
    uuid sender_user_id FK
    text body
    string priority
    datetime sent_at
    datetime read_at
  }

  AUDIT_EVENTS {
    uuid id PK
    uuid actor_user_id FK
    string action
    string resource_type
    uuid resource_id
    datetime occurred_at
    string ip_address
  }

  USERS ||--o{ USER_ROLES : has
  ROLES ||--o{ USER_ROLES : assigned
  USERS ||--o| PATIENTS : owns
  USERS ||--o| CLINICIANS : owns
  USERS ||--o| CARE_COORDINATORS : owns
  PATIENTS ||--o{ CONSENTS : grants
  PATIENTS ||--o{ APPOINTMENTS : books
  CLINICIANS ||--o{ APPOINTMENTS : attends
  APPOINTMENTS ||--o| ENCOUNTERS : creates
  PATIENTS ||--o{ ENCOUNTERS : has
  CLINICIANS ||--o{ ENCOUNTERS : conducts
  ENCOUNTERS ||--o{ CLINICAL_NOTES : contains
  PATIENTS ||--o{ CARE_PLANS : has
  ENCOUNTERS ||--o| CARE_PLANS : updates
  CARE_PLANS ||--o{ CARE_GOALS : includes
  ENCOUNTERS ||--o{ PRESCRIPTIONS : issues
  PATIENTS ||--o{ PRESCRIPTIONS : receives
  CLINICIANS ||--o{ PRESCRIPTIONS : signs
  PRESCRIPTIONS ||--|{ MEDICATION_ORDERS : includes
  MEDICATION_ORDERS ||--o{ DISPENSE_RECORDS : dispensed
  MEDICATION_ORDERS ||--o{ ADHERENCE_LOGS : tracked
  PATIENTS ||--o{ ADHERENCE_LOGS : records
  ENCOUNTERS ||--o{ LAB_ORDERS : orders
  LAB_ORDERS ||--o{ LAB_RESULTS : returns
  PATIENTS ||--o{ VITAL_OBSERVATIONS : records
  PATIENTS ||--o{ CLINICAL_ALERTS : has
  VITAL_OBSERVATIONS ||--o{ CLINICAL_ALERTS : triggers
  LAB_RESULTS ||--o{ CLINICAL_ALERTS : triggers
  PATIENTS ||--o{ MESSAGE_THREADS : participates
  MESSAGE_THREADS ||--|{ MESSAGES : contains
  USERS ||--o{ MESSAGES : sends
  USERS ||--o{ AUDIT_EVENTS : performs
```

## Storage Notes

- `USER_ROLES` is a join table because one user can hold multiple roles, such as clinician and administrator.
- `PATIENTS`, `CLINICIANS`, and `CARE_COORDINATORS` are role-specific profiles owned by `USERS`.
- `ENCOUNTERS` stores direct `patient_id` and `clinician_id` for query efficiency and historical stability, even though it also relates to `APPOINTMENTS`.
- `CLINICAL_ALERTS` allows nullable origin references because alerts can be raised from vitals, lab results, messages, or manual clinician review.
- `AUDIT_EVENTS.resource_type` plus `resource_id` avoids coupling audit storage to every clinical table.
