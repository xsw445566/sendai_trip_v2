class Weather {
  final double temperature;
  final String description;
  final String icon;
  final String cityName;

  Weather({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.cityName,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: json['main']['temp'].toDouble(),
      description: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      cityName: json['name'],
    );
  }
}
