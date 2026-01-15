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
  Weather? _gpsWeather;
  Weather? _customWeather;
  bool _isGpsLoading = true;
  bool _isCustomLoading = true;

  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;
  String _currentTime = '';
  Timer? _clockTimer;

  // 全日本地區清單
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
    _initWeather();
    // 每一秒更新一次時鐘
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

  Future<void> _initWeather() async {
    // 初始化時自動抓取 GPS 與 預設自訂城市 (仙台)
    _loadGpsWeather();
    _loadCustomWeather("Sendai");
  }

  // --- GPS 定位修復版 ---
  Future<void> _loadGpsWeather() async {
    if (!mounted) return;
    setState(() => _isGpsLoading = true);

    try {
      final w = await WeatherService.fetchWeatherByLocation();
      if (mounted) {
        if (w != null) {
          setState(() {
            _gpsWeather = w;
            _isGpsLoading = false;
          });
          _updateTime();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("GPS 定位天氣已更新"),
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          throw "定位回傳為空，請確認 GPS 已開啟";
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGpsLoading = false);
        // 如果定位失敗，彈出對話框告知原因 (通常是權限問題)
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("定位服務提示"),
            content: Text("無法取得 GPS 位置：$e\n請檢查手機的定位權限是否已開啟。"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("確定"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadCustomWeather(String city) async {
    if (!mounted) return;
    setState(() => _isCustomLoading = true);
    final w = await WeatherService.fetchWeatherByCity(city);
    if (mounted) {
      setState(() {
        _customWeather = w;
        _isCustomLoading = false;
      });
      _updateTime();
    }
  }

  void _updateTime() {
    if (!mounted) return;
    DateTime now = DateTime.now().toUtc();
    // 依照「自訂區域」的時區偏移量計算時間
    if (_customWeather != null) {
      now = now.add(Duration(seconds: _customWeather!.timezone));
    } else {
      now = DateTime.now(); // 預設本地時間
    }
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  // 地區選擇器 BottomSheet
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "選擇天氣區域",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
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
      'Nikko': '日光',
      'Hakone': '箱根',
      'Kobe': '神戶',
      'Kamakura': '鎌倉',
    };
    return names[city] ?? city;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 星宇高級背景
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
                _buildDualHeader(),
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

  Widget _buildDualHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：自動時區時間 + GPS 定位資訊
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
              if (_isGpsLoading)
                const Text(
                  "定位中...",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                )
              else if (_gpsWeather != null)
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 10, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      "${_gpsWeather!.temperature.round()}° ${_gpsWeather!.cityName}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // 右側：自訂選擇區域 (可點擊)
          GestureDetector(
            onTap: _showLocationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "自訂天氣區域 ▾",
                    style: TextStyle(
                      color: Color(0xFFD4C5A9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isCustomLoading)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (_customWeather != null) ...[
                    Text(
                      _translateCity(_customWeather!.cityName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${_customWeather!.temperature.round()}° ${_customWeather!.description}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
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
