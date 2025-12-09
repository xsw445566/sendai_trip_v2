import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // 用於網頁版開啟
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// 1. Firebase 設定
// ---------------------------------------------------------------------------
const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyBB6wqntt9gzoC1qHonWkSwH2NS4I9-TLY",
  authDomain: "sendai-app-18d03.firebaseapp.com",
  projectId: "sendai-app-18d03",
  storageBucket: "sendai-app-18d03.firebasestorage.app",
  messagingSenderId: "179113239546",
  appId: "1:179113239546:web:d45344e45740fe0df03a43",
);

// ---------------------------------------------------------------------------
// 2. 天氣 API Key
// ---------------------------------------------------------------------------
const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.logAppOpen();
  } catch (e) {
    print("Firebase 初始化訊息: $e");
  }
  runApp(const TohokuTripApp());
}

// ---------------------------------------------------------------------------
// 資料模型
// ---------------------------------------------------------------------------
enum ActivityType { sight, food, shop, transport, other }

class Activity {
  String id;
  String time;
  String title;
  String location;
  String notes;
  double cost;
  ActivityType type;
  List<String> imageUrls;
  int dayIndex;

  Activity({
    required this.id,
    required this.time,
    required this.title,
    this.location = '',
    this.notes = '',
    this.cost = 0.0,
    this.type = ActivityType.sight,
    this.imageUrls = const [],
    required this.dayIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'title': title,
      'location': location,
      'notes': notes,
      'cost': cost,
      'type': type.index,
      'imageUrls': imageUrls,
      'dayIndex': dayIndex,
    };
  }

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      time: data['time'] ?? '00:00',
      title: data['title'] ?? '',
      location: data['location'] ?? '',
      notes: data['notes'] ?? '',
      cost: (data['cost'] ?? 0).toDouble(),
      type: ActivityType.values[data['type'] ?? 0],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      dayIndex: data['dayIndex'] ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 主程式 UI
// ---------------------------------------------------------------------------
class TohokuTripApp extends StatelessWidget {
  const TohokuTripApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '仙台星宇絕美旅程',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
      theme: ThemeData(
        primaryColor: const Color(0xFF8B2E2E),
        scaffoldBackgroundColor: const Color(0xFFF9F8F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B2E2E),
          surface: const Color(0xFFF9F8F4),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ElegantItineraryPage(),
    );
  }
}

class ElegantItineraryPage extends StatefulWidget {
  const ElegantItineraryPage({super.key});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  int _selectedDayIndex = 0;
  final String _bgImage =
      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSLKhcB5F9FQl1QS4diAnfhxsCw9eQN6afXIA&s';

  Timer? _timer;
  String _currentTime = '';

  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "載入中...";
  IconData _weatherIcon = Icons.cloud_download;

  final CollectionReference _activitiesRef = FirebaseFirestore.instance
      .collection('activities');

  // ★★★ 解決閃爍：Stream 快取變數 ★★★
  late Stream<QuerySnapshot> _currentStream;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchRealWeather();

