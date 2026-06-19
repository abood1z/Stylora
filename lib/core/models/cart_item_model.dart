class CartItemModel {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final String storeID;
  final String storeName;
  int quantity;

  CartItemModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.storeID,
    required this.storeName,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'storeID': storeID,
      'storeName': storeName,
      'quantity': quantity,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      storeID: map['storeID'] ?? '',
      storeName: map['storeName'] ?? '',
      quantity: map['quantity']?.toInt() ?? 1,
    );
  }
}
