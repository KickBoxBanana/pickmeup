import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'game_mechanics.dart';
import 'main.dart';
import 'task_page.dart';

// Displays basic user info on a card widget
class UserProfileCard extends StatelessWidget {
  final Map<String, dynamic> userData; // User data map containing stats like name, level, health, etc.
  final String className;


  const UserProfileCard({
    super.key,
    required this.userData,
    required this.className,
  });

  // Returns user's intials based on their name
  String _getInitials(String name) {
    List<String> nameSplit = name.split(" ");
    String initials = "";

    if (nameSplit.isNotEmpty && nameSplit[0].isNotEmpty) {
      initials += nameSplit[0][0];
    }
    if (nameSplit.length > 1 && nameSplit[1].isNotEmpty) {
      initials += nameSplit[1][0];
    }

    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Get values from userData map, otherwise use defaults
    final String name = userData['name'] ?? '';
    final int level = userData['userLevel'] ?? 1;
    final int gold = userData['gold'] ?? 0;
    final int gems = userData['gems'] ?? 0;
    final int health = userData['health'] ?? 0;
    final int maxHealth = userData['maxHealth'] ?? 100;
    final int xp = userData['xp'] ?? 0;
    final int xpRequired = LevelManager.getRequiredXpForLevel(level);

    return Card(
      color: Colors.deepPurple,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with user intials
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text(
                _getInitials(name),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // User basic info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class and Level
                  Text('Class: $className',
                      style: const TextStyle(color: Colors.white, fontSize: 18)),
                  Text('Level: $level',
                      style: const TextStyle(color: Colors.white)),

                  // Gold and Gems
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text('Gold: $gold',
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 12),
                      const Icon(Icons.diamond, color: Colors.lightBlueAccent, size: 16),
                      const SizedBox(width: 4),
                      Text('Gems: $gems',
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Health and XP Bars
                  Text('Health: $health/$maxHealth',
                      style: const TextStyle(color: Colors.white)),
                  LinearProgressIndicator(
                    value: health / maxHealth,
                    backgroundColor: Colors.grey,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 5),
                  const Text('XP', style: TextStyle(color: Colors.white)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'XP Progress',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: xp / xpRequired,
                              backgroundColor: Colors.grey[300],
                              color: Colors.blue,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$xp/$xpRequired',
                            style: const TextStyle(fontSize: 12),
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
    );
  }
}

// Displays basic task info (title, category, type, due/completed date)
class TaskCard extends StatelessWidget {
  final String title, type, category;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;
  final String? dueDate;
  final DateTime? completedDate;

  TaskCard({
    required this.title,
    required this.type,
    required this.category,
    required this.onComplete,
    this.onTap,
    this.dueDate,
    this.completedDate,
  });

  // Define colors for different types
  final Map<String, Color> typeColors = {
    'Daily': Colors.deepPurple,
    'Weekly': Colors.blue,
    'Monthly': Colors.teal,
    'One-Time': Colors.redAccent,
  };

  // Define colors for different categories
  final Map<String, Color> categoryColors = {
    'Physical': Colors.orange,
    'Intellectual': Colors.green,
    'Academic': Colors.indigo,
    'Lifestyle': Colors.pink,
    'Miscellaneous': Colors.brown,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 4, // Increased elevation for more shadow
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(  // Add a subtle border
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),

          // Apply a slight gradient to make the card pop
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardTheme.color ?? theme.colorScheme.surface,
                  theme.isDarkTheme
                      ? Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.surface)
                      : theme.colorScheme.surface.withOpacity(0.9),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mark Complete Button
                if (onComplete != null)
                  IconButton(
                    icon: Icon(Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 28),
                    onPressed: onComplete,
                  )
                  //Disable Button if task is completed
                else
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.check_circle,
                        color: theme.disabledColor,
                        size: 28),
                  ),

                // Task Title
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (type == 'One-Time' && dueDate != null)
                        Text(
                          'Due: ${DateFormat.yMMMd().format(DateTime.parse(dueDate!))}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      if (completedDate != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Completed on: ${DateFormat.yMMMd().format(completedDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),

                // Type & Category Section (Rightmost)
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(
                        color: theme.dividerColor,
                        width: 1
                    )),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [

                      // Type Section (Top)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: typeColors[type] ?? theme.colorScheme.secondary,
                          borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                          border: Border(bottom: BorderSide(
                              color: theme.dividerColor,
                              width: 1
                          )),
                        ),
                        child: Text(
                          type,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,  // Make text bolder
                          ),
                        ),
                      ),

                      // Category Section (Bottom)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColors[category] ?? theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
                        ),
                        child: Text(
                          category,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
    );
  }
}

