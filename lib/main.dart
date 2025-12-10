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
// 2. API Keys  （⚠ 航班 API 目前仍直接呼叫 AirLabs，之後可改成 Cloud Functions）
// ---------------------------------------------------------------------------

const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";
const String _flightApiKey = "73d5e5ca-a0eb-462d-8a91-62e6a7657cb9";

// ---------------------------------------------------------------------------
// 3. Firestore Service：集中管理 users/{uid}/... 路徑
// ---------------------------------------------------------------------------

class FirestoreService {
  final String uid;
  FirestoreService(this.uid);

  CollectionReference<Map<String, dynamic>> get activities => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('activities');

  CollectionReference<Map<String, dynamic>> get flights => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('flights');

  DocumentReference<Map<String, dynamic>> get billData => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('tools')
      .doc('bill_data');
}

// ---------------------------------------------------------------------------
// 4. Models
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

  factory FlightInfo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
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

    // 取出日期
    String dateStr = '';
    final depTime = json['dep_time'];
    if (depTime is String) {
      final dt = DateTime.tryParse(depTime);
      if (dt != null) {
        dateStr = DateFormat('dd MMM').format(dt).toUpperCase();
      }
    }

    final sDep = formatTime(json['dep_time']);
    final sArr = formatTime(json['arr_time']);
    String eDep = formatTime(json['dep_estimated']);
    if (eDep.isEmpty) eDep = sDep;

    return FlightInfo(
      id: '',
      flightNo: json['flight_iata'] ?? '',
      fromCode: json['dep_iata'] ?? '',
      toCode: json['arr_iata'] ?? '',
      date: dateStr,
      schedDep: sDep,
      schedArr: sArr,
      estDep: eDep,
      terminal: json['dep_terminal'] ?? '-',
      gate: json['dep_gate'] ?? '-',
      counter: '-',
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

  factory Activity.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
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
// 5. main() & App 殼
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseAnalytics.instance; // 若之後要用 analytics 可再補 log
  } catch (e) {
    print('Firebase init error: $e');
  }
  runApp(const TohokuTripApp());
}

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9E8B6E)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasData && snap.data != null) {
            return ElegantItineraryPage(uid: snap.data!.uid);
          }
          return const LoginPage();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Login Page
// ---------------------------------------------------------------------------

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _isLogin = true;
  String _err = '';
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _err = '';
      _loading = true;
    });
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pwd.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pwd.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _err = e.message ?? '發生錯誤');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: '電子郵件',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _pwd,
                    decoration: const InputDecoration(
                      labelText: '密碼',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  if (_err.isNotEmpty)
                    Text(_err, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E8B6E),
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isLogin ? '登入' : '註冊'),
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
// 7. 主頁面：ElegantItineraryPage
// ---------------------------------------------------------------------------

class ElegantItineraryPage extends StatefulWidget {
  final String uid;
  const ElegantItineraryPage({super.key, required this.uid});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  late final FirestoreService _fs;

  final PageController _pageController = PageController();
  int _selectedDayIndex = 0;

  final String _bgImage =
      'https://icrvb3jy.xinmedia.com/solomo/article/7/5/2/752e384b-d5f4-4d6e-b7ea-717d43c66cf2.jpeg';

  Timer? _timer;
  String _currentTime = '';

  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "";
  IconData _weatherIcon = Icons.cloud;

  bool _isToolsExpanded = false;

  // 預設靜態機票
  final FlightInfo _defaultOutbound = FlightInfo(
    id: 'default_out',
    flightNo: 'JX862',
    fromCode: 'TPE',
    toCode: 'SDJ',
    date: '16 JAN',
    schedDep: '11:50',
    schedArr: '16:00',
    estDep: '',
    terminal: '1',
    gate: 'B5',
    counter: '-',
    baggage: '05',
    status: 'Scheduled',
  );
  final FlightInfo _defaultInbound = FlightInfo(
    id: 'default_in',
    flightNo: 'JX863',
    fromCode: 'SDJ',
    toCode: 'TPE',
    date: '20 JAN',
    schedDep: '17:30',
    schedArr: '20:40',
    estDep: '',
    terminal: 'I',
    gate: '3',
    counter: '-',
    baggage: '06',
    status: 'Scheduled',
  );

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService(widget.uid);

