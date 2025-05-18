import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'custom_widgets.dart';


class ClassPage extends StatefulWidget {
  @override
  _ClassPageState createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  TabController? _tabController;
  List<Map<String, dynamic>> classList = [];
  bool isLoading = true;
  int userLevel = 1;
  String? currentClass;
  List<String> userClasses = [];
  Map<String, dynamic>? selectedClass;
  List<String> userClassTypes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadClasses();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;

          setState(() {
            userLevel = data['userLevel'] ?? 1;

            // Handle class field which might be a DocumentReference
            if (data['class'] is String) {
              currentClass = data['class'];
            } else if (data['class'] != null) {
              // If it's a reference, use the ID
              currentClass = (data['class'] as dynamic).id;
            } else {
              currentClass = null;
            }

            // Handle classes array which might contain DocumentReferences
            userClasses = [];
            if (data['classes'] != null && data['classes'] is List) {
              for (var classItem in data['classes']) {
                if (classItem is String) {
                  userClasses.add(classItem);
                } else if (classItem is DocumentReference) {
                  // We'll store the document IDs for comparison later
                  userClasses.add(classItem.id);
                }
              }
            }
          });

          print('DEBUG: User data loaded - Level: $userLevel, Current class: $currentClass');
          print('DEBUG: User classes: $userClasses');
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }


  Future<void> _loadClasses() async {
    try {
      print('DEBUG: Starting to load classes from Firestore');
      final classesSnapshot = await _firestore.collection('classes').get();
      print('DEBUG: Retrieved ${classesSnapshot.docs.length} classes from Firestore');

      final classes = await Future.wait(classesSnapshot.docs.map((doc) async {
        final data = doc.data();
        final skillsRaw = data['skills'] ?? [];

        print('DEBUG: Class "${data['className'] ?? 'Unknown'}" (ID: ${doc.id}) - Skills raw type: ${skillsRaw.runtimeType}');
        print('DEBUG: Skills raw data: $skillsRaw');

        // Process skills based on their type
        List<dynamic> processedSkills = [];

        if (skillsRaw is List) {
          for (var skill in skillsRaw) {
            if (skill is DocumentReference) {
              print('DEBUG: Found skill reference: ${skill.path}');
              try {
                final skillDoc = await skill.get();
                if (skillDoc.exists) {
                  final skillData = skillDoc.data() as Map<String, dynamic>?;
                  if (skillData != null) {
                    processedSkills.add({
                      'name': skillData['name'] ?? 'Unknown Skill',
                      'description': skillData['description'] ?? 'No description available',
                      'reference': skill,
                    });
                    print('DEBUG: Resolved skill reference to: ${skillData['name']}');
                  } else {
                    processedSkills.add(skill); // Keep original reference if no data
                    print('DEBUG: Skill document has no data');
                  }
                }
              } catch (e) {
                print('DEBUG: Error resolving skill reference: $e');
                processedSkills.add(skill); // Keep original reference on error
              }
            } else {
              processedSkills.add(skill); // Keep as is if not a reference
              print('DEBUG: Non-reference skill: $skill');
            }
          }
        } else {
          print('DEBUG: Skills not in expected list format: $skillsRaw');
        }

        if (processedSkills.isNotEmpty) {
          print('DEBUG: First processed skill for "${data['className']}": ${_formatSkill(processedSkills.first)}');
        } else {
          print('DEBUG: No processed skills for class "${data['className'] ?? 'Unknown'}"');
        }

        return {
          'id': doc.id,
          'className': data['className'] ?? 'Unknown Class',
          'reqLevel': data['reqLevel'] ?? 1,
          'type': data['type'] ?? 'basic',
          'description': data['description'] ?? 'No description available',
          'skills': processedSkills,
          'rawSkills': skillsRaw, // Keep raw skills for debugging
        };
      }).toList());


      setState(() {
        classList = classes;
        isLoading = false;
      });

      print('DEBUG: Finished loading ${classes.length} classes with their skills');
      for (var classData in classes) {
        final skills = classData['skills'] as List;
        print('DEBUG: Class "${classData['className']}" has ${skills.length} processed skills');
      }
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        isLoading = false;
      });
    }

    _updateUserClassTypes();
  }

  void _updateUserClassTypes() {
    userClassTypes = [];

    // For each class ID the user has, find its type
    for (String classId in userClasses) {
      for (var classData in classList) {
        if (classData['id'] == classId) {
          String type = classData['type'].toString().toLowerCase();
          if (!userClassTypes.contains(type)) {
            userClassTypes.add(type);
          }
          break;
        }
      }
    }

    print('DEBUG: User class types: $userClassTypes');
  }

  String _formatSkill(dynamic skill) {
    if (skill is Map<String, dynamic>) {
      return '{name: ${skill['name']}, description: ${skill['description'] ?? 'No description'}}';
    } else if (skill is String) {
      return skill;
    } else {
      print('DEBUG: Unexpected skill type: ${skill.runtimeType}');
      return skill.toString();
    }
  }

  void _showClassDialog(Map<String, dynamic> classData) {
    print('DEBUG: Opening dialog for class "${classData['className']}"');
    print('DEBUG: Class skills: ${classData['skills']}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(classData['className']),
        content: Text(classData['description']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showConfirmDialog(classData);
            },
            child: Text('Promote'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(Map<String, dynamic> classData) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Promotion'),
        content: Text('Are you sure you want to promote to ${classData['className']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _promoteToClass(classData);
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _promoteToClass(Map<String, dynamic> classData) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Create a reference to the class document
        final classRef = _firestore.collection('classes').doc(classData['id']);
        print('DEBUG: Creating class reference: ${classRef.path}');

        // Add the class reference to user's classes and set as current class
        await _firestore.collection('users').doc(userId).update({
          'class': classRef,  // Store reference instead of entire class data
          'classes': FieldValue.arrayUnion([classRef]),  // Store reference in array
        });

        // Update local state - use the class ID for consistency
        setState(() {
          currentClass = classData['id']; // Store ID instead of name

          if (!userClasses.contains(classData['id'])) {
            userClasses.add(classData['id']);
          }

          // Update class types after promoting
          _updateUserClassTypes();
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully promoted to ${classData["className"]}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error promoting to class: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to promote to class: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _canSelectClass(Map<String, dynamic> classData) {
    final String type = classData['type'].toString().toLowerCase();
    final int reqLevel = classData['reqLevel'] ?? 1;
    final String classId = classData['id'];

    // Check if user already has this class (by ID)
    if (userClasses.contains(classId)) return false;

    // Check level requirement
    if (userLevel < reqLevel) return false;

    // Basic class restriction - can't select basic if already have a basic class
    if (type == 'basic' && userClassTypes.contains('basic')) return false;

    // Advanced class restriction - must be level 20+
    if (type == 'advanced' && userLevel < 20) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
      children: [
        // Tab buttons
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController?.animateTo(0);
                    setState(() {});
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabController?.index == 0
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      'Basic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _tabController?.index == 0
                            ? theme.primaryColor
                            : theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: userLevel >= 20 ? () {
                    _tabController?.animateTo(1);
                    setState(() {});
                  } : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabController?.index == 1
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Advanced',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: userLevel >= 20
                                ? (_tabController?.index == 1
                                ? theme.primaryColor
                                : theme.textTheme.bodyLarge?.color)
                                : theme.disabledColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (userLevel < 20)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: theme.disabledColor),
                            ),
                            child: Text(
                              'Lvl 20+',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.disabledColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Class list
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: userLevel >= 20
                ? AlwaysScrollableScrollPhysics()
                : NeverScrollableScrollPhysics(),
            children: [
              // Basic Classes Tab
              _buildClassList('basic'),
              // Advanced Classes Tab
              _buildClassList('advanced'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassList(String type) {
    final filteredClasses = classList.where(
            (classData) => classData['type'].toString().toLowerCase() == type
    ).toList();

    print('DEBUG: Building $type class list with ${filteredClasses.length} classes');

    if (filteredClasses.isEmpty) {
      return Center(
        child: Text(
          'No ${type.toLowerCase()} classes available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredClasses.length,
      itemBuilder: (context, index) {
        final classData = filteredClasses[index];
        final skills = classData['skills'] as List? ?? [];
        print('DEBUG: Rendering class card for "${classData['className']}" with ${skills.length} skills');

        return ClassCard(
          classData: classData,
          onTap: _canSelectClass(classData)
              ? () => _showClassDialog(classData)
              : null,
          userLevel: userLevel,
          userClasses: userClasses,
        );
      },
    );
  }
}

