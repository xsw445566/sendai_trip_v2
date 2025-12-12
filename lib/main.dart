// ==========================
// FINAL main.dart (PRODUCTION READY)
// ==========================

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';

/* ---------------- Firebase ---------------- */

const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyBB6wqntt9gzoC1qHonWkSwH2NS4I9-TLY",
  authDomain: "sendai-app-18d03.firebaseapp.com",
  projectId: "sendai-app-18d03",
  storageBucket: "sendai-app-18d03.firebasestorage.app",
  messagingSenderId: "179113239546",
  appId: "1:179113239546:web:d45344e45740fe0df03a43",
);

/* ---------------- API Keys ---------------- */

const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc";
const String _flightApiKey = "73d5e5ca-a0eb-462d-8a91-62e6a7657cb9";

/* ---------------- Main ---------------- */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  FirebaseAnalytics.instance;
  runApp(const TohokuTripApp());
}

/* ---------------- Utils ---------------- */

Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(
    uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}

/* ==========================
   APP ROOT
========================== */

class TohokuTripApp extends StatelessWidget {
  const TohokuTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STARLUX Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF9E8B6E),
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return s.hasData
              ? ElegantItineraryPage(uid: s.data!.uid)
              : const LoginPage();
        },
      ),
    );
  }
}
/* ==========================
   MODELS
========================== */

class FlightInfo {
  String id;
  String flightNo;
  String fromCode;
  String toCode;
  String date;
  String schedDep;
  String schedArr;
  String estDep;
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

  Map<String, dynamic> toMap() => {
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
  int dayIndex;

  Activity({
    required this.id,
    required this.time,
    required this.title,
    this.location = '',
    this.notes = '',
    this.detailedInfo = '',
    this.cost = 0,
    this.type = ActivityType.sight,
    required this.dayIndex,
  });

  Map<String, dynamic> toMap() => {
    'time': time,
    'title': title,
    'location': location,
    'notes': notes,
    'detailedInfo': detailedInfo,
    'cost': cost,
    'type': type.index,
    'dayIndex': dayIndex,
  };

  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Activity(
      id: doc.id,
      time: d['time'] ?? '00:00',
      title: d['title'] ?? '',
      location: d['location'] ?? '',
      notes: d['notes'] ?? '',
      detailedInfo: d['detailedInfo'] ?? '',
      cost: (d['cost'] ?? 0).toDouble(),
      type: ActivityType.values[d['type'] ?? 0],
      dayIndex: d['dayIndex'] ?? 0,
    );
  }
}

