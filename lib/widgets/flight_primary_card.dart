import 'package:flutter/material.dart';
import '../models/flight_status.dart';

class FlightPrimaryCard extends StatelessWidget {
  final FlightStatus flight;
  const FlightPrimaryCard({super.key, required this.flight});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: const Icon(Icons.flight_takeoff),
        title: Text('航班 ${flight.flightNo}'),
        subtitle: Text('${flight.from} -> ${flight.to}'),
        trailing: Text(flight.status),
      ),
    );
  }
}
