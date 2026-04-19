import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ktbpsliejglodmonmzhs.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0YnBzbGllamdsb2Rtb25temhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDA2MTYsImV4cCI6MjA5MjAxNjYxNn0.WMwO-DFKZeMDb8MTy7qjBs6zdX_bP6vdC0ffF5V0KLg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const CareFlowApp());
}

class CareFlowApp extends StatelessWidget {
  const CareFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff087761),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'CareFlow E-Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xfff6fbf8),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xffd5e4dc)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const PatientHomePage(),
    );
  }
}

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  final _store = CareStore();
  final _appointmentReason = TextEditingController();
  final _messageBody = TextEditingController();
  final _vitalValue = TextEditingController();

  AppData _data = AppData.empty();
  String? _selectedPatientId;
  String _backendMode = 'loading';
  String _backendMessage = 'Connecting to care records...';
  String _appointmentDate = '';
  String _vitalType = 'Blood pressure systolic';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appointmentReason.dispose();
    _messageBody.dispose();
    _vitalValue.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _store.load();
    if (!mounted) return;

    setState(() {
      _data = result.data;
      _backendMode = result.mode;
      _backendMessage = result.message;
      _selectedPatientId = _data.patients.firstOrNull?['id'] as String?;
    });
  }

  Map<String, dynamic>? get patient =>
      _data.patients.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == _selectedPatientId,
        orElse: () => null,
      );

  List<Map<String, dynamic>> _forPatient(List<Map<String, dynamic>> records) {
    return records
        .where((item) => item['patient_id'] == _selectedPatientId)
        .toList();
  }

  Future<void> _saveOfflineIfNeeded() async {
    if (_backendMode == 'offline') {
      await _store.saveOffline(_data);
    }
  }

  Future<void> _insert(String key, Map<String, dynamic> record) async {
    setState(() => _data = _data.inserted(key, record));

    if (_backendMode == 'supabase') {
      try {
        await _store.insert(key, record);
      } catch (error) {
        setState(() {
          _backendMode = 'offline';
          _backendMessage = '$error. Switched to browser storage.';
        });
      }
    }

    await _saveOfflineIfNeeded();
  }

  Future<void> _update(
    String key,
    String id,
    Map<String, dynamic> patch,
  ) async {
    setState(() => _data = _data.updated(key, id, patch));

    if (_backendMode == 'supabase') {
      try {
        await _store.update(key, id, patch);
      } catch (error) {
        setState(() {
          _backendMode = 'offline';
          _backendMessage = '$error. Switched to browser storage.';
        });
      }
    }

    await _saveOfflineIfNeeded();
  }

  Future<void> _seedDemo() async {
    final seeded = AppData.seeded();
    setState(() {
      _data = seeded;
      _selectedPatientId = seeded.patients.first['id'] as String;
    });

    if (_backendMode == 'supabase') {
      try {
        await _store.seedSupabase(seeded);
        setState(() => _backendMessage = 'Demo patient records seeded.');
      } catch (error) {
        await _store.saveOffline(seeded);
        setState(() {
          _backendMode = 'offline';
          _backendMessage =
              '$error. Demo records are available in browser storage.';
        });
      }
    } else {
      await _store.saveOffline(seeded);
      setState(() => _backendMessage = 'Demo patient records reset locally.');
    }
  }

  Future<void> _bookAppointment() async {
    final currentPatient = patient;
    if (currentPatient == null || _appointmentReason.text.trim().isEmpty) {
      return;
    }

    final selectedDate = _appointmentDate.isEmpty
        ? DateTime.now().add(const Duration(days: 2))
        : DateTime.parse(_appointmentDate);
    final record = {
      'id': newId(),
      'patient_id': currentPatient['id'],
      'clinician_id': _data.clinicians.firstOrNull?['id'],
      'scheduled_start': selectedDate.toIso8601String(),
      'scheduled_end': selectedDate
          .add(const Duration(minutes: 30))
          .toIso8601String(),
      'type': 'Video visit',
      'status': 'Requested',
      'reason': _appointmentReason.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    await _insert('appointments', record);
    _appointmentReason.clear();
    setState(() => _appointmentDate = '');
  }

  Future<void> _moveAppointment(
    Map<String, dynamic> appointment,
    String action,
  ) async {
    final next = transitionAppointment(
      appointment['status'] as String? ?? '',
      action,
    );
    await _update('appointments', appointment['id'] as String, {
      'status': next,
    });
  }

  Future<void> _recordVital() async {
    final currentPatient = patient;
    if (currentPatient == null || _vitalValue.text.trim().isEmpty) return;

    final value = double.tryParse(_vitalValue.text.trim());
    if (value == null) return;

    final vital = {
      'id': newId(),
      'patient_id': currentPatient['id'],
      'type': _vitalType,
      'value': value,
      'unit': unitForVital(_vitalType),
      'source': 'Home device',
      'observed_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
    await _insert('vitals', vital);

    final alert = classifyVital(_vitalType, value);
    if (alert != null) {
      await _insert('alerts', {
        'id': newId(),
        'patient_id': currentPatient['id'],
        'vital_observation_id': vital['id'],
        'type': 'VitalObservation',
        'severity': alert.severity,
        'status': 'Raised',
        'message': alert.message,
        'raised_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    _vitalValue.clear();
  }

  Future<void> _sendMessage() async {
    final currentPatient = patient;
    final text = _messageBody.text.trim();
    if (currentPatient == null || text.isEmpty) return;

    final triage = triageMessage(text);
    await _insert('messages', {
      'id': newId(),
      'patient_id': currentPatient['id'],
      'subject': triage.urgent
          ? 'Urgent symptom report'
          : 'Message to care team',
      'status': triage.urgent ? 'Escalated' : 'AwaitingCareTeam',
      'latest_message': text,
      'priority': triage.urgent ? 'Urgent' : 'Routine',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (triage.urgent) {
      await _insert('alerts', {
        'id': newId(),
        'patient_id': currentPatient['id'],
        'type': 'SecureMessage',
        'severity': 'High',
        'status': 'Routed',
        'message': 'Urgent message sent to the care team.',
        'raised_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    _messageBody.clear();
  }

  Future<void> _requestRefill(Map<String, dynamic> medication) async {
    final currentPatient = patient;
    if (currentPatient == null) return;

    await _insert('messages', {
      'id': newId(),
      'patient_id': currentPatient['id'],
      'subject': 'Refill request',
      'status': 'AwaitingCareTeam',
      'latest_message':
          'Please review my refill for ${medication['medication_name']}.',
      'priority': 'Routine',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPatient = patient;
    final appointments = _forPatient(_data.appointments);
    final meds = _forPatient(_data.prescriptions);
    final labs = _forPatient(_data.labOrders);
    final vitals = _forPatient(_data.vitals);
    final alerts = _forPatient(_data.alerts);
    final messages = _forPatient(_data.messages);
    final careScore = max(48, 86 - alerts.length * 8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareFlow'),
        actions: [
          Chip(
            avatar: Icon(
              _backendMode == 'supabase' ? Icons.cloud_done : Icons.storage,
              size: 18,
            ),
            label: Text(
              _backendMode == 'supabase' ? 'Cloud synced' : 'Offline demo',
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Reset demo records',
            onPressed: _seedDemo,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: currentPatient == null
            ? Center(
                child: FilledButton.icon(
                  onPressed: _seedDemo,
                  icon: const Icon(Icons.add),
                  label: const Text('Seed demo patient'),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 280,
                                    child: _SidePanel(
                                      patients: _data.patients,
                                      selectedId: _selectedPatientId,
                                      onSelect: (id) => setState(
                                        () => _selectedPatientId = id,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _MainPanel(
                                      backendMessage: _backendMessage,
                                      patient: currentPatient,
                                      appointments: appointments,
                                      medications: meds,
                                      labs: labs,
                                      vitals: vitals,
                                      alerts: alerts,
                                      messages: messages,
                                      careScore: careScore,
                                      appointmentReason: _appointmentReason,
                                      appointmentDate: _appointmentDate,
                                      onAppointmentDateChanged: (value) =>
                                          setState(
                                            () => _appointmentDate = value,
                                          ),
                                      onBookAppointment: _bookAppointment,
                                      onAppointmentAction: _moveAppointment,
                                      vitalType: _vitalType,
                                      vitalValue: _vitalValue,
                                      onVitalTypeChanged: (value) =>
                                          setState(() => _vitalType = value),
                                      onRecordVital: _recordVital,
                                      messageBody: _messageBody,
                                      onSendMessage: _sendMessage,
                                      onRefill: _requestRefill,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _SidePanel(
                                    patients: _data.patients,
                                    selectedId: _selectedPatientId,
                                    onSelect: (id) =>
                                        setState(() => _selectedPatientId = id),
                                  ),
                                  const SizedBox(height: 16),
                                  _MainPanel(
                                    backendMessage: _backendMessage,
                                    patient: currentPatient,
                                    appointments: appointments,
                                    medications: meds,
                                    labs: labs,
                                    vitals: vitals,
                                    alerts: alerts,
                                    messages: messages,
                                    careScore: careScore,
                                    appointmentReason: _appointmentReason,
                                    appointmentDate: _appointmentDate,
                                    onAppointmentDateChanged: (value) =>
                                        setState(
                                          () => _appointmentDate = value,
                                        ),
                                    onBookAppointment: _bookAppointment,
                                    onAppointmentAction: _moveAppointment,
                                    vitalType: _vitalType,
                                    vitalValue: _vitalValue,
                                    onVitalTypeChanged: (value) =>
                                        setState(() => _vitalType = value),
                                    onRecordVital: _recordVital,
                                    messageBody: _messageBody,
                                    onSendMessage: _sendMessage,
                                    onRefill: _requestRefill,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.patients,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> patients;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          title: 'Family profiles',
          subtitle: 'Switch between people you help manage.',
          icon: Icons.group,
          child: Column(
            children: [
              for (final patient in patients) ...[
                ListTile(
                  selected: patient['id'] == selectedId,
                  selectedTileColor: const Color(0xffe7f6ef),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(patient['full_name'] as String),
                  subtitle: Text('${patient['risk_level']} risk'),
                  onTap: () => onSelect(patient['id'] as String),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'Today',
          subtitle: 'Care actions that need attention.',
          icon: Icons.today,
          child: const Column(
            children: [
              TaskTile(label: 'Medication logged', done: true),
              TaskTile(label: 'Record blood pressure'),
              TaskTile(label: 'Read new care message'),
              TaskTile(label: 'Review lab result'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MainPanel extends StatelessWidget {
  const _MainPanel({
    required this.backendMessage,
    required this.patient,
    required this.appointments,
    required this.medications,
    required this.labs,
    required this.vitals,
    required this.alerts,
    required this.messages,
    required this.careScore,
    required this.appointmentReason,
    required this.appointmentDate,
    required this.onAppointmentDateChanged,
    required this.onBookAppointment,
    required this.onAppointmentAction,
    required this.vitalType,
    required this.vitalValue,
    required this.onVitalTypeChanged,
    required this.onRecordVital,
    required this.messageBody,
    required this.onSendMessage,
    required this.onRefill,
  });

  final String backendMessage;
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> medications;
  final List<Map<String, dynamic>> labs;
  final List<Map<String, dynamic>> vitals;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> messages;
  final int careScore;
  final TextEditingController appointmentReason;
  final String appointmentDate;
  final ValueChanged<String> onAppointmentDateChanged;
  final VoidCallback onBookAppointment;
  final Future<void> Function(Map<String, dynamic>, String) onAppointmentAction;
  final String vitalType;
  final TextEditingController vitalValue;
  final ValueChanged<String> onVitalTypeChanged;
  final VoidCallback onRecordVital;
  final TextEditingController messageBody;
  final VoidCallback onSendMessage;
  final Future<void> Function(Map<String, dynamic>) onRefill;

  @override
  Widget build(BuildContext context) {
    final nextAppointment = appointments.firstOrNull;
    final latestVital = vitals.firstOrNull;
    final medication = medications.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(
          patient: patient,
          careScore: careScore,
          backendMessage: backendMessage,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatCard(
              icon: Icons.video_call,
              label: 'Next visit',
              value: nextAppointment == null ? 'None' : '2 days',
            ),
            StatCard(
              icon: Icons.medication,
              label: 'Medications',
              value: '${medications.length}',
            ),
            StatCard(
              icon: Icons.notifications,
              label: 'Open alerts',
              value: '${alerts.length}',
            ),
            StatCard(
              icon: Icons.mark_chat_unread,
              label: 'Messages',
              value: '${messages.length}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            AppointmentCard(
              appointment: nextAppointment,
              reasonController: appointmentReason,
              appointmentDate: appointmentDate,
              onDateChanged: onAppointmentDateChanged,
              onSubmit: onBookAppointment,
              onAction: onAppointmentAction,
            ),
            MedicationCard(medication: medication, onRefill: onRefill),
            ResultsCard(labs: labs),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minTileWidth: 410,
          children: [
            VitalsCard(
              latestVital: latestVital,
              alerts: alerts,
              vitalType: vitalType,
              valueController: vitalValue,
              onVitalTypeChanged: onVitalTypeChanged,
              onSubmit: onRecordVital,
            ),
            MessagesCard(
              messages: messages,
              controller: messageBody,
              onSubmit: onSendMessage,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const ResponsiveGrid(
          children: [CarePlanCard(), BillingCard(), AccessCard()],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.patient,
    required this.careScore,
    required this.backendMessage,
  });

  final Map<String, dynamic> patient;
  final int careScore;
  final String backendMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final image = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://images.unsplash.com/photo-1576765607924-05f89b5f7082?auto=format&fit=crop&w=900&q=80',
                height: 230,
                width: 300,
                fit: BoxFit.cover,
              ),
            );

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  avatar: const Icon(Icons.home, size: 18),
                  label: const Text('Patient home'),
                  backgroundColor: const Color(0xffdff5e8),
                  side: BorderSide.none,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hi ${firstName(patient['full_name'] as String)}, your care plan is on track.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage appointments, medications, messages, test results, and home readings from one place.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(value: careScore / 100),
                const SizedBox(height: 8),
                Text('Weekly care plan progress: $careScore%'),
                const SizedBox(height: 8),
                Text(
                  backendMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [content, const SizedBox(height: 16), image],
              );
            }

            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 24),
                image,
              ],
            );
          },
        ),
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 320,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = max(1, constraints.maxWidth ~/ minTileWidth);
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.reasonController,
    required this.appointmentDate,
    required this.onDateChanged,
    required this.onSubmit,
    required this.onAction,
  });

  final Map<String, dynamic>? appointment;
  final TextEditingController reasonController;
  final String appointmentDate;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onSubmit;
  final Future<void> Function(Map<String, dynamic>, String) onAction;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Next appointment',
      subtitle: 'Book and manage upcoming care.',
      icon: Icons.video_call,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (appointment == null)
            const EmptyState(text: 'No appointment booked.')
          else
            RecordTile(
              title: appointment!['reason'] as String,
              subtitle: formatDate(appointment!['scheduled_start'] as String?),
              badge: appointment!['status'] as String,
              actions: [
                for (final action in appointmentActions(
                  appointment!['status'] as String? ?? '',
                ))
                  TextButton(
                    onPressed: () => onAction(appointment!, action.$1),
                    child: Text(action.$2),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: 'Visit reason'),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Preferred date',
              helperText: 'YYYY-MM-DD, defaults to two days from now',
            ),
            onChanged: onDateChanged,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add),
            label: const Text('Request visit'),
          ),
        ],
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    required this.onRefill,
  });

  final Map<String, dynamic>? medication;
  final Future<void> Function(Map<String, dynamic>) onRefill;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Medications',
      subtitle: 'Track doses and request refills.',
      icon: Icons.medication,
      child: medication == null
          ? const EmptyState(text: 'No active medication.')
          : RecordTile(
              title: '${medication!['medication_name']} ${medication!['dose']}',
              subtitle:
                  '${medication!['frequency']} · ${medication!['repeats']} refills left',
              badge: 'Active',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => onRefill(medication!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Request refill'),
                ),
              ],
            ),
    );
  }
}

class ResultsCard extends StatelessWidget {
  const ResultsCard({super.key, required this.labs});

  final List<Map<String, dynamic>> labs;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Test results',
      subtitle: 'View results and follow-up status.',
      icon: Icons.science,
      child: labs.isEmpty
          ? const EmptyState(text: 'No test results yet.')
          : Column(
              children: [
                for (final lab in labs.take(3)) ...[
                  RecordTile(
                    title: lab['test_name'] as String,
                    subtitle:
                        '${lab['status']} · ${formatDate(lab['ordered_at'] as String?)}',
                    badge: lab['flag'] as String,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class VitalsCard extends StatelessWidget {
  const VitalsCard({
    super.key,
    required this.latestVital,
    required this.alerts,
    required this.vitalType,
    required this.valueController,
    required this.onVitalTypeChanged,
    required this.onSubmit,
  });

  final Map<String, dynamic>? latestVital;
  final List<Map<String, dynamic>> alerts;
  final String vitalType;
  final TextEditingController valueController;
  final ValueChanged<String> onVitalTypeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Home health tracking',
      subtitle: 'Log readings from home devices and receive guidance.',
      icon: Icons.monitor_heart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xffeef7f1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest reading'),
                const SizedBox(height: 6),
                Text(
                  latestVital == null
                      ? 'No reading'
                      : '${latestVital!['value']} ${latestVital!['unit']}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  latestVital == null
                      ? 'Record a vital to begin.'
                      : latestVital!['type'] as String,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: vitalType,
            decoration: const InputDecoration(labelText: 'Reading type'),
            items: const [
              DropdownMenuItem(
                value: 'Blood pressure systolic',
                child: Text('Blood pressure systolic'),
              ),
              DropdownMenuItem(value: 'Glucose', child: Text('Glucose')),
              DropdownMenuItem(value: 'Heart rate', child: Text('Heart rate')),
            ],
            onChanged: (value) {
              if (value != null) onVitalTypeChanged(value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Value (${unitForVital(vitalType)})',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onSubmit, child: const Text('Save reading')),
          const SizedBox(height: 12),
          for (final alert in alerts.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordTile(
                title: alert['message'] as String,
                subtitle: alert['status'] as String? ?? 'Raised',
                badge: alert['severity'] as String? ?? 'Alert',
              ),
            ),
        ],
      ),
    );
  }
}

class MessagesCard extends StatelessWidget {
  const MessagesCard({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> messages;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Messages',
      subtitle: 'Ask a question or report symptoms.',
      icon: Icons.chat_bubble_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Patient message',
              hintText: 'Try: I have chest pain and shortness of breath',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onSubmit,
            child: const Text('Send to care team'),
          ),
          const SizedBox(height: 14),
          for (final message in messages.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordTile(
                title: message['subject'] as String,
                subtitle: message['latest_message'] as String,
                badge: message['status'] as String,
              ),
            ),
        ],
      ),
    );
  }
}

class CarePlanCard extends StatelessWidget {
  const CarePlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoCard(
      title: 'Care plan',
      subtitle: 'Daily actions from your care team.',
      icon: Icons.checklist,
      child: Column(
        children: [
          TaskTile(label: 'Take morning medication', done: true),
          TaskTile(label: 'Record blood pressure before dinner'),
          TaskTile(label: 'Read low-sodium meal guide'),
          TaskTile(label: 'Complete weekly check-in'),
        ],
      ),
    );
  }
}

class BillingCard extends StatelessWidget {
  const BillingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      title: 'Billing',
      subtitle: 'Estimate costs and view balances.',
      icon: Icons.credit_card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Current balance',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$0.00',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('No payment is due.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () {}, child: const Text('View estimates')),
        ],
      ),
    );
  }
}

class AccessCard extends StatelessWidget {
  const AccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoCard(
      title: 'Care access',
      subtitle: 'Quick paths for routine and urgent care.',
      icon: Icons.local_hospital,
      child: Column(
        children: [
          QuickLink(
            icon: Icons.video_call,
            title: 'Start virtual care',
            text: 'Join a video visit or request advice.',
          ),
          QuickLink(
            icon: Icons.place,
            title: 'Nearby services',
            text: 'Find labs, pharmacies, and urgent care.',
          ),
          QuickLink(
            icon: Icons.verified_user,
            title: 'Record sharing',
            text: 'Share your summary with another provider.',
          ),
        ],
      ),
    );
  }
}

class QuickLink extends StatelessWidget {
  const QuickLink({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final String badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd5e4dc)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip(label: badge),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('high') || normalized.contains('critical')
        ? const Color(0xffba1a1a)
        : normalized.contains('pending') || normalized.contains('requested')
        ? const Color(0xffffdf8a)
        : const Color(0xffdff5e8);
    final textColor =
        normalized.contains('high') || normalized.contains('critical')
        ? Colors.white
        : const Color(0xff143f34);

    return Chip(
      label: Text(label),
      backgroundColor: color,
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd5e4dc)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.label, this.done = false});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Theme.of(context).colorScheme.primary : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                decoration: done
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadResult {
  const LoadResult({
    required this.data,
    required this.mode,
    required this.message,
  });

  final AppData data;
  final String mode;
  final String message;
}

class CareStore {
  static const _offlineKey = 'careflow.flutter.offline.v1';

  final _client = Supabase.instance.client;

  Future<LoadResult> load() async {
    try {
      final loaded = AppData(
        patients: await _select('patients'),
        clinicians: await _select('clinicians'),
        appointments: await _select('appointments'),
        encounters: await _select('encounters'),
        prescriptions: await _select('prescriptions'),
        labOrders: await _select('lab_orders'),
        vitals: await _select('vital_observations'),
        alerts: await _select('clinical_alerts'),
        messages: await _select('message_threads'),
        auditEvents: await _select('audit_events'),
      );

      if (loaded.patients.isEmpty || loaded.clinicians.isEmpty) {
        return LoadResult(
          data: AppData.seeded(),
          mode: 'supabase',
          message: 'Connected. Seed demo records to persist this patient view.',
        );
      }

      return LoadResult(
        data: loaded,
        mode: 'supabase',
        message: 'Connected to Supabase care records.',
      );
    } catch (error) {
      return LoadResult(
        data: await loadOffline(),
        mode: 'offline',
        message:
            '$error. Using browser storage until Supabase schema is applied.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _select(String table) async {
    final rows = await _client
        .from(table)
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> insert(String key, Map<String, dynamic> record) async {
    await _client.from(tableFor(key)).insert(record);
  }

  Future<void> update(String key, String id, Map<String, dynamic> patch) async {
    await _client.from(tableFor(key)).update(patch).eq('id', id);
  }

  Future<void> seedSupabase(AppData data) async {
    await _client.from('patients').upsert(data.patients);
    await _client.from('clinicians').upsert(data.clinicians);
    await _client.from('appointments').upsert(data.appointments);
    await _client.from('encounters').upsert(data.encounters);
    await _client.from('prescriptions').upsert(data.prescriptions);
    await _client.from('lab_orders').upsert(data.labOrders);
    await _client.from('vital_observations').upsert(data.vitals);
    await _client.from('clinical_alerts').upsert(data.alerts);
    await _client.from('message_threads').upsert(data.messages);
  }

  Future<AppData> loadOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineKey);
    if (raw == null) {
      final seeded = AppData.seeded();
      await saveOffline(seeded);
      return seeded;
    }
    return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveOffline(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineKey, jsonEncode(data.toJson()));
  }
}

class AppData {
  const AppData({
    required this.patients,
    required this.clinicians,
    required this.appointments,
    required this.encounters,
    required this.prescriptions,
    required this.labOrders,
    required this.vitals,
    required this.alerts,
    required this.messages,
    required this.auditEvents,
  });

  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> clinicians;
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> encounters;
  final List<Map<String, dynamic>> prescriptions;
  final List<Map<String, dynamic>> labOrders;
  final List<Map<String, dynamic>> vitals;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> auditEvents;

  factory AppData.empty() {
    return const AppData(
      patients: [],
      clinicians: [],
      appointments: [],
      encounters: [],
      prescriptions: [],
      labOrders: [],
      vitals: [],
      alerts: [],
      messages: [],
      auditEvents: [],
    );
  }

  factory AppData.seeded() {
    final patientId = newId();
    final secondPatientId = newId();
    final clinicianId = newId();
    final appointmentId = newId();
    final encounterId = newId();

    return AppData(
      patients: [
        {
          'id': patientId,
          'full_name': 'Maya Chen',
          'date_of_birth': '1988-09-14',
          'preferred_language': 'English',
          'risk_level': 'Moderate',
          'care_goal': 'Reduce blood pressure and improve medication adherence',
          'created_at': nowIso(),
        },
        {
          'id': secondPatientId,
          'full_name': 'Noah Patel',
          'date_of_birth': '1975-02-03',
          'preferred_language': 'English',
          'risk_level': 'High',
          'care_goal': 'Monitor glucose and follow up on abnormal lab results',
          'created_at': nowIso(),
        },
      ],
      clinicians: [
        {
          'id': clinicianId,
          'full_name': 'Dr. Amelia Hart',
          'specialty': 'General Practice',
          'accepting_appointments': true,
          'created_at': nowIso(),
        },
      ],
      appointments: [
        {
          'id': appointmentId,
          'patient_id': patientId,
          'clinician_id': clinicianId,
          'scheduled_start': DateTime.now()
              .add(const Duration(days: 2))
              .toIso8601String(),
          'scheduled_end': DateTime.now()
              .add(const Duration(days: 2, minutes: 30))
              .toIso8601String(),
          'type': 'Video visit',
          'status': 'Confirmed',
          'reason': 'Blood pressure review',
          'created_at': nowIso(),
        },
      ],
      encounters: [
        {
          'id': encounterId,
          'appointment_id': appointmentId,
          'patient_id': patientId,
          'clinician_id': clinicianId,
          'status': 'Planning',
          'chief_complaint': 'Follow-up for hypertension',
          'assessment': 'Home readings remain above target range.',
          'plan': 'Review medication adherence and monitor daily vitals.',
          'created_at': nowIso(),
        },
      ],
      prescriptions: [
        {
          'id': newId(),
          'encounter_id': encounterId,
          'patient_id': patientId,
          'clinician_id': clinicianId,
          'status': 'ActiveMedication',
          'medication_name': 'Amlodipine',
          'dose': '5 mg',
          'route': 'Oral',
          'frequency': 'Once daily',
          'repeats': 2,
          'issued_at': nowIso(),
          'expires_at': DateTime.now()
              .add(const Duration(days: 180))
              .toIso8601String(),
          'created_at': nowIso(),
        },
      ],
      labOrders: [
        {
          'id': newId(),
          'encounter_id': encounterId,
          'patient_id': patientId,
          'clinician_id': clinicianId,
          'test_name': 'Lipid panel',
          'status': 'Ordered',
          'flag': 'Pending',
          'ordered_at': nowIso(),
          'created_at': nowIso(),
        },
        {
          'id': newId(),
          'encounter_id': encounterId,
          'patient_id': patientId,
          'clinician_id': clinicianId,
          'test_name': 'HbA1c',
          'status': 'Resulted',
          'flag': 'Normal',
          'ordered_at': nowIso(),
          'created_at': nowIso(),
        },
      ],
      vitals: [
        {
          'id': newId(),
          'patient_id': patientId,
          'type': 'Blood pressure systolic',
          'value': 152,
          'unit': 'mmHg',
          'source': 'Home device',
          'observed_at': nowIso(),
          'created_at': nowIso(),
        },
      ],
      alerts: [
        {
          'id': newId(),
          'patient_id': patientId,
          'type': 'VitalObservation',
          'severity': 'High',
          'status': 'Acknowledged',
          'message': 'Systolic blood pressure is above target range.',
          'raised_at': nowIso(),
          'created_at': nowIso(),
        },
      ],
      messages: [
        {
          'id': newId(),
          'patient_id': patientId,
          'subject': 'Medication question',
          'status': 'AwaitingCareTeam',
          'latest_message':
              'I missed a dose yesterday. Should I double up today?',
          'priority': 'Routine',
          'created_at': nowIso(),
        },
      ],
      auditEvents: [],
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) {
      return ((json[key] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return AppData(
      patients: list('patients'),
      clinicians: list('clinicians'),
      appointments: list('appointments'),
      encounters: list('encounters'),
      prescriptions: list('prescriptions'),
      labOrders: list('labOrders'),
      vitals: list('vitals'),
      alerts: list('alerts'),
      messages: list('messages'),
      auditEvents: list('auditEvents'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patients': patients,
      'clinicians': clinicians,
      'appointments': appointments,
      'encounters': encounters,
      'prescriptions': prescriptions,
      'labOrders': labOrders,
      'vitals': vitals,
      'alerts': alerts,
      'messages': messages,
      'auditEvents': auditEvents,
    };
  }

  AppData inserted(String key, Map<String, dynamic> record) {
    List<Map<String, dynamic>> add(List<Map<String, dynamic>> source) => [
      record,
      ...source,
    ];

    return copyWith(
      appointments: key == 'appointments' ? add(appointments) : null,
      prescriptions: key == 'prescriptions' ? add(prescriptions) : null,
      labOrders: key == 'labOrders' ? add(labOrders) : null,
      vitals: key == 'vitals' ? add(vitals) : null,
      alerts: key == 'alerts' ? add(alerts) : null,
      messages: key == 'messages' ? add(messages) : null,
      auditEvents: key == 'auditEvents' ? add(auditEvents) : null,
    );
  }

  AppData updated(String key, String id, Map<String, dynamic> patch) {
    List<Map<String, dynamic>> update(List<Map<String, dynamic>> source) {
      return [
        for (final item in source)
          if (item['id'] == id) {...item, ...patch} else item,
      ];
    }

    return copyWith(
      appointments: key == 'appointments' ? update(appointments) : null,
      alerts: key == 'alerts' ? update(alerts) : null,
      messages: key == 'messages' ? update(messages) : null,
    );
  }

  AppData copyWith({
    List<Map<String, dynamic>>? patients,
    List<Map<String, dynamic>>? clinicians,
    List<Map<String, dynamic>>? appointments,
    List<Map<String, dynamic>>? encounters,
    List<Map<String, dynamic>>? prescriptions,
    List<Map<String, dynamic>>? labOrders,
    List<Map<String, dynamic>>? vitals,
    List<Map<String, dynamic>>? alerts,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? auditEvents,
  }) {
    return AppData(
      patients: patients ?? this.patients,
      clinicians: clinicians ?? this.clinicians,
      appointments: appointments ?? this.appointments,
      encounters: encounters ?? this.encounters,
      prescriptions: prescriptions ?? this.prescriptions,
      labOrders: labOrders ?? this.labOrders,
      vitals: vitals ?? this.vitals,
      alerts: alerts ?? this.alerts,
      messages: messages ?? this.messages,
      auditEvents: auditEvents ?? this.auditEvents,
    );
  }
}

class VitalAlert {
  const VitalAlert(this.severity, this.message);

  final String severity;
  final String message;
}

class MessageTriage {
  const MessageTriage(this.urgent);

  final bool urgent;
}

VitalAlert? classifyVital(String type, num value) {
  if (type == 'Blood pressure systolic' && value >= 140) {
    return VitalAlert(
      value >= 180 ? 'Critical' : 'High',
      'Systolic blood pressure is above target range.',
    );
  }
  if (type == 'Glucose' && (value >= 11 || value <= 3.9)) {
    return VitalAlert(
      value >= 15 ? 'Critical' : 'Medium',
      'Glucose reading is outside the expected range.',
    );
  }
  if (type == 'Heart rate' && (value >= 120 || value <= 45)) {
    return const VitalAlert('High', 'Heart rate requires clinical review.');
  }
  return null;
}

MessageTriage triageMessage(String body) {
  final normalized = body.toLowerCase();
  final urgent = [
    'chest pain',
    'shortness of breath',
    'faint',
    'severe',
    'emergency',
  ].any(normalized.contains);
  return MessageTriage(urgent);
}

String transitionAppointment(String status, String action) {
  const transitions = {
    'Requested': {'confirm': 'Confirmed'},
    'Confirmed': {
      'checkIn': 'CheckedIn',
      'cancel': 'Cancelled',
      'reschedule': 'RescheduleRequested',
    },
    'RescheduleRequested': {'acceptSlot': 'Confirmed'},
    'CheckedIn': {'startConsultation': 'InConsultation'},
  };
  return transitions[status]?[action] ?? status;
}

List<(String, String)> appointmentActions(String status) {
  const actions = {
    'Requested': [('confirm', 'Confirm request')],
    'Confirmed': [
      ('checkIn', 'Check in'),
      ('reschedule', 'Reschedule'),
      ('cancel', 'Cancel'),
    ],
    'RescheduleRequested': [('acceptSlot', 'Accept slot')],
    'CheckedIn': [('startConsultation', 'Join video visit')],
  };
  return actions[status] ?? const [];
}

String tableFor(String key) {
  return {
    'appointments': 'appointments',
    'prescriptions': 'prescriptions',
    'labOrders': 'lab_orders',
    'vitals': 'vital_observations',
    'alerts': 'clinical_alerts',
    'messages': 'message_threads',
    'auditEvents': 'audit_events',
  }[key]!;
}

String unitForVital(String type) {
  if (type == 'Glucose') return 'mmol/L';
  if (type == 'Heart rate') return 'bpm';
  return 'mmHg';
}

String firstName(String name) => name.split(' ').first;

String nowIso() => DateTime.now().toIso8601String();

String formatDate(String? value) {
  if (value == null || value.isEmpty) return 'No date set';
  return DateFormat(
    'd MMM yyyy, h:mm a',
  ).format(DateTime.parse(value).toLocal());
}

String newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