/* ==========================
   LOGIN PAGE
========================== */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool isLogin = true;
  String err = '';

  Future<void> submit() async {
    setState(() => err = '');
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pw.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pw.text.trim(),
        );
      }
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9E8B6E),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight_takeoff, size: 48),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _pw,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (err.isNotEmpty)
                  Text(err, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: submit,
                  child: Text(isLogin ? '登入' : '註冊'),
                ),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(isLogin ? '建立帳號' : '已有帳號'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/* ==========================
   MAIN ITINERARY PAGE
========================== */

class ElegantItineraryPage extends StatefulWidget {
  final String uid;
  const ElegantItineraryPage({super.key, required this.uid});

  @override
  State<ElegantItineraryPage> createState() => _ElegantItineraryPageState();
}

class _ElegantItineraryPageState extends State<ElegantItineraryPage> {
  final PageController _pageController = PageController();
  int _dayIndex = 0;

  Timer? _clockTimer;
  Timer? _flightTimer;
  String _time = '';

  final String _city = 'Sendai';
  String _temp = '--°';
  String _cond = '';
  IconData _weatherIcon = Icons.cloud;

  CollectionReference get _actRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .collection('activities');

  CollectionReference get _flightRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .collection('flights');

  CollectionReference get _globalFlightRef =>
      FirebaseFirestore.instance.collection('flights');

  final FlightInfo _defaultOut = FlightInfo(
    id: 'default_out',
    flightNo: 'JX862',
    fromCode: 'TPE',
    toCode: 'SDJ',
    date: '01-16',
    schedDep: '11:50',
    schedArr: '16:00',
    terminal: '1',
    gate: '-',
    counter: '-',
    baggage: '-',
    status: 'scheduled',
  );

  final FlightInfo _defaultIn = FlightInfo(
    id: 'default_in',
    flightNo: 'JX863',
    fromCode: 'SDJ',
    toCode: 'TPE',
    date: '01-20',
    schedDep: '17:30',
    schedArr: '20:40',
    terminal: 'I',
    gate: '-',
    counter: '-',
    baggage: '-',
    status: 'scheduled',
  );

  @override
  void initState() {
    super.initState();
    _tick();
    _fetchWeather();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _flightTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAllFlights(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _flightTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    final n = DateTime.now();
    setState(() {
      _time =
          '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    });
  }

  /* ---------- WEATHER ---------- */

  Future<void> _fetchWeather() async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$_city&appid=$_weatherApiKey&units=metric&lang=zh_tw',
      );
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        setState(() {
          _temp = '${d['main']['temp'].round()}°';
          _cond = d['weather'][0]['description'];
        });
      }
    } catch (_) {}
  }

  /* ---------- AIRLABS API ---------- */

  Future<FlightInfo?> _fetchApiData(String flightNo) async {
    if (flightNo.isEmpty) return null;
    try {
      final url = Uri.parse(
        'https://airlabs.co/api/v9/schedules?flight_iata=$flightNo&api_key=$_flightApiKey',
      );
      final r = await http.get(url);
      if (r.statusCode != 200) return null;

      final j = json.decode(r.body);
      if (j['response'] == null || j['response'].isEmpty) return null;
      final d = j['response'][0];

      String t(String? s) =>
          s != null && s.length >= 16 ? s.substring(11, 16) : '';

      return FlightInfo(
        id: '',
        flightNo: d['flight_iata'] ?? flightNo,
        fromCode: d['dep_iata'] ?? '',
        toCode: d['arr_iata'] ?? '',
        date: d['dep_time']?.substring(5, 10) ?? '',
        schedDep: t(d['dep_time']),
        schedArr: t(d['arr_time']),
        estDep: t(d['dep_estimated']),
        estArr: t(d['arr_estimated']),
        terminal: d['dep_terminal'] ?? '-',
        gate: d['dep_gate'] ?? '-',
        counter: '-',
        baggage: d['arr_baggage'] ?? '-',
        status: d['status'] ?? 'scheduled',
        delay: d['dep_delayed'] ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /* ---------- FLIGHT SYNC ---------- */

  Future<void> _refreshAllFlights() async {
    final snap = await _flightRef.get();
    for (var d in snap.docs) {
      await _refreshSingleFlight(FlightInfo.fromFirestore(d), silent: true);
    }
  }

  Future<void> _refreshSingleFlight(FlightInfo f, {bool silent = false}) async {
    final api = await _fetchApiData(f.flightNo);
    if (api == null) return;

    f
      ..date = api.date
      ..schedDep = api.schedDep
      ..schedArr = api.schedArr
      ..estDep = api.estDep
      ..estArr = api.estArr
      ..terminal = api.terminal
      ..gate = api.gate
      ..baggage = api.baggage
      ..status = api.status
      ..delay = api.delay;

    await _flightRef.doc(f.id).update(f.toMap());
    await _globalFlightRef.doc(f.id).set({
      ...f.toMap(),
      'uid': widget.uid,
    }, SetOptions(merge: true));

    if (!silent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('航班已同步')));
    }
  }

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(_time, style: const TextStyle(fontSize: 42)),
          Text('$_temp $_cond'),
          _buildFlightCarousel(),
          Expanded(child: _buildDayPages()),
        ],
      ),
    );
  }

  Widget _buildFlightCarousel() {
    return SizedBox(
      height: 180,
      child: StreamBuilder<QuerySnapshot>(
        stream: _flightRef.snapshots(),
        builder: (_, s) {
          List<FlightInfo> flights = s.hasData && s.data!.docs.isNotEmpty
              ? s.data!.docs.map((d) => FlightInfo.fromFirestore(d)).toList()
              : [_defaultOut, _defaultIn];

          return PageView(children: flights.map(_flightCard).toList());
        },
      ),
    );
  }

  Widget _flightCard(FlightInfo f) {
    return GestureDetector(
      onLongPress: () => _refreshSingleFlight(f),
      child: Card(
        margin: const EdgeInsets.all(12),
        child: ListTile(
          title: Text('${f.flightNo} ${f.fromCode}→${f.toCode}'),
          subtitle: Text('${f.schedDep} - ${f.schedArr}'),
          trailing: Text(f.status),
        ),
      ),
    );
  }

  Widget _buildDayPages() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (i) => setState(() => _dayIndex = i),
      itemCount: 5,
      itemBuilder: (_, i) =>
          DayItineraryWidget(dayIndex: i, onAddPressed: _addActivity),
    );
  }

  void _addActivity() {
    final a = Activity(
      id: '',
      time: '00:00',
      title: '新行程',
      dayIndex: _dayIndex,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          activity: a,
          onSave: (x) => _actRef.add(x.toMap()),
        ),
      ),
    );
  }
}
/* ==========================
   DAY ITINERARY
========================== */

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
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('activities')
        .where('dayIndex', isEqualTo: dayIndex);

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: ref.snapshots(),
          builder: (_, s) {
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final acts =
                s.data!.docs.map((d) => Activity.fromFirestore(d)).toList()
                  ..sort((a, b) => a.time.compareTo(b.time));

            if (acts.isEmpty) {
              return const Center(
                child: Text('尚無行程', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: acts.length,
              itemBuilder: (_, i) {
                final a = acts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Text(
                      a.time,
                      style: const TextStyle(
                        color: Color(0xFF9E8B6E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text(a.title),
                    subtitle: a.location.isNotEmpty ? Text(a.location) : null,
                    trailing: a.cost > 0 ? Text('¥${a.cost.toInt()}') : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailPage(
                            activity: a,
                            onSave: (u) {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('activities')
                                  .doc(a.id)
                                  .update(u.toMap());
                            },
                            onDelete: () {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('activities')
                                  .doc(a.id)
                                  .delete();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: onAddPressed,
            backgroundColor: const Color(0xFF9E8B6E),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/* ==========================
   ACTIVITY DETAIL
========================== */

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
  late TextEditingController _title;
  late TextEditingController _time;
  late TextEditingController _loc;
  late TextEditingController _cost;
  late TextEditingController _note;
  late ActivityType _type;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.activity.title);
    _time = TextEditingController(text: widget.activity.time);
    _loc = TextEditingController(text: widget.activity.location);
    _cost = TextEditingController(text: widget.activity.cost.toString());
    _note = TextEditingController(text: widget.activity.notes);
    _type = widget.activity.type;
  }

  void _save() {
    widget.activity
      ..title = _title.text
      ..time = _time.text
      ..location = _loc.text
      ..cost = double.tryParse(_cost.text) ?? 0
      ..notes = _note.text
      ..type = _type;
    widget.onSave(widget.activity);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行程編輯'),
        backgroundColor: const Color(0xFF9E8B6E),
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _time,
              decoration: const InputDecoration(labelText: '時間'),
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '標題'),
            ),
            TextField(
              controller: _loc,
              decoration: const InputDecoration(labelText: '地點'),
            ),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '花費'),
            ),
            DropdownButtonFormField<ActivityType>(
              value: _type,
              items: ActivityType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '備註'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ==========================
   PLACEHOLDER TOOLS
========================== */

class PackingListPage extends StatelessWidget {
  const PackingListPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Packing List')));
}

class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Shopping List')));
}

class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Translator')));
}

class MapListPage extends StatelessWidget {
  const MapListPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Map')));
}

class AdvancedSplitBillDialog extends StatelessWidget {
  const AdvancedSplitBillDialog({super.key});
  @override
  Widget build(BuildContext context) =>
      const AlertDialog(content: Text('Split Bill'));
}
