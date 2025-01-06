import 'package:flutter/material.dart';
import 'package:stay_near/pages/login_page.dart';
import 'package:stay_near/services/api_service.dart';

class MyDrawer extends StatelessWidget {
  MyDrawer({
    super.key,
  });

  final ApiService _apiService = ApiService();

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final response = await _apiService.logout();
      
      if (response.success) {
        // Navigation zum Login-Screen
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Logout fehlgeschlagen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ein Fehler ist aufgetreten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 34, 34, 34),
      child: Column(
        children: [
          // Header
          DrawerHeader(
            child: Center(
              child: Text(
                "Stay Near",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          // Menüpunkte (Profile)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Profile',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    tileColor: const Color.fromARGB(255, 59, 59, 59),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    minTileHeight: 60,
                  ),
                 
                ],
              ),
            ),
          ),
          
          // Logout Button am Ende
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 40),
            child: ListTile(
              title: const Center(
                child: Text(
                  'Logout',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              tileColor: const Color.fromARGB(255, 59, 59, 59),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              onTap: () => _handleLogout(context),
            ),
          ),
        ],
      ),
    );
  }
}