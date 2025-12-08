import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
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

  Activity({
    required this.id,
    required this.time,
    required this.title,
    this.location = '',
    this.notes = '',
    this.cost = 0.0,
    this.type = ActivityType.sight,
  });
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
        primaryColor: const Color(0xFF8B2E2E), // 深紅
        scaffoldBackgroundColor: const Color(0xFFF9F8F4), // 米白紙質感
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
  String _bgImage = 'https://images.unsplash.com/photo-1542051841857-5f90071e7989?q=80'; // 預設背景
  Timer? _timer;
  String _currentTime = '';
  
  // 天氣資料 (模擬 Weather.com 連結內容)
  final String _weatherUrl = "https://weather.com/zh-TW/weather/today/l/46f6ead6d0822254bd95746ea4d837b07ce90579820dd8f6906d46ca8b28eae7";
  String _weatherTemp = "2°";
  String _weatherCond = "多雲時晴";
  IconData _weatherIcon = Icons.cloud;

  // 核心資料：5天的行程
  final List<List<Activity>> _dailyActivities = [
    // Day 1
    [
      Activity(id: '1-1', time: '07:25', title: '桃園機場集合', location: '第二航廈', notes: '星宇航空櫃檯', type: ActivityType.transport),
      Activity(id: '1-2', time: '11:50', title: '搭機前往仙台', location: 'JX862', type: ActivityType.transport),
      Activity(id: '1-3', time: '16:00', title: '抵達仙台機場', location: '仙台空港', type: ActivityType.transport),
      Activity(id: '1-4', time: '18:00', title: '仙台市區逛街', location: '一番町', notes: '晚餐自理，推薦牛舌', type: ActivityType.shop, cost: 5000),
    ],
    // Day 2
    [
      Activity(id: '2-1', time: '09:00', title: '藏王樹冰纜車', location: '藏王山麓站', notes: '冬季限定 ICE MONSTER', cost: 3000, type: ActivityType.sight),
      Activity(id: '2-2', time: '13:00', title: '銀山溫泉散策', location: '銀山溫泉', notes: '神隱少女場景', type: ActivityType.sight),
      Activity(id: '2-3', time: '18:00', title: '飯店會席料理', location: '天童溫泉', type: ActivityType.food),
    ],
    // Day 3
    [
      Activity(id: '3-1', time: '09:30', title: '飯豊雪上樂園', location: '飯豊', notes: '無限暢玩雪上摩托車', type: ActivityType.sight),
      Activity(id: '3-2', time: '14:00', title: '南陽熊野大社', location: '熊野大社', notes: '尋找三隻兔子', type: ActivityType.sight),
      Activity(id: '3-3', time: '16:00', title: '大和川酒造', location: '喜多方', notes: '試飲日本酒', type: ActivityType.shop),
    ],
    // Day 4
    [
      Activity(id: '4-1', time: '10:00', title: '大內宿', location: '大內宿', notes: '日本三大茅葺屋聚落', type: ActivityType.sight),
      Activity(id: '4-2', time: '13:00', title: '會津鐵道體驗', location: '湯野上溫泉', notes: '茅草屋車站', type: ActivityType.transport),
      Activity(id: '4-3', time: '14:00', title: '蘆之牧溫泉站', location: '蘆之牧溫泉', notes: '拜訪貓咪站長', type: ActivityType.sight),
      Activity(id: '4-4', time: '16:00', title: '會津若松城', location: '鶴城', type: ActivityType.sight),
    ],
    // Day 5
    [
      Activity(id: '5-1', time: '09:00', title: '松島遊船', location: '松島海岸', notes: '日本三景', cost: 1500, type: ActivityType.sight),
      Activity(id: '5-2', time: '10:30', title: '五大堂', location: '五大堂', notes: '走結緣橋', type: ActivityType.sight),
      Activity(id: '5-3', time: '13:00', title: 'AEON MALL 購物', location: '名取 AEON', notes: '最後衝刺', type: ActivityType.shop, cost: 20000),
      Activity(id: '5-4', time: '15:30', title: '前往機場', location: '仙台空港', type: ActivityType.transport),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    // 模擬天氣初始化
    _fetchWeather(); 
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

  // 模擬從 Weather.com 獲取數據的視覺效果
  void _fetchWeather() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          // 這裡模擬 1 月仙台的典型天氣
          _weatherTemp = "2°";
          _weatherCond = "多雲時陰"; 
          _weatherIcon = Icons.cloud;
        });
      }
    });
  }

  double _calculateTotalCost() {
    double total = 0;
    for (var list in _dailyActivities) {
      for (var item in list) {
        total += item.cost;
      }
    }
    return total;
  }

  double _calculateDailyCost(int dayIndex) {
    double total = 0;
    for (var item in _dailyActivities[dayIndex]) {
      total += item.cost;
    }
    return total;
  }

  // ---------------------------------------------------
  // Dialogs (功能視窗)
  // ---------------------------------------------------

  // 1. 更換背景圖片
  void _showChangeImageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更換背景圖片'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '請輸入圖片網址 (URL)', hintText: 'https://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _bgImage = controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 2. 匯率換算器
  void _showCurrencyDialog() {
    double rate = 0.215; // 預設匯率
    double jpy = 0;
    double twd = 0;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Row(children: [Icon(Icons.currency_exchange, color: Colors.orange), SizedBox(width: 8), Text('匯率換算')]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '日幣 (JPY)', suffixText: '円', border: OutlineInputBorder()),
                  onChanged: (val) {
                    setState(() {
                      jpy = double.tryParse(val) ?? 0;
                      twd = jpy * rate;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('匯率: '),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                        controller: TextEditingController(text: rate.toString()),
                        onChanged: (val) {
                          rate = double.tryParse(val) ?? 0.215;
                          setState(() => twd = jpy * rate);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text('約合台幣', style: TextStyle(color: Colors.grey)),
                      Text('NT\$ ${twd.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                )
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
          );
        });
      },
    );
  }

  // 3. 分帳計算機
  void _showSplitBillDialog() {
    double total = 0;
    int people = 2;
    double result = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          void calc() {
            if (people > 0) result = total / people;
          }
          return AlertDialog(
            title: const Row(children: [Icon(Icons.diversity_3, color: Colors.green), SizedBox(width: 8), Text('分帳計算機')]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '總金額 (円)', prefixIcon: Icon(Icons.receipt_long), border: OutlineInputBorder()),
                  onChanged: (val) {
                    setState(() {
                      total = double.tryParse(val) ?? 0;
                      calc();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('人數:', style: TextStyle(fontSize: 16)),
                    Row(
                      children: [
                        IconButton(onPressed: () => setState(() { if(people>1) people--; calc(); }), icon: const Icon(Icons.remove_circle_outline)),
                        Text('$people', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setState(() { people++; calc(); }), icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text('每人應付', style: TextStyle(color: Colors.grey)),
                      Text('¥ ${result.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                )
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉'))],
          );
        });
      },
    );
  }

  // 4. 新增/編輯行程 Dialog
  void _showEditor({Activity? activity, int? dayIndex}) {
    final bool isEditing = activity != null;
    final titleC = TextEditingController(text: isEditing ? activity.title : '');
    final timeC = TextEditingController(text: isEditing ? activity.time : '');
    final locC = TextEditingController(text: isEditing ? activity.location : '');
    final costC = TextEditingController(text: isEditing ? activity.cost.toString() : '0');
    final noteC = TextEditingController(text: isEditing ? activity.notes : '');
    ActivityType type = isEditing ? activity.type : ActivityType.sight;
    int targetDay = dayIndex ?? _selectedDayIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? '編輯行程' : '新增行程', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(children: [
                Expanded(child: TextField(controller: timeC, decoration: const InputDecoration(labelText: '時間', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextField(controller: titleC, decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: ActivityType.values.map((t) => ChoiceChip(
                label: Text(_getTypeName(t)), 
                selected: type == t,
                onSelected: (v) => setSheetState(() => type = t),
              )).toList()),
              const SizedBox(height: 10),
              TextField(controller: locC, decoration: const InputDecoration(labelText: '地點', prefixIcon: Icon(Icons.map), border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: costC, decoration: const InputDecoration(labelText: '花費', prefixIcon: Icon(Icons.currency_yen), border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextField(controller: noteC, decoration: const InputDecoration(labelText: '筆記', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B2E2E), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    if (isEditing) {
                      activity.title = titleC.text;
                      activity.time = timeC.text;
                      activity.location = locC.text;
                      activity.cost = double.tryParse(costC.text) ?? 0;
                      activity.notes = noteC.text;
                      activity.type = type;
                    } else {
                      _dailyActivities[targetDay].add(Activity(
                        id: DateTime.now().toString(), time: timeC.text, title: titleC.text,
                        location: locC.text, cost: double.tryParse(costC.text) ?? 0, notes: noteC.text, type: type
                      ));
                      _dailyActivities[targetDay].sort((a, b) => a.time.compareTo(b.time));
                    }
                  });
                  Navigator.pop(context);
                }, 
                child: const Text('儲存')
              )),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  String _getTypeName(ActivityType type) {
    switch (type) {
      case ActivityType.sight: return '景點';
      case ActivityType.food: return '美食';
      case ActivityType.shop: return '購物';
      case ActivityType.transport: return '交通';
      case ActivityType.other: return '其他';
    }
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
            child: GestureDetector(
              onLongPress: _showChangeImageDialog, // 長按換圖
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
          ),

          // 主要內容區
          SafeArea(
            child: Column(
              children: [
                // 1. 頂部資訊區 (日期、地點、天氣)
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
                      // 天氣卡 (連動 Weather.com)
                      GestureDetector(
                        onTap: () {
                          // 顯示提示並提供連結 (因為 Web APP 限制，這裡用 Dialog 顯示連結)
                          showDialog(context: context, builder: (context) => AlertDialog(
                            title: const Text('Weather.com 詳細報告'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('點擊下方按鈕或複製網址查看詳細天氣：'),
                                const SizedBox(height: 10),
                                SelectableText(_weatherUrl, style: const TextStyle(color: Colors.blue)),
                              ],
                            ),
                            actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('關閉'))],
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            border: Border.all(color: const Color(0xFFD4C5A9)), 
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              Icon(_weatherIcon, color: Colors.amber, size: 32),
                              const SizedBox(height: 4),
                              Text(_weatherTemp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
                              Text(_weatherCond, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              const Text('詳細報告 >', style: TextStyle(fontSize: 10, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 工具列 (新增 匯率 & 分帳)
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildToolItem(Icons.currency_exchange, '匯率換算', Colors.orange, onTap: _showCurrencyDialog),
                      _buildToolItem(Icons.diversity_3, '分帳', Colors.green, onTap: _showSplitBillDialog),
                      _buildToolItem(Icons.image, '換背景', Colors.grey, onTap: _showChangeImageDialog),
                      _buildToolItem(Icons.luggage, '行李', Colors.blue),
                      _buildToolItem(Icons.shopping_bag, '必買', Colors.pink),
                      _buildToolItem(Icons.translate, '翻譯', Colors.purple),
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

                // 4. 時間軸行程列表
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: _dailyActivities[_selectedDayIndex].length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = _dailyActivities[_selectedDayIndex].removeAt(oldIndex);
                        _dailyActivities[_selectedDayIndex].insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final activity = _dailyActivities[_selectedDayIndex][index];
                      return Container(
                        key: ValueKey(activity.id),
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
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showEditor(activity: activity, dayIndex: _selectedDayIndex),
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
                                          if (activity.location.isNotEmpty || activity.notes.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                            const SizedBox(height: 8),
                                          ],
                                          if (activity.location.isNotEmpty)
                                            Row(children: [const Icon(Icons.search, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(activity.location, style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.underline))]),
                                          if (activity.notes.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(activity.notes, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                            ),
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
              onPressed: () => _showEditor(dayIndex: _selectedDayIndex),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL EXPENSE (ALL DAYS)', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                      Text('¥ ${_calculateTotalCost().toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontFamily: 'Serif', color: Color(0xFF8B2E2E))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TODAY', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Colors.grey)),
                      Text('¥ ${_calculateDailyCost(_selectedDayIndex).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontFamily: 'Serif', color: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 工具列小按鈕
  Widget _buildToolItem(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打開 $label')));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ActivityType type) {
    String text = '';
    Color color = Colors.grey;
    switch (type) {
      case ActivityType.sight: text = '景點'; color = Colors.teal; break;
      case ActivityType.food: text = '美食'; color = Colors.orange; break;
      case ActivityType.shop: text = '購物'; color = Colors.pink; break;
      case ActivityType.transport: text = '交通'; color = Colors.blueGrey; break;
      case ActivityType.other: text = '彈性'; color = Colors.purple; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}