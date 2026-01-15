import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/weather.dart';
import 'location_service.dart';
import 'package:geolocator/geolocator.dart';

class WeatherService {
  // 自動 GPS
  static Future<Weather?> fetchWeatherByLocation() async {
    try {
      Position pos = await LocationService.getCurrentPosition();
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$weatherApiKey&units=metric&lang=zh_tw';
      final res = await http.get(Uri.parse(url));
      return res.statusCode == 200
          ? Weather.fromJson(json.decode(res.body))
          : null;
    } catch (e) {
      return null;
    }
  }

  // 手動輸入城市
  static Future<Weather?> fetchWeatherByCity(String city) async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$weatherApiKey&units=metric&lang=zh_tw';
      final res = await http.get(Uri.parse(url));
      return res.statusCode == 200
          ? Weather.fromJson(json.decode(res.body))
          : null;
    } catch (e) {
      return null;
    }
  }
}
