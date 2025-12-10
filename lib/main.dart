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
import 'package:flutter_tts/flutter_tts.dart';

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
  String id;
  String flightNo;
  String fromCode;
  String toCode;
  String date;
  String schedDep;
  String schedArr;
  String estDep;
  String terminal;
  String gate;
  String counter;
  String baggage;
  String status;

  FlightInfo({
    required this.id,
    required this.flightNo,
    required this.fromCode,
    required this.toCode,
    required this.date,
    required this.schedDep,
    required this.schedArr,
    this.estDep = '',
    required this.terminal,
    required this.gate,
    required this.counter,
    required this.baggage,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'flightNo': flightNo,
      'fromCode': fromCode,
      'toCode': toCode,
      'date': date,
      'schedDep': schedDep,
      'schedArr': schedArr,
      'estDep': estDep,
      'terminal': terminal,
      'gate': gate,
      'counter': counter,
      'baggage': baggage,
      'status': status,
    };
  }

  factory FlightInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FlightInfo(
      id: doc.id,
      flightNo: data['flightNo'] ?? '',
      fromCode: data['fromCode'] ?? '',
      toCode: data['toCode'] ?? '',
      date: data['date'] ?? '',
      schedDep: data['schedDep'] ?? '',
      schedArr: data['schedArr'] ?? '',
      estDep: data['estDep'] ?? '',
      terminal: data['terminal'] ?? '-',
      gate: data['gate'] ?? '-',
      counter: data['counter'] ?? '-',
      baggage: data['baggage'] ?? '-',
      status: data['status'] ?? 'Plan',
    );
  }

  factory FlightInfo.fromApi(Map<String, dynamic> json) {
    String formatTime(String? fullTime) {
      if (fullTime == null || fullTime.length < 16) return '';
      return fullTime.substring(11, 16);
    }

    // 取得表定時間
    String sDep = formatTime(json['dep_time']);
    String sArr = formatTime(json['arr_time']);

    // 取得預計時間，如果 API 回傳 null，則用表定時間遞補 (代表準點)
    String eDep = formatTime(json['dep_estimated']);
    if (eDep.isEmpty) eDep = sDep;

    return FlightInfo(
      id: '',
      flightNo: json['flight_iata'] ?? '',
      fromCode: json['dep_iata'] ?? '',
      toCode: json['arr_iata'] ?? '',
      date: json['dep_time']?.toString().substring(5, 10) ?? '',
      schedDep: sDep,
      schedArr: sArr,
      estDep: eDep,
      terminal: json['dep_terminal'] ?? '-',
      gate: json['dep_gate'] ?? '-',
      counter: '-', // API 不提供，預設為空
      baggage: json['arr_baggage'] ?? '-',
      status: json['status'] ?? 'Active',
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
  String detailedInfo;
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
    this.detailedInfo = '',
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
      'detailedInfo': detailedInfo,
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
      detailedInfo: data['detailedInfo'] ?? '',
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
  final CollectionReference _flightsRef = FirebaseFirestore.instance.collection(
    'flights',
  );

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

  // --- 機票管理功能 ---
  void _addNewFlight() {
    FlightInfo newFlight = FlightInfo(
      id: '',
      flightNo: '',
      fromCode: 'TPE',
      toCode: 'SDJ',
      date: '',
      schedDep: '',
      schedArr: '',
      terminal: '',
      gate: '',
      counter: '',
      baggage: '',
      status: '',
    );
    _showFlightEditor(newFlight, isNew: true);
  }

  // 查詢 API 並回傳資料的 Helper (優化版)
  Future<FlightInfo?> _fetchApiData(String flightNo) async {
    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules?flight_iata=$flightNo&api_key=$_flightApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['response'] != null &&
            (jsonResponse['response'] as List).isNotEmpty) {
          // 這裡通常會回傳多筆資料 (包含過去幾天與未來幾天)
          // 我們簡單取第一筆 (AirLabs 預設排序通常是最新的)
          return FlightInfo.fromApi(jsonResponse['response'][0]);
        }
      }
    } catch (e) {
      print("API Fetch Error: $e");
    }
    return null;
  }

  void _showFlightEditor(FlightInfo flight, {required bool isNew}) {
    final noC = TextEditingController(text: flight.flightNo);
    final dateC = TextEditingController(text: flight.date);

    // 欄位控制器
    final fromC = TextEditingController(text: flight.fromCode);
    final toC = TextEditingController(text: flight.toCode);
    final depC = TextEditingController(text: flight.schedDep);
    final arrC = TextEditingController(text: flight.schedArr);
    final termC = TextEditingController(text: flight.terminal);
    final gateC = TextEditingController(text: flight.gate);
    final counterC = TextEditingController(text: flight.counter);
    final bagC = TextEditingController(text: flight.baggage);

    bool isFetching = false;
    bool isLocked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isNew ? '新增機票 (自動同步)' : '編輯機票'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noC,
                          decoration: const InputDecoration(
                            labelText: '航班號 (ex: JX862)',
                          ),
                        ),
                      ),
                      // 日期欄位保留，但如果 API 抓到會更新
                      if (!isNew) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dateC,
                            decoration: const InputDecoration(labelText: '日期'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isFetching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: LinearProgressIndicator(color: Color(0xFF9E8B6E)),
                    ),
                  const SizedBox(height: 10),

                  // 鎖定狀態提示
                  const Divider(),
                  Row(
                    children: [
                      Icon(
                        isLocked ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: isLocked ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isLocked ? "航班資訊已鎖定 (防止誤改)" : "請輸入航班號並同步",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 主要資訊 (鎖定)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '出發',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: toC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '抵達',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: depC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '起飛時間',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: arrC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '抵達時間',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 次要資訊 (部分鎖定)
                  Row(
                    children: [
                      // 櫃檯通常 API 沒有，所以保持開放編輯
                      Expanded(
                        child: TextField(
                          controller: counterC,
                          decoration: const InputDecoration(
                            labelText: '報到櫃台',
                            hintText: '需手動輸入',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: termC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '航廈',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: gateC,
                          enabled: !isLocked,
                          decoration: InputDecoration(
                            labelText: '登機門',
                            filled: isLocked,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 行李轉盤有時候 API 會有，但常常變動，建議也可以保持開放，這裡先設為跟隨鎖定但可手動解鎖
                      Expanded(
                        child: TextField(
                          controller: bagC,
                          enabled: true,
                          decoration: const InputDecoration(labelText: '行李轉盤'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              // 搜尋按鈕
              if (!isLocked)
                TextButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("搜尋與同步"),
                  onPressed: () async {
                    setDialogState(() => isFetching = true);
                    FlightInfo? apiData = await _fetchApiData(noC.text);
                    setDialogState(() {
                      isFetching = false;
                      if (apiData != null) {
                        isLocked = true; // 鎖定
                        fromC.text = apiData.fromCode;
                        toC.text = apiData.toCode;
                        depC.text = apiData.schedDep;
                        arrC.text = apiData.schedArr;
                        termC.text = apiData.terminal;
                        gateC.text = apiData.gate;
                        // 嘗試填入行李，如果沒有則留空
                        if (apiData.baggage != '-') bagC.text = apiData.baggage;
                        dateC.text = apiData.date; // 更新日期
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('找不到航班，請檢查代號')),
                        );
                      }
                    });
                  },
                ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),

              ElevatedButton(
                onPressed: () {
                  // 儲存邏輯：如果 API 有抓到 estDep 就用，沒有就用 schedDep
                  // 但這裡是存入 DB，所以主要存表定
                  final data = FlightInfo(
                    id: isNew ? '' : flight.id,
                    flightNo: noC.text,
                    fromCode: fromC.text,
                    toCode: toC.text,
                    date: dateC.text,
                    schedDep: depC.text,
                    schedArr: arrC.text,
                    estDep: depC.text, // 預設預計時間=表定時間
                    terminal: termC.text,
                    gate: gateC.text,
                    counter: counterC.text,
                    baggage: bagC.text,
                    status: 'Saved',
                  ).toMap();

                  if (isNew) {
                    _flightsRef.add(data);
                  } else {
                    _flightsRef.doc(flight.id).update(data);
                  }
                  Navigator.pop(context);
                },
                child: const Text('儲存'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editFlight(FlightInfo flight) {
    // 編輯時通常是為了改櫃檯或行李，所以直接顯示編輯窗，但核心資料不建議大改
    _showFlightEditor(flight, isNew: false);
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

  void _showCurrencyDialog() {
    double rate = 0.215;
    double jpy = 0;
    double twd = 0;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> fetchRate() async {
              try {
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
                        twd = jpy * rate;
                      });
                    }
                  }
                }
              } catch (e) {
                print('Currency API Error: $e');
              }
            }

            fetchRate();

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

  // --- Widget 構建: 動態機票卡片 (Firestore) ---
  Widget _buildFlightCarousel() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: _flightsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final flightDocs = snapshot.data!.docs;

          if (flightDocs.isEmpty) {
            return Center(
              child: GestureDetector(
                onTap: _addNewFlight,
                child: Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text("新增您的第一張機票"),
                    ],
                  ),
                ),
              ),
            );
          }

          return PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: flightDocs.length + 1,
            itemBuilder: (context, index) {
              if (index == flightDocs.length) {
                return GestureDetector(
                  onTap: _addNewFlight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, size: 50, color: Colors.white),
                    ),
                  ),
                );
              }
              final flight = FlightInfo.fromFirestore(flightDocs[index]);
              return _buildCompactFlightCard(flight);
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactFlightCard(FlightInfo info) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9E8B6E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${info.date} • ${info.flightNo}',
                    style: const TextStyle(
                      color: Color(0xFF9E8B6E),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // 如果有櫃台資訊就顯示，沒有則不顯示
                if (info.counter != '-' && info.counter.isNotEmpty)
                  Text(
                    '櫃台: ${info.counter}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
              ],
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
                    const Text("➔", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                _buildAirportCode(info.toCode, info.schedArr),
              ],
            ),
            // 顯示預計時間 (若與表定不同或有值)
            if (info.estDep.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '預計起飛: ${info.estDep}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSmallInfo("航廈", info.terminal),
                _buildSmallInfo("登機門", info.gate),
                _buildSmallInfo("行李", info.baggage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      _flightsRef.doc(info.id).delete();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
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
              const SizedBox(height: 10),
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
                "${info.fromCode} ➔ ${info.toCode}",
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
                  _buildDetailItem(Icons.update, "預計起飛", info.estDep),
                  _buildDetailItem(Icons.how_to_reg, "報到櫃台", info.counter),
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
  late TextEditingController _detailC;
  late ActivityType _type;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.activity.title);
    _timeC = TextEditingController(text: widget.activity.time);
    _locC = TextEditingController(text: widget.activity.location);
    _costC = TextEditingController(text: widget.activity.cost.toString());
    _noteC = TextEditingController(text: widget.activity.notes);
    _detailC = TextEditingController(text: widget.activity.detailedInfo);
    _type = widget.activity.type;
  }

  void _save() {
    widget.activity.title = _titleC.text;
    widget.activity.time = _timeC.text;
    widget.activity.location = _locC.text;
    widget.activity.cost = double.tryParse(_costC.text) ?? 0.0;
    widget.activity.notes = _noteC.text;
    widget.activity.detailedInfo = _detailC.text;
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
              maxLines: 2,
              decoration: const InputDecoration(labelText: '簡短筆記'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _detailC,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '詳細資訊 (景點介紹/攻略/連結)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
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
  // TTS
  final FlutterTts flutterTts = FlutterTts();

  final List<Map<String, String>> _list = [
    {'jp': 'トイレはどこですか？', 'zh': '廁所在哪裡？'},
    {'jp': 'これください', 'zh': '我要這個'},
    {'jp': 'チェックアウトを手伝ってください。', 'zh': '麻煩幫我結帳'},
  ];
  final TextEditingController _j = TextEditingController(),
      _z = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("ja-JP");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
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
                  onPressed: () => _speak(_list[i]['jp']!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
