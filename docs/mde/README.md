# E-Health App MDE Model Package

This package is structured as a model driven engineering artifact set for an e-health application. It separates the problem model from implementation choices so the same domain model can drive UI flows, API contracts, database schema, validation rules, and tests.

## Modeling Levels

| MDE level | Purpose | Artifacts in this package |
| --- | --- | --- |
| CIM, computation independent model | Describe the healthcare problem without technical platform assumptions | Stakeholders, capabilities, business rules, use case diagram |
| PIM, platform independent model | Define stable domain structure and behavior | Class diagram, state diagrams, sequence diagrams, ER diagram |
| PSM, platform specific model | Map PIM concepts to implementable services and storage | Component diagram, persistence mapping, API boundary guidance |
| Transformation and validation | Keep models traceable to generated code and tests | Traceability matrix, invariants, generation targets |

## Assumed Scope

The workspace was empty when this package was generated, so the models assume a greenfield patient care app with:

- Patient registration and profile management
- Appointment booking and telehealth consultation
- Encounter notes and care plan management
- Prescription, medication adherence, and refill workflows
- Lab order, lab result, vital sign, and clinical alert workflows
- Secure messaging between patients, clinicians, and care coordinators

## Files

- [01-cim-context.md](./01-cim-context.md): stakeholder, capability, and use case models.
- [02-pim-class-model.md](./02-pim-class-model.md): platform independent domain class model.
- [03-pim-state-models.md](./03-pim-state-models.md): rich lifecycle state models.
- [04-pim-sequence-models.md](./04-pim-sequence-models.md): interaction models that explain cross-component behavior.
- [05-pim-er-model.md](./05-pim-er-model.md): normalized data model derived from the domain model.
- [06-psm-traceability.md](./06-psm-traceability.md): component boundaries, transformations, invariants, and traceability.

## How To Use These Models

1. Review the CIM scope and capability model with non-technical stakeholders.
2. Use the PIM class, state, and sequence diagrams as the source of truth for behavior.
3. Derive database tables, API resources, frontend routes, and validation schemas from the PIM.
4. Use the traceability matrix to show that each user-facing feature has a domain model, behavior model, storage model, and candidate test coverage.
5. Treat implementation code as generated or conformed output. If implementation behavior diverges, update the model first or document an intentional platform-specific deviation.
