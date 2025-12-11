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
import 'package:firebase_auth/firebase_auth.dart';
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
// OpenWeather
const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";
// AirLabs Real-time Flights API
const String _flightApiKey = "73d5e5ca-a0eb-462d-8a91-62e6a7657cb9";

// ---------------------------------------------------------------------------
// 3. Main
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseAnalytics.instance;
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
  String date; // 01-16 之類

  String schedDep; // 表定起飛 HH:mm
  String schedArr; // 表定抵達 HH:mm

  String estDep; // 實際 / 預計起飛
  String estArr; // 實際 / 預計抵達

  String terminal;
  String gate;
  String counter;
  String baggage;

  String status; // scheduled / active / landed / cancelled...
  int delay; // dep_delayed (分鐘)

  FlightInfo({
    required this.id,
    required this.flightNo,
    required this.fromCode,
    required this.toCode,
    required this.date,
    required this.schedDep,
    required this.schedArr,
    this.estDep = '',
    this.estArr = '',
    required this.terminal,
    required this.gate,
    required this.counter,
    required this.baggage,
    required this.status,
    this.delay = 0,
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
      'estArr': estArr,
      'terminal': terminal,
      'gate': gate,
      'counter': counter,
      'baggage': baggage,
      'status': status,
      'delay': delay,
    };
  }

  factory FlightInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlightInfo(
      id: doc.id,
      flightNo: data['flightNo'] ?? '',
      fromCode: data['fromCode'] ?? '',
      toCode: data['toCode'] ?? '',
      date: data['date'] ?? '',
      schedDep: data['schedDep'] ?? '',
      schedArr: data['schedArr'] ?? '',
      estDep: data['estDep'] ?? '',
      estArr: data['estArr'] ?? '',
      terminal: data['terminal'] ?? '-',
      gate: data['gate'] ?? '-',
      counter: data['counter'] ?? '-',
      baggage: data['baggage'] ?? '-',
      status: data['status'] ?? 'scheduled',
      delay: (data['delay'] ?? 0).toInt(),
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
// 一次性舊資料搬移：root activities/flights -> users/{uid}/...
// ---------------------------------------------------------------------------
Future<void> runMigrationIfNeeded(String uid) async {
  final db = FirebaseFirestore.instance;

  try {
    final userActs = await db
        .collection('users')
        .doc(uid)
        .collection('activities')
        .limit(1)
        .get();

    // 如果已經有資料，就視為已搬移
    if (userActs.docs.isNotEmpty) {
      return;
    }

    // 搬移 activities
    final oldActs = await db.collection('activities').get();
    for (var doc in oldActs.docs) {
      await db
          .collection('users')
          .doc(uid)
          .collection('activities')
          .doc(doc.id)
          .set(doc.data());
    }

    // 搬移 flights
    final oldFlights = await db.collection('flights').get();
    for (var doc in oldFlights.docs) {
      await db
          .collection('users')
          .doc(uid)
          .collection('flights')
          .doc(doc.id)
          .set(doc.data());
    }
  } catch (e) {
    print("Migration error: $e");
  }
}

// ---------------------------------------------------------------------------
// 主程式 UI Setup
// ---------------------------------------------------------------------------
class TohokuTripApp extends StatelessWidget {
  const TohokuTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STARLUX Journey',
      debugShowCheckedModeBanner: false,
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ElegantItineraryPage(uid: snapshot.data!.uid);
          }
          return const LoginPage();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 登入/註冊頁面
// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  String _errorMessage = '';

  Future<void> _submit() async {
    setState(() => _errorMessage = '');
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? '發生錯誤';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9E8B6E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flight_takeoff,
                    size: 60,
                    color: Color(0xFF9E8B6E),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin ? '歡迎回來' : '建立帳號',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '電子郵件',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密碼',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E8B6E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isLogin ? '登入' : '註冊',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? '沒有帳號？點此註冊' : '已有帳號？點此登入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 主頁面 (行程頁)
// ---------------------------------------------------------------------------
class ElegantItineraryPage extends StatefulWidget {
  final String uid;
  const ElegantItineraryPage({super.key, required this.uid});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;

  final String _bgImage =
      'https://icrvb3jy.xinmedia.com/solomo/article/7/5/2/752e384b-d5f4-4d6e-b7ea-717d43c66cf2.jpeg';

  Timer? _timer;
  Timer? _flightTimer;
  String _currentTime = '';

  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "Loading";
  IconData _weatherIcon = Icons.cloud;

  bool _isToolsExpanded = false;

  CollectionReference get _activitiesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .collection('activities');

  CollectionReference get _flightsRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .collection('flights');

  CollectionReference get _globalFlightsRef =>
      FirebaseFirestore.instance.collection('flights');

  final FlightInfo _defaultOutbound = FlightInfo(
    id: 'default_out',
    flightNo: 'JX862',
    fromCode: 'TPE',
    toCode: 'SDJ',
    date: '01-16',
    schedDep: '11:50',
    schedArr: '16:00',
    estDep: '',
    estArr: '',
    terminal: '1',
    gate: 'A5',
    counter: '6',
    baggage: '--',
    status: 'scheduled',
    delay: 0,
  );

  final FlightInfo _defaultInbound = FlightInfo(
    id: 'default_in',
    flightNo: 'JX863',
    fromCode: 'SDJ',
    toCode: 'TPE',
    date: '01-20',
    schedDep: '17:30',
    schedArr: '20:40',
    estDep: '',
    estArr: '',
    terminal: 'I',
    gate: '3',
    counter: '-',
    baggage: '--',
    status: 'scheduled',
    delay: 0,
  );

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchRealWeather();

    // 一次性搬移舊資料
    runMigrationIfNeeded(widget.uid);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _updateTime();
      if (t.tick % 1800 == 0) _fetchRealWeather();
    });

    // 自動每 60 秒同步航班資料
    _flightTimer = Timer.periodic(const Duration(seconds: 60), (t) {
      _refreshAllFlights();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flightTimer?.cancel();
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

  // -----------------------------------------------------------------------
  // 行程新增
  // -----------------------------------------------------------------------
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

  // -----------------------------------------------------------------------
  // AirLabs Realtime (Schedules) Flights API
  // -----------------------------------------------------------------------
  Future<FlightInfo?> _fetchApiData(String flightNo) async {
    final trimmedNo = flightNo.trim();
    if (trimmedNo.isEmpty) return null;

    try {
      // 改成使用 Flight Schedules API，而不是 flights
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules'
        '?flight_iata=$trimmedNo&api_key=$_flightApiKey',
      );

      final response = await http.get(url);

      // 方便除錯：可以看到實際回傳內容
      print('Airlabs status=${response.statusCode} body=${response.body}');

      if (response.statusCode != 200) return null;

      final jsonResponse = json.decode(response.body);

      // API 本身的錯誤（例如額度用完、金鑰錯誤）
      if (jsonResponse is Map && jsonResponse['error'] != null) {
        print('Airlabs error: ${jsonResponse['error']}');
        return null;
      }

      final list = jsonResponse['response'];
      if (list == null || list is! List || list.isEmpty) {
        print('Airlabs no data for flight $trimmedNo');
        return null;
      }

      final data = list.first as Map<String, dynamic>;

      String fmt(String? t) {
        if (t == null || t.length < 16) return "";
        // "2021-07-14 19:53" -> "19:53"
        return t.substring(11, 16);
      }

      final depTimeStr = data['dep_time'] as String?;
      final arrTimeStr = data['arr_time'] as String?;

      return FlightInfo(
        id: '',
        flightNo: (data['flight_iata'] ?? trimmedNo) as String,
        fromCode: (data['dep_iata'] ?? '') as String,
        toCode: (data['arr_iata'] ?? '') as String,
        // dep_time: "2021-07-14 19:53" -> "07-14"
        date: depTimeStr != null && depTimeStr.length >= 10
            ? depTimeStr.substring(5, 10)
            : '',

        schedDep: fmt(depTimeStr),
        schedArr: fmt(arrTimeStr),

        // 有 actual 用 actual，沒有就用 estimated
        estDep: fmt((data['dep_actual'] ?? data['dep_estimated']) as String?),
        estArr: fmt((data['arr_actual'] ?? data['arr_estimated']) as String?),

        terminal: (data['dep_terminal'] ?? '-') as String,
        gate: (data['dep_gate'] ?? '-') as String,
        counter: '-', // 報到櫃檯沒有提供，維持手動輸入
        baggage: (data['arr_baggage'] ?? '-') as String,

        status: (data['status'] ?? 'scheduled') as String,
        delay: (() {
          final v = data['dep_delayed'];
          if (v is int) return v;
          if (v is double) return v.toInt();
          return 0;
        })(),
      );
    } catch (e, st) {
      print("Realtime API error: $e\n$st");
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // 新增 / 編輯航班
  // -----------------------------------------------------------------------
  void _addNewFlight() {
    final newFlight = FlightInfo(
      id: '',
      flightNo: '',
      fromCode: 'TPE',
      toCode: 'SDJ',
      date: '',
      schedDep: '',
      schedArr: '',
      estDep: '',
      estArr: '',
      terminal: '',
      gate: '',
      counter: '',
      baggage: '',
      status: 'scheduled',
      delay: 0,
    );
    _showFlightEditor(newFlight, isNew: true);
  }

  void _showFlightEditor(FlightInfo flight, {required bool isNew}) {
    final noC = TextEditingController(text: flight.flightNo);
    final dateC = TextEditingController(text: flight.date);

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
            title: Text(isNew ? '新增航班 (即時同步)' : '編輯航班'),
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
                            labelText: '航班號 (如 JX862)',
                          ),
                        ),
                      ),
                      if (!isNew) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dateC,
                            decoration: const InputDecoration(
                              labelText: '日期 (MM-DD)',
                            ),
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
                  const Divider(),
                  Row(
                    children: [
                      Icon(
                        isLocked ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: isLocked ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLocked ? "航班資訊來自即時 API" : "輸入航班號後可同步即時資訊",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                            labelText: '表定起飛',
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
                            labelText: '表定抵達',
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
                          controller: counterC,
                          decoration: const InputDecoration(
                            labelText: '報到櫃台 (可手動)',
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
                      Expanded(
                        child: TextField(
                          controller: bagC,
                          decoration: const InputDecoration(labelText: '行李轉盤'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (!isLocked)
                TextButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("搜尋與同步"),
                  onPressed: () async {
                    setDialogState(() => isFetching = true);
                    final apiData = await _fetchApiData(noC.text.trim());
                    setDialogState(() {
                      isFetching = false;
                      if (apiData != null) {
                        isLocked = true;
                        fromC.text = apiData.fromCode;
                        toC.text = apiData.toCode;
                        depC.text = apiData.schedDep;
                        arrC.text = apiData.schedArr;
                        termC.text = apiData.terminal;
                        gateC.text = apiData.gate;
                        if (apiData.baggage != '-') {
                          bagC.text = apiData.baggage;
                        }
                        dateC.text = apiData.date;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('未找到航班資料，請確認航班號或稍後再試')),
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
                onPressed: () async {
                  final info = FlightInfo(
                    id: isNew ? '' : flight.id,
                    flightNo: noC.text.trim(),
                    fromCode: fromC.text.trim(),
                    toCode: toC.text.trim(),
                    date: dateC.text.trim(),
                    schedDep: depC.text.trim(),
                    schedArr: arrC.text.trim(),
                    estDep: flight.estDep,
                    estArr: flight.estArr,
                    terminal: termC.text.trim(),
                    gate: gateC.text.trim(),
                    counter: counterC.text.trim(),
                    baggage: bagC.text.trim(),
                    status: 'saved',
                    delay: flight.delay,
                  );

                  final map = info.toMap();

                  if (isNew) {
                    final ref = await _flightsRef.add(map);
                    await _globalFlightsRef.doc(ref.id).set({
                      ...map,
                      'uid': widget.uid,
                    });
                  } else {
                    await _flightsRef.doc(flight.id).update(map);
                    await _globalFlightsRef.doc(flight.id).set({
                      ...map,
                      'uid': widget.uid,
                    }, SetOptions(merge: true));
                  }

                  if (mounted) Navigator.pop(context);
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
    _showFlightEditor(flight, isNew: false);
  }

  // -----------------------------------------------------------------------
  // Travel Tools
  // -----------------------------------------------------------------------
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showCurrencyDialog() {
    double rate = 0.215;
    double jpy = 0;
    double twd = 0;

    showDialog(
      context: context,
      builder: (_) {
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
                    onChanged: (v) {
                      setState(() {
                        jpy = double.tryParse(v) ?? 0;
                        twd = jpy * rate;
                      });
                    },
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
      builder: (_) => const AdvancedSplitBillDialog(),
    );
  }

  // -----------------------------------------------------------------------
  // 航班輪播卡片
  // -----------------------------------------------------------------------
  Widget _buildFlightCarousel() {
    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: _flightsRef.snapshots(),
        builder: (context, snapshot) {
          List<FlightInfo> flights = [];
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            flights = snapshot.data!.docs
                .map((doc) => FlightInfo.fromFirestore(doc))
                .toList();
          } else {
            flights = [_defaultOutbound, _defaultInbound];
          }

          return PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: flights.length + 1,
            itemBuilder: (context, index) {
              if (index == flights.length) {
                return GestureDetector(
                  onTap: _addNewFlight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                    ),
                    child: const Center(
                      child: Icon(Icons.add, size: 50, color: Colors.white),
                    ),
                  ),
                );
              }
              final info = flights[index];
              final isDefault = info.id.startsWith('default');
              return GestureDetector(
                onTap: () => isDefault ? null : _showFlightDetails(info),
                onLongPress: () =>
                    isDefault ? null : _refreshSingleFlight(info),
                child: _buildCompactFlightCard(info, isDefault: isDefault),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'landed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'landed':
        return '已抵達';
      case 'active':
        return '飛行中';
      case 'scheduled':
        return '預定';
      case 'cancelled':
        return '取消';
      default:
        return status;
    }
  }

  Widget _buildCompactFlightCard(FlightInfo info, {required bool isDefault}) {
    final isDelayed = info.delay > 0;
    final statusColor = _statusColor(info.status);

    final depTimeDisplay = info.estDep.isNotEmpty ? info.estDep : info.schedDep;
    final arrTimeDisplay = info.estArr.isNotEmpty ? info.estArr : info.schedArr;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: Airline / status / manual refresh hint
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STARLUX • ${info.flightNo}',
                style: const TextStyle(
                  color: Color(0xFFD4C5A9),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _statusText(info.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Middle: big from/to
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAirportBlock(
                info.fromCode,
                depTimeDisplay,
                isDelayed: isDelayed,
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(
                      Icons.flight_takeoff,
                      color: Colors.white54,
                      size: 26,
                    ),
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white24,
                            Colors.white.withOpacity(0.05),
                            Colors.white24,
                          ],
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.flight_land,
                      color: Colors.white54,
                      size: 22,
                    ),
                  ],
                ),
              ),
              _buildAirportBlock(
                info.toCode,
                arrTimeDisplay,
                isDelayed: isDelayed,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isDelayed)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '延誤 ${info.delay} 分鐘',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 6),
          // Bottom row: date / terminal / gate / baggage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    info.date,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildSmallInfo("航廈", info.terminal),
                  const SizedBox(width: 12),
                  _buildSmallInfo("登機門", info.gate),
                  const SizedBox(width: 12),
                  _buildSmallInfo("報到", info.counter),
                ],
              ),
            ],
          ),
          if (!isDefault)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '長按卡片可立即重新同步航班資訊',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAirportBlock(
    String code,
    String time, {
    required bool isDelayed,
  }) {
    final timeStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDelayed ? Colors.redAccent : Colors.white,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(time, style: timeStyle),
      ],
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 詳細航班 BottomSheet
  void _showFlightDetails(FlightInfo info) {
    final isDelayed = info.delay > 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "STARLUX ${info.flightNo}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(info.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusText(info.status),
                        style: TextStyle(
                          color: _statusColor(info.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _refreshSingleFlight(info);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pop(context);
                        _editFlight(info);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await _flightsRef.doc(info.id).delete();
                        await _globalFlightsRef.doc(info.id).delete();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "${info.fromCode} ➜ ${info.toCode}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "日期：${info.date}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (isDelayed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "延誤 ${info.delay} 分鐘",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.7,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildDetailItem(Icons.schedule, "表定起飛", info.schedDep),
                    _buildDetailItem(Icons.schedule, "表定抵達", info.schedArr),
                    _buildDetailItem(
                      Icons.flight_takeoff,
                      "實際/預計起飛",
                      info.estDep,
                    ),
                    _buildDetailItem(Icons.flight_land, "實際/預計抵達", info.estArr),
                    _buildDetailItem(
                      Icons.domain,
                      "航廈 (Terminal)",
                      info.terminal,
                    ),
                    _buildDetailItem(
                      Icons.meeting_room,
                      "登機門 (Gate)",
                      info.gate,
                    ),
                    _buildDetailItem(Icons.person_pin, "報到櫃檯", info.counter),
                    _buildDetailItem(Icons.luggage, "行李轉盤", info.baggage),
                  ],
                ),
              ],
            ),
          );
        },
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
          Icon(icon, color: const Color(0xFF9E8B6E), size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Travel tools bar
  // -----------------------------------------------------------------------
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
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() => _isToolsExpanded = !_isToolsExpanded);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          _buildToolIcon(
                            Icons.logout,
                            '登出',
                            Colors.red,
                            onTap: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                          ),
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
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111827), Color(0xFF1F2937)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
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

  Widget _buildToolIcon(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => _handleToolTap(label),
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

  // -----------------------------------------------------------------------
  // Scaffold build
  // -----------------------------------------------------------------------
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
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey),
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
                    horizontal: 24,
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
                          setState(() => _selectedDayIndex = index);
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

// ---------------------------------------------------------------------------
// 以下為既有行程/工具頁面
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
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('activities')
              .where('dayIndex', isEqualTo: dayIndex)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
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
            builder: (_) => ActivityDetailPage(
              activity: activity,
              onSave: (updated) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('activities')
                    .doc(updated.id)
                    .update(updated.toMap());
              },
              onDelete: () {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('activities')
                    .doc(activity.id)
                    .delete();
              },
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
            DropdownButtonFormField<ActivityType>(
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
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('地圖導航'), backgroundColor: Colors.green),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('activities')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs.where((d) {
            final data = d.data() as Map;
            return (data['location'] ?? '').toString().isNotEmpty;
          }).toList();
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

// 分帳
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

  DocumentReference get _billRef => FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('tools')
      .doc('bill_data');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await _billRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          total = (data['total'] ?? 0).toDouble();
          people = List<String>.from(data['people'] ?? []);
          _totalC.text = total == 0 ? '' : total.toStringAsFixed(0);
        });
      } else {
        setState(() => people = ['我']);
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
    final share = people.isNotEmpty ? total / people.length : 0;
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

// 行李清單
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
    final items = _categories[category] ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
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
            itemBuilder: (_, index) {
              final item = items[index];
              final isChecked = _checkedItems[item] ?? false;
              return CheckboxListTile(
                title: Text(
                  item,
                  style: TextStyle(
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? Colors.grey : Colors.black,
                  ),
                ),
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    _checkedItems[item] = val ?? false;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// 必買清單
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
                    if (_c.text.isNotEmpty) {
                      setState(() {
                        _list.add(_c.text);
                        _c.clear();
                      });
                    }
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
                  onPressed: () {
                    setState(() => _list.removeAt(i));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 旅遊翻譯
class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts flutterTts = FlutterTts();

  final List<Map<String, String>> _list = [
    {'jp': 'トイレはどこですか？', 'zh': '廁所在哪裡？'},
    {'jp': 'これください', 'zh': '我要這個'},
    {'jp': 'チェックアウトを手伝ってください。', 'zh': '麻煩幫我結帳'},
  ];

  final TextEditingController _j = TextEditingController();
  final TextEditingController _z = TextEditingController();

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
                    if (_j.text.isNotEmpty) {
                      setState(() {
                        _list.add({'jp': _j.text, 'zh': _z.text});
                        _j.clear();
                        _z.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _list.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) => ListTile(
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
