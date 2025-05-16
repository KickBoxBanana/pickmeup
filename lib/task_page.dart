import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'custom_widgets.dart';
import 'game_mechanics.dart';
import 'task_dialog_service.dart';

// Represents task rewards
class TaskReward {
  final int xp;
  final int gold;
  final Map<String, int> stats;

  TaskReward({
    required this.xp,
    required this.gold,
    required this.stats,
  });
}

// Handles Interval Task Refreshes
class TaskResetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User settings with defaults
  Map<String, dynamic> _userSettings = {
    'monthlyResetAtStart': true,
    'resetHour': 0, // Midnight by default
    'resetIsAM': true,
    'resetMinute': 0,
    'weekStartDay': 'Monday'
  };

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

  // Initialize with the current user settings
  Future<void> loadUserSettings() async {
    if (_auth.currentUser == null) {
      debugPrint("No authenticated user to load settings for");
      return;
    }

    try {
      final String userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists && userDoc.data()!.containsKey('settings')) {
        final Map<String, dynamic> settings = Map<String, dynamic>.from(userDoc.data()!['settings'] ?? {});

        // Update settings with values from Firestore, using current values as defaults
        _userSettings = {
          'monthlyResetAtStart': settings['monthlyResetAtStart'] ?? _userSettings['monthlyResetAtStart'],
          'resetHour': settings['resetHour'] ?? _userSettings['resetHour'],
          'resetIsAM': settings['resetIsAM'] ?? _userSettings['resetIsAM'],
          'resetMinute': settings['resetMinute'] ?? _userSettings['resetMinute'],
          'weekStartDay': settings['weekStartDay'] ?? _userSettings['weekStartDay'],
        };

        debugPrint("Loaded user settings: $_userSettings");
      } else {
        debugPrint("No settings found, using defaults");
      }
    } catch (e) {
      debugPrint("Error loading user settings: $e");
    }
  }

  // Calculate the next reset time for a task based on its type
  DateTime calculateNextResetTime(String taskType, DateTime? lastReset) {
    // If lastReset is null, use current time as the base
    final DateTime baseTime = lastReset ?? DateTime.now();

    // Get the hour and minute from user settings
    final int hour = _userSettings['resetHour'] as int;
    final int minute = _userSettings['resetMinute'] as int;
    // Convert from 12-hour format to 24-hour if needed
    final int resetHour = _userSettings['resetIsAM'] ? hour : (hour == 12 ? 12 : hour + 12);

    debugPrint("=== Reset Time Calculation ===");
    debugPrint("Task Type: $taskType");
    debugPrint("Base Time: $baseTime");
    debugPrint("User Settings - Hour: $hour, Minute: $minute, IsAM: ${_userSettings['resetIsAM']}");
    debugPrint("Converted Reset Hour (24h): $resetHour");
    debugPrint("Current User Settings: $_userSettings");

    switch (taskType) {
      case 'Daily':
        // For daily tasks, check if today's reset time has passed
        final DateTime todayReset = DateTime(baseTime.year, baseTime.month, baseTime.day, resetHour, minute);
        final DateTime now = DateTime.now();
        
        // If current time is before today's reset time, use today's reset time
        if (now.isBefore(todayReset)) {
          debugPrint("Current time is before reset time, using today's reset: $todayReset");
          return todayReset;

          // Otherwise, use tomorrow's reset time
        } else {
          final DateTime tomorrowReset = todayReset.add(Duration(days: 1));
          debugPrint("Current time is after reset time, using tomorrow's reset: $tomorrowReset");
          return tomorrowReset;
        }

      case 'Weekly':
        // Get the preferred start day of the week
        final int preferredWeekday = _weekdayMap[_userSettings['weekStartDay']] ?? 1; // Default to Monday

        // Calculate days until the next preferred weekday
        int daysUntilNextReset = preferredWeekday - baseTime.weekday;
        if (daysUntilNextReset <= 0) {
          daysUntilNextReset += 7; // If today is the reset day or we've passed it, go to next week
        }

        // Create DateTime for the next reset
        final nextReset = DateTime(
            baseTime.year,
            baseTime.month,
            baseTime.day + daysUntilNextReset,
            resetHour,
            minute
        );
        debugPrint("Next weekly reset: $nextReset");
        return nextReset;

      case 'Monthly':
        // Determine if we reset at the start of the month or the end of the month
        if (_userSettings['monthlyResetAtStart'] as bool) {
          // Reset on the 1st of next month
          int nextMonth = baseTime.month + 1;
          int year = baseTime.year;

          // Handle December -> January transition
          if (nextMonth > 12) {
            nextMonth = 1;
            year += 1;
          }

          final nextReset = DateTime(year, nextMonth, 1, resetHour, minute);
          debugPrint("Next monthly reset (start): $nextReset");
          return nextReset;
        } else {
          // Reset at the end of the current month
          // Get the last day of the current month
          int lastDayOfMonth = DateTime(baseTime.year, baseTime.month + 1, 0).day;
          final nextReset = DateTime(baseTime.year, baseTime.month, lastDayOfMonth, resetHour, minute);
          debugPrint("Next monthly reset (end): $nextReset");
          return nextReset;
        }

      default:
        // For "One-Time" tasks or unrecognized types, return the base time
        debugPrint("Using base time for One-Time task: $baseTime");
        return baseTime;
    }
  }

  // Check if a task is due for reset
  bool isTaskDueForReset(Map<String, dynamic> task) {
    if (!_isRecurringTask(task['type'])) {
      return false; // Non-recurring tasks don't reset
    }

    // Get the last reset time, or use creation time if it doesn't exist
    DateTime lastResetTime;
    if (task.containsKey('lastResetTime') && task['lastResetTime'] != null) {
      lastResetTime = DateTime.parse(task['lastResetTime']);
    } else if (task.containsKey('createdAt') && task['createdAt'] != null) {
      lastResetTime = DateTime.parse(task['createdAt']);
    } else {
      // If there's no creation time, use a day ago as fallback
      lastResetTime = DateTime.now().subtract(Duration(days: 1));
    }

    // Calculate when this task should next reset
    final DateTime nextResetTime = calculateNextResetTime(task['type'], lastResetTime);

    // The task is due for reset if the next reset time is before or equal to now
    return nextResetTime.isBefore(DateTime.now()) || nextResetTime.isAtSameMomentAs(DateTime.now());
  }

  // Reset a single task
  Future<void> resetTask(String taskId) async {
    if (_auth.currentUser == null) {
      debugPrint("No authenticated user to reset tasks for");
      return;
    }

    final String userId = _auth.currentUser!.uid;
    final taskRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId);

    try {
      // Get the current task data
      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        debugPrint("Task does not exist: $taskId");
        return;
      }

      final taskData = taskDoc.data()!;
      final now = DateTime.now();

      debugPrint("\nResetting task: ${taskData['title']}");
      debugPrint("Current time: $now");

      // Create a new task with the same data but reset completion status
      final newTaskData = Map<String, dynamic>.from(taskData);
      newTaskData['completed'] = false;
      newTaskData['completedDate'] = null;
      newTaskData['lastResetTime'] = now.toIso8601String();
      newTaskData['createdAt'] = now.toIso8601String();

      // Calculate and set the next due date based on task type
      final nextDueDate = calculateNextResetTime(taskData['type'], now);
      newTaskData['dueDate'] = nextDueDate.toIso8601String();

      debugPrint("New due date: ${nextDueDate.toIso8601String()}");

      // Delete the old task and create a new one
      await _firestore.runTransaction((transaction) async {
        transaction.delete(taskRef);
        transaction.set(_firestore.collection('users').doc(userId).collection('tasks').doc(), newTaskData);
      });

      debugPrint("Successfully reset task: ${taskData['title']}");
    } catch (e) {
      debugPrint("Error resetting task: $e");
    }
  }

  // Check and reset all tasks that need resetting
  Future<int> checkAndResetTasks() async {
    if (_auth.currentUser == null) {
      debugPrint("No authenticated user to reset tasks for");
      return 0;
    }

    // Load latest user settings
    await loadUserSettings();
    debugPrint("=== Starting Task Reset Check ===");
    debugPrint("Current User Settings: $_userSettings");

    final String userId = _auth.currentUser!.uid;
    int tasksReset = 0;

    try {
      // Get all recurring tasks, regardless of completion status
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('type', whereIn: ['Daily', 'Weekly', 'Monthly'])
          .get();

      debugPrint("Found ${tasksSnapshot.docs.length} recurring tasks to check");

      for (var doc in tasksSnapshot.docs) {
        final task = doc.data();
        task['id'] = doc.id; // Add ID to the task data

        debugPrint("\nChecking task: ${task['title']} (${task['type']})");
        debugPrint("Last reset time: ${task['lastResetTime']}");
        debugPrint("Current due date: ${task['dueDate']}");

        // Check if this task should be reset
        if (isTaskDueForReset(task)) {
          debugPrint("Task needs reset - resetting now");
          await resetTask(doc.id);
          tasksReset++;
        } else {
          debugPrint("Task does not need reset");
        }
      }

      debugPrint("\nReset $tasksReset tasks");
      return tasksReset;
    } catch (e) {
      debugPrint("Error checking and resetting tasks: $e");
      return 0;
    }
  }

  // Helper to check if a task type is recurring
  bool _isRecurringTask(String taskType) {
    return taskType == 'Daily' || taskType == 'Weekly' || taskType == 'Monthly';
  }
}

