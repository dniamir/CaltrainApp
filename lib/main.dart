import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:caltrain_app/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Debug params
const String apiKey = '7f3f26c8-c002-4131-9bc0-5794d15893ef';
const bool debugTimeOfDay = false;
const bool debugAPIRequest = true;
const String debugTimeString = "10:30 AM";
const double fontSize = 15;

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

Future<Map<String, dynamic>> getVehicleData({bool debugRealtime = false}) async {
  
  // Debug support for getting a predefined late Caltrain schedule
  // Train 168 heading southbound should be late
  if (debugRealtime) {
    final String response = await rootBundle.loadString('assets/data/debug_vehicle_monitoring.json');
    return json.decode(response);

  // Load from API using a URL request
  } else {
    
    final uri = Uri.https('api.511.org', '/transit/VehicleMonitoring', {'api_key': apiKey, 'agency': 'CT',},);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data from API');
    }
  }
}

Future<Map<String, int>> fetchDelayByVehicleRef() async {

  final data = await getVehicleData(debugRealtime: debugAPIRequest); // or false for live
  final vehicleActivities = data['Siri']['ServiceDelivery']['VehicleMonitoringDelivery']['VehicleActivity'];
  Map<String, int> delayByVehicleRef = {};

  for (var activity in vehicleActivities) {
    final journey = activity['MonitoredVehicleJourney'];
    final vehicleRef = journey['VehicleRef'];

    // Departure delay
    final aimed = DateTime.parse(journey['MonitoredCall']['AimedDepartureTime']);
    final expected = DateTime.parse(journey['MonitoredCall']['ExpectedDepartureTime']);

    final delayMinutes = expected.difference(aimed).inMinutes;
    delayByVehicleRef[vehicleRef] = delayMinutes > 0 ? delayMinutes : 0;
  }

  return delayByVehicleRef;
  
}

class _CaltrainHomePageState extends State<CaltrainHomePage> {
  List<String> stations = [];
  List<dynamic> schedule = [];  // Unsure what's going to be in this list, so call it dynamic
  List<dynamic> northboundSchedule = [];
  List<dynamic> southboundSchedule = [];

  String? selectedStart; // Can be empty, or can be a string
  String? selectedEnd;
  bool delayed = false;

