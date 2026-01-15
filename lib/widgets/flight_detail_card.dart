import 'package:flutter/material.dart';
import '../models/flight_status.dart';
import 'package:intl/intl.dart';

class FlightDetailCard extends StatelessWidget {
  final FlightStatus flight;

  const FlightDetailCard({super.key, required this.flight});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('航班歷程', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            _infoRow(
              label: '原定起飛',
              value: timeFormat.format(flight.scheduledDeparture),
            ),

            for (final event in flight.events)
              if (event.type == FlightEventType.delay)
                _infoRow(
                  label: '延誤',
                  value: '${event.durationMinutes} 分鐘',
                  highlight: true,
                ),

            _infoRow(
              label: '原定抵達',
              value: timeFormat.format(flight.scheduledArrival),
            ),

            if (flight.actualArrival != null)
              _infoRow(
                label: '實際抵達',
                value: timeFormat.format(flight.actualArrival!),
                bold: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool highlight = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.orange : null,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
