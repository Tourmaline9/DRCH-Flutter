import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  bool _uploading = false;

  String _roleLabel(String role) {
    switch (role) {
      case 'ngo':
        return 'NGO';
      case 'govt_authority':
        return 'Govt authority';
      default:
        return 'Community / Volunteer';
    }
  }

  Future<void> _uploadAadhar() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (picked == null) return;

      setState(() => _uploading = true);

      final bytes = await File(picked.path).readAsBytes();
      final base64 = base64Encode(bytes);

      await _db.collection('users').doc(user.uid).update({
        'aadharImage': base64,
        'aadharSubmitted': true,
        'aadharStatus': 'pending',
        'aadharUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aadhar uploaded. Verification pending.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload Aadhar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = (data['name'] ?? user.email ?? 'Unknown user').toString();
          final role = (data['role'] ?? 'community').toString();
          final roleText = _roleLabel(role);
          final aadharSubmitted = data['aadharSubmitted'] == true;
          final aadharStatus = (data['aadharStatus'] ?? 'not_submitted').toString();

          Color statusColor;
          String statusText;

          switch (aadharStatus) {
            case 'approved':
              statusColor = Colors.green;
              statusText = 'Identity verified';
              break;
            case 'pending':
              statusColor = Colors.orange;
              statusText = 'Verification pending';
              break;
            default:
              statusColor = Colors.red;
              statusText = 'Upload Aadhar to verify';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Type: $roleText'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _uploadAadhar,
                icon: _uploading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.badge_outlined),
                label: Text(aadharSubmitted ? 'Re-upload Aadhar' : 'Upload Aadhar'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aadhar upload is required for profile verification. Name and user type are shown in your profile.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }
}