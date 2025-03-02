import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../models/user_profile.dart';

extension StringExtension on String {
  String capitalize() {
    return this[0].toUpperCase() + substring(1);
  }
}

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;

  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Logger? logger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _logger = logger ?? Logger();

  CollectionReference get _usersCollection => _firestore.collection('users');

  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromFirestore(
            doc.data()! as Map<String, dynamic>, doc.id);
      }

      final newProfile = UserProfile.create(
        id: currentUser.uid,
        email: currentUser.email ?? '',
        name: currentUser.displayName ??
            (currentUser.email?.split('@')[0].capitalize() ?? 'User'),
        photoUrl: currentUser.photoURL,
      );

      await saveUserProfile(newProfile);
      return newProfile;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _usersCollection.doc(profile.id).set(
            profile.toFirestore(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to save user profile. Please try again.');
    }
  }

  Future<void> updateUserProfile({
    required String name,
    String? photoUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userData = {
        'name': name,
      };

      if (photoUrl != null) {
        userData['photoUrl'] = photoUrl;
      }

      await _usersCollection.doc(currentUser.uid).update(userData);
    } catch (e) {
      throw Exception('Failed to update user profile. Please try again.');
    }
  }

  Future<List<UserProfile>> searchUsersByEmail(String email) async {
    try {
      if (email.isEmpty) return [];

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to search');
      }

      final query = await _usersCollection
          .where('email', isGreaterThanOrEqualTo: email.toLowerCase())
          .where('email', isLessThanOrEqualTo: '${email.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      return query.docs
          .map((doc) => UserProfile.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .where((profile) => profile.id != currentUser.uid)
          .toList();
    } catch (e) {
      print('User search error: $e');

      return [];
    }
  }

  Future<UserProfile?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromFirestore(
            doc.data()! as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<UserProfile?> getUserByEmail(String email) async {
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return UserProfile.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
