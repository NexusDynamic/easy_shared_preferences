import 'package:flutter/material.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

/// Example showing how to use GlobalSettings for easy app-wide access
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global settings early in main()
  await GlobalSettings.initialize([
    // Game settings group
    GroupConfig(
      key: 'game',
      items: [
        BoolSetting(key: 'soundEnabled', defaultValue: true),
        DoubleSetting(
          key: 'volume',
          defaultValue: 0.8,
          validator: (value) => value >= 0.0 && value <= 1.0,
        ),
        IntSetting(
          key: 'difficulty',
          defaultValue: 1,
          validator: (value) => value >= 1 && value <= 3,
        ),
      ],
    ),
    // UI settings group
    GroupConfig(
      key: 'ui',
      items: [
        StringSetting(
          key: 'theme',
          defaultValue: 'light',
          validator: (value) => ['light', 'dark', 'auto'].contains(value),
        ),
        BoolSetting(key: 'showAnimations', defaultValue: true),
        IntSetting(
          key: 'fontSize',
          defaultValue: 14,
          validator: (value) => value >= 12 && value <= 24,
        ),
      ],
    ),
  ], enableLogging: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Settings Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Use global settings directly in theme configuration
        brightness: GlobalSettings.getString('ui.theme') == 'dark'
            ? Brightness.dark
            : Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();

    // Listen to changes in settings
    GlobalSettings.addChangeCallback((key, oldValue, newValue) {
      // Use debugPrint instead of print for better Flutter integration
      debugPrint('Setting changed: $key from $oldValue to $newValue');

      // Rebuild UI when theme changes
      if (key == 'ui.theme') {
        setState(() {});
      }
    });

    // Demonstrate adding a group after initialization
    _addNewFeatureGroup();
  }

  Future<void> _addNewFeatureGroup() async {
    // Simulate adding a new feature after app startup
    await Future.delayed(Duration(seconds: 2));

    try {
      await GlobalSettings.addGroup('newFeature', [
        BoolSetting(key: 'enabled', defaultValue: false),
        StringSetting(key: 'mode', defaultValue: 'basic'),
      ]);
      debugPrint('New feature settings added successfully!');
    } catch (e) {
      debugPrint('Error adding new feature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Global Settings Demo'),
        backgroundColor: GlobalSettings.getString('ui.theme') == 'dark'
            ? Colors.grey[800]
            : Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            // Sound toggle - access GlobalSettings directly
            SwitchListTile(
              title: Text('Sound Enabled'),
              value: GlobalSettings.getBool('game.soundEnabled'),
              onChanged: (value) async {
                await GlobalSettings.setBool('game.soundEnabled', value);
                setState(() {});
              },
            ),

            // Volume slider
            ListTile(
              title: Text(
                  'Volume: ${(GlobalSettings.getDouble('game.volume') * 100).round()}%'),
              subtitle: Slider(
                value: GlobalSettings.getDouble('game.volume'),
                onChanged: (value) async {
                  await GlobalSettings.setDouble('game.volume', value);
                  setState(() {});
                },
              ),
            ),

            // Difficulty selector
            ListTile(
              title: Text('Difficulty'),
              subtitle: DropdownButton<int>(
                value: GlobalSettings.getInt('game.difficulty'),
                items: [
                  DropdownMenuItem(value: 1, child: Text('Easy')),
                  DropdownMenuItem(value: 2, child: Text('Medium')),
                  DropdownMenuItem(value: 3, child: Text('Hard')),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await GlobalSettings.setInt('game.difficulty', value);
                    setState(() {});
                  }
                },
              ),
            ),

            SizedBox(height: 24),
            Text(
              'UI Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            // Theme selector
            ListTile(
              title: Text('Theme'),
              subtitle: DropdownButton<String>(
                value: GlobalSettings.getString('ui.theme'),
                items: [
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await GlobalSettings.setString('ui.theme', value);
                    setState(() {});
                  }
                },
              ),
            ),

            // Animation toggle
            SwitchListTile(
              title: Text('Show Animations'),
              value: GlobalSettings.getBool('ui.showAnimations'),
              onChanged: (value) async {
                await GlobalSettings.setBool('ui.showAnimations', value);
                setState(() {});
              },
            ),

            SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await GlobalSettings.resetGroup('game');
                    setState(() {});
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Game settings reset')),
                      );
                    }
                  },
                  child: const Text('Reset Game'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await GlobalSettings.resetAll();
                    setState(() {});
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('All settings reset')),
                      );
                    }
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Show new feature settings if available
            if (GlobalSettings.hasGroup('newFeature')) ...[
              Text(
                'New Feature Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('New Feature Enabled'),
                value: GlobalSettings.getBool('newFeature.enabled'),
                onChanged: (value) async {
                  await GlobalSettings.setBool('newFeature.enabled', value);
                  setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up when the app closes
    GlobalSettings.dispose();
    super.dispose();
  }
}
