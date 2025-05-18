import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

//Helper Functions
void showLevelUpDialog(BuildContext context, int newLevel) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Level Up!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward, color: Colors.amber, size: 50),
          SizedBox(height: 16),
          Text(
            'Congratulations!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'You have reached level $newLevel',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'Keep up the good work!',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}


// Skill data model
class Skill {
  final String id;
  final String name;
  final String description;
  final String type; // 'physical', 'magic', 'healing', 'buff', 'debuff'
  final int mpCost;
  final int? damagePercent; // Optional for attack skills
  final int? healPercent;   // Optional for healing skills
  final String? element;    // Optional element like fire, ice, etc.
  final int? cooldown;      // Optional cooldown in turns
  final Map<String, dynamic>? effects; // For buffs/debuffs
  final int? duration;      // Duration for buffs/debuffs in turns

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.mpCost,
    this.damagePercent,
    this.healPercent,
    this.element,
    this.cooldown,
    this.effects,
    this.duration,
  });

  // Parses skills from firestore
  factory Skill.fromMap(Map<String, dynamic> map, String id) {
    try {
      // Ensure numeric values are properly converted from possible string representation
      int parseMpCost(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        if (value is double) return value.toInt();
        return 0;
      }

      int? parseOptionalInt(dynamic value, int? defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        if (value is double) return value.toInt();
        return defaultValue;
      }

      // Debug the map to help identify issues
      print('Processing skill map with id: $id');
      print('Map contents: $map');

      // Convert values with safe parsing
      final mpCost = parseMpCost(map['mp']);
      final damagePercent = parseOptionalInt(map['damage'], null);
      final healPercent = parseOptionalInt(map['heal'], null);
      final cooldown = parseOptionalInt(map['cooldown'], null);
      final duration = parseOptionalInt(map['duration'], null);

      // Handle effects map
      Map<String, dynamic>? effects;
      if (map['effects'] != null && map['effects'] is Map) {
        effects = Map<String, dynamic>.from(map['effects']);
      }

      return Skill(
        id: id,
        name: map['name'] ?? 'Unknown Skill',
        description: map['description'] ?? 'No description available',
        type: (map['type'] ?? 'physical').toString().toLowerCase(),
        mpCost: mpCost,
        damagePercent: damagePercent,
        healPercent: healPercent,
        element: map['element'] as String?,
        cooldown: cooldown,
        effects: effects,
        duration: duration,
      );
    } catch (e) {
      print('Error creating Skill from map: $e');
      print('Map data: $map');

      // Return a default skill as fallback
      return Skill(
        id: id,
        name: 'Error Skill',
        description: 'Failed to load skill data',
        type: 'physical',
        mpCost: 0,
        damagePercent: 100,
        healPercent: null,
        element: null,
        cooldown: null,
        effects: null,
        duration: null,
      );
    }
  }

  // Converts to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'mp': mpCost,
      'damage': damagePercent,
      'heal': healPercent,
      'element': element,
      'cooldown': cooldown,
      'effects': effects,
      'duration': duration,
    };
  }
}

// Represents an active buff in combat
class ActiveBuff {
  final String skillId;
  final String name;
  final Map<String, dynamic> effects;
  int remainingTurns;

  ActiveBuff({
    required this.skillId,
    required this.name,
    required this.effects,
    required this.remainingTurns,
  });
}

// Handles buff logic for players/enemies
class BuffManager {
  List<ActiveBuff> playerBuffs = [];
  List<ActiveBuff> enemyBuffs = [];

  // Add a new buff
  void addBuff(bool isPlayer, Skill skill) {
    if (skill.effects == null || skill.duration == null) return;

    final newBuff = ActiveBuff(
      skillId: skill.id,
      name: skill.name,
      effects: skill.effects!,
      remainingTurns: skill.duration!,
    );

    // Remove existing buff of the same type before adding new one
    if (isPlayer) {
      playerBuffs.removeWhere((buff) => buff.skillId == skill.id);
      playerBuffs.add(newBuff);
    } else {
      enemyBuffs.removeWhere((buff) => buff.skillId == skill.id);
      enemyBuffs.add(newBuff);
    }
  }

