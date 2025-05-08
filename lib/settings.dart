import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final List<String> stations;
  const SettingsPage({super.key, required this.stations});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? defaultFrom;
  String? defaultTo;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      defaultFrom = prefs.getString('default_from');
      defaultTo = prefs.getString('default_to');
    });
  }

  Future<void> _saveDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_from', defaultFrom ?? '');
    await prefs.setString('default_to', defaultTo ?? '');
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: widget.stations.contains(defaultFrom) ? defaultFrom : null,
              hint: const Text("Default From Station"),
              isExpanded: true,
              onChanged: (value) => setState(() => defaultFrom = value),
              items: widget.stations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            ),
            DropdownButton<String>(
              value: widget.stations.contains(defaultTo) ? defaultTo : null,
              hint: const Text("Default To Station"),
              isExpanded: true,
              onChanged: (value) => setState(() => defaultTo = value),
              items: widget.stations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _saveDefaults, child: const Text("Save Defaults"))
          ],
        ),
      ),
    );
  }
}