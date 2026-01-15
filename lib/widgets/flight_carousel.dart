import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flight_info.dart';
import '../services/flight_api_service.dart';

class FlightCarousel extends StatelessWidget {
  const FlightCarousel({super.key});

  // 1. 航班狀態中文化轉換
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

  // 狀態顏色對應
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'landed':
        return Colors.greenAccent;
      case 'active':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return const Color(0xFFD4C5A9); // 星宇金
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
          height: 195,
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

  // 星宇質感機票卡片
  Widget _buildStarluxCard(FlightInfo info) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(22),
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
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(info.status).withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(info.status).withAlpha(100),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _translateStatus(info.status),
                  style: TextStyle(
                    color: _getStatusColor(info.status),
                    fontSize: 11,
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
              const Icon(Icons.flight_takeoff, color: Colors.white24, size: 28),
              _airportBlock(info.toCode, info.schedArr),
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

  Widget _airportBlock(String code, String time) {
    return Column(
      children: [
        Text(
          code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 15)),
      ],
    );
  }

  Widget _smallInfo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          val.isEmpty || val == "-" ? "待定" : val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
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
        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 44, color: Colors.white60),
          SizedBox(height: 8),
          Text("新增航班", style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  // 點擊卡片彈出的詳細資訊
  void _showFlightDetails(BuildContext context, FlightInfo flight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "${flight.flightNo} 航班詳情",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Divider(),
            _detailRow(
              "預計/實際起飛",
              flight.estDep.isEmpty ? "依表定時間" : flight.estDep,
            ),
            _detailRow(
              "預計/實際抵達",
              flight.estArr.isEmpty ? "依表定時間" : flight.estArr,
            ),
            _detailRow(
              "報到櫃檯",
              flight.counter.isEmpty || flight.counter == "-"
                  ? "尚未公佈"
                  : flight.counter,
            ),
            _detailRow("狀態", _translateStatus(flight.status)),
            _detailRow(
              "延誤情形",
              flight.delay > 0 ? "延誤 ${flight.delay} 分鐘" : "準點",
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // 長按同步航班資訊
  Future<void> _syncFlight(
    BuildContext context,
    String uid,
    FlightInfo flight,
  ) async {
    // 顯示 Loading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("正在同步 ${flight.flightNo} 資訊...")));

    final info = await FlightApiService.fetchApiData(flight.flightNo);

    if (!context.mounted) return;

    if (info != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('flights')
          .doc(flight.id)
          .update(info.toMap());

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("航班資訊已更新至最新狀態")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("暫時無法取得最新資訊，請稍後再試")));
    }
  }
}
