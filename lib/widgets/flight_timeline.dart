import 'package:flutter/material.dart';
import '../models/flight_status.dart';
import 'package:intl/intl.dart';

class FlightTimeline extends StatelessWidget {
  final FlightStatus flight;

  const FlightTimeline({super.key, required this.flight});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Column(
      children: [
        _timelineItem(
          time: timeFormat.format(flight.scheduledDeparture),
          title: '原定搭機 ${flight.flightNo}',
        ),

        for (final event in flight.events)
          if (event.type == FlightEventType.delay)
            _eventItem('延誤 ${event.durationMinutes} 分鐘'),

        if (flight.actualArrival != null)
          _timelineItem(
            time: timeFormat.format(flight.actualArrival!),
            title: '抵達 ${flight.to}（實際）',
            highlight: true,
          ),
      ],
    );
  }

  Widget _timelineItem({
    required String time,
    required String title,
    bool highlight = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Column(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: highlight ? Colors.green : Colors.grey,
          ),
          Container(width: 2, height: 24, color: Colors.grey.shade300),
        ],
      ),
      title: Text(time),
      subtitle: Text(title),
    );
  }

  Widget _eventItem(String text) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: Text(text, style: const TextStyle(color: Colors.orange)),
    );
  }
}
