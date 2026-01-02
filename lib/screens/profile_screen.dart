import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';

import '../utils/constants.dart';

void main() => runApp(const MaterialApp(home: ProfileScreen()));

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  bool _areNotificationsEnabled = true;
  var userModel = UserModel();
  var firestore = FirestoreService();



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }


  void init() async {
    final pref = await SharedPreferences.getInstance();
    final userId = pref.getString('userId');

    if (userId == null) return;

    firestore.getUserDetails(userId).listen((user) {
      setState(() {
        userModel = user;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showLogoutDialog(context);
            },
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 30),
            // Stats Row
            // _buildStatsRow(),
            // const SizedBox(height: 30),
            // Preferences Section
            _buildSectionTitle("PREFERENCES"),
            _buildPreferencesList(),
            const SizedBox(height: 30),
            // Account & Support Section
            _buildSectionTitle("ACCOUNT & SUPPORT"),
            _buildAccountSupportList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper for Profile Header
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              // Replace with your actual image asset
              child: Icon(Icons.person, size: 60, color: Colors.grey),
            ),
            // Positioned(
            //   bottom: 0,
            //   right: 0,
            //   child: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       color: const Color(0xFF00BFFF),
            //       shape: BoxShape.circle,
            //       border: Border.all(color: Colors.white, width: 3),
            //     ),
            //     child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            //   ),
            // ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          userModel.firstName??'',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Text(
          userModel.email??'',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 3,
          ),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text("Edit Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Helper for Stats Row
  // Widget _buildStatsRow() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 20),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         _buildStatCard(icon: Icons.chat_bubble, value: "124", label: "QUESTIONS", color: Colors.blue),
  //         _buildStatCard(icon: Icons.local_fire_department, value: "7 Days", label: "STREAK", color: Colors.orange),
  //       ],
  //     ),
  //   );
  // }

  // Helper for an individual Stat Card
  Widget _buildStatCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Helper for Section Titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
    );
  }

  // Helper for Preferences List
  Widget _buildPreferencesList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.notifications, color: Colors.blue)),
            title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
            value: _areNotificationsEnabled,
            onChanged: (val) => setState(() => _areNotificationsEnabled = val),
            activeColor: const Color(0xFF00BFFF),
          ),
        ],
      ),
    );
  }

  // Helper for Account & Support List
  Widget _buildAccountSupportList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          _buildListTile(icon: Icons.delete, title: "Clear History", color: Colors.red, onTap: () {}),
          const Divider(height: 1, indent: 70),
          _buildListTile(icon: Icons.info, title: "About Teach Me", color: Colors.grey, onTap: () {}),
          const Divider(height: 1, indent: 70),
          _buildListTile(icon: Icons.lock, title: "Privacy Policy", color: Colors.grey, onTap: () {}),
        ],
      ),
    );
  }

  // Helper for a generic ListTile
  Widget _buildListTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}