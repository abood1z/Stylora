class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://api.dummyoutfitstylist.com'; // Dummy
  static const String login = '$baseUrl/v1/auth/login';
  static const String signup = '$baseUrl/v1/auth/signup';
  static const String analyzeImage = '$baseUrl/v1/ai/analyze-garment';
  static const String getOutfits = '$baseUrl/v1/outfits/suggest';
  static const String shopProducts = '$baseUrl/v1/shop/products';
}
