import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fb_user_credit_model.dart';

/// Controller for managing user credits
/// Handles real-time credit balance, consumption, and insufficient credit states
class CreditController extends GetxController {
  static CreditController get to => Get.find<CreditController>();

  // ==================== OBSERVABLES ====================
  
  /// Current user's credit data
  final Rx<FBUserCreditsModel?> userCredits = Rx<FBUserCreditsModel?>(null);
  
  /// Loading state for credit operations
  final RxBool isLoading = false.obs;
  
  /// Stream subscription for real-time credit updates
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _creditSubscription;

  // ==================== GETTERS ====================
  
  /// Get remaining credits (safe getter)
  int get remainingCredits => userCredits.value?.remainingCredits ?? 0;
  
  /// Get total credits earned
  int get totalCreditsEarned => userCredits.value?.totalCreditsEarned ?? 0;
  
  /// Get used credits
  int get usedCredits => userCredits.value?.usedCredits ?? 0;
  
  /// Check if user has any credits
  bool get hasCredits => remainingCredits > 0;
  
  /// Check if user has enough credits for a search (1 credit)
  bool get canSearch => remainingCredits >= 1;

  // ==================== INITIALIZATION ====================

  @override
  void onInit() {
    super.onInit();
    _initCreditStream();
  }

  @override
  void onClose() {
    _creditSubscription?.cancel();
    super.onClose();
  }

