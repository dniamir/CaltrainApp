import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const CaltrainApp());
}

class CaltrainApp extends StatelessWidget {
  const CaltrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caltrain Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const CaltrainHomePage(),
    );
  }
}

class CaltrainHomePage extends StatefulWidget {  // Inherits stateful widget
  const CaltrainHomePage({super.key});  // 

  @override
  State<CaltrainHomePage> createState() => _CaltrainHomePageState();  // Overrid the base class with this function for createState
}

class _CaltrainHomePageState extends State<CaltrainHomePage> {
  List<String> stations = [];
  List<dynamic> schedule = [];  // Unsure what's going to be in this list, so call it dynamic
  List<dynamic> northboundSchedule = [];
  List<dynamic> southboundSchedule = [];

  String? selectedStart; // Can be empty, or can be a string
  String? selectedEnd;

  @override
  void initState() {
    super.initState();
    loadAssets();
  }

  Future<void> loadAssets() async {
    final northboundJson = await rootBundle.loadString('assets/data/caltrain_northbound_weekday.json');
    final southboundJson = await rootBundle.loadString('assets/data/caltrain_southbound_weekday.json');
    final stationCsv = await rootBundle.loadString('assets/data/caltrain_station_order.csv');

    final loadedNorth = json.decode(northboundJson);
    final loadedSouth = json.decode(southboundJson);

    final orderedStations = stationCsv
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Collect only the stations actually present in the JSON
    final usedStations = <String>{};
    for (final train in [...loadedNorth, ...loadedSouth]) {
      for (final stop in train['stops']) {
        usedStations.add(stop['station']);
      }
    }

    final sortedStations = orderedStations.where((s) => usedStations.contains(s)).toList();

    setState(() {
      northboundSchedule = loadedNorth;
      southboundSchedule = loadedSouth;
      stations = sortedStations;
      selectedStart = stations.first;
      selectedEnd = stations.last;
    });
  }

  List<Map<String, dynamic>> getFilteredTrains() {
    if (selectedStart == null || selectedEnd == null) return [];

    final startIndex = stations.indexOf(selectedStart!);
    final endIndex = stations.indexOf(selectedEnd!);

    if (startIndex == -1 || endIndex == -1 || startIndex == endIndex) return [];

    final goingSouth = startIndex < endIndex;
    final schedule = goingSouth ? southboundSchedule : northboundSchedule;

    final now = TimeOfDay.now();

    return schedule.where((train) {
      final stops = train['stops'] as List;
      final stopNames = stops.map((s) => s['station']).toList();

      if (!stopNames.contains(selectedStart) || !stopNames.contains(selectedEnd)) return false;

      final startTimeStr = (stops.firstWhere((s) => s['station'] == selectedStart))['time'];
      final endTimeStr = (stops.firstWhere((s) => s['station'] == selectedEnd))['time'];

      final startTime = _parseTime(startTimeStr);
      final isPast = _isTimeBefore(now, startTime);

      train['startTime'] = startTimeStr;
      train['endTime'] = endTimeStr;
      train['isPast'] = !isPast;
      train['isDelayed'] = false;

      return true;
    }).map<Map<String, dynamic>>((train) => Map<String, dynamic>.from(train)).toList();
  }

  TimeOfDay _parseTime(String timeStr) {
    final match = RegExp(r'(\d+):(\d+)(a|p)').firstMatch(timeStr.toLowerCase());
    if (match == null) return const TimeOfDay(hour: 0, minute: 0);

    int hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final isPM = match[3] == 'p';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeBefore(TimeOfDay now, TimeOfDay trainTime) {
    return (now.hour < trainTime.hour) ||
        (now.hour == trainTime.hour && now.minute < trainTime.minute);
  }

  @override
  Widget build(BuildContext context) {
    final trains = getFilteredTrains();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caltrain Planner'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: stations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: stations.contains(selectedStart) ? selectedStart : null,
                    isExpanded: true,
                    onChanged: (value) => setState(() => selectedStart = value),
                    items: stations.toSet().toList().map((station) =>
                      DropdownMenuItem(value: station, child: Text('From: $station'))
                    ).toList(),
                  ),
                  DropdownButton<String>(
                    value: stations.contains(selectedEnd) ? selectedEnd : null,
                    isExpanded: true,
                    onChanged: (value) => setState(() => selectedEnd = value),
                    items: stations.toSet().toList().map((station) =>
                      DropdownMenuItem(value: station, child: Text('To: $station'))
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: trains.isEmpty
                        ? const Center(child: Text("No trains available for this route."))
                        : ListView.builder(
                            itemCount: trains.length,
                            itemBuilder: (context, index) {
                              final train = trains[index];
                              final isPast = train['isPast'] == 'true';
                              final isDelayed = train['isDelayed'] == 'true';

                              final textColor = isDelayed
                                  ? Colors.red
                                  : isPast
                                      ? Colors.grey
                                      : Colors.black;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(Icons.train, color: textColor),
                                  title: Text(
                                    'Train ${train['train']}',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${train['startTime']} → ${train['endTime']}',
                                    style: TextStyle(color: textColor),
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