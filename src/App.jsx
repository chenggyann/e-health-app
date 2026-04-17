import { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  Bell,
  CalendarDays,
  CheckCircle2,
  ChevronRight,
  ClipboardList,
  CreditCard,
  FileHeart,
  HeartPulse,
  MessageCircle,
  Pill,
  Plus,
  RotateCcw,
  ShieldCheck,
  Stethoscope,
  TestTube2,
  Users,
  Video,
} from 'lucide-react';
import {
  classifyVital,
  createInitialRecords,
  initialClinicians,
  initialPatients,
  transitionAppointment,
  triageMessage,
} from './lib/domain.js';
import { clearOfflineState, loadOfflineState, saveOfflineState } from './lib/offlineStore.js';
import { runQuery, supabase, supabaseUrl } from './lib/supabase.js';
import { Badge } from './components/ui/badge.jsx';
import { Button } from './components/ui/button.jsx';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from './components/ui/card.jsx';
import { Input } from './components/ui/input.jsx';
import { Label } from './components/ui/label.jsx';
import { Progress } from './components/ui/progress.jsx';
import { Separator } from './components/ui/separator.jsx';
import { Textarea } from './components/ui/textarea.jsx';

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
    labOrders: [
      ...records.labOrders,
      {
        id: crypto.randomUUID(),
        encounter_id: records.encounters[0].id,
        patient_id: patients[0].id,
        clinician_id: clinicians[0].id,
        test_name: 'HbA1c',
        status: 'Resulted',
        flag: 'Normal',
        ordered_at: new Date().toISOString(),
      },
    ],
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
    message: 'Connecting to care records...',
  });
  const [appointmentForm, setAppointmentForm] = useState({
    scheduled_start: '',
    reason: '',
    type: 'Video visit',
  });
  const [vitalForm, setVitalForm] = useState({
    type: 'Blood pressure systolic',
    value: '',
    unit: 'mmHg',
    source: 'Home device',
  });
  const [messageBody, setMessageBody] = useState('');

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
            message: 'Connected. Seed demo records to persist this patient view.',
          });
          return;
        }

        setData(next);
        setSelectedPatientId(next.patients[0]?.id || '');
        setBackend({
          mode: 'supabase',
          message: 'Connected to Supabase care records.',
        });
      } catch (error) {
        const offline = loadOfflineState(seedState);
        if (!active) return;
        setData(offline);
        setSelectedPatientId(offline.patients[0]?.id || '');
        setBackend({
          mode: 'offline',
          message: `${error.message}. Using browser storage until Supabase schema is applied.`,
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
  const patientRecords = useMemo(() => {
    const byPatient = (item) => item.patient_id === selectedPatientId;

    return {
      appointments: data.appointments.filter(byPatient),
      prescriptions: data.prescriptions.filter(byPatient),
      labOrders: data.labOrders.filter(byPatient),
      vitals: data.vitals.filter(byPatient),
      alerts: data.alerts.filter(byPatient),
      messageThreads: data.messageThreads.filter(byPatient),
    };
  }, [data, selectedPatientId]);

  const nextAppointment = patientRecords.appointments[0];
  const activeMedication = patientRecords.prescriptions[0];
  const latestVital = patientRecords.vitals[0];
  const unreadMessages = patientRecords.messageThreads.filter(
    (thread) => thread.status !== 'Closed',
  ).length;
  const careScore = Math.max(48, 86 - patientRecords.alerts.length * 8);
  const selectedClinician = data.clinicians[0];

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
      actor_name: selectedPatient?.full_name || 'Patient',
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
      setBackend({ mode: 'offline', message: 'Demo patient records reset locally.' });
      return;
    }

    try {
      await runQuery('seed patients', supabase.from('patients').upsert(seeded.patients));
      await runQuery('seed clinicians', supabase.from('clinicians').upsert(seeded.clinicians));
      await runQuery(
        'seed appointments',
        supabase.from('appointments').upsert(seeded.appointments),
      );
      await runQuery('seed encounters', supabase.from('encounters').upsert(seeded.encounters));
      await runQuery(
        'seed prescriptions',
        supabase.from('prescriptions').upsert(seeded.prescriptions),
      );
      await runQuery('seed lab orders', supabase.from('lab_orders').upsert(seeded.labOrders));
      await runQuery('seed vitals', supabase.from('vital_observations').upsert(seeded.vitals));
      await runQuery('seed alerts', supabase.from('clinical_alerts').upsert(seeded.alerts));
      await runQuery(
        'seed message threads',
        supabase.from('message_threads').upsert(seeded.messageThreads),
      );
      setBackend({ mode: 'supabase', message: 'Demo patient records seeded.' });
    } catch (error) {
      setBackend({
        mode: 'offline',
        message: `${error.message}. Demo records are available in browser storage.`,
      });
    }
  }

  async function bookAppointment(event) {
    event.preventDefault();
    if (!selectedPatient) return;

    const start = new Date(appointmentForm.scheduled_start);
    const end = new Date(start.getTime() + 30 * 60 * 1000);
    const record = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      clinician_id: selectedClinician?.id,
      scheduled_start: start.toISOString(),
      scheduled_end: end.toISOString(),
      type: appointmentForm.type,
      status: 'Requested',
      reason: appointmentForm.reason,
      created_at: new Date().toISOString(),
    };

    await persistInsert('appointments', record);
    setAppointmentForm({ scheduled_start: '', reason: '', type: 'Video visit' });
    await writeAudit('appointment.requested', 'Appointment', record.id);
  }

  async function moveAppointment(appointment, action) {
    const status = transitionAppointment(appointment.status, action);
    await persistUpdate('appointments', appointment.id, { status });
    await writeAudit(`appointment.${action}`, 'Appointment', appointment.id);
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

  async function sendMessage(event) {
    event.preventDefault();
    if (!selectedPatient || messageBody.trim() === '') return;

    const triage = triageMessage(messageBody);
    const thread = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      subject: triage.priority === 'Urgent' ? 'Urgent symptom report' : 'Message to care team',
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
        message: 'Urgent message sent to the care team.',
        raised_at: new Date().toISOString(),
      });
    }
    setMessageBody('');
    await writeAudit('message.sent', 'SecureMessageThread', thread.id);
  }

  async function requestRefill() {
    if (!selectedPatient || !activeMedication) return;

    const thread = {
      id: crypto.randomUUID(),
      patient_id: selectedPatient.id,
      subject: 'Refill request',
      status: 'AwaitingCareTeam',
      latest_message: `Please review my refill for ${activeMedication.medication_name}.`,
      priority: 'Routine',
      created_at: new Date().toISOString(),
    };
    await persistInsert('messageThreads', thread);
    await writeAudit('prescription.refill_requested', 'Prescription', activeMedication.id);
  }

  return (
    <main className="min-h-screen bg-background text-foreground">
      <AppHeader
        backend={backend}
        patient={selectedPatient}
        unreadMessages={unreadMessages}
        onSeed={seedSupabase}
      />

      <div className="mx-auto grid w-full max-w-[1500px] gap-5 px-4 py-5 lg:grid-cols-[280px_minmax(0,1fr)] lg:px-6">
        <aside className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5 text-primary" />
                Family profiles
              </CardTitle>
              <CardDescription>Switch between the people you help manage.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-2">
              {data.patients.map((patient) => (
                <button
                  className={`rounded-md border p-3 text-left transition-colors ${
                    patient.id === selectedPatientId
                      ? 'border-primary bg-emerald-50'
                      : 'border-border bg-card hover:bg-accent'
                  }`}
                  key={patient.id}
                  type="button"
                  onClick={() => setSelectedPatientId(patient.id)}
                >
                  <span className="block font-semibold">{patient.full_name}</span>
                  <span className="text-sm text-muted-foreground">{patient.risk_level} risk</span>
                </button>
              ))}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Today</CardTitle>
              <CardDescription>Patient actions that need attention.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3">
              <TaskItem checked label="Medication logged" />
              <TaskItem label="Record blood pressure" />
              <TaskItem label="Read new care message" />
              <TaskItem label="Review lab result" />
            </CardContent>
          </Card>
        </aside>

        <section className="space-y-5">
          {selectedPatient ? (
            <>
              <section className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_360px]">
                <Card className="overflow-hidden">
                  <div className="grid min-h-[260px] gap-6 p-5 sm:p-6 lg:grid-cols-[minmax(0,1fr)_280px]">
                    <div className="flex flex-col justify-between gap-8">
                      <div>
                        <Badge variant="success" className="mb-4">
                          Patient home
                        </Badge>
                        <h1 className="max-w-2xl text-3xl font-bold leading-tight tracking-normal sm:text-4xl">
                          Hi {firstName(selectedPatient.full_name)}, your care plan is on track.
                        </h1>
                        <p className="mt-3 max-w-2xl text-base text-muted-foreground">
                          Manage appointments, medications, messages, test results, and home
                          readings from one place.
                        </p>
                      </div>
                      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                        <Metric
                          icon={CalendarDays}
                          label="Next visit"
                          value={nextAppointment ? '2 days' : 'None'}
                        />
                        <Metric
                          icon={Pill}
                          label="Medications"
                          value={patientRecords.prescriptions.length}
                        />
                        <Metric
                          icon={Bell}
                          label="Open alerts"
                          value={patientRecords.alerts.length}
                        />
                        <Metric icon={MessageCircle} label="Messages" value={unreadMessages} />
                      </div>
                    </div>
                    <img
                      className="h-full min-h-[220px] w-full rounded-md object-cover"
                      src="https://images.unsplash.com/photo-1576765607924-05f89b5f7082?auto=format&fit=crop&w=900&q=80"
                      alt="Patient using a phone to manage care"
                    />
                  </div>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <HeartPulse className="h-5 w-5 text-primary" />
                      Health plan progress
                    </CardTitle>
                    <CardDescription>{selectedPatient.care_goal}</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div>
                      <div className="mb-2 flex items-center justify-between text-sm">
                        <span>Weekly completion</span>
                        <strong>{careScore}%</strong>
                      </div>
                      <Progress value={careScore} />
                    </div>
                    <Separator />
                    <div className="grid gap-3 text-sm">
                      <InfoRow label="Preferred language" value={selectedPatient.preferred_language} />
                      <InfoRow label="Risk level" value={selectedPatient.risk_level} />
                      <InfoRow
                        label="Record status"
                        value={backend.mode === 'supabase' ? 'Cloud synced' : 'Local demo'}
                      />
                    </div>
                  </CardContent>
                </Card>
              </section>

              <section className="grid gap-5 xl:grid-cols-3">
                <NextVisitCard
                  appointment={nextAppointment}
                  form={appointmentForm}
                  onChange={setAppointmentForm}
                  onSubmit={bookAppointment}
                  onAction={moveAppointment}
                />
                <MedicationCard medication={activeMedication} onRefill={requestRefill} />
                <ResultsCard results={patientRecords.labOrders} />
              </section>

              <section className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_390px]">
                <VitalsCard
                  latestVital={latestVital}
                  alerts={patientRecords.alerts}
                  form={vitalForm}
                  onChange={setVitalForm}
                  onSubmit={addVital}
                />
                <MessagesCard
                  threads={patientRecords.messageThreads}
                  messageBody={messageBody}
                  onMessageChange={setMessageBody}
                  onSubmit={sendMessage}
                />
              </section>

              <section className="grid gap-5 xl:grid-cols-3">
                <CarePlanCard />
                <BillingCard />
                <AccessCard supabaseUrl={supabaseUrl} backend={backend} />
              </section>
            </>
          ) : (
            <Card>
              <CardHeader>
                <CardTitle>No patient selected</CardTitle>
                <CardDescription>Seed demo data to start using the patient app.</CardDescription>
              </CardHeader>
              <CardContent>
                <Button type="button" onClick={seedSupabase}>
                  Seed demo patient
                </Button>
              </CardContent>
            </Card>
          )}
        </section>
      </div>
    </main>
  );
}

