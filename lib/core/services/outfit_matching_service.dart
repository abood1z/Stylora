import '../../core/models/closet_item_model.dart';

class OutfitMatchingService {
  // مصفوفة توافق الفئات (ماذا يرتدي المستخدم مع ماذا؟)
  static const Map<String, List<String>> _categoryMatchingMap = {
    'Blazer': ['Chinos', 'Jeans', 'Pants', 'Skirt'],
    'Blouse': ['Capris', 'Chinos', 'Culottes', 'Jeans', 'Pants', 'Shorts', 'Skirt'],
    'Capris': ['Blouse', 'Cardigan', 'Crop', 'Halter', 'Henley', 'Tank', 'Tee', 'Top'],
    'Cardigan': ['Capris', 'Chinos', 'Jeans', 'Leggings', 'Pants', 'Skirt'],
    'Chinos': ['Blazer', 'Blouse', 'Cardigan', 'Coat', 'Henley', 'Jacket', 'Sweater', 'Tee', 'Top', 'Turtleneck'],
    'Coat': ['Chinos', 'Jeans', 'Joggers', 'Leggings', 'Pants', 'Skirt'],
    'Crop': ['Capris', 'Cutoffs', 'Jeans', 'Joggers', 'Leggings', 'Shorts', 'Skirt'],
    'Culottes': ['Blouse', 'Crop', 'Halter', 'Tank', 'Tee', 'Top'],
    'Cutoffs': ['Crop', 'Halter', 'Henley', 'Hoodie', 'Tank', 'Tee'],
    'Dress': ['Cardigan', 'Coat', 'Jacket', 'Kimono'],
    'Halter': ['Capris', 'Culottes', 'Cutoffs', 'Jeans', 'Shorts', 'Skirt'],
    'Henley': ['Capris', 'Chinos', 'Cutoffs', 'Jeans', 'Joggers', 'Pants', 'Shorts'],
    'Hoodie': ['Cutoffs', 'Jeans', 'Joggers', 'Leggings', 'Pants', 'Shorts'],
    'Jacket': ['Chinos', 'Jeans', 'Joggers', 'Pants', 'Skirt'],
    'Jeans': ['Blazer', 'Blouse', 'Cardigan', 'Coat', 'Crop', 'Halter', 'Henley', 'Hoodie', 'Jacket', 'Jersey', 'Sweater', 'Tank', 'Tee', 'Top', 'Turtleneck'],
    'Jersey': ['Jeans', 'Joggers', 'Shorts', 'Trunks'],
    'Joggers': ['Crop', 'Henley', 'Hoodie', 'Jacket', 'Jersey', 'Sweater', 'Tee'],
    'Jumpsuit': ['Cardigan', 'Coat', 'Jacket', 'Kimono'],
    'Kimono': ['Dress', 'Jeans', 'Jumpsuit', 'Romper', 'Shorts'],
    'Leggings': ['Cardigan', 'Coat', 'Crop', 'Hoodie', 'Sweater', 'Tee', 'Top'],
    'Others': ['Others'],
    'Pants': ['Blazer', 'Blouse', 'Cardigan', 'Coat', 'Henley', 'Hoodie', 'Jacket', 'Sweater', 'Tee', 'Top', 'Turtleneck'],
    'Parka': ['Jeans', 'Joggers', 'Pants'],
    'Poncho': ['Jeans', 'Leggings', 'Pants'],
    'Romper': ['Cardigan', 'Jacket', 'Kimono'],
    'Shorts': ['Blouse', 'Crop', 'Halter', 'Henley', 'Hoodie', 'Jersey', 'Tank', 'Tee', 'Top'],
    'Skirt': ['Blazer', 'Blouse', 'Cardigan', 'Coat', 'Crop', 'Halter', 'Jacket', 'Sweater', 'Tank', 'Tee', 'Top'],
    'Sweater': ['Chinos', 'Jeans', 'Joggers', 'Leggings', 'Pants', 'Skirt'],
    'Tank': ['Capris', 'Culottes', 'Cutoffs', 'Jeans', 'Shorts', 'Skirt'],
    'Tee': ['Capris', 'Chinos', 'Culottes', 'Cutoffs', 'Jeans', 'Joggers', 'Leggings', 'Pants', 'Shorts', 'Skirt', 'Trunks'],
    'Top': ['Capris', 'Chinos', 'Culottes', 'Jeans', 'Leggings', 'Pants', 'Shorts', 'Skirt'],
    'Trunks': ['Jersey', 'Tee', 'Tank'],
    'Turtleneck': ['Chinos', 'Jeans', 'Pants', 'Skirt'],
  };

  // مصفوفة توافق الألوان الأساسية
  static const Map<String, List<String>> _colorMatchingMap = {
    'black': ['white', 'grey', 'red', 'blue', 'yellow', 'brown', 'beige', 'silver'],
    'white': ['black', 'blue', 'navy', 'green', 'red', 'grey', 'pink', 'orange'],
    'grey': ['black', 'white', 'navy', 'pink', 'blue', 'red'],
    'blue': ['white', 'black', 'grey', 'beige', 'brown', 'orange'],
    'navy': ['white', 'grey', 'beige', 'red', 'yellow'],
    'red': ['white', 'black', 'grey', 'navy', 'blue'],
    'green': ['white', 'black', 'beige', 'brown', 'grey'],
    'yellow': ['black', 'navy', 'grey', 'white', 'purple'],
    'brown': ['beige', 'white', 'black', 'green', 'navy'],
    'beige': ['navy', 'brown', 'black', 'white', 'green', 'blue'],
    'pink': ['white', 'grey', 'navy', 'black'],
    'purple': ['white', 'grey', 'black', 'yellow'],
    'orange': ['white', 'black', 'blue', 'navy'],
    'silver': ['black', 'white', 'grey', 'navy'],
  };

  /// دالة لاقتراح قطع من الخزانة تتناسب مع القطعة الجديدة
  static List<ClosetItemModel> getMatches({
    required ClosetItemModel newItem,
    required List<ClosetItemModel> userCloset,
  }) {
    List<ClosetItemModel> matches = [];

    // 1. الحصول على الفئات التي تناسب القطعة الجديدة
    final compatibleCategories = _categoryMatchingMap[newItem.category] ?? [];
    
    // 2. الحصول على الألوان التي تناسب لون القطعة الجديدة
    final compatibleColors = _colorMatchingMap[newItem.color.toLowerCase()] ?? [];

    // 3. فلترة الخزانة بناءً على التوافق
    for (var item in userCloset) {
      bool isCompatibleCategory = compatibleCategories.contains(item.category);
      bool isCompatibleColor = compatibleColors.contains(item.color.toLowerCase());

      // إذا كانت الفئة متوافقة واللون متوافق، أضفها للاقتراحات
      if (isCompatibleCategory && isCompatibleColor) {
        matches.add(item);
      }
    }

    // ترتيب العشوائي قليلاً ليعطي تنوعاً كل مرة أو حسب الأحدث
    matches.shuffle();
    
    // إرجاع أفضل 10 اقتراحات فقط لعدم إزعاج المستخدم
    return matches.take(10).toList();
  }
}
