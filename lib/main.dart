import 'package:flutter/material.dart';
import 'dart:async';
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
const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";
const String _flightApiKey = "73d5e5ca-a0eb-462d-8a91-62e6a7657cb9";

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseAnalytics.instance;
  } catch (e) {
    print("Firebase 初始化失敗: $e");
  }

  runApp(const TohokuTripApp());
}

// ---------------------------------------------------------------------------
// Flight Model
// ---------------------------------------------------------------------------
class FlightInfo {
  String id;
  String flightNo;
  String fromCode;
  String toCode;

  String date; // MM-DD
  String schedDep; // HH:mm
  String schedArr; // HH:mm

  String estDep; // 即時預估/實際
  String estArr;

  String terminal;
  String gate;
  String counter;
  String baggage;

  String status;
  int delay;

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
    final d = doc.data() as Map<String, dynamic>;

    return FlightInfo(
      id: doc.id,
      flightNo: d['flightNo'] ?? '',
      fromCode: d['fromCode'] ?? '',
      toCode: d['toCode'] ?? '',
      date: d['date'] ?? '',
      schedDep: d['schedDep'] ?? '',
      schedArr: d['schedArr'] ?? '',
      estDep: d['estDep'] ?? '',
      estArr: d['estArr'] ?? '',
      terminal: d['terminal'] ?? '-',
      gate: d['gate'] ?? '-',
      counter: d['counter'] ?? '-',
      baggage: d['baggage'] ?? '-',
      status: d['status'] ?? 'scheduled',
      delay: (d['delay'] ?? 0).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Model
// ---------------------------------------------------------------------------
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
    final d = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      time: d['time'] ?? "00:00",
      title: d['title'] ?? "",
      location: d['location'] ?? "",
      notes: d['notes'] ?? "",
      detailedInfo: d['detailedInfo'] ?? "",
      cost: (d['cost'] ?? 0).toDouble(),
      type: ActivityType.values[d['type'] ?? 0],
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
      dayIndex: d['dayIndex'] ?? 0,
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
// App 外殼
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
// 登入 / 註冊頁
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
// 主頁面 (行程 + 航班 + 工具)
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

  // 使用 A 方案：user 專屬 collection + global mirror
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

    // 一次性搬移舊資料 (root -> users/{uid}/...)
    runMigrationIfNeeded(widget.uid);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _updateTime();
      if (t.tick % 1800 == 0) _fetchRealWeather();
    });

    // 自動每 60 秒同步航班資料 (只同步目前這個 user 的 flights)
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

  // -----------------------------------------------------------------------
  // 天氣 (OpenWeather)
  // -----------------------------------------------------------------------
  Future<void> _fetchRealWeather() async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$_city&appid=$_weatherApiKey&units=metric&lang=zh_tw',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final temp = (data['main']['temp'] as num).toDouble();
          _weatherTemp = "${temp.round()}°";
          _weatherCond = data['weather'][0]['description'];
          final iconCode = data['weather'][0]['icon'];
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
  // AirLabs Realtime Flight Schedules API
  // -----------------------------------------------------------------------
  Future<FlightInfo?> _fetchApiData(String flightNo) async {
    final trimmedNo = flightNo.trim();
    if (trimmedNo.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules'
        '?flight_iata=$trimmedNo&api_key=$_flightApiKey',
      );

      final response = await http.get(url);
      print('Airlabs status=${response.statusCode} body=${response.body}');

      if (response.statusCode != 200) return null;

      final jsonResponse = json.decode(response.body);

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
        estDep: fmt((data['dep_actual'] ?? data['dep_estimated']) as String?),
        estArr: fmt((data['arr_actual'] ?? data['arr_estimated']) as String?),
        terminal: (data['dep_terminal'] ?? '-') as String,
        gate: (data['dep_gate'] ?? '-') as String,
        counter: '-',
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
  // 航班同步（A 方案：使用 Firestore 自動 doc.id）
  // -----------------------------------------------------------------------
  Future<void> _refreshAllFlights() async {
    try {
      final snap = await _flightsRef.get();
      for (final doc in snap.docs) {
        final info = FlightInfo.fromFirestore(doc);
        if (info.flightNo.isEmpty) continue;
        await _refreshSingleFlight(info);
      }
    } catch (e) {
      print("Refresh all flights error: $e");
    }
  }

  Future<void> _refreshSingleFlight(FlightInfo flight) async {
    final apiData = await _fetchApiData(flight.flightNo);
    if (apiData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法取得最新航班資訊')));
      return;
    }

    final updated = flight
      ..date = apiData.date
      ..schedDep = apiData.schedDep
      ..schedArr = apiData.schedArr
      ..estDep = apiData.estDep
      ..estArr = apiData.estArr
      ..terminal = apiData.terminal
      ..gate = apiData.gate
      ..baggage = apiData.baggage
      ..status = apiData.status
      ..delay = apiData.delay;

    final map = updated.toMap();

    try {
      // 更新 user 專屬 flights
      await _flightsRef.doc(flight.id).update(map);

      // 同步一份到 global flights，用同一個 doc.id（autoId）
      await _globalFlightsRef.doc(flight.id).set({
        ...map,
        'uid': widget.uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('航班資訊已同步')));
    } catch (e) {
      print("Refresh single flight error: $e");
    }
  }

  // -----------------------------------------------------------------------
  // 行程新增
  // -----------------------------------------------------------------------
  void _addNewActivity() {
    final newActivity = Activity(
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
  // 新增航班（Editor 會在下一段完成）
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

  // -----------------------------------------------------------------------
  // 航班編輯視窗（A 方案：Firestore autoId）
  // -----------------------------------------------------------------------
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
            title: Text(isNew ? '新增航班（即時同步）' : '編輯航班'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: noC,
                    decoration: const InputDecoration(
                      labelText: '航班號（如 JX863）',
                    ),
                  ),
                  if (isFetching)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromC,
                          enabled: !isLocked,
                          decoration: const InputDecoration(labelText: '出發'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: toC,
                          enabled: !isLocked,
                          decoration: const InputDecoration(labelText: '抵達'),
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
                          decoration: const InputDecoration(labelText: '表定起飛'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: arrC,
                          enabled: !isLocked,
                          decoration: const InputDecoration(labelText: '表定抵達'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dateC,
                    decoration: const InputDecoration(labelText: '日期（MM-DD）'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: termC,
                          decoration: const InputDecoration(labelText: '航廈'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: gateC,
                          decoration: const InputDecoration(labelText: '登機門'),
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
                          decoration: const InputDecoration(labelText: '報到櫃檯'),
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
              TextButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('搜尋並同步'),
                onPressed: () async {
                  setDialogState(() => isFetching = true);
                  final apiData = await _fetchApiData(noC.text.trim());
                  setDialogState(() => isFetching = false);

                  if (apiData != null) {
                    setDialogState(() {
                      isLocked = true;
                      fromC.text = apiData.fromCode;
                      toC.text = apiData.toCode;
                      depC.text = apiData.schedDep;
                      arrC.text = apiData.schedArr;
                      dateC.text = apiData.date;
                      termC.text = apiData.terminal;
                      gateC.text = apiData.gate;
                      bagC.text = apiData.baggage;
                    });
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('查無航班資料')));
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final info = FlightInfo(
                    id: flight.id,
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
                    status: 'scheduled',
                    delay: 0,
                  );

                  if (isNew) {
                    final ref = await _flightsRef.add(info.toMap());
                    await _globalFlightsRef.doc(ref.id).set({
                      ...info.toMap(),
                      'uid': widget.uid,
                    });
                  } else {
                    await _flightsRef.doc(flight.id).update(info.toMap());
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
  // 航班輪播（STARLUX 高級卡片）
  // -----------------------------------------------------------------------
  Widget _buildFlightCarousel() {
    return SizedBox(
      height: 190,
      child: StreamBuilder<QuerySnapshot>(
        stream: _flightsRef.snapshots(),
        builder: (context, snapshot) {
          List<FlightInfo> flights = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            flights = snapshot.data!.docs
                .map((d) => FlightInfo.fromFirestore(d))
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
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                      color: Colors.white24,
                    ),
                    child: const Center(
                      child: Icon(Icons.add, size: 48, color: Colors.white),
                    ),
                  ),
                );
              }

              final info = flights[index];
              final isDefault = info.id.startsWith('default');

              return GestureDetector(
                onTap: isDefault ? null : () => _showFlightDetails(info),
                onLongPress: isDefault
                    ? null
                    : () => _refreshSingleFlight(info),
                child: _buildCompactFlightCard(info, isDefault: isDefault),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompactFlightCard(FlightInfo info, {required bool isDefault}) {
    final isDelayed = info.delay > 0;
    final depTime = info.estDep.isNotEmpty ? info.estDep : info.schedDep;
    final arrTime = info.estArr.isNotEmpty ? info.estArr : info.schedArr;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STARLUX • ${info.flightNo}',
                style: const TextStyle(
                  color: Color(0xFFD4C5A9),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                info.status.toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _airportBlock(info.fromCode, depTime, isDelayed),
              const Expanded(child: Icon(Icons.flight, color: Colors.white54)),
              _airportBlock(info.toCode, arrTime, isDelayed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _airportBlock(String code, String time, bool delayed) {
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
        Text(
          time,
          style: TextStyle(
            fontSize: 18,
            color: delayed ? Colors.redAccent : Colors.white,
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 航班詳細資訊 BottomSheet（STARLUX）
  // -----------------------------------------------------------------------
  void _showFlightDetails(FlightInfo info) {
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
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _flightsRef.doc(info.id).delete();
                        await _globalFlightsRef.doc(info.id).delete();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${info.fromCode} ➜ ${info.toCode}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "日期：${info.date}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.8,
                  children: [
                    _buildDetailItem(Icons.schedule, "表定起飛", info.schedDep),
                    _buildDetailItem(Icons.schedule, "表定抵達", info.schedArr),
                    _buildDetailItem(Icons.flight_takeoff, "預計起飛", info.estDep),
                    _buildDetailItem(Icons.flight_land, "預計抵達", info.estArr),
                    _buildDetailItem(Icons.domain, "航廈", info.terminal),
                    _buildDetailItem(Icons.meeting_room, "登機門", info.gate),
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
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF9E8B6E)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
  // Tools Bar（旅遊工具列）
  // -----------------------------------------------------------------------
  Widget _buildExpandableTools() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isToolsExpanded ? 230 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            onTap: () => setState(() => _isToolsExpanded = !_isToolsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TRAVEL TOOLS',
                    style: TextStyle(letterSpacing: 1.5, color: Colors.grey),
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
          if (_isToolsExpanded)
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildToolIcon(Icons.luggage, '行李', Colors.blue),
                  _buildToolIcon(Icons.shopping_bag, '必買', Colors.pink),
                  _buildToolIcon(Icons.currency_exchange, '匯率', Colors.orange),
                  _buildToolIcon(Icons.diversity_3, '分帳', Colors.teal),
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
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _handleToolTap(String label) {
    switch (label) {
      case '行李':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PackingListPage()),
        );
        break;
      case '必買':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShoppingListPage()),
        );
        break;
      case '翻譯':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TranslatorPage()),
        );
        break;
      case '地圖':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapListPage()),
        );
        break;
    }
  }

  // -----------------------------------------------------------------------
  // Scaffold build（主畫面）
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildFlightCarousel(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _selectedDayIndex = i),
                    itemCount: 5,
                    itemBuilder: (_, i) => DayItineraryWidget(
                      dayIndex: i,
                      onAddPressed: _addNewActivity,
                    ),
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