function AppHeader({ backend, patient, unreadMessages, onSeed }) {
  return (
    <header className="sticky top-0 z-20 border-b border-border bg-background/95 backdrop-blur">
      <div className="mx-auto flex max-w-[1500px] flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between lg:px-6">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <FileHeart className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-semibold leading-none">CareFlow</p>
            <p className="text-xs text-muted-foreground">Patient portal</p>
          </div>
        </div>
        <nav className="flex flex-wrap items-center gap-2">
          <Badge variant={backend.mode === 'supabase' ? 'success' : 'warning'}>
            {backend.mode === 'supabase' ? 'Cloud synced' : 'Offline demo'}
          </Badge>
          <Button type="button" variant="outline" size="sm">
            <Bell className="h-4 w-4" />
            {unreadMessages}
          </Button>
          <Button type="button" variant="outline" size="sm">
            <ShieldCheck className="h-4 w-4" />
            {patient ? firstName(patient.full_name) : 'Guest'}
          </Button>
          <Button type="button" size="sm" onClick={onSeed}>
            <RotateCcw className="h-4 w-4" />
            Reset demo
          </Button>
        </nav>
      </div>
      <div className="border-t border-border bg-muted px-4 py-2 text-sm text-muted-foreground lg:px-6">
        {backend.message}
      </div>
    </header>
  );
}

