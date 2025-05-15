import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'main.dart';

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

  // Define colors for different types - keeping these as they are task-specific visual indicators
  final Map<String, Color> typeColors = {
    'Daily': Colors.deepPurple,
    'Weekly': Colors.blue,
    'Monthly': Colors.teal,
    'One-Time': Colors.redAccent,
  };

  // Define colors for different categories - keeping these as they are task-specific visual indicators
  final Map<String, Color> categoryColors = {
    'Physical': Colors.orange,
    'Intellectual': Colors.green,
    'Academic': Colors.indigo,
    'Lifestyle': Colors.pink,
    'Miscellaneous': Colors.brown,
  };

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 4, // Increased elevation for more shadow
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8), // Add some margin
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Slightly larger radius
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
                // Rest of your existing row layout...
                // Mark Complete Button (Left Side)
                if (onComplete != null)
                  IconButton(
                    icon: Icon(Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 28),
                    onPressed: onComplete,
                  )
                else
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.check_circle,
                        color: theme.disabledColor,
                        size: 28),
                  ),

                // Task Name (Centered)
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
                      topRight: Radius.circular(12),  // Matched to outer radius
                      bottomRight: Radius.circular(12),  // Matched to outer radius
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
                            fontWeight: FontWeight.bold,  // Make text bolder
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
    final rewardGold = enemy['rewardGold'] ?? 0;
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
                            Text('$rewardGold Gems'),
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



class SkillCard extends StatelessWidget {
  final Map<String, dynamic> skill;
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
          child: Icon(
            _getSkillIcon(skill['type'] ?? 'basic'),
            color: isLearned ? Colors.white : theme.iconTheme.color,
            size: 24, // Reduced icon size
          ),
        ),
      ),
    );
  }

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
            size: 12, // Further reduced icon size
            color: isLearned ? Colors.white : Theme.of(context).iconTheme.color,
          ),
          const SizedBox(height: 1), // Reduced spacing
          Text(
            label,
            style: TextStyle(
              fontSize: 8, // Further reduced font size
              color: isLearned ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
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
      default:
        return Icons.extension;
    }
  }
}

class ConnectionsPainter extends CustomPainter {
  final Map<String, Offset> skillPositions;
  final List<Map<String, dynamic>> connections;
  final Offset panOffset;
  final double scale;
  final List<String> learnedSkills;
  final double collapsedCardWidth;

  ConnectionsPainter({
    required this.skillPositions,
    required this.connections,
    required this.panOffset,
    required this.scale,
    required this.learnedSkills,
    this.collapsedCardWidth = 60.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(collapsedCardWidth / 2, collapsedCardWidth / 2); // Center offset of skill card

    for (var connection in connections) {
      final fromId = connection['from'];
      final toId = connection['to'];

      final fromPosition = skillPositions[fromId];
      final toPosition = skillPositions[toId];

      if (fromPosition != null && toPosition != null) {
        final adjustedFromPos = fromPosition * scale + panOffset + center;
        final adjustedToPos = toPosition * scale + panOffset + center;

        // Determine if both skills are learned
        final fromLearned = learnedSkills.contains(fromId);
        final toLearned = learnedSkills.contains(toId);

        // Set line color based on learned status
        final paint = Paint()
          ..color = fromLearned && toLearned
              ? Colors.green
              : fromLearned
              ? Colors.blue
              : Colors.grey
          ..strokeWidth = fromLearned && toLearned ? 3.0 : 2.0
          ..style = PaintingStyle.stroke;

        // Draw connection line
        canvas.drawLine(adjustedFromPos, adjustedToPos, paint);

        // Draw arrow at the end of the line
        _drawArrow(canvas, adjustedFromPos, adjustedToPos, paint);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Calculate arrow direction
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // Normalize direction vector
    final directionX = distance > 0 ? dx / distance : 0;
    final directionY = distance > 0 ? dy / distance : 0;

    final arrowSize = 10.0 * scale;

    // Calculate arrow points
    final arrowTip = Offset(
        end.dx - directionX * 10.0 * scale,
        end.dy - directionY * 10.0 * scale
    ); // Pull back a bit from end

    // Perpendicular vector
    final perpX = -directionY;
    final perpY = directionX;

    final arrowBase1 = Offset(
        arrowTip.dx - directionX * arrowSize + perpX * arrowSize / 2,
        arrowTip.dy - directionY * arrowSize + perpY * arrowSize / 2
    );

    final arrowBase2 = Offset(
        arrowTip.dx - directionX * arrowSize - perpX * arrowSize / 2,
        arrowTip.dy - directionY * arrowSize - perpY * arrowSize / 2
    );

    // Draw arrow head
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowBase1.dx, arrowBase1.dy)
      ..lineTo(arrowBase2.dx, arrowBase2.dy)
      ..close();

    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(ConnectionsPainter oldDelegate) {
    return oldDelegate.panOffset != panOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.learnedSkills != learnedSkills;
  }
}
