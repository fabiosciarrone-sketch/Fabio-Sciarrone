import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'community_locali_screen.dart';
import 'subscription_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Lista delle schermate collegate alla barra in basso
  final List<Widget> _screens = [
    const HomeScreen(), // 0: Intorno
    const ChatListScreen(), // 1: Chat
    const CommunityLocaliScreen(), // 2: Community

    const SubscriptionScreen(), // 4: Premium / Abbonamento
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        type:
            BottomNavigationBarType.fixed, // Obbligatorio con più di 3 elementi
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Intorno',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Premium',
          ),
        ],
      ),
    );
  }
}