// Handles task addition/deletion/editing, completion, and filtering logic
class TaskProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TaskResetService _resetService = TaskResetService();
  DateTime _lastCheckTime = DateTime.now();


  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredOngoingTasks = [];
  List<Map<String, dynamic>> _filteredCompletedTasks = [];

  bool _isLoading = false;
  String? _error;

  String _search = '';
  String _type = 'All';
  String _category = 'All';
  String _difficulty = 'All';




  String get currentSearch => _search;
  String get currentType => _type;
  String get currentCategory => _category;
  String get currentDifficulty => _difficulty;

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  // Auth state subscription
  StreamSubscription<User?>? _authSubscription;

  // Getters
  List<Map<String, dynamic>> get ongoingTasks => _filteredOngoingTasks;
  List<Map<String, dynamic>> get completedTasks => _filteredCompletedTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> checkForTaskResets({bool force = false}) async {
    final now = DateTime.now();

    _lastCheckTime = now;
    debugPrint("Checking for tasks that need to be reset...");

    int resetCount = await _resetService.checkAndResetTasks();
    if (resetCount > 0) {
      // Tasks were reset, reload the UI
      debugPrint("Reset $resetCount tasks. Reloading task list.");
      // No need to reload manually, the Firestore listener will detect changes
    } else {
      debugPrint("No tasks needed resetting");
    }
  }

  TaskProvider() {
    // Listen for auth state changes
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChange);

    // If user is already logged in, initialize immediately
    if (_auth.currentUser != null) {
      _initTasksListener();
      // Initialize the reset service and load settings
      _resetService.loadUserSettings().then((_) {
        debugPrint("TaskResetService initialized with settings");
      });
    }
  }



  // Handle authentication state changes
  void _handleAuthStateChange(User? user) {
    // Cancel existing task subscription
    _tasksSubscription?.cancel();

    if (user != null) {
      // User is logged in, initialize tasks listener
      _initTasksListener();
    } else {
      // User is logged out, clear tasks
      _allTasks = [];
      _filteredOngoingTasks = [];
      _filteredCompletedTasks = [];
      _error = null;
      notifyListeners();
    }
  }

  // Initialize the listener for real-time tasks updates
  void _initTasksListener() {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final String userId = _auth.currentUser!.uid;
    debugPrint("Initializing tasks listener for user: $userId");

    try {
      // Make sure to close any existing subscription
      _tasksSubscription?.cancel();

      _tasksSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .snapshots()
          .listen(
            (snapshot) {
          _allTasks = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
          }).toList();

          debugPrint("Loaded ${_allTasks.length} tasks from Firestore");
          _isLoading = false;
          _error = null;
          _applyFilters();
        },
        onError: (error) {
          debugPrint("Error loading tasks: $error");
          _isLoading = false;
          _error = "Failed to load tasks: $error";
          notifyListeners();
        },
      );

      // Check for task resets after initializing listener
      checkForTaskResets();
    } catch (e) {
      debugPrint("Exception initializing task listener: $e");
      _isLoading = false;
      _error = "Failed to initialize task listener: $e";
      notifyListeners();
    }
  }

  // Force a reset check regardless of the time since last check
  Future<void> forceResetCheck() async {
    debugPrint("Forcing task reset check...");
    await checkForTaskResets(force: true);
  }

  // Clean up subscriptions when no longer needed
  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Add a new task
  Future<void> addTask(Map<String, dynamic> task) async {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    final String userId = _auth.currentUser!.uid;

    // Remove the id as Firestore will generate one
    final taskData = Map<String, dynamic>.from(task);
    if (taskData.containsKey('id')) taskData.remove('id');

    // Validate task type
    final String taskType = taskData['type'] as String? ?? 'Daily';
    if (!['Daily', 'Weekly', 'Monthly', 'One-Time'].contains(taskType)) {
      debugPrint("Invalid task type: $taskType, defaulting to Daily");
      taskData['type'] = 'Daily';
    }

    final now = DateTime.now();
    taskData['createdAt'] = now.toIso8601String();

    debugPrint("=== Creating New Task ===");
    debugPrint("Task Type: ${taskData['type']}");
    debugPrint("Current Time: $now");

    // Ensure settings are loaded before calculating reset time
    await _resetService.loadUserSettings();

    // For recurring tasks, set the initial due date based on the task type
    if (taskData['type'] == 'Daily' || taskData['type'] == 'Weekly' || taskData['type'] == 'Monthly') {
      taskData['lastResetTime'] = now.toIso8601String();
      debugPrint("Calculating next reset time for ${taskData['type']} task...");
      
      // For new tasks, set the due date to today's or tomorrow's reset time
      final currentYear = DateTime.now().year;
      final today = DateTime(currentYear, now.month, now.day);
      final nextResetTime = _resetService.calculateNextResetTime(taskData['type'], today);
      taskData['dueDate'] = nextResetTime.toIso8601String();
      debugPrint("Set due date to: ${taskData['dueDate']}");
    } else if (taskData['type'] == 'One-Time' && taskData['dueDate'] != null) {
      // For One-Time tasks, set the time to match the daily reset time
      final dueDate = DateTime.parse(taskData['dueDate']);
      debugPrint("Original due date: $dueDate");
      final nextResetTime = _resetService.calculateNextResetTime('Daily', dueDate);
      taskData['dueDate'] = nextResetTime.toIso8601String();
      debugPrint("Adjusted due date to: ${taskData['dueDate']}");
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(taskData);
      debugPrint("Task successfully added to Firestore");
    } catch (e) {
      debugPrint("Error adding task: $e");
      _error = "Failed to add task: $e";
      notifyListeners();
    }
  }

  // Calculate rewards for task completion based on difficulty and category
  TaskReward calculateRewards(Map<String, dynamic> task) {
    // Base rewards by difficulty
    int baseXp = 0;
    int baseGold = 0;
    int baseStatPoints = 0;

    switch (task['difficulty']) {
      case 'Easy':
        baseXp = 10;
        baseGold = 5;
        baseStatPoints = 1;
        break;
      case 'Medium':
        baseXp = 20;
        baseGold = 10;
        baseStatPoints = 2;
        break;
      case 'Hard':
        baseXp = 30;
        baseGold = 15;
        baseStatPoints = 3;
        break;
    }

    // Adjust rewards based on task type
    double typeMultiplier = 1.0;
    switch (task['type']) {
      case 'Daily':
        typeMultiplier = 1.0;
        break;
      case 'Weekly':
        typeMultiplier = 1.5;
        break;
      case 'Monthly':
        typeMultiplier = 2.0;
        break;
      case 'One-Time':
        typeMultiplier = 1.2;
        break;
    }

    int adjustedXp = (baseXp * typeMultiplier).round();
    int adjustedGold = (baseGold * typeMultiplier).round();

    // Determine which stat to reward based on category
    Map<String, int> statRewards = {
      'strength': 0,
      'intelligence': 0,
      'vitality': 0,
      'wisdom': 0,
    };

    switch (task['category']) {
      case 'Physical':
        statRewards['strength'] = baseStatPoints;
        break;
      case 'Academic':
        statRewards['intelligence'] = baseStatPoints;
        break;
      case 'Lifestyle':
        statRewards['vitality'] = baseStatPoints;
        break;
      case 'Intellectual':
        statRewards['wisdom'] = baseStatPoints;
        break;
      case 'Miscellaneous':
      // Extra XP for miscellaneous tasks
        adjustedXp += 5;
        break;
    }

    return TaskReward(
      xp: adjustedXp,
      gold: adjustedGold,
      stats: statRewards,
    );
  }

  // Check whether user can level up after task completion
  Future<int> checkAndProcessLevelUp(
      DocumentReference userRef,
      int currentXp,
      Transaction transaction,
      Map<String, dynamic> userData
      ) async {
    final int currentLevel = userData['userLevel'] ?? 1;

    if (LevelManager.canLevelUp(currentLevel, currentXp)) {
      // User can level up
      final int newLevel = currentLevel + 1;
      final int remainingXp = LevelManager.processLevelUp(currentLevel, currentXp);

      // Update user level and XP in the transaction
      transaction.update(userRef, {
        'userLevel': newLevel,
        'xp': remainingXp,
      });

      // Return the adjusted XP value for any further processing
      return remainingXp;
    }

    // If no level up occurred, just return the original XP
    return currentXp;
  }

  // Mark a task as complete and award rewards
  Future<TaskReward> completeTask(String taskId) async {
    if (_auth.currentUser == null) {
      throw Exception('User not authenticated');
    }

    final String userId = _auth.currentUser!.uid;

    // Find the task in our local list
    final task = _allTasks.firstWhere(
          (t) => t['id'] == taskId,
      orElse: () => throw Exception('Task not found'),
    );

    // Calculate rewards
    final TaskReward rewards = calculateRewards(task);

    try {
      // Update Firestore in a transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        // Get task reference
        final taskRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskId);

        // Get user document to update gold, XP, health, and mana
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        // Get the base stats document
        final baseStatsRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('stats')
            .doc('base');

        final baseStatsDoc = await transaction.get(baseStatsRef);

        // Get the battle stats document
        final battleStatsRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('stats')
            .doc('battle');

        final battleStatsDoc = await transaction.get(battleStatsRef);

        // Read the task document to verify it exists
        final taskDoc = await transaction.get(taskRef);
        if (!taskDoc.exists) {
          throw Exception('Task document not found');
        }


        // Mark task as completed
        transaction.update(taskRef, {
          'completed': true,
          'completedDate': DateTime.now().toIso8601String(),
        });

        // Update user's gold and XP, as well as regenerate health
        final userData = userDoc.data() as Map<String, dynamic>;
        final int currentGold = (userData['gold'] ?? 0).toInt();
        final int currentXp = (userData['xp'] ?? 0).toInt();
        final int currentHealth = (userData['health'] ?? 0).toInt();
        final int maxHealth = (userData['maxHealth'] ?? 100).toInt();
        final int newXp = currentXp + rewards.xp;
        final int newHealth;
        if (currentHealth < maxHealth) {
          newHealth = currentHealth + (maxHealth ~/ 10); // Use integer division
        } else {
          newHealth = maxHealth;
        }

        // Maps to track what needs to be updated
        Map<String, dynamic> userUpdates = {
          'gold': currentGold + rewards.gold,
          'xp': newXp,
          'health': newHealth,
          'mana': (userData['maxMana'] ?? 50),
        };

        // Variables to track health and mana increases
        int vitIncrease = 0;
        int wisIncrease = 0;

        // Update stats in base stats document
        if (baseStatsDoc.exists) {
          final baseStats = baseStatsDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> baseStatsUpdates = {};

          // Update each stat that has a reward
          for (final statName in rewards.stats.keys) {
            if (rewards.stats[statName]! > 0) {
              final int currentValue = baseStats[statName] ?? 0;
              final int newValue = currentValue + rewards.stats[statName]!;
              baseStatsUpdates[statName] = newValue;

              // Track VIT and WIS increases for health and mana updates
              if (statName == 'vitality') {
                vitIncrease = rewards.stats[statName]!;
              } else if (statName == 'wisdom') {
                wisIncrease = rewards.stats[statName]!;
              }
            }
          }

          if (baseStatsUpdates.isNotEmpty) {
            transaction.update(baseStatsRef, baseStatsUpdates);
          }
        } else {
          // If the base stats document doesn't exist, create it
          transaction.set(baseStatsRef, {
            'strength': rewards.stats['strength'] ?? 0,
            'intelligence': rewards.stats['intelligence'] ?? 0,
            'vitality': rewards.stats['vitality'] ?? 0,
            'wisdom': rewards.stats['wisdom'] ?? 0,
          });

          // All stats would be new in this case
          vitIncrease = rewards.stats['vitality'] ?? 0;
          wisIncrease = rewards.stats['wisdom'] ?? 0;
        }

        // Update battle stats document
        if (battleStatsDoc.exists) {
          final battleStats = battleStatsDoc.data() as Map<String, dynamic>;
          Map<String, dynamic> battleStatsUpdates = {};

          // Update physical attack if strength was increased
          if (rewards.stats['strength'] != null && rewards.stats['strength']! > 0) {
            final int currentPhyAtk = battleStats['phyatk'] ?? 0;
            battleStatsUpdates['phyatk'] = currentPhyAtk + rewards.stats['strength']!;
          }

          // Update magical attack if intelligence was increased
          if (rewards.stats['intelligence'] != null && rewards.stats['intelligence']! > 0) {
            final int currentMagAtk = battleStats['magatk'] ?? 0;
            battleStatsUpdates['magatk'] = currentMagAtk + rewards.stats['intelligence']!;
          }

          if (battleStatsUpdates.isNotEmpty) {
            transaction.update(battleStatsRef, battleStatsUpdates);
          }
        } else {
          // If the battle stats document doesn't exist, create it with initial values
          transaction.set(battleStatsRef, {
            'phyatk': 5+(rewards.stats['strength']!-1),
            'magatk': 5+(rewards.stats['intelligence']!-1),
            'phydef': 5,
            'magdef': 5,
          });
        }

        // Update maxHealth and maxMana in user document if VIT or WIS increased
        if (vitIncrease > 0) {
          int currentMaxHealth = userData['maxHealth'] ?? 100; // Base is 100
          userUpdates['maxHealth'] = currentMaxHealth + vitIncrease;

          // Also update current health if needed
          if (userData.containsKey('health')) {
            int currentHealth = userData['health'];
            // Only increase current health if it's at max already
            if (currentHealth == currentMaxHealth) {
              userUpdates['health'] = currentMaxHealth + vitIncrease;
            }
          } else {
            // If health doesn't exist yet, set it to the new max
            userUpdates['health'] = currentMaxHealth + vitIncrease;
          }
        }

        if (wisIncrease > 0) {
          int currentMaxMana = userData['maxMana'] ?? 50; // Base is 50
          userUpdates['maxMana'] = currentMaxMana + wisIncrease;

          // Also update current mana if needed
          if (userData.containsKey('mana')) {
            int currentMana = userData['mana'];
            // Only increase current mana if it's at max already
            if (currentMana == currentMaxMana) {
              userUpdates['mana'] = currentMaxMana + wisIncrease;
            }
          } else {
            // If mana doesn't exist yet, set it to the new max
            userUpdates['mana'] = currentMaxMana + wisIncrease;
          }
        }

        // Check for level up and process if needed
        final int processedXp = await checkAndProcessLevelUp(
            userRef,
            newXp,
            transaction,
            userData
        );

        // Make sure we're using the potentially adjusted XP value after level up check
        userUpdates['xp'] = processedXp;

        // Apply all user updates
        transaction.update(userRef, userUpdates);
      });

      return rewards;
    } catch (e) {
      debugPrint("Error completing task: $e");
      throw Exception('Failed to complete task: $e');
    }
  }

  // Edit an existing task
  Future<void> editTask(
      String id,
      String newTitle,
      String newDesc,
      String newType,
      String newCategory,
      String newDifficulty,
      DateTime? dueDate,
      ) async {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    final String userId = _auth.currentUser!.uid;

    try {
      // Get the current task data
      final taskDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .get();

      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final taskData = taskDoc.data()!;
      final String oldType = taskData['type'];
      final DateTime now = DateTime.now();

      // Calculate new due date based on task type
      String? newDueDate;
      if (newType == 'One-Time' && dueDate != null) {
        // For One-Time tasks, adjust the time to match reset time
        final nextResetTime = _resetService.calculateNextResetTime('Daily', dueDate);
        newDueDate = nextResetTime.toIso8601String();
      } else if (newType == 'Daily' || newType == 'Weekly' || newType == 'Monthly') {
        // For recurring tasks, calculate next reset time
        // If type changed, use current time as base
        // If type didn't change, use last reset time or creation time
        DateTime baseTime;
        if (oldType != newType) {
          baseTime = now;
        } else {
          baseTime = taskData['lastResetTime'] != null 
              ? DateTime.parse(taskData['lastResetTime'])
              : DateTime.parse(taskData['createdAt']);
        }
        final nextResetTime = _resetService.calculateNextResetTime(newType, baseTime);
        newDueDate = nextResetTime.toIso8601String();
      }

      // Update the task
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .update({
        'title': newTitle,
        'description': newDesc,
        'type': newType,
        'category': newCategory,
        'difficulty': newDifficulty,
        'dueDate': newDueDate,
        // If type changed, update lastResetTime
        if (oldType != newType) 'lastResetTime': now.toIso8601String(),
      });

      debugPrint("Updated task $id with new type: $newType and due date: $newDueDate");
    } catch (e) {
      debugPrint("Error editing task: $e");
      _error = "Failed to edit task: $e";
      notifyListeners();
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    final String userId = _auth.currentUser!.uid;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      debugPrint("Error deleting task: $e");
      _error = "Failed to delete task: $e";
      notifyListeners();
    }
  }

  // Update filters
  void updateFilters({
    String search = '',
    String type = 'All',
    String category = 'All',
    String difficulty = 'All',
  }) {
    _search = search;
    _type = type;
    _category = category;
    _difficulty = difficulty;

    _applyFilters();
  }

  void _applyFilters() {
    // Filter tasks first
    List<Map<String, dynamic>> ongoingTasks = _allTasks.where((task) {
      return _matchesFilters(task) && (task['completed'] == false);
    }).toList();

    List<Map<String, dynamic>> completedTasks = _allTasks.where((task) {
      return _matchesFilters(task) && (task['completed'] == true);
    }).toList();

    // Sort ongoing tasks by due date (closest first)
    ongoingTasks.sort((a, b) {
      // Tasks without due dates come last
      if (a['dueDate'] == null && b['dueDate'] == null) return 0;
      if (a['dueDate'] == null) return 1;
      if (b['dueDate'] == null) return -1;

      // Compare due dates
      DateTime aDate = DateTime.parse(a['dueDate']);
      DateTime bDate = DateTime.parse(b['dueDate']);
      return aDate.compareTo(bDate);
    });

    // Sort completed tasks by completion date (most recent first)
    completedTasks.sort((a, b) {
      // Tasks without completion dates should be extremely rare, but handle just in case
      if (a['completedDate'] == null && b['completedDate'] == null) return 0;
      if (a['completedDate'] == null) return 1;
      if (b['completedDate'] == null) return -1;

      // Compare completion dates (descending - newest first)
      DateTime aDate = DateTime.parse(a['completedDate']);
      DateTime bDate = DateTime.parse(b['completedDate']);
      return bDate.compareTo(aDate); // Note the reversed order
    });

    // Update the filtered lists
    _filteredOngoingTasks = ongoingTasks;
    _filteredCompletedTasks = completedTasks;

    notifyListeners();
  }

  bool _matchesFilters(Map<String, dynamic> task) {
    final matchesSearch = _search.isEmpty ||
        task['title'].toLowerCase().contains(_search.toLowerCase());

    final matchesType = _type == 'All' || task['type'] == _type;
    final matchesCategory = _category == 'All' || task['category'] == _category;
    final matchesDifficulty = _difficulty == 'All' || task['difficulty'] == _difficulty;

    return matchesSearch && matchesType && matchesCategory && matchesDifficulty;
  }

  // Force reload tasks from Firebase
  Future<void> reloadTasks() async {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    // Set loading state
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Cancel existing subscription
    _tasksSubscription?.cancel();
    _tasksSubscription = null;

    // Clear tasks
    _allTasks = [];
    _filteredOngoingTasks = [];
    _filteredCompletedTasks = [];

    try {
      // Small delay to ensure connection can be re-established if needed
      await Future.delayed(Duration(milliseconds: 300));

      // Check for tasks that need to be reset
      await checkForTaskResets();

      // Reinitialize listener
      _initTasksListener();
    } catch (e) {
      _isLoading = false;
      _error = "Failed to reload tasks: $e";
      notifyListeners();
    }
  }

  // Clear all tasks
  Future<void> clearAllTasks() async {
    if (_auth.currentUser == null) {
      _error = "No authenticated user";
      notifyListeners();
      return;
    }

    final String userId = _auth.currentUser!.uid;

    try {
      final batch = _firestore.batch();

      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .get();

      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error clearing tasks: $e");
      _error = "Failed to clear tasks: $e";
      notifyListeners();
    }
  }

}