  /// Initialize real-time credit stream for the logged-in user
  Future<void> _initCreditStream() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId == null || userId.isEmpty) {
      print('[CREDITS] No user ID found, skipping credit stream init');
      return;
    }
    
    listenToCredits(userId);
  }

  /// Start listening to user's credit document in Firestore
  void listenToCredits(String userId) {
    _creditSubscription?.cancel();
    
    print('[CREDITS] Starting listener for user: $userId');
    
    _creditSubscription = FirebaseFirestore.instance
        .collection('user_credits')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        userCredits.value = FBUserCreditsModel.fromFirestore(snapshot.docs.first);
        print('[CREDITS] Updated: ${userCredits.value?.remainingCredits} remaining');
      } else {
        print('[CREDITS] No credit document found for user: $userId');
        userCredits.value = null;
      }
    }, onError: (error) {
      print('[CREDITS] Stream error: $error');
    });
  }

  /// Refresh credits manually (useful after purchase)
  Future<void> refreshCredits() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_credits')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        userCredits.value = FBUserCreditsModel.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      print('[CREDITS] Refresh error: $e');
    }
  }

  // ==================== CREDIT CONSUMPTION ====================

  /// Check if user can perform a search (has at least 1 credit)
  /// Returns true if allowed, false if not (and shows dialog)
  Future<bool> checkAndConsumeCredit() async {
    if (!canSearch) {
      _showInsufficientCreditsDialog();
      return false;
    }
    
    // Consume credit
    final success = await _consumeCredit();
    
    if (!success) {
      _showInsufficientCreditsDialog();
      return false;
    }
    
    return true;
  }

  /// Internal method to consume 1 credit via Firestore transaction
  Future<bool> _consumeCredit() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId == null) return false;
    
    // Get the credit document ID
    final creditDocId = userCredits.value?.id;
    if (creditDocId == null) return false;
    
    try {
      final ref = FirebaseFirestore.instance
          .collection('user_credits')
          .doc(creditDocId);
      
      return await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        
        if (!snapshot.exists) return false;
        
        final remaining = snapshot.data()?['remainingCredits'] as int? ?? 0;
        final used = snapshot.data()?['usedCredits'] as int? ?? 0;
        
        if (remaining <= 0) return false;
        
        tx.update(ref, {
          'remainingCredits': remaining - 1,
          'usedCredits': used + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('[CREDITS] Consumed 1 credit. Remaining: ${remaining - 1}');
        return true;
      });
    } catch (e) {
      print('[CREDITS] Consume error: $e');
      return false;
    }
  }

  // ==================== ADD CREDITS ====================

  /// Add credits after a successful purchase
  Future<bool> addCreditsAfterPurchase(int credits) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId == null || userId.isEmpty) {
      print('[CREDITS] No user ID found');
      return false;
    }
    
    try {
      // Try to get credit doc ID from cache first
      String? creditDocId = userCredits.value?.id;
      
      // If not cached, fetch from Firestore
      if (creditDocId == null) {
        print('[CREDITS] Fetching credit doc from Firestore...');
        final snapshot = await FirebaseFirestore.instance
            .collection('user_credits')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        
        if (snapshot.docs.isEmpty) {
          // 🆕 Create credit document if it doesn't exist
          print('[CREDITS] No credit document found, creating one...');
          creditDocId = await _createCreditDocument(userId, credits);
          if (creditDocId == null) {
            return false;
          }
          // Start listening to the new document
          listenToCredits(userId);
          return true;
        }
        
        creditDocId = snapshot.docs.first.id;
        // Update cache
        userCredits.value = FBUserCreditsModel.fromFirestore(snapshot.docs.first);
      }
      
      final ref = FirebaseFirestore.instance
          .collection('user_credits')
          .doc(creditDocId);
      
      await ref.update({
        'totalCreditsEarned': FieldValue.increment(credits),
        'remainingCredits': FieldValue.increment(credits),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh the cache
      await refreshCredits();
      
      print('[CREDITS] Added $credits credits. New balance: ${userCredits.value?.remainingCredits}');
      
      return true;
    } catch (e) {
      print('[CREDITS] Add credits error: $e');
      return false;
    }
  }

  /// Create a new credit document for a user
  Future<String?> _createCreditDocument(String userId, int initialCredits) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('user_credits').doc();
      
      await docRef.set({
        'userId': userId,
        'totalCreditsEarned': initialCredits,
        'remainingCredits': initialCredits,
        'usedCredits': 0,
        'freeCreditsGranted': false, // This is a purchased credit
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('[CREDITS] Created new credit document: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('[CREDITS] Error creating credit document: $e');
      return null;
    }
  }

  // ==================== UI DIALOGS ====================

  /// Show insufficient credits bottom sheet with option to buy
  void _showInsufficientCreditsDialog() {
    showCreditsExhaustedSheet();
  }
  
  /// Show credits exhausted bottom sheet - called when user tries to submit with no credits
  void showCreditsExhaustedSheet() {
    Get.bottomSheet(
      const CreditsExhaustedBottomSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  /// Show buy credits bottom sheet
  void showBuyCreditsSheet() {
    Get.bottomSheet(
      const BuyCreditsBottomSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}

// ==================== BUY CREDITS BOTTOM SHEET ====================

class BuyCreditsBottomSheet extends StatelessWidget {
  const BuyCreditsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          const Text(
            'Buy Credits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '1 credit = 1 question',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Credit Package Card
          _CreditPackageCard(
            credits: 20,
            price: '\$0.99',
            onTap: () => _showComingSoon(context),
          ),
          
          const SizedBox(height: 24),
          
          // Current balance
          GetBuilder<CreditController>(
            builder: (controller) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Balance: ${controller.remainingCredits} credits',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    Get.back(); // Close sheet
    
    Get.snackbar(
      '🚀 Coming Soon!',
      'In-app purchases will be available soon. Stay tuned!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.purple.shade600,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.rocket_launch, color: Colors.white),
    );
  }
}

// ==================== CREDITS EXHAUSTED BOTTOM SHEET ====================

/// Bottom sheet shown when user tries to submit a question but has no credits
class CreditsExhaustedBottomSheet extends StatelessWidget {
  const CreditsExhaustedBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Icon and Title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.token_outlined,
              color: Colors.orange,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Out of Credits!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You\'ve used all your credits. Each question requires 1 credit to process.',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          
          // Credits summary
          GetX<CreditController>(
            builder: (controller) {
              final total = controller.totalCreditsEarned;
              final used = controller.usedCredits;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withOpacity(0.2),
                      Colors.blue.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCreditStat('Total Earned', total, Colors.blue),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade700,
                    ),
                    _buildCreditStat('Used', used, Colors.orange),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade700,
                    ),
                    _buildCreditStat('Remaining', 0, Colors.red),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 28),
          
          // Buy Credits Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade600,
                  Colors.blue.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _handleBuyCredits(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Buy More Credits',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Maybe Later Button
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
  
  Widget _buildCreditStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  void _handleBuyCredits() {
    Get.back(); // Close this sheet
    
    // Show "Coming Soon" snackbar
    Get.snackbar(
      '🚀 Coming Soon!',
      'In-app purchases will be available soon. Stay tuned!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.purple.shade600,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.rocket_launch, color: Colors.white),
    );
  }
}

class _CreditPackageCard extends StatelessWidget {
  final int credits;
  final String price;
  final VoidCallback onTap;

  const _CreditPackageCard({
    required this.credits,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade700,
              Colors.blue.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.token,
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  '$credits',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Credits',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                price,
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

