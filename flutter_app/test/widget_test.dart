import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  test('seed data contains patient portal records', () {
    final data = AppData.seeded();

    expect(data.patients, isNotEmpty);
    expect(data.appointments, isNotEmpty);
    expect(data.prescriptions, isNotEmpty);
    expect(data.labOrders, isNotEmpty);
    expect(data.vitals, isNotEmpty);
    expect(data.messages, isNotEmpty);
  });

  test('urgent messages are triaged', () {
    final triage = triageMessage('I have chest pain and shortness of breath');

    expect(triage.urgent, isTrue);
  });
}
