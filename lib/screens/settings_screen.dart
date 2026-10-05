import 'package:flutter/material.dart';
import 'package:gym_progression/services/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: settings.darkMode,
              onChanged: settings.setDarkMode,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.groups_outlined),
              title: const Text('Personal trainer mode'),
              subtitle: const Text(
                'Manage clients, each with their own workouts and logs.',
              ),
              value: settings.trainerMode,
              onChanged: settings.setTrainerMode,
            ),
          ],
        ),
      ),
    );
  }
}
