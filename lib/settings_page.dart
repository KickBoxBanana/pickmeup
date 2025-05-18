import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_pages.dart';
import 'firebase_service.dart';
import 'task_page.dart';

class SettingsProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // Theme settings
  bool _isDarkMode = true;

  // Daily reset time settings
  int _resetHour = 12;
  int _resetMinute = 0;
  bool _resetIsAM = false; // false = PM

  // Week start settings
  String _weekStartDay = 'Monday';
  final List<String> weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  // Map weekday names to DateTime weekday values (DateTime uses 1 for Monday through 7 for Sunday)
  final Map<String, int> _weekdayMap = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 7
  };

  // Monthly reset settings
  bool _monthlyResetAtStart = true;

  // Getters
  bool get isDarkMode => _isDarkMode;
  int get resetHour => _resetHour;
  int get resetMinute => _resetMinute;
  bool get resetIsAM => _resetIsAM;
  String get weekStartDay => _weekStartDay;
  bool get monthlyResetAtStart => _monthlyResetAtStart;
  bool get isEmailVerified => _firebaseService.isEmailVerified;

  // Initialize settings from Firestore first, fall back to SharedPreferences
  Future<void> loadSettings() async {
    // Try to load from Firestore first
    final firestoreSettings = await _firebaseService.loadUserSettings();

    if (firestoreSettings != null) {
      _loadFromMap(firestoreSettings);
      notifyListeners();
      return;
    }

    // Fall back to local SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final userId = _firebaseService.userId;
    if (userId == null) {
      // Load default settings if no user
      _isDarkMode = true;
      _resetHour = 12;
      _resetMinute = 0;
      _resetIsAM = false;
      _weekStartDay = 'Monday';
      _monthlyResetAtStart = true;
    } else {
      // Load user-specific settings using userId prefix
      _isDarkMode = prefs.getBool('$userId.isDarkMode') ?? true;
      _resetHour = prefs.getInt('$userId.resetHour') ?? 12;
      _resetMinute = prefs.getInt('$userId.resetMinute') ?? 0;
      _resetIsAM = prefs.getBool('$userId.resetIsAM') ?? false;
      _weekStartDay = prefs.getString('$userId.weekStartDay') ?? 'Monday';
      _monthlyResetAtStart = prefs.getBool('$userId.monthlyResetAtStart') ?? true;

      // Also save to Firestore for first-time setup
      if (firestoreSettings == null) {
        saveSettings();
      }
    }

    notifyListeners();
  }

  // Load settings from map (from Firestore)
  void _loadFromMap(Map<String, dynamic> settings) {
    _isDarkMode = settings['isDarkMode'] ?? true;
    _resetHour = settings['resetHour'] ?? 12;
    _resetMinute = settings['resetMinute'] ?? 0;
    _resetIsAM = settings['resetIsAM'] ?? false;
    _weekStartDay = settings['weekStartDay'] ?? 'Monday';
    _monthlyResetAtStart = settings['monthlyResetAtStart'] ?? true;
  }

  // Convert settings to map for storage
  Map<String, dynamic> _toMap() {
    return {
      'isDarkMode': _isDarkMode,
      'resetHour': _resetHour,
      'resetMinute': _resetMinute,
      'resetIsAM': _resetIsAM,
      'weekStartDay': _weekStartDay,
      'monthlyResetAtStart': _monthlyResetAtStart,
    };
  }

  // Save settings to both SharedPreferences and Firestore
  Future<void> saveSettings() async {
    final settingsMap = _toMap();

    // Save to Firestore if user is logged in
    if (_firebaseService.isUserLoggedIn) {
      await _firebaseService.saveUserSettings(settingsMap);
    }

    // Save to SharedPreferences as backup
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = _firebaseService.userId;

    if (userId != null) {
      // Save with user-specific prefix
      await prefs.setBool('$userId.isDarkMode', _isDarkMode);
      await prefs.setInt('$userId.resetHour', _resetHour);
      await prefs.setInt('$userId.resetMinute', _resetMinute);
      await prefs.setBool('$userId.resetIsAM', _resetIsAM);
      await prefs.setString('$userId.weekStartDay', _weekStartDay);
      await prefs.setBool('$userId.monthlyResetAtStart', _monthlyResetAtStart);
    }
  }

  // Update theme
  void setDarkMode(bool value) {
    _isDarkMode = value;
    saveSettings();
    notifyListeners();
  }

  // Update daily reset time
  void setDailyResetTime(int hour, int minute, bool isAM) async {
    _resetHour = hour;
    _resetMinute = minute;
    _resetIsAM = isAM;
    
    // Update all tasks' due times to match new reset time
    try {
      final userId = _firebaseService.userId;
      if (userId != null) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .get();

        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in tasksSnapshot.docs) {
          final task = doc.data();
          if (task['type'] == 'One-Time' && task['dueDate'] != null) {
            // For One-Time tasks, adjust the time component of the due date
            final dueDate = DateTime.parse(task['dueDate']);
            // Convert to 24-hour format
            final resetHour24 = isAM ? hour : (hour == 12 ? 12 : hour + 12);
            final newDueDate = DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
              resetHour24,
              minute,
            );
            
            batch.update(doc.reference, {
              'dueDate': newDueDate.toIso8601String(),
            });
          } else if (task['type'] == 'Daily' || task['type'] == 'Weekly' || task['type'] == 'Monthly') {
            // For recurring tasks, recalculate the next reset time
            final lastReset = task['lastResetTime'] != null 
                ? DateTime.parse(task['lastResetTime'])
                : DateTime.parse(task['createdAt']);
                
            final nextReset = _calculateNextResetTime(task['type'], lastReset);
            
            batch.update(doc.reference, {
              'dueDate': nextReset.toIso8601String(),
            });
          }
        }
        
        await batch.commit();
        debugPrint("Updated task due dates with new reset time: ${isAM ? hour : hour + 12}:$minute");
      }
    } catch (e) {
      debugPrint("Error updating task due times: $e");
    }
    
    saveSettings();
    notifyListeners();
  }

  // Helper method to calculate next reset time (copied from TaskResetService)
  DateTime _calculateNextResetTime(String taskType, DateTime lastReset) {
    final DateTime baseTime = lastReset;
    final int hour = _resetHour;
    final int minute = _resetMinute;
    // Convert to 24-hour format
    final int resetHour = _resetIsAM ? hour : (hour == 12 ? 12 : hour + 12);

    switch (taskType) {
      case 'Daily':
        final DateTime today = DateTime(baseTime.year, baseTime.month, baseTime.day, resetHour, minute);
        if (baseTime.isAfter(today)) {
          return today.add(Duration(days: 1));
        } else {
          return today;
        }

      case 'Weekly':
        final int preferredWeekday = _weekdayMap[_weekStartDay] ?? 1;
        int daysUntilNextReset = preferredWeekday - baseTime.weekday;
        if (daysUntilNextReset <= 0) {
          daysUntilNextReset += 7;
        }
        return DateTime(
            baseTime.year,
            baseTime.month,
            baseTime.day + daysUntilNextReset,
            resetHour,
            minute
        );

      case 'Monthly':
        if (_monthlyResetAtStart) {
          int nextMonth = baseTime.month + 1;
          int year = baseTime.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            year += 1;
          }
          return DateTime(year, nextMonth, 1, resetHour, minute);
        } else {
          int lastDayOfMonth = DateTime(baseTime.year, baseTime.month + 1, 0).day;
          return DateTime(baseTime.year, baseTime.month, lastDayOfMonth, resetHour, minute);
        }

      default:
        return DateTime.now().add(Duration(days: 365 * 10));
    }
  }

  // Update week start day
  void setWeekStartDay(String day) {
    _weekStartDay = day;
    saveSettings();
    notifyListeners();
  }

  // Update monthly reset preference
  void setMonthlyResetAtStart(bool value) {
    _monthlyResetAtStart = value;
    saveSettings();
    notifyListeners();
  }

  // Reset user account data in Firebase
  Future<void> resetUserAccount() async {
    await _firebaseService.resetUserData();
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    await _firebaseService.sendEmailVerification();
  }

  // Sign out user
  Future<void> signOut() async {
    await _firebaseService.signOut();
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load settings when page initializes
    _loadSettings();
    // Reload the user to get the latest emailVerified status
    _firebaseService.currentUser?.reload();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEmailVerified = _firebaseService.isEmailVerified;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              await settingsProvider.saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings saved!'))
              );
            },
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Theme Settings
                      _buildSectionHeader('Theme'),
                      ListTile(
                        title: Text('App Theme'),
                        trailing: ToggleButtons(
                          isSelected: [!settingsProvider.isDarkMode, settingsProvider.isDarkMode],
                          onPressed: (index) {
                            settingsProvider.setDarkMode(index == 1);
                          },
                          borderRadius: BorderRadius.circular(30),
                          selectedColor: Colors.white,
                          fillColor: Colors.deepPurple,
                          constraints: BoxConstraints(minWidth: 50, minHeight: 40),
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lightbulb, size: 20),
                                  SizedBox(width: 4),
                                  Text('Light'),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.nightlight_round, size: 20),
                                  SizedBox(width: 4),
                                  Text('Dark'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      _buildDivider(),

                      // Daily Reset Settings
                      _buildSectionHeader('Daily Reset Time'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Hour dropdown
                          DropdownButton<int>(
                            value: settingsProvider.resetHour,
                            onChanged: (value) {
                              if (value != null) {
                                settingsProvider.setDailyResetTime(
                                    value,
                                    settingsProvider.resetMinute,
                                    settingsProvider.resetIsAM
                                );
                              }
                            },
                            items: List.generate(12, (index) => index + 1)
                                .map((hour) => DropdownMenuItem(
                              value: hour,
                              child: Text(hour.toString().padLeft(2, '0')),
                            ))
                                .toList(),
                          ),
                          Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
                          // Minute dropdown
                          DropdownButton<int>(
                            value: settingsProvider.resetMinute,
                            onChanged: (value) {
                              if (value != null) {
                                settingsProvider.setDailyResetTime(
                                    settingsProvider.resetHour,
                                    value,
                                    settingsProvider.resetIsAM
                                );
                              }
                            },
                            items: List.generate(60, (index) => index)
                                .map((minute) => DropdownMenuItem(
                              value: minute,
                              child: Text(minute.toString().padLeft(2, '0')),
                            ))
                                .toList(),
                          ),
                          // AM/PM toggle
                          ToggleButtons(
                            isSelected: [settingsProvider.resetIsAM, !settingsProvider.resetIsAM],
                            onPressed: (index) {
                              settingsProvider.setDailyResetTime(
                                  settingsProvider.resetHour,
                                  settingsProvider.resetMinute,
                                  index == 0
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            selectedColor: Colors.white,
                            fillColor: Colors.deepPurple,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('AM'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('PM'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      _buildDivider(),

                      // Week Start Settings
                      _buildSectionHeader('Week Start Day'),
                      DropdownButtonFormField<String>(
                        value: settingsProvider.weekStartDay,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            settingsProvider.setWeekStartDay(value);
                          }
                        },
                        items: settingsProvider.weekDays
                            .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day),
                        ))
                            .toList(),
                      ),

                      _buildDivider(),

                      // Monthly Reset Settings
                      _buildSectionHeader('Monthly Reset'),
                      ListTile(
                        title: Text('Monthly Reset Time'),
                        subtitle: Text(settingsProvider.monthlyResetAtStart
                            ? 'At the start of month'
                            : 'At the end of month'),
                        trailing: Switch(
                          value: settingsProvider.monthlyResetAtStart,
                          onChanged: (value) {
                            settingsProvider.setMonthlyResetAtStart(value);
                          },
                          activeColor: Colors.deepPurple,
                        ),
                      ),

                      _buildDivider(),

                      // Account Actions
                      _buildSectionHeader('Account'),
                      SizedBox(height: 16),

                      // Email verification button - only shown if email is not verified
                      if (!isEmailVerified)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.email),
                            label: Text('Verify Email'),
                            onPressed: _sendVerificationEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                      if (!isEmailVerified)
                        SizedBox(height: 16),

                      // Reset Account button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('Reset Account'),
                          onPressed: _resetAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Logout button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.logout),
                          label: Text('Logout'),
                          onPressed: () => _showLogoutConfirmation(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isLoading = true);

    try {
      await Provider.of<SettingsProvider>(context, listen: false).sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent! Please check your inbox.'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification email: ${e.toString()}'))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetAccount() {
    // Store context reference before showing dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset Account'),
        content: Text('Are you sure you want to reset your account? This will delete all your progress, including your level, gold, gems, health, mana, and battles won.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                // Reset tasks
                await taskProvider.clearAllTasks();

                // Reset user data in Firebase
                await settingsProvider.resetUserAccount();

                // Use stored scaffoldMessenger reference
                scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Account reset successfully!'))
                );
              } catch (e) {
                // Use stored scaffoldMessenger reference
                scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error resetting account: ${e.toString()}'))
                );
              } finally {
                // Check if the widget is still mounted before calling setState
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: Text('Reset'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<SettingsProvider>(context, listen: false).signOut();
              // Navigate to the first screen (likely login screen)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginPage()),
                    (route) => false,
              );
            },
            child: Text('Logout'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(thickness: 1),
    );
  }
}