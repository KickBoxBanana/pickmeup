import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'custom_widgets.dart';


class SkillsPage extends StatefulWidget {
  @override
  _SkillsPageState createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String currentSkillTree = 'Adventurer';
  List<String> availableSkillTrees = ['Adventurer'];

  List<Map<String, dynamic>> skillsData = [];
  List<String> userLearnedSkills = [];
  int userSkillPoints = 0;
  bool _isLoading = true;

  Map<String, List<Map<String, dynamic>>> classSkillsMap = {};
  Map<String, Map<String, dynamic>> skillsMap = {};

  // Track expanded skill cards
  Set<String> expandedSkills = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Load user data
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();

          // Get user's skill points
          userSkillPoints = userData?['skillPoints'] ?? 0;

          // Get user's learned skills
          if (userData?['skills'] != null && userData!['skills'] is List) {
            List<dynamic> skillsRaw = userData['skills'];
            userLearnedSkills = skillsRaw.map<String>((skillRef) {
              if (skillRef is DocumentReference) {
                return skillRef.id;
              } else if (skillRef is String) {
                final parts = skillRef.split('/');
                return parts.last;
              }
              return '';
            }).where((id) => id.isNotEmpty).toList();
          }

          // Load available classes
          List<String> userClassIds = [];
          Map<String, String> classNameMap = {}; // Map to store id -> name mappings

          if (userData?['classes'] != null && userData!['classes'] is List) {
            List<dynamic> classesRaw = userData['classes'];
            userClassIds = classesRaw.map<String>((classRef) {
              if (classRef is DocumentReference) {
                return classRef.id;
              } else if (classRef is String) {
                final parts = classRef.split('/');
                return parts.last;
              }
              return '';
            }).where((id) => id.isNotEmpty).toList();

            // Always add Adventurer
            classNameMap['def_class'] = 'Adventurer';

            // Fetch proper class names from Firestore
            for (String classId in userClassIds) {
              if (classId == 'def_class') {
                continue; // Already handled
              }

              try {
                final classDoc = await _firestore.collection('classes').doc(classId).get();
                if (classDoc.exists && classDoc.data() != null) {
                  final className = classDoc.data()!['name'] ?? '';
                  if (className.isNotEmpty) {
                    classNameMap[classId] = className;
                  } else {
                    // Fallback to formatted ID if name not found
                    classNameMap[classId] = _formatClassId(classId);
                  }
                } else {
                  // Fallback to formatted ID if document not found
                  classNameMap[classId] = _formatClassId(classId);
                }
              } catch (e) {
                print('Error fetching class name for $classId: $e');
                classNameMap[classId] = _formatClassId(classId);
              }
            }
          }

          // Always ensure Adventurer is available
          if (!userClassIds.contains('def_class')) {
            userClassIds.add('def_class');
          }

          // Add available class skill trees with proper names
          setState(() {
            // Map class IDs to their proper display names
            availableSkillTrees = userClassIds.map((id) =>
            classNameMap[id] ?? _formatClassId(id)
            ).toList();
          });

          // Load skills for all available skill trees
          await _loadAllSkillTrees();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fallback function in case classname not found
  String _formatClassId(String classId) {
    // Handle common class ID patterns
    if (classId == 'def_class') return 'Adventurer';
    if (classId == 'war_class') return 'Warrior';
    if (classId == 'mag_class') return 'Mage';
    if (classId == 'hunt_class') return 'Hunter';

    // For other patterns, try to extract meaningful name
    if (classId.endsWith('_class')) {
      String nameBase = classId.substring(0, classId.indexOf('_class'));
      // Capitalize first letter
      if (nameBase.isNotEmpty) {
        return nameBase[0].toUpperCase() + nameBase.substring(1);
      }
    }

    // Default fallback: make first letter uppercase and remove underscores
    if (classId.isEmpty) return 'Unknown';
    return classId
        .split('_')
        .map((part) => part.isNotEmpty
        ? part[0].toUpperCase() + part.substring(1)
        : '')
        .join(' ');
  }



  Future<void> _loadAllSkillTrees() async {
    try {
      // Clear existing maps to avoid stale data
      skillsMap.clear();
      classSkillsMap.clear();

      print('DEBUG: Starting to load skill trees...');

      // Create a mapping from display names to class IDs
      Map<String, String> displayToIdMap = {};

      // Add mapping for Adventurer
      displayToIdMap['Adventurer'] = 'def_class';

      // Add mappings for other classes based on naming patterns
      for (String displayName in availableSkillTrees) {
        if (displayName == 'Adventurer') continue; // Already handled

        if (displayName == 'Warrior') displayToIdMap[displayName] = 'war_class';
        else if (displayName == 'Mage') displayToIdMap[displayName] = 'mag_class';
        else if (displayName == 'Hunter') displayToIdMap[displayName] = 'hunt_class';
        else {
          // Generate ID from display name as fallback
          String classId = displayName.toLowerCase().substring(0, 3) + '_class';
          displayToIdMap[displayName] = classId;
        }
      }

      // Load all skills first for reference
      final allSkillsSnapshot = await _firestore.collection('skills').get();
      print('DEBUG: Found ${allSkillsSnapshot.docs.length} total skills in the skills collection');

      // Store all skills in the map for quick lookup
      for (var doc in allSkillsSnapshot.docs) {
        skillsMap[doc.id] = {
          ...doc.data(),
          'id': doc.id,
        };
      }

      // Initialize all class skill maps as empty arrays
      for (String className in availableSkillTrees) {
        classSkillsMap[className] = [];
      }

      // LOAD ADVENTURER SKILLS - directly from def_class document
      print('DEBUG: Loading Adventurer skills from def_class...');
      try {
        final defClassDoc = await _firestore.collection('classes').doc('def_class').get();

        if (defClassDoc.exists && defClassDoc.data() != null) {
          final data = defClassDoc.data()!;
          if (data['skills'] != null && data['skills'] is List) {
            List<dynamic> skillRefs = data['skills'];
            print('DEBUG: Found ${skillRefs.length} skill references in def_class');

            List<Map<String, dynamic>> adventurerSkills = [];

            for (var skillRef in skillRefs) {
              try {
                if (skillRef is DocumentReference) {
                  String skillId = skillRef.id;

                  // Load the skill directly from Firestore
                  final skillDoc = await _firestore.collection('skills').doc(skillId).get();
                  if (skillDoc.exists && skillDoc.data() != null) {
                    adventurerSkills.add({
                      ...skillDoc.data()!,
                      'id': skillDoc.id,
                    });
                    print('DEBUG: Loaded skill: ${skillDoc.id}');
                  }
                }
              } catch (e) {
                print('DEBUG: Error loading skill: $e');
              }
            }

            print('DEBUG: Successfully loaded ${adventurerSkills.length} Adventurer skills');
            classSkillsMap['Adventurer'] = adventurerSkills;
          }
        }
      } catch (e) {
        print('DEBUG: Error loading Adventurer skills: $e');
      }

      // LOAD OTHER CLASSES - Try loading with standardized document IDs
      for (String className in availableSkillTrees.where((c) => c != 'Adventurer')) {
        print('DEBUG: Loading skills for class: $className');

        // Get the document ID from our mapping
        String docId = displayToIdMap[className] ??
            (className.toLowerCase().substring(0, 3) + '_class');

        try {
          final classDoc = await _firestore.collection('classes').doc(docId).get();

          if (classDoc.exists && classDoc.data() != null) {
            final data = classDoc.data()!;

            // Check if skills field exists
            if (data['skills'] != null && data['skills'] is List) {
              List<dynamic> skillRefs = data['skills'];
              print('DEBUG: Found ${skillRefs.length} skill references for $className');

              List<Map<String, dynamic>> classSkills = [];

              for (var skillRef in skillRefs) {
                if (skillRef is DocumentReference) {
                  String skillId = skillRef.id;

                  // Load the skill directly from Firestore
                  final skillDoc = await _firestore.collection('skills').doc(skillId).get();
                  if (skillDoc.exists && skillDoc.data() != null) {
                    classSkills.add({
                      ...skillDoc.data()!,
                      'id': skillDoc.id,
                    });
                  }
                }
              }

              print('DEBUG: Successfully loaded ${classSkills.length} skills for $className');
              classSkillsMap[className] = classSkills;
            } else {
              print('DEBUG: No skills array found for $className');

              // If no skills array, try assigning skills based on type (if applicable)
              if (className == 'Warrior') {
                List<Map<String, dynamic>> physicalSkills = allSkillsSnapshot.docs
                    .where((doc) => doc.data()['type'] == 'physical')
                    .map<Map<String, dynamic>>((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
                    .toList();

                if (physicalSkills.isNotEmpty) {
                  classSkillsMap[className] = physicalSkills;
                  print('DEBUG: Assigned ${physicalSkills.length} physical skills to $className');
                }
              } else if (className == 'Mage') {
                List<Map<String, dynamic>> magicSkills = allSkillsSnapshot.docs
                    .where((doc) => doc.data()['type'] == 'magic')
                    .map<Map<String, dynamic>>((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
                    .toList();

                if (magicSkills.isNotEmpty) {
                  classSkillsMap[className] = magicSkills;
                  print('DEBUG: Assigned ${magicSkills.length} magic skills to $className');
                }
              } else if (className == 'Hunter') {
                List<Map<String, dynamic>> hunterSkills = allSkillsSnapshot.docs
                    .where((doc) =>
                doc.data()['type'] == 'ranged' ||
                    doc.data()['type'] == 'physical')
                    .map<Map<String, dynamic>>((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
                    .toList();

                if (hunterSkills.isNotEmpty) {
                  classSkillsMap[className] = hunterSkills;
                  print('DEBUG: Assigned ${hunterSkills.length} skills to $className');
                }
              }
            }
          } else {
            print('DEBUG: Class document not found for $className ($docId)');
          }
        } catch (e) {
          print('DEBUG: Error loading skills for $className: $e');
        }
      }

      // Final check of loaded skills
      classSkillsMap.forEach((className, skills) {
        print('DEBUG: Class $className has ${skills.length} skills loaded');
      });

      // Update UI with current skill tree data
      _updateSkillsData();
      print('DEBUG: Skills data updated, ${skillsData.length} skills in current view');

    } catch (e) {
      print('DEBUG: Error in _loadAllSkillTrees: $e');
    }
  }

  void _updateSkillsData() {
    setState(() {
      // Get skills for the current selected skill tree
      if (classSkillsMap.containsKey(currentSkillTree)) {
        List<Map<String, dynamic>> currentTreeSkills = classSkillsMap[currentSkillTree] ?? [];

        if (currentTreeSkills.isNotEmpty) {
          // If we have skills, update the skillsData
          skillsData = List.from(currentTreeSkills);

          // Print some debug info
          print('DEBUG: Updated skillsData with ${skillsData.length} skills for $currentSkillTree');
          print('DEBUG: First skill: ${skillsData.isNotEmpty ? skillsData.first['name'] : 'none'}');
        } else {
          // If no skills for this class, set empty list
          print('DEBUG: No skills found for $currentSkillTree, setting empty skillsData');
          skillsData = [];
        }
      } else {
        print('DEBUG: currentSkillTree "$currentSkillTree" not found in classSkillsMap');
        skillsData = [];
      }
    });
  }

  Future<void> _learnSkill(Map<String, dynamic> skill) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Check if user has enough skill points
      int requiredPoints = skill['spCost'] ?? 1;
      if (userSkillPoints < requiredPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough skill points!')),
        );
        return;
      }

      // Check prerequisites
      bool prerequisitesMet = true;
      List<String> missingPrereqs = [];

      if (skill['prerequisites'] != null && skill['prerequisites'] is List) {
        for (var prereq in skill['prerequisites']) {
          String prereqId;

          if (prereq is DocumentReference) {
            prereqId = prereq.id;
          } else if (prereq is String) {
            final parts = prereq.split('/');
            prereqId = parts.last;
          } else {
            continue;
          }

          if (!userLearnedSkills.contains(prereqId)) {
            prerequisitesMet = false;
            // Get prerequisite name
            String prereqName = skillsMap[prereqId]?['name'] ?? 'Unknown Skill';
            missingPrereqs.add(prereqName);
          }
        }
      }

      if (!prerequisitesMet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Missing prerequisites: ${missingPrereqs.join(", ")}')),
        );
        return;
      }

      // Get reference to the skill
      DocumentReference skillRef = _firestore.collection('skills').doc(skill['id']);

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'skills': FieldValue.arrayUnion([skillRef]),
        'skillPoints': FieldValue.increment(-requiredPoints),
      });

      // Update local state
      setState(() {
        userLearnedSkills.add(skill['id']);
        userSkillPoints -= requiredPoints;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${skill['name']} learned successfully!')),
      );
    } catch (e) {
      print('Error learning skill: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to learn skill: $e')),
      );
    }
  }

  void _toggleSkillExpansion(String skillId) {
    setState(() {
      if (expandedSkills.contains(skillId)) {
        expandedSkills.remove(skillId);
      } else {
        expandedSkills.add(skillId);
      }
    });
  }

  // Modified _buildEffectsList method for the _SkillsPageState class
  List<Widget> _buildEffectsList(Map<String, dynamic> skill) {
    List<Widget> effectWidgets = [];

    // Check for different types of effects
    if (skill['effects'] != null) {
      if (skill['effects'] is Map) {
        Map<String, dynamic> effects = skill['effects'];
        effects.forEach((key, value) {
          effectWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• $key: '),
                  _formatEffectValue(value),
                ],
              ),
            ),
          );
        });
      } else if (skill['effects'] is List) {
        List<dynamic> effects = skill['effects'];
        for (var effect in effects) {
          if (effect is String) {
            effectWidgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('• $effect'),
              ),
            );
          }
        }
      } else if (skill['effects'] is String) {
        effectWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text('• ${skill["effects"]}'),
          ),
        );
      }
    }

    // Add damage info if available
    if (skill['damage'] != null) {
      effectWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Damage: '),
              Text(
                '${skill["damage"]}',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add heal info if available
    if (skill['heal'] != null) {
      effectWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Heal: '),
              Text(
                '${skill["heal"]}',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add stat bonuses if available
    ['strength', 'intelligence', 'vitality', 'wisdom', 'phyatk', 'phydef', 'magatk', 'magdef'].forEach((stat) {
      if (skill[stat] != null && skill[stat] != 0) {
        String displayStat = stat.toUpperCase();
        effectWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• $displayStat: '),
                _formatStatValue(skill[stat]),
              ],
            ),
          ),
        );
      }
    });

    // If no effects were added, show a default message
    if (effectWidgets.isEmpty) {
      effectWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text('• No specific effects listed'),
        ),
      );
    }

    return effectWidgets;
  }

// Helper method to format stat values with colors and proper formatting
  Widget _formatStatValue(dynamic value) {
    if (value == null) return Text('0');

    bool isPositive = value > 0;
    bool isDecimal = value is double || (value.toString().contains('.') && value.toString().split('.')[1] != '0');

    String displayText;
    Color textColor;

    if (isDecimal) {
      // Convert to percentage
      double percentage = value * 100;
      displayText = '${isPositive ? '' : ''}${percentage.toStringAsFixed(1)}%';
      textColor = isPositive ? Colors.green : Colors.red;
    } else {
      // Format as integer
      displayText = '${isPositive ? '+' : ''}$value';
      textColor = isPositive ? Colors.green : Colors.red;
    }

    return Text(
      displayText,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

// Helper method for formatting effect values that might be stats or other data
  Widget _formatEffectValue(dynamic value) {
    // If it's a number, format it as a stat
    if (value is num) {
      return _formatStatValue(value);
    }
    // If it's a string but can be parsed as a number
    else if (value is String) {
      try {
        double numValue = double.parse(value);
        return _formatStatValue(numValue);
      } catch (_) {
        // If not a number, just display as text
        return Text(value);
      }
    }
    // Otherwise just convert to string
    else {
      return Text(value.toString());
    }
  }

  IconData _getSkillIcon(String skillType) {
    switch (skillType.toLowerCase()) {
      case 'attack':
        return Icons.local_fire_department;
      case 'defense':
        return Icons.shield;
      case 'magic':
        return Icons.auto_fix_high;
      case 'support':
        return Icons.healing;
      case 'passive':
        return Icons.stars;
      case 'physical':
        return Icons.fitness_center;
      case 'ranged':
        return Icons.gps_fixed;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Skill points display
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text(
                  'Skill Points: $userSkillPoints',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Skill tree toggle
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(16),
                constraints: BoxConstraints(minWidth: 100, minHeight: 40),
                isSelected: availableSkillTrees.map((tree) => tree == currentSkillTree).toList(),
                onPressed: (index) {
                  setState(() {
                    currentSkillTree = availableSkillTrees[index];
                    _updateSkillsData();
                    // Reset expanded cards when switching trees
                    expandedSkills.clear();
                  });
                },
                children: availableSkillTrees.map((tree) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(tree),
                )).toList(),
              ),
            ),
          ),

          SizedBox(height: 8),

          // Skill cards list
          Expanded(
            child: skillsData.isEmpty
                ? Center(child: Text('No skills available for this class'))
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: skillsData.length,
              itemBuilder: (context, index) {
                final skill = skillsData[index];
                final skillId = skill['id'] as String;
                final isExpanded = expandedSkills.contains(skillId);
                final isLearned = userLearnedSkills.contains(skillId);

                return SkillInfoCard(
                  skill: skill,
                  isExpanded: isExpanded,
                  isLearned: isLearned,
                  skillsMap: skillsMap,
                  learnedSkills: userLearnedSkills,
                  onToggleExpand: () => _toggleSkillExpansion(skillId),
                  onLearn: () => _learnSkill(skill),
                  getSkillIcon: _getSkillIcon,
                  buildEffectsList: () => _buildEffectsList(skill),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
