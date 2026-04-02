import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final profileUploadingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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

  Future<void> _uploadAadhar(BuildContext context, WidgetRef ref) async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final picker = ImagePicker();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (picked == null) return;

      ref.read(profileUploadingProvider.notifier).state = true;
      final bytes = await File(picked.path).readAsBytes();
      final base64 = base64Encode(bytes);

      await db.collection('users').doc(user.uid).update({
        'aadharImage': base64,
        'aadharSubmitted': true,
        'aadharStatus': 'pending',
        'aadharUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aadhar uploaded. Verification pending.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload Aadhar: $e')),
        );
      }
    } finally {
      ref.read(profileUploadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final db = FirebaseFirestore.instance;
    final uploading = ref.watch(profileUploadingProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = (data['name'] ?? user.email ?? 'Unknown user').toString();
          final roleText = _roleLabel((data['role'] ?? 'community').toString());
          final aadharSubmitted = data['aadharSubmitted'] == true;
          final aadharStatus = (data['aadharStatus'] ?? 'not_submitted').toString();

          Color statusColor = Colors.red;
          String statusText = 'Upload Aadhar to verify';
          if (aadharStatus == 'approved') {
            statusColor = Colors.green;
            statusText = 'Identity verified';
          } else if (aadharStatus == 'pending') {
            statusColor = Colors.orange;
            statusText = 'Verification pending';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: uploading ? null : () => _uploadAadhar(context, ref),
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.badge_outlined),
                label: Text(aadharSubmitted ? 'Re-upload Aadhar' : 'Upload Aadhar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
