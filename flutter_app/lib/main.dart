import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ktbpsliejglodmonmzhs.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0YnBzbGllamdsb2Rtb25temhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDA2MTYsImV4cCI6MjA5MjAxNjYxNn0.WMwO-DFKZeMDb8MTy7qjBs6zdX_bP6vdC0ffF5V0KLg';

const _ink = Color(0xff0b0f0e);
const _surface = Color(0xff121816);
const _surfaceHigh = Color(0xff18211f);
const _line = Color(0xff293431);
const _muted = Color(0xff93a09b);
const _text = Color(0xffecf3ef);
const _mint = Color(0xff5cc8ad);
const _blue = Color(0xff68a0ff);
const _amber = Color(0xffffbd59);
const _rose = Color(0xffff6f7d);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const HealthPathApp());
}

class HealthPathApp extends StatelessWidget {
  const HealthPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _mint,
          brightness: Brightness.dark,
        ).copyWith(
          primary: _mint,
          secondary: _blue,
          tertiary: _amber,
          surface: _surface,
          onSurface: _text,
        );

    return MaterialApp(
      title: 'HealthPath',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _ink,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _ink,
          foregroundColor: _text,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: _surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: _line),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _mint, width: 1.4),
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
  String _vitalType = 'Blood pressure systolic';
  int _tab = 0;
  Set<String> _completedTasks = {};

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
    final selected = result.data.patients.firstOrNull?['id'] as String?;
    final completed = await _loadTasks(selected);
    if (!mounted) return;

    setState(() {
      _data = result.data;
      _backendMode = result.mode;
      _backendMessage = result.message;
      _selectedPatientId = selected;
      _completedTasks = completed;
    });
  }

  Future<Set<String>> _loadTasks(String? patientId) async {
    if (patientId == null) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('healthpath.tasks.$patientId');
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  Future<void> _saveTasks() async {
    if (_selectedPatientId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'healthpath.tasks.$_selectedPatientId',
      jsonEncode(_completedTasks.toList()),
    );
  }

  Map<String, dynamic>? get patient {
    return _data.patients.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == _selectedPatientId,
      orElse: () => null,
    );
  }

  List<Map<String, dynamic>> _forPatient(List<Map<String, dynamic>> records) {
    return records
        .where((item) => item['patient_id'] == _selectedPatientId)
        .toList();
  }

  List<Map<String, dynamic>> get _appointments =>
      _forPatient(_data.appointments);
  List<Map<String, dynamic>> get _prescriptions =>
      _forPatient(_data.prescriptions);
  List<Map<String, dynamic>> get _labs => _forPatient(_data.labOrders);
  List<Map<String, dynamic>> get _vitals => _forPatient(_data.vitals);
  List<Map<String, dynamic>> get _alerts => _forPatient(_data.alerts);
  List<Map<String, dynamic>> get _messages => _forPatient(_data.messages);

  Future<void> _insert(String key, Map<String, dynamic> record) async {
    setState(() => _data = _data.inserted(key, record));
    try {
      if (_backendMode == 'supabase') await _store.insert(key, record);
    } catch (error) {
      _showSnack('Saved locally. Supabase write failed: $error');
      setState(() {
        _backendMode = 'offline';
        _backendMessage =
            'Using browser storage after a Supabase write failed.';
      });
    }
    await _store.saveOffline(_data);
  }

  Future<void> _update(
    String key,
    String id,
    Map<String, dynamic> patch,
  ) async {
    setState(() => _data = _data.updated(key, id, patch));
    try {
      if (_backendMode == 'supabase') await _store.update(key, id, patch);
    } catch (error) {
      _showSnack('Updated locally. Supabase update failed: $error');
      setState(() {
        _backendMode = 'offline';
        _backendMessage =
            'Using browser storage after a Supabase update failed.';
      });
    }
    await _store.saveOffline(_data);
  }

  Future<void> _seedSupabase() async {
    try {
      final seeded = AppData.seeded();
      await _store.seedSupabase(seeded);
      await _store.saveOffline(seeded);
      final completed = await _loadTasks(seeded.patients.first['id'] as String);
      setState(() {
        _data = seeded;
        _selectedPatientId = seeded.patients.first['id'] as String;
        _backendMode = 'supabase';
        _backendMessage = 'Demo records seeded in Supabase.';
        _completedTasks = completed;
      });
      _showSnack('Demo data seeded.');
    } catch (error) {
      _showSnack('Supabase seed failed: $error');
    }
  }

  Future<void> _switchPatient(String id) async {
    final completed = await _loadTasks(id);
    setState(() {
      _selectedPatientId = id;
      _completedTasks = completed;
      _tab = 0;
    });
  }

  Future<void> _requestAppointment() async {
    final selected = patient;
    if (selected == null) return;
    final reason = _appointmentReason.text.trim();
    if (reason.isEmpty) {
      _showSnack('Add a reason for the appointment.');
      return;
    }

    final clinician = _data.clinicians.firstOrNull;
    final start = DateTime.now().add(const Duration(days: 3, hours: 2));
    await _insert('appointments', {
      'id': newId(),
      'patient_id': selected['id'],
      'clinician_id': clinician?['id'],
      'scheduled_start': start.toIso8601String(),
      'scheduled_end': start.add(const Duration(minutes: 30)).toIso8601String(),
      'type': 'Video visit',
      'status': 'Requested',
      'reason': reason,
      'created_at': nowIso(),
    });
    _appointmentReason.clear();
    _showSnack('Appointment request sent.');
  }

  Future<void> _transitionAppointment(
    Map<String, dynamic> appointment,
    String action,
  ) async {
    final next = transitionAppointment(appointment['status'] as String, action);
    await _update('appointments', appointment['id'] as String, {
      'status': next,
    });
  }

  Future<void> _requestRefill(Map<String, dynamic> prescription) async {
    final selected = patient;
    if (selected == null) return;
    await _insert('prescriptions', {
      'id': newId(),
      'encounter_id': prescription['encounter_id'],
      'patient_id': selected['id'],
      'clinician_id': prescription['clinician_id'],
      'status': 'RefillRequested',
      'medication_name': prescription['medication_name'],
      'dose': prescription['dose'],
      'route': prescription['route'] ?? 'Oral',
      'frequency': prescription['frequency'],
      'repeats': 0,
      'issued_at': nowIso(),
      'expires_at': DateTime.now()
          .add(const Duration(days: 90))
          .toIso8601String(),
      'created_at': nowIso(),
    });
    _showSnack('Refill request sent to the care team.');
  }

  Future<void> _sendMessage() async {
    final selected = patient;
    final body = _messageBody.text.trim();
    if (selected == null) return;
    if (body.length < 8) {
      _showSnack('Write a little more detail for your care team.');
      return;
    }

    final triage = triageMessage(body);
    await _insert('messages', {
      'id': newId(),
      'patient_id': selected['id'],
      'subject': triage.urgent
          ? 'Urgent symptom question'
          : 'Care team question',
      'status': triage.urgent ? 'UrgentReview' : 'AwaitingCareTeam',
      'latest_message': body,
      'priority': triage.urgent ? 'Urgent' : 'Routine',
      'created_at': nowIso(),
    });
    _messageBody.clear();
    _showSnack(triage.urgent ? 'Marked urgent for review.' : 'Message sent.');
  }

  Future<void> _logVital() async {
    final selected = patient;
    final value = num.tryParse(_vitalValue.text.trim());
    if (selected == null) return;
    if (value == null) {
      _showSnack('Enter a valid reading.');
      return;
    }

    final vitalId = newId();
    await _insert('vitals', {
      'id': vitalId,
      'patient_id': selected['id'],
      'type': _vitalType,
      'value': value,
      'unit': unitForVital(_vitalType),
      'source': 'Patient app',
      'observed_at': nowIso(),
      'created_at': nowIso(),
    });

    final alert = classifyVital(_vitalType, value);
    if (alert != null) {
      await _insert('alerts', {
        'id': newId(),
        'patient_id': selected['id'],
        'vital_observation_id': vitalId,
        'type': 'VitalObservation',
        'severity': alert.severity,
        'status': 'Raised',
        'message': alert.message,
        'raised_at': nowIso(),
        'created_at': nowIso(),
      });
    }

    _vitalValue.clear();
    _showSnack(
      alert == null ? 'Reading logged.' : 'Reading logged and alert raised.',
    );
  }

  Future<void> _toggleTask(String id) async {
    setState(() {
      if (_completedTasks.contains(id)) {
        _completedTasks.remove(id);
      } else {
        _completedTasks.add(id);
      }
    });
    await _saveTasks();
  }

  List<CarePlan> get _plans {
    final clinicianName =
        (_data.clinicians.firstOrNull?['full_name'] as String?) ?? 'Care team';
    return [
      CarePlan(
        id: 'cardiac',
        title: 'Cardiac Recovery Programme',
        clinician: clinicianName,
        progress: _planProgress(['bp', 'meds', 'walk']),
        activities: 3,
        accent: _mint,
      ),
      CarePlan(
        id: 'diabetes',
        title: 'Diabetes Management Plan',
        clinician: 'Dr. Raj Patel',
        progress: _planProgress(['glucose', 'labs']),
        activities: 2,
        accent: _blue,
      ),
    ];
  }

  List<CareTask> get _tasks {
    return [
      const CareTask(
        id: 'bp',
        title: 'Log blood pressure',
        subtitle: 'Morning reading before coffee',
        icon: Icons.monitor_heart_outlined,
        accent: _mint,
      ),
      const CareTask(
        id: 'meds',
        title: 'Take Amlodipine',
        subtitle: '5 mg once daily',
        icon: Icons.medication_outlined,
        accent: _blue,
      ),
      const CareTask(
        id: 'walk',
        title: '10 minute walk',
        subtitle: 'Low intensity movement',
        icon: Icons.directions_walk_outlined,
        accent: _amber,
      ),
      const CareTask(
        id: 'glucose',
        title: 'Check glucose',
        subtitle: 'Before lunch if fasting today',
        icon: Icons.water_drop_outlined,
        accent: _rose,
      ),
      const CareTask(
        id: 'labs',
        title: 'Review test results',
        subtitle: 'Open latest lipid panel',
        icon: Icons.science_outlined,
        accent: _mint,
      ),
    ];
  }

  double _planProgress(List<String> taskIds) {
    if (taskIds.isEmpty) return 0;
    final done = taskIds.where(_completedTasks.contains).length;
    return done / taskIds.length;
  }

  int get _pendingCount {
    final appointmentCount = _appointments
        .where(
          (item) =>
              ['Requested', 'RescheduleRequested'].contains(item['status']),
        )
        .length;
    final alertCount = _alerts
        .where((item) => item['status'] == 'Raised')
        .length;
    final messageCount = _messages
        .where(
          (item) =>
              ['AwaitingCareTeam', 'UrgentReview'].contains(item['status']),
        )
        .length;
    final labCount = _labs.where((item) => item['flag'] == 'Pending').length;
    return appointmentCount + alertCount + messageCount + labCount;
  }

  int get _doneToday => _completedTasks.length;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = patient;
    final content = selected == null
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _tab,
            children: [
              _HomeTab(
                patient: selected,
                plans: _plans,
                tasks: _tasks,
                completedTasks: _completedTasks,
                doneToday: _doneToday,
                pendingCount: _pendingCount,
                activePlans: _plans.length,
                backendMode: _backendMode,
                latestAlert: _alerts.firstOrNull,
                onToggleTask: _toggleTask,
                onOpenToday: () => setState(() => _tab = 2),
                onOpenMetrics: () => setState(() => _tab = 3),
              ),
              _PlansTab(
                plans: _plans,
                tasks: _tasks,
                completedTasks: _completedTasks,
                onToggleTask: _toggleTask,
              ),
              _TodayTab(
                appointments: _appointments,
                prescriptions: _prescriptions,
                labs: _labs,
                messages: _messages,
                appointmentReason: _appointmentReason,
                messageBody: _messageBody,
                onRequestAppointment: _requestAppointment,
                onAppointmentAction: _transitionAppointment,
                onRequestRefill: _requestRefill,
                onSendMessage: _sendMessage,
              ),
              _MetricsTab(
                vitals: _vitals,
                alerts: _alerts,
                vitalType: _vitalType,
                vitalValue: _vitalValue,
                onVitalTypeChanged: (value) =>
                    setState(() => _vitalType = value),
                onLogVital: _logVital,
              ),
              _ProfileTab(
                patient: selected,
                patients: _data.patients,
                backendMode: _backendMode,
                backendMessage: _backendMessage,
                selectedPatientId: _selectedPatientId,
                onSwitchPatient: _switchPatient,
                onSeedSupabase: _seedSupabase,
              ),
            ],
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFrame = constraints.maxWidth > 640;
        final app = ClipRRect(
          borderRadius: BorderRadius.circular(useFrame ? 28 : 0),
          child: Scaffold(
            body: SafeArea(child: content),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              height: 72,
              backgroundColor: _surface,
              indicatorColor: _mint.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) => setState(() => _tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Plans',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: 'Metrics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );

        if (!useFrame) return app;
        return ColoredBox(
          color: const Color(0xff080a09),
          child: Center(
            child: Container(
              width: 430,
              height: min(constraints.maxHeight - 32, 920),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xff343c39), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 32,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: app,
            ),
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.patient,
    required this.plans,
    required this.tasks,
    required this.completedTasks,
    required this.doneToday,
    required this.pendingCount,
    required this.activePlans,
    required this.backendMode,
    required this.latestAlert,
    required this.onToggleTask,
    required this.onOpenToday,
    required this.onOpenMetrics,
  });

  final Map<String, dynamic> patient;
  final List<CarePlan> plans;
  final List<CareTask> tasks;
  final Set<String> completedTasks;
  final int doneToday;
  final int pendingCount;
  final int activePlans;
  final String backendMode;
  final Map<String, dynamic>? latestAlert;
  final ValueChanged<String> onToggleTask;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenMetrics;

  @override
  Widget build(BuildContext context) {
    final name = patient['full_name'] as String;
    final first = firstName(name);
    final nextTasks = tasks
        .where((task) => !completedTasks.contains(task.id))
        .take(3);

    return _Screen(
      children: [
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'HealthPath',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            _Avatar(name: name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(color: _muted, fontSize: 16),
                  ),
                  Text(
                    first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _Pill(
              label: backendMode == 'supabase' ? 'Live' : 'Local',
              icon: backendMode == 'supabase'
                  ? Icons.cloud_done
                  : Icons.cloud_off,
              color: backendMode == 'supabase' ? _mint : _amber,
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_turned_in_outlined,
                value: '$activePlans',
                label: 'Active Plans',
                color: _mint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                value: '$doneToday',
                label: 'Done Today',
                color: _blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.pending_actions_outlined,
                value: '$pendingCount',
                label: 'Pending',
                color: _amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Active Care Plans',
          action: 'Today',
          onTap: onOpenToday,
        ),
        const SizedBox(height: 12),
        for (final plan in plans) ...[
          _PlanCard(plan: plan),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        const _SectionHeader(title: "Today's Highlights"),
        const SizedBox(height: 12),
        if (latestAlert != null)
          _InsightCard(
            title: latestAlert!['message'] as String,
            detail: 'Your care team can see new high-priority alerts.',
            icon: Icons.notifications_active_outlined,
            color: _rose,
          )
        else
          const _InsightCard(
            title: 'No active clinical alerts',
            detail: 'Keep following your plan and logging readings.',
            icon: Icons.favorite_border,
            color: _mint,
          ),
        const SizedBox(height: 12),
        for (final task in nextTasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskTile(
              task: task,
              done: completedTasks.contains(task.id),
              onTap: () => onToggleTask(task.id),
            ),
          ),
        const SizedBox(height: 8),
        _ImageFeatureCard(onOpenMetrics: onOpenMetrics),
      ],
    );
  }
}

class _PlansTab extends StatelessWidget {
  const _PlansTab({
    required this.plans,
    required this.tasks,
    required this.completedTasks,
    required this.onToggleTask,
  });

  final List<CarePlan> plans;
  final List<CareTask> tasks;
  final Set<String> completedTasks;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return _Screen(
      title: 'Care Plans',
      subtitle: 'Your daily actions and progress are tracked here.',
      children: [
        for (final plan in plans) ...[
          _PlanCard(plan: plan),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Plan Tasks'),
        const SizedBox(height: 12),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskTile(
              task: task,
              done: completedTasks.contains(task.id),
              onTap: () => onToggleTask(task.id),
            ),
          ),
      ],
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.appointments,
    required this.prescriptions,
    required this.labs,
    required this.messages,
    required this.appointmentReason,
    required this.messageBody,
    required this.onRequestAppointment,
    required this.onAppointmentAction,
    required this.onRequestRefill,
    required this.onSendMessage,
  });

  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> prescriptions;
  final List<Map<String, dynamic>> labs;
  final List<Map<String, dynamic>> messages;
  final TextEditingController appointmentReason;
  final TextEditingController messageBody;
  final Future<void> Function() onRequestAppointment;
  final Future<void> Function(Map<String, dynamic>, String) onAppointmentAction;
  final Future<void> Function(Map<String, dynamic>) onRequestRefill;
  final Future<void> Function() onSendMessage;

  @override
  Widget build(BuildContext context) {
    final latestPrescription = prescriptions.firstOrNull;

    return _Screen(
      title: 'Today',
      subtitle: 'Appointments, refills, results, and messages.',
      children: [
        _Panel(
          title: 'Book care',
          icon: Icons.video_call_outlined,
          child: Column(
            children: [
              TextField(
                controller: appointmentReason,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What do you need help with?',
                  hintText: 'Blood pressure review',
                ),
              ),
              const SizedBox(height: 10),
              _PrimaryButton(
                label: 'Request video appointment',
                onPressed: onRequestAppointment,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _SectionHeader(title: 'Upcoming'),
        const SizedBox(height: 10),
        if (appointments.isEmpty)
          const _EmptyCard(message: 'No appointments yet.')
        else
          for (final appointment in appointments.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AppointmentTile(
                appointment: appointment,
                onAction: (action) => onAppointmentAction(appointment, action),
              ),
            ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Medication',
          icon: Icons.medication_outlined,
          child: latestPrescription == null
              ? const _MutedText('No medications recorded.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${latestPrescription['medication_name']} ${latestPrescription['dose']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${latestPrescription['frequency']} · ${latestPrescription['status']}',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(
                      label: 'Request refill',
                      icon: Icons.refresh,
                      onPressed: () => onRequestRefill(latestPrescription),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Test results',
          icon: Icons.science_outlined,
          child: labs.isEmpty
              ? const _MutedText('No lab orders yet.')
              : Column(
                  children: [
                    for (final lab in labs.take(3))
                      _MiniRow(
                        title: lab['test_name'] as String,
                        detail: '${lab['status']} · ${lab['flag']}',
                        color: lab['flag'] == 'Normal' ? _mint : _amber,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Secure message',
          icon: Icons.chat_bubble_outline,
          child: Column(
            children: [
              TextField(
                controller: messageBody,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message your care team',
                  hintText: 'Ask a non-urgent medical question',
                ),
              ),
              const SizedBox(height: 10),
              _PrimaryButton(
                label: 'Send and triage',
                onPressed: onSendMessage,
              ),
              const SizedBox(height: 12),
              for (final message in messages.take(2))
                _MiniRow(
                  title: message['subject'] as String,
                  detail: '${message['status']} · ${message['priority']}',
                  color: message['priority'] == 'Urgent' ? _rose : _mint,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsTab extends StatelessWidget {
  const _MetricsTab({
    required this.vitals,
    required this.alerts,
    required this.vitalType,
    required this.vitalValue,
    required this.onVitalTypeChanged,
    required this.onLogVital,
  });

  final List<Map<String, dynamic>> vitals;
  final List<Map<String, dynamic>> alerts;
  final String vitalType;
  final TextEditingController vitalValue;
  final ValueChanged<String> onVitalTypeChanged;
  final Future<void> Function() onLogVital;

  @override
  Widget build(BuildContext context) {
    final latest = vitals.firstOrNull;

    return _Screen(
      title: 'Metrics',
      subtitle: 'Log readings and spot changes earlier.',
      children: [
        _Panel(
          title: 'Add reading',
          icon: Icons.add_chart_outlined,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: vitalType,
                items: const [
                  DropdownMenuItem(
                    value: 'Blood pressure systolic',
                    child: Text('Blood pressure systolic'),
                  ),
                  DropdownMenuItem(value: 'Glucose', child: Text('Glucose')),
                  DropdownMenuItem(
                    value: 'Heart rate',
                    child: Text('Heart rate'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onVitalTypeChanged(value);
                },
                decoration: const InputDecoration(labelText: 'Reading type'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vitalValue,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Value',
                  suffixText: unitForVital(vitalType),
                ),
              ),
              const SizedBox(height: 10),
              _PrimaryButton(label: 'Log reading', onPressed: onLogVital),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (latest != null)
          _Panel(
            title: 'Latest reading',
            icon: Icons.monitor_heart_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${latest['value']} ${latest['unit']}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latest['type']} · ${formatDate(latest['observed_at'] as String?)}',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const _SectionHeader(title: 'Clinical alerts'),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          const _EmptyCard(message: 'No alerts raised.')
        else
          for (final alert in alerts.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertTile(alert: alert),
            ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.patient,
    required this.patients,
    required this.backendMode,
    required this.backendMessage,
    required this.selectedPatientId,
    required this.onSwitchPatient,
    required this.onSeedSupabase,
  });

  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> patients;
  final String backendMode;
  final String backendMessage;
  final String? selectedPatientId;
  final ValueChanged<String> onSwitchPatient;
  final Future<void> Function() onSeedSupabase;

  @override
  Widget build(BuildContext context) {
    return _Screen(
      title: 'Profile',
      subtitle: 'Family access, demo data, and model traceability.',
      children: [
        _Panel(
          title: 'Patient account',
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: patient['full_name'] as String, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['full_name'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${patient['risk_level']} risk · ${patient['preferred_language']}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                patient['care_goal'] as String,
                style: const TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Family profiles',
          icon: Icons.family_restroom_outlined,
          child: Column(
            children: [
              for (final item in patients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ProfileSwitchTile(
                    patient: item,
                    selected: item['id'] == selectedPatientId,
                    onTap: () => onSwitchPatient(item['id'] as String),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Backend status',
          icon: backendMode == 'supabase'
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Pill(
                label: backendMode == 'supabase'
                    ? 'Supabase connected'
                    : 'Offline demo',
                icon: backendMode == 'supabase' ? Icons.check : Icons.storage,
                color: backendMode == 'supabase' ? _mint : _amber,
              ),
              const SizedBox(height: 10),
              Text(
                backendMessage,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: 'Seed demo data',
                icon: Icons.dataset_outlined,
                onPressed: onSeedSupabase,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Panel(
          title: 'Model trace',
          icon: Icons.account_tree_outlined,
          child: Column(
            children: [
              _MiniRow(
                title: 'Class model',
                detail: 'Patients, clinicians, appointments, prescriptions',
                color: _mint,
              ),
              _MiniRow(
                title: 'State models',
                detail: 'Appointments, alerts, messages, refill requests',
                color: _blue,
              ),
              _MiniRow(
                title: 'ER model',
                detail: 'Supabase tables mirror the domain model',
                color: _amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({this.title, this.subtitle, required this.children});

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: _muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 22),
        ],
        ...children,
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _mint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 74});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _mint,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: _ink,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 18),
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    final percent = (plan.progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill(
                  label: 'Active',
                  icon: Icons.play_circle_outline,
                  color: plan.accent,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.clinician, style: const TextStyle(color: _muted)),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: plan.progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: _line,
                color: plan.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$percent% complete · ${plan.activities} activities',
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.done,
    required this.onTap,
  });

  final CareTask task;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: task.accent.withValues(alpha: 0.14),
                ),
                child: Icon(task.icon, color: task.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(task.subtitle, style: const TextStyle(color: _muted)),
                  ],
                ),
              ),
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? _mint : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.onAction});

  final Map<String, dynamic> appointment;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = appointmentActions(appointment['status'] as String);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment['reason'] as String,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Pill(
                  label: appointment['status'] as String,
                  icon: Icons.circle,
                  color: _mint,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${appointment['type']} · ${formatDate(appointment['scheduled_start'] as String?)}',
              style: const TextStyle(color: _muted),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    _SmallButton(
                      label: action.$2,
                      onPressed: () => onAction(action.$1),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] as String;
    final color = severity == 'Critical' ? _rose : _amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert['message'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$severity · ${alert['status']}',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFeatureCard extends StatelessWidget {
  const _ImageFeatureCard({required this.onOpenMetrics});

  final VoidCallback onOpenMetrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.network(
              'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=900&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: _surfaceHigh,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: _mint,
                  size: 44,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected care at home',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log readings, follow plans, and keep your care team in the loop.',
                  style: TextStyle(color: _muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                _SecondaryButton(
                  label: 'Open metrics',
                  icon: Icons.show_chart,
                  onPressed: onOpenMetrics,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitchTile extends StatelessWidget {
  const _ProfileSwitchTile({
    required this.patient,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> patient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? _mint.withValues(alpha: 0.12) : _surfaceHigh,
          border: Border.all(color: selected ? _mint : _line),
        ),
        child: Row(
          children: [
            _Avatar(name: patient['full_name'] as String, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['full_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${patient['risk_level']} risk',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: _mint),
          ],
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _mint,
          foregroundColor: _ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => onPressed(),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _mint,
        side: const BorderSide(color: _mint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: _muted));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, style: const TextStyle(color: _muted)),
      ),
    );
  }
}

class CarePlan {
  const CarePlan({
    required this.id,
    required this.title,
    required this.clinician,
    required this.progress,
    required this.activities,
    required this.accent,
  });

  final String id;
  final String title;
  final String clinician;
  final double progress;
  final int activities;
  final Color accent;
}

class CareTask {
  const CareTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
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
  static const _offlineKey = 'healthpath.flutter.offline.v2';

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
          'full_name': 'Alex Johnson',
          'date_of_birth': '1988-09-14',
          'preferred_language': 'English',
          'risk_level': 'Moderate',
          'care_goal': 'Reduce blood pressure and rebuild daily activity.',
          'created_at': nowIso(),
        },
        {
          'id': secondPatientId,
          'full_name': 'Noah Patel',
          'date_of_birth': '1975-02-03',
          'preferred_language': 'English',
          'risk_level': 'High',
          'care_goal': 'Monitor glucose and follow up on abnormal lab results.',
          'created_at': nowIso(),
        },
      ],
      clinicians: [
        {
          'id': clinicianId,
          'full_name': 'Dr. Sarah Evans',
          'specialty': 'Primary Care',
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
      prescriptions: key == 'prescriptions' ? update(prescriptions) : null,
      labOrders: key == 'labOrders' ? update(labOrders) : null,
      vitals: key == 'vitals' ? update(vitals) : null,
      alerts: key == 'alerts' ? update(alerts) : null,
      messages: key == 'messages' ? update(messages) : null,
      auditEvents: key == 'auditEvents' ? update(auditEvents) : null,
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

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 18) return 'Good afternoon,';
  return 'Good evening,';
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
