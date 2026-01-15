import 'package:cloud_firestore/cloud_firestore.dart';

class FlightInfo {
  String id;
  String flightNo;
  String fromCode;
  String toCode;
  String date;
  String schedDep;
  String schedArr;
  String estDep;
  String estArr;
  String terminal;
  String gate;
  String counter;
  String baggage;
  String status;
  int delay;

  FlightInfo({
    required this.id,
    required this.flightNo,
    required this.fromCode,
    required this.toCode,
    required this.date,
    required this.schedDep,
    required this.schedArr,
    this.estDep = '',
    this.estArr = '',
    required this.terminal,
    required this.gate,
    required this.counter,
    required this.baggage,
    required this.status,
    this.delay = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'flightNo': flightNo,
      'fromCode': fromCode,
      'toCode': toCode,
      'date': date,
      'schedDep': schedDep,
      'schedArr': schedArr,
      'estDep': estDep,
      'estArr': estArr,
      'terminal': terminal,
      'gate': gate,
      'counter': counter,
      'baggage': baggage,
      'status': status,
      'delay': delay,
    };
  }

  factory FlightInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlightInfo(
      id: doc.id,
      flightNo: data['flightNo'] ?? '',
      fromCode: data['fromCode'] ?? '',
      toCode: data['toCode'] ?? '',
      date: data['date'] ?? '',
      schedDep: data['schedDep'] ?? '',
      schedArr: data['schedArr'] ?? '',
      estDep: data['estDep'] ?? '',
      estArr: data['estArr'] ?? '',
      terminal: data['terminal'] ?? '-',
      gate: data['gate'] ?? '-',
      counter: data['counter'] ?? '-',
      baggage: data['baggage'] ?? '-',
      status: data['status'] ?? 'scheduled',
      delay: (data['delay'] ?? 0).toInt(),
    );
  }
}
