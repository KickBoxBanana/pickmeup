import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_pages.dart';
import 'custom_widgets.dart';
import 'game_mechanics.dart';
import 'game_pages.dart';
import 'profile_pages.dart';
import 'settings_page.dart';
import 'shop_page.dart';
import 'task_dialog_service.dart';
import 'task_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  try {
    print("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully!");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TaskProvider()),
        ChangeNotifierProvider(create: (context) => settingsProvider),
        // Add auth state provider
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Define light theme
    final ThemeData lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      primaryColor: Colors.deepPurple,
      colorScheme: ColorScheme.light(
        primary: Colors.deepPurple,
        secondary: Colors.deepPurpleAccent,
        surface: Colors.white,
        background: Colors.grey[100]!,
        error: Colors.red,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[600],
      ),
      iconTheme: IconThemeData(color: Colors.deepPurple),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,  // Keep white for light theme
        shadowColor: Colors.black38,
        elevation: 4,
      ),
      toggleButtonsTheme: ToggleButtonsThemeData(
        selectedColor: Colors.white,
        fillColor: Colors.deepPurple,
        color: Colors.grey[700],
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepPurple),
        ),
      ),
    );

    // Define dark theme
    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.deepPurple,
      colorScheme: ColorScheme.dark(
        primary: Colors.deepPurple,
        secondary: Colors.deepPurpleAccent,
        surface: Colors.grey[900]!,
        background: Colors.black,
        error: Colors.redAccent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.white70,
      ),
      iconTheme: IconThemeData(color: Colors.deepPurple),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.deepPurpleAccent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: Color(0xFF2A2A2A),  // A bit lighter than background for contrast
        shadowColor: Colors.black,
        elevation: 4,
      ),
      toggleButtonsTheme: ToggleButtonsThemeData(
        selectedColor: Colors.white,
        fillColor: Colors.deepPurple,
        color: Colors.grey[400],
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.grey[900],
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepPurpleAccent),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: settingsProvider.isDarkMode ? darkTheme : lightTheme,
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    // If no user, go to login
    if (user == null) {
      return LoginPage();
    }

    // If user exists but email not verified, show verification screen
    if (!user.emailVerified) {
      return EmailVerificationPage();
    }

    // User is logged in and verified
    return HomePage();
  }
}



