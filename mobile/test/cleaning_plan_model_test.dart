import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaning_plan_model.dart';

void main() {
  group('CleaningPlanModel Serialization & Domain Logic Tests (FR-12)', () {
    test('1. fromJson harus mem-parsing respons backend dengan format snake_case dan camelCase', () {
      final json = {
        'id': 'plan-test-01',
        'customer_id': 'usr-cust-001',
        'plan_name': 'Langganan Bersih Kos Mingguan',
        'service_category': 'kos',
        'service_id': 'srv-002',
        'frequency': 'mingguan',
        'day_of_week': 1,
        'day_name': 'Senin',
        'start_time': '09:00',
        'duration': 2,
        'price_per_session': 100000,
        'address': 'Jl. Kaliurang KM 14.5 No. 4',
        'landmark': 'Pagar hitam dekat warung',
        'notes': 'Fokus kamar mandi & teras',
        'preferred_cleaner_id': 'cln-001',
        'status': 'Aktif',
        'next_session_date': '2026-10-19',
        'last_generated_date': '2026-10-12',
        'total_sessions_completed': 3,
        'created_at': '2026-10-01T08:00:00.000Z',
        'updated_at': '2026-10-12T10:00:00.000Z',
      };

      final plan = CleaningPlanModel.fromJson(json);

      expect(plan.id, 'plan-test-01');
      expect(plan.customerId, 'usr-cust-001');
      expect(plan.planName, 'Langganan Bersih Kos Mingguan');
      expect(plan.serviceCategory, 'kos');
      expect(plan.serviceId, 'srv-002');
      expect(plan.frequency, 'mingguan');
      expect(plan.dayOfWeek, 1);
      expect(plan.dayName, 'Senin');
      expect(plan.startTime, '09:00');
      expect(plan.duration, 2);
      expect(plan.pricePerSession, 100000.0);
      expect(plan.address, 'Jl. Kaliurang KM 14.5 No. 4');
      expect(plan.landmark, 'Pagar hitam dekat warung');
      expect(plan.notes, 'Fokus kamar mandi & teras');
      expect(plan.preferredCleanerId, 'cln-001');
      expect(plan.status, 'Aktif');
      expect(plan.nextSessionDate, '2026-10-19');
      expect(plan.lastGeneratedDate, '2026-10-12');
      expect(plan.totalSessionsCompleted, 3);
      expect(plan.isAktif, isTrue);
      expect(plan.isDijeda, isFalse);
      expect(plan.isDibatalkan, isFalse);
      expect(plan.frequencyDisplay, 'Setiap Minggu');
    });

    test('2. fromJson harus mem-parsing preferensi petugas tersemat (preferredCleaner)', () {
      final json = {
        'id': 'plan-test-02',
        'customer_id': 'usr-cust-002',
        'plan_name': 'Paket Bersih Rumah 2 Mingguan',
        'service_category': 'rumah',
        'service_id': 'srv-001',
        'frequency': 'dua_mingguan',
        'day_of_week': 6,
        'day_name': 'Sabtu',
        'start_time': '10:00',
        'duration': 3,
        'price_per_session': 175000,
        'address': 'Perumahan Sleman Asri B-3',
        'status': 'Dijeda',
        'preferred_cleaner_id': 'cln-002',
        'preferred_cleaner': {
          'id': 'cln-002',
          'nama': 'Ahmad Fauzi',
          'nomor_telepon': '081298765432',
          'rating_rata_rata': 4.85,
          'total_pekerjaan': 55
        }
      };

      final plan = CleaningPlanModel.fromJson(json);

      expect(plan.isDijeda, isTrue);
      expect(plan.isAktif, isFalse);
      expect(plan.frequencyDisplay, 'Setiap 2 Minggu');
      expect(plan.preferredCleaner, isNotNull);
      expect(plan.preferredCleaner!.id, 'cln-002');
      expect(plan.preferredCleaner!.nama, 'Ahmad Fauzi');
      expect(plan.preferredCleaner!.ratingRataRata, 4.85);
      expect(plan.preferredCleaner!.nomorTelepon, '081298765432');
    });

    test('3. toJson menghasilkan payload yang valid untuk POST /api/cleaning-plans', () {
      final plan = CleaningPlanModel(
        id: 'plan-new',
        customerId: 'usr-cust-001',
        planName: 'Rutin Kos Mahasiswa',
        serviceCategory: 'kos',
        serviceId: 'srv-002',
        frequency: 'mingguan',
        dayOfWeek: 3,
        dayName: 'Rabu',
        startTime: '13:00',
        duration: 2,
        pricePerSession: 100000.0,
        address: 'Jl. Gejayan No. 12',
        landmark: 'Depan minimarket',
        notes: 'Bawa lap khusus',
        preferredCleanerId: 'cln-001',
        status: 'Aktif',
      );

      final payload = plan.toJson();

      expect(payload['plan_name'], 'Rutin Kos Mahasiswa');
      expect(payload['service_category'], 'kos');
      expect(payload['service_id'], 'srv-002');
      expect(payload['frequency'], 'mingguan');
      expect(payload['day_of_week'], 3);
      expect(payload['day_name'], 'Rabu');
      expect(payload['start_time'], '13:00');
      expect(payload['duration'], 2);
      expect(payload['price_per_session'], 100000.0);
      expect(payload['address'], 'Jl. Gejayan No. 12');
      expect(payload['landmark'], 'Depan minimarket');
      expect(payload['notes'], 'Bawa lap khusus');
      expect(payload['preferred_cleaner_id'], 'cln-001');
    });

    test('4. fromJson menangani fallback nilai kosong dan format camelCase dengan aman', () {
      final jsonMinimal = {
        'id': 'plan-min',
        'customerId': 'usr-cust-003',
        'planName': 'Paket Minimalis',
        'serviceCategory': 'rumah',
        'serviceId': 'srv-001',
        'frequency': 'mingguan',
        'dayOfWeek': 5,
        'dayName': 'Jumat',
        'startTime': '08:30',
        'duration': 2,
        'pricePerSession': 120000,
        'address': 'Jl. Kaliurang KM 9',
      };

      final plan = CleaningPlanModel.fromJson(jsonMinimal);

      expect(plan.id, 'plan-min');
      expect(plan.customerId, 'usr-cust-003');
      expect(plan.totalSessionsCompleted, 0);
      expect(plan.status, 'Aktif');
      expect(plan.preferredCleanerId, isNull);
      expect(plan.preferredCleaner, isNull);
      expect(plan.landmark, isNull);
      expect(plan.notes, isNull);
    });
  });
}
