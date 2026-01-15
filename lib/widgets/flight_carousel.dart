import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight_info.dart';
import '../services/flight_api_service.dart';

class FlightCarousel extends StatelessWidget {
  const FlightCarousel({super.key});

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'landed':
        return '已抵達';
      case 'active':
        return '飛行中';
      case 'scheduled':
        return '預定中';
      case 'cancelled':
        return '已取消';
      case 'saved':
        return '已儲存';
      case 'started':
        return '已起飛';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'landed':
        return Colors.greenAccent;
      case 'active':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return const Color(0xFFD4C5A9);
    }
  }

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
          height: 200, // 稍微增加高度以容納延誤資訊
          child: PageView.builder(
            itemCount: flights.length + 1,
            controller: PageController(viewportFraction: 0.92),
            itemBuilder: (ctx, index) {
              if (index == flights.length) return _buildAddCard(context);
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
    final bool isDelayed = info.delay > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  // 延誤標籤：僅在延誤時顯示
                  if (isDelayed)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '延誤 ${info.delay}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(info.status).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _translateStatus(info.status),
                      style: TextStyle(
                        color: _getStatusColor(info.status),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _airportBlock(
                info.fromCode,
                info.schedDep,
                actualTime: isDelayed ? info.estDep : null,
              ),
              const Icon(Icons.flight_takeoff, color: Colors.white24, size: 24),
              _airportBlock(
                info.toCode,
                info.schedArr,
                actualTime: isDelayed ? info.estArr : null,
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _smallInfo("登機門", info.gate),
              _smallInfo("航廈", info.terminal),
              _smallInfo("行李轉盤", info.baggage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _airportBlock(String code, String schedTime, {String? actualTime}) {
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
        if (actualTime != null && actualTime.isNotEmpty)
          Text(
            actualTime,
            style: const TextStyle(
              color: Colors.orangeAccent, // 延誤時顯示顯眼的橘色
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Text(
            schedTime,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
      ],
    );
  }

  Widget _smallInfo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        Text(
          val.isEmpty || val == "-" ? "待定" : val,
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
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: const Center(
        child: Icon(Icons.add_circle_outline, size: 40, color: Colors.white54),
      ),
    );
  }

  void _showFlightDetails(BuildContext context, FlightInfo flight) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
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
              "預計起飛",
              flight.estDep.isEmpty ? flight.schedDep : flight.estDep,
            ),
            _detailRow(
              "預計抵達",
              flight.estArr.isEmpty ? flight.schedArr : flight.estArr,
            ),
            _detailRow("延誤時間", flight.delay > 0 ? "${flight.delay} 分鐘" : "準點"),
            _detailRow("報到櫃檯", flight.counter),
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
