// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:easy_shared_preferences/easy_shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize global settings with enhanced features
  await GlobalSettings.initialize([
    GroupConfig(
      key: 'app',
      items: [
        // String list with validation and recovery
        StringListSetting(
          key: 'tags',
          defaultValue: ['flutter', 'dart'],
          validator: CompositeValidator<List<String>>.and([
            ListLengthValidator(maxLength: 10),
            ListContentValidator(itemValidator: CommonValidators.nonEmpty),
          ]),
          onValidationError: (key, invalidValue, error) {
            // Recovery: filter out empty strings and limit to 10 items
            if (invalidValue is List<String>) {
              final filtered = invalidValue
                  .where((item) => item.isNotEmpty)
                  .take(10)
                  .toList();
              return filtered.isEmpty
                  ? ['flutter']
                  : filtered; // Fallback to default tag
            }
            return null; // Use default
          },
        ),

        // Features validation with recovery
        DoubleSetting(
          key: 'performance',
          defaultValue: 0.8,
          validator: CommonValidators.percentage,
          onValidationError: (key, invalidValue, error) {
            // Recovery: clamp invalid values to valid range
            if (invalidValue is double) {
              return invalidValue.clamp(0.0, 1.0);
            }
            return null;
          },
        ),

        // String with detailed validation
        StringSetting(
          key: 'apiEndpoint',
          defaultValue: 'https://api.example.com',
          validator: CompositeValidator<String>.and([
            CommonValidators.url,
            LengthValidator(maxLength: 200),
          ]),
          onValidationError: (key, invalidValue, error) {
            // Log the error and use default
            print('Invalid API endpoint: $invalidValue, using default');
            return null;
          },
        ),

        // List with complex validation
        StringListSetting(
          key: 'favoriteColors',
          defaultValue: ['blue', 'green'],
          validator: CompositeValidator<List<String>>.and([
            ListLengthValidator(minLength: 1, maxLength: 5),
            ListContentValidator(
              itemValidator: EnumValidator<String>([
                'red',
                'blue',
                'green',
                'yellow',
                'purple',
                'orange',
                'pink'
              ]),
            ),
          ]),
        ),
      ],
    ),
    GroupConfig(
      key: 'user',
      items: [
        StringSetting(
          key: 'email',
          defaultValue: '',
          validator: CommonValidators.email,
        ),
        StringListSetting(
          key: 'interests',
          defaultValue: [],
          validator: ListLengthValidator(maxLength: 20),
        ),
      ],
    ),
  ], enableLogging: true);

  runApp(const FeaturesExampleApp());
}

class FeaturesExampleApp extends StatelessWidget {
  const FeaturesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Features Easy Shared Preferences Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FeaturesDemo(),
    );
  }
}

class FeaturesDemo extends StatefulWidget {
  const FeaturesDemo({super.key});

  @override
  State<FeaturesDemo> createState() => _FeaturesDemoState();
}

class _FeaturesDemoState extends State<FeaturesDemo> {
  List<String> _tags = [];
  double _performance = 0.8;
  String _apiEndpoint = '';
  List<String> _favoriteColors = [];
  String _email = '';
  List<String> _interests = [];

  final _tagController = TextEditingController();
  final _emailController = TextEditingController();
  final _interestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupStreamListeners();
  }

  void _loadSettings() {
    setState(() {
      _tags = GlobalSettings.getStringList('app.tags');
      _performance = GlobalSettings.getDouble('app.performance');
      _apiEndpoint = GlobalSettings.getString('app.apiEndpoint');
      _favoriteColors = GlobalSettings.getStringList('app.favoriteColors');
      _email = GlobalSettings.getString('user.email');
      _interests = GlobalSettings.getStringList('user.interests');
    });
    _emailController.text = _email;
  }

  void _setupStreamListeners() {
    // Listen to changes through GlobalSettings
    GlobalSettings.addChangeCallback((key, oldValue, newValue) {
      print('Setting changed: $key from $oldValue to $newValue');
      if (mounted) {
        _loadSettings();
      }
    });
  }

  Future<void> _addTag() async {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty) {
      final newTags = [..._tags, tag];
      try {
        await GlobalSettings.setStringList('app.tags', newTags);
        _tagController.clear();
      } catch (e) {
        _showError('Failed to add tag: $e');
      }
    }
  }

  Future<void> _removeTag(String tag) async {
    final newTags = _tags.where((t) => t != tag).toList();
    try {
      await GlobalSettings.setStringList('app.tags', newTags);
    } catch (e) {
      _showError('Failed to remove tag: $e');
    }
  }

  Future<void> _updateEmail() async {
    try {
      await GlobalSettings.setString('user.email', _emailController.text);
    } catch (e) {
      _showError('Invalid email format');
    }
  }

  Future<void> _addInterest() async {
    final interest = _interestController.text.trim();
    if (interest.isNotEmpty) {
      final newInterests = [..._interests, interest];
      try {
        await GlobalSettings.setStringList('user.interests', newInterests);
        _interestController.clear();
      } catch (e) {
        _showError('Failed to add interest: $e');
      }
    }
  }

  Future<void> _toggleColor(String color) async {
    final newColors = _favoriteColors.contains(color)
        ? _favoriteColors.where((c) => c != color).toList()
        : [..._favoriteColors, color];

    try {
      await GlobalSettings.setStringList('app.favoriteColors', newColors);
    } catch (e) {
      _showError('Failed to update colors: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features Settings Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tags Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tags (Max 10, Non-empty)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () => _removeTag(tag),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            labelText: 'Add tag',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addTag,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Performance Slider
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Performance (0.0 - 1.0)',
                      style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    value: _performance,
                    onChanged: (value) async {
                      try {
                        await GlobalSettings.setDouble(
                            'app.performance', value);
                      } catch (e) {
                        _showError('Invalid performance value');
                      }
                    },
                  ),
                  Text('Current: ${_performance.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),

          // Favorite Colors
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Favorite Colors (1-5)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      'red',
                      'blue',
                      'green',
                      'yellow',
                      'purple',
                      'orange',
                      'pink'
                    ]
                        .map((color) => FilterChip(
                              label: Text(color),
                              selected: _favoriteColors.contains(color),
                              onSelected: (_) => _toggleColor(color),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Selected: ${_favoriteColors.join(', ')}'),
                ],
              ),
            ),
          ),

          // Email with validation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email (with validation)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _updateEmail(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _updateEmail,
                    child: const Text('Update Email'),
                  ),
                ],
              ),
            ),
          ),

          // Interests
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interests (Max 20)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_interests.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _interests
                          .map((interest) => Chip(
                                label: Text(interest),
                                onDeleted: () async {
                                  final newInterests = _interests
                                      .where((i) => i != interest)
                                      .toList();
                                  await GlobalSettings.setStringList(
                                      'user.interests', newInterests);
                                },
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _interestController,
                          decoration: const InputDecoration(
                            labelText: 'Add interest',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addInterest,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Debug info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Debug Info',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('API Endpoint: $_apiEndpoint'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await GlobalSettings.resetAll();
                      _loadSettings();
                    },
                    child: const Text('Reset All Settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    _emailController.dispose();
    _interestController.dispose();
    super.dispose();
  }
}