    _runMigrationIfNeeded(); // ✅ 將舊頂層 activities / flights 搬到 users/{uid}/...

    _updateTime();
    _fetchRealWeather();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  // ------------------ 資料搬移 ------------------

  Future<void> _runMigrationIfNeeded() async {
    final db = FirebaseFirestore.instance;
    try {
      final existing = await _fs.activities.limit(1).get();
      if (existing.docs.isNotEmpty) return; // 代表已搬過，不再處理

      // activities
      final oldActs = await db.collection('activities').get();
      for (var doc in oldActs.docs) {
        await _fs.activities.doc(doc.id).set(doc.data());
      }

      // flights
      final oldFlights = await db.collection('flights').get();
      for (var doc in oldFlights.docs) {
        await _fs.flights.doc(doc.id).set(doc.data());
      }

      print('🔥 Migration finished for user ${widget.uid}');
    } catch (e) {
      print('Migration error: $e');
    }
  }

  // ------------------ 時間 & 天氣 ------------------

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
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (!mounted) return;
        final temp = (data['main']['temp'] as num).round();
        final desc = data['weather'][0]['description'];
        final iconCode = data['weather'][0]['icon'] as String;

        setState(() {
          _weatherTemp = "$temp°";
          _weatherCond = desc;
          _weatherIcon = _mapWeatherIcon(iconCode);
        });
      } else {
        print('Weather error: ${res.statusCode}');
      }
    } catch (e) {
      print('Weather error: $e');
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

  // ------------------ Activity 新增 ------------------

  void _addNewActivity() {
    final newActivity = Activity(
      id: '',
      time: '00:00',
      title: '新行程',
      dayIndex: _selectedDayIndex,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          activity: newActivity,
          onSave: (a) async {
            await _fs.activities.add(a.toMap());
          },
          onDelete: null,
        ),
      ),
    );
  }

  // ------------------ Flight API 呼叫 ------------------

  Future<FlightInfo?> _fetchApiData(String flightNo) async {
    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules?flight_iata=$flightNo&api_key=$_flightApiKey',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['response'] != null &&
            data['response'] is List &&
            (data['response'] as List).isNotEmpty) {
          return FlightInfo.fromApi(data['response'][0]);
        }
      } else {
        print('AirLabs error: ${res.statusCode}');
      }
    } catch (e) {
      print('AirLabs exception: $e');
    }
    return null;
  }

  void _addNewFlight() {
    final f = FlightInfo(
      id: '',
      flightNo: '',
      fromCode: 'TPE',
      toCode: 'SDJ',
      date: '',
      schedDep: '',
      schedArr: '',
      estDep: '',
      terminal: '',
      gate: '',
      counter: '',
      baggage: '',
      status: '',
    );
    _showFlightEditor(f, isNew: true);
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
        builder: (context, setS) {
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
                      padding: EdgeInsets.all(8),
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
                      const SizedBox(width: 5),
                      Text(
                        isLocked ? "航班資訊已鎖定" : "請輸入航班號並同步",
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
                    setS(() => isFetching = true);
                    final apiData = await _fetchApiData(noC.text.trim());
                    setS(() {
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
                          const SnackBar(content: Text('未找到航班資料，請手動輸入')),
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
                  final data = FlightInfo(
                    id: isNew ? '' : flight.id,
                    flightNo: noC.text,
                    fromCode: fromC.text,
                    toCode: toC.text,
                    date: dateC.text,
                    schedDep: depC.text,
                    schedArr: arrC.text,
                    estDep: depC.text,
                    terminal: termC.text,
                    gate: gateC.text,
                    counter: counterC.text,
                    baggage: bagC.text,
                    status: 'Saved',
                  ).toMap();

                  if (isNew) {
                    _fs.flights.add(data);
                  } else {
                    _fs.flights.doc(flight.id).update(data);
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

  void _showFlightDetails(FlightInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
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
                      _fs.flights.doc(info.id).delete();
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
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 2.5,
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

  Widget _buildCompactFlightCard(FlightInfo info) {
    final isDefault = info.id.startsWith('default');
    return GestureDetector(
      onTap: () => isDefault ? null : _showFlightDetails(info),
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
            if (info.estDep.isNotEmpty && info.estDep != info.schedDep)
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

  Widget _buildFlightCarousel() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.flights.snapshots(),
        builder: (context, snap) {
          List<FlightInfo> flights;
          if (snap.hasData && snap.data!.docs.isNotEmpty) {
            flights = snap.data!.docs
                .map((d) => FlightInfo.fromFirestore(d))
                .toList();
          } else {
            flights = [_defaultOutbound, _defaultInbound];
          }

          return PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: flights.length + 1,
            itemBuilder: (context, i) {
              if (i == flights.length) {
                // 新增按鈕
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
              return _buildCompactFlightCard(flights[i]);
            },
          );
        },
      ),
    );
  }

  // ------------------ Tools ------------------

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
          MaterialPageRoute(builder: (_) => MapListPage(firestoreService: _fs)),
        );
        break;
      case '匯率':
        _showCurrencyDialog();
        break;
      case '分帳':
        _showSplitBillDialog();
        break;
    }
  }

  void _showCurrencyDialog() {
    double rate = 0.215;
    double jpy = 0;
    double twd = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (c, setS) {
          Future<void> fetchRate() async {
            try {
              final url = Uri.parse(
                'https://api.exchangerate-api.com/v4/latest/JPY',
              );
              final res = await http.get(url);
              if (res.statusCode == 200) {
                final data = json.decode(res.body);
                final r = (data['rates']['TWD'] as num).toDouble();
                if (c.mounted) {
                  setS(() {
                    rate = r;
                    twd = jpy * rate;
                  });
                }
              }
            } catch (e) {
              print('Currency API error: $e');
            }
          }

          // 簡單來說：每次打開 dialog 抓一次
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
                    setS(() {
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
      ),
    );
  }

  void _showSplitBillDialog() {
    showDialog(
      context: context,
      builder: (_) => AdvancedSplitBillDialog(firestoreService: _fs),
    );
  }

  Widget _buildTotalCostCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.activities.snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            total += (d.data()['cost'] ?? 0).toDouble();
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

  Widget _buildToolIcon(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => _handleToolTap(label),
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

  Widget _buildExpandableTools() {
    final h = MediaQuery.of(context).size.height;
    final expandedHeight = h * 0.35 > 260 ? 260.0 : h * 0.35;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isToolsExpanded ? expandedHeight : 60,
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
              setState(() => _isToolsExpanded = !_isToolsExpanded);
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
                child: SizedBox(
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ build ------------------

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
                      final isSelected = _selectedDayIndex == index;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
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
                        onPageChanged: (i) {
                          setState(() => _selectedDayIndex = i);
                        },
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: DayItineraryWidget(
                            dayIndex: i,
                            onAddPressed: _addNewActivity,
                          ),
                        ),
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
// 8. DayItineraryWidget
// ---------------------------------------------------------------------------

class DayItineraryWidget extends StatelessWidget {
  final int dayIndex;
  final VoidCallback onAddPressed;

  const DayItineraryWidget({
    super.key,
    required this.dayIndex,
    required this.onAddPressed,
  });

  int _timeToMinutes(String t) {
    try {
      final parts = t.split(':');
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final fs = FirestoreService(user.uid);

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: fs.activities
              .where('dayIndex', isEqualTo: dayIndex)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Error'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var acts = snap.data!.docs
                .map((d) => Activity.fromFirestore(d))
                .toList();

            acts.sort(
              (a, b) =>
                  _timeToMinutes(a.time).compareTo(_timeToMinutes(b.time)),
            );

            if (acts.isEmpty) {
              return const Center(
                child: Text('尚無行程', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              itemCount: acts.length,
              itemBuilder: (context, i) {
                final a = acts[i];
                return KeyedSubtree(
                  key: ValueKey(a.id),
                  child: _buildActivityCard(context, a),
                );
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

  Widget _buildActivityCard(BuildContext context, Activity a) {
    final user = FirebaseAuth.instance.currentUser;
    final fs = FirestoreService(user!.uid);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityDetailPage(
              activity: a,
              onSave: (updated) {
                fs.activities.doc(updated.id).update(updated.toMap());
              },
              onDelete: () => fs.activities.doc(a.id).delete(),
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
                  color: _getTypeColor(a.type),
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
                            a.time,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF9E8B6E),
                            ),
                          ),
                          if (a.cost > 0)
                            Text(
                              '¥${a.cost.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (a.location.isNotEmpty)
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
                                a.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
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
// 9. ActivityDetailPage
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
              onChanged: (v) => setState(() => _type = v ?? _type),
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

// ---------------------------------------------------------------------------
// 10. MapListPage
// ---------------------------------------------------------------------------

class MapListPage extends StatelessWidget {
  final FirestoreService firestoreService;
  const MapListPage({super.key, required this.firestoreService});

  Future<void> _openMap(String loc) async {
    final url = Uri.parse(
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestoreService.activities.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs
              .where((d) => (d.data()['location'] ?? '').toString().isNotEmpty)
              .toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final data = docs[i].data();
              return ListTile(
                leading: const Icon(Icons.map, color: Colors.red),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['location'] ?? ''),
                trailing: const Icon(Icons.directions),
                onTap: () => _openMap(data['location']),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11. 分帳 Dialog
// ---------------------------------------------------------------------------

class AdvancedSplitBillDialog extends StatefulWidget {
  final FirestoreService firestoreService;
  const AdvancedSplitBillDialog({super.key, required this.firestoreService});

  @override
  State<AdvancedSplitBillDialog> createState() =>
      _AdvancedSplitBillDialogState();
}

class _AdvancedSplitBillDialogState extends State<AdvancedSplitBillDialog> {
  double total = 0;
  List<String> people = [];
  final TextEditingController _c = TextEditingController();
  final TextEditingController _totalC = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _billRef =>
      widget.firestoreService.billData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await _billRef.get();
      if (doc.exists) {
        final data = doc.data()!;
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

// ---------------------------------------------------------------------------
// 12. PackingListPage
// ---------------------------------------------------------------------------

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
  final Map<String, bool> _checked = {};
  final TextEditingController _addC = TextEditingController();

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

  Widget _buildList(String cat) {
    final items = _categories[cat] ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addC,
                  decoration: InputDecoration(
                    hintText: '新增到 $cat',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (_addC.text.isNotEmpty) {
                    setState(() {
                      _categories[cat]!.add(_addC.text);
                      _addC.clear();
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
            itemBuilder: (_, i) {
              final item = items[i];
              final checked = _checked[item] ?? false;
              return CheckboxListTile(
                title: Text(
                  item,
                  style: TextStyle(
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? Colors.grey : Colors.black,
                  ),
                ),
                value: checked,
                onChanged: (v) => setState(() => _checked[item] = v ?? false),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 13. ShoppingListPage
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// 14. TranslatorPage
// ---------------------------------------------------------------------------

class TranslatorPage extends StatefulWidget {
  const TranslatorPage({super.key});

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

class _TranslatorPageState extends State<TranslatorPage> {
  final FlutterTts _tts = FlutterTts();

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
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
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
              itemBuilder: (_, i) {
                final item = _list[i];
                return ListTile(
                  title: Text(
                    item['jp']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    item['zh']!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.purple),
                    onPressed: () => _speak(item['jp']!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
