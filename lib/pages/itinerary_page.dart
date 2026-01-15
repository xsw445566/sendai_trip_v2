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
  Weather? _displayWeather; // 目前顯示的天氣 (可能是 GPS 或 自訂)
  bool _isLoading = true;
  bool _isUsingGps = true; // 追蹤目前是否在使用 GPS

  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;
  String _currentTime = '';
  Timer? _clockTimer;

  final Map<String, List<String>> _japanRegions = {
    '北海道': ['Sapporo', 'Hakodate', 'Asahikawa', 'Otaru'],
    '東北': ['Sendai', 'Aomori', 'Morioka', 'Akita', 'Yamagata', 'Fukushima'],
    '關東': [
      'Tokyo',
      'Yokohama',
      'Chiba',
      'Saitama',
      'Kamakura',
      'Nikko',
      'Hakone',
    ],
    '中部': ['Nagoya', 'Kanazawa', 'Takayama', 'Niigata', 'Shizuoka', 'Nagano'],
    '近畿': ['Osaka', 'Kyoto', 'Nara', 'Kobe', 'Himeji', 'Wakayama'],
    '中國': ['Hiroshima', 'Okayama', 'Matsue', 'Tottori'],
    '四國': ['Takamatsu', 'Matsuyama', 'Tokushima', 'Kochi'],
    '九州沖繩': ['Fukuoka', 'Kumamoto', 'Kagoshima', 'Nagasaki', 'Oita', 'Okinawa'],
  };

  @override
  void initState() {
    super.initState();
    _loadGpsWeather(); // 預設進場使用 GPS 定位
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

  // --- 核心天氣載入邏輯 ---
  Future<void> _loadGpsWeather() async {
    setState(() {
      _isLoading = true;
      _isUsingGps = true;
    });
    try {
      final w = await WeatherService.fetchWeatherByLocation();
      if (mounted && w != null) {
        setState(() {
          _displayWeather = w;
          _isLoading = false;
        });
        _updateTime();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("GPS Error: $e");
    }
  }

  Future<void> _loadCustomWeather(String city) async {
    setState(() {
      _isLoading = true;
      _isUsingGps = false;
    });
    final w = await WeatherService.fetchWeatherByCity(city);
    if (mounted && w != null) {
      setState(() {
        _displayWeather = w;
        _isLoading = false;
      });
      _updateTime();
    }
  }

  void _updateTime() {
    if (!mounted) return;
    DateTime now = DateTime.now().toUtc();
    if (_displayWeather != null) {
      now = now.add(Duration(seconds: _displayWeather!.timezone));
    } else {
      now = DateTime.now();
    }
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "切換天氣區域",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: Color(0xFF9E8B6E)),
              title: const Text("使用 GPS 自動定位"),
              onTap: () {
                _loadGpsWeather();
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: _japanRegions.entries.map((region) {
                  return ExpansionTile(
                    title: Text(
                      region.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: region.value
                        .map(
                          (city) => ListTile(
                            title: Text(_translateCity(city)),
                            subtitle: Text(city),
                            onTap: () {
                              _loadCustomWeather(city);
                              Navigator.pop(ctx);
                            },
                          ),
                        )
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateCity(String city) {
    Map<String, String> names = {
      'Sapporo': '札幌',
      'Sendai': '仙台',
      'Tokyo': '東京',
      'Yokohama': '橫濱',
      'Osaka': '大阪',
      'Kyoto': '京都',
      'Nara': '奈良',
      'Fukuoka': '福岡',
      'Okinawa': '沖繩',
      'Nagoya': '名古屋',
      'Hiroshima': '廣島',
      'Kobe': '神戶',
    };
    return names[city] ?? city;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景漸層
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
                        Colors.black54,
                        Colors.white.withAlpha(20),
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
                _buildElegantHeader(), // 全新設計的 Header
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

  // --- 全新精緻 Header UI ---
  Widget _buildElegantHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側：大時間
          Text(
            _currentTime,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),

          // 右側：整合天氣資訊區塊
          GestureDetector(
            onTap: _showLocationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withAlpha(30),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isUsingGps ? Icons.near_me : Icons.location_on,
                        size: 12,
                        color: const Color(0xFFD4C5A9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isUsingGps ? "當前位置" : "指定區域",
                        style: const TextStyle(
                          color: Color(0xFFD4C5A9),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (_isLoading)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (_displayWeather != null) ...[
                    Text(
                      _translateCity(_displayWeather!.cityName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "${_displayWeather!.temperature.round()}° ${_displayWeather!.description}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 130),
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
