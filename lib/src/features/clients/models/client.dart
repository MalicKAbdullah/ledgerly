import 'package:flutter/foundation.dart';

/// A client the freelancer bills.
@immutable
final class Client {
  const Client({
    required this.id,
    required this.name,
    this.company = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      name: json['name'] as String,
      company: json['company'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String name;
  final String company;
  final String email;
  final String address;
  final String notes;
  final DateTime createdAt;

  /// True when [query] matches name, company, or email (case-insensitive).
  bool matches(String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        company.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q);
  }

  Client copyWith({
    String? name,
    String? company,
    String? email,
    String? address,
    String? notes,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'company': company,
    'email': email,
    'address': address,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };
}
