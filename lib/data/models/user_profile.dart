import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile extends Equatable {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? photoUrl;

  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.photoUrl,
  });

  factory UserProfile.create({
    required String id,
    required String email,
    required String name,
    String? photoUrl,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name,
      createdAt: DateTime.now(),
      photoUrl: photoUrl,
    );
  }

  UserProfile copyWith({
    String? name,
    String? photoUrl,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name ?? this.name,
      createdAt: createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'photoUrl': photoUrl,
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String id) {
    return UserProfile(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      photoUrl: data['photoUrl'],
    );
  }

  @override
  List<Object?> get props => [id, email, name, createdAt, photoUrl];
}
