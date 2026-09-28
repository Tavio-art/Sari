
class ProductCategories {
  static const List<String> all = [
    'All',
    'Beverages',
    'Coffee & Tea',
    'Snacks',
    'Noodles',
    'Canned Goods',
    'Condiments',
    'Personal Care',
    'Household',
  ];

  static List<String> get forPicker =>
      all.where((c) => c != 'All').toList(growable: false);
}
