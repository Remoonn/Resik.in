import 'package:flutter_test/flutter_test.dart';
import 'package:resik_in_mobile/models/cleaner_model.dart';

void main() {
  group('CleanerModel and CleanerRecommendation Tests', () {
    final Map<String, dynamic> sampleCleanerJson = {
      'id': 'cln-001',
      'nama': 'Candra Pratama',
      'nomor_kontak': '081234567801',
      'foto_url': 'https://images.unsplash.com/photo-1540569014015-19a7be504e3a?w=400',
      'keahlian': ['pasca_renovasi', 'rumah', 'kantor'],
      'pengalaman_tahun': 4,
      'rating_rata_rata': 4.9,
      'total_ulasan': 127,
      'total_pekerjaan': 142,
      'tingkat_kepuasan': 99,
      'ketepatan_waktu': 98,
      'status_operasional': 'Aktif',
      'tentang': 'Spesialis pembersihan mendalam (deep cleaning).',
      'sertifikasi': ['Sertifikasi BNSP K3 Kebersihan'],
      'ulasan': [
        {
          'id': 'rev-001',
          'cleaner_id': 'cln-001',
          'customer_nama': 'Anisa Rahmawati',
          'rating': 5,
          'tanggal': '2026-09-20',
          'ulasan': 'Pekerjaan sangat bersih dan rapi!',
          'service_nama': 'Pembersihan Pasca Renovasi'
        }
      ]
    };

    final Map<String, dynamic> sampleRecommendationJson = {
      'cleaner': sampleCleanerJson,
      'score': {
        'skillScore': 100,
        'availScore': 100,
        'ratingScore': 98.0,
        'effectiveRating': 4.9,
        'isProvisionalRating': false,
        'expScore': 80,
        'totalScore': 97.6,
        'matchBadge': 'Sangat Direkomendasikan'
      }
    };

    test('TC-MOD-01: Deserialisasi CleanerModel dari JSON lengkap', () {
      final cleaner = CleanerModel.fromJson(sampleCleanerJson);

      expect(cleaner.id, 'cln-001');
      expect(cleaner.nama, 'Candra Pratama');
      expect(cleaner.ratingRataRata, 4.9);
      expect(cleaner.totalUlasan, 127);
      expect(cleaner.totalPekerjaan, 142);
      expect(cleaner.tingkatKepuasan, 99);
      expect(cleaner.ketepatanWaktu, 98);
      expect(cleaner.keahlian.length, 3);
      expect(cleaner.sertifikasi.length, 1);
      expect(cleaner.ulasan.length, 1);
      expect(cleaner.ulasan.first.customerNama, 'Anisa Rahmawati');
    });

    test('TC-MOD-02: Deserialisasi CleanerRecommendation dengan detail skor', () {
      final recommendation = CleanerRecommendation.fromJson(sampleRecommendationJson);

      expect(recommendation.cleaner.id, 'cln-001');
      expect(recommendation.score.totalScore, 97.6);
      expect(recommendation.score.matchBadge, 'Sangat Direkomendasikan');
      expect(recommendation.score.isProvisionalRating, false);
      expect(recommendation.score.effectiveRating, 4.9);
    });

    test('TC-MOD-03: Deserialisasi Petugas Baru dengan Provisional Rating 4.5', () {
      final newCleanerRecommendation = CleanerRecommendation.fromJson({
        'cleaner': {
          'id': 'cln-005',
          'nama': 'Dewi Lestari',
          'rating_rata_rata': 0,
          'total_ulasan': 0,
          'total_pekerjaan': 0,
          'pengalaman_tahun': 1,
          'keahlian': ['rumah'],
          'status_operasional': 'Aktif'
        },
        'score': {
          'skillScore': 100,
          'availScore': 100,
          'ratingScore': 90.0,
          'effectiveRating': 4.5,
          'isProvisionalRating': true,
          'expScore': 20,
          'totalScore': 90.0,
          'matchBadge': 'Sangat Direkomendasikan'
        }
      });

      expect(newCleanerRecommendation.score.isProvisionalRating, true);
      expect(newCleanerRecommendation.score.effectiveRating, 4.5);
    });
  });
}
