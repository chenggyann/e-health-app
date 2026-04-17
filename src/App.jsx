import { useEffect, useMemo, useState } from 'react';
import {
  classifyVital,
  createInitialRecords,
  initialClinicians,
  initialPatients,
  transitionAlert,
  transitionAppointment,
  transitionEncounter,
  triageMessage,
} from './lib/domain.js';
import { clearOfflineState, loadOfflineState, saveOfflineState } from './lib/offlineStore.js';
import { runQuery, supabase, supabaseUrl } from './lib/supabase.js';

const tables = {
  patients: 'patients',
  clinicians: 'clinicians',
  appointments: 'appointments',
  encounters: 'encounters',
  prescriptions: 'prescriptions',
  labOrders: 'lab_orders',
  vitals: 'vital_observations',
  alerts: 'clinical_alerts',
  messageThreads: 'message_threads',
  auditEvents: 'audit_events',
};

const emptyState = {
  patients: [],
  clinicians: [],
  appointments: [],
  encounters: [],
  prescriptions: [],
  labOrders: [],
  vitals: [],
  alerts: [],
  messageThreads: [],
  auditEvents: [],
};

function seedState() {
  const patients = initialPatients;
  const clinicians = initialClinicians;
  const records = createInitialRecords(patients[0].id, clinicians[0].id);

  return {
    ...emptyState,
    patients,
    clinicians,
    appointments: records.appointments,
    encounters: records.encounters,
    prescriptions: records.prescriptions,
    labOrders: records.labOrders,
    vitals: records.vitals,
    alerts: records.alerts,
    messageThreads: records.messageThreads,
  };
}

