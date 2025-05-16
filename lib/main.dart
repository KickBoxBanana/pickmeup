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

    final settingsProvider = SettingsProvider();
    await settingsProvider.loadSettings();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => TaskProvider()),
          ChangeNotifierProvider(create: (context) => settingsProvider),
          StreamProvider<User?>.value(
            value: FirebaseAuth.instance.authStateChanges(),
            initialData: null,
          ),
        ],
        child: MyApp(),
      ),
    );

  } catch (e) {
    print("Error initializing Firebase: $e");
  }
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

    // Starts App in AuthWrapper(Can be Login, Email Verification, or Home Page)
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: settingsProvider.isDarkMode ? darkTheme : lightTheme,
      home: AuthWrapper(),
    );
  }
}

// Handles which screen user sees on app launch
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    // If no user found, go to login
    if (user == null) {
      return LoginPage();
    }

    // If user exists but email not verified, show verification screen
    if (!user.emailVerified) {
      return EmailVerificationPage();
    }

    // User is logged in and verified
    return NavigationPage();
  }
}



class NavigationPage extends StatefulWidget {
  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    HomePage(),
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

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  // Fetch user data from database and load for display
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

  // Check whether user can level up
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

  // Returns the 3 most urgent tasks based on due date, frequency, and difficulty.
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

    return _isLoading ? Center(child: CircularProgressIndicator()) : Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display user info overview
            UserProfileCard(
              userData: userData!,
              className: className ?? "Unknown",
            ),
            SizedBox(height: 20),

            //Display most urgent tasks
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
}

extension ThemeDataExtensions on ThemeData {
  bool get isDarkTheme => brightness == Brightness.dark;
}