  // Apply all active buffs for a turn
  Map<String, int> getBuffedStats(bool isPlayer, Map<String, int> baseStats) {
    final Map<String, int> buffedStats = Map.from(baseStats);
    final buffs = isPlayer ? playerBuffs : enemyBuffs;

    for (var buff in buffs) {
      buff.effects.forEach((stat, value) {
        if (buffedStats.containsKey(stat) && value is num) {
          // Handle percentage increases
          if (value is double) {
            buffedStats[stat] = (buffedStats[stat]! * value).round();
          } else {
            buffedStats[stat] = buffedStats[stat]! + value as int;
          }
        }
      });
    }

    return buffedStats;
  }

  // Decrease duration for all buffs and remove expired ones
  void updateBuffDurations(bool isPlayer) {
    final buffs = isPlayer ? playerBuffs : enemyBuffs;

    for (int i = buffs.length - 1; i >= 0; i--) {
      buffs[i].remainingTurns--;
      if (buffs[i].remainingTurns <= 0) {
        buffs.removeAt(i);
      }
    }
  }

  // Get all active buff names for display
  List<String> getActiveBuffNames(bool isPlayer) {
    final buffs = isPlayer ? playerBuffs : enemyBuffs;
    return buffs.map((buff) => '${buff.name} (${buff.remainingTurns})').toList();
  }
}

// Manages Level Progression
class LevelManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Calculate XP required for a specific level
  // Creates an exponential curve where each level requires more XP
  static int getRequiredXpForLevel(int level) {
    // Base XP for level 1
    const int baseXp = 20;
    // Growth factor (higher = steeper XP curve)
    const double growthFactor = 1.3;

    return (baseXp * pow(growthFactor, level - 1)).floor();
  }

  // Check if user has enough XP to level up
  static bool canLevelUp(int currentLevel, int currentXp) {
    return currentXp >= getRequiredXpForLevel(currentLevel);
  }

  // Process the level up and return remaining XP
  static int processLevelUp(int currentLevel, int currentXp) {
    final requiredXp = getRequiredXpForLevel(currentLevel);
    // Remaining XP after level up
    return currentXp - requiredXp;
  }

  // Check and process level ups, can be called from anywhere in the app
  static Future<Map<String, dynamic>> checkAndProcessLevelUps(BuildContext? context) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'success': false, 'error': 'No authenticated user'};
    }

    try {
      bool leveledUp = false;
      int newLevel = 0;

      // Use a transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User document not found');
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        int currentLevel = userData['userLevel'] ?? 1;
        int currentXp = userData['xp'] ?? 0;

        // Check for multiple level ups in a loop
        while (canLevelUp(currentLevel, currentXp)) {
          leveledUp = true;
          currentLevel++;
          newLevel = currentLevel;  // Store the latest level for return value
          currentXp = processLevelUp(currentLevel - 1, currentXp);

          // Could add level-up bonuses here
          // Ex: int healthBonus = currentLevel * 5;
          // transaction.update(userRef, {'maxHealth': FieldValue.increment(healthBonus)});
        }

        // Only update if user leveled up
        if (leveledUp) {
          transaction.update(userRef, {
            'userLevel': currentLevel,
            'xp': currentXp,
            // Add extra level up rewards here
          });
        }
      });

      // Return the level up information
      return {
        'success': true,
        'leveledUp': leveledUp,
        'newLevel': newLevel,
      };
    } catch (e) {
      print('Error checking level ups: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get the current progress to next level
  static Future<Map<String, dynamic>> getLevelProgress() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'success': false, 'error': 'No authenticated user'};
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return {'success': false, 'error': 'User document not found'};
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final int currentLevel = userData['userLevel'] ?? 1;
      final int currentXp = userData['xp'] ?? 0;
      final int requiredXp = getRequiredXpForLevel(currentLevel);

      return {
        'success': true,
        'currentLevel': currentLevel,
        'currentXp': currentXp,
        'requiredXp': requiredXp,
        'progress': currentXp / requiredXp, // Returns a value between 0.0 and 1.0
      };
    } catch (e) {
      print('Error getting level progress: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

