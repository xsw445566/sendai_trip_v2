import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// ★★★ Firebase 設定區 (請填入你的 Web App Config) ★★★
// ---------------------------------------------------------------------------
const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyBB6wqntt9gzoC1qHonWkSwH2NS4I9-TLY", // 例如: AIzaSyD...
  authDomain: "sendai-app-18d03.firebaseapp.com",
  projectId: "sendai-app-18d03",
  storageBucket: "sendai-app-18d03.firebasestorage.app",
  messagingSenderId: "179113239546",
  appId: "1:179113239546:web:d45344e45740fe0df03a43",
);

void main() async {
  // 確保 Flutter 引擎與 Firebase 初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    print("Firebase 初始化失敗 (若是重複初始化可忽略): $e");
  }
  runApp(const TohokuTripApp());
}

// ---------------------------------------------------------------------------
// 資料模型 (Data Models)
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
  int dayIndex; // 新增：用來區分是第幾天的行程

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

  // 轉成 Map 存入 Firebase
  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'title': title,
      'location': location,
      'notes': notes,
      'cost': cost,
      'type': type.index, // 存 enum 的索引值 (0, 1, 2...)
      'imageUrls': imageUrls,
      'dayIndex': dayIndex,
    };
  }

  // 從 Firebase 讀出
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
// 主程式
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
  
  // 天氣變數 (請填入你的 API Key)
  final String _apiKey = "請將你的OpenWeatherMap_Key貼在這裡"; 
  final String _city = "Sendai";
  
  String _weatherTemp = "--°";
  String _weatherCond = "載入中...";
  IconData _weatherIcon = Icons.cloud_download;

  // Firebase Collection 參照
  final CollectionReference _activitiesRef = FirebaseFirestore.instance.collection('activities');

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
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _fetchRealWeather() async {
    if (_apiKey.contains("OpenWeatherMap_Key")) return; // 防止未設定 Key 報錯

    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=$_city&appid=$_apiKey&units=metric&lang=zh_tw');
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

  // 計算總花費 (讀取 Firebase 串流)
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

  // 導航到詳細頁面
  void _navigateToDetail(Activity activity, bool isNew) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActivityDetailPage(
        activity: activity, 
        onSave: (updatedActivity) async {
          if (isNew) {
            // 新增到 Firebase
            await _activitiesRef.add(updatedActivity.toMap());
          } else {
            // 更新 Firebase
            await _activitiesRef.doc(updatedActivity.id).update(updatedActivity.toMap());
          }
        },
        onDelete: isNew ? null : () async {
          // 從 Firebase 刪除
          await _activitiesRef.doc(activity.id).delete();
        },
      )),
    );
  }

  // 新增行程
  void _addNewActivity(int dayIndex) {
    Activity newActivity = Activity(
      id: '', // ID 會由 Firebase 自動產生
      time: '00:00',
      title: '新行程',
      type: ActivityType.sight,
      dayIndex: dayIndex,
    );
    _navigateToDetail(newActivity, true);
  }

  // 導航功能
  void _handleToolTap(String label) {
    Widget page;
    switch (label) {
      case '行李': page = const PackingListPage(); break;
      case '必買': page = const ShoppingListPage(); break;
      case '翻譯': page = const TranslatorPage(); break;
      // 地圖暫時需傳入空列表，因為資料已在雲端
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
    // 簡單版分帳
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
          // 頂部背景圖
          Positioned(
            top: 0, left: 0, right: 0,
            height: 350,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(_bgImage, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black12, Colors.white.withOpacity(0.1), const Color(0xFFF9F8F4)], 
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
                // 1. 頂部資訊區
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
                        onTap: () => setState(() => _selectedDayIndex = index),
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

                // 4. 即時連線行程列表 (使用 StreamBuilder)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _activitiesRef
                      .where('dayIndex', isEqualTo: _selectedDayIndex)
                      .snapshots(), // 監聽資料庫變化
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('錯誤: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      // 取得資料並轉為 List<Activity>
                      List<Activity> activities = snapshot.data!.docs.map((doc) => Activity.fromFirestore(doc)).toList();
                      
                      // 在客戶端進行排序 (依照時間)
                      activities.sort((a, b) => a.time.compareTo(b.time));

                      if (activities.isEmpty) return const Center(child: Text('點擊 + 新增行程', style: TextStyle(color: Colors.grey)));

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

          // 浮動新增按鈕
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

          // 底部總花費欄
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFD4C5A9))),
              ),
              child: _buildTotalCostDisplay(), // 改用 StreamBuilder 顯示
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
  final VoidCallback? onDelete; // 新增刪除功能

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
                    Navigator.pop(c); // 關 Dialog
                    Navigator.pop(context); // 回列表
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
// 功能子頁面 (Packing, Shopping, etc.)
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