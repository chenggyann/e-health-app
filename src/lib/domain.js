export const initialPatients = [
  {
    id: crypto.randomUUID(),
    full_name: 'Maya Chen',
    date_of_birth: '1988-09-14',
    preferred_language: 'English',
    risk_level: 'Moderate',
    care_goal: 'Reduce blood pressure and improve medication adherence',
  },
  {
    id: crypto.randomUUID(),
    full_name: 'Noah Patel',
    date_of_birth: '1975-02-03',
    preferred_language: 'English',
    risk_level: 'High',
    care_goal: 'Monitor glucose and follow up on abnormal lab results',
  },
];

export const initialClinicians = [
  {
    id: crypto.randomUUID(),
    full_name: 'Dr. Amelia Hart',
    specialty: 'General Practice',
    accepting_appointments: true,
  },
  {
    id: crypto.randomUUID(),
    full_name: 'Dr. Samuel Green',
    specialty: 'Cardiology',
    accepting_appointments: true,
  },
];

export function createInitialRecords(patientId, clinicianId) {
  const appointmentId = crypto.randomUUID();
  const encounterId = crypto.randomUUID();
  const prescriptionId = crypto.randomUUID();
  const labOrderId = crypto.randomUUID();

  return {
    appointments: [
      {
        id: appointmentId,
        patient_id: patientId,
        clinician_id: clinicianId,
        scheduled_start: nextIsoDate(2, 9),
        scheduled_end: nextIsoDate(2, 9, 30),
        type: 'Telehealth',
        status: 'Confirmed',
        reason: 'Blood pressure review',
      },
    ],
    encounters: [
      {
        id: encounterId,
        appointment_id: appointmentId,
        patient_id: patientId,
        clinician_id: clinicianId,
        status: 'Planning',
        chief_complaint: 'Follow-up for hypertension',
        assessment: 'Home readings remain above target range.',
        plan: 'Review medication adherence and monitor daily vitals.',
      },
    ],
    prescriptions: [
      {
        id: prescriptionId,
        encounter_id: encounterId,
        patient_id: patientId,
        clinician_id: clinicianId,
        status: 'ActiveMedication',
        medication_name: 'Amlodipine',
        dose: '5 mg',
        route: 'Oral',
        frequency: 'Once daily',
        repeats: 2,
      },
    ],
    labOrders: [
      {
        id: labOrderId,
        encounter_id: encounterId,
        patient_id: patientId,
        clinician_id: clinicianId,
        test_name: 'Lipid panel',
        status: 'Ordered',
        flag: 'Pending',
      },
    ],
    vitals: [
      {
        id: crypto.randomUUID(),
        patient_id: patientId,
        type: 'Blood pressure systolic',
        value: 152,
        unit: 'mmHg',
        source: 'Home device',
        observed_at: new Date().toISOString(),
      },
    ],
    alerts: [
      {
        id: crypto.randomUUID(),
        patient_id: patientId,
        type: 'VitalObservation',
        severity: 'High',
        status: 'Acknowledged',
        message: 'Systolic blood pressure is above target range.',
      },
    ],
    messageThreads: [
      {
        id: crypto.randomUUID(),
        patient_id: patientId,
        subject: 'Medication question',
        status: 'AwaitingCareTeam',
        latest_message: 'I missed a dose yesterday. Should I double up today?',
        priority: 'Routine',
      },
    ],
  };
}

export function transitionAppointment(status, action) {
  const transitions = {
    Requested: { confirm: 'Confirmed', reject: 'Rejected', waitlist: 'Waitlisted' },
    Waitlisted: { releaseSlot: 'Requested' },
    Confirmed: {
      checkIn: 'CheckedIn',
      cancel: 'Cancelled',
      noShow: 'NoShow',
      reschedule: 'RescheduleRequested',
    },
    RescheduleRequested: { acceptSlot: 'Confirmed', cancel: 'Cancelled' },
    CheckedIn: { startConsultation: 'InConsultation', noShow: 'NoShow' },
    InConsultation: { complete: 'Completed', followUp: 'FollowUpRequired' },
    FollowUpRequired: { createTask: 'Completed' },
  };

  return transitions[status]?.[action] || status;
}

export function transitionEncounter(status, action) {
  const transitions = {
    NotStarted: { open: 'Active' },
    Active: { reviewHistory: 'CollectingHistory', cancel: 'Cancelled' },
    CollectingHistory: { captureVitals: 'Examining' },
    Examining: { assess: 'Assessing' },
    Assessing: { plan: 'Planning' },
    Planning: { ordersPending: 'AwaitingOrders', ready: 'ReadyToSign' },
    AwaitingOrders: { completeOrders: 'Planning' },
    ReadyToSign: { sign: 'Signed', revise: 'Active' },
    Signed: { amend: 'Amended', close: 'Closed' },
    Amended: { sign: 'Signed' },
  };

  return transitions[status]?.[action] || status;
}

export function transitionAlert(status, action) {
  const transitions = {
    Raised: { route: 'Routed' },
    Routed: { acknowledge: 'Acknowledged', escalate: 'Escalated' },
    Acknowledged: { review: 'InReview' },
    InReview: { action: 'ActionRequired', falsePositive: 'FalsePositive' },
    ActionRequired: { resolve: 'Resolved' },
    Escalated: { acknowledge: 'Acknowledged', resolve: 'Resolved' },
    FalsePositive: { close: 'Closed' },
    Resolved: { close: 'Closed' },
  };

  return transitions[status]?.[action] || status;
}

export function classifyVital(type, value) {
  if (type === 'Blood pressure systolic' && Number(value) >= 140) {
    return {
      severity: Number(value) >= 180 ? 'Critical' : 'High',
      message: 'Systolic blood pressure is above target range.',
    };
  }

  if (type === 'Glucose' && (Number(value) >= 11 || Number(value) <= 3.9)) {
    return {
      severity: Number(value) >= 15 ? 'Critical' : 'Medium',
      message: 'Glucose reading is outside the expected range.',
    };
  }

  if (type === 'Heart rate' && (Number(value) >= 120 || Number(value) <= 45)) {
    return {
      severity: 'High',
      message: 'Heart rate requires clinical review.',
    };
  }

  return null;
}

export function triageMessage(body) {
  const urgentTerms = ['chest pain', 'shortness of breath', 'faint', 'severe', 'emergency'];
  const normalized = body.toLowerCase();
  const urgent = urgentTerms.some((term) => normalized.includes(term));

  return {
    priority: urgent ? 'Urgent' : 'Routine',
    status: urgent ? 'Escalated' : 'AwaitingCareTeam',
  };
}

function nextIsoDate(dayOffset, hour, minute = 0) {
  const date = new Date();
  date.setDate(date.getDate() + dayOffset);
  date.setHours(hour, minute, 0, 0);
  return date.toISOString();
}
