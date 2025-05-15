import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // Check if user is logged in
  bool get isUserLoggedIn => _auth.currentUser != null;

  // Check if user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Save user settings to Firestore
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'settings': settings,
    });
  }

  // Load user settings from Firestore
  Future<Map<String, dynamic>?> loadUserSettings() async {
    if (userId == null) return null;

    final docSnapshot = await _firestore.collection('users').doc(userId).get();
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('settings')) {
      return docSnapshot.data()!['settings'] as Map<String, dynamic>;
    }
    return null;
  }

  // Reset user account data
  Future<void> resetUserData() async {
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'battlesWon': 0,
      'class': _firestore.collection('classes').doc('def_class'),
      'gems': 0,
      'gold': 0,
      'health': 100,
      'mana': 50,
      'userLevel': 1,
      'skills': {
        'skill1': _firestore.collection('skills').doc('yAcWu8PcE5BTHSYwj3xw'),
        'skill2': _firestore.collection('skills').doc('i1esz97fcNqCKLzZE6Ao')
      },
      'xp': 0,
      'maxHealth': 100,
      'maxMana': 50,
    });

    // Remove lastBattleTimestamp field if it exists
    final docRef = _firestore.collection('users').doc(userId);
    final doc = await docRef.get();
    if (doc.exists && doc.data()!.containsKey('lastBattleTimestamp')) {
      await docRef.update({
        'lastBattleTimestamp': FieldValue.delete(),
      });
    }
  }

  // Delete specified subcollections from user document
  Future<void> deleteUserSubcollections() async {
    if (userId == null) return;

    final subcollections = [
      'battleHistory',
      'inventory',
      'purchaseHistory',
      'tasks'
    ];

    for (final subcollection in subcollections) {
      await _deleteSubcollection('users/$userId/$subcollection');
    }
  }

  // Helper method to delete a subcollection
  Future<void> _deleteSubcollection(String path) async {
    final collection = await _firestore.collection(path).get();

    final batch = _firestore.batch();
    for (final doc in collection.docs) {
      batch.delete(doc.reference);
    }

    if (collection.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Update the 'stats' subcollection with default values
  Future<void> resetUserStats() async {
    if (userId == null) return;

    // Set base stats
    await _firestore.collection('users/$userId/stats').doc('base').set({
      'strength': 1,
      'intelligence': 1,
      'vitality': 1,
      'wisdom': 1,
    });

    // Set battle stats
    await _firestore.collection('users/$userId/stats').doc('battle').set({
      'phyatk': 10,
      'phydef': 10,
      'magatk': 10,
      'magdef': 10,
    });
  }

  // Send email verification
  // Add this method to your FirebaseService class
  // Add this method to your FirebaseService class
  Future<void> sendEmailVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        // Set language code explicitly before sending email verification
        await FirebaseAuth.instance.setLanguageCode('en');

        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Error sending verification email: $e');
      throw e;
    }
  }
  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }
}