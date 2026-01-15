import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  double _rate = 0.0;
  double _amount = 1.0;
  String _fromCurrency = "TWD";
  String _toCurrency = "JPY";
  bool _isLoading = true;

  final List<String> _currencies = [
    "TWD",
    "JPY",
    "USD",
    "KRW",
    "EUR",
    "CNY",
    "HKD",
    "THB",
  ];

  @override
  void initState() {
    super.initState();
    _fetchRate();
  }

  Future<void> _fetchRate() async {
    setState(() => _isLoading = true);
    try {
      // 使用免費匯率 API
      final url = Uri.parse(
        "https://api.exchangerate-api.com/v4/latest/$_fromCurrency",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _rate = data['rates'][_toCurrency].toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("匯率獲取失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("匯率換算"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildCurrencyCard("從", _fromCurrency, true, (val) {
              setState(() => _fromCurrency = val!);
              _fetchRate();
            }),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Icon(Icons.arrow_downward, color: Colors.orange),
            ),
            _buildCurrencyCard("換算為", _toCurrency, false, (val) {
              setState(() => _toCurrency = val!);
              _fetchRate();
            }),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text("目前的匯率", style: TextStyle(color: Colors.grey[600])),
                    Text(
                      "1 $_fromCurrency = $_rate $_toCurrency",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text("試算結果", style: TextStyle(color: Colors.grey[600])),
                    Text(
                      "${(_amount * _rate).toStringAsFixed(2)} $_toCurrency",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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

  Widget _buildCurrencyCard(
    String label,
    String value,
    bool isInput,
    Function(String?) onChanged,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: isInput
                  ? TextField(
                      decoration: InputDecoration(
                        labelText: label,
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          setState(() => _amount = double.tryParse(v) ?? 0),
                    )
                  : Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            DropdownButton<String>(
              value: value,
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