    // 初始化 Stream
    _updateStream();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _updateTime(); // 這裡只更新時間變數，不會影響 Stream
      if (t.tick % 1800 == 0) _fetchRealWeather();
    });
  }

  // 只有切換日期時，才重新建立 Stream
  void _updateStream() {
    _currentStream = _activitiesRef
        .where('dayIndex', isEqualTo: _selectedDayIndex)
        .snapshots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _fetchRealWeather() async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$_city&appid=$_weatherApiKey&units=metric&lang=zh_tw',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          double temp = data['main']['temp'];
          _weatherTemp = "${temp.round()}°";
          _weatherCond = data['weather'][0]['description'];
          String iconCode = data['weather'][0]['icon'];
          _weatherIcon = _mapWeatherIcon(iconCode);
        });
      }
    } catch (e) {
      print("Error fetching weather: $e");
    }
  }

  IconData _mapWeatherIcon(String code) {
    switch (code) {
      case '01d':
        return Icons.wb_sunny;
      case '01n':
        return Icons.nightlight_round;
      case '02d':
      case '02n':
        return Icons.wb_cloudy;
      case '03d':
      case '03n':
        return Icons.cloud;
      case '04d':
      case '04n':
        return Icons.cloud_queue;
      case '09d':
      case '09n':
        return Icons.grain;
      case '10d':
      case '10n':
        return Icons.umbrella;
      case '11d':
      case '11n':
        return Icons.flash_on;
      case '13d':
      case '13n':
        return Icons.ac_unit;
      case '50d':
      case '50n':
        return Icons.waves;
      default:
        return Icons.cloud;
    }
  }

  Widget _buildTotalCostDisplay() {
    // 這裡的 Stream 不需要快取，因為它要監聽所有日期的總和
    return StreamBuilder<QuerySnapshot>(
      stream: _activitiesRef.snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        double daily = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double cost = (data['cost'] ?? 0).toDouble();
            total += cost;
            if (data['dayIndex'] == _selectedDayIndex) {
              daily += cost;
            }
          }
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL EXPENSE (ALL DAYS)',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '¥ ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'Serif',
                    color: Color(0xFF8B2E2E),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '¥ ${daily.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'Serif',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetail(Activity activity, bool isNew) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailPage(
          activity: activity,
          onSave: (updatedActivity) async {
            if (isNew) {
              await _activitiesRef.add(updatedActivity.toMap());
            } else {
              await _activitiesRef
                  .doc(updatedActivity.id)
                  .update(updatedActivity.toMap());
            }
          },
          onDelete: isNew
              ? null
              : () async {
                  await _activitiesRef.doc(activity.id).delete();
                },
        ),
      ),
    );
  }

  void _addNewActivity(int dayIndex) {
    Activity newActivity = Activity(
      id: '',
      time: '00:00',
      title: '新行程',
      type: ActivityType.sight,
      dayIndex: dayIndex,
    );
    _navigateToDetail(newActivity, true);
  }

  // ★ 處理工具列點擊
  void _handleToolTap(String label) {
    Widget page;
    switch (label) {
      case '行李':
        page = const PackingListPage();
        break;
      case '必買':
        page = const ShoppingListPage();
        break;
      case '翻譯':
        page = const TranslatorPage();
        break;
      case '地圖':
        page = const MapListPage();
        break; // 雲端地圖
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  // ★ 匯率換算
  void _showCurrencyDialog() {
    double rate = 0.215;
    double jpy = 0;
    double twd = 0;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('匯率換算'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '日幣 (JPY)'),
                    onChanged: (v) => setState(() {
                      jpy = double.tryParse(v) ?? 0;
                      twd = jpy * rate;
                    }),
                  ),
                  Text(
                    '約 NT\$ ${twd.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ★ 進階分帳
  void _showSplitBillDialog() {
    showDialog(
      context: context,
      builder: (context) => const AdvancedSplitBillDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _bgImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black12,
                        Colors.white.withOpacity(0.1),
                        const Color(0xFFF9F8F4),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. 資訊區
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '2026.01.16 - 01.20',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 5),
                              ],
                            ),
                          ),
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              fontFamily: 'Serif',
                              fontSize: 60,
                              height: 1.0,
                              color: Color(0xFF8B2E2E),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Text(
                                '桃園',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.flight_takeoff, size: 20),
                              ),
                              Text(
                                '仙台',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Miyagi, Japan',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          _fetchRealWeather();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('更新天氣...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(_weatherIcon, color: Colors.amber, size: 32),
                              Text(
                                _weatherTemp,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _weatherCond,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 工具列 (已移除匯入與背景)
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildToolItem(
                        Icons.luggage,
                        '行李',
                        Colors.blue,
                        onTap: () => _handleToolTap('行李'),
                      ),
                      _buildToolItem(
                        Icons.shopping_bag,
                        '必買',
                        Colors.pink,
                        onTap: () => _handleToolTap('必買'),
                      ),
                      _buildToolItem(
                        Icons.translate,
                        '翻譯',
                        Colors.purple,
                        onTap: () => _handleToolTap('翻譯'),
                      ),
                      _buildToolItem(
                        Icons.map,
                        '地圖',
                        Colors.green,
                        onTap: () => _handleToolTap('地圖'),
                      ),
                      _buildToolItem(
                        Icons.currency_exchange,
                        '匯率',
                        Colors.orange,
                        onTap: _showCurrencyDialog,
                      ),
                      _buildToolItem(
                        Icons.diversity_3,
                        '分帳',
                        Colors.teal,
                        onTap: _showSplitBillDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. 日期選擇器
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedDayIndex == index;
                      return GestureDetector(
                        onTap: () {
                          // 切換日期 -> 更新 Stream -> 介面自動重繪
                          setState(() {
                            _selectedDayIndex = index;
                            _updateStream();
                          });
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF8B2E2E)
                                : Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Day ${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                              Text(
                                '1/${16 + index}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontFamily: 'Serif',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 4. 行程列表 (使用快取的 Stream)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _currentStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Center(child: Text('錯誤: ${snapshot.error}'));

                      // ★ 關鍵優化：不回傳 Loading，直接顯示當下資料或空，避免每秒閃爍
                      if (!snapshot.hasData) return const SizedBox();

                      List<Activity> activities = snapshot.data!.docs
                          .map((doc) => Activity.fromFirestore(doc))
                          .toList();
                      activities.sort((a, b) => a.time.compareTo(b.time));

                      if (activities.isEmpty) {
                        return const Center(
                          child: Text(
                            '點擊右下角 + 新增行程',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 0),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 18),
                                        Text(
                                          activity.time,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Serif',
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              left: 15,
                                              top: 8,
                                              bottom: 8,
                                            ),
                                            width: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _navigateToDetail(activity, false),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                          border: const Border(
                                            left: BorderSide(
                                              color: Color(0xFF8B2E2E),
                                              width: 4,
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _buildTag(activity.type),
                                                  if (activity.cost > 0)
                                                    Text(
                                                      '¥${activity.cost.toInt()}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF8B2E2E,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                activity.title,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (activity
                                                  .location
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                const Divider(
                                                  height: 1,
                                                  color: Color(0xFFEEEEEE),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      activity.location,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            right: 20,
            bottom: 90,
            child: FloatingActionButton(
              onPressed: () => _addNewActivity(_selectedDayIndex),
              backgroundColor: const Color(0xFF8B2E2E),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFD4C5A9))),
              ),
              child: _buildTotalCostDisplay(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ActivityType type) {
    String text = '';
    Color color = Colors.grey;
    switch (type) {
      case ActivityType.sight:
        text = '景點';
        color = Colors.teal;
        break;
      case ActivityType.food:
        text = '美食';
        color = Colors.orange;
        break;
      case ActivityType.shop:
        text = '購物';
        color = Colors.pink;
        break;
      case ActivityType.transport:
        text = '交通';
        color = Colors.blueGrey;
        break;
      case ActivityType.other:
        text = '彈性';
        color = Colors.purple;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 詳細資料與編輯頁面
// ---------------------------------------------------------------------------
class ActivityDetailPage extends StatefulWidget {
  final Activity activity;
  final Function(Activity) onSave;
  final VoidCallback? onDelete;

  const ActivityDetailPage({
    super.key,
    required this.activity,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late TextEditingController _titleC;
  late TextEditingController _timeC;
  late TextEditingController _locC;
  late TextEditingController _costC;
  late TextEditingController _noteC;
  late ActivityType _type;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.activity.title);
    _timeC = TextEditingController(text: widget.activity.time);
    _locC = TextEditingController(text: widget.activity.location);
    _costC = TextEditingController(text: widget.activity.cost.toString());
    _noteC = TextEditingController(text: widget.activity.notes);
    _type = widget.activity.type;
  }

  void _save() {
    widget.activity.title = _titleC.text;
    widget.activity.time = _timeC.text;
    widget.activity.location = _locC.text;
    widget.activity.cost = double.tryParse(_costC.text) ?? 0.0;
    widget.activity.notes = _noteC.text;
    widget.activity.type = _type;
    widget.onSave(widget.activity);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程詳細'),
        backgroundColor: const Color(0xFF8B2E2E),
        foregroundColor: Colors.white,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('確定刪除?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onDelete!();
                          Navigator.pop(c);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '刪除',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _timeC,
                    decoration: const InputDecoration(
                      labelText: '時間',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleC,
                    decoration: const InputDecoration(
                      labelText: '標題',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ActivityType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: '類別',
                border: OutlineInputBorder(),
              ),
              items: ActivityType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.toString().split('.').last),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _locC,
              decoration: const InputDecoration(
                labelText: '地點',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _costC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花費',
                prefixIcon: Icon(Icons.currency_yen),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteC,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '筆記',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ★★★ 進階分帳功能 (可增減人數) ★★★
// ---------------------------------------------------------------------------
class AdvancedSplitBillDialog extends StatefulWidget {
  const AdvancedSplitBillDialog({super.key});

  @override
  State<AdvancedSplitBillDialog> createState() =>
      _AdvancedSplitBillDialogState();
}

class _AdvancedSplitBillDialogState extends State<AdvancedSplitBillDialog> {
  double total = 0;
  List<String> people = ['我', '旅伴'];
  final TextEditingController _personC = TextEditingController();

  double get share => people.isNotEmpty ? total / people.length : 0;

  void _addPerson() {
    if (_personC.text.isNotEmpty) {
      setState(() {
        people.add(_personC.text);
        _personC.clear();
      });
    }
  }

  void _removePerson(int index) {
    setState(() {
      people.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.diversity_3, color: Colors.teal),
          SizedBox(width: 8),
          Text('分帳計算'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '總金額 (円)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
              onChanged: (v) => setState(() => total = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('每人應付', style: TextStyle(color: Colors.grey)),
                  Text(
                    '¥ ${share.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  Text(
                    '(共 ${people.length} 人)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _personC,
                    decoration: const InputDecoration(
                      hintText: '輸入名字',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: _addPerson,
                ),
              ],
            ),
            SizedBox(
              height: 100,
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: people.length,
                itemBuilder: (c, i) => ListTile(
                  dense: true,
                  title: Text(people[i]),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _removePerson(i),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 附屬頁面 (行李、必買、翻譯 - 可新增) (地圖 - 雲端化 + Google Map)
// ---------------------------------------------------------------------------

class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key});
  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  final Map<String, bool> _items = {'防滑鞋': false, '護照': false, '日幣': false};
  final TextEditingController _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行李清單'), backgroundColor: Colors.blue),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration: const InputDecoration(hintText: '新增項目'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_c.text.isNotEmpty)
                      setState(() {
                        _items[_c.text] = false;
                        _c.clear();
                      });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: _items.keys
                  .map(
                    (k) => CheckboxListTile(
                      title: Text(k),
                      value: _items[k],
                      onChanged: (v) => setState(() => _items[k] = v!),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<String> _list = ['牛舌', '萩之月', '毛豆泥麻糬'];
  final TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('必買清單'), backgroundColor: Colors.pink),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration: const InputDecoration(hintText: '新增必買'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_c.text.isNotEmpty)
                      setState(() {
                        _list.add(_c.text);
                        _c.clear();
                      });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(_list[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _list.removeAt(i)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});
  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final List<Map<String, String>> _list = [
    {'jp': 'お湯をください', 'zh': '請給我溫水'},
    {'jp': 'これはいくらですか？', 'zh': '這個多少錢?'},
    {'jp': 'トイレはどこですか？', 'zh': '廁所在哪裡?'},
  ];
  final TextEditingController _jpC = TextEditingController();
  final TextEditingController _zhC = TextEditingController();

  void _add() {
    if (_jpC.text.isNotEmpty && _zhC.text.isNotEmpty) {
      setState(() {
        _list.add({'jp': _jpC.text, 'zh': _zhC.text});
        _jpC.clear();
        _zhC.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('翻譯官'), backgroundColor: Colors.purple),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _jpC,
                  decoration: const InputDecoration(
                    hintText: '日文',
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: _zhC,
                  decoration: const InputDecoration(
                    hintText: '中文',
                    isDense: true,
                  ),
                ),
                ElevatedButton(onPressed: _add, child: const Text('新增翻譯卡')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (c, i) => Card(
                child: ListTile(
                  title: Text(_list[i]['jp']!),
                  subtitle: Text(_list[i]['zh']!),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _list.removeAt(i)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ★★★ 地圖功能：雲端化 + 連結 Google Maps ★★★
class MapListPage extends StatelessWidget {
  const MapListPage({super.key});

  Future<void> _openMap(String location) async {
    // 使用 'dir' (direction) 模式，destination 填入地點
    final Uri googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$location',
    );

    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } else {
      // Web fallback
      try {
        html.window.open(googleUrl.toString(), '_blank');
      } catch (e) {
        // ignore: avoid_print
        print("Web launch failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('雲端地圖導航'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('activities').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['location'] != null &&
                data['location'].toString().isNotEmpty;
          }).toList();

          if (docs.isEmpty) return const Center(child: Text('目前沒有設定地點的行程'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String title = data['title'];
              String location = data['location'];

              return ListTile(
                leading: const Icon(Icons.map, color: Colors.red),
                title: Text(title),
                subtitle: Text(location),
                trailing: const Icon(Icons.directions, color: Colors.blue),
                onTap: () => _openMap(location),
              );
            },
          );
        },
      ),
    );
  }
}
