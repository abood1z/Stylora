class DummyData {
  DummyData._();

  static const List<Map<String, dynamic>> dailyLooks = [
    {
      'id': '1',
      'title': 'Casual Friday',
      'imageUrl': 'https://images.unsplash.com/photo-1488161628813-04466f872be2?w=500',
      'matchScore': 95,
    },
    {
      'id': '2',
      'title': 'Office Setup',
      'imageUrl': 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=500',
      'matchScore': 88,
    },
    {
      'id': '3',
      'title': 'Weekend Vibe',
      'imageUrl': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=500',
      'matchScore': 92,
    },
  ];

  static const List<Map<String, dynamic>> wardrobeItems = [
    {
      'id': 'w1',
      'category': 'Tops',
      'type': 'T-Shirt',
      'color': 'White',
      'season': 'summer',
      'imageUrl': 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500',
    },
    {
      'id': 'w2',
      'category': 'Bottoms',
      'type': 'Jeans',
      'color': 'Blue',
      'season': 'winter',
      'imageUrl': 'https://images.unsplash.com/photo-1542272604-780c9685006b?w=500',
    },
    {
      'id': 'w3',
      'category': 'Outerwear',
      'type': 'Jacket',
      'color': 'Black',
      'season': 'winter',
      'imageUrl': 'https://images.unsplash.com/photo-1551028719-01c1eb562251?w=500',
    },
    {
      'id': 'w4',
      'category': 'Shoes',
      'type': 'Sneakers',
      'color': 'White',
      'season': 'summer',
      'imageUrl': 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=500',
    },
  ];

  static const List<Map<String, dynamic>> shopStores = [
    {
      'id': 's1',
      'name': 'Urban Outfitters',
      'logoUrl': 'https://images.unsplash.com/photo-1542282088-fe8426682b8f?w=200',
      'products': [
        {
          'id': 'p1',
          'name': 'Classic Denim Jacket',
          'brand': 'Levi\'s',
          'price': 89.99,
          'imageUrl': 'https://images.unsplash.com/photo-1576871337622-98d48d1cf531?w=500',
          'matchReason': 'Matches your white t-shirt',
          'category': 'Jacket',
          'color': 'blue',
          'season': 'winter',
        },
        {
          'id': 'p2',
          'name': 'Vintage Graphic Tee',
          'brand': 'Urban Outfitters',
          'price': 34.99,
          'imageUrl': 'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=500',
          'matchReason': 'Great with your blue jeans',
          'category': 'Tee',
          'color': 'grey',
          'season': 'summer',
        },
      ]
    },
    {
      'id': 's2',
      'name': 'Zara',
      'logoUrl': 'https://images.unsplash.com/photo-1582041148888-59afcbdd7b43?w=200',
      'products': [
        {
          'id': 'p3',
          'name': 'Chino Pants',
          'brand': 'Zara',
          'price': 49.99,
          'imageUrl': 'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=500',
          'matchReason': 'Alternative to your blue jeans',
          'category': 'Chinos',
          'color': 'brown',
          'season': 'summer',
        },
        {
          'id': 'p4',
          'name': 'Oxford Shirt',
          'brand': 'Zara',
          'price': 59.99,
          'imageUrl': 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?w=500',
          'matchReason': 'Formal match for your chinos',
          'category': 'Top',
          'color': 'white',
          'season': 'summer',
        },
      ]
    },
    {
      'id': 's3',
      'name': 'Nike',
      'logoUrl': 'https://images.unsplash.com/photo-1620018591321-df5f375f4eb7?w=200',
      'products': [
        {
          'id': 'p5',
          'name': 'Minimalist Sneakers',
          'brand': 'Nike',
          'price': 120.00,
          'imageUrl': 'https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?w=500',
          'matchReason': 'Completes your casual look',
          'category': 'Others',
          'color': 'white',
          'season': 'summer',
        },
        {
          'id': 'p6',
          'name': 'Sport Hoodie',
          'brand': 'Nike',
          'price': 75.00,
          'imageUrl': 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=500',
          'matchReason': 'Matches your black sweatpants',
          'category': 'Hoodie',
          'color': 'black',
          'season': 'winter',
        },
      ]
    },
  ];
}
