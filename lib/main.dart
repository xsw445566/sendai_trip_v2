import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// ★★★ 1. Firebase 設定區 (已填入你的 Key) ★★★
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
// ★★★ 2. 天氣 API Key (已填入你的 Key) ★★★
// ---------------------------------------------------------------------------
const String _weatherApiKey = "956b9c1aeed5b382fd6aa09218369bbc"; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
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
// 備份資料 (用於一鍵還原)
// ---------------------------------------------------------------------------
final List<Activity> _backupData = [
  // Day 1
  Activity(id: '', dayIndex: 0, time: '07:25', title: '桃園機場集合', location: '第二航廈', notes: '星宇航空櫃檯', type: ActivityType.transport),
  Activity(id: '', dayIndex: 0, time: '11:50', title: '搭機前往仙台', location: 'JX862', type: ActivityType.transport),
  Activity(id: '', dayIndex: 0, time: '16:00', title: '抵達仙台機場', location: '仙台空港', type: ActivityType.transport),
  Activity(id: '', dayIndex: 0, time: '18:00', title: '仙台市區逛街', location: '一番町', notes: '晚餐自理，推薦牛舌', type: ActivityType.shop, cost: 5000),
  // Day 2
  Activity(id: '', dayIndex: 1, time: '09:00', title: '藏王樹冰纜車', location: '藏王山麓站', notes: '冬季限定 ICE MONSTER', cost: 3000, type: ActivityType.sight, imageUrls: ['https://images.unsplash.com/photo-1548263594-a71ea65a85b8?q=80']),
  Activity(id: '', dayIndex: 1, time: '13:00', title: '銀山溫泉散策', location: '銀山溫泉', notes: '神隱少女場景', type: ActivityType.sight, imageUrls: ['https://images.unsplash.com/photo-1533052445851-913437142b78?q=80']),
  Activity(id: '', dayIndex: 1, time: '18:00', title: '飯店會席料理', location: '天童溫泉', type: ActivityType.food),
  // Day 3
  Activity(id: '', dayIndex: 2, time: '09:30', title: '飯豊雪上樂園', location: '飯豊', notes: '無限暢玩雪上摩托車', type: ActivityType.sight, imageUrls: ['https://images.unsplash.com/photo-1551524559-8af4e6624178?q=80']),
  Activity(id: '', dayIndex: 2, time: '14:00', title: '南陽熊野大社', location: '熊野大社', notes: '尋找三隻兔子', type: ActivityType.sight),
  Activity(id: '', dayIndex: 2, time: '16:00', title: '大和川酒造', location: '喜多方', notes: '試飲日本酒', type: ActivityType.shop),
  // Day 4
  Activity(id: '', dayIndex: 3, time: '10:00', title: '大內宿', location: '大內宿', notes: '日本三大茅葺屋聚落', type: ActivityType.sight, imageUrls: ['https://images.unsplash.com/photo-1533423376241-750f6820464f?q=80']),
  Activity(id: '', dayIndex: 3, time: '13:00', title: '會津鐵道體驗', location: '湯野上溫泉', notes: '茅草屋車站', type: ActivityType.transport),
  Activity(id: '', dayIndex: 3, time: '14:00', title: '蘆之牧溫泉站', location: '蘆之牧溫泉', notes: '拜訪貓咪站長', type: ActivityType.sight),
  Activity(id: '', dayIndex: 3, time: '16:00', title: '會津若松城', location: '鶴城', type: ActivityType.sight),
  // Day 5
  Activity(id: '', dayIndex: 4, time: '09:00', title: '松島遊船', location: '松島海岸', notes: '日本三景', cost: 1500, type: ActivityType.sight, imageUrls: ['https://images.unsplash.com/photo-1572535780442-8354c553835c?q=80']),
  Activity(id: '', dayIndex: 4, time: '10:30', title: '五大堂', location: '五大堂', notes: '走結緣橋', type: ActivityType.sight),
  Activity(id: '', dayIndex: 4, time: '13:00', title: 'AEON MALL 購物', location: '名取 AEON', notes: '最後衝刺', type: ActivityType.shop, cost: 20000),
  Activity(id: '', dayIndex: 4, time: '15:30', title: '前往機場', location: '仙台空港', type: ActivityType.transport),
];

