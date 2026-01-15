import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 移除未使用的 models/flight_info.dart 和 services/flight_api_service.dart
import '../models/activity.dart';
import '../models/weather.dart';
import '../services/migration_service.dart';
import '../services/weather_service.dart';
import '../widgets/activity_card.dart';
import '../widgets/expandable_tools.dart';
import '../widgets/flight_carousel.dart';

class ElegantItineraryPage extends StatefulWidget {
  final String uid;
  const ElegantItineraryPage({super.key, required this.uid});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  Weather? _weather;
  bool _isWeatherLoading = true;
  String? _weatherError; // 這個現在會在 UI 中被使用，警告會消失
  IconData _weatherIcon = Icons.cloud;

  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _loadWeather();
    runMigrationIfNeeded(widget.uid);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _loadWeather() async {
    final result = await WeatherService.fetchWeatherByLocation();
    if (!mounted) return;
    setState(() {
      _isWeatherLoading = false;
      if (result == null) {
        _weatherError = '無法取得天氣';
      } else {
        _weather = result;
        _weatherIcon = _mapWeatherIcon(result.icon);
      }
    });
  }

  IconData _mapWeatherIcon(String code) {
    if (code.contains('01')) return Icons.wb_sunny;
    if (code.contains('02')) return Icons.wb_cloudy;
    if (code.contains('10')) return Icons.umbrella;
    if (code.contains('13')) return Icons.ac_unit;
    return Icons.cloud;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopInfo(),
                const FlightCarousel(),
                _buildDaySelector(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 5,
                    onPageChanged: (i) => setState(() => _selectedDayIndex = i),
                    itemBuilder: (context, index) => DayItineraryWidget(
                      dayIndex: index,
                      onAddPressed: () {},
                    ),
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

  Widget _buildTopInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _currentTime,
            style: const TextStyle(fontSize: 40, color: Colors.black),
          ),
          if (_isWeatherLoading)
            const Text('讀取中...')
          else if (_weatherError != null)
            Text(_weatherError!, style: const TextStyle(color: Colors.red))
          else if (_weather != null)
            Row(
              children: [
                Icon(_weatherIcon),
                const SizedBox(width: 8),
                Text('${_weather!.temperature.round()}°'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          final isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF9E8B6E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'Day ${index + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
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
  final VoidCallback onAddPressed;

  const DayItineraryWidget({
    super.key,
    required this.dayIndex,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .where('dayIndex', isEqualTo: dayIndex)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final activities = snapshot.data!.docs
            .map((doc) => Activity.fromFirestore(doc))
            .toList();
        if (activities.isEmpty) return const Center(child: Text('目前沒有行程'));
        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) =>
              ActivityCard(activity: activities[index]),
        );
      },
    );
  }
}
