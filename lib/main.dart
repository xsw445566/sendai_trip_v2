import 'package:flutter/material.dart';

void main() {
  runApp(const HokkaidoTripApp());
}

class HokkaidoTripApp extends StatelessWidget {
  const HokkaidoTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '北海道星宇滑雪趣',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 設定星宇航空風格配色 (金/大地色系) 與 北海道雪白
        primaryColor: const Color(0xFFB4975A), // 星宇金
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB4975A)),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const ItineraryHomePage(),
    );
  }
}

// 資料模型：每日行程
class DaySchedule {
  final String date;
  final String dayLabel;
  final String title;
  final String description;
  final String hotel;
  final List<String> highlights;
  final IconData icon;

  DaySchedule({
    required this.date,
    required this.dayLabel,
    required this.title,
    required this.description,
    required this.hotel,
    required this.highlights,
    required this.icon,
  });
}

class ItineraryHomePage extends StatelessWidget {
  const ItineraryHomePage({super.key});

  // 模擬從網站抓取的行程資料 (2026/1/16 - 1/20)
  static List<DaySchedule> itineraryList = [
    DaySchedule(
      date: '1/16 (五)',
      dayLabel: 'Day 1',
      title: '啟程：星宇直飛北海道',
      description: '集合於桃園機場，搭乘星宇航空豪華客機飛往新千歲空港。抵達後專車前往溫泉區，享受北國著名的露天風呂，洗去旅途疲憊。',
      hotel: '定山溪 萬世閣 或 登別 石水亭',
      highlights: ['桃園機場集合 (JX850)', '新千歲機場', '溫泉迎賓會席料理'],
      icon: Icons.flight_takeoff,
    ),
    DaySchedule(
      date: '1/17 (六)',
      dayLabel: 'Day 2',
      title: '浪漫小樽與玩雪體驗',
      description: '早餐後前往滑雪樂園享受玩雪樂趣。下午漫步於充滿大正浪漫氣息的小樽運河，參觀音樂盒堂與北一硝子館。',
      hotel: '札幌市區 普米爾椿 或 同級',
      highlights: ['雪上樂園(雪盆/甜甜圈)', '小樽運河散策', '銀之鐘咖啡(贈杯)', '北一硝子館'],
      icon: Icons.snowboarding,
    ),
    DaySchedule(
      date: '1/18 (日)',
      dayLabel: 'Day 3',
      title: '神宮參拜與免稅購物',
      description: '參拜北海道總鎮守「北海道神宮」，隨後前往免稅店選購伴手禮。午餐後前往旭山動物園(或尼克斯)，晚上享用三大螃蟹吃到飽。',
      hotel: '札幌市區 普米爾椿 或 同級',
      highlights: ['北海道神宮', '免稅店 Duty Free', '旭山動物園(企鵝散步)', '三大蟹吃到飽'],
      icon: Icons.temple_buddhist,
    ),
    DaySchedule(
      date: '1/19 (一)',
      dayLabel: 'Day 4',
      title: '札幌市區 自由探索',
      description: '全日自由活動。推薦前往大通公園、時計台拍照，或至狸小路商店街大肆採購藥妝與土產。晚餐可自行探索札幌拉麵橫丁。',
      hotel: '札幌市區 普米爾椿 或 同級',
      highlights: ['大通公園', '時計台(路經)', '狸小路商店街', '自由尋訪美食'],
      icon: Icons.shopping_bag,
    ),
    DaySchedule(
      date: '1/20 (二)',
      dayLabel: 'Day 5',
      title: '滿載而歸',
      description: '早餐後整理行囊，前往三井Outlet Park做最後衝刺。隨後前往機場，搭乘星宇航空返回溫暖的家。',
      hotel: '溫暖的家',
      highlights: ['三井 Outlet Park', '新千歲機場採買', '星宇航空 (JX851)'],
      icon: Icons.flight_land,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('北海道星宇 5日遊', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('2026/01/16 - 01/20', style: TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C2C), // 深色背景質感
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share, color: Colors.white)),
        ],
      ),
      body: Column(
        children: [
          // 頂部橫幅 Banner
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1548263594-a71ea65a85b8?q=80&w=2076&auto=format&fit=crop'), // 網路上的北海道圖片
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Tour Code: NSA011605JX6',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          
          // 行程列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: itineraryList.length,
              itemBuilder: (context, index) {
                final item = itineraryList[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // 點擊卡片跳轉到詳情頁
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DetailPage(schedule: item)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // 左側日期圈圈
                          Column(
                            children: [
                              Text(item.dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB4975A))),
                              const SizedBox(height: 4),
                              CircleAvatar(
                                backgroundColor: const Color(0xFF2C2C2C),
                                radius: 24,
                                child: Icon(item.icon, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // 右側文字資訊
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(
                                  item.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
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

// 行程詳情頁面
class DetailPage extends StatelessWidget {
  final DaySchedule schedule;

  const DetailPage({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(schedule.dayLabel),
        backgroundColor: const Color(0xFFB4975A), // 星宇金
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 頂部大標題區
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: const Color(0xFFF0E6D2), // 淡金色背景
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(schedule.icon, size: 30, color: const Color(0xFF8C7335)),
                      const SizedBox(width: 10),
                      Text(schedule.date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8C7335))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(schedule.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 詳細介紹
                  const Text('行程介紹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    schedule.description,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                  const Divider(height: 40),

                  // 重點 Highlight
                  const Text('今日亮點', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...schedule.highlights.map((point) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Text(point, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  )),
                  const Divider(height: 40),

                  // 住宿資訊
                  const Text('住宿安排', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hotel, color: Colors.blueGrey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(schedule.hotel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}