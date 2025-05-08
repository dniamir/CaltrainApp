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

    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString('default_from');
    final to = prefs.getString('default_to');

    selectedStart = stations.contains(from) ? from : stations.first;
    selectedEnd = stations.contains(to) ? to : stations.last;
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

      final startStop = stops.firstWhere((s) => s['station'] == selectedStart);
      final endStop = stops.firstWhere((s) => s['station'] == selectedEnd);

      final startIndex = stops.indexOf(startStop);
      final endIndex = stops.indexOf(endStop);

      if (startIndex >= endIndex) return false; // train doesn't go in desired direction

      final startTimeStr = startStop['time'];
      final endTimeStr = endStop['time'];

      final startTime = _parseTime(startTimeStr);

      final duration = _durationInMinutes(startTimeStr, endTimeStr);
      final isPast = _isTimeBefore(now, startTime);

      train['startTime'] = startTimeStr;
      train['endTime'] = endTimeStr;
      train['duration'] = duration;
      train['isPast'] = isPast;
      train['isDelayed'] = false;

      print(startTimeStr);
      print(duration);
      print(endTimeStr);
      print(" ");

      return true;
    }).map<Map<String, dynamic>>((train) => Map<String, dynamic>.from(train)).toList();
  }

  int _durationInMinutes(String startTimeStr, String endTimeStr) {
    final start = _parseTime(startTimeStr);
    final end = _parseTime(endTimeStr);

    print(start);
    print(end);

    final startDate = DateTime(2024, 1, 1, start.hour, start.minute);
    final endDate = DateTime(2024, 1, 1, end.hour, end.minute);

    final duration = endDate.difference(startDate).inMinutes;
    return duration > 0 ? duration : 0;
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            DropdownButton<String>(
                              value: stations.contains(selectedStart) ? selectedStart : null,
                              isExpanded: true,
                              onChanged: (value) => setState(() => selectedStart = value),
                              items: stations.map((station) =>
                                DropdownMenuItem(value: station, child: Text('From: $station'))
                              ).toList(),
                            ),
                            DropdownButton<String>(
                              value: stations.contains(selectedEnd) ? selectedEnd : null,
                              isExpanded: true,
                              onChanged: (value) => setState(() => selectedEnd = value),
                              items: stations.map((station) =>
                                DropdownMenuItem(value: station, child: Text('To: $station'))
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_vert, size: 32),
                            tooltip: 'Swap From/To',
                            onPressed: () {
                              setState(() {
                                final temp = selectedStart;
                                selectedStart = selectedEnd;
                                selectedEnd = temp;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: trains.isEmpty
                        ? const Center(child: Text("No trains available for this route."))
                        : ListView.builder(
                            itemCount: trains.length,
                            itemBuilder: (context, index) {
                              final train = trains[index];
                              final isPast = train['isPast'] == true;
                              final isDelayed = train['isDelayed'] == true;

                              final textColor = isDelayed
                                  ? Colors.red
                                  : isPast
                                      ? Colors.grey
                                      : Colors.black;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(Icons.train, color: textColor),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Train ${train['train']}',
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${train['startTime']} → ${train['endTime']}',
                                            style: TextStyle(color: textColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${train['duration']} min',
                                            style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                                          ),
                                        ],
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
    );
  }
}