  final List<GlobalKey> _trainKeys = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadAssets();
  }

  Future<Map<String, String>> fetchLiveDelays() async {
  final url = Uri.parse('https://api.511.org/transit/vehicle-monitoring?agency=CT&api_key=$apiKey');

  try {
    final response = await http.get(url);

    if (response.statusCode != 200) {
      print('Failed to fetch live data: ${response.statusCode}');
      return {};
    }

    final data = json.decode(response.body);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
    print('--- Pretty Printed API Response ---\n$prettyJson');

    final activities = data['Siri']['ServiceDelivery']['VehicleMonitoringDelivery'][0]['VehicleActivity'];
    final Map<String, String> delayedTrains = {};

    for (final activity in activities) {
      final journey = activity['MonitoredVehicleJourney'];
      final trainId = journey['PublishedLineName'];
      final expectedDeparture = journey['MonitoredCall']?['ExpectedDepartureTime'];

      if (expectedDeparture != null) {
        delayedTrains[trainId] = expectedDeparture;
      }
    }

    return delayedTrains;
  } catch (e) {
    print('Error fetching live delays: $e');
    return {};
  }
}

  Future<void> loadAssets() async {
    
    // Check if it's a weekday or weekend (minus 3 hours)
    final now = DateTime.now().subtract(const Duration(hours: 3));
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    // Load schedule based on weekday vs weekend
    final northboundJson = await rootBundle.loadString(
      isWeekend
          ? 'assets/data/caltrain_northbound_weekend.json'
          : 'assets/data/caltrain_northbound_weekday.json',
    );
    final southboundJson = await rootBundle.loadString(
      isWeekend
          ? 'assets/data/caltrain_southbound_weekend.json'
          : 'assets/data/caltrain_southbound_weekday.json',
    );

    // Load caltrain stations
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

    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString('default_from');
    final to = prefs.getString('default_to');

    setState(() {
      northboundSchedule = loadedNorth;
      southboundSchedule = loadedSouth;
      stations = sortedStations;
      selectedStart = stations.contains(from) ? from : stations.first;
      selectedEnd = stations.contains(to) ? to : stations.last;
      delayed = false;
    });

    selectedStart = stations.contains(from) ? from : stations.first;
    selectedEnd = stations.contains(to) ? to : stations.last;
  }

  Future<List<Map<String, dynamic>>> getFilteredTrains() async {

    // Get live train data
    final delayMap = await fetchDelayByVehicleRef(); // Use in init or provider

    if (selectedStart == null || selectedEnd == null) return [];

    final startIndex = stations.indexOf(selectedStart!);
    final endIndex = stations.indexOf(selectedEnd!);

    if (startIndex == -1 || endIndex == -1 || startIndex == endIndex) return [];

    final goingSouth = startIndex < endIndex;
    final schedule = goingSouth ? southboundSchedule : northboundSchedule;

    final now = debugTimeOfDay ? _parseTime(debugTimeString) : TimeOfDay.now();
    // print(now, TimeOfDay.now());
    print('$now ${TimeOfDay.now()}');

    final scrollToIndex = schedule.indexWhere((train) {
      final stops = train['stops'] as List;
      final stop = stops.firstWhere((s) => s['station'] == selectedStart, orElse: () => null);
      if (stop == null) return false;

      final time = _parseTime(stop['time']);
      return _isTimeBefore(now, time); // future train
    });

    return schedule.where((train) {
      final stops = train['stops'] as List;
      final stopNames = stops.map((s) => s['station']).toList();

      // Get train ID and delay map
      final trainId = train['train'].toString();
      final delay = delayMap[trainId];

      if (!stopNames.contains(selectedStart) || !stopNames.contains(selectedEnd)) return false;

      final startStop = stops.firstWhere((s) => s['station'] == selectedStart);
      final endStop = stops.firstWhere((s) => s['station'] == selectedEnd);

      final startIndex = stops.indexOf(startStop);
      final endIndex = stops.indexOf(endStop);

      if (startIndex >= endIndex) return false; // train doesn't go in desired direction

      // Read and parse start/end times
      final startTimeStr = startStop['time'];
      final endTimeStr = endStop['time'];

      final startTime = _parseTime(startTimeStr);
      final endTime = _parseTime(endTimeStr);

      // Get stats
      final duration = _durationInMinutes(startTime, endTime);
      // final isPast = _isTimeBefore(now, startTime);
      bool isPast = _durationInMinutes(startTime, now) > 0;



      // Set card properties
      train['startTime'] = startTimeStr;
      train['endTime'] = endTimeStr;
      train['duration'] = duration;
      train['isPast'] = isPast;
      train['isDelayed'] = false;

      // If train is delayed and hasn't already left
      if (delay != null && isPast) {
        if (delay > 0) {
          TimeOfDay newStartTime = _addMinutes(startTime, delay);
          TimeOfDay newEndTime = _addMinutes(endTime, delay);

          train['startTime'] = _formatTimeOfDay(newStartTime);
          train['endTime'] = _formatTimeOfDay(newEndTime);
          train['isDelayed'] = true;
        }
      }

      return true;
    }).map<Map<String, dynamic>>((train) => Map<String, dynamic>.from(train)).toList();
  }

  int _durationInMinutes(TimeOfDay startTime, TimeOfDay endTime) {
    
    // Make exception for early morning hours
    int start_day = 1;
    int end_day = 1;
    if (startTime.hour < 4) {start_day = 2;};
    if (endTime.hour < 4) {end_day = 2;};

    final startDate = DateTime(2024, 1, start_day, startTime.hour, startTime.minute);
    final endDate = DateTime(2024, 1, end_day, endTime.hour, endTime.minute);
    final duration = endDate.difference(startDate).inMinutes;

    return duration > 0 ? duration : 0;
  }

  TimeOfDay _addMinutes(TimeOfDay startTime, int minutes) {
    
    final startDate = DateTime(2024, 1, 1, startTime.hour, startTime.minute);
    final endDate = startDate.add(Duration(minutes: minutes));
    final endTime = TimeOfDay(hour: endDate.hour, minute: endDate.minute);

    return endTime;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    int hour = time.hour;
    int minute = time.minute;

    // Handle early morning (24–27) wrapped hours
    if (hour >= 24) {hour -= 24;}

    String suffix = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;

    String minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }

  TimeOfDay _parseTime(String timeStr) {
    final match = RegExp(r'(\d+):(\d+)\s*(a|p)m').firstMatch(timeStr.toLowerCase());
    if (match == null) return const TimeOfDay(hour: 0, minute: 0);

    int hour = int.parse(match[1]!);
    int minute = int.parse(match[2]!);
    bool isPM = match[3]!.toLowerCase() == 'p';

    // bool isEarlyMorning = hour <= 3;

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour += 12;
    // if (!isPM && isEarlyMorning) hour += 24;

    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    bool hourCheck1 = time1.hour < time2.hour;
    bool hourCheck2 = time1.hour == time2.hour;
    bool minuteCheck = time1.minute < time2.minute;
    bool finalCheck = hourCheck1 || (hourCheck2 && minuteCheck);
    return finalCheck;
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Caltrain Planner'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: "Settings",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(stations: stations),
              ),
            );
          },
        ),
      ],
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
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: getFilteredTrains(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final trains = snapshot.data!;
                      if (trains.isEmpty) {
                        return const Center(child: Text("No trains available for this route."));
                      }

                      // Resize _trainKeys to match
                      if (_trainKeys.length > trains.length) {
                        _trainKeys.removeRange(trains.length, _trainKeys.length);
                      }
                      while (_trainKeys.length < trains.length) {
                        _trainKeys.add(GlobalKey());
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final now = debugTimeOfDay ? _parseTime(debugTimeString) : TimeOfDay.now();
                        final firstFutureIndex = trains.indexWhere((t) {
                          final time = _parseTime(t['startTime']);
                          return _isTimeBefore(now, time);
                        });
                        if (firstFutureIndex != -1 && _trainKeys.length > firstFutureIndex) {
                          final context = _trainKeys[firstFutureIndex].currentContext;
                          if (context != null) {
                            Scrollable.ensureVisible(
                              context,
                              duration: Duration(milliseconds: 300),
                              alignment: 0.1,
                            );
                          }
                        }
                      });

                      return ListView.builder(
                        itemCount: trains.length,
                        controller: _scrollController,
                        itemBuilder: (context, index) {
                          final key = _trainKeys[index];
                          final train = trains[index];
                          final isPast = train['isPast'] == true;
                          final isDelayed = train['isDelayed'] == true;

                          final textColor = isPast
                              ? Colors.black
                              : Colors.grey;
                          
                          final timeTextColor = isDelayed
                              ? Colors.red
                              : isPast
                                  ? Colors.black
                                  : Colors.grey;

                          final backgroundColor = isPast
                              ? Colors.white
                              : Colors.grey.shade800;

                          return Card(
                            color: backgroundColor,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            key: key,
                            child: ListTile(
                              leading: Icon(Icons.train, color: textColor),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Train ${train['train']}',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: fontSize),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${train['startTime']} → ${train['endTime']}',
                                        style: TextStyle(color: timeTextColor, fontSize: fontSize),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${train['duration']} min',
                                        style: TextStyle(color: timeTextColor, fontStyle: FontStyle.italic, fontSize: fontSize),
                                      ),
                                    ],
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
  );
}
}