export function App() {
  const [data, setData] = useState(emptyState);
  const [selectedPatientId, setSelectedPatientId] = useState('');
  const [backend, setBackend] = useState({
    mode: 'loading',
    message: 'Connecting to Supabase...',
  });
  const [patientForm, setPatientForm] = useState({
    full_name: '',
    date_of_birth: '',
    preferred_language: 'English',
    risk_level: 'Moderate',
    care_goal: '',
  });
  const [appointmentForm, setAppointmentForm] = useState({
    clinician_id: '',
    scheduled_start: '',
    reason: '',
    type: 'Telehealth',
  });
  const [vitalForm, setVitalForm] = useState({
    type: 'Blood pressure systolic',
    value: '',
    unit: 'mmHg',
    source: 'Home device',
  });
  const [messageBody, setMessageBody] = useState('');
  const [prescriptionForm, setPrescriptionForm] = useState({
    medication_name: '',
    dose: '',
    route: 'Oral',
    frequency: '',
    repeats: 0,
  });
  const [labForm, setLabForm] = useState({
    test_name: '',
    flag: 'Pending',
  });

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const loaded = {};

        await Promise.all(
          Object.entries(tables).map(async ([stateKey, table]) => {
            loaded[stateKey] = await runQuery(
              `load ${table}`,
              supabase.from(table).select('*').order('created_at', { ascending: false }),
            );
          }),
        );

        if (!active) return;

        const next = { ...emptyState, ...loaded };

        if (next.patients.length === 0 || next.clinicians.length === 0) {
          const seeded = seedState();
          setData(seeded);
          setSelectedPatientId(seeded.patients[0]?.id || '');
          setBackend({
            mode: 'supabase',
            message: 'Supabase connected. Use "Seed Supabase" to add demo records.',
          });
          return;
        }

        setData(next);
        setSelectedPatientId(next.patients[0]?.id || '');
        setBackend({
          mode: 'supabase',
          message: 'Supabase connected. Clinical records are persisted.',
        });
      } catch (error) {
        const offline = loadOfflineState(seedState);
        if (!active) return;
        setData(offline);
        setSelectedPatientId(offline.patients[0]?.id || '');
        setBackend({
          mode: 'offline',
          message: `${error.message}. Using browser storage until the Supabase schema is applied.`,
        });
      }
    }

    load();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (backend.mode === 'offline') {
      saveOfflineState(data);
    }
  }, [backend.mode, data]);

  const selectedPatient = data.patients.find((patient) => patient.id === selectedPatientId);
  const selectedClinician = data.clinicians[0];

  const patientRecords = useMemo(() => {
    const byPatient = (item) => item.patient_id === selectedPatientId;

    return {
      appointments: data.appointments.filter(byPatient),
      encounters: data.encounters.filter(byPatient),
      prescriptions: data.prescriptions.filter(byPatient),
      labOrders: data.labOrders.filter(byPatient),
      vitals: data.vitals.filter(byPatient),
      alerts: data.alerts.filter(byPatient),
      messageThreads: data.messageThreads.filter(byPatient),
    };
  }, [data, selectedPatientId]);

  async function persistInsert(stateKey, record) {
    setData((current) => ({
      ...current,
      [stateKey]: [record, ...current[stateKey]],
    }));

    if (backend.mode !== 'supabase') return;

    try {
      await runQuery(
        `insert ${tables[stateKey]}`,
        supabase.from(tables[stateKey]).insert(record).select().single(),
      );
    } catch (error) {
      setBackend({
        mode: 'offline',
        message: `${error.message}. Switched to browser storage.`,
      });
    }
  }

  async function persistUpdate(stateKey, id, patch) {
    setData((current) => ({
      ...current,
      [stateKey]: current[stateKey].map((item) =>
        item.id === id ? { ...item, ...patch } : item,
      ),
    }));

    if (backend.mode !== 'supabase') return;

    try {
      await runQuery(
        `update ${tables[stateKey]}`,
        supabase.from(tables[stateKey]).update(patch).eq('id', id).select().single(),
      );
    } catch (error) {
      setBackend({
        mode: 'offline',
        message: `${error.message}. Switched to browser storage.`,
      });
    }
  }

  async function writeAudit(action, resourceType, resourceId) {
    await persistInsert('auditEvents', {
      id: crypto.randomUUID(),
      actor_name: 'CareFlow Demo User',
      action,
      resource_type: resourceType,
      resource_id: resourceId,
      occurred_at: new Date().toISOString(),
    });
  }

  async function seedSupabase() {
    const seeded = seedState();
    setData(seeded);
    setSelectedPatientId(seeded.patients[0]?.id || '');

    if (backend.mode !== 'supabase') {
      clearOfflineState();
      saveOfflineState(seeded);
      setBackend({
        mode: 'offline',
        message: 'Demo records reset in browser storage.',
      });
      return;
    }

    try {
      await Promise.all([
        runQuery('seed patients', supabase.from('patients').upsert(seeded.patients)),
        runQuery('seed clinicians', supabase.from('clinicians').upsert(seeded.clinicians)),
        runQuery('seed appointments', supabase.from('appointments').upsert(seeded.appointments)),
        runQuery('seed encounters', supabase.from('encounters').upsert(seeded.encounters)),
        runQuery('seed prescriptions', supabase.from('prescriptions').upsert(seeded.prescriptions)),
        runQuery('seed lab orders', supabase.from('lab_orders').upsert(seeded.labOrders)),
        runQuery('seed vitals', supabase.from('vital_observations').upsert(seeded.vitals)),
        runQuery('seed alerts', supabase.from('clinical_alerts').upsert(seeded.alerts)),
        runQuery(
          'seed message threads',
          supabase.from('message_threads').upsert(seeded.messageThreads),
        ),
      ]);
      setBackend({
        mode: 'supabase',
        message: 'Demo records seeded in Supabase.',
      });
    } catch (error) {
      setBackend({
        mode: 'offline',
        message: `${error.message}. Demo records are available in browser storage.`,
      });
    }
  }

  async function addPatient(event) {
    event.preventDefault();
    const record = {
      id: crypto.randomUUID(),
      ...patientForm,
      created_at: new Date().toISOString(),
    };

    await persistInsert('patients', record);
    setSelectedPatientId(record.id);
    setPatientForm({
      full_name: '',
      date_of_birth: '',
      preferred_language: 'English',
      risk_level: 'Moderate',
      care_goal: '',
    });
    await writeAudit('patient.created', 'Patient', record.id);
  }

  async function bookAppointment(event) {
    event.preventDefault();
    if (!selectedPatient) return;

    const start = new Date(appointmentForm.scheduled_start);
    const end = new Date(start.getTime() + 30 * 60 * 1000);
    const record = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      clinician_id: appointmentForm.clinician_id || selectedClinician?.id,
      scheduled_start: start.toISOString(),
      scheduled_end: end.toISOString(),
      type: appointmentForm.type,
      status: 'Requested',
      reason: appointmentForm.reason,
      created_at: new Date().toISOString(),
    };

    await persistInsert('appointments', record);
    setAppointmentForm({
      clinician_id: '',
      scheduled_start: '',
      reason: '',
      type: 'Telehealth',
    });
    await writeAudit('appointment.requested', 'Appointment', record.id);
  }

  async function moveAppointment(appointment, action) {
    const status = transitionAppointment(appointment.status, action);
    await persistUpdate('appointments', appointment.id, { status });

    if (action === 'startConsultation') {
      const encounter = {
        id: crypto.randomUUID(),
        appointment_id: appointment.id,
        patient_id: appointment.patient_id,
        clinician_id: appointment.clinician_id,
        status: 'Active',
        chief_complaint: appointment.reason,
        assessment: '',
        plan: '',
        started_at: new Date().toISOString(),
      };
      await persistInsert('encounters', encounter);
      await writeAudit('encounter.opened', 'Encounter', encounter.id);
    }

    await writeAudit(`appointment.${action}`, 'Appointment', appointment.id);
  }

  async function moveEncounter(encounter, action) {
    const status = transitionEncounter(encounter.status, action);
    const patch = {
      status,
      ended_at: status === 'Closed' ? new Date().toISOString() : encounter.ended_at,
    };

    await persistUpdate('encounters', encounter.id, patch);
    await writeAudit(`encounter.${action}`, 'Encounter', encounter.id);
  }

  async function addVital(event) {
    event.preventDefault();
    if (!selectedPatient) return;

    const value = Number(vitalForm.value);
    const vital = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      type: vitalForm.type,
      value,
      unit: vitalForm.unit,
      source: vitalForm.source,
      observed_at: new Date().toISOString(),
    };
    await persistInsert('vitals', vital);

    const alert = classifyVital(vital.type, vital.value);
    if (alert) {
      await persistInsert('alerts', {
        id: crypto.randomUUID(),
        patient_id: selectedPatient.id,
        vital_observation_id: vital.id,
        type: 'VitalObservation',
        severity: alert.severity,
        status: 'Raised',
        message: alert.message,
        raised_at: new Date().toISOString(),
      });
    }

    setVitalForm({
      type: 'Blood pressure systolic',
      value: '',
      unit: 'mmHg',
      source: 'Home device',
    });
    await writeAudit('vital.recorded', 'VitalObservation', vital.id);
  }

  async function moveAlert(alert, action) {
    const status = transitionAlert(alert.status, action);
    await persistUpdate('alerts', alert.id, {
      status,
      resolved_at: status === 'Resolved' ? new Date().toISOString() : alert.resolved_at,
    });
    await writeAudit(`alert.${action}`, 'ClinicalAlert', alert.id);
  }

  async function sendMessage(event) {
    event.preventDefault();
    if (!selectedPatient || messageBody.trim() === '') return;

    const triage = triageMessage(messageBody);
    const thread = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      subject: triage.priority === 'Urgent' ? 'Urgent symptom report' : 'Care team message',
      status: triage.status,
      latest_message: messageBody,
      priority: triage.priority,
      created_at: new Date().toISOString(),
    };
    await persistInsert('messageThreads', thread);

    if (triage.priority === 'Urgent') {
      await persistInsert('alerts', {
        id: crypto.randomUUID(),
        patient_id: selectedPatient.id,
        type: 'SecureMessage',
        severity: 'High',
        status: 'Routed',
        message: 'Urgent message needs clinician review.',
        raised_at: new Date().toISOString(),
      });
    }

    setMessageBody('');
    await writeAudit('message.sent', 'SecureMessageThread', thread.id);
  }

  async function addPrescription(event) {
    event.preventDefault();
    if (!selectedPatient) return;

    const record = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      clinician_id: selectedClinician?.id,
      encounter_id: patientRecords.encounters[0]?.id || null,
      status: 'Signed',
      issued_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString(),
      ...prescriptionForm,
      repeats: Number(prescriptionForm.repeats),
    };

    await persistInsert('prescriptions', record);
    setPrescriptionForm({
      medication_name: '',
      dose: '',
      route: 'Oral',
      frequency: '',
      repeats: 0,
    });
    await writeAudit('prescription.signed', 'Prescription', record.id);
  }

  async function addLabOrder(event) {
    event.preventDefault();
    if (!selectedPatient) return;

    const record = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      clinician_id: selectedClinician?.id,
      encounter_id: patientRecords.encounters[0]?.id || null,
      test_name: labForm.test_name,
      status: labForm.flag === 'Pending' ? 'Ordered' : 'Resulted',
      flag: labForm.flag,
      ordered_at: new Date().toISOString(),
    };

    await persistInsert('labOrders', record);

    if (labForm.flag === 'Critical') {
      await persistInsert('alerts', {
        id: crypto.randomUUID(),
        patient_id: selectedPatient.id,
        lab_order_id: record.id,
        type: 'LabResult',
        severity: 'Critical',
        status: 'Routed',
        message: `${labForm.test_name} returned a critical result.`,
        raised_at: new Date().toISOString(),
      });
    }

    setLabForm({ test_name: '', flag: 'Pending' });
    await writeAudit('lab.ordered', 'LabOrder', record.id);
  }

  return (
    <main>
      <header className="app-header">
        <div>
          <p className="eyebrow">Model-driven care coordination</p>
          <h1>CareFlow E-Health</h1>
          <p className="lede">
            Appointments, encounters, prescriptions, vitals, alerts, and secure
            messages generated from the MDE model package.
          </p>
        </div>
        <img
          src="https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80"
          alt="Clinician reviewing a digital care plan"
        />
      </header>

      <section className={`status-bar ${backend.mode}`}>
        <div>
          <strong>{backend.mode === 'supabase' ? 'Supabase' : 'Offline demo'}</strong>
          <span>{backend.message}</span>
        </div>
        <div className="status-actions">
          <code>{supabaseUrl.replace('https://', '')}</code>
          <button type="button" onClick={seedSupabase}>
            Seed demo data
          </button>
        </div>
      </section>

      <section className="workspace">
        <aside className="sidebar" aria-label="Patients">
          <div className="section-heading">
            <p className="eyebrow">Patient panel</p>
            <h2>Care roster</h2>
          </div>

          <div className="patient-list">
            {data.patients.map((patient) => (
              <button
                className={patient.id === selectedPatientId ? 'patient active' : 'patient'}
                key={patient.id}
                type="button"
                onClick={() => setSelectedPatientId(patient.id)}
              >
                <span>{patient.full_name}</span>
                <small>{patient.risk_level} risk</small>
              </button>
            ))}
          </div>

          <form className="stacked-form" onSubmit={addPatient}>
            <h3>Add patient</h3>
            <label>
              Full name
              <input
                required
                value={patientForm.full_name}
                onChange={(event) =>
                  setPatientForm({ ...patientForm, full_name: event.target.value })
                }
              />
            </label>
            <label>
              Date of birth
              <input
                required
                type="date"
                value={patientForm.date_of_birth}
                onChange={(event) =>
                  setPatientForm({ ...patientForm, date_of_birth: event.target.value })
                }
              />
            </label>
            <label>
              Risk level
              <select
                value={patientForm.risk_level}
                onChange={(event) =>
                  setPatientForm({ ...patientForm, risk_level: event.target.value })
                }
              >
                <option>Low</option>
                <option>Moderate</option>
                <option>High</option>
              </select>
            </label>
            <label>
              Care goal
              <textarea
                required
                rows="3"
                value={patientForm.care_goal}
                onChange={(event) =>
                  setPatientForm({ ...patientForm, care_goal: event.target.value })
                }
              />
            </label>
            <button type="submit">Create patient</button>
          </form>
        </aside>

        <section className="care-board">
          {selectedPatient ? (
            <>
              <PatientSummary patient={selectedPatient} records={patientRecords} />

              <div className="grid two">
                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Appointment state machine</p>
                    <h2>Scheduling</h2>
                  </div>
                  <form className="inline-form" onSubmit={bookAppointment}>
                    <label>
                      Clinician
                      <select
                        value={appointmentForm.clinician_id}
                        onChange={(event) =>
                          setAppointmentForm({
                            ...appointmentForm,
                            clinician_id: event.target.value,
                          })
                        }
                      >
                        <option value="">First available</option>
                        {data.clinicians.map((clinician) => (
                          <option key={clinician.id} value={clinician.id}>
                            {clinician.full_name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      Start time
                      <input
                        required
                        type="datetime-local"
                        value={appointmentForm.scheduled_start}
                        onChange={(event) =>
                          setAppointmentForm({
                            ...appointmentForm,
                            scheduled_start: event.target.value,
                          })
                        }
                      />
                    </label>
                    <label>
                      Reason
                      <input
                        required
                        value={appointmentForm.reason}
                        onChange={(event) =>
                          setAppointmentForm({
                            ...appointmentForm,
                            reason: event.target.value,
                          })
                        }
                      />
                    </label>
                    <button type="submit">Request appointment</button>
                  </form>
                  <RecordList
                    empty="No appointments yet."
                    items={patientRecords.appointments}
                    render={(appointment) => (
                      <article className="record" key={appointment.id}>
                        <div>
                          <strong>{appointment.reason}</strong>
                          <p>{formatDate(appointment.scheduled_start)}</p>
                        </div>
                        <Status value={appointment.status} />
                        <ActionRow
                          actions={appointmentActions(appointment.status)}
                          onAction={(action) => moveAppointment(appointment, action)}
                        />
                      </article>
                    )}
                  />
                </section>

                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Encounter state machine</p>
                    <h2>Consultations</h2>
                  </div>
                  <RecordList
                    empty="Start a consultation from a checked-in appointment."
                    items={patientRecords.encounters}
                    render={(encounter) => (
                      <article className="record" key={encounter.id}>
                        <div>
                          <strong>{encounter.chief_complaint || 'Clinical review'}</strong>
                          <p>{encounter.assessment || 'Assessment pending'}</p>
                        </div>
                        <Status value={encounter.status} />
                        <ActionRow
                          actions={encounterActions(encounter.status)}
                          onAction={(action) => moveEncounter(encounter, action)}
                        />
                      </article>
                    )}
                  />
                </section>
              </div>

              <div className="grid three">
                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Vitals to alerts</p>
                    <h2>Remote monitoring</h2>
                  </div>
                  <form className="stacked-form compact" onSubmit={addVital}>
                    <label>
                      Vital
                      <select
                        value={vitalForm.type}
                        onChange={(event) =>
                          setVitalForm({
                            ...vitalForm,
                            type: event.target.value,
                            unit: unitForVital(event.target.value),
                          })
                        }
                      >
                        <option>Blood pressure systolic</option>
                        <option>Glucose</option>
                        <option>Heart rate</option>
                      </select>
                    </label>
                    <label>
                      Value
                      <input
                        required
                        type="number"
                        step="0.1"
                        value={vitalForm.value}
                        onChange={(event) =>
                          setVitalForm({ ...vitalForm, value: event.target.value })
                        }
                      />
                    </label>
                    <button type="submit">Record vital</button>
                  </form>
                  <RecordList
                    empty="No vitals recorded."
                    items={patientRecords.vitals}
                    render={(vital) => (
                      <article className="record slim" key={vital.id}>
                        <strong>
                          {vital.value} {vital.unit}
                        </strong>
                        <p>{vital.type}</p>
                      </article>
                    )}
                  />
                </section>

                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Clinical alert lifecycle</p>
                    <h2>Alerts</h2>
                  </div>
                  <RecordList
                    empty="No alerts."
                    items={patientRecords.alerts}
                    render={(alert) => (
                      <article className="record" key={alert.id}>
                        <div>
                          <strong>{alert.message}</strong>
                          <p>{alert.severity} severity</p>
                        </div>
                        <Status value={alert.status} tone={alert.severity} />
                        <ActionRow
                          actions={alertActions(alert.status)}
                          onAction={(action) => moveAlert(alert, action)}
                        />
                      </article>
                    )}
                  />
                </section>

                <section className="panel image-panel">
                  <img
                    src="https://images.unsplash.com/photo-1584515933487-779824d29309?auto=format&fit=crop&w=900&q=80"
                    alt="Remote patient monitoring device"
                  />
                  <div>
                    <p className="eyebrow">MDE proof point</p>
                    <h2>Models become working rules</h2>
                    <p>
                      Abnormal vitals create alerts, messages are triaged, and workflow
                      buttons only expose valid state transitions.
                    </p>
                  </div>
                </section>
              </div>

              <div className="grid two">
                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Prescription workflow</p>
                    <h2>Medication</h2>
                  </div>
                  <form className="inline-form" onSubmit={addPrescription}>
                    <label>
                      Medication
                      <input
                        required
                        value={prescriptionForm.medication_name}
                        onChange={(event) =>
                          setPrescriptionForm({
                            ...prescriptionForm,
                            medication_name: event.target.value,
                          })
                        }
                      />
                    </label>
                    <label>
                      Dose
                      <input
                        required
                        value={prescriptionForm.dose}
                        onChange={(event) =>
                          setPrescriptionForm({
                            ...prescriptionForm,
                            dose: event.target.value,
                          })
                        }
                      />
                    </label>
                    <label>
                      Frequency
                      <input
                        required
                        value={prescriptionForm.frequency}
                        onChange={(event) =>
                          setPrescriptionForm({
                            ...prescriptionForm,
                            frequency: event.target.value,
                          })
                        }
                      />
                    </label>
                    <button type="submit">Sign prescription</button>
                  </form>
                  <RecordList
                    empty="No prescriptions."
                    items={patientRecords.prescriptions}
                    render={(prescription) => (
                      <article className="record slim" key={prescription.id}>
                        <strong>
                          {prescription.medication_name} {prescription.dose}
                        </strong>
                        <p>
                          {prescription.frequency} · {prescription.status}
                        </p>
                      </article>
                    )}
                  />
                </section>

                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Diagnostics</p>
                    <h2>Lab orders</h2>
                  </div>
                  <form className="inline-form" onSubmit={addLabOrder}>
                    <label>
                      Test name
                      <input
                        required
                        value={labForm.test_name}
                        onChange={(event) =>
                          setLabForm({ ...labForm, test_name: event.target.value })
                        }
                      />
                    </label>
                    <label>
                      Result flag
                      <select
                        value={labForm.flag}
                        onChange={(event) =>
                          setLabForm({ ...labForm, flag: event.target.value })
                        }
                      >
                        <option>Pending</option>
                        <option>Normal</option>
                        <option>Abnormal</option>
                        <option>Critical</option>
                      </select>
                    </label>
                    <button type="submit">Save lab item</button>
                  </form>
                  <RecordList
                    empty="No lab orders."
                    items={patientRecords.labOrders}
                    render={(lab) => (
                      <article className="record slim" key={lab.id}>
                        <strong>{lab.test_name}</strong>
                        <p>
                          {lab.status} · {lab.flag}
                        </p>
                      </article>
                    )}
                  />
                </section>
              </div>

              <div className="grid two">
                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Secure message state machine</p>
                    <h2>Care team inbox</h2>
                  </div>
                  <form className="stacked-form compact" onSubmit={sendMessage}>
                    <label>
                      Patient message
                      <textarea
                        required
                        rows="4"
                        value={messageBody}
                        onChange={(event) => setMessageBody(event.target.value)}
                        placeholder="Try: I have chest pain and shortness of breath"
                      />
                    </label>
                    <button type="submit">Send and triage</button>
                  </form>
                  <RecordList
                    empty="No message threads."
                    items={patientRecords.messageThreads}
                    render={(thread) => (
                      <article className="record" key={thread.id}>
                        <div>
                          <strong>{thread.subject}</strong>
                          <p>{thread.latest_message}</p>
                        </div>
                        <Status value={thread.status} tone={thread.priority} />
                      </article>
                    )}
                  />
                </section>

                <section className="panel">
                  <div className="section-heading">
                    <p className="eyebrow">Traceability</p>
                    <h2>Model to app mapping</h2>
                  </div>
                  <ul className="trace-list">
                    <li>
                      <span>Class model</span>
                      <strong>Patients, clinicians, encounters, prescriptions</strong>
                    </li>
                    <li>
                      <span>State models</span>
                      <strong>Workflow buttons expose valid transitions</strong>
                    </li>
                    <li>
                      <span>Sequence models</span>
                      <strong>Booking, triage, alerts, prescribing</strong>
                    </li>
                    <li>
                      <span>ER model</span>
                      <strong>Supabase tables in supabase/schema.sql</strong>
                    </li>
                    <li>
                      <span>Invariants</span>
                      <strong>Time windows, alert rules, signed clinical actions</strong>
                    </li>
                  </ul>
                </section>
              </div>
            </>
          ) : (
            <section className="panel">
              <h2>No patient selected</h2>
              <p>Create or seed a patient to begin.</p>
            </section>
          )}
        </section>
      </section>
    </main>
  );
}

function PatientSummary({ patient, records }) {
  return (
    <section className="summary-band">
      <div>
        <p className="eyebrow">Active patient</p>
        <h2>{patient.full_name}</h2>
        <p>
          Born {patient.date_of_birth} · {patient.preferred_language} ·{' '}
          {patient.risk_level} risk
        </p>
      </div>
      <div className="metrics">
        <Metric label="Appointments" value={records.appointments.length} />
        <Metric label="Alerts" value={records.alerts.length} />
        <Metric label="Vitals" value={records.vitals.length} />
        <Metric label="Messages" value={records.messageThreads.length} />
      </div>
    </section>
  );
}

function Metric({ label, value }) {
  return (
    <div className="metric">
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function RecordList({ items, render, empty }) {
  if (items.length === 0) {
    return <p className="empty">{empty}</p>;
  }

  return <div className="records">{items.map(render)}</div>;
}

function Status({ value, tone = '' }) {
  return <span className={`status-pill ${tone.toLowerCase()}`}>{value}</span>;
}

function ActionRow({ actions, onAction }) {
  if (actions.length === 0) return null;

  return (
    <div className="actions">
      {actions.map((action) => (
        <button key={action.id} type="button" onClick={() => onAction(action.id)}>
          {action.label}
        </button>
      ))}
    </div>
  );
}

function appointmentActions(status) {
  const map = {
    Requested: [
      { id: 'confirm', label: 'Confirm' },
      { id: 'waitlist', label: 'Waitlist' },
    ],
    Confirmed: [
      { id: 'checkIn', label: 'Check in' },
      { id: 'reschedule', label: 'Reschedule' },
      { id: 'cancel', label: 'Cancel' },
    ],
    RescheduleRequested: [{ id: 'acceptSlot', label: 'Accept slot' }],
    CheckedIn: [{ id: 'startConsultation', label: 'Start consult' }],
    InConsultation: [
      { id: 'complete', label: 'Complete' },
      { id: 'followUp', label: 'Follow-up' },
    ],
    FollowUpRequired: [{ id: 'createTask', label: 'Create task' }],
  };

  return map[status] || [];
}

function encounterActions(status) {
  const map = {
    Active: [{ id: 'reviewHistory', label: 'Review history' }],
    CollectingHistory: [{ id: 'captureVitals', label: 'Capture vitals' }],
    Examining: [{ id: 'assess', label: 'Assess' }],
    Assessing: [{ id: 'plan', label: 'Plan' }],
    Planning: [
      { id: 'ordersPending', label: 'Orders pending' },
      { id: 'ready', label: 'Ready to sign' },
    ],
    AwaitingOrders: [{ id: 'completeOrders', label: 'Complete orders' }],
    ReadyToSign: [
      { id: 'sign', label: 'Sign' },
      { id: 'revise', label: 'Revise' },
    ],
    Signed: [
      { id: 'close', label: 'Close' },
      { id: 'amend', label: 'Amend' },
    ],
    Amended: [{ id: 'sign', label: 'Sign addendum' }],
  };

  return map[status] || [];
}

function alertActions(status) {
  const map = {
    Raised: [{ id: 'route', label: 'Route' }],
    Routed: [
      { id: 'acknowledge', label: 'Acknowledge' },
      { id: 'escalate', label: 'Escalate' },
    ],
    Acknowledged: [{ id: 'review', label: 'Review' }],
    InReview: [
      { id: 'action', label: 'Action needed' },
      { id: 'falsePositive', label: 'False positive' },
    ],
    ActionRequired: [{ id: 'resolve', label: 'Resolve' }],
    Escalated: [
      { id: 'acknowledge', label: 'Acknowledge' },
      { id: 'resolve', label: 'Resolve' },
    ],
    FalsePositive: [{ id: 'close', label: 'Close' }],
    Resolved: [{ id: 'close', label: 'Close' }],
  };

  return map[status] || [];
}

function unitForVital(type) {
  if (type === 'Glucose') return 'mmol/L';
  if (type === 'Heart rate') return 'bpm';
  return 'mmHg';
}

function formatDate(value) {
  if (!value) return 'No date set';

  return new Intl.DateTimeFormat('en-AU', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
