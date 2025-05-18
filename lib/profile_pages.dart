import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'class_skills_container.dart';

import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Avatar? userAvatar;
  String? currentAvatarSprite;
  AvatarLayers? userAvatarLayers;
  String? baseAvatarSprite;
  String? weaponLayerSprite;
  String? armorLayerSprite;
  String? cosmeticLayerSprite;

  Map<String, dynamic>? userData;
  Map<String, dynamic>? baseStats;
  Map<String, dynamic>? battleStats;
  Map<String, dynamic>? equippedWeapon;
  Map<String, dynamic>? equippedArmor;
  Map<String, dynamic>? equippedCosmetic;
  List<Map<String, dynamic>> weaponInventory = [];
  List<Map<String, dynamic>> armorInventory = [];
  List<Map<String, dynamic>> cosmeticInventory = [];

  String currentInventoryTab = 'Weapons';
  bool _isLoading = true;

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
      if (userId == null) return;

      // Batch multiple document fetches into a single Future.wait operation
      final results = await Future.wait([
        _firestore.collection('users').doc(userId).get(),
        _firestore.collection('users').doc(userId).collection('avatar').doc('layers').get(),
        _firestore.collection('users').doc(userId).collection('stats').doc('base').get(),
        _firestore.collection('users').doc(userId).collection('stats').doc('battle').get(),
      ]);

      // Parse results
      final userDoc = results[0];
      final avatarLayersDoc = results[1];
      final baseStatsDoc = results[2];
      final battleStatsDoc = results[3];

      // Process user data
      if (userDoc.exists) {
        userData = userDoc.data();

        // Process avatar layers
        if (avatarLayersDoc.exists) {
          userAvatarLayers = AvatarLayers.fromFirestore(avatarLayersDoc.data() ?? {});
        } else {
          userAvatarLayers = AvatarLayers(
              baseSprite: 'assets/images/sprites/avatar/default_avatar.png',
              weaponLayers: {},
              armorLayers: {},
              cosmeticLayers: {}
          );
        }

        // Process stats
        if (baseStatsDoc.exists) {
          baseStats = baseStatsDoc.data();
        }

        if (battleStatsDoc.exists) {
          battleStats = battleStatsDoc.data();
        }

        // Load equipped items and inventory in parallel
        await Future.wait([
          _loadEquippedItems(userId),
          _loadInventory(userId)
        ]);

        // Update avatar layers
        _updateAvatarLayers();

        setState(() {
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEquippedItems(String userId) async {
    try {
      // Load equipped weapon if any
      final equippedWeaponRef = userData?['equippedWeapon'];
      if (equippedWeaponRef != null) {
        final weaponDoc = await equippedWeaponRef.get();
        if (weaponDoc.exists) {
          equippedWeapon = {
            ...weaponDoc.data() as Map<String, dynamic>,
            'id': weaponDoc.id,
          };

          // Ensure spritePath is loaded from the weapon document
          if (equippedWeapon!.containsKey('spritePath') && equippedWeapon!['spritePath'] != null) {
            String itemId = weaponDoc.id;
            String spritePath = equippedWeapon!['spritePath'];

            // Make sure the avatar layers are updated with this sprite path
            if (userAvatarLayers != null && !userAvatarLayers!.weaponLayers.containsKey(itemId)) {
              await _updateAvatarLayerWithSpritePath('weapon', itemId, spritePath);
            }
          }
        }
      }

      // Load equipped armor if any
      final equippedArmorRef = userData?['equippedArmor'];
      if (equippedArmorRef != null) {
        final armorDoc = await equippedArmorRef.get();
        if (armorDoc.exists) {
          equippedArmor = {
            ...armorDoc.data() as Map<String, dynamic>,
            'id': armorDoc.id,
          };

          // Ensure spritePath is loaded from the armor document
          if (equippedArmor!.containsKey('spritePath') && equippedArmor!['spritePath'] != null) {
            String itemId = armorDoc.id;
            String spritePath = equippedArmor!['spritePath'];

            // Make sure the avatar layers are updated with this sprite path
            if (userAvatarLayers != null && !userAvatarLayers!.armorLayers.containsKey(itemId)) {
              await _updateAvatarLayerWithSpritePath('armor', itemId, spritePath);
            }
          }
        }
      }

      // Load equipped cosmetic if any
      final equippedCosmeticRef = userData?['equippedCosmetic'];
      if (equippedCosmeticRef != null) {
        final cosmeticDoc = await equippedCosmeticRef.get();
        if (cosmeticDoc.exists) {
          equippedCosmetic = {
            ...cosmeticDoc.data() as Map<String, dynamic>,
            'id': cosmeticDoc.id,
          };

          // Ensure spritePath is loaded from the cosmetic document
          if (equippedCosmetic!.containsKey('spritePath') && equippedCosmetic!['spritePath'] != null) {
            String itemId = cosmeticDoc.id;
            String spritePath = equippedCosmetic!['spritePath'];

            // Make sure the avatar layers are updated with this sprite path
            if (userAvatarLayers != null && !userAvatarLayers!.cosmeticLayers.containsKey(itemId)) {
              await _updateAvatarLayerWithSpritePath('cosmetic', itemId, spritePath);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading equipped items: $e');
    }
  }

  Future<void> _loadInventory(String userId) async {
    try {
      print('Loading inventory for user: $userId');

      // Get equipped item IDs for filtering
      String? equippedWeaponId = equippedWeapon?['id'];
      String? equippedArmorId = equippedArmor?['id'];
      String? equippedCosmeticId = equippedCosmetic?['id'];

      // Load weapons inventory
      final weaponsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc('weapons')
          .get();

      print('Weapons snapshot exists: ${weaponsSnapshot.exists}');
      weaponInventory = [];

      if (weaponsSnapshot.exists && weaponsSnapshot.data() != null) {
        final weaponsData = weaponsSnapshot.data()!;

        print('Weapons data keys: ${weaponsData.keys}');

        // Check if the items field exists in any form
        if (weaponsData.containsKey('items')) {
          final items = weaponsData['items'];
          print('Items type: ${items.runtimeType}');

          if (items is List) {
            print('Processing ${items.length} weapon references');

            for (var itemRef in items) {
              print('Item reference type: ${itemRef.runtimeType}');

              try {
                DocumentReference docRef;

                // Handle both DocumentReference objects and String paths
                if (itemRef is DocumentReference) {
                  docRef = itemRef;
                  print('Using existing reference: ${docRef.path}');
                } else if (itemRef is String) {
                  // Convert string path to DocumentReference
                  docRef = _firestore.doc(itemRef);
                  print('Created reference from string: $itemRef');
                } else {
                  print('Unknown reference type: ${itemRef.runtimeType}');
                  continue; // Skip this item if we can't handle its type
                }

                final weaponDoc = await docRef.get();

                if (weaponDoc.exists) {
                  print('Found weapon: ${weaponDoc.id}');

                  // Only add to inventory if not equipped
                  if (weaponDoc.id != equippedWeaponId) {
                    weaponInventory.add({
                      ...weaponDoc.data() as Map<String, dynamic>,
                      'id': weaponDoc.id,
                      'ref': docRef,
                    });
                  }
                }
              } catch (e) {
                print('Error processing weapon reference: $e');
              }
            }
          }
        }
      }

      print('Loaded ${weaponInventory.length} weapons');

      // Load armor inventory
      final armorSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc('armor')
          .get();

      armorInventory = [];

      if (armorSnapshot.exists && armorSnapshot.data() != null) {
        final armorData = armorSnapshot.data()!;
        print('Armor data keys: ${armorData.keys}');

        if (armorData.containsKey('items')) {
          final items = armorData['items'];

          if (items is List) {
            print('Processing ${items.length} armor references');

            for (var itemRef in items) {
              try {
                DocumentReference docRef;

                // Handle both DocumentReference objects and String paths
                if (itemRef is DocumentReference) {
                  docRef = itemRef;
                } else if (itemRef is String) {
                  // Convert string path to DocumentReference
                  docRef = _firestore.doc(itemRef);
                  print('Created armor reference from string: $itemRef');
                } else {
                  print('Unknown armor reference type: ${itemRef.runtimeType}');
                  continue; // Skip this item
                }

                final armorDoc = await docRef.get();

                if (armorDoc.exists) {
                  print('Found armor: ${armorDoc.id}');

                  // Only add to inventory if not equipped
                  if (armorDoc.id != equippedArmorId) {
                    armorInventory.add({
                      ...armorDoc.data() as Map<String, dynamic>,
                      'id': armorDoc.id,
                      'ref': docRef,
                    });
                  }
                }
              } catch (e) {
                print('Error processing armor reference: $e');
              }
            }
          }
        }
      }

      print('Loaded ${armorInventory.length} armor pieces');

      // Load cosmetics inventory
      final cosmeticsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc('cosmetics')
          .get();

      cosmeticInventory = [];

      if (cosmeticsSnapshot.exists && cosmeticsSnapshot.data() != null) {
        final cosmeticsData = cosmeticsSnapshot.data()!;
        print('Cosmetics data keys: ${cosmeticsData.keys}');

        if (cosmeticsData.containsKey('items')) {
          final items = cosmeticsData['items'];

          if (items is List) {
            print('Processing ${items.length} cosmetic references');

            for (var itemRef in items) {
              try {
                DocumentReference docRef;

                // Handle both DocumentReference objects and String paths
                if (itemRef is DocumentReference) {
                  docRef = itemRef;
                } else if (itemRef is String) {
                  // Convert string path to DocumentReference
                  docRef = _firestore.doc(itemRef);
                  print('Created cosmetic reference from string: $itemRef');
                } else {
                  print('Unknown cosmetic reference type: ${itemRef.runtimeType}');
                  continue; // Skip this item
                }

                final cosmeticDoc = await docRef.get();

                if (cosmeticDoc.exists) {
                  print('Found cosmetic: ${cosmeticDoc.id}');

                  // Only add to inventory if not equipped
                  if (cosmeticDoc.id != equippedCosmeticId) {
                    cosmeticInventory.add({
                      ...cosmeticDoc.data() as Map<String, dynamic>,
                      'id': cosmeticDoc.id,
                      'ref': docRef,
                    });
                  }
                }
              } catch (e) {
                print('Error processing cosmetic reference: $e');
              }
            }
          }
        }
      }

      print('Loaded ${cosmeticInventory.length} cosmetic items');

    } catch (e) {
      print('Error loading inventory: $e');
    }
  }

  Future<void> _updateBattleStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Calculate total stats including equipment
      final totalStats = calculateTotalStats();

      // Update battle stats in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('battle')
          .update({
        'phyatk': totalStats['phyatk'],
        'phydef': totalStats['phydef'],
        'magatk': totalStats['magatk'],
        'magdef': totalStats['magdef'],
      });

      // Update local battle stats
      battleStats = {
        'phyatk': totalStats['phyatk'],
        'phydef': totalStats['phydef'],
        'magatk': totalStats['magatk'],
        'magdef': totalStats['magdef'],
      };

    } catch (e) {
      print('Error updating battle stats: $e');
    }
  }

  // Calculate total stats including equipment bonuses
  Map<String, int> calculateTotalStats() {
    // Base stats from the base stats document
    int strength = baseStats?['strength'] ?? 10;
    int intelligence = baseStats?['intelligence'] ?? 10;
    int vitality = baseStats?['vitality'] ?? 10;
    int wisdom = baseStats?['wisdom'] ?? 10;

    // Initialize combat stats with base values
    int phyatk = 5;  // Base physical attack
    int phydef = 5;  // Base physical defense
    int magatk = 5;  // Base magical attack
    int magdef = 5;  // Base magical defense

    // Apply base stat modifiers to combat stats
    phyatk += strength ~/ 2;  // Each 2 points of strength adds 1 to phyatk
    phydef += vitality ~/ 2;  // Each 2 points of vitality adds 1 to phydef
    magatk += intelligence ~/ 2; // Each 2 points of intelligence adds 1 to magatk
    magdef += wisdom ~/ 2;    // Each 2 points of wisdom adds 1 to magdef

    // Add weapon bonuses if weapon is equipped
    if (equippedWeapon != null) {
      phyatk += equippedWeapon?['phyatk'] as int? ?? 0;
      phydef += equippedWeapon?['phydef'] as int? ?? 0;
      magatk += equippedWeapon?['magatk'] as int? ?? 0;
      magdef += equippedWeapon?['magdef'] as int? ?? 0;
    }

    // Add armor bonuses if armor is equipped
    if (equippedArmor != null) {
      phyatk += equippedArmor?['phyatk'] as int? ?? 0;
      phydef += equippedArmor?['phydef'] as int? ?? 0;
      magatk += equippedArmor?['magatk'] as int? ?? 0;
      magdef += equippedArmor?['magdef'] as int? ?? 0;
    }

    // Debug output
    print('Calculated stats - phyatk: $phyatk, phydef: $phydef, magatk: $magatk, magdef: $magdef');

    return {
      'strength': strength,
      'intelligence': intelligence,
      'vitality': vitality,
      'wisdom': wisdom,
      'phyatk': phyatk,
      'phydef': phydef,
      'magatk': magatk,
      'magdef': magdef,
    };
  }

  Future<void> _equipItem(Map<String, dynamic> item, String itemType) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final itemRef = item['ref'] as DocumentReference?;
      if (itemRef == null) {
        throw Exception('Item reference is missing');
      }

      String equippedField;
      Map<String, dynamic>? previousItem;

      // Determine which equipped field to update and which previous item to unequip
      switch (itemType) {
        case 'weapon':
          equippedField = 'equippedWeapon';
          previousItem = equippedWeapon;
          break;
        case 'armor':
          equippedField = 'equippedArmor';
          previousItem = equippedArmor;
          break;
        case 'cosmetic':
          equippedField = 'equippedCosmetic';
          previousItem = equippedCosmetic;
          break;
        default:
          throw Exception('Invalid item type');
      }

      // If there's a previously equipped item, clear its layer first
      if (previousItem != null && previousItem['id'] != null) {
        String previousItemId = previousItem['id'];
        await _clearAvatarLayer(itemType, previousItemId);
      }

      // Update the user document with the new equipped item
      await _firestore.collection('users').doc(userId).update({
        equippedField: itemRef,
      });

      // Get the spritePath from the item and update avatar layers
      String? spritePath = item['spritePath'];
      String itemId = item['id'];

      if (spritePath != null) {
        // Update avatar layers with the spritePath
        await _updateAvatarLayerWithSpritePath(itemType, itemId, spritePath);
      }

      // Update battle stats in the database
      await _updateBattleStats();

      // Update local state for UI responsiveness
      setState(() {
        switch (itemType) {
          case 'weapon':
            equippedWeapon = item;
            weaponInventory.removeWhere((i) => i['id'] == itemId);
            break;
          case 'armor':
            equippedArmor = item;
            armorInventory.removeWhere((i) => i['id'] == itemId);
            break;
          case 'cosmetic':
            equippedCosmetic = item;
            cosmeticInventory.removeWhere((i) => i['id'] == itemId);
            break;
        }
      });

      // Reload user data in the background to ensure complete synchronization
      _loadUserData().then((_) {
        // Only update UI if the widget is still mounted
        if (mounted) {
          setState(() {
            // Update avatar layers after data reload
            _updateAvatarLayers();
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item['name']} equipped!')),
      );
    } catch (e) {
      print('Error equipping item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to equip item: $e')),
      );
    }
  }

  Future<void> _unequipItem(String itemType) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      String equippedField;
      String itemName;
      String? itemId;
      Map<String, dynamic>? itemToUnequip;

      switch (itemType) {
        case 'weapon':
          equippedField = 'equippedWeapon';
          itemToUnequip = equippedWeapon;
          itemName = equippedWeapon?['name'] ?? 'Weapon';
          itemId = equippedWeapon?['id'];
          break;
        case 'armor':
          equippedField = 'equippedArmor';
          itemToUnequip = equippedArmor;
          itemName = equippedArmor?['name'] ?? 'Armor';
          itemId = equippedArmor?['id'];
          break;
        case 'cosmetic':
          equippedField = 'equippedCosmetic';
          itemToUnequip = equippedCosmetic;
          itemName = equippedCosmetic?['name'] ?? 'Cosmetic';
          itemId = equippedCosmetic?['id'];
          break;
        default:
          throw Exception('Invalid item type');
      }

      // If we have an item ID, clear its layer from the avatar
      if (itemId != null) {
        await _clearAvatarLayer(itemType, itemId);
      }

      // Use FieldValue.delete() to completely remove the field
      await _firestore.collection('users').doc(userId).update({
        equippedField: FieldValue.delete(),
      });

      // Immediately update local state for UI responsiveness
      setState(() {
        if (itemType == 'weapon') {
          equippedWeapon = null;
          weaponLayerSprite = null;
        } else if (itemType == 'armor') {
          equippedArmor = null;
          armorLayerSprite = null;
        } else if (itemType == 'cosmetic') {
          equippedCosmetic = null;
          cosmeticLayerSprite = null;
        }
      });

      // Update battle stats in the database to remove the item's bonuses
      await _updateBattleStats();

      // Now reload user data and inventory to refresh everything
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$itemName unequipped successfully!')),
      );
    } catch (e) {
      print('Error unequipping item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unequip item: $e')),
      );
    }
  }

  Future<void> _addEquippedItemToInventory(Map<String, dynamic> item, String itemType) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      String inventoryDocName;
      switch (itemType) {
        case 'weapon':
          inventoryDocName = 'weapons';
          break;
        case 'armor':
          inventoryDocName = 'armor';
          break;
        case 'cosmetic':
          inventoryDocName = 'cosmetics';
          break;
        default:
          throw Exception('Invalid item type');
      }

      // Get a reference to the item
      final itemRef = item['ref'] as DocumentReference?;
      if (itemRef == null) {
        throw Exception('Item reference is missing');
      }

      // Add the item reference to the appropriate inventory collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('inventory')
          .doc(inventoryDocName)
          .update({
        'items': FieldValue.arrayUnion([itemRef]),
      });

    } catch (e) {
      print('Error adding equipped item back to inventory: $e');
    }
  }

  void _updateAvatarLayers() {
    if (userAvatarLayers == null) return;

    // Set base sprite
    baseAvatarSprite = userAvatarLayers!.baseSprite;

    // Reset layer sprites
    weaponLayerSprite = null;
    armorLayerSprite = null;
    cosmeticLayerSprite = null;

    // Check if weapon is equipped and if it has a matching layer
    if (equippedWeapon != null) {
      String weaponId = equippedWeapon!['id'];
      if (userAvatarLayers!.weaponLayers.containsKey(weaponId)) {
        weaponLayerSprite = userAvatarLayers!.weaponLayers[weaponId];
      }
    }

    // Check if armor is equipped and if it has a matching layer
    if (equippedArmor != null) {
      String armorId = equippedArmor!['id'];
      if (userAvatarLayers!.armorLayers.containsKey(armorId)) {
        armorLayerSprite = userAvatarLayers!.armorLayers[armorId];
      }
    }

    // Check if cosmetic is equipped and if it has a matching layer
    if (equippedCosmetic != null) {
      String cosmeticId = equippedCosmetic!['id'];
      if (userAvatarLayers!.cosmeticLayers.containsKey(cosmeticId)) {
        cosmeticLayerSprite = userAvatarLayers!.cosmeticLayers[cosmeticId];
      }
    }
  }

  Future<void> _clearAvatarLayer(String itemType, String itemId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userAvatarLayers == null) return;

    try {
      Map<String, dynamic> updateData = {};

      // Use FieldValue.delete() to remove the specific field
      switch (itemType) {
        case 'weapon':
          userAvatarLayers!.weaponLayers.remove(itemId);
          updateData = {'weaponLayers.$itemId': FieldValue.delete()};
          break;
        case 'armor':
          userAvatarLayers!.armorLayers.remove(itemId);
          updateData = {'armorLayers.$itemId': FieldValue.delete()};
          break;
        case 'cosmetic':
          userAvatarLayers!.cosmeticLayers.remove(itemId);
          updateData = {'cosmeticLayers.$itemId': FieldValue.delete()};
          break;
        default:
          throw Exception('Invalid item type');
      }

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('avatar')
          .doc('layers')
          .update(updateData);

      print('Cleared $itemType layer with ID: $itemId');
    } catch (e) {
      print('Error clearing avatar layer: $e');
    }
  }

  // Update Avatar Sprite layers with the proper sprites
  Future<void> _updateAvatarLayerWithSpritePath(String itemType, String itemId, String spritePath) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userAvatarLayers == null) return;

    try {
      Map<String, dynamic> updateData = {};

      switch (itemType) {
        case 'weapon':
          userAvatarLayers!.weaponLayers[itemId] = spritePath;
          updateData = {'weaponLayers.$itemId': spritePath};
          break;
        case 'armor':
          userAvatarLayers!.armorLayers[itemId] = spritePath;
          updateData = {'armorLayers.$itemId': spritePath};
          break;
        case 'cosmetic':
          userAvatarLayers!.cosmeticLayers[itemId] = spritePath;
          updateData = {'cosmeticLayers.$itemId': spritePath};
          break;
        default:
          throw Exception('Invalid item type');
      }

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('avatar')
          .doc('layers')
          .update(updateData);

    } catch (e) {
      print('Error updating avatar layer with spritePath: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalStats = calculateTotalStats();

    return Scaffold(
      appBar: AppBar(
        title: Text('Character'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : userData == null
          ? Center(child: Text('User data not available'))
          : Column(
        children: [
          // Top Panel - Character and Equipment
          Expanded(
            flex: 5,
            child: _buildTopPanel(theme),
          ),

          // Bottom Panel - Stats and Inventory
          Expanded(
            flex: 6,
            child: _buildBottomPanel(theme, totalStats),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPanel(ThemeData theme) {
    return Stack(
      children: [
        // Character Avatar in Center
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Character Avatar/Sprite - Updated to use layered sprite
              baseAvatarSprite != null
                  ? LayeredSprite(
                baseLayer: baseAvatarSprite!,
                weaponLayer: weaponLayerSprite,
                armorLayer: armorLayerSprite,
                cosmeticLayer: cosmeticLayerSprite,
                size: 120,
              )
                  : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: theme.primaryColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person,
                    size: 80,
                    color: theme.primaryColor,
                  ),
                ),
              ),

              SizedBox(height: 8),

              // Character Name
              Text(
                userData?['username'] ?? 'Player',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              // Level
              Text(
                'Level ${userData?['userLevel'] ?? 1}',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Equipment Slots - moved to the left side in a column
        Positioned(
          left: 20,
          top: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEquipmentSlot(
                'Weapon',
                equippedWeapon?['name'] ?? 'No Weapon',
                Icons.local_fire_department,
                theme,
                    () => _showEquipmentDialog(equippedWeapon, 'weapon'),
              ),
              SizedBox(height: 12),
              _buildEquipmentSlot(
                'Armor',
                equippedArmor?['name'] ?? 'No Armor',
                Icons.shield,
                theme,
                    () => _showEquipmentDialog(equippedArmor, 'armor'),
              ),
              SizedBox(height: 12),
              _buildEquipmentSlot(
                'Cosmetic',
                equippedCosmetic?['name'] ?? 'No Cosmetic',
                Icons.face,
                theme,
                    () => _showEquipmentDialog(equippedCosmetic, 'cosmetic'),
              ),
            ],
          ),
        ),

        // Skill Tree Button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClassSkillsContainer()),
              );
            },
            child: Icon(Icons.account_tree),
            tooltip: 'Skill Tree',
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentSlot(
      String title,
      String itemName,
      IconData icon,
      ThemeData theme,
      VoidCallback onTap,
      ) {
    // Find the appropriate equipped item and sprite path
    String? spritePath;
    if (title == 'Weapon' && equippedWeapon != null) {
      spritePath = equippedWeapon!['spritePath'];
    } else if (title == 'Armor' && equippedArmor != null) {
      spritePath = equippedArmor!['spritePath'];
    } else if (title == 'Cosmetic' && equippedCosmetic != null) {
      spritePath = equippedCosmetic!['spritePath'];
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 70,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use sprite image if available, otherwise fall back to icon
            spritePath != null && spritePath.isNotEmpty
                ? Container(
              height: 24,
              width: 24,
              child: Image.asset(
                spritePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image $spritePath: $error');
                  return Icon(icon, color: theme.primaryColor);
                },
              ),
            )
                : Icon(icon, color: theme.primaryColor),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(height: 2),
            Text(
              itemName,
              style: TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(ThemeData theme, Map<String, int> totalStats) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Stats Panel - Left Side
          Expanded(
            flex: 4,
            child: _buildStatsPanel(theme, totalStats),
          ),

          // Vertical Divider
          Container(
            height: double.infinity,
            width: 1,
            color: theme.dividerColor,
          ),

          // Inventory Panel - Right Side
          Expanded(
            flex: 6,
            child: _buildInventoryPanel(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(ThemeData theme, Map<String, int> totalStats) {
    // Use SingleChildScrollView to handle overflow
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Character Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),

            // Base Stats
            Text(
              'Base Stats',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),

            SizedBox(height: 8),

            _buildStatRow('STR', totalStats['strength']!, theme),
            _buildStatRow('INT', totalStats['intelligence']!, theme),
            _buildStatRow('VIT', totalStats['vitality']!, theme),
            _buildStatRow('WIS', totalStats['wisdom']!, theme),

            SizedBox(height: 16),

            // Combat Stats
            Text(
              'Combat Stats',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),

            SizedBox(height: 8),

            _buildStatRow(
              'PATK',
              totalStats['phyatk']!,
              theme,
              baseValue: userData?['phyatk'] ?? 5,
            ),

            _buildStatRow(
              'PDEF',
              totalStats['phydef']!,
              theme,
              baseValue: userData?['phydef'] ?? 5,
            ),

            _buildStatRow(
              'MATK',
              totalStats['magatk']!,
              theme,
              baseValue: userData?['magatk'] ?? 5,
            ),

            _buildStatRow(
              'MDEF',
              totalStats['magdef']!,
              theme,
              baseValue: userData?['magdef'] ?? 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, ThemeData theme, {int? baseValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label with constrained width to ensure it doesn't take too much space
          Flexible(
            flex: 2,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8.0),
          Flexible(
            flex: 1,
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fix for the overflow in the Row - Use Wrap instead of Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Inventory Title
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Category Toggle Buttons - Updated to remove border
              Container(
                margin: EdgeInsets.only(top: 8),
                child: ToggleButtons(
                  constraints: BoxConstraints(minWidth: 48, minHeight: 32),
                  borderRadius: BorderRadius.circular(20),
                  borderWidth: 0, // Remove the border
                  fillColor: theme.primaryColor.withOpacity(0.2),
                  selectedBorderColor: Colors.transparent, // Remove selected border
                  borderColor: Colors.transparent, // Remove border
                  isSelected: [
                    currentInventoryTab == 'Weapons',
                    currentInventoryTab == 'Armor',
                    currentInventoryTab == 'Cosmetics',
                  ],
                  onPressed: (index) {
                    setState(() {
                      currentInventoryTab = index == 0
                          ? 'Weapons'
                          : index == 1
                          ? 'Armor'
                          : 'Cosmetics';
                    });
                  },
                  children: [
                    Icon(Icons.local_fire_department, size: 16),
                    Icon(Icons.shield, size: 16),
                    Icon(Icons.face, size: 16),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Inventory Grid
          Expanded(
            child: currentInventoryTab == 'Weapons'
                ? _buildInventoryGrid(weaponInventory, 'weapon', theme)
                : currentInventoryTab == 'Armor'
                ? _buildInventoryGrid(armorInventory, 'armor', theme)
                : _buildInventoryGrid(cosmeticInventory, 'cosmetic', theme),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid(List<Map<String, dynamic>> items, String itemType, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Text('No items in inventory'),
      );
    }

    // Make grid responsive based on available width
    return LayoutBuilder(
        builder: (context, constraints) {
          // Calculate number of items per row based on width
          final double itemWidth = 80; // Minimum width for an item
          final int crossAxisCount = constraints.maxWidth ~/ itemWidth;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final String? spritePath = item['spritePath'];

              return GestureDetector(
                onTap: () => _showEquipConfirmation(item, itemType),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Item Sprite or Fallback Icon
                      spritePath != null && spritePath.isNotEmpty
                          ? Container(
                        height: 32,
                        width: 32,
                        child: Image.asset(
                          spritePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image $spritePath: $error');
                            return Icon(
                              itemType == 'weapon'
                                  ? Icons.local_fire_department
                                  : itemType == 'armor'
                                  ? Icons.shield
                                  : Icons.face,
                              color: theme.primaryColor,
                              size: 24,
                            );
                          },
                        ),
                      )
                          : Icon(
                        itemType == 'weapon'
                            ? Icons.local_fire_department
                            : itemType == 'armor'
                            ? Icons.shield
                            : Icons.face,
                        color: theme.primaryColor,
                        size: 24,
                      ),

                      SizedBox(height: 4),

                      // Item Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          item['name'] ?? 'Unknown Item',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                          maxLines: 2,
                        ),
                      ),

                      // Item Level if available
                      if (item['level'] != null)
                        Text(
                          'Lvl ${item['level']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.hintColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        }
    );
  }

  void _showEquipmentDialog(Map<String, dynamic>? equipment, String type) {
    if (equipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No item equipped')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(equipment['name'] ?? 'Unknown Item'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (equipment['description'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(equipment['description']),
              ),

            if (type != 'cosmetic') ...[
              Text('Stats:', style: TextStyle(fontWeight: FontWeight.bold)),

              if ((equipment['phyatk'] ?? 0) != 0)
                _buildStatChangeText('Physical Attack', equipment['phyatk']),

              if ((equipment['phydef'] ?? 0) != 0)
                _buildStatChangeText('Physical Defense', equipment['phydef']),

              if ((equipment['magatk'] ?? 0) != 0)
                _buildStatChangeText('Magic Attack', equipment['magatk']),

              if ((equipment['magdef'] ?? 0) != 0)
                _buildStatChangeText('Magic Defense', equipment['magdef']),
            ],

            if (equipment['rarity'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Rarity: ${equipment['rarity']}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: _getRarityColor(equipment['rarity']),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showUnequipConfirmation(equipment, type);
            },
            child: Text('Unequip'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

// New method to show unequip confirmation dialog
  void _showUnequipConfirmation(Map<String, dynamic> equipment, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unequip ${equipment['name']}?'),
        content: Text('Are you sure you want to unequip this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _unequipItem(type);
              Navigator.pop(context);
            },
            child: Text('Unequip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showEquipConfirmation(Map<String, dynamic> item, String itemType) {
    final String? spritePath = item['spritePath'];
    final IconData fallbackIcon = itemType == 'weapon'
        ? Icons.local_fire_department
        : itemType == 'armor'
        ? Icons.shield
        : Icons.face;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            // Item Sprite
            spritePath != null && spritePath.isNotEmpty
                ? Container(
              height: 32,
              width: 32,
              margin: EdgeInsets.only(right: 8),
              child: Image.asset(
                spritePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(fallbackIcon, color: Theme.of(context).primaryColor);
                },
              ),
            )
                : Icon(fallbackIcon, color: Theme.of(context).primaryColor),

            // Item Name
            Expanded(
              child: Text('Equip ${item['name']}?'),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Item stats
            if (itemType != 'cosmetic') ...[
              Text('Stats:'),

              if ((item['phyatk'] ?? 0) != 0)
                _buildStatChangeText('Physical Attack', item['phyatk']),

              if ((item['phydef'] ?? 0) != 0)
                _buildStatChangeText('Physical Defense', item['phydef']),

              if ((item['magatk'] ?? 0) != 0)
                _buildStatChangeText('Magic Attack', item['magatk']),

              if ((item['magdef'] ?? 0) != 0)
                _buildStatChangeText('Magic Defense', item['magdef']),
            ] else
              Text('Equip this cosmetic item?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _equipItem(item, itemType);
              Navigator.pop(context);
            },
            child: Text('Equip'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChangeText(String label, int value) {
    final color = value > 0 ? Colors.green : Colors.red;
    final prefix = value > 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Text('$label: '),
          Text(
            '$prefix$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEquipmentDetails(Map<String, dynamic>? equipment, String type) {
    if (equipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No item equipped')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(equipment['name'] ?? 'Unknown Item'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (equipment['description'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(equipment['description']),
              ),

            if (type != 'cosmetic') ...[
              Text('Stats:', style: TextStyle(fontWeight: FontWeight.bold)),

              if ((equipment['phyatk'] ?? 0) != 0)
                _buildStatChangeText('Physical Attack', equipment['phyatk']),

              if ((equipment['phydef'] ?? 0) != 0)
                _buildStatChangeText('Physical Defense', equipment['phydef']),

              if ((equipment['magatk'] ?? 0) != 0)
                _buildStatChangeText('Magic Attack', equipment['magatk']),

              if ((equipment['magdef'] ?? 0) != 0)
                _buildStatChangeText('Magic Defense', equipment['magdef']),
            ],

            if (equipment['rarity'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Rarity: ${equipment['rarity']}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: _getRarityColor(equipment['rarity']),
                  ),
                ),
              ),
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

  Future<void> addSpriteLayerMapping(String itemType, String itemId, String layerPath) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userAvatarLayers == null) return;

    try {
      Map<String, dynamic> updateData = {};

      switch (itemType) {
        case 'weapon':
          userAvatarLayers!.weaponLayers[itemId] = layerPath;
          updateData = {'weaponLayers.$itemId': layerPath};
          break;
        case 'armor':
          userAvatarLayers!.armorLayers[itemId] = layerPath;
          updateData = {'armorLayers.$itemId': layerPath};
          break;
        case 'cosmetic':
          userAvatarLayers!.cosmeticLayers[itemId] = layerPath;
          updateData = {'cosmeticLayers.$itemId': layerPath};
          break;
        default:
          throw Exception('Invalid item type');
      }

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('avatar')
          .doc('layers')
          .update(updateData);

    } catch (e) {
      print('Error adding sprite layer mapping: $e');
    }
  }

// Helper method for admin purposes - adds sprite layer mapping for all users
  Future<void> addSpriteLayerMappingForAllUsers(String itemType, String itemId, String layerPath) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        String userId = userDoc.id;
        Map<String, dynamic> updateData = {};

        switch (itemType) {
          case 'weapon':
            updateData = {'weaponLayers.$itemId': layerPath};
            break;
          case 'armor':
            updateData = {'armorLayers.$itemId': layerPath};
            break;
          case 'cosmetic':
            updateData = {'cosmeticLayers.$itemId': layerPath};
            break;
          default:
            throw Exception('Invalid item type');
        }

        // Update in Firestore
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('avatar')
            .doc('layers')
            .update(updateData);
      }

      print('Added $itemType layer mapping for item $itemId to all users');
    } catch (e) {
      print('Error adding sprite layer mapping for all users: $e');
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'mythic':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Extension to add the sword icon (you may need to create a custom icon or use an image)
extension CustomIcons on Icons {
  static const IconData sword = IconData(0xe5e8, fontFamily: 'MaterialIcons');
}

class Avatar {
  final String baseSprite;
  final Map<String, String> weaponSprites;
  final Map<String, String> armorSprites;
  final Map<String, String> cosmeticSprites;

  Avatar({
    required this.baseSprite,
    required this.weaponSprites,
    required this.armorSprites,
    required this.cosmeticSprites,
  });

  static Avatar fromFirestore(Map<String, dynamic> data) {
    return Avatar(
      baseSprite: data['baseSprite'] ?? 'assets/images/sprites/avatar/default_avatar.png',
      weaponSprites: Map<String, String>.from(data['weaponSprites'] ?? {}),
      armorSprites: Map<String, String>.from(data['armorSprites'] ?? {}),
      cosmeticSprites: Map<String, String>.from(data['cosmeticSprites'] ?? {}),
    );
  }
}

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
              ),
            ),

            // Armor layer
            if (armorLayer != null)
              Positioned.fill(
                child: Image.asset(
                  armorLayer!,
                  fit: BoxFit.contain,
                ),
              ),

            // Weapon layer
            if (weaponLayer != null)
              Positioned.fill(
                child: Image.asset(
                  weaponLayer!,
                  fit: BoxFit.contain,
                ),
              ),

            // Cosmetic layer (shown on top of everything)
            if (cosmeticLayer != null)
              Positioned.fill(
                child: Image.asset(
                  cosmeticLayer!,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}