import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity.dart';
import '../models/weather.dart';
import '../services/weather_service.dart';
import '../widgets/activity_card.dart';
import '../widgets/expandable_tools.dart';
import '../widgets/flight_carousel.dart';
import 'activity_detail_page.dart';

class ElegantItineraryPage extends StatefulWidget {
  final String uid;
  const ElegantItineraryPage({super.key, required this.uid});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  Weather? _gpsWeather;
  Weather? _customWeather;
  bool _isLoading = true;
  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;
  String _currentTime = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // 同時抓取 GPS 和 預設自訂城市 (仙台)
    final results = await Future.wait([
      WeatherService.fetchWeatherByLocation(),
      WeatherService.fetchWeatherByCity("Sendai"),
    ]);
    if (mounted) {
      setState(() {
        _gpsWeather = results[0];
        _customWeather = results[1];
        _isLoading = false;
      });
      _updateTime();
    }
  }

  void _updateTime() {
    if (!mounted) return;
    // 如果有自訂城市，依照該城市時區顯示時間，否則顯示系統時間
    DateTime now = DateTime.now().toUtc();
    if (_customWeather != null) {
      now = now.add(Duration(seconds: _customWeather!.timezone));
    } else {
      now = DateTime.now(); // 預設本地
    }

    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  void _changeCustomCity() {
    final TextEditingController cityC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("自訂區域天氣"),
        content: TextField(
          controller: cityC,
          decoration: const InputDecoration(hintText: "輸入城市名稱 (如: Tokyo)"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final w = await WeatherService.fetchWeatherByCity(cityC.text);
              if (w != null && mounted) {
                setState(() => _customWeather = w);
                _updateTime();
                Navigator.pop(ctx);
              }
            },
            child: const Text("切換"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildDualWeatherHeader(),
                const FlightCarousel(),
                const SizedBox(height: 10),
                _buildDaySelector(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 5,
                    onPageChanged: (i) => setState(() => _selectedDayIndex = i),
                    itemBuilder: (ctx, index) =>
                        DayItineraryWidget(dayIndex: index, uid: widget.uid),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ExpandableTools(uid: widget.uid),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://icrvb3jy.xinmedia.com/solomo/article/7/5/2/752e384b-d5f4-4d6e-b7ea-717d43c66cf2.jpeg',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.white.withAlpha(20),
                  const Color(0xFFF5F5F5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualWeatherHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：時間與 GPS 天氣
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                ),
              ),
              if (_gpsWeather != null)
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      "${_gpsWeather!.temperature.round()}° ${_gpsWeather!.cityName}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // 右側：自訂區域天氣
          GestureDetector(
            onTap: _changeCustomCity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "自訂區域",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (_customWeather != null) ...[
                  Text(
                    _customWeather!.cityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    "${_customWeather!.temperature.round()}° ${_customWeather!.description}",
                    style: const TextStyle(
                      color: Color(0xFFD4C5A9),
                      fontSize: 12,
                    ),
                  ),
                ] else
                  const Text(
                    "點擊設置",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        itemBuilder: (ctx, index) {
          final isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF9E8B6E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  'Day ${index + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DayItineraryWidget extends StatelessWidget {
  final int dayIndex;
  final String uid;
  const DayItineraryWidget({
    super.key,
    required this.dayIndex,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('activities')
              .where('dayIndex', isEqualTo: dayIndex)
              .snapshots(),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final activities = snapshot.data!.docs
                .map((doc) => Activity.fromFirestore(doc))
                .toList();
            activities.sort((a, b) => a.time.compareTo(b.time));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              itemCount: activities.length,
              itemBuilder: (ctx, index) =>
                  ActivityCard(activity: activities[index]),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 90,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF9E8B6E),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityDetailPage(
                    activity: Activity(
                      id: '',
                      time: '12:00',
                      title: '新行程',
                      dayIndex: dayIndex,
                    ),
                    onSave: (act) => FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('activities')
                        .add(act.toMap()),
                  ),
                ),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
