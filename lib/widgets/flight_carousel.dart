import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight_info.dart';

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
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: Text("尚無航班資訊", style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        final flights = snapshot.data!.docs
            .map((doc) => FlightInfo.fromFirestore(doc))
            .toList();

        return SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: flights.length,
            controller: PageController(viewportFraction: 0.9),
            itemBuilder: (context, index) {
              final flight = flights[index];
              return Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STARLUX • ${flight.flightNo}',
                        style: const TextStyle(
                          color: Color(0xFFD4C5A9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _airportBlock(flight.fromCode, flight.schedDep),
                          const Icon(
                            Icons.flight_takeoff,
                            color: Colors.white54,
                          ),
                          _airportBlock(flight.toCode, flight.schedArr),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Status: ${flight.status}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _airportBlock(String code, String time) {
    return Column(
      children: [
        Text(
          code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(time, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
