import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../config/api_keys.dart';
import '../models/weather.dart';
import 'location_service.dart';

class WeatherService {
  static Future<Weather?> fetchWeatherByLocation() async {
    try {
      Position position = await LocationService.getCurrentPosition();

      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&appid=$weatherApiKey'
        '&units=metric'
        '&lang=zh_tw',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return Weather.fromJson(json.decode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('WeatherService error: $e');
      return null;
    }
  }
}