class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with AutomaticKeepAliveClientMixin {
  bool showOngoing = true; // Determines whether to show 'Ongoing' or 'Completed' Tasks Page
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTaskProvider();
    });
  }

  void _initializeTaskProvider() async {
    if (!_isInitialized) {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      setState(() {
        _isInitialized = true;
      });

      // Check if task provider is already loading
      if (!taskProvider.isLoading) {
        await taskProvider.reloadTasks();
      }
    }
  }

  // Pull to refresh implementation
  Future<void> _refreshTasks() async {
    try {
      await Provider.of<TaskProvider>(context, listen: false).reloadTasks();
    } catch (e) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh tasks: $e')),
      );
    }
  }

  // Display addTask dialog
  void addTask(BuildContext context) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    String selectedType = 'Daily';
    String selectedCategory = 'Physical';
    String selectedDifficulty = 'Easy';
    DateTime? dueDate;
    bool showError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Create Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    //Title Input
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Name',
                        errorText: showError && titleController.text.isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),

                    // Description input
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                    ),

                    // Type Dropdown Menu
                    DropdownButtonFormField(
                      value: selectedType,
                      // Maps each type to the dropdown menu
                      items: ['Daily', 'Weekly', 'Monthly', 'One-Time']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Type'),
                    ),

                    // Category Dropdown menu
                    DropdownButtonFormField(
                      value: selectedCategory,
                      // Maps each category to the dropdown menu
                      items: ['Physical', 'Intellectual', 'Academic', 'Lifestyle', 'Miscellaneous']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Category'),
                    ),

                    //Difficulty 3-way toggle-button
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: ToggleButtons(
                        isSelected: [
                          selectedDifficulty == 'Easy',
                          selectedDifficulty == 'Medium',
                          selectedDifficulty == 'Hard',
                        ],
                        onPressed: (int index) {
                          setDialogState(() {
                            selectedDifficulty = ['Easy', 'Medium', 'Hard'][index];
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        fillColor: Colors.deepPurple,
                        color: Colors.grey,
                        children: [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Easy')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Medium')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Hard')),
                        ],
                      ),
                    ),

                    // If type is One-Time, show due date picker
                    if (selectedType == 'One-Time')
                      TextButton(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        child: Text(dueDate == null ? 'Pick Due Date' : DateFormat.yMMMd().format(dueDate!)),
                      ),
                    if (showError && selectedType == 'One-Time' && dueDate == null)
                      Text('Due Date is required', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              actions: [
                TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    // Only show error if title is empty or due date is missing for "One-Time" task
                    if (titleController.text.isEmpty ||
                        (selectedType == 'One-Time' && dueDate == null)) {
                      setDialogState(() => showError = true);
                    } else {
                      // Add task to the provider
                      Provider.of<TaskProvider>(context, listen: false).addTask({
                        'title': titleController.text,
                        'description': descController.text.isEmpty ? null : descController.text,
                        'type': selectedType,
                        'category': selectedCategory,
                        'difficulty': selectedDifficulty,
                        'completed': false,
                        'dueDate': dueDate?.toIso8601String(),
                        'createdAt': DateTime.now().toIso8601String(), // Add creation timestamp
                      });

                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show dialog for editing tasks
  void editTask(BuildContext context, Map<String, dynamic> task) {
    TaskDialogService.showEditTaskDialog(context, task);
  }

  // Show Filter Dialog
  void showFilterDialog(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    // Get current filter values from the provider
    TextEditingController searchController = TextEditingController(text: taskProvider.currentSearch);
    String selectedType = taskProvider.currentType;
    String selectedCategory = taskProvider.currentCategory;
    String selectedDifficulty = taskProvider.currentDifficulty;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Filter Tasks'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Search by name
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: 'Search by Name',
                      ),
                    ),

                    // Filter by Type
                    DropdownButtonFormField(
                      value: selectedType,
                      items: ['All', 'Daily', 'Weekly', 'Monthly', 'One-Time']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Type'),
                    ),

                    // Filter by Category
                    DropdownButtonFormField(
                      value: selectedCategory,
                      items: ['All', 'Physical', 'Intellectual', 'Academic', 'Lifestyle', 'Miscellaneous']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value as String;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Category'),
                    ),

                    // Filter by Difficulty
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: ToggleButtons(
                        isSelected: [
                          selectedDifficulty == 'All',
                          selectedDifficulty == 'Easy',
                          selectedDifficulty == 'Medium',
                          selectedDifficulty == 'Hard',
                        ],
                        onPressed: (int index) {
                          setDialogState(() {
                            selectedDifficulty = ['All','Easy', 'Medium', 'Hard'][index];
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        selectedColor: Colors.white,
                        fillColor: Colors.deepPurple,
                        color: Colors.grey,
                        children: [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 13), child: Text('All')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 13), child: Text('Easy')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 13), child: Text('Medium')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 13), child: Text('Hard')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Reset Filters
              actions: [
                TextButton(
                  child: Text('Reset'),
                  onPressed: () {
                    taskProvider.updateFilters(
                      search: '',
                      type: 'All',
                      category: 'All',
                      difficulty: 'All',
                    );
                    Navigator.pop(context);
                  },
                ),

                // Cancel Filter Select
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),

                // Apply Filters
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    taskProvider.updateFilters(
                      search: searchController.text,
                      type: selectedType,
                      category: selectedCategory,
                      difficulty: selectedDifficulty,
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show reward dialog when a task is completed
  void _showRewardDialog(BuildContext context, TaskReward reward, String taskTitle) {
    showDialog(
      context: context,
      builder: (context) => RewardDialog(reward: reward, taskTitle: taskTitle),
    );
  }

  // Handle task completion and show reward dialog
  Future<void> _handleTaskCompletion(BuildContext context, String taskId, String taskTitle) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final TaskReward reward = await taskProvider.completeTask(taskId);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show reward dialog
      _showRewardDialog(context, reward, taskTitle);

      // Check for level ups after showing the reward dialog
      final levelResult = await LevelManager.checkAndProcessLevelUps(context);

      print("Success: $levelResult['success']");
      print("LeveledUp: $levelResult['leveledUp']");
      // If leveled up, show level up notification
      if (levelResult['success'] == true && levelResult['leveledUp'] == true) {
        print("Level up dialog show");
        // Small delay before showing level up dialog
        await Future.delayed(Duration(milliseconds: 500));

        // Show level up dialog
        showLevelUpDialog(context,levelResult['newLevel']);
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to complete task: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(errorMessage),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshTasks,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  // If no tasks, show empty list indicator
  Widget _buildEmptyListWidget(bool isOngoing) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOngoing ? Icons.assignment_outlined : Icons.assignment_turned_in_outlined,
            size: 60,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            isOngoing ? 'No ongoing tasks' : 'No completed tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            isOngoing
                ? 'Add a new task to get started'
                : 'Complete tasks to see them here',
          ),
          if (isOngoing)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                onPressed: () => addTask(context),
                child: Text('Add Task'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ToggleButtons(
                isSelected: [showOngoing, !showOngoing],
                onPressed: (int index) {
                  setState(() {
                    showOngoing = index == 0;
                  });
                },
                children: [
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text('Ongoing'),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text('Completed'),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(icon: Icon(Icons.add), onPressed: () => addTask(context)),
                  IconButton(
                    icon: Icon(Icons.filter_list),
                    onPressed: () => showFilterDialog(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _refreshTasks,
                  ),
                ],
              ),
            ],
          ),
          if (taskProvider.isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (taskProvider.error != null)
            Expanded(
              child: _buildErrorWidget(taskProvider.error!),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTasks,

                // Shows Task List
                child: showOngoing
                    ? (taskProvider.ongoingTasks.isEmpty
                    ? ListView(
                  // Need ListView here for RefreshIndicator to work
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _buildEmptyListWidget(true),
                    ),
                  ],
                )
                    : ListView.builder(
                  itemCount: taskProvider.ongoingTasks.length,
                  itemBuilder: (context, index) {
                    final task = taskProvider.ongoingTasks[index];
                    return Dismissible(
                      key: Key(task['id']),
                      background: Container(
                        color: Colors.green,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.check, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Complete task if swiping left to right
                          await _handleTaskCompletion(
                              context, task['id'], task['title']);
                          return false; // Don't dismiss the item
                        } else {
                          // Delete task
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Confirm"),
                                content: Text(
                                    "Are you sure you want to delete this task?"),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: Text("CANCEL"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: Text("DELETE"),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      // Delete task when swiping right to left
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                          taskProvider.deleteTask(task['id']);
                        }
                      },
                      child: GestureDetector(
                        onTap: () => editTask(context, task),
                        child: TaskCard(
                          title: task['title'],
                          type: task['type'],
                          category: task['category'],
                          dueDate: task['dueDate'],
                          onComplete: () => _handleTaskCompletion(
                              context, task['id'], task['title']),
                        ),
                      ),
                    );
                  },
                ))
                    : (taskProvider.completedTasks.isEmpty
                    ? ListView(
                  // Need ListView here for RefreshIndicator to work
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: _buildEmptyListWidget(false),
                    ),
                  ],
                )
                    : ListView.builder(
                  itemCount: taskProvider.completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = taskProvider.completedTasks[index];
                    DateTime? completedDate;
                    if (task['completedDate'] != null) {
                      completedDate = DateTime.parse(task['completedDate']);
                    }

                    return Dismissible(
                      key: Key(task['id']),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Confirm"),
                              content: Text(
                                  "Are you sure you want to delete this completed task?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text("CANCEL"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text("DELETE"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        taskProvider.deleteTask(task['id']);
                      },
                      child: GestureDetector(
                        onTap: () => editTask(context, task),
                        child: TaskCard(
                          title: task['title'],
                          type: task['type'],
                          category: task['category'],
                          onComplete: null, // No complete button for completed tasks
                          completedDate: completedDate,
                        ),
                      ),
                    );
                  },
                )),
              ),
            ),
        ],
      ),
    );
  }
}