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
  final String _apiKey = '7f3f26c8-c002-4131-9bc0-5794d15893ef'; // <- Replace this!

  @override
  void initState() {
    super.initState();
    _fetchTrainTimes();
  }

  Future<void> _fetchTrainTimes() async {
    setState(() => _loading = true);
    final stopCode = _stationCodeMap[_selectedStation] ?? '70011';
    final url = Uri.parse(
      'https://api.511.org/transit/StopMonitoring?api_key=$_apiKey&agency=CT&stopCode=$stopCode&format=xml',
    );

    try {
      final response = await http.get(url);
      print('Response body:\n${response.body}');

      final doc = XmlDocument.parse(response.body);
      final visits = doc.findAllElements('MonitoredStopVisit');

      if (visits.isEmpty) {
        _arrivalTimes = [];
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
          final hour = time.hour == 0
              ? 12
              : time.hour > 12
                  ? time.hour - 12
                  : time.hour;
          final ampm = time.hour >= 12 ? 'PM' : 'AM';
          final formattedTime =
              '$hour:${time.minute.toString().padLeft(2, '0')} $ampm';
          return '$line to $dest at $formattedTime';
        }).toList();
      }
    } catch (e) {
      print('ERROR: $e');
      _arrivalTimes = ['Error fetching train data'];
    }

    setState(() => _loading = false);
  }

  Widget _buildTrainCard(String content) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.train, color: Colors.red),
        title: Text(content,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caltrain Tracker'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedStation,
              onChanged: (newVal) {
                if (newVal != null) {
                  setState(() => _selectedStation = newVal);
                  _fetchTrainTimes();
                }
              },
              items: _stationCodeMap.keys.map((station) {
                return DropdownMenuItem<String>(
                  value: station,
                  child: Text(station),
                );
              }).toList(),
              isExpanded: true,
              underline: Container(
                height: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? Center(
                    child: Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text("Fetching train data..."),
                      ],
                    ),
                  )
                : _arrivalTimes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "No upcoming trains at this time.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _arrivalTimes.length,
                          itemBuilder: (context, index) =>
                              _buildTrainCard(_arrivalTimes[index]),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}