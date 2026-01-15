import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Weather? _weather;
  bool _isWeatherLoading = true;
  String _currentCity = "自動定位";
  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;
  String _currentTime = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _loadWeather();
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

  void _updateTime() {
    final now = DateTime.now();
    if (!mounted) return;
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _loadWeather({String? city}) async {
    setState(() => _isWeatherLoading = true);
    Weather? result;
    if (city == null) {
      result = await WeatherService.fetchWeatherByLocation();
      _currentCity = result?.cityName ?? "未知位置";
    } else {
      result = await WeatherService.fetchWeatherByCity(city);
      if (result != null) {
        _currentCity = city;
      }
    }
    if (!mounted) return;
    setState(() {
      _weather = result;
      _isWeatherLoading = false;
    });
  }

  void _showCityDialog() {
    final TextEditingController cityC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("切換城市"),
        content: TextField(
          controller: cityC,
          decoration: const InputDecoration(hintText: "例如: Sendai"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _loadWeather();
              Navigator.pop(ctx);
            },
            child: const Text("自動定位"),
          ),
          ElevatedButton(
            onPressed: () {
              _loadWeather(city: cityC.text);
              Navigator.pop(ctx);
            },
            child: const Text("確定"),
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
          // 星宇風格背景
          Positioned(
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
                        Colors.black45,
                        Colors.white.withAlpha(25),
                        const Color(0xFFF5F5F5),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              const Text(
                '2026.01.16 - 01.20',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showCityDialog,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isWeatherLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  const Icon(Icons.location_on, color: Colors.white, size: 18),
                  Text(
                    _currentCity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_weather?.temperature.round() ?? "--"}° ${_weather?.description ?? ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              itemCount: activities.length,
              itemBuilder: (ctx, index) =>
                  ActivityCard(activity: activities[index]),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 85,
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