function Metric({ icon: Icon, label, value }) {
  return (
    <div className="rounded-md border border-border bg-background p-3">
      <Icon className="mb-3 h-5 w-5 text-primary" />
      <strong className="block text-2xl leading-none">{value}</strong>
      <span className="mt-1 block text-xs text-muted-foreground">{label}</span>
    </div>
  );
}

function NextVisitCard({ appointment, form, onChange, onSubmit, onAction }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Video className="h-5 w-5 text-primary" />
          Next appointment
        </CardTitle>
        <CardDescription>Book and manage upcoming care.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {appointment ? (
          <div className="rounded-md border border-border bg-muted p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-semibold">{appointment.reason}</p>
                <p className="mt-1 text-sm text-muted-foreground">
                  {formatDate(appointment.scheduled_start)}
                </p>
              </div>
              <StatusBadge value={appointment.status} />
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {appointmentActions(appointment.status).map((action) => (
                <Button
                  key={action.id}
                  type="button"
                  size="sm"
                  variant={action.variant || 'secondary'}
                  onClick={() => onAction(appointment, action.id)}
                >
                  {action.label}
                </Button>
              ))}
            </div>
          </div>
        ) : (
          <p className="rounded-md border border-dashed border-border p-4 text-sm text-muted-foreground">
            No appointment booked.
          </p>
        )}

        <form className="grid gap-3" onSubmit={onSubmit}>
          <Field label="Visit reason">
            <Input
              required
              value={form.reason}
              placeholder="Repeat prescription, blood pressure..."
              onChange={(event) => onChange({ ...form, reason: event.target.value })}
            />
          </Field>
          <Field label="Preferred time">
            <Input
              required
              type="datetime-local"
              value={form.scheduled_start}
              onChange={(event) =>
                onChange({ ...form, scheduled_start: event.target.value })
              }
            />
          </Field>
          <Button type="submit">
            <Plus className="h-4 w-4" />
            Request visit
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}

