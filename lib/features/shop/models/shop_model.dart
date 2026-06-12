class SkinModel {
  final String id;
  final String name;
  final String type; // character, trail, flag
  final String? previewUrl;
  final int price;
  final bool isFree;
  final bool isOwned;
  final bool isEquipped;
  final bool isLimited;
  final String? badge; // new, hot, limited
  final DateTime? expiresAt;

  const SkinModel({
    required this.id,
    required this.name,
    required this.type,
    this.previewUrl,
    required this.price,
    this.isFree = false,
    this.isOwned = false,
    this.isEquipped = false,
    this.isLimited = false,
    this.badge,
    this.expiresAt,
  });

  factory SkinModel.fromJson(Map<String, dynamic> json) {
    return SkinModel(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      previewUrl: json['preview_url'],
      price: json['price'] ?? 0,
      isFree: json['is_free'] ?? false,
      isOwned: json['is_owned'] ?? false,
      isEquipped: json['is_equipped'] ?? false,
      isLimited: json['is_limited'] ?? false,
      badge: json['badge'],
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
    );
  }
}

class BundleModel {
  final String id;
  final String name;
  final String description;
  final List<String> itemIds;
  final int originalPrice;
  final int discountedPrice;
  final double discountPercent;
  final String? iconUrl;

  const BundleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.itemIds,
    required this.originalPrice,
    required this.discountedPrice,
    required this.discountPercent,
    this.iconUrl,
  });

  factory BundleModel.fromJson(Map<String, dynamic> json) {
    return BundleModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      itemIds: List<String>.from(json['item_ids'] ?? []),
      originalPrice: json['original_price'] ?? 0,
      discountedPrice: json['discounted_price'] ?? 0,
      discountPercent: (json['discount_percent'] ?? 0).toDouble(),
      iconUrl: json['icon_url'],
    );
  }
}

class CoinPackage {
  final String id;
  final int coins;
  final int bonusCoins;
  final double priceUsd;
  final bool isPopular;

  const CoinPackage({
    required this.id,
    required this.coins,
    this.bonusCoins = 0,
    required this.priceUsd,
    this.isPopular = false,
  });
}

// Default coin packages
const List<CoinPackage> coinPackages = [
  CoinPackage(id: 'coins_100', coins: 100, priceUsd: 0.99),
  CoinPackage(id: 'coins_500', coins: 500, bonusCoins: 50, priceUsd: 4.99, isPopular: true),
  CoinPackage(id: 'coins_1200', coins: 1200, bonusCoins: 200, priceUsd: 9.99),
  CoinPackage(id: 'coins_3000', coins: 3000, bonusCoins: 600, priceUsd: 19.99),
];
