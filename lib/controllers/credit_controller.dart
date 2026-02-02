import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fb_user_credit_model.dart';
import 'subscription_controller.dart';

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
  StreamSubscription<DocumentSnapshot>? _creditSubscription;

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
        print('[CREDITS] No credit document found for user');
        userCredits.value = null;
      }
    }, onError: (error) {
      print('[CREDITS] Stream error: $error');
    }) as StreamSubscription<DocumentSnapshot<Object?>>?;
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
          print('[CREDITS] No credit document found, cannot add credits');
          return false;
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

  // ==================== UI DIALOGS ====================

  /// Show insufficient credits dialog with option to buy
  void _showInsufficientCreditsDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.token_outlined,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Out of Credits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need credits to continue searching.',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.2),
                    Colors.blue.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '20 Credits',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Only \$0.99',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Later',
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              showBuyCreditsSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Buy Credits'),
          ),
        ],
      ),
      barrierDismissible: true,
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
            '1 credit = 1 search',
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
            onTap: () => _handlePurchase(context),
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
          
          const SizedBox(height: 16),
          
          // Restore purchases
          TextButton(
            onPressed: () => _handleRestore(context),
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  void _handlePurchase(BuildContext context) async {
    Get.back(); // Close sheet
    
    // Get SubscriptionController and trigger purchase
    try {
      final subscriptionController = Get.find<SubscriptionController>();
      await subscriptionController.purchaseCredits();
    } catch (e) {
      print('[PURCHASE] Error: $e');
      Get.snackbar(
        'Purchase Failed',
        'Unable to complete purchase. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  void _handleRestore(BuildContext context) async {
    Get.back(); // Close sheet first for better UX
    
    try {
      // Add 20 credits on restore for testing
      final creditController = Get.find<CreditController>();
      final success = await creditController.addCreditsAfterPurchase(20);
      
      if (success) {
        Get.snackbar(
          '🎉 Restore Complete',
          'Your 20 credits have been restored! Balance: ${creditController.remainingCredits}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Restore Failed',
          'Unable to add credits. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('[RESTORE] Error: $e');
      Get.snackbar(
        'Restore Failed',
        'Unable to restore purchases',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
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