function MedicationCard({ medication, onRefill }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Pill className="h-5 w-5 text-primary" />
          Medications
        </CardTitle>
        <CardDescription>Track doses and request refills.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {medication ? (
          <div className="rounded-md border border-border bg-muted p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-semibold">
                  {medication.medication_name} {medication.dose}
                </p>
                <p className="mt-1 text-sm text-muted-foreground">
                  {medication.frequency} · {medication.repeats} refills left
                </p>
              </div>
              <Badge variant="success">Active</Badge>
            </div>
            <Button className="mt-4 w-full" type="button" variant="outline" onClick={onRefill}>
              Request refill
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        ) : (
          <p className="rounded-md border border-dashed border-border p-4 text-sm text-muted-foreground">
            No active medication.
          </p>
        )}
      </CardContent>
    </Card>
  );
}

function ResultsCard({ results }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <TestTube2 className="h-5 w-5 text-primary" />
          Test results
        </CardTitle>
        <CardDescription>View results and follow-up status.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {results.length === 0 ? (
          <p className="rounded-md border border-dashed border-border p-4 text-sm text-muted-foreground">
            No test results yet.
          </p>
        ) : (
          results.slice(0, 3).map((result) => (
            <div className="rounded-md border border-border p-4" key={result.id}>
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-semibold">{result.test_name}</p>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {result.status} · {formatDate(result.ordered_at)}
                  </p>
                </div>
                <StatusBadge value={result.flag} />
              </div>
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}

function VitalsCard({ latestVital, alerts, form, onChange, onSubmit }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Activity className="h-5 w-5 text-primary" />
          Home health tracking
        </CardTitle>
        <CardDescription>Log readings from home devices and receive guidance.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-5 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="space-y-4">
          <div className="rounded-md border border-border bg-muted p-4">
            <p className="text-sm text-muted-foreground">Latest reading</p>
            <strong className="mt-2 block text-3xl">
              {latestVital ? `${latestVital.value} ${latestVital.unit}` : 'No reading'}
            </strong>
            <p className="mt-1 text-sm text-muted-foreground">
              {latestVital ? latestVital.type : 'Record a vital to begin tracking.'}
            </p>
          </div>
          <div className="grid gap-2">
            {alerts.slice(0, 2).map((alert) => (
              <div className="rounded-md border border-border p-3" key={alert.id}>
                <div className="mb-1 flex items-center justify-between gap-2">
                  <Badge variant={alert.severity === 'High' ? 'destructive' : 'warning'}>
                    {alert.severity}
                  </Badge>
                  <span className="text-xs text-muted-foreground">{alert.status}</span>
                </div>
                <p className="text-sm">{alert.message}</p>
              </div>
            ))}
          </div>
        </div>
        <form className="grid gap-3" onSubmit={onSubmit}>
          <Field label="Reading type">
            <select
              className="h-10 rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              value={form.type}
              onChange={(event) =>
                onChange({
                  ...form,
                  type: event.target.value,
                  unit: unitForVital(event.target.value),
                })
              }
            >
              <option>Blood pressure systolic</option>
              <option>Glucose</option>
              <option>Heart rate</option>
            </select>
          </Field>
          <Field label={`Value (${form.unit})`}>
            <Input
              required
              type="number"
              step="0.1"
              value={form.value}
              onChange={(event) => onChange({ ...form, value: event.target.value })}
            />
          </Field>
          <Button type="submit">Save reading</Button>
        </form>
      </CardContent>
    </Card>
  );
}

function MessagesCard({ threads, messageBody, onMessageChange, onSubmit }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <MessageCircle className="h-5 w-5 text-primary" />
          Messages
        </CardTitle>
        <CardDescription>Ask a question or report symptoms.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <form className="grid gap-3" onSubmit={onSubmit}>
          <Textarea
            required
            value={messageBody}
            placeholder="Try: I have chest pain and shortness of breath"
            onChange={(event) => onMessageChange(event.target.value)}
          />
          <Button type="submit">Send to care team</Button>
        </form>
        <div className="space-y-3">
          {threads.slice(0, 3).map((thread) => (
            <div className="rounded-md border border-border p-3" key={thread.id}>
              <div className="mb-1 flex items-center justify-between gap-2">
                <p className="font-semibold">{thread.subject}</p>
                <StatusBadge value={thread.status} />
              </div>
              <p className="text-sm text-muted-foreground">{thread.latest_message}</p>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

function CarePlanCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ClipboardList className="h-5 w-5 text-primary" />
          Care plan
        </CardTitle>
        <CardDescription>Daily actions from your care team.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-3">
        <TaskItem checked label="Take morning medication" />
        <TaskItem label="Record blood pressure before dinner" />
        <TaskItem label="Read low-sodium meal guide" />
        <TaskItem label="Complete weekly check-in" />
      </CardContent>
    </Card>
  );
}

function BillingCard() {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <CreditCard className="h-5 w-5 text-primary" />
          Billing
        </CardTitle>
        <CardDescription>Estimate costs and view balances.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="rounded-md border border-border bg-muted p-4">
          <p className="text-sm text-muted-foreground">Current balance</p>
          <strong className="mt-2 block text-3xl">$0.00</strong>
          <p className="mt-1 text-sm text-muted-foreground">No payment is due.</p>
        </div>
        <Button type="button" variant="outline" className="w-full">
          View estimates
        </Button>
      </CardContent>
    </Card>
  );
}

function AccessCard({ supabaseUrl, backend }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Stethoscope className="h-5 w-5 text-primary" />
          Care access
        </CardTitle>
        <CardDescription>Quick paths for routine and urgent care.</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <QuickLink icon={Video} title="Start virtual care" text="Join a video visit or request 24/7 advice." />
        <QuickLink icon={TestTube2} title="Nearby services" text="Find labs, pharmacies, and urgent care." />
        <QuickLink icon={ShieldCheck} title="Record sharing" text="Share your summary with another provider." />
        <p className="pt-2 text-xs text-muted-foreground">
          {backend.mode === 'supabase' ? 'Connected to ' : 'Configured for '}
          {supabaseUrl.replace('https://', '')}
        </p>
      </CardContent>
    </Card>
  );
}

function QuickLink({ icon: Icon, title, text }) {
  return (
    <div className="flex gap-3 rounded-md border border-border p-3">
      <Icon className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
      <div>
        <p className="font-semibold">{title}</p>
        <p className="text-sm text-muted-foreground">{text}</p>
      </div>
    </div>
  );
}

function Field({ label, children }) {
  return (
    <div className="grid gap-2">
      <Label>{label}</Label>
      {children}
    </div>
  );
}

function TaskItem({ label, checked = false }) {
  return (
    <div className="flex items-center gap-3 rounded-md border border-border p-3">
      <CheckCircle2
        className={`h-5 w-5 ${checked ? 'text-primary' : 'text-muted-foreground'}`}
      />
      <span className={checked ? 'text-sm line-through decoration-primary/60' : 'text-sm'}>
        {label}
      </span>
    </div>
  );
}

function InfoRow({ label, value }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-muted-foreground">{label}</span>
      <strong className="text-right">{value}</strong>
    </div>
  );
}

function StatusBadge({ value }) {
  const normalized = String(value || '').toLowerCase();
  const variant =
    normalized.includes('critical') || normalized.includes('high')
      ? 'destructive'
      : normalized.includes('pending') || normalized.includes('requested')
        ? 'warning'
        : normalized.includes('normal') || normalized.includes('confirmed')
          ? 'success'
          : 'secondary';

  return <Badge variant={variant}>{value}</Badge>;
}

function appointmentActions(status) {
  const map = {
    Requested: [{ id: 'confirm', label: 'Confirm request' }],
    Confirmed: [
      { id: 'checkIn', label: 'Check in' },
      { id: 'reschedule', label: 'Reschedule', variant: 'outline' },
      { id: 'cancel', label: 'Cancel', variant: 'outline' },
    ],
    RescheduleRequested: [{ id: 'acceptSlot', label: 'Accept slot' }],
    CheckedIn: [{ id: 'startConsultation', label: 'Join video visit' }],
  };

  return map[status] || [];
}

function unitForVital(type) {
  if (type === 'Glucose') return 'mmol/L';
  if (type === 'Heart rate') return 'bpm';
  return 'mmHg';
}

function firstName(name) {
  return name?.split(' ')[0] || 'there';
}

function formatDate(value) {
  if (!value) return 'No date set';

  return new Intl.DateTimeFormat('en-AU', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