class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    HomeScreen(),
    TaskPage(),
    GamePage(),
    ShopPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pick-Me-Up!'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: 'Game'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Shop'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // Let the theme handle the colors
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  String? className;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> checkAndProcessLevelUp() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userData == null) return;

    final int currentLevel = userData!['userLevel'] ?? 1;
    final int currentXp = userData!['xp'] ?? 0;

    if (LevelManager.canLevelUp(currentLevel, currentXp)) {
      // User can level up
      final int newLevel = currentLevel + 1;
      final int remainingXp = LevelManager.processLevelUp(currentLevel, currentXp);

      // Update database
      await _firestore.collection('users').doc(userId).update({
        'userLevel': newLevel,
        'xp': remainingXp,
      });

      // Update local state
      setState(() {
        userData!['userLevel'] = newLevel;
        userData!['xp'] = remainingXp;
      });

      // Show level up notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Congratulations! You leveled up to level $newLevel!'),
          backgroundColor: Colors.green,
        ),
      );

      // Check if user can level up again (in case they earned a lot of XP)
      checkAndProcessLevelUp();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();

          // Get the class name from the reference
          if (data != null && data['class'] is DocumentReference) {
            final classRef = data['class'] as DocumentReference;
            final classDoc = await classRef.get();
            if (classDoc.exists) {
              final classData = classDoc.data() as Map<String, dynamic>?;
              setState(() {
                className = classData?['className'] ?? 'Unknown Class';
              });
            } else {
              setState(() {
                className = 'Unknown Class';
              });
            }
          }

          setState(() {
            userData = data;
            _isLoading = false;
          });

          // Add this line to check for level up whenever user data is loaded
          checkAndProcessLevelUp();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        className = 'Error Loading Class';
      });
    }
  }

  List<Map<String, dynamic>> _getUrgentTasks(TaskProvider taskProvider) {
    // Get all ongoing tasks
    List<Map<String, dynamic>> tasks = List.from(taskProvider.ongoingTasks);

    // Sort tasks by urgency
    tasks.sort((a, b) {
      // First priority: One-Time tasks with due dates
      bool aIsOneTime = a['type'] == 'One-Time';
      bool bIsOneTime = b['type'] == 'One-Time';

      if (aIsOneTime && !bIsOneTime) return -1;
      if (!aIsOneTime && bIsOneTime) return 1;

      // For One-Time tasks, sort by due date
      if (aIsOneTime && bIsOneTime) {
        if (a['dueDate'] != null && b['dueDate'] != null) {
          DateTime aDate = DateTime.parse(a['dueDate']);
          DateTime bDate = DateTime.parse(b['dueDate']);
          return aDate.compareTo(bDate);
        } else if (a['dueDate'] != null) {
          return -1;
        } else if (b['dueDate'] != null) {
          return 1;
        }
      }

      // Second priority: Daily > Weekly > Monthly
      final typeOrder = {'Daily': 0, 'Weekly': 1, 'Monthly': 2};
      int aTypeValue = typeOrder[a['type']] ?? 3;
      int bTypeValue = typeOrder[b['type']] ?? 3;
      if (aTypeValue != bTypeValue) {
        return aTypeValue.compareTo(bTypeValue);
      }

      // Third priority: Hard > Medium > Easy
      final difficultyOrder = {'Hard': 0, 'Medium': 1, 'Easy': 2};
      int aDifficulty = difficultyOrder[a['difficulty']] ?? 3;
      int bDifficulty = difficultyOrder[b['difficulty']] ?? 3;
      return aDifficulty.compareTo(bDifficulty);
    });

    // Return top 3 tasks or fewer if there aren't 3 tasks
    return tasks.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Access TaskProvider
    final taskProvider = Provider.of<TaskProvider>(context);
    final urgentTasks = _getUrgentTasks(taskProvider);

    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.deepPurple,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        _getInitials(userData?['name'] ?? ''),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Class: ${className ?? "Unknown"}',
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                          Text('Level: ${userData?['userLevel'] ?? "1"}',
                              style: TextStyle(color: Colors.white)),
                          Row(
                            children: [
                              Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text('Gold: ${userData?['gold'] ?? "0"}',
                                  style: TextStyle(color: Colors.white)),
                              SizedBox(width: 12),
                              Icon(Icons.diamond, color: Colors.lightBlueAccent, size: 16),
                              SizedBox(width: 4),
                              Text('Gems: ${userData?['gems'] ?? "0"}',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text('Health: ${userData?['health'] ?? 0}/${userData?['maxHealth'] ?? 100}',
                              style: TextStyle(color: Colors.white)),
                          LinearProgressIndicator(
                            value: (userData?['health'] ?? 0) / (userData?['maxHealth'] ?? 100),
                            backgroundColor: Colors.grey,
                            color: Colors.red,
                          ),
                          SizedBox(height: 5),
                          Text('XP', style: TextStyle(color: Colors.white)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'XP Progress',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: (userData!['xp'] ?? 0) /
                                          LevelManager.getRequiredXpForLevel(userData!['userLevel'] ?? 1),
                                      backgroundColor: Colors.grey[300],
                                      color: Colors.blue,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${userData!['xp'] ?? 0}/${LevelManager.getRequiredXpForLevel(userData!['userLevel'] ?? 1)}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text("Urgent Tasks",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (urgentTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "No urgent tasks. Great job!",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: urgentTasks.map((task) {
                  return GestureDetector(
                    onTap: () => TaskDialogService.showEditTaskDialog(context, task),
                    child: TaskCard(
                      title: task['title'],
                      type: task['type'],
                      category: task['category'],
                      dueDate: task['dueDate'],
                      onComplete: () => taskProvider.completeTask(task['id']),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    List<String> nameSplit = name.split(" ");
    String initials = "";

    if (nameSplit.length > 0) {
      if (nameSplit[0].isNotEmpty) {
        initials += nameSplit[0][0];
      }

      if (nameSplit.length > 1 && nameSplit[1].isNotEmpty) {
        initials += nameSplit[1][0];
      }
    }

    return initials.toUpperCase();
  }
}

extension ThemeDataExtensions on ThemeData {
  bool get isDarkTheme => brightness == Brightness.dark;
}

