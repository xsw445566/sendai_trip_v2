import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flight_info.dart';
import '../config/api_keys.dart';

class FlightApiService {
  static Future<FlightInfo?> fetchApiData(String flightNo) async {
    final trimmedNo = flightNo.trim();
    if (trimmedNo.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules?flight_iata=$trimmedNo&api_key=$flightApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final jsonResponse = json.decode(response.body);
      final list = jsonResponse['response'];
      if (list == null || list is! List || list.isEmpty) return null;

      final data = list.first as Map<String, dynamic>;

      String fmt(String? t) {
        if (t == null || t.length < 16) return "";
        return t.substring(11, 16);
      }

      final depTimeStr = data['dep_time'] as String?;
      final arrTimeStr = data['arr_time'] as String?;

      return FlightInfo(
        id: '',
        flightNo: (data['flight_iata'] ?? trimmedNo) as String,
        fromCode: (data['dep_iata'] ?? '') as String,
        toCode: (data['arr_iata'] ?? '') as String,
        date: depTimeStr != null && depTimeStr.length >= 10
            ? depTimeStr.substring(5, 10)
            : '',
        schedDep: fmt(depTimeStr),
        schedArr: fmt(arrTimeStr),
        estDep: fmt((data['dep_actual'] ?? data['dep_estimated']) as String?),
        estArr: fmt((data['arr_actual'] ?? data['arr_estimated']) as String?),
        terminal: (data['dep_terminal'] ?? '-') as String,
        gate: (data['dep_gate'] ?? '-') as String,
        counter: '-',
        baggage: (data['arr_baggage'] ?? '-') as String,
        status: (data['status'] ?? 'scheduled') as String,
        delay: (data['dep_delayed'] is num)
            ? (data['dep_delayed'] as num).toInt()
            : 0,
      );
    } catch (e) {
      print("Flight API error: $e");
      return null;
    }
  }
}
