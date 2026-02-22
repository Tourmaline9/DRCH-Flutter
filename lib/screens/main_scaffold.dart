import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_screen.dart';
import 'nearby_screen.dart';
import 'report_screen.dart';
import 'verify_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeScreen(),
      const NearbyScreen(),

      // 🔥 Pass callback to Report
      ReportScreen(
        onReportSubmitted: () {
          setState(() {
            _index = 3; // Go to Verify
          });
        },
      ),

      const VerifyScreen(),
    ];
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  BottomNavigationBarItem _navItem(
      IconData icon,
      String label,
      int index,
      ) {
    final bool selected = _index == index;

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
  Widget build(BuildContext context) {
    return Scaffold(
      // ================= APP BAR =================
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFD32F2F),
                Color(0xFFB71C1C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "DRCH",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      // ================= BODY =================
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),

      // ================= BOTTOM NAV =================
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: (i) {
           setState(() {
            _index = i;
          });
        },
        items: [
          _navItem(Icons.home, "Home", 0),
          _navItem(Icons.map, "Nearby", 1),
          _navItem(Icons.add_circle, "Report", 2),
          _navItem(Icons.verified, "Verify", 3),
        ],
      ),
    );
  }
}
