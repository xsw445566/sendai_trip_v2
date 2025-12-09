import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // 需要在 pubspec.yaml 加入 intl: ^0.18.0

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
// 主程式 UI Setup
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
      title: 'STARLUX Journey',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
      theme: ThemeData(
        // 星宇風格配色：大地金、深灰、米白
        primaryColor: const Color(0xFF9E8B6E),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E8B6E),
          surface: const Color(0xFFF5F5F5),
          primary: const Color(0xFF9E8B6E),
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
  // PageController 用於翻頁控制
  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;

  // 背景圖
  final String _bgImage =
      'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80';

  Timer? _timer;
  String _currentTime = '';

  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "Loading";
  IconData _weatherIcon = Icons.cloud;

  final CollectionReference _activitiesRef = FirebaseFirestore.instance
      .collection('activities');

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchRealWeather();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _updateTime();
      if (t.tick % 1800 == 0) _fetchRealWeather();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
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

  void _addNewActivity() {
    Activity newActivity = Activity(
      id: '',
      time: '00:00',
      title: '新行程',
      type: ActivityType.sight,
      dayIndex: _selectedDayIndex,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailPage(
          activity: newActivity,
          onSave: (updatedActivity) async {
            await _activitiesRef.add(updatedActivity.toMap());
          },
          onDelete: null,
        ),
      ),
    );
  }

  // --- 工具按鈕處理 ---
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
        break;
      case '匯率':
        _showCurrencyDialog();
        return; // 彈窗不跳頁
      case '分帳':
        _showSplitBillDialog();
        return; // 彈窗不跳頁
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

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
              title: const Text('即時匯率試算'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '日幣 (JPY)',
                      suffixText: '円',
                    ),
                    onChanged: (v) => setState(() {
                      jpy = double.tryParse(v) ?? 0;
                      twd = jpy * rate;
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '約 NT\$ ${twd.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E8B6E),
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

  void _showSplitBillDialog() {
    showDialog(
      context: context,
      builder: (context) => const AdvancedSplitBillDialog(),
    );
  }

  // --- Widget 構建 ---

  // 星宇風格機票卡片
  Widget _buildBoardingPass() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 上半部：飛行資訊
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TPE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Taoyuan',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Icon(
                  Icons.flight_takeoff,
                  color: Color(0xFF9E8B6E),
                  size: 28,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'SDJ',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Sendai',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 虛線分隔
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
                  height: 1,
                ),
              ),
            ),
          ),
          // 下半部：詳細資訊
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTicketInfo('FLIGHT', 'JX862'),
                _buildTicketInfo('DATE', '16 JAN'),
                _buildTicketInfo('TIME', '11:50'),
                _buildTicketInfo('GATE', 'A5'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
      ],
    );
  }

  // 底部工具箱與總花費
  Widget _buildToolsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'TRAVEL TOOLS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(
            height: 100, // 固定高度
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 第一張卡片：總花費
                _buildTotalCostCard(),
                const SizedBox(width: 12),
                // 工具按鈕
                _buildToolIcon(Icons.shopping_bag, '必買', Colors.pink),
                _buildToolIcon(Icons.translate, '翻譯', Colors.purple),
                _buildToolIcon(Icons.map, '地圖', Colors.green),
                _buildToolIcon(Icons.luggage, '行李', Colors.blue),
                _buildToolIcon(Icons.currency_exchange, '匯率', Colors.orange),
                _buildToolIcon(Icons.diversity_3, '分帳', Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCostCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _activitiesRef.snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            total += (data['cost'] ?? 0).toDouble();
          }
        }
        return Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C2C2C), Color(0xFF4A4A4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TOTAL SPENT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${NumberFormat('#,###').format(total)}',
                style: const TextStyle(
                  color: Color(0xFFD4C5A9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolIcon(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _handleToolTap(label),
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景圖層
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _bgImage,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: Colors.grey),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black26,
                        Colors.white.withOpacity(0.1),
                        const Color(0xFFF5F5F5),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. 頂部狀態列
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const Text(
                            '2026.01.16 - 01.20',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(_weatherIcon, color: Colors.white, size: 30),
                          Text(
                            '$_weatherTemp $_weatherCond',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. 機票卡片 (裝飾用)
                _buildBoardingPass(),

                // 3. 天數切換指示器
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedDayIndex == index;
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF9E8B6E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            'Day ${index + 1}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 4. 翻頁式行程列表 (PageView)
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 5,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedDayIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return DayItineraryWidget(
                        dayIndex: index,
                        onAddPressed: _addNewActivity,
                      );
                    },
                  ),
                ),

                // 5. 底部工具區 (包含總花費)
                _buildToolsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 獨立出來的單日行程 Widget (解決閃爍問題)
// ---------------------------------------------------------------------------
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
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activities')
              .where('dayIndex', isEqualTo: dayIndex)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Error'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            List<Activity> activities = snapshot.data!.docs
                .map((doc) => Activity.fromFirestore(doc))
                .toList();
            activities.sort((a, b) => a.time.compareTo(b.time));

            if (activities.isEmpty) {
              return const Center(
                child: Text('尚無行程', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityCard(context, activity);
              },
            );
          },
        ),
        // 懸浮新增按鈕 (跟隨頁面)
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: onAddPressed,
            backgroundColor: const Color(0xFF9E8B6E),
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, Activity activity) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityDetailPage(
              activity: activity,
              onSave: (updated) => FirebaseFirestore.instance
                  .collection('activities')
                  .doc(updated.id)
                  .update(updated.toMap()),
              onDelete: () => FirebaseFirestore.instance
                  .collection('activities')
                  .doc(activity.id)
                  .delete(),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: _getTypeColor(activity.type),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            activity.time,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF9E8B6E),
                            ),
                          ),
                          if (activity.cost > 0)
                            Text(
                              '¥${activity.cost.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (activity.location.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
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
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(ActivityType type) {
    switch (type) {
      case ActivityType.sight:
        return Colors.teal;
      case ActivityType.food:
        return Colors.orange;
      case ActivityType.shop:
        return Colors.pink;
      case ActivityType.transport:
        return Colors.blueGrey;
      case ActivityType.other:
        return Colors.purple;
    }
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
        title: const Text('行程編輯'),
        backgroundColor: const Color(0xFF9E8B6E),
        foregroundColor: Colors.white,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                widget.onDelete!();
                Navigator.pop(context);
              },
            ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
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
                    decoration: const InputDecoration(labelText: '時間'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _titleC,
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField(
              value: _type,
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
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _costC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '花費',
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteC,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '筆記'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 附屬頁面：地圖、行李、必買、翻譯、分帳 (全雲端化或功能化)
// ---------------------------------------------------------------------------

// 地圖
class MapListPage extends StatelessWidget {
  const MapListPage({super.key});
  Future<void> _openMap(String loc) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$loc',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      html.window.open(url.toString(), '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地圖導航'), backgroundColor: Colors.green),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('activities').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs
              .where((d) => (d.data() as Map)['location']?.isNotEmpty ?? false)
              .toList();
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              var d = docs[i].data() as Map;
              return ListTile(
                leading: const Icon(Icons.map, color: Colors.red),
                title: Text(d['title']),
                subtitle: Text(d['location']),
                trailing: const Icon(Icons.directions),
                onTap: () => _openMap(d['location']),
              );
            },
          );
        },
      ),
    );
  }
}

