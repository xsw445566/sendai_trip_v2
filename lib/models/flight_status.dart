// 直接刪除第一行的 import 'package:flutter/material.dart';

enum FlightEventType { delay, gateChange, statusChange }

class FlightEvent {
  final FlightEventType type;
  final String title;
  final String description;
  final int? durationMinutes;

  FlightEvent({
    required this.type,
    required this.title,
    this.description = '',
    this.durationMinutes,
  });
}

class FlightStatus {
  final String flightNo;
  final String from;
  final String to;
  final DateTime scheduledDeparture;
  final DateTime scheduledArrival;
  final DateTime? actualArrival;
  final String status;
  final List<FlightEvent> events;

  FlightStatus({
    required this.flightNo,
    required this.from,
    required this.to,
    required this.scheduledDeparture,
    required this.scheduledArrival,
    this.actualArrival,
    required this.status,
    required this.events,
  });
}
