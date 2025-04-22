import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:xml/xml.dart';

void main() {
  runApp(const CaltrainApp());
}

class CaltrainApp extends StatelessWidget {
  const CaltrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caltrain Schedule',
      home: CaltrainHomePage(),
    );
  }
}

class CaltrainHomePage extends StatefulWidget {
  @override
  State<CaltrainHomePage> createState() => _CaltrainHomePageState();
}

class _CaltrainHomePageState extends State<CaltrainHomePage> {
  String _selectedStation = 'San Francisco';
  List<String> _arrivalTimes = [];
  bool _loading = false;

  final List<String> _stations = [
    'San Francisco',
    '22nd Street',
    'Millbrae',
    'Palo Alto',
    'San Jose Diridon',
  ];

Future<void> _fetchTrainTimes(String station) async {
  setState(() => _loading = true);

  // Simulated XML response (what you’d get from 511.org)
  const fakeXml = '''
  <ServiceDelivery>
    <StopMonitoringDelivery>
      <MonitoredStopVisit>
        <MonitoredVehicleJourney>
          <PublishedLineName>Train 217</PublishedLineName>
          <DestinationName>San Jose Diridon</DestinationName>
          <MonitoredCall>
            <ExpectedDepartureTime>2025-04-22T07:42:00Z</ExpectedDepartureTime>
          </MonitoredCall>
        </MonitoredVehicleJourney>
      </MonitoredStopVisit>
      <MonitoredStopVisit>
        <MonitoredVehicleJourney>
          <PublishedLineName>Train 221</PublishedLineName>
          <DestinationName>San Jose Diridon</DestinationName>
          <MonitoredCall>
            <ExpectedDepartureTime>2025-04-22T08:05:00Z</ExpectedDepartureTime>
          </MonitoredCall>
        </MonitoredVehicleJourney>
      </MonitoredStopVisit>
    </StopMonitoringDelivery>
  </ServiceDelivery>
  ''';

  final doc = XmlDocument.parse(fakeXml);
  final visits = doc.findAllElements('MonitoredStopVisit');
  final now = DateTime.now();

  final times = visits.map((visit) {
    final train = visit.findElements('MonitoredVehicleJourney').first;
    final line = train.findElements('PublishedLineName').first.text;
    final timeStr = train
        .findElements('MonitoredCall')
        .first
        .findElements('ExpectedDepartureTime')
        .first
        .text;
    final time = DateTime.parse(timeStr).toLocal();
    final formattedTime = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return '$line - $formattedTime';
  }).toList();

  setState(() {
    _arrivalTimes = times;
    _loading = false;
  });
}

//   Future<void> _fetchTrainTimes(String station) async {
//   setState(() => _loading = true);

//   final Map<String, String> _stationCodeMap = {
//     'San Francisco': '70011',
//     '22nd Street': '70012',
//     'Millbrae': '70021',
//     'Palo Alto': '70111',
//     'San Jose Diridon': '70231',
//   };

//   final apiKey = '7f3f26c8-c002-4131-9bc0-5794d15893ef'; // replace with your key
//   final stopCode = _stationCodeMap[station] ?? '70011';

//   final url = Uri.parse(
//       'https://api.511.org/transit/StopMonitoring?api_key=$apiKey&agency=CT&stopCode=$stopCode');

//   try {
//     final response = await http.get(url);

//     print('API response (${response.statusCode}):');
//     print(response.body);

//     if (response.statusCode == 200) {
//       final xml = response.body;

//       // TODO: Parse XML for actual departures — for now, just simulate
//       setState(() {
//         _arrivalTimes = [
//           'Live Train A - 10:02 AM',
//           'Live Train B - 10:34 AM',
//           'Live Train C - 11:01 AM',
//         ];
//       });
//     } else {
//       setState(() {
//         _arrivalTimes = ['Error: ${response.statusCode}'];
//       });
//     }
//   } catch (e) {
//     setState(() {
//       _arrivalTimes = ['Error fetching data: $e'];
//     });
//   }

//   setState(() => _loading = false);
// }

  @override
  void initState() {
    super.initState();
    _fetchTrainTimes(_selectedStation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caltrain Schedule')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedStation,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedStation = newValue);
                  _fetchTrainTimes(newValue);
                }
              },
              items: _stations.map((station) {
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
                        return ListTile(
                          title: Text(_arrivalTimes[index]),
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