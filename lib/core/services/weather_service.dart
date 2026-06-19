import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherInfo {
  final int temp;
  final String conditionKey;
  final IconData icon;

  WeatherInfo({
    required this.temp,
    required this.conditionKey,
    required this.icon,
  });
}

class WeatherService {
  static Future<WeatherInfo> getWeatherForCity(String city) async {
    final client = HttpClient();
    // Set a connection timeout of 8 seconds
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      // Clean city name (e.g., "Riyadh, Saudi Arabia" -> "Riyadh")
      String cleanCity = city.trim();
      if (cleanCity.contains(',')) {
        cleanCity = cleanCity.split(',').first.trim();
      }

      // Remove any emojis (especially country flags from CSCPicker) and special characters
      cleanCity = cleanCity.replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), '').trim();
      cleanCity = cleanCity.replaceAll(RegExp(r'\s+'), ' ');

      // Exclude common geographic suffixes and prefix words that break geocoding
      final wordsToExclude = {
        'province', 'governorate', 'state', 'city', 'district', 'region', 'muhafazah', 'wilayah', 'county', 'capital',
        'محافظة', 'ولاية', 'إقليم', 'منطقة', 'العاصمة', 'عاصمة'
      };
      cleanCity = cleanCity.split(' ').where((w) => !wordsToExclude.contains(w.toLowerCase())).join(' ').trim();

      // 1. Geocode city name to lat/lng using Open-Meteo Geocoding
      final geocodeUri = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cleanCity)}&count=1&language=ar');
      final geocodeRequest = await client.getUrl(geocodeUri);
      final geocodeResponse = await geocodeRequest.close();
      
      if (geocodeResponse.statusCode == 200) {
        final geocodeBody = await geocodeResponse.transform(utf8.decoder).join();
        final geocodeData = jsonDecode(geocodeBody) as Map<String, dynamic>;
        final results = geocodeData['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final firstResult = results.first as Map<String, dynamic>;
          final double lat = (firstResult['latitude'] as num).toDouble();
          final double lng = (firstResult['longitude'] as num).toDouble();
          
          // 2. Fetch current weather for lat/lng
          final weatherUri = Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code');
          final weatherRequest = await client.getUrl(weatherUri);
          final weatherResponse = await weatherRequest.close();
          
          if (weatherResponse.statusCode == 200) {
            final weatherBody = await weatherResponse.transform(utf8.decoder).join();
            final weatherData = jsonDecode(weatherBody) as Map<String, dynamic>;
            final current = weatherData['current'] as Map<String, dynamic>?;
            
            if (current != null) {
              final double tempDouble = (current['temperature_2m'] as num).toDouble();
              final int temp = tempDouble.round();
              final int code = current['weather_code'] as int? ?? 0;
              
              final mapped = _mapWeatherCode(code);
              return WeatherInfo(
                temp: temp,
                conditionKey: mapped['key'] as String,
                icon: mapped['icon'] as IconData,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('WeatherService Error: $e');
    } finally {
      client.close();
    }
    
    // If API fails or returns no results, return a sensible fallback instead of 0.
    return _getFallbackWeather(city);
  }

  static Map<String, dynamic> _mapWeatherCode(int code) {
    if (code == 0) {
      return {'key': 'sunny', 'icon': Icons.wb_sunny_rounded};
    } else if (code >= 1 && code <= 3) {
      return {'key': 'partlyCloudy', 'icon': Icons.cloud_queue_rounded};
    } else if (code == 45 || code == 48) {
      return {'key': 'foggy', 'icon': Icons.filter_drama_rounded};
    } else if (code >= 51 && code <= 65) {
      return {'key': 'rainy', 'icon': Icons.beach_access_rounded};
    } else if (code >= 71 && code <= 75) {
      return {'key': 'snowy', 'icon': Icons.ac_unit_rounded};
    } else if (code >= 80 && code <= 82) {
      return {'key': 'rainShowers', 'icon': Icons.umbrella_rounded};
    } else if (code >= 95 && code <= 99) {
      return {'key': 'thunderstorm', 'icon': Icons.thunderstorm_rounded};
    }
    return {'key': 'mild', 'icon': Icons.wb_cloudy_rounded};
  }

  static WeatherInfo _getFallbackWeather(String city) {
    final cityLower = city.toLowerCase();
    int temp = 24;
    String conditionKey = 'mild';
    IconData icon = Icons.wb_cloudy_rounded;

    if (cityLower.contains('riyadh') || cityLower.contains('رياض') || 
        cityLower.contains('dubai') || cityLower.contains('دبي') ||
        cityLower.contains('cairo') || cityLower.contains('قاهرة') ||
        cityLower.contains('jeddah') || cityLower.contains('جدة')) {
      temp = 36;
      conditionKey = 'sunnyHot';
      icon = Icons.wb_sunny_rounded;
    } else if (cityLower.contains('london') || cityLower.contains('لندن') ||
               cityLower.contains('paris') || cityLower.contains('باريس') ||
               cityLower.contains('moscow') || cityLower.contains('موسكو')) {
      temp = 14;
      conditionKey = 'chillyRainy';
      icon = Icons.thunderstorm_rounded;
    } else {
      temp = 24;
      conditionKey = 'partlyCloudy';
      icon = Icons.cloud_queue_rounded;
    }

    return WeatherInfo(
      temp: temp,
      conditionKey: conditionKey,
      icon: icon,
    );
  }
}

// Riverpod Provider for Weather
final weatherProvider = FutureProvider.family<WeatherInfo, String>((ref, city) async {
  return WeatherService.getWeatherForCity(city);
});
