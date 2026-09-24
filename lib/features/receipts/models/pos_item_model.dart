import 'package:flutter/material.dart';

class PosItemModel {
  final String id;
  final String title;
  final String category; // 'Sacraments', 'Mass Intentions', 'Certificates', 'Devotionals', 'Others'
  final double defaultPrice;
  final IconData icon;
  final String iconName;
  final String description;
  final bool allowsCustomPrice;
  final bool isActive;

  const PosItemModel({
    required this.id,
    required this.title,
    required this.category,
    required this.defaultPrice,
    required this.icon,
    this.iconName = 'church',
    required this.description,
    this.allowsCustomPrice = false,
    this.isActive = true,
  });

  PosItemModel copyWith({
    String? id,
    String? title,
    String? category,
    double? defaultPrice,
    IconData? icon,
    String? iconName,
    String? description,
    bool? allowsCustomPrice,
    bool? isActive,
  }) {
    return PosItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      icon: icon ?? this.icon,
      iconName: iconName ?? this.iconName,
      description: description ?? this.description,
      allowsCustomPrice: allowsCustomPrice ?? this.allowsCustomPrice,
      isActive: isActive ?? this.isActive,
    );
  }

  static IconData resolveIcon(String? name) {
    switch (name?.toLowerCase()) {
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'fire':
      case 'confirmation':
        return Icons.local_fire_department_outlined;
      case 'communion':
      case 'bread':
        return Icons.restaurant_outlined;
      case 'heart':
      case 'marriage':
        return Icons.favorite_border;
      case 'funeral':
      case 'coffin':
        return Icons.church_outlined;
      case 'celebration':
        return Icons.celebration_outlined;
      case 'soul':
      case 'person':
        return Icons.person_outline;
      case 'prayer':
      case 'petition':
        return Icons.volunteer_activism_outlined;
      case 'certificate':
      case 'badge':
        return Icons.badge_outlined;
      case 'verified':
        return Icons.verified_outlined;
      case 'contract':
        return Icons.card_membership_outlined;
      case 'candle':
      case 'lamp':
        return Icons.light_mode_outlined;
      case 'flower':
        return Icons.yard_outlined;
      case 'donation':
        return Icons.favorite;
      case 'receipt':
        return Icons.receipt_long_outlined;
      default:
        return Icons.church_outlined;
    }
  }

  factory PosItemModel.fromMap(Map<String, dynamic> map) {
    final iconStr = map['icon_name']?.toString() ?? 'church';
    return PosItemModel(
      id: map['particular_id']?.toString() ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Offering',
      category: map['category']?.toString() ?? 'Sacraments',
      defaultPrice: double.tryParse(map['default_price']?.toString() ?? '0') ?? 0.0,
      icon: resolveIcon(iconStr),
      iconName: iconStr,
      description: map['description']?.toString() ?? '',
      allowsCustomPrice: map['allows_custom_price'] == true,
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'particular_id': id,
      'title': title.trim(),
      'category': category.trim(),
      'default_price': defaultPrice,
      'icon_name': iconName,
      'description': description.trim(),
      'allows_custom_price': allowsCustomPrice,
      'is_active': isActive,
    };
  }

  /// Initial Canonical Catalog defaults used for seeding database
  static const List<PosItemModel> initialDefaults = [
    // Sacraments
    PosItemModel(
      id: 'sac_baptism',
      title: 'Baptism',
      category: 'Sacraments',
      defaultPrice: 300.0,
      icon: Icons.water_drop_outlined,
      iconName: 'water_drop',
      description: 'Community or individual baptism registration stipend',
    ),
    PosItemModel(
      id: 'sac_confirmation',
      title: 'Confirmation',
      category: 'Sacraments',
      defaultPrice: 300.0,
      icon: Icons.local_fire_department_outlined,
      iconName: 'fire',
      description: 'Canonical confirmation rite registration',
    ),
    PosItemModel(
      id: 'sac_first_communion',
      title: 'First Communion',
      category: 'Sacraments',
      defaultPrice: 300.0,
      icon: Icons.restaurant_outlined,
      iconName: 'communion',
      description: 'First Holy Communion parish registry fee',
    ),
    PosItemModel(
      id: 'sac_marriage',
      title: 'Nuptial Mass (Marriage)',
      category: 'Sacraments',
      defaultPrice: 1000.0,
      icon: Icons.favorite_border,
      iconName: 'heart',
      description: 'Wedding ceremony and canonical banns processing',
    ),
    PosItemModel(
      id: 'sac_funeral',
      title: 'Funeral / Memorial Mass',
      category: 'Sacraments',
      defaultPrice: 500.0,
      icon: Icons.church_outlined,
      iconName: 'funeral',
      description: 'Funeral rite or cemetery blessing stipend',
    ),

    // Mass Intentions
    PosItemModel(
      id: 'mass_thanksgiving',
      title: 'Thanksgiving Mass Intention',
      category: 'Mass Intentions',
      defaultPrice: 100.0,
      icon: Icons.celebration_outlined,
      iconName: 'celebration',
      description: 'Pasasalamat for birthdays, healing, and blessings',
    ),
    PosItemModel(
      id: 'mass_repose_souls',
      title: 'Repose of the Soul Intention',
      category: 'Mass Intentions',
      defaultPrice: 100.0,
      icon: Icons.person_outline,
      iconName: 'soul',
      description: 'Para sa kaluluwa / departed faithful loved ones',
    ),
    PosItemModel(
      id: 'mass_special_petition',
      title: 'Special Petitions / Intentions',
      category: 'Mass Intentions',
      defaultPrice: 100.0,
      icon: Icons.volunteer_activism_outlined,
      iconName: 'petition',
      description: 'Board exams, safe travels, recovery from illness',
    ),

    // Certificates / Pabuklat
    PosItemModel(
      id: 'cert_baptismal',
      title: 'Baptismal Certificate (Pabuklat)',
      category: 'Certificates',
      defaultPrice: 150.0,
      icon: Icons.badge_outlined,
      iconName: 'certificate',
      description: 'Official verified baptism certificate issuance',
    ),
    PosItemModel(
      id: 'cert_confirmation',
      title: 'Confirmation Certificate',
      category: 'Certificates',
      defaultPrice: 150.0,
      icon: Icons.verified_outlined,
      iconName: 'verified',
      description: 'Official sacrament of confirmation certificate',
    ),
    PosItemModel(
      id: 'cert_marriage',
      title: 'Marriage Certificate',
      category: 'Certificates',
      defaultPrice: 200.0,
      icon: Icons.card_membership_outlined,
      iconName: 'contract',
      description: 'Official parish canonical marriage contract copy',
    ),

    // Devotionals & Parish Offerings
    PosItemModel(
      id: 'dev_sanctuary_lamp',
      title: 'Sanctuary Lamp Offering',
      category: 'Devotionals',
      defaultPrice: 150.0,
      icon: Icons.light_mode_outlined,
      iconName: 'lamp',
      description: 'Tabernacle candle offering intention for 1 week',
    ),
    PosItemModel(
      id: 'dev_altar_flowers',
      title: 'Altar Flowers Donation',
      category: 'Devotionals',
      defaultPrice: 250.0,
      icon: Icons.yard_outlined,
      iconName: 'flower',
      description: 'Contribution toward altar flower decorations',
    ),
    PosItemModel(
      id: 'dev_general_donation',
      title: 'General Parish Donation',
      category: 'Devotionals',
      defaultPrice: 50.0,
      icon: Icons.favorite,
      iconName: 'donation',
      description: 'Discretionary church donation or tithe',
      allowsCustomPrice: true,
    ),
  ];
}

class PosCartItem {
  final PosItemModel item;
  int quantity;
  double customPrice;
  String? remarks;

  PosCartItem({
    required this.item,
    this.quantity = 1,
    double? customPrice,
    this.remarks,
  }) : customPrice = customPrice ?? item.defaultPrice;

  double get total => customPrice * quantity;
}