// 進階分帳
class AdvancedSplitBillDialog extends StatefulWidget {
  const AdvancedSplitBillDialog({super.key});
  @override
  State<AdvancedSplitBillDialog> createState() =>
      _AdvancedSplitBillDialogState();
}

class _AdvancedSplitBillDialogState extends State<AdvancedSplitBillDialog> {
  double total = 0;
  List<String> people = ['我', '旅伴'];
  final TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    double share = people.isNotEmpty ? total / people.length : 0;
    return AlertDialog(
      title: const Text('分帳'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '總金額'),
              onChanged: (v) => setState(() => total = double.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 10),
            Text(
              '每人 ¥${share.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration: const InputDecoration(hintText: '加人'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_c.text.isNotEmpty)
                      setState(() {
                        people.add(_c.text);
                        _c.clear();
                      });
                  },
                ),
              ],
            ),
            Wrap(
              children: people
                  .map(
                    (p) => Chip(
                      label: Text(p),
                      onDeleted: () => setState(() => people.remove(p)),
                    ),
                  )
                  .toList(),
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

// 行李、必買、翻譯 (這裡簡化為本地存儲示意，若需雲端可套用 Firestore)
class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key});
  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  final Map<String, bool> _items = {'護照': false, '日幣': false};
  final TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行李'), backgroundColor: Colors.blue),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _c)),
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
  final List<String> _list = ['牛舌', '清酒'];
  final TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('必買'), backgroundColor: Colors.pink),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _c)),
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
    {'jp': 'トイレ', 'zh': '廁所'},
  ];
  final TextEditingController _j = TextEditingController(),
      _z = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('翻譯'), backgroundColor: Colors.purple),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _j,
                    decoration: const InputDecoration(hintText: '日'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _z,
                    decoration: const InputDecoration(hintText: '中'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_j.text.isNotEmpty)
                      setState(() {
                        _list.add({'jp': _j.text, 'zh': _z.text});
                        _j.clear();
                        _z.clear();
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
                title: Text(_list[i]['jp']!),
                subtitle: Text(_list[i]['zh']!),
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
