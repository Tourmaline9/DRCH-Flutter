import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'nearby_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'verify_screen.dart';

final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  BottomNavigationBarItem _navItem(IconData icon, String label, bool selected) {
    return BottomNavigationBarItem(
      label: label,
      icon: AnimatedScale(
        scale: selected ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(mainTabIndexProvider);
    final screens = [
      const HomeScreen(),
      const NearbyScreen(),
      ReportScreen(
        onReportSubmitted: () => ref.read(mainTabIndexProvider.notifier).state = 3,
      ),
      const VerifyScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'DRCH',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (i) => ref.read(mainTabIndexProvider.notifier).state = i,
        items: [
          _navItem(Icons.home, 'Home', index == 0),
          _navItem(Icons.map, 'Nearby', index == 1),
          _navItem(Icons.add_circle, 'Report', index == 2),
          _navItem(Icons.verified, 'Verify', index == 3),
        ],
      ),
    );
  }
}