// Displays basic enemy info (sprite, name, level, health, rewards)
class EnemyCard extends StatelessWidget {
  final Map<String, dynamic> enemy;
  final VoidCallback onTap;

  const EnemyCard({
    Key? key,
    required this.enemy,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isBoss = enemy['isBoss'] ?? false;
    final rewardGems = enemy['rewardGold'] ?? 0;
    final rewardXp = enemy['rewardXp'] ?? 0;
    final enemyMaxHealth = enemy['maxHealth'] ?? 100;
    final enemyHealth = enemy['health'] ?? enemyMaxHealth;
    final enemyLevel = enemy['level'] ?? 1;
    final spritePath = enemy['spritePath'];

    // Get the enemy stats
    final Map<String, dynamic> enemyStats = enemy['stats'] ?? {
      'phyatk': 5,
      'phydef': 3,
      'magatk': 5,
      'magdef': 3
    };

    final phyAtk = enemyStats['phyatk'] ?? 5;
    final phyDef = enemyStats['phydef'] ?? 3;
    final magAtk = enemyStats['magatk'] ?? 5;
    final magDef = enemyStats['magdef'] ?? 3;

    // Determine enemy type for icon (fallback if sprite not available)
    IconData enemyIcon;
    switch (enemy['type']?.toString().toLowerCase() ?? 'monster') {
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // If enemy is boss, highlight card with red border
          side: isBoss
              ? BorderSide(color: Colors.red, width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enemy info with portrait
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enemy sprite or fallback icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: spritePath != null && spritePath.isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        spritePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image fails to load
                          return Icon(
                            enemyIcon,
                            size: 40,
                            color: theme.primaryColor,
                          );
                        },
                      ),
                    )
                        : Icon(
                      enemyIcon,
                      size: 40,
                      color: theme.primaryColor,
                    ),
                  ),

                  SizedBox(width: 12),

