import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'custom_widgets.dart';


class ShopPage extends StatefulWidget {
  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected category
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['Weapons', 'Armor', 'Cosmetics'];

  // User data
  int _userGold = 0;
  int _userGems = 0;

  // Items displayed in the shop
  List<Map<String, dynamic>> _shopItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
    _loadShopItems(_categories[_selectedCategoryIndex].toLowerCase());
  }

  Future<void> _loadUserCurrency() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          setState(() {
            // Convert num to int using toInt()
            _userGold = (userDoc.data()?['gold'] ?? 0).toInt();
            _userGems = (userDoc.data()?['gems'] ?? 0).toInt();
          });
        }
      }
    } catch (e) {
      print('Error loading user currency: $e');
    }
  }

  Future<void> _loadShopItems(String category) async {



    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _shopItems = [];
        });
        return;
      }

      // Get all items in the category
      final itemsSnapshot = await _firestore.collection(category).get();

      // Get user's inventory for this category
      final userInventoryRef = _firestore.collection('users').doc(userId).collection('inventory').doc(category);
      final inventoryDoc = await userInventoryRef.get();

      // Extract the list of owned item paths
      List<String> ownedItemPaths = [];
      if (inventoryDoc.exists && inventoryDoc.data()?['items'] != null) {
        ownedItemPaths = List<String>.from(inventoryDoc.data()?['items'] ?? []);
      }

      final List<Map<String, dynamic>> items = [];

      for (var doc in itemsSnapshot.docs) {
        final data = doc.data();

        final int price = (data['price'] ?? 0).toInt();

        // Skip items with price of 0
        if (price == 0) continue;

        final itemPath = 'collection/${category}/${doc.id}';
        // Check if user owns this item
        final bool isOwned = _isItemOwned(ownedItemPaths, doc.id, category);

        items.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Item',
          'description': data['description'] ?? 'No description available',
          'price': (data['price'] ?? 0).toInt(),
          'currency': category == 'cosmetics' ? 'gems' : 'gold',
          'spritePath': data['spritePath'] ?? 'assets/images/placeholder.png',
          'phyatk': (data['phyatk'] ?? 0).toInt(),
          'phydef': (data['phydef'] ?? 0).toInt(),
          'magatk': (data['magatk'] ?? 0).toInt(),
          'magdef': (data['magdef'] ?? 0).toInt(),
          'purchased': isOwned, // Set based on ownership check
        });
      }

      setState(() {
        _shopItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading shop items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// Helper method to check if an item is owned
  bool _isItemOwned(List<String> ownedItemPaths, String itemId, String category) {
    // Check if the item path exists in the owned items list
    final String itemPath = '${category}/${itemId}';

    // Check for exact match or if the path contains the item ID
    return ownedItemPaths.any((path) =>
    path == itemPath ||
        path.endsWith('/${itemId}') ||
        path.contains(itemId)
    );
  }

  void _changeCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
    _loadShopItems(_categories[index].toLowerCase());
  }

  Future<void> _purchaseItem(Map<String, dynamic> item) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Get the price as an int
    final int itemPrice = item['price'] as int;
    final String category = _categories[_selectedCategoryIndex].toLowerCase();

    // Check if user has enough currency
    if (item['currency'] == 'gems' && _userGems < itemPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough gems to purchase this item!'))
      );
      return;
    } else if (item['currency'] == 'gold' && _userGold < itemPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough gold to purchase this item!'))
      );
      return;
    }

    try {
      // Create a transaction to update both user currency and inventory
      await _firestore.runTransaction((transaction) async {
        // Get user document reference
        final userRef = _firestore.collection('users').doc(userId);

        // Get the item reference from the collection
        final itemRef = _firestore.collection(category).doc(item['id']);

        // Update user currency
        if (item['currency'] == 'gems') {
          transaction.update(userRef, {'gems': FieldValue.increment(-itemPrice)});
        } else {
          transaction.update(userRef, {'gold': FieldValue.increment(-itemPrice)});
        }

        // Store in inventory - create an "items" array field in the user's inventory document
        final userInventoryRef = userRef.collection('inventory').doc(category);

        // Create or update the inventory document with an array of references
        transaction.set(userInventoryRef, {
          'items': FieldValue.arrayUnion([itemRef.path])
        }, SetOptions(merge: true));

        // Optionally store minimal metadata about when it was purchased
        final purchaseHistoryRef = userRef.collection('purchaseHistory').doc();
        transaction.set(purchaseHistoryRef, {
          'itemId': item['id'],
          'itemPath': itemRef.path,
          'category': category,
          'purchaseDate': FieldValue.serverTimestamp(),
          'price': itemPrice,
          'currency': item['currency']
        });
      });

      // Update local state after successful transaction
      setState(() {
        if (item['currency'] == 'gems') {
          _userGems -= itemPrice;
        } else {
          _userGold -= itemPrice;
        }

        // Update the shop items list to reflect purchase
        final index = _shopItems.indexWhere((i) => i['id'] == item['id']);
        if (index != -1) {
          _shopItems[index]['purchased'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item purchased successfully!'))
      );
    } catch (e) {
      print('Error purchasing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to purchase item. Please try again.'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Currency display
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.monetization_on, color: Colors.amber),
                SizedBox(width: 4),
                Text('$_userGold', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 16),
                Icon(Icons.diamond, color: Colors.lightBlueAccent),
                SizedBox(width: 4),
                Text('$_userGems', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Replace your category toggle with this:
          // Category toggle - centered
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center, // Changed to center alignment
            width: double.infinity,     // Ensures the container takes full width
            child: DefaultTabController(
              length: _categories.length,
              initialIndex: _selectedCategoryIndex,
              child: TabBar(
                onTap: (index) {
                  _changeCategory(index);
                },
                isScrollable: true,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                tabAlignment: TabAlignment.center, // Changed to center alignment
                padding: EdgeInsets.zero,          // Removed left padding
                tabs: _categories.map((category) =>
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          category,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                ).toList(),
              ),
            ),
          ),

          // Shop items grid
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _shopItems.isEmpty
                ? Center(child: Text('No items available in this category'))
                : GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _shopItems.length,
              itemBuilder: (context, index) {
                final item = _shopItems[index];
                return ItemCard(
                  item: item,
                  onPurchase: () => _purchaseItem(item),
                  onInfo: () => _showItemInfoDialog(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showItemInfoDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => ItemInfoDialog(
        item: item,
        onPurchase: () {
          Navigator.of(context).pop();
          _purchaseItem(item);
        },
      ),
    );
  }
}


class ItemInfoDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onPurchase;

  const ItemInfoDialog({
    required this.item,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get stats as integers
    final int phyatk = item['phyatk'] as int;
    final int phydef = item['phydef'] as int;
    final int magatk = item['magatk'] as int;
    final int magdef = item['magdef'] as int;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header panel
            Row(
              children: [
                // Item image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      item['spritePath'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          child: Icon(
                            Icons.image_not_supported,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Item name and price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            item['currency'] == 'gems'
                                ? Icons.diamond
                                : Icons.monetization_on,
                            color: item['currency'] == 'gems'
                                ? Colors.lightBlueAccent
                                : Colors.amber,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${item['price']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Divider(height: 24),

            // Middle panel - description and stats
            Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(item['description']),
                  SizedBox(height: 16),
                  Text(
                    'Stats:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Stats grid
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            if (phyatk != 0)
                              _buildStatItem(
                                context,
                                'Physical ATK',
                                phyatk,
                                Icons.fitness_center,
                              ),
                            if (phydef != 0)
                              _buildStatItem(
                                context,
                                'Physical DEF',
                                phydef,
                                Icons.shield,
                              ),
                            if (magatk != 0)
                              _buildStatItem(
                                context,
                                'Magic ATK',
                                magatk,
                                Icons.auto_fix_high,
                              ),
                            if (magdef != 0)
                              _buildStatItem(
                                context,
                                'Magic DEF',
                                magdef,
                                Icons.security,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 24),

            // Footer panel - buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                  // Will use your theme's textButtonTheme
                ),
                SizedBox(width: 16),
                if (!item['purchased'])
                  ElevatedButton(
                    onPressed: onPurchase,
                    child: Text('Buy'),
                    // Will use your theme's elevatedButtonTheme
                  )
                else
                  ElevatedButton(
                    onPressed: null,
                    child: Text('Owned'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, int value, IconData icon) {
    final theme = Theme.of(context);
    final String prefix = value > 0 ? '+' : '';

    // Use theme-appropriate colors for stats
    Color valueColor;
    if (value > 0) {
      valueColor = Colors.green[400]!;
    } else {
      valueColor = theme.colorScheme.error;
    }

    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.iconTheme.color,
          ),
          SizedBox(width: 4),
          Text('$label: '),
          Text(
            '$prefix$value',
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}