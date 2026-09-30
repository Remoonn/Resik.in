/// Model data ulasan pelanggan untuk pesanan yang telah tuntas (FR-11)
class ReviewModel {
  final String id;
  final String orderId;
  final String customerId;
  final String? customerName;
  final String cleanerId;
  final int rating;
  final String? catatanUlasan;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    this.customerName,
    required this.cleanerId,
    required this.rating,
    this.catatanUlasan,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? json['customer_nama'] as String?,
      cleanerId: json['cleaner_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      catatanUlasan: json['catatan_ulasan'] as String? ?? json['ulasan'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : (json['tanggal'] != null ? DateTime.tryParse(json['tanggal'] as String) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      'cleaner_id': cleanerId,
      'rating': rating,
      if (catatanUlasan != null) 'catatan_ulasan': catatanUlasan,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