// ---------------------------------------------------------------------------
// 主程式 UI
// ---------------------------------------------------------------------------

class TohokuTripApp extends StatelessWidget {
  const TohokuTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '仙台星宇絕美旅程',
      debugShowCheckedModeBanner: false,
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
  String _bgImage = 'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80';
  Timer? _timer;
  String _currentTime = '';
  
  final String _city = "Sendai";
  String _weatherTemp = "--°";
  String _weatherCond = "載入中...";
  IconData _weatherIcon = Icons.cloud_download;

  final CollectionReference _activitiesRef = FirebaseFirestore.instance.collection('activities');
  
  // 快取 Stream 防止閃爍
  late Stream<QuerySnapshot> _currentStream;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _fetchRealWeather();
    
    // 初始化時載入 Day 1
    _updateStream();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      _updateTime();
      if (t.tick % 1800 == 0) _fetchRealWeather();
    });
  }

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
      _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _fetchRealWeather() async {
    // 簡單防呆
    if (_weatherApiKey.length < 10) return;

    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$_city&appid=$_weatherApiKey&units=metric&lang=zh_tw');
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
      case '01d': return Icons.wb_sunny;
      case '01n': return Icons.nightlight_round;
      case '02d': case '02n': return Icons.wb_cloudy;
      case '03d': case '03n': return Icons.cloud;
      case '04d': case '04n': return Icons.cloud_queue;
      case '09d': case '09n': return Icons.grain;
      case '10d': case '10n': return Icons.umbrella;
      case '11d': case '11n': return Icons.flash_on;
      case '13d': case '13n': return Icons.ac_unit;
      case '50d': case '50n': return Icons.waves;
      default: return Icons.cloud;
    }
  }

  Future<void> _uploadDefaultData() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在匯入預設行程至雲端...')));
    var snapshot = await _activitiesRef.get();
    if (snapshot.docs.isNotEmpty) {
      bool confirm = await showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text('警告'),
          content: const Text('雲端資料庫看起來已經有資料了，確定要重複匯入嗎？'),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text('取消')),
            TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text('確定匯入')),
          ],
        )
      ) ?? false;
      if (!confirm) return;
    }
    for (var item in _backupData) {
      await _activitiesRef.add(item.toMap());
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('匯入完成！')));
  }

  Widget _buildTotalCostDisplay() {
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
                const Text('TOTAL EXPENSE (ALL DAYS)', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                Text('¥ ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontFamily: 'Serif', color: Color(0xFF8B2E2E))),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TODAY', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                Text('¥ ${daily.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontFamily: 'Serif', color: Colors.black87)),
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
      MaterialPageRoute(builder: (context) => ActivityDetailPage(
        activity: activity, 
        onSave: (updatedActivity) async {
          if (isNew) {
            await _activitiesRef.add(updatedActivity.toMap());
          } else {
            await _activitiesRef.doc(updatedActivity.id).update(updatedActivity.toMap());
          }
        },
        onDelete: isNew ? null : () async {
          await _activitiesRef.doc(activity.id).delete();
        },
      )),
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

  void _handleToolTap(String label) {
    if (label == '匯入資料') {
      _uploadDefaultData();
      return;
    }
    Widget page;
    switch (label) {
      case '行李': page = const PackingListPage(); break;
      case '必買': page = const ShoppingListPage(); break;
      case '翻譯': page = const TranslatorPage(); break;
      case '地圖': page = const MapListPage(); break; 
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
  
  void _showCurrencyDialog() {
    double rate = 0.215; 
    double jpy = 0;
    double twd = 0;
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('匯率換算'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '日幣 (JPY)'), onChanged: (v) => setState(() { jpy = double.tryParse(v)??0; twd = jpy*rate; })),
            Text('約 NT\$ ${twd.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          ]),
        );
      });
    });
  }

  void _showSplitBillDialog() {
    showDialog(context: context, builder: (context) => const AlertDialog(title: Text('分帳'), content: Text('請自行實作或參考前版')));
  }

  void _showChangeImageDialog() {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('背景'), content: TextField(controller: c),
      actions: [TextButton(onPressed: (){ if(c.text.isNotEmpty) setState(()=>_bgImage=c.text); Navigator.pop(ctx); }, child: const Text('OK'))]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(_bgImage, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black12, Colors.white.withOpacity(0.1), const Color(0xFFF9F8F4)], stops: const [0.0, 0.6, 1.0],
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2026.01.16 - 01.20', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 5)])),
                          Text(_currentTime, style: const TextStyle(fontFamily: 'Serif', fontSize: 60, height: 1.0, color: Color(0xFF8B2E2E), fontWeight: FontWeight.w400)), 
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Text('桃園', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.flight_takeoff, size: 20)),
                              Text('仙台', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Row(children: [Icon(Icons.location_on, size: 14, color: Colors.grey), SizedBox(width: 4), Text('Miyagi, Japan', style: TextStyle(color: Colors.grey))]),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          _fetchRealWeather();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新天氣...'), duration: Duration(seconds: 1)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Icon(_weatherIcon, color: Colors.amber, size: 32),
                              Text(_weatherTemp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text(_weatherCond, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 工具列
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildToolItem(Icons.luggage, '行李', Colors.blue, onTap: () => _handleToolTap('行李')),
                      _buildToolItem(Icons.shopping_bag, '必買', Colors.pink, onTap: () => _handleToolTap('必買')),
                      _buildToolItem(Icons.translate, '翻譯', Colors.purple, onTap: () => _handleToolTap('翻譯')),
                      _buildToolItem(Icons.map, '地圖', Colors.green, onTap: () => _handleToolTap('地圖')),
                      _buildToolItem(Icons.currency_exchange, '匯率', Colors.orange, onTap: _showCurrencyDialog),
                      _buildToolItem(Icons.diversity_3, '分帳', Colors.teal, onTap: _showSplitBillDialog),
                      _buildToolItem(Icons.cloud_upload, '匯入資料', Colors.red, onTap: () => _handleToolTap('匯入資料')), 
                      _buildToolItem(Icons.image, '換背景', Colors.grey, onTap: _showChangeImageDialog),
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
                          // 切換日期時更新 Stream
                          setState(() {
                            _selectedDayIndex = index;
                            _updateStream();
                          });
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF8B2E2E) : Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Day ${index + 1}', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                              Text('1/${16 + index}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87, fontFamily: 'Serif')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 4. 行程列表
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _currentStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('錯誤: ${snapshot.error}'));
                      
                      // 使用者體驗優化：不放 Loading 避免閃爍，直接顯示空或舊資料
                      if (!snapshot.hasData) return const SizedBox();

                      List<Activity> activities = snapshot.data!.docs.map((doc) => Activity.fromFirestore(doc)).toList();
                      
                      activities.sort((a, b) => a.time.compareTo(b.time));

                      if (activities.isEmpty) {
                         return const Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.cloud_off, size: 50, color: Colors.grey),
                               SizedBox(height: 10),
                               Text('目前沒有行程', style: TextStyle(color: Colors.grey)),
                             ],
                           )
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 18),
                                        Text(activity.time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Serif')),
                                        Expanded(child: Container(margin: const EdgeInsets.only(left: 15, top: 8, bottom: 8), width: 1, color: Colors.grey.shade300)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToDetail(activity, false),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                          border: const Border(left: BorderSide(color: Color(0xFF8B2E2E), width: 4)),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildTag(activity.type),
                                                  if (activity.cost > 0)
                                                    Text('¥${activity.cost.toInt()}', style: const TextStyle(color: Color(0xFF8B2E2E), fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(activity.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                              if (activity.location.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                                const SizedBox(height: 8),
                                                Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(activity.location, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
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
            right: 20, bottom: 90,
            child: FloatingActionButton(
              onPressed: () => _addNewActivity(_selectedDayIndex),
              backgroundColor: const Color(0xFF8B2E2E),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
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

  Widget _buildToolItem(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ActivityType type) {
    String text = ''; Color color = Colors.grey;
    switch (type) {
      case ActivityType.sight: text = '景點'; color = Colors.teal; break;
      case ActivityType.food: text = '美食'; color = Colors.orange; break;
      case ActivityType.shop: text = '購物'; color = Colors.pink; break;
      case ActivityType.transport: text = '交通'; color = Colors.blueGrey; break;
      case ActivityType.other: text = '彈性'; color = Colors.purple; break;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)));
  }
}

// ---------------------------------------------------------------------------
// 詳細資料與編輯頁面
// ---------------------------------------------------------------------------
class ActivityDetailPage extends StatefulWidget {
  final Activity activity;
  final Function(Activity) onSave;
  final VoidCallback? onDelete;

  const ActivityDetailPage({super.key, required this.activity, required this.onSave, this.onDelete});

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
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.activity.title);
    _timeC = TextEditingController(text: widget.activity.time);
    _locC = TextEditingController(text: widget.activity.location);
    _costC = TextEditingController(text: widget.activity.cost.toString());
    _noteC = TextEditingController(text: widget.activity.notes);
    _type = widget.activity.type;
    _images = List.from(widget.activity.imageUrls);
  }

  void _save() {
    widget.activity.title = _titleC.text;
    widget.activity.time = _timeC.text;
    widget.activity.location = _locC.text;
    widget.activity.cost = double.tryParse(_costC.text) ?? 0.0;
    widget.activity.notes = _noteC.text;
    widget.activity.type = _type;
    widget.activity.imageUrls = _images;
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
            IconButton(icon: const Icon(Icons.delete), onPressed: () {
              showDialog(context: context, builder: (c) => AlertDialog(
                title: const Text('確定刪除?'),
                actions: [
                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text('取消')),
                  TextButton(onPressed: (){ 
                    widget.onDelete!(); 
                    Navigator.pop(c);
                    Navigator.pop(context);
                  }, child: const Text('刪除', style: TextStyle(color: Colors.red))),
                ],
              ));
            }),
          IconButton(onPressed: _save, icon: const Icon(Icons.check))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(children: [SizedBox(width: 80, child: TextField(controller: _timeC, decoration: const InputDecoration(labelText: '時間', border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: _titleC, decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder())))]),
            const SizedBox(height: 20),
            DropdownButtonFormField<ActivityType>(value: _type, decoration: const InputDecoration(labelText: '類別', border: OutlineInputBorder()), items: ActivityType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.toString().split('.').last))).toList(), onChanged: (v) => setState(() => _type = v!)),
            const SizedBox(height: 20),
            TextField(controller: _locC, decoration: const InputDecoration(labelText: '地點', prefixIcon: Icon(Icons.map), border: OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '花費', prefixIcon: Icon(Icons.currency_yen), border: OutlineInputBorder())),
            const SizedBox(height: 20),
            TextField(controller: _noteC, maxLines: 5, decoration: const InputDecoration(labelText: '筆記', border: OutlineInputBorder())),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 功能子頁面
// ---------------------------------------------------------------------------

class PackingListPage extends StatefulWidget {
  const PackingListPage({super.key});
  @override
  State<PackingListPage> createState() => _PackingListPageState();
}
class _PackingListPageState extends State<PackingListPage> {
  final Map<String, bool> _items = {'防滑鞋': false, '暖暖包': false, '護照': false};
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('清單')), body: ListView(children: _items.keys.map((k) => CheckboxListTile(title: Text(k), value: _items[k], onChanged: (v) => setState(() => _items[k] = v!))).toList()));
  }
}

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}
class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<String> _list = ['牛舌', '清酒'];
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('必買')), body: ListView.builder(itemCount: _list.length, itemBuilder: (c, i) => ListTile(title: Text(_list[i]))));
  }
}

class TranslatorPage extends StatelessWidget {
  const TranslatorPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('翻譯')), body: const Center(child: Text('翻譯功能')));
  }
}

class MapListPage extends StatelessWidget {
  const MapListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('地圖')), body: const Center(child: Text('地圖功能 (資料已雲端化)')));
  }
}