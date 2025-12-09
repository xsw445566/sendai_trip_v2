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
import 'package:intl/intl.dart';

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
// 2. API Keys
// ---------------------------------------------------------------------------
const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";
const String _flightApiKey = "73d5e5ca-a0eb-462d-8a91-62e6a7657cb9";

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

class FlightInfo {
  String flightNo;
  String fromCode;
  String fromCity;
  String toCode;
  String toCity;
  String date;
  String schedDep;
  String schedArr;
  String estDep;
  String estArr;
  String terminal;
  String gate;
  String baggage;
  String status;

  FlightInfo({
    required this.flightNo,
    required this.fromCode,
    required this.fromCity,
    required this.toCode,
    required this.toCity,
    required this.date,
    required this.schedDep,
    required this.schedArr,
    this.estDep = '',
    this.estArr = '',
    required this.terminal,
    required this.gate,
    required this.baggage,
    required this.status,
  });

  factory FlightInfo.fromJson(Map<String, dynamic> json) {
    String formatTime(String? fullTime) {
      if (fullTime == null || fullTime.length < 16) return '--:--';
      return fullTime.substring(11, 16);
    }

    return FlightInfo(
      flightNo: json['flight_iata'] ?? 'JX???',
      fromCode: json['dep_iata'] ?? '',
      fromCity: 'Taoyuan',
      toCode: json['arr_iata'] ?? '',
      toCity: 'Sendai',
      date: json['dep_time']?.toString().substring(5, 10) ?? '',
      schedDep: formatTime(json['dep_time']),
      schedArr: formatTime(json['arr_time']),
      estDep: formatTime(json['dep_estimated']),
      estArr: formatTime(json['arr_estimated']),
      terminal: json['dep_terminal'] ?? '-',
      gate: json['dep_gate'] ?? '-',
      baggage: json['arr_baggage'] ?? '-',
      status: json['status'] ?? 'Scheduled',
    );
  }
}

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
  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;

  final String _bgImage =
      'https://icrvb3jy.xinmedia.com/solomo/article/7/5/2/752e384b-d5f4-4d6e-b7ea-717d43c66cf2.jpeg';

  Timer? _timer;
  String _currentTime = '';

  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "Loading";
  IconData _weatherIcon = Icons.cloud;

  bool _isToolsExpanded = false;

  final CollectionReference _activitiesRef = FirebaseFirestore.instance
      .collection('activities');

  // --- 航班資料 (預設靜態值 - 優化去程資料顯示) ---
  // 若 API 抓不到 2026 年資料，就會顯示這些完整的靜態資料
  FlightInfo _outboundFlight = FlightInfo(
    flightNo: 'JX862',
    fromCode: 'TPE',
    fromCity: 'Taoyuan',
    toCode: 'SDJ',
    toCity: 'Sendai',
    date: '16 JAN',
    schedDep: '11:50',
    schedArr: '16:00',
    terminal: '1',
    gate: 'B5',
    baggage: '--',
    status: 'Scheduled', // 手動補齊資訊
  );

  FlightInfo _inboundFlight = FlightInfo(
    flightNo: 'JX863',
    fromCode: 'SDJ',
    fromCity: 'Sendai',
    toCode: 'TPE',
    toCity: 'Taoyuan',
    date: '20 JAN',
    schedDep: '17:30',
    schedArr: '20:40',
    terminal: 'I',
    gate: '3',
    baggage: '06',
    status: 'Scheduled',
  );

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchRealWeather();
    _updateFlightStatus();

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

  Future<void> _updateFlightStatus() async {
    if (_flightApiKey.isEmpty) return;
    await _fetchSingleFlight('JX862', (data) {
      setState(() => _outboundFlight = data);
    });
    await _fetchSingleFlight('JX863', (data) {
      setState(() => _inboundFlight = data);
    });
  }

  Future<void> _fetchSingleFlight(
    String flightIata,
    Function(FlightInfo) onSuccess,
  ) async {
    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules?flight_iata=$flightIata&api_key=$_flightApiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['response'] != null &&
            (jsonResponse['response'] as List).isNotEmpty) {
          var flightData = jsonResponse['response'][0];
          onSuccess(FlightInfo.fromJson(flightData));
        }
      }
    } catch (e) {
      print("Flight API Error: $e");
    }
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
        return;
      case '分帳':
        _showSplitBillDialog();
        return;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  // --- 匯率彈窗 (即時更新版) ---
  void _showCurrencyDialog() {
    // 預設值 (避免 API 失敗時顯示 0)
    double rate = 0.215;
    double jpy = 0;
    double twd = 0;
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 取得即時匯率的函式
            Future<void> fetchRate() async {
              try {
                // 使用 ExchangeRate-API (免費、無須 Key、更新頻率高)
                final url = Uri.parse(
                  'https://api.exchangerate-api.com/v4/latest/JPY',
                );
                final response = await http.get(url);
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  if (data['rates'] != null && data['rates']['TWD'] != null) {
                    if (context.mounted) {
                      setState(() {
                        rate = (data['rates']['TWD']).toDouble();
                        isLoading = false;
                        // 更新計算結果
                        twd = jpy * rate;
                      });
                    }
                  }
                }
              } catch (e) {
                print('Currency API Error: $e');
                setState(() => isLoading = false);
              }
            }

            // 第一次打開時執行
            if (isLoading) fetchRate();

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('即時匯率試算'),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
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
                  const SizedBox(height: 15),
                  Text(
                    '約 NT\$ ${twd.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E8B6E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '目前匯率: 1 JPY ≈ ${rate.toStringAsFixed(4)} TWD',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    '(資料來源: 國際即時匯率)',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('關閉'),
                ),
              ],
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

  Widget _buildFlightCarousel() {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: PageView(
        controller: PageController(viewportFraction: 0.92),
        children: [
          _buildCompactFlightCard(_outboundFlight, '去程'),
          _buildCompactFlightCard(_inboundFlight, '回程'),
        ],
      ),
    );
  }

  Widget _buildCompactFlightCard(FlightInfo info, String label) {
    return GestureDetector(
      onTap: () => _showFlightDetails(info),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9E8B6E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$label • ${info.date}',
                style: const TextStyle(
                  color: Color(0xFF9E8B6E),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAirportCode(info.fromCode, info.schedDep),
                Column(
                  children: [
                    Icon(
                      Icons.flight_takeoff,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.flightNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                _buildAirportCode(info.toCode, info.schedArr),
              ],
            ),
            if (info.estDep.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '預計: ${info.estDep} - ${info.estArr}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirportCode(String code, String time) {
    return Column(
      children: [
        Text(
          code,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(time, style: const TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  void _showFlightDetails(FlightInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(25),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Flight Details",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      info.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "${info.fromCity} ➔ ${info.toCity}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                children: [
                  _buildDetailItem(Icons.access_time, "表定起飛", info.schedDep),
                  _buildDetailItem(
                    Icons.access_time_filled,
                    "表定抵達",
                    info.schedArr,
                  ),
                  _buildDetailItem(
                    Icons.update,
                    "預計起飛",
                    info.estDep.isEmpty ? '--' : info.estDep,
                  ),
                  _buildDetailItem(
                    Icons.domain,
                    "航廈 (Terminal)",
                    info.terminal,
                  ),
                  _buildDetailItem(Icons.meeting_room, "登機門 (Gate)", info.gate),
                  _buildDetailItem(Icons.luggage, "行李轉盤", info.baggage),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9E8B6E), size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableTools() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isToolsExpanded ? 240 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isToolsExpanded = !_isToolsExpanded;
              });
            },
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TRAVEL TOOLS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  Icon(
                    _isToolsExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: const Color(0xFF9E8B6E),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildTotalCostCard(),
                          const SizedBox(width: 12),
                          _buildToolIcon(Icons.luggage, '行李', Colors.blue),
                          _buildToolIcon(Icons.shopping_bag, '必買', Colors.pink),
                          _buildToolIcon(Icons.diversity_3, '分帳', Colors.teal),
                          _buildToolIcon(
                            Icons.currency_exchange,
                            '匯率',
                            Colors.orange,
                          ),
                          _buildToolIcon(Icons.translate, '翻譯', Colors.purple),
                          _buildToolIcon(Icons.map, '地圖', Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
          width: 140,
          margin: const EdgeInsets.only(right: 12),
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
                  fontSize: 18,
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
        width: 65,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
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

                _buildFlightCarousel(),

                const SizedBox(height: 20),
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

                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: 5,
                        onPageChanged: (index) {
                          setState(() {
                            _selectedDayIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 60),
                            child: DayItineraryWidget(
                              dayIndex: index,
                              onAddPressed: _addNewActivity,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _buildExpandableTools(),
          ),
        ],
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

class AdvancedSplitBillDialog extends StatefulWidget {
  const AdvancedSplitBillDialog({super.key});
  @override
  State<AdvancedSplitBillDialog> createState() =>
      _AdvancedSplitBillDialogState();
}

class _AdvancedSplitBillDialogState extends State<AdvancedSplitBillDialog> {
  double total = 0;
  List<String> people = [];
  final TextEditingController _c = TextEditingController();
  final TextEditingController _totalC = TextEditingController();
  final DocumentReference _billRef = FirebaseFirestore.instance
      .collection('tools')
      .doc('bill_data');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      DocumentSnapshot doc = await _billRef.get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          total = (data['total'] ?? 0).toDouble();
          people = List<String>.from(data['people'] ?? []);
          _totalC.text = total == 0 ? '' : total.toStringAsFixed(0);
        });
      } else {
        setState(() {
          people = ['我'];
        });
      }
    } catch (e) {
      print('Load bill error: $e');
    }
  }

  Future<void> _saveData() async {
    await _billRef.set({'total': total, 'people': people});
  }

  @override
  Widget build(BuildContext context) {
    double share = people.isNotEmpty ? total / people.length : 0;
    return AlertDialog(
      title: const Text('分帳神器 (自動記憶)'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _totalC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '總金額 (JPY)'),
              onChanged: (v) {
                setState(() => total = double.tryParse(v) ?? 0);
                _saveData();
              },
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('每人應付', style: TextStyle(color: Colors.teal)),
                  Text(
                    '¥${share.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "分帳成員:",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Wrap(
              spacing: 8,
              children: people
                  .map(
                    (p) => Chip(
                      label: Text(p),
                      onDeleted: () {
                        setState(() => people.remove(p));
                        _saveData();
                      },
                    ),
                  )
                  .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration: const InputDecoration(hintText: '新增名字'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.teal),
                  onPressed: () {
                    if (_c.text.isNotEmpty) {
                      setState(() {
                        people.add(_c.text);
                        _c.clear();
                      });
                      _saveData();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key});
  @override
  State<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<PackingListPage> {
  final Map<String, List<String>> _categories = {
    '通用': ['護照', '日幣/信用卡', '網卡/漫遊', '充電器/行動電源', '盥洗用品', '常備藥品'],
    '雪國': [
      '發熱衣(Heattech)',
      '防水手套',
      '毛帽',
      '圍巾/脖圍',
      '冰爪',
      '厚襪子',
      '暖暖包',
      '保濕乳液/護唇膏',
      '墨鏡(雪盲)',
    ],
    '男生': ['刮鬍刀', '髮蠟'],
    '女生': ['化妝品', '卸妝油', '生理用品', '電棒捲'],
  };
  final Map<String, bool> _checkedItems = {};
  final TextEditingController _addItemController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('行李清單'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: '通用'),
              Tab(text: '雪國'),
              Tab(text: '男生'),
              Tab(text: '女生'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList('通用'),
            _buildList('雪國'),
            _buildList('男生'),
            _buildList('女生'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String category) {
    List<String> items = _categories[category] ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addItemController,
                  decoration: InputDecoration(
                    hintText: '新增到 $category',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_addItemController.text.isNotEmpty) {
                    setState(() {
                      _categories[category]!.add(_addItemController.text);
                      _addItemController.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              String item = items[index];
              bool isChecked = _checkedItems[item] ?? false;
              return CheckboxListTile(
                title: Text(
                  item,
                  style: TextStyle(
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? Colors.grey : Colors.black,
                  ),
                ),
                value: isChecked,
                onChanged: (val) => setState(() => _checkedItems[item] = val!),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<String> _list = ['仙台牛舌', '荻之月', '喜久福', '伊達政宗周邊'];
  final TextEditingController _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('必買清單'), backgroundColor: Colors.pink),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    decoration: const InputDecoration(hintText: '輸入想買的東西...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Colors.pink,
                    size: 30,
                  ),
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
                leading: const Icon(Icons.check_circle_outline),
                title: Text(_list[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
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
    {'jp': 'トイレはどこですか？', 'zh': '廁所在哪裡？'},
    {'jp': 'これください', 'zh': '我要這個'},
    {'jp': 'チェックアウトを手伝ってください。', 'zh': '麻煩幫我結帳'},
  ];
  final TextEditingController _j = TextEditingController(),
      _z = TextEditingController();

  Future<void> _playVoice(String text) async {
    final url = Uri.parse(
      'https://translate.google.com/?sl=ja&tl=zh-TW&text=${Uri.encodeComponent(text)}&op=translate',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      html.window.open(url.toString(), '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('旅遊翻譯'), backgroundColor: Colors.purple),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _j,
                    decoration: const InputDecoration(hintText: '日文'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _z,
                    decoration: const InputDecoration(hintText: '中文'),
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
            child: ListView.separated(
              itemCount: _list.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (c, i) => ListTile(
                title: Text(
                  _list[i]['jp']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _list[i]['zh']!,
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.purple),
                  onPressed: () => _playVoice(_list[i]['jp']!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