                  // Enemy details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enemy name and level
                        Row(
                          children: [
                            Text(
                              'Level $enemyLevel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.hintColor,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                enemy['name'] ?? 'Unknown Enemy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // Enemy health bar
                        Text('Health', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: enemyHealth / enemyMaxHealth,
                          backgroundColor: Colors.grey[300],
                          color: Colors.red,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),

                        SizedBox(height: 8),

                        // Display enemy stats
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Stats:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'PHY: $phyAtk / $phyDef',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'MAG: $magAtk / $magDef',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // Rewards section
                        Text(
                          'Rewards:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.diamond,
                                color: Colors.lightBlueAccent, size: 16),
                            SizedBox(width: 4),
                            Text('$rewardGems Gems'),
                            SizedBox(width: 16),
                            Icon(Icons.star,
                                color: Colors.blue, size: 16),
                            SizedBox(width: 4),
                            Text('$rewardXp XP'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Boss indicator
            if (isBoss)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'BOSS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Displays Item Info
class ItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onPurchase;
  final VoidCallback onInfo;
  final Color? backgroundColor; // Added background color parameter

  const ItemCard({
    required this.item,
    required this.onPurchase,
    required this.onInfo,
    this.backgroundColor, // Optional background color
  });

  @override
  _ItemCardState createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Safely get spritePath, with fallback to a default
    final String spritePath = widget.item['spritePath'] ?? 'assets/images/placeholder.png';

    // Determine the background color
    final Color cardBackgroundColor = widget.backgroundColor ??
        (isDarkMode ? Colors.grey.shade800 : Colors.white);

    return GestureDetector(
      onTap: () {
        setState(() {
          _isHovered = !_isHovered;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBackgroundColor, // Apply background color
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black : Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],

          // Add a subtle gradient overlay to enhance the background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardBackgroundColor.withOpacity(0.8),
              cardBackgroundColor,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background pattern (optional subtle pattern)
              Container(
                decoration: BoxDecoration(
                  // Optional pattern effect
                  image: isDarkMode ? null : DecorationImage(
                    image: AssetImage('assets/images/card_pattern.png'),
                    fit: BoxFit.cover,
                    opacity: 0.05, // Very subtle pattern
                  ),
                ),
              ),

              // Item image - now as a layer above the background
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Image.asset(
                  spritePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.transparent,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    );
                  },
                ),
              ),

              // Item name/title
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.item['name'] ?? 'Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Price footer
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.item['currency'] == 'gems'
                            ? Icons.diamond
                            : Icons.monetization_on,
                        color: widget.item['currency'] == 'gems'
                            ? Colors.lightBlueAccent
                            : Colors.amber,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.item['price']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Button overlay when tapped
              if (_isHovered)
                Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!widget.item['purchased'])
                        ElevatedButton(
                          onPressed: widget.onPurchase,
                          child: Text('Buy'),
                          style: ElevatedButton.styleFrom(
                            // Use default button theme from your app
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: null,
                          child: Text('Owned'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: widget.onInfo,
                        child: Text('Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Displays Skill Info (for skills page)
class SkillInfoCard extends StatelessWidget {
  final Map<String, dynamic> skill;
  final bool isExpanded;
  final bool isLearned;
  final Map<String, Map<String, dynamic>> skillsMap;
  final List<String> learnedSkills;
  final Function onToggleExpand;
  final Function onLearn;
  final Function getSkillIcon;
  final Function buildEffectsList;

  const SkillInfoCard({
    Key? key,
    required this.skill,
    required this.isExpanded,
    required this.isLearned,
    required this.skillsMap,
    required this.learnedSkills,
    required this.onToggleExpand,
    required this.onLearn,
    required this.getSkillIcon,
    required this.buildEffectsList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final skillName = skill['name'] ?? 'Unknown Skill';
    final skillType = skill['type'] ?? 'basic';
    final skillDescription = skill['description'] ?? 'No description available.';
    final spCost = skill['spCost'] ?? 1;

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

        if (!learnedSkills.contains(prereqId)) {
          prerequisitesMet = false;
          // Get prerequisite name
          String prereqName = skillsMap[prereqId]?['name'] ?? 'Unknown Skill';
          missingPrereqs.add(prereqName);
        }
      }
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isLearned
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => onToggleExpand(),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Card Header - Always Visible
            Container(
              height: 80,
              child: Row(
                children: [
                  // Left side - Icon/Image
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(isExpanded ? 0 : 16),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          getSkillIcon(skillType),
                          color: Theme.of(context).primaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  // Right side - Skill Name
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              skillName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLearned)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Expanded Content
            if (isExpanded)
              Container(
                padding: EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      skillDescription,
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 16),

                    // Effects
                    Text(
                      'Effects:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    ...buildEffectsList(),
                    SizedBox(height: 16),

                    // Missing Prerequisites
                    if (!prerequisitesMet && missingPrereqs.isNotEmpty) ...[
                      Text(
                        'Missing Prerequisites:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: 4),
                      ...missingPrereqs.map((prereq) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(prereq),
                          ],
                        ),
                      )).toList(),
                      SizedBox(height: 16),
                    ],

                    // Learn Button
                    Center(
                      child: isLearned
                          ? Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Learned',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                          : ElevatedButton(
                        onPressed: prerequisitesMet ? () => onLearn() : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Learn Skill'),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, size: 16),
                                  SizedBox(width: 2),
                                  Text('$spCost'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Displays Skill Info (for battle)
class SkillCard extends StatelessWidget {
  final Map<String, dynamic> skill; // Skill data from firestore
  final bool isLearned;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;
  final VoidCallback onLearnTap;
  final double collapsedWidth;
  final double expandedWidth;
  final double collapsedHeight;
  final double expandedHeight;

  const SkillCard({
    Key? key,
    required this.skill,
    required this.isLearned,
    required this.isExpanded,
    required this.onTap,
    required this.onInfoTap,
    required this.onLearnTap,
    this.collapsedWidth = 60.0,
    this.expandedWidth = 140.0,
    this.collapsedHeight = 60.0,
    this.expandedHeight = 120.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skillPointCost = skill['spCost'] ?? 1;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: isExpanded ? expandedWidth : collapsedWidth,
        height: isExpanded ? expandedHeight : collapsedHeight,
        decoration: BoxDecoration(
          color: isLearned ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(isExpanded ? 16 : 30),
          border: Border.all(
            color: isLearned ? theme.primaryColor : theme.dividerColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: isExpanded
            ? Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Skill name
              Text(
                skill['name'] ?? 'Unknown',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLearned ? Colors.white : theme.textTheme.bodyLarge?.color,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Info button
                  _buildCompactButton(
                    context,
                    icon: Icons.info_outline,
                    label: 'Info',
                    onTap: onInfoTap,
                    isLearned: isLearned,
                  ),
                  // Learn button (only if not learned)
                  if (!isLearned)
                    _buildCompactButton(
                      context,
                      icon: Icons.add_circle_outline,
                      label: '$skillPointCost SP',
                      onTap: onLearnTap,
                      isLearned: false,
                    ),
                ],
              ),
            ],
          ),
        )
            : Center(
          // Skill Icon
          child: Icon(
            _getSkillIcon(skill['type'] ?? 'basic'),
            color: isLearned ? Colors.white : theme.iconTheme.color,
            size: 24, // Reduced icon size
          ),
        ),
      ),
    );
  }

  // Builds a tiny button with an icon and label
  Widget _buildCompactButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required bool isLearned,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isLearned ? Colors.white : Theme.of(context).iconTheme.color,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: isLearned ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  // Get skill icon depending on skill type
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
      default:
        return Icons.extension;
    }
  }
}

// Create a Reward Dialog widget to display task rewards
class RewardDialog extends StatelessWidget {
  final TaskReward reward;
  final String taskTitle;

  const RewardDialog({
    Key? key,
    required this.reward,
    required this.taskTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Task Completed!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You completed: $taskTitle', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Text('Rewards earned:', style: TextStyle(fontSize: 16)),
          SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 5),
              Text('XP: +${reward.xp}', style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.monetization_on, color: Colors.amber),
              SizedBox(width: 5),
              Text('Gold: +${reward.gold}', style: TextStyle(fontSize: 16)),
            ],
          ),

          // Display stat rewards if any
          if (reward.stats.values.any((val) => val > 0)) ...[
            SizedBox(height: 10),
            Text('Stat points:', style: TextStyle(fontSize: 16)),
            SizedBox(height: 5),
            if (reward.stats['strength']! > 0)
              Row(
                children: [
                  Icon(Icons.fitness_center, color: Colors.red),
                  SizedBox(width: 5),
                  Text('STR: +${reward.stats['strength']}', style: TextStyle(fontSize: 16)),
                ],
              ),
            if (reward.stats['intelligence']! > 0)
              Row(
                children: [
                  Icon(Icons.school, color: Colors.blue),
                  SizedBox(width: 5),
                  Text('INT: +${reward.stats['intelligence']}', style: TextStyle(fontSize: 16)),
                ],
              ),
            if (reward.stats['vitality']! > 0)
              Row(
                children: [
                  Icon(Icons.favorite, color: Colors.green),
                  SizedBox(width: 5),
                  Text('VIT: +${reward.stats['vitality']}', style: TextStyle(fontSize: 16)),
                ],
              ),
            if (reward.stats['wisdom']! > 0)
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.purple),
                  SizedBox(width: 5),
                  Text('WIS: +${reward.stats['wisdom']}', style: TextStyle(fontSize: 16)),
                ],
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('OK'),
        ),
      ],
    );
  }
}

// Displays Class Info
class ClassCard extends StatelessWidget {
  final Map<String, dynamic> classData;
  final VoidCallback? onTap;
  final int userLevel;
  final List<String> userClasses;

  const ClassCard({
    Key? key,
    required this.classData,
    this.onTap,
    required this.userLevel,
    required this.userClasses,
  }) : super(key: key);

  bool get isOwned => userClasses.contains(classData['id']);
  bool get canSelect => onTap != null;
  bool get isBasic => classData['type'].toString().toLowerCase() == 'basic';
  bool get isAdvanced => classData['type'].toString().toLowerCase() == 'advanced';
  bool get hasLevelRequirement => userLevel < (classData['reqLevel'] ?? 1);

  String get statusMessage {
    if (isOwned) return 'Owned';
    if (isBasic && userClasses.isNotEmpty) return 'Already have basic class';
    if (hasLevelRequirement) return 'Need higher level';
    if (isAdvanced && userLevel < 20) return 'Need level 20+';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skills = classData['skills'] as List? ?? [];

    print('DEBUG: Building ClassCard for "${classData['className']}" with ${skills.length} skills');
    if (skills.isNotEmpty) {
      print('DEBUG: First skill for "${classData['className']}": ${_formatSkill(skills.first)}');
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: canSelect ? 1.0 : 0.6,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with class name and level requirement
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      classData['className'] ?? 'Unknown Class',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Req. Level: ${classData['reqLevel'] ?? 1}',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),

                // Status label if applicable
                if (statusMessage.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwned ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOwned ? Colors.green : Colors.red,
                      ),
                    ),
                  ),

                // Skill icons
                if (skills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        for (int i = 0; i < 3 && i < skills.length; i++)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                print('DEBUG: Skill tapped: ${_formatSkill(skills[i])}');
                                // Show skill dialog
                                _showSkillDialog(context, skills[i]);
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getSkillIcon(skills[i]),
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSkill(dynamic skill) {
    if (skill is Map) {
      return '{name: ${skill['name']}, description: ${skill['description'] ?? 'No description'}}';
    } else if (skill is String) {
      return skill;
    } else {
      return skill.toString();
    }
  }

  IconData _getSkillIcon(dynamic skill) {
    // This would ideally be mapped to specific skill icons
    // For now using placeholder icons
    final icons = [
      Icons.flash_on,
      Icons.security,
      Icons.sports_kabaddi,
      Icons.local_fire_department,
      Icons.bolt,
      Icons.add_moderator,
    ];

    // Generate a consistent index based on the skill name or ID
    int index = 0;
    print('DEBUG: Skill type: ${skill.runtimeType}');

    if (skill is Map<String, dynamic>) {
      final name = skill['name'] as String? ?? '';
      print('DEBUG: Getting icon for skill map: $name');
      index = name.isNotEmpty ? name.codeUnitAt(0) % icons.length : 0;
    } else if (skill is String) {
      print('DEBUG: Getting icon for skill string: $skill');
      index = skill.isNotEmpty ? skill.codeUnitAt(0) % icons.length : 0;
    } else if (skill is DocumentReference) {
      // Handle DocumentReference case
      print('DEBUG: Skill is a DocumentReference: ${skill.id}');
      final id = skill.id;
      index = id.isNotEmpty ? id.codeUnitAt(0) % icons.length : 0;
    } else {
      print('DEBUG: Unexpected skill type: ${skill.runtimeType}, value: $skill');
    }

    return icons[index];
  }

  void _showSkillDialog(BuildContext context, dynamic skill) async {
    String skillName = 'Unknown Skill';
    String skillDescription = 'No description available.';

    print('DEBUG: Showing skill dialog. Skill type: ${skill.runtimeType}');
    print('DEBUG: Skill raw value: $skill');

    if (skill is Map<String, dynamic>) {
      skillName = skill['name'] as String? ?? 'Unknown Skill';
      skillDescription = skill['description'] as String? ?? 'No description available.';
      print('DEBUG: Showing skill dialog for map: $skillName');
    } else if (skill is String) {
      skillName = skill;
      print('DEBUG: Showing skill dialog for string skill: $skillName');
    } else if (skill is DocumentReference) {
      // Handle skill reference by fetching the actual skill data
      print('DEBUG: Fetching skill data from reference: ${skill.id}');
      try {
        final skillDoc = await skill.get();
        if (skillDoc.exists) {
          final skillData = skillDoc.data() as Map<String, dynamic>?;
          if (skillData != null) {
            skillName = skillData['name'] as String? ?? 'Unknown Skill';
            skillDescription = skillData['description'] as String? ?? 'No description available.';
            print('DEBUG: Successfully fetched skill: $skillName');
          }
        }
      } catch (e) {
        print('DEBUG: Error fetching skill data: $e');
      }
    }

    // Only show dialog if context is still valid
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(skillName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(skillDescription),
              SizedBox(height: 8),
              Text('Debug info:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Type: ${skill.runtimeType}', style: TextStyle(fontSize: 12)),
              if (skill is DocumentReference)
                Text('Reference: ${skill.path}', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
