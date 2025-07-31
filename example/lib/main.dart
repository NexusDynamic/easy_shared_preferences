import 'package:flutter/material.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

late SettingsStore store;
late SettingsGroup gameSettings;
late SettingsGroup uiSettings;
late EasySettings settings;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize store and settings
  store = SettingsStore();
  settings = EasySettings(store: store);

  // Define your settings groups with both function and class validators
  gameSettings = SettingsGroup(
    key: 'game',
    items: [
      BoolSetting(key: 'soundEnabled', defaultValue: true),
      DoubleSetting(
        key: 'volume',
        defaultValue: 0.8,
        // Using class validator for better validation descriptions
        validator: CommonValidators.percentage,
      ),
      IntSetting(
        key: 'difficulty',
        defaultValue: 1,
        // Using class validator with specific range
        validator: RangeValidator<int>(min: 1, max: 3),
      ),
    ],
    store: store,
  );

  uiSettings = SettingsGroup(
    key: 'ui',
    items: [
      StringSetting(
        key: 'theme',
        defaultValue: 'light',
        // Using enum validator for allowed values
        validator: EnumValidator<String>(['light', 'dark', 'auto']),
      ),
      BoolSetting(key: 'notifications', defaultValue: true),
    ],
    store: store,
  );

  settings.register(gameSettings);
  settings.register(uiSettings);
  await settings.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Shared Preferences Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SettingsDemo(),
    );
  }
}

class SettingsDemo extends StatefulWidget {
  const SettingsDemo({super.key});

  @override
  State<SettingsDemo> createState() => _SettingsDemoState();
}

class _SettingsDemoState extends State<SettingsDemo> {
  bool _soundEnabled = true;
  double _volume = 0.8;
  int _difficulty = 1;
  String _theme = 'light';
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // Listen to changes
    gameSettings['soundEnabled']?.stream.listen((value) {
      setState(() => _soundEnabled = value);
    });

    gameSettings['volume']?.stream.listen((value) {
      setState(() => _volume = value);
    });

    uiSettings['theme']?.stream.listen((value) {
      setState(() => _theme = value);
    });
  }

  void _loadSettings() {
    setState(() {
      _soundEnabled = settings.getBool('game.soundEnabled');
      _volume = settings.getDouble('game.volume');
      _difficulty = settings.getInt('game.difficulty');
      _theme = settings.getString('ui.theme');
      _notifications = settings.getBool('ui.notifications');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Shared Preferences Demo'),
        backgroundColor: _theme == 'dark' ? Colors.grey[800] : Colors.blue,
      ),
      backgroundColor: _theme == 'dark' ? Colors.grey[900] : Colors.white,
      body: Container(
        color: _theme == 'dark' ? Colors.grey[900] : Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Game Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _theme == 'dark' ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Sound Enabled
            Card(
              color: _theme == 'dark' ? Colors.grey[800] : Colors.white,
              child: SwitchListTile(
                title: Text(
                  'Sound Enabled',
                  style: TextStyle(
                    color: _theme == 'dark' ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Enable or disable game sounds',
                  style: TextStyle(
                    color:
                        _theme == 'dark' ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                value: _soundEnabled,
                onChanged: (value) async {
                  await settings.setBool('game.soundEnabled', value);
                },
              ),
            ),

            // Volume
            Card(
              color: _theme == 'dark' ? Colors.grey[800] : Colors.white,
              child: ListTile(
                title: Text(
                  'Volume: ${(_volume * 100).round()}%',
                  style: TextStyle(
                    color: _theme == 'dark' ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_volume * 100).round()}%',
                  onChanged: _soundEnabled
                      ? (value) async {
                          await settings.setDouble('game.volume', value);
                        }
                      : null,
                ),
              ),
            ),

            // Difficulty
            Card(
              color: _theme == 'dark' ? Colors.grey[800] : Colors.white,
              child: ListTile(
                title: Text(
                  'Difficulty',
                  style: TextStyle(
                    color: _theme == 'dark' ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Easy')),
                    ButtonSegment(value: 2, label: Text('Medium')),
                    ButtonSegment(value: 3, label: Text('Hard')),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (selection) async {
                    await settings.setInt('game.difficulty', selection.first);
                    setState(() => _difficulty = selection.first);
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'UI Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _theme == 'dark' ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Theme
            Card(
              color: _theme == 'dark' ? Colors.grey[800] : Colors.white,
              child: ListTile(
                title: Text(
                  'Theme',
                  style: TextStyle(
                    color: _theme == 'dark' ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: DropdownButton<String>(
                  value: _theme,
                  dropdownColor:
                      _theme == 'dark' ? Colors.grey[800] : Colors.white,
                  items: ['light', 'dark', 'auto'].map((theme) {
                    return DropdownMenuItem(
                      value: theme,
                      child: Text(
                        theme.substring(0, 1).toUpperCase() +
                            theme.substring(1),
                        style: TextStyle(
                          color: _theme == 'dark' ? Colors.white : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      await settings.setString('ui.theme', value);
                    }
                  },
                ),
              ),
            ),

            // Notifications
            Card(
              color: _theme == 'dark' ? Colors.grey[800] : Colors.white,
              child: SwitchListTile(
                title: Text(
                  'Notifications',
                  style: TextStyle(
                    color: _theme == 'dark' ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  'Enable push notifications',
                  style: TextStyle(
                    color:
                        _theme == 'dark' ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                value: _notifications,
                onChanged: (value) async {
                  await settings.setBool('ui.notifications', value);
                  setState(() => _notifications = value);
                },
              ),
            ),

            const SizedBox(height: 32),

            // Reset buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await settings.resetGroup('game');
                      _loadSettings();
                    },
                    child: const Text('Reset Game Settings'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await settings.resetAll();
                      _loadSettings();
                    },
                    child: const Text('Reset All'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
