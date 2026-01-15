import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight_info.dart';
import '../services/flight_api_service.dart';

class FlightCarousel extends StatelessWidget {
  const FlightCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('flights')
          .snapshots(),
      builder: (ctx, snapshot) {
        final List<FlightInfo> flights = [];
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            flights.add(FlightInfo.fromFirestore(doc));
          }
        }

        return SizedBox(
          height: 190,
          child: PageView.builder(
            itemCount: flights.length + 1,
            controller: PageController(viewportFraction: 0.92),
            itemBuilder: (ctx, index) {
              if (index == flights.length) {
                return _buildAddCard(context);
              }
              final flight = flights[index];
              return GestureDetector(
                onTap: () => _showFlightDetails(context, flight),
                onLongPress: () => _syncFlight(context, uid, flight),
                child: _buildStarluxCard(flight),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStarluxCard(FlightInfo info) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STARLUX • ${info.flightNo}',
                style: const TextStyle(
                  color: Color(0xFFD4C5A9),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  info.status,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _airportBlock(info.fromCode, info.schedDep),
              const Icon(Icons.flight_takeoff, color: Colors.white54, size: 28),
              _airportBlock(info.toCode, info.schedArr),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _smallInfo("Gate", info.gate),
              _smallInfo("Terminal", info.terminal),
              _smallInfo("Baggage", info.baggage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _airportBlock(String code, String time) {
    return Column(
      children: [
        Text(
          code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _smallInfo(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: const Center(
        child: Icon(Icons.add_circle_outline, size: 40, color: Colors.white),
      ),
    );
  }

  void _showFlightDetails(BuildContext context, FlightInfo flight) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${flight.flightNo} 航班詳情",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _detailRow(
              "預計/實際起飛",
              flight.estDep.isEmpty ? "依表定" : flight.estDep,
            ),
            _detailRow(
              "預計/實際抵達",
              flight.estArr.isEmpty ? "依表定" : flight.estArr,
            ),
            _detailRow("報到櫃檯", flight.counter),
            _detailRow("延誤時間", "${flight.delay} 分鐘"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Future<void> _syncFlight(
    BuildContext context,
    String uid,
    FlightInfo flight,
  ) async {
    final info = await FlightApiService.fetchApiData(flight.flightNo);
    if (!context.mounted) return;
    if (info != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('flights')
          .doc(flight.id)
          .update(info.toMap());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("航班資訊已同步")));
    }
  }
}
