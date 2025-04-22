import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

void main() {
  runApp(const CaltrainApp());
}

class CaltrainApp extends StatelessWidget {
  const CaltrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caltrain Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const CaltrainHomePage(),
    );
  }
}

class CaltrainHomePage extends StatefulWidget {
  const CaltrainHomePage({super.key});

  @override
  State<CaltrainHomePage> createState() => _CaltrainHomePageState();
}

class _CaltrainHomePageState extends State<CaltrainHomePage> {
  final Map<String, String> _stationCodeMap = {
    'San Francisco': '70011',
    '22nd Street': '70012',
    'Millbrae': '70021',
    'Palo Alto': '70111',
    'San Jose Diridon': '70231',
  };

  String _selectedStation = 'San Francisco';
  List<String> _arrivalTimes = [];
  bool _loading = false;
  final String _apiKey = '7f3f26c8-c002-4131-9bc0-5794d15893ef';

  @override
  void initState() {
    super.initState();
    _fetchTrainTimes();
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12';
    if (hour > 12) return '${hour - 12}';
    return '$hour';
  }

  Future<void> _fetchTrainTimes() async {
    setState(() => _loading = true);
    final stopCode = _stationCodeMap[_selectedStation] ?? '70011';
    final url = Uri.parse(
      'https://api.511.org/transit/StopMonitoring?api_key=$_apiKey&agency=CT&stopCode=$stopCode&format=xml',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('Response body:\n${response.body}');
        final doc = XmlDocument.parse(response.body);
        final visits = doc.findAllElements('MonitoredStopVisit');
        if (visits.isEmpty) {
          _arrivalTimes = ['No upcoming trains'];
        } else {
          _arrivalTimes = visits.map((visit) {
            final journey = visit.findElements('MonitoredVehicleJourney').first;
            final line = journey.findElements('PublishedLineName').first.text;
            final dest = journey.findElements('DestinationName').first.text;
            final timeStr = journey
                .findElements('MonitoredCall')
                .first
                .findElements('ExpectedDepartureTime')
                .first
                .text;
            final time = DateTime.parse(timeStr).toLocal();
            final formattedTime =
                '${_formatHour(time.hour)}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';
            return '$line to $dest – $formattedTime';
          }).toList();
        }
      } else {
        _arrivalTimes = ['Error: ${response.statusCode}'];
      }
    } catch (e) {
      print('ERROR: $e');
      setState(() {
        _arrivalTimes = ['Error fetching train data'];
      });
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caltrain Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedStation,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedStation = newValue);
                  _fetchTrainTimes();
                }
              },
              items: _stationCodeMap.keys.map((station) {
                return DropdownMenuItem<String>(
                  value: station,
                  child: Text(station),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Expanded(
                    child: ListView.builder(
                      itemCount: _arrivalTimes.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              _arrivalTimes[index],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

extension DateFormatting on int {
  String get hourOfDay {
    final h = this % 24;
    return h == 0 ? '12' : h > 12 ? '${h - 12}' : '$h';
  }
}