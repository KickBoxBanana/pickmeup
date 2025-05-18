import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'custom_widgets.dart';
import 'game_mechanics.dart';

// Handles enemy list display and selection
class GamePage extends StatefulWidget {
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> enemies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadEnemies();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          // Get user data
          final basicUserData = userDoc.data() ?? {};

          // Get battle stats from the stats subcollection
          final battleStatsDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('stats')
              .doc('battle')
              .get();

          // Combine the user data with battle stats
          Map<String, dynamic> fullUserData = Map.from(basicUserData);

          // Create stats map structure if stats document exists
          if (battleStatsDoc.exists) {
            fullUserData['stats'] = {
              'battle': battleStatsDoc.data()
            };
          }

          setState(() {
            userData = fullUserData;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Loads enemies from database into list
  Future<void> _loadEnemies() async {
    try {
      // Get user level to filter appropriate enemies
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userLevel = userDoc.data()?['userLevel'] ?? 1;

      // Fetch enemies from Firestore with some level-based filtering
      final enemiesSnapshot = await _firestore
          .collection('enemies')
          .where('minLevel', isLessThanOrEqualTo: userLevel)
          .orderBy('minLevel')
          .get();

      List<Map<String, dynamic>> loadedEnemies = [];

      for (var doc in enemiesSnapshot.docs) {
        final enemyData = doc.data();
        enemyData['id'] = doc.id;

        // Make sure the stats field properly loads
        if (!enemyData.containsKey('stats')) {
          // If stats not directly in the document, try to retrieve them
          print('Loading stats for enemy: ${doc.id}');

          // Ensures that theres always a stats object, even if it's empty
          enemyData['stats'] = {
            'phyatk': enemyData['phyatk'] ?? 5,
            'phydef': enemyData['phydef'] ?? 3,
            'magatk': enemyData['magatk'] ?? 5,
            'magdef': enemyData['magdef'] ?? 3
          };
        }

        loadedEnemies.add(enemyData);
      }

      // Sort enemies: normal enemies first, then bosses
      loadedEnemies.sort((a, b) {
        // Sort by boss status first
        final aIsBoss = a['isBoss'] ?? false;
        final bIsBoss = b['isBoss'] ?? false;

        if (aIsBoss != bIsBoss) {
          return aIsBoss ? 1 : -1; // Non-bosses come first
        }

        // Then sort by level
        return (a['level'] ?? 0).compareTo(b['level'] ?? 0);
      });

      setState(() {
        enemies = loadedEnemies;
      });
    } catch (e) {
      print('Error loading enemies: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Get health and mana values with appropriate defaults
    final int currentHealth = userData?['health'] ?? 100;
    final int maxHealth = userData?['maxHealth'] ?? 100;
    final int currentMana = userData?['mana'] ?? 50;
    final int maxMana = userData?['maxMana'] ?? 50;

    return Scaffold(
      body: Column(
        children: [
          // Player Status Bar
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  radius: 30,
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${userData?['userLevel'] ?? 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text('HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: currentHealth / maxHealth,
                              backgroundColor: Colors.grey[300],
                              color: Colors.red,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('$currentHealth/$maxHealth', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 4),
                      // Mana bar
                      Row(
                        children: [
                          Text('MP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: currentMana / maxMana,
                              backgroundColor: Colors.grey[300],
                              color: Colors.blue,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('$currentMana/$maxMana', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Enemy List Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Enemies',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${enemies.length} found',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),

          // Enemy List
          Expanded(
            child: enemies.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No enemies available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: enemies.length,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final enemy = enemies[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: EnemyCard(
                    enemy: enemy,
                    onTap: () => _showBattleConfirmation(context, enemy),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBattleConfirmation(BuildContext context, Map<String, dynamic> enemy) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Battle Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you ready to battle ${enemy['name']}?'),
            SizedBox(height: 16),
            Text('Your Health: ${userData?['health'] ?? 100}/${userData?['maxHealth'] ?? 100}'),
            SizedBox(height: 8),
            enemy['isBoss'] == true
                ? Text(
              'Warning: This is a boss enemy!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            )
                : SizedBox.shrink(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close the dialog
              Navigator.pop(context);

              // Navigate to battle screen with enemy and user data
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BattlePage(
                    enemy: enemy,
                    userData: userData!,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
            ),
            child: Text('Battle!'),
          ),
        ],
      ),
    );
  }
}

// Handles battle logic
class BattlePage extends StatefulWidget {
  final Map<String, dynamic> enemy;
  final Map<String, dynamic> userData;

  const BattlePage({
    Key? key,
    required this.enemy,
    required this.userData,
  }) : super(key: key);

  @override
  _BattlePageState createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> with TickerProviderStateMixin {
  // Player and enemy stats
  late int playerHealth;
  late int playerMaxHealth;
  late int playerMana;
  late int playerMaxMana;
  late int enemyHealth;
  late int enemyMaxHealth;
  late int enemyMana;
  late int enemyMaxMana;

  // Avatar layers
  String? baseAvatarSprite;
  String? weaponLayerSprite;
  String? armorLayerSprite;
  String? cosmeticLayerSprite;
  AvatarLayers? userAvatarLayers;

  //Battle Stats
  late int playerPhyAtk;
  late int playerPhyDef;
  late int playerMagAtk;
  late int playerMagDef;
  late int enemyPhyAtk;
  late int enemyPhyDef;
  late int enemyMagAtk;
  late int enemyMagDef;

  // Battle state variables
  List<String> battleLog = [];
  String currentAction = "Choose an action";
  String currentSubMenu = "";
  bool playerTurn = true;
  bool battleEnded = false;

  // Mana regeneration
  double playerManaRegenPerTurn = 0.1; // Amount of mana to regenerate per turn (percentage)

  // Animation controllers
  late AnimationController _playerAttackController;
  late AnimationController _enemyAttackController;
  late AnimationController _shakeController;

  List<Skill> playerSkills = [];
  List<Skill> enemySkills = [];
  bool isLoadingSkills = true;

  BuffManager buffManager = BuffManager();
  Map<String, int> basePlayerStats = {};
  Map<String, int> baseEnemyStats = {};

  @override
  void initState() {
    super.initState();
    _initBattleStats();
    _initAnimationControllers();
    _loadSkills();
    _loadAvatarLayers();


    // Add initial battle message
    _addToBattleLog("Battle started against ${widget.enemy['name']}!");

  }


  // Load user avatar
  Future<void> _loadAvatarLayers() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Load avatar layers data for base sprite
        final avatarLayersDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('avatar')
            .doc('layers')
            .get();

        // Set base avatar sprite
        if (avatarLayersDoc.exists) {
          setState(() {
            userAvatarLayers = AvatarLayers.fromFirestore(avatarLayersDoc.data() ?? {});
            baseAvatarSprite = userAvatarLayers!.baseSprite;
            print('Base avatar sprite set to: $baseAvatarSprite');
          });
        } else {
          setState(() {
            baseAvatarSprite = 'assets/images/sprites/avatar/default_avatar.png';
            print('Using default avatar sprite');
          });
        }

        // Get equipped items as DocumentReferences
        final equippedWeapon = widget.userData['equippedWeapon'];
        final equippedArmor = widget.userData['equippedArmor'];
        final equippedCosmetic = widget.userData['equippedCosmetic'];

        print('Loading equipment from references:');

        // Handle weapon reference
        if (equippedWeapon != null) {
          try {
            print('Weapon reference: $equippedWeapon');
            DocumentSnapshot weaponDoc;
            if (equippedWeapon is DocumentReference) {
              // Direct reference
              weaponDoc = await equippedWeapon.get();
            } else {
              // In case it's a map with path or id
              String? weaponId = equippedWeapon is Map ? equippedWeapon['id'] : null;
              if (weaponId != null) {
                weaponDoc = await FirebaseFirestore.instance
                    .collection('weapons')
                    .doc(weaponId)
                    .get();
              } else {
                print('Cannot resolve weapon reference');
                return;
              }
            }

            if (weaponDoc.exists) {
              final weaponData = weaponDoc.data();
              if (weaponData is Map<String, dynamic> && weaponData['spritePath'] != null) {
                setState(() {
                  weaponLayerSprite = weaponData['spritePath'];
                  print('Weapon sprite set to: ${weaponData['spritePath']}');
                });
              } else {
                print('Weapon data exists but has no spritePath: $weaponData');
              }
            } else {
              print('Weapon document does not exist');
            }
          } catch (e) {
            print('Error loading weapon: $e');
          }
        }

        // Handle armor reference
        if (equippedArmor != null) {
          try {
            print('Armor reference: $equippedArmor');
            DocumentSnapshot armorDoc;
            if (equippedArmor is DocumentReference) {
              // Direct reference
              armorDoc = await equippedArmor.get();
            } else {
              // In case it's a map with path or id
              String? armorId = equippedArmor is Map ? equippedArmor['id'] : null;
              if (armorId != null) {
                armorDoc = await FirebaseFirestore.instance
                    .collection('armor')
                    .doc(armorId)
                    .get();
              } else {
                print('Cannot resolve armor reference');
                return;
              }
            }

            if (armorDoc.exists) {
              final armorData = armorDoc.data();
              if (armorData is Map<String, dynamic> && armorData['spritePath'] != null) {
                setState(() {
                  armorLayerSprite = armorData['spritePath'];
                  print('Armor sprite set to: ${armorData['spritePath']}');
                });
              } else {
                print('Armor data exists but has no spritePath: $armorData');
              }
            } else {
              print('Armor document does not exist');
            }
          } catch (e) {
            print('Error loading armor: $e');
          }
        }

        // Handle cosmetic reference
        if (equippedCosmetic != null) {
          try {
            print('Cosmetic reference: $equippedCosmetic');
            DocumentSnapshot cosmeticDoc;
            if (equippedCosmetic is DocumentReference) {
              // Direct reference
              cosmeticDoc = await equippedCosmetic.get();
            } else {
              // In case it's a map with path or id
              String? cosmeticId = equippedCosmetic is Map ? equippedCosmetic['id'] : null;
              if (cosmeticId != null) {
                cosmeticDoc = await FirebaseFirestore.instance
                    .collection('cosmetics')
                    .doc(cosmeticId)
                    .get();
              } else {
                print('Cannot resolve cosmetic reference');
                return;
              }
            }

            if (cosmeticDoc.exists) {
              final cosmeticData = cosmeticDoc.data();
              if (cosmeticData is Map<String, dynamic> && cosmeticData['spritePath'] != null) {
                setState(() {
                  cosmeticLayerSprite = cosmeticData['spritePath'];
                  print('Cosmetic sprite set to: ${cosmeticData['spritePath']}');
                });
              } else {
                print('Cosmetic data exists but has no spritePath: $cosmeticData');
              }
            } else {
              print('Cosmetic document does not exist');
            }
          } catch (e) {
            print('Error loading cosmetic: $e');
          }
        }
      }
    } catch (e) {
      print('Error in _loadAvatarLayersWithReferences: $e');
    }
  }


  // Load player and enemy Skills
  Future<void> _loadSkills() async {
    setState(() {
      isLoadingSkills = true;
    });

    try {
      // Load player skills
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data()!.containsKey('skills')) {
          final skillsData = userDoc.data()!['skills'];
          print('Skills data type: ${skillsData.runtimeType}');

          // Skills is now always an array
          if (skillsData is List) {
            print('Skills data is a List with ${skillsData.length} items');
            for (int i = 0; i < skillsData.length; i++) {
              final skillItem = skillsData[i];
              print('Processing skill item $i, type: ${skillItem.runtimeType}');
              try {
                if (skillItem is String) {
                  // Handle skill IDs stored as strings
                  print('Processing skill item as String: $skillItem');
                  try {
                    final skillDoc = await FirebaseFirestore.instance
                        .collection('skills')
                        .doc(skillItem)
                        .get();

                    if (skillDoc.exists) {
                      final skillData = skillDoc.data() as Map<String, dynamic>;
                      // Make sure to convert any numeric fields that might be strings
                      Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillData);
                      playerSkills.add(Skill.fromMap(
                        sanitizedData,
                        skillDoc.id,
                      ));
                    }
                  } catch (e) {
                    print('Error processing string skill ID "$skillItem": $e');
                  }
                } else if (skillItem is DocumentReference) {
                  try {
                    // Handle skills stored as DocumentReferences in a list
                    final skillDoc = await skillItem.get();

                    if (skillDoc.exists) {
                      final skillData = skillDoc.data() as Map<String, dynamic>;
                      // Make sure to convert any numeric fields that might be strings
                      Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillData);
                      print('Sanitized skill data: $sanitizedData');
                      playerSkills.add(Skill.fromMap(
                        sanitizedData,
                        skillDoc.id,
                      ));
                    }
                  } catch (e) {
                    print('Error fetching document reference: $e');
                  }
                } else if (skillItem is Map<String, dynamic>) {
                  // Handle skills stored directly as maps in a list
                  print('Processing skill item as Map: $skillItem');
                  try {
                    final skillId = skillItem['id'] as String? ?? 'unknown';
                    // Make sure to convert any numeric fields that might be strings
                    Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillItem);
                    playerSkills.add(Skill.fromMap(sanitizedData, skillId));
                  } catch (e) {
                    print('Error processing map skill: $e');
                    print('Skill item data: $skillItem');
                  }
                }
              } catch (e) {
                print('Error loading skill from list at index $i: $e');
                print('Skill item type: ${skillItem.runtimeType}, value: $skillItem');
                // Continue loading other skills even if one fails
              }
            }
          }
        }
      }

      // Load enemy skills if they have any
      if (widget.enemy.containsKey('skills')) {
        final enemySkillsData = widget.enemy['skills'];

        // Enemy skills are also now always an array
        if (enemySkillsData is List) {
          for (int i = 0; i < enemySkillsData.length; i++) {
            final skillItem = enemySkillsData[i];
            try {
              if (skillItem is String) {
                final skillDoc = await FirebaseFirestore.instance
                    .collection('skills')
                    .doc(skillItem)
                    .get();

                if (skillDoc.exists) {
                  final skillData = skillDoc.data() as Map<String, dynamic>;
                  // Make sure to convert any numeric fields that might be strings
                  Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillData);
                  enemySkills.add(Skill.fromMap(
                    sanitizedData,
                    skillDoc.id,
                  ));
                }
              } else if (skillItem is DocumentReference) {
                try {
                  final skillDoc = await skillItem.get();

                  if (skillDoc.exists) {
                    final skillData = skillDoc.data() as Map<String, dynamic>;
                    // Make sure to convert any numeric fields that might be strings
                    Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillData);
                    enemySkills.add(Skill.fromMap(
                      sanitizedData,
                      skillDoc.id,
                    ));
                  }
                } catch (e) {
                  print('Error fetching enemy document reference: $e');
                }
              } else if (skillItem is Map<String, dynamic>) {
                final skillId = skillItem['id'] as String? ?? 'unknown';
                // Make sure to convert any numeric fields that might be strings
                Map<String, dynamic> sanitizedData = _sanitizeSkillData(skillItem);
                enemySkills.add(Skill.fromMap(sanitizedData, skillId));
              }
            } catch (e) {
              print('Error loading enemy skill at index $i: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error loading skills: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSkills = false;
        });

        // Debug output
        print('Loaded ${playerSkills.length} player skills and ${enemySkills.length} enemy skills');
      }
    }
  }

// Helper method to sanitize skill data and ensure numeric fields are the correct type
  Map<String, dynamic> _sanitizeSkillData(Map<String, dynamic> data) {
    Map<String, dynamic> sanitized = Map.from(data);

    // Convert string numbers to integers where needed
    if (sanitized.containsKey('mp')) {
      sanitized['mp'] = _ensureInt(sanitized['mp']);
    }

    if (sanitized.containsKey('damagePercent')) {
      sanitized['damagePercent'] = _ensureInt(sanitized['damagePercent']);
    }

    // Add any other numeric fields that might be in your Skill class
    // For example, cooldown, duration, etc.

    return sanitized;
  }

// Helper method to ensure values are converted to int
  int _ensureInt(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      return int.tryParse(value) ?? 0;
    } else if (value is double) {
      return value.toInt();
    }
    return 0;
  }




  void _initBattleStats() {
    // Initialize player stats
    playerHealth = widget.userData['health'] ?? 100;
    playerMaxHealth = widget.userData['maxHealth'] ?? 100;
    playerMana = widget.userData['mana'] ?? 50;
    playerMaxMana = widget.userData['maxMana'] ?? 50;

    // Initialize player battle stats from userData
    final Map<String, dynamic> playerStats =
        widget.userData['stats']?['battle'] ?? {
          'phyatk': 10,
          'phydef': 5,
          'magatk': 10,
          'magdef': 5
        };

    playerPhyAtk = playerStats['phyatk'] ?? 10;
    playerPhyDef = playerStats['phydef'] ?? 5;
    playerMagAtk = playerStats['magatk'] ?? 10;
    playerMagDef = playerStats['magdef'] ?? 5;

    // Store base player stats for buff calculations
    basePlayerStats = {
      'phyatk': playerPhyAtk,
      'phydef': playerPhyDef,
      'magatk': playerMagAtk,
      'magdef': playerMagDef,
    };

    // Initialize enemy stats
    enemyHealth = widget.enemy['health'] ?? widget.enemy['maxHealth'] ?? 100;
    enemyMaxHealth = widget.enemy['maxHealth'] ?? 100;
    enemyMana = widget.enemy['mana'] ?? widget.enemy['maxMana'] ?? 30;
    enemyMaxMana = widget.enemy['maxMana'] ?? 30;

    // Initialize enemy battle stats
    final Map<String, dynamic> enemyStats = widget.enemy['stats'] ?? {
      'phyatk': 8,
      'phydef': 3,
      'magatk': 8,
      'magdef': 3
    };

    enemyPhyAtk = enemyStats['phyatk'] ?? 8;
    enemyPhyDef = enemyStats['phydef'] ?? 3;
    enemyMagAtk = enemyStats['magatk'] ?? 8;
    enemyMagDef = enemyStats['magdef'] ?? 3;

    // Store base enemy stats for buff calculations
    baseEnemyStats = {
      'phyatk': enemyPhyAtk,
      'phydef': enemyPhyDef,
      'magatk': enemyMagAtk,
      'magdef': enemyMagDef,
    };
  }

  void _initAnimationControllers() {
    // Player attack animation
    _playerAttackController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    // Enemy attack animation
    _enemyAttackController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    // Shake animation for taking damage
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _playerAttackController.dispose();
    _enemyAttackController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _addToBattleLog(String message) {
    setState(() {
      // Keep only the latest 4 messages
      if (battleLog.length >= 4) {
        battleLog.removeAt(0);
      }
      battleLog.add(message);
    });
  }

  void _performBasicAttack() async {
    if (!playerTurn || battleEnded) return;

    // Calculate damage using physical attack stats
    // Player's phyatk minus enemy's phydef with a minimum damage of 1
    final int baseDamage = playerPhyAtk;
    final int defense = enemyPhyDef;
    final int damage = max(baseDamage - (defense / 2).floor(), 1);

    setState(() {
      playerTurn = false;
      currentAction = "Attacking...";
    });

    // Play attack animation
    await _playerAttackController.forward().then((_) => _playerAttackController.reverse());
    await _shakeController.forward().then((_) => _shakeController.reverse());

    // Apply damage
    setState(() {
      enemyHealth = max(0, enemyHealth - damage);
      _addToBattleLog("You attack ${widget.enemy['name']} for $damage damage!");

      // Check if enemy is defeated
      if (enemyHealth <= 0) {
        _addToBattleLog("${widget.enemy['name']} was defeated!");
        _endBattle(true);
        return;
      }

      currentAction = "Enemy's turn...";
    });

    // Regenerate mana when using basic attack
    _regeneratePlayerMana();

    // Enemy turn after a short delay
    Future.delayed(Duration(milliseconds: 1000), () {
      _enemyTurn();
    });
  }

  void _regeneratePlayerMana() {
    setState(() {
      // Regenerate mana but don't exceed max mana
      // Convert to int after calculation to avoid the type cast error
      playerMana = min(playerMaxMana, (playerMana + (playerMaxMana * playerManaRegenPerTurn)).toInt());

      // Display the regeneration as a percentage of max mana
      int percentageRegained = (playerManaRegenPerTurn * 100).round();
      _addToBattleLog("You regenerated $percentageRegained% mana.");
    });
  }

  void _performSkill(Skill skill) async {
    if (!playerTurn || battleEnded || playerMana < skill.mpCost) return;

    setState(() {
      playerTurn = false;
      playerMana -= skill.mpCost;
      currentAction = "Using ${skill.name}...";
      currentSubMenu = "";
    });

    // Handle different skill types
    switch (skill.type.toLowerCase()) {
      case 'physical':
      case 'magic':
        await _performDamageSkill(skill);
        break;
      case 'healing':
        _performHealingSkill(skill);
        break;
      case 'buff':
        _performBuffSkill(skill, true); // Apply to player
        break;
      case 'debuff':
        _performBuffSkill(skill, false); // Apply to enemy
        break;
      default:
        _addToBattleLog("Used ${skill.name}!");
        break;
    }

    // Check if enemy is defeated before proceeding
    if (battleEnded) return;

    // Enemy turn after a short delay
    Future.delayed(Duration(milliseconds: 1000), () {
      // Update buff durations at the end of player turn
      buffManager.updateBuffDurations(true);
      _enemyTurn();
    });
  }


  Future<void> _performDamageSkill(Skill skill) async {
    // Calculate damage based on skill type and damage percentage
    int damage;
    if (skill.type.toLowerCase() == 'physical') {
      // Physical skill uses phyatk and enemy's phydef
      final baseAttack = (playerPhyAtk * (skill.damagePercent ?? 100) / 100).round();
      damage = max(baseAttack - (enemyPhyDef / 2).floor(), 1);
    } else {
      // Magic skill uses magatk and enemy's magdef
      final baseAttack = (playerMagAtk * (skill.damagePercent ?? 100) / 100).round();
      damage = max(baseAttack - (enemyMagDef / 2).floor(), 1);
    }

    // Play attack animation
    await _playerAttackController.forward().then((_) => _playerAttackController.reverse());
    await _shakeController.forward().then((_) => _shakeController.reverse());

    // Apply damage
    setState(() {
      enemyHealth = max(0, enemyHealth - damage);
      _addToBattleLog("You used ${skill.name} for $damage damage!");

      // Check if enemy is defeated
      if (enemyHealth <= 0) {
        _addToBattleLog("${widget.enemy['name']} was defeated!");
        _endBattle(true);
      }
    });
  }

  void _performHealingSkill(Skill skill) {
    // Calculate healing amount based on percentage of max health
    final int healAmount = ((skill.healPercent ?? 20) / 100 * playerMaxHealth).round();

    setState(() {
      playerHealth = min(playerMaxHealth, playerHealth + healAmount);
      _addToBattleLog("You used ${skill.name} and restored $healAmount health!");
    });
  }

  void _performBuffSkill(Skill skill, bool targetPlayer) {
    // Add the buff to the target
    buffManager.addBuff(targetPlayer, skill);

    // Apply the effects immediately
    _updateBuffedStats();

    setState(() {
      if (targetPlayer) {
        _addToBattleLog("You used ${skill.name} on yourself!");
      } else {
        _addToBattleLog("You used ${skill.name} on ${widget.enemy['name']}!");
      }

      // Show the active buff effects
      final List<String> effectDescriptions = [];
      skill.effects?.forEach((stat, value) {
        if (value is num) {
          final effectStr = value > 0 ? "+$value" : "$value";
          effectDescriptions.add("$stat $effectStr");
        }
      });

      if (effectDescriptions.isNotEmpty) {
        _addToBattleLog("Effects: ${effectDescriptions.join(', ')} for ${skill.duration} turns");
      }
    });
  }

  void _updateBuffedStats() {
    // Apply player buffs
    final buffedPlayerStats = buffManager.getBuffedStats(true, basePlayerStats);
    setState(() {
      playerPhyAtk = buffedPlayerStats['phyatk'] ?? basePlayerStats['phyatk']!;
      playerPhyDef = buffedPlayerStats['phydef'] ?? basePlayerStats['phydef']!;
      playerMagAtk = buffedPlayerStats['magatk'] ?? basePlayerStats['magatk']!;
      playerMagDef = buffedPlayerStats['magdef'] ?? basePlayerStats['magdef']!;
    });

    // Apply enemy buffs/debuffs
    final buffedEnemyStats = buffManager.getBuffedStats(false, baseEnemyStats);
    setState(() {
      enemyPhyAtk = buffedEnemyStats['phyatk'] ?? baseEnemyStats['phyatk']!;
      enemyPhyDef = buffedEnemyStats['phydef'] ?? baseEnemyStats['phydef']!;
      enemyMagAtk = buffedEnemyStats['magatk'] ?? baseEnemyStats['magatk']!;
      enemyMagDef = buffedEnemyStats['magdef'] ?? baseEnemyStats['magdef']!;
    });
  }


  void _enemyTurn() async {
    if (battleEnded) return;

    // Check if enemy has skills and enough mana to use one
    bool useSkill = false;
    Skill? selectedSkill;

    if (enemySkills.isNotEmpty) {
      // Filter skills by available mana
      final availableSkills = enemySkills.where((skill) => enemyMana >= skill.mpCost).toList();

      if (availableSkills.isNotEmpty) {
        // 70% chance to use a skill if available
        useSkill = Random().nextDouble() < 0.7;

        if (useSkill) {
          // Enhanced enemy AI for skill selection
          List<Skill> offensiveSkills = [];
          List<Skill> healingSkills = [];
          List<Skill> buffSkills = [];
          List<Skill> debuffSkills = [];

          for (var skill in availableSkills) {
            final skillType = skill.type.toLowerCase();
            if (skillType == 'physical' || skillType == 'magic') {
              offensiveSkills.add(skill);
            } else if (skillType == 'healing') {
              healingSkills.add(skill);
            } else if (skillType == 'buff') {
              buffSkills.add(skill);
            } else if (skillType == 'debuff') {
              debuffSkills.add(skill);
            }
          }

          // Enhanced enemy AI decision making
          double healthPercentage = enemyHealth / enemyMaxHealth;
          if (healthPercentage < 0.3 && healingSkills.isNotEmpty) {
            // Use healing if low health and has healing skills
            selectedSkill = healingSkills[Random().nextInt(healingSkills.length)];
          } else if (healthPercentage < 0.5 && Random().nextDouble() < 0.4 && buffSkills.isNotEmpty) {
            // More likely to buff self when below half health
            selectedSkill = buffSkills[Random().nextInt(buffSkills.length)];
          } else if (debuffSkills.isNotEmpty && Random().nextDouble() < 0.3) {
            // 30% chance to debuff player
            selectedSkill = debuffSkills[Random().nextInt(debuffSkills.length)];
          } else if (offensiveSkills.isNotEmpty) {
            // Otherwise use offensive skills
            selectedSkill = offensiveSkills[Random().nextInt(offensiveSkills.length)];
          } else if (availableSkills.isNotEmpty) {
            // Fall back to any available skill
            selectedSkill = availableSkills[Random().nextInt(availableSkills.length)];
          }
        }
      }
    }

    if (useSkill && selectedSkill != null) {
      // Enemy uses a skill
      await _useEnemySkill(selectedSkill);
    } else {
      // Standard attack if not using a skill
      await _performEnemyBasicAttack();
    }

    // If battle hasn't ended, update buff durations and return to player turn
    if (!battleEnded) {
      // Update buff durations at the end of enemy turn
      buffManager.updateBuffDurations(false);
      _updateBuffedStats();

      setState(() {
        playerTurn = true;
        currentAction = "Choose an action";
      });
    }
  }

  // Extracted enemy's basic attack into a separate method
  Future<void> _performEnemyBasicAttack() async {
    final bool isPhysicalAttack = Random().nextDouble() < 0.7;

    int damage;
    String attackType;

    if (isPhysicalAttack) {
      // Calculate enemy physical damage
      damage = max(enemyPhyAtk - (playerPhyDef / 2).floor(), 1);
      attackType = "physical";
    } else {
      // Calculate enemy magic damage
      damage = max(enemyMagAtk - (playerMagDef / 2).floor(), 1);
      attackType = "magic";
    }

    // Play enemy attack animation
    await _enemyAttackController.forward().then((_) => _enemyAttackController.reverse());
    await _shakeController.forward().then((_) => _shakeController.reverse());

    // Apply damage to player
    setState(() {
      playerHealth = max(0, playerHealth - damage);
      _addToBattleLog("${widget.enemy['name']} uses a $attackType attack for $damage damage!");

      // Check if player is defeated
      if (playerHealth <= 0) {
        _addToBattleLog("You were defeated!");
        _endBattle(false);
      }
    });
  }

  // New comprehensive method for enemy skill usage
  Future<void> _useEnemySkill(Skill skill) async {
    // Determine what kind of skill to use
    final String skillType = skill.type.toLowerCase();

    setState(() {
      enemyMana -= skill.mpCost;
      _addToBattleLog("${widget.enemy['name']} is using ${skill.name}!");
    });

    switch (skillType) {
      case 'physical':
      case 'magic':
        await _performEnemyDamageSkill(skill);
        break;
      case 'healing':
        _performEnemyHealingSkill(skill);
        break;
      case 'buff':
        _performEnemyBuffSkill(skill, false); // Apply buff to enemy
        break;
      case 'debuff':
        _performEnemyBuffSkill(skill, true); // Apply debuff to player
        break;
      default:
        _addToBattleLog("${widget.enemy['name']} used ${skill.name}!");
        break;
    }
  }

  Future<void> _performEnemyDamageSkill(Skill skill) async {
    // Calculate damage based on skill type
    int damage;
    if (skill.type.toLowerCase() == 'physical') {
      final baseAttack = (enemyPhyAtk * (skill.damagePercent ?? 100) / 100).round();
      damage = max(baseAttack - (playerPhyDef / 2).floor(), 1);
    } else {
      final baseAttack = (enemyMagAtk * (skill.damagePercent ?? 100) / 100).round();
      damage = max(baseAttack - (playerMagDef / 2).floor(), 1);
    }

    // Reduce enemy's mana
    enemyMana -= skill.mpCost;

    // Play enemy attack animation
    await _enemyAttackController.forward().then((_) => _enemyAttackController.reverse());
    await _shakeController.forward().then((_) => _shakeController.reverse());

    // Apply damage to player
    setState(() {
      playerHealth = max(0, playerHealth - damage);
      _addToBattleLog("${widget.enemy['name']} uses ${skill.name} for $damage damage!");

      // Check if player is defeated
      if (playerHealth <= 0) {
        _addToBattleLog("You were defeated!");
        _endBattle(false);
      }
    });
  }

  void _performEnemyHealingSkill(Skill skill) {
    // Calculate healing amount
    final int healAmount = ((skill.healPercent ?? 20) / 100 * enemyMaxHealth).round();

    // Reduce enemy's mana
    enemyMana -= skill.mpCost;

    setState(() {
      enemyHealth = min(enemyMaxHealth, enemyHealth + healAmount);
      _addToBattleLog("${widget.enemy['name']} used ${skill.name} and restored $healAmount health!");
    });
  }

  void _performEnemyBuffSkill(Skill skill, bool targetPlayer) {
    // Reduce enemy's mana
    enemyMana -= skill.mpCost;

    // Add the buff to the target
    buffManager.addBuff(targetPlayer, skill);

    // Apply the effects immediately
    _updateBuffedStats();

    setState(() {
      if (targetPlayer) {
        _addToBattleLog("${widget.enemy['name']} used ${skill.name} on you!");
      } else {
        _addToBattleLog("${widget.enemy['name']} used ${skill.name} on itself!");
      }
    });
  }

  Widget _buildActiveBuffs(bool isPlayer) {
    final buffNames = buffManager.getActiveBuffNames(isPlayer);
    if (buffNames.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Effects:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 4,
          children: buffNames.map((name) {
            return Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: TextStyle(fontSize: 10),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showRetreatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Retreat'),
        content: Text('Are you sure you want to retreat from battle?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to GamePage
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text('Retreat'),
          ),
        ],
      ),
    );
  }

  void _endBattle(bool victory) {
    setState(() {
      battleEnded = true;
      currentAction = victory ? "Victory!" : "Defeat!";

      if (victory) {
        final gemsReward = widget.enemy['rewardGold'] ?? 10;
        final xpReward = widget.enemy['rewardXp'] ?? 20;
        _addToBattleLog("You earned $gemsReward gems and $xpReward XP!");

        // Save rewards and battle results
        _saveBattleResults(gemsReward, xpReward);
      } else {
        // Save defeat state
        _saveDefeatState();
      }
    });

    // Return to game page after battle ends
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _saveBattleResults(int gemsReward, int xpReward) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;

      // Calculate new values
      final currentGems = userData['gems'] ?? 0;
      final currentXp = userData['xp'] ?? 0;
      final currentLevel = userData['userLevel'] ?? 1;

      // Calculate new gold and XP
      final newGems = currentGems + gemsReward;
      final newXp = currentXp + xpReward;

      // Check for level up (simple level up logic)
      int newLevel = currentLevel;
      final xpNeededForNextLevel = currentLevel * 100; // Simple formula: level * 100 XP needed

      if (newXp >= xpNeededForNextLevel) {
        newLevel = currentLevel + 1;
        _addToBattleLog("Level up! You are now level $newLevel!");
      }

      // Update user data in Firestore with new health/mana fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'gems': newGems,
        'xp': newXp,
        'userLevel': newLevel,
        'health': playerHealth, // Current health
        'maxHealth': playerMaxHealth, // Maximum health
        'mana': playerMana, // Current mana
        'maxMana': playerMaxMana, // Maximum mana
        'lastBattleTimestamp': FieldValue.serverTimestamp(),
        'battlesWon': FieldValue.increment(1),
      });

      // Update battle history (optional)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('battleHistory')
          .add({
        'enemyId': widget.enemy['id'],
        'enemyName': widget.enemy['name'],
        'timestamp': FieldValue.serverTimestamp(),
        'result': 'victory',
        'gemsEarned': gemsReward,
        'xpEarned': xpReward,
        'playerHealthRemaining': playerHealth,
      });

    } catch (e) {
      print('Error saving battle results: $e');
    }
  }

  // Save defeat state to Firebase
  Future<void> _saveDefeatState() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get current max health/mana values
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final maxHealth = userDoc.data()?['maxHealth'] ?? 100;
      final maxMana = userDoc.data()?['maxMana'] ?? 50;

      // Update user state after defeat
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'health': playerHealth > 0 ? playerHealth : (maxHealth * 0.2).round(), // 20% of max health if defeated
        'mana': playerMana > 0 ? playerMana : (maxMana * 0.3).round(), // 30% of max mana if defeated
        'lastDefeatTimestamp': FieldValue.serverTimestamp(),
        'battlesLost': FieldValue.increment(1),
      });

      // Add to battle history
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('battleHistory')
          .add({
        'enemyId': widget.enemy['id'],
        'enemyName': widget.enemy['name'],
        'timestamp': FieldValue.serverTimestamp(),
        'result': 'defeat',
      });

    } catch (e) {
      print('Error saving defeat state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        // If battle has ended, allow normal back button behavior
        if (battleEnded) {
          return true;
        }

        // If battle is ongoing, show retreat confirmation
        _showRetreatConfirmation();

        // Return false to prevent the default back button behavior
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Enemy info section
              _buildEnemyInfoSection(),


              // Battle scene
              Expanded(
                flex: 5,
                child: _buildBattleScene(theme, screenSize),
              ),

              // Battle log
              _buildBattleLog(theme),

              // Battle actions and player info
              _buildBottomSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnemyInfoSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.enemy['name'] ?? 'Enemy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                // Health bar
                Row(
                  children: [
                    Text('HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: enemyHealth / enemyMaxHealth,
                        backgroundColor: Colors.grey[300],
                        color: Colors.red,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('$enemyHealth/$enemyMaxHealth', style: TextStyle(fontSize: 12)),
                  ],
                ),
                SizedBox(height: 4),
                // Mana bar
                Row(
                  children: [
                    Text('MP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: enemyMana / enemyMaxMana,
                        backgroundColor: Colors.grey[300],
                        color: Colors.blue,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('$enemyMana/$enemyMaxMana', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build battle screen
  Widget _buildBattleScene(ThemeData theme, Size screenSize) {


    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Use a gradient for battle background
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.brightness == Brightness.dark
              ? [Colors.black, Colors.grey[900]!]
              : [Colors.lightBlue[100]!, Colors.grey[200]!],
        ),
      ),
      child: Stack(
        children: [
          // Enemy portrait with animation
          Positioned(
            top: 20,
            right: 40,
            child: AnimatedBuilder(
              animation: Listenable.merge([_enemyAttackController, _shakeController]),
              builder: (context, child) {
                double dx = 0.0;
                double dy = 0.0;

                // Apply attack animation
                if (_enemyAttackController.isAnimating) {
                  dx = -20.0 * _enemyAttackController.value;
                }

                // Apply shake animation
                if (_shakeController.isAnimating) {
                  dx += 5.0 * sin(_shakeController.value * 10);
                }

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                // Check for sprite path and use it, fallback to icon if not available
                child: widget.enemy['spritePath'] != null && widget.enemy['spritePath'].isNotEmpty
                    ? Image.asset(
                  widget.enemy['spritePath'],
                  fit: BoxFit.contain,
                )
                    : _buildFallbackEnemyIcon(theme),
              ),
            ),
          ),

          // Player portrait with animation
          Positioned(
            bottom: 20,
            left: 40,
            child: AnimatedBuilder(
              animation: Listenable.merge([_playerAttackController, _shakeController]),
              builder: (context, child) {
                double dx = 0.0;
                double dy = 0.0;

                // Apply attack animation
                if (_playerAttackController.isAnimating) {
                  dx = 20.0 * _playerAttackController.value;
                }

                // Apply shake animation when taking damage
                if (_shakeController.isAnimating && !_playerAttackController.isAnimating) {
                  dx += 5.0 * sin(_shakeController.value * 10);
                }

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                );
              },
              child: baseAvatarSprite != null
                  ? LayeredSprite(
                baseLayer: baseAvatarSprite!,
                weaponLayer: weaponLayerSprite,
                armorLayer: armorLayerSprite,
                cosmeticLayer: cosmeticLayerSprite,
                size: 100,
              )
                  : Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method to create the fallback icon based on enemy type
  Widget _buildFallbackEnemyIcon(ThemeData theme) {
    IconData enemyIcon;

    // Determine the enemy type for icon
    switch (widget.enemy['type']?.toString().toLowerCase() ?? 'monster') {
      case 'undead':
        enemyIcon = Icons.nightlight;
        break;
      case 'beast':
        enemyIcon = Icons.pets;
        break;
      case 'dragon':
        enemyIcon = Icons.local_fire_department;
        break;
      case 'elemental':
        enemyIcon = Icons.whatshot;
        break;
      case 'humanoid':
        enemyIcon = Icons.person;
        break;
      default:
        enemyIcon = Icons.psychology;
    }

    return Icon(
      enemyIcon,
      size: 60,
      color: widget.enemy['isBoss'] == true
          ? Colors.red
          : theme.primaryColor,
    );
  }

  Widget _buildBattleLog(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(12),
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: battleLog.length,
              itemBuilder: (context, index) {
                return Text(
                  battleLog[index],
                  style: TextStyle(fontSize: 14),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBottomSection(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Battle actions
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAction,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),

                // Show different menus based on current submenu
                if (currentSubMenu == "")
                  _buildMainActionMenu()
                else if (currentSubMenu == "skills")
                  _buildSkillsMenu()
              ],
            ),
          ),

          SizedBox(width: 12),

          // Player stats with new battle stats display
          Expanded(
            flex: 1,
            child: _buildPlayerStats(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Attack button
        ElevatedButton(
          onPressed: playerTurn && !battleEnded
              ? _performBasicAttack
              : null,
          child: Text('Attack'),
        ),

        SizedBox(height: 8), // Add spacing between buttons

        // Skill button
        ElevatedButton(
          onPressed: playerTurn && !battleEnded
              ? () => setState(() => currentSubMenu = "skills")
              : null,
          child: Text('Skills'),
        ),

        SizedBox(height: 8), // Add spacing between buttons

        // Retreat button
        ElevatedButton(
          onPressed: playerTurn && !battleEnded
              ? _showRetreatConfirmation
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('Retreat'),
        ),
      ],
    );
  }

  Widget _buildPlayerStats() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level ${widget.userData['userLevel'] ?? 1} ${widget.userData['name']?? 'Player'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          // Health bar
          Text('Health', style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: playerHealth / playerMaxHealth,
            backgroundColor: Colors.grey[300],
            color: Colors.red,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          Text('$playerHealth/$playerMaxHealth',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.right
          ),
          SizedBox(height: 8),
          // Mana bar
          Text('Mana', style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: playerMana / playerMaxMana,
            backgroundColor: Colors.grey[300],
            color: Colors.blue,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          Text('$playerMana/$playerMaxMana',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.right
          ),
          Divider(),
          // Combat stats
          Text('Battle Stats', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PHY ATK: $playerPhyAtk', style: TextStyle(fontSize: 11)),
              Text('PHY DEF: $playerPhyDef', style: TextStyle(fontSize: 11)),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MAG ATK: $playerMagAtk', style: TextStyle(fontSize: 11)),
              Text('MAG DEF: $playerMagDef', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSkillsMenu() {
    if (isLoadingSkills) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (playerSkills.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No skills available'),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => setState(() => currentSubMenu = ""),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: Text('Back'),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 240,
          child: ListView.builder(
            itemCount: playerSkills.length,
            itemBuilder: (context, index) {
              final skill = playerSkills[index];
              final bool canUseSkill = playerTurn && !battleEnded && playerMana >= skill.mpCost;
              final String skillType = skill.type.toLowerCase() == 'physical' ? 'Physical' : 'Magic';
              final String skillStat = skill.type.toLowerCase() == 'physical' ? 'Phys. Atk' : 'Mag. Atk';

              final Color skillColor = skill.type.toLowerCase() == 'physical'
                  ? Colors.orangeAccent
                  : Colors.blueAccent;

              return InkWell(
                onTap: canUseSkill ? () => _performSkill(skill) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Color(0xFF333333)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canUseSkill ? skillColor : Colors.grey,
                      width: 2,
                    ),
                    boxShadow: canUseSkill ? [
                      BoxShadow(
                        color: skillColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with name and MP cost
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Constrain the skill name width to prevent overflow
                            Expanded(
                              flex: 3,
                              child: Text(
                                skill.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: canUseSkill ? null : Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            // MP Cost badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: canUseSkill
                                    ? skillColor.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${skill.mpCost} MP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: canUseSkill ? skillColor : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 6),

                        // Skill type and damage info in a row
                        Wrap(
                          spacing: 8,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: skillColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                skillType,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: canUseSkill ? skillColor : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${skill.damagePercent}% of $skillStat',
                              style: TextStyle(
                                fontSize: 10,
                                color: canUseSkill ? null : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => currentSubMenu = ""),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
          ),
          child: Text('Back'),
        ),
      ],
    );
  }


}

// Avatar Layer data model
class AvatarLayers {
  final String baseSprite;
  final Map<String, String> weaponLayers;
  final Map<String, String> armorLayers;
  final Map<String, String> cosmeticLayers;

  AvatarLayers({
    required this.baseSprite,
    required this.weaponLayers,
    required this.armorLayers,
    required this.cosmeticLayers,
  });

  static AvatarLayers fromFirestore(Map<String, dynamic> data) {
    return AvatarLayers(
      baseSprite: data['baseSprite'] ?? 'assets/images/sprites/avatar/default_avatar.png',
      weaponLayers: Map<String, String>.from(data['weaponLayers'] ?? {}),
      armorLayers: Map<String, String>.from(data['armorLayers'] ?? {}),
      cosmeticLayers: Map<String, String>.from(data['cosmeticLayers'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'baseSprite': baseSprite,
      'weaponLayers': weaponLayers,
      'armorLayers': armorLayers,
      'cosmeticLayers': cosmeticLayers,
    };
  }
}

// Handles Player Sprite display
class LayeredSprite extends StatelessWidget {
  final String baseLayer;
  final String? weaponLayer;
  final String? armorLayer;
  final String? cosmeticLayer;
  final double size;

  const LayeredSprite({
    Key? key,
    required this.baseLayer,
    this.weaponLayer,
    this.armorLayer,
    this.cosmeticLayer,
    this.size = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((size / 2) - 1), // Adjust for border
        child: Stack(
          children: [
            // Base character layer (always shown)
            Positioned.fill(
              child: Image.asset(
                baseLayer,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading base layer image: $error');
                  return Icon(
                    Icons.person,
                    size: size / 2,
                    color: Theme.of(context).primaryColor,
                  );
                },
              ),
            ),

            // Armor layer
            if (armorLayer != null && armorLayer!.isNotEmpty)
              Positioned.fill(
                child: Image.asset(
                  armorLayer!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading armor layer image: $error');
                    return SizedBox.shrink(); // Return empty widget on error
                  },
                ),
              ),

            // Weapon layer
            if (weaponLayer != null && weaponLayer!.isNotEmpty)
              Positioned.fill(
                child: Image.asset(
                  weaponLayer!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading weapon layer image: $error');
                    return SizedBox.shrink(); // Return empty widget on error
                  },
                ),
              ),

            // Cosmetic layer (shown on top of everything)
            if (cosmeticLayer != null && cosmeticLayer!.isNotEmpty)
              Positioned.fill(
                child: Image.asset(
                  cosmeticLayer!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading cosmetic layer image: $error');
                    return SizedBox.shrink(); // Return empty widget on error
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}