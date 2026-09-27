class ServiceModel {
  final String id;
  final String namaLayanan;
  final String kategori;
  final String deskripsi;
  final String durasiEstimasi;
  final double tarifDasar;
  final String iconName;
  final bool isActive;

  ServiceModel({
    required this.id,
    required this.namaLayanan,
    required this.kategori,
    required this.deskripsi,
    required this.durasiEstimasi,
    required this.tarifDasar,
    required this.iconName,
    required this.isActive,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id']?.toString() ?? '',
      namaLayanan: json['nama_layanan']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? '',
      deskripsi: json['deskripsi']?.toString() ?? '',
      durasiEstimasi: json['durasi_estimasi']?.toString() ?? '',
      tarifDasar: (json['tarif_dasar'] is num)
          ? (json['tarif_dasar'] as num).toDouble()
          : double.tryParse(json['tarif_dasar']?.toString() ?? '0') ?? 0.0,
      iconName: json['icon_name']?.toString() ?? 'cleaning_services',
      isActive: json['is_active'] == true,
    );
  }
}
