import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uid/uid.dart';
import 'credit_controller.dart';

class SubscriptionController extends GetxController {
  // ==================== CONSTANTS ====================
  
  /// Credits awarded per purchase
  static const int creditsPerPurchase = 20;
  
  /// Default fallback SDK keys (will be overridden by Remote Config)
  static const String _defaultAndroidKey = "goog_KKCHtzgQStGwRklQpABOAZWTTAq";
  static const String _defaultIosKey = ""; // Will be set via Remote Config

  // ==================== OBSERVABLES ====================
  
  final RxBool isInitialized = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isPurchasing = false.obs;
  final Rx<Offerings?> offerings = Rx<Offerings?>(null);
  final RxString errorMessage = ''.obs;

  // ==================== GETTERS ====================
  
  /// Get the appropriate SDK key based on platform
  String get _sdkKey {
    final remoteConfig = FirebaseRemoteConfig.instance;
    
    if (Platform.isIOS) {
      final iosKey = remoteConfig.getString('revenuecat_ios_key');
      return iosKey.isNotEmpty ? iosKey : _defaultIosKey;
    } else {
      final androidKey = remoteConfig.getString('revenuecat_android_key');
      return androidKey.isNotEmpty ? androidKey : _defaultAndroidKey;
    }
  }

  /// Check if offerings are available
  bool get hasOfferings => offerings.value?.current != null;

  /// Get the current offering's first package (our 20 credit pack)
  Package? get creditPackage => offerings.value?.current?.availablePackages.firstOrNull;

  /// Get the price string for display
  String get priceString => creditPackage?.storeProduct.priceString ?? '\$0.99';

  // ==================== INITIALIZATION ====================

  /// Initialize RevenueCat with user ID
  /// Call this once after user login
  Future<void> init(String userId) async {
    if (userId.isEmpty) {
      print('[REVENUECAT] Empty userId, skipping init');
      return;
    }

    try {
      final sdkKey = _sdkKey;
      
      if (sdkKey.isEmpty) {
        print('[REVENUECAT] No SDK key available for this platform');
        return;
      }

      await Purchases.configure(
        PurchasesConfiguration(sdkKey)..appUserID = userId,
      );

      // Set up purchase listener
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      await _fetchOfferings();
      isInitialized.value = true;
      
      print('[REVENUECAT] Initialized for user: $userId');
    } catch (e) {
      print('[REVENUECAT] Init error: $e');
      errorMessage.value = 'Failed to initialize purchases';
    }
  }

  /// Handle customer info updates (useful for subscription status changes)
  void _handleCustomerInfoUpdate(CustomerInfo info) {
    print('[REVENUECAT] Customer info updated');
    // For consumable credits, we handle this in purchaseCredits()
  }

  /// Fetch available offerings (credit packs)
  Future<void> _fetchOfferings() async {
    try {
      offerings.value = await Purchases.getOfferings();
      
      if (offerings.value?.current != null) {
        print('[REVENUECAT] Offerings loaded: ${offerings.value!.current!.availablePackages.length} packages');
      } else {
        print('[REVENUECAT] No current offering available');
      }
    } catch (e) {
      print('[REVENUECAT] Failed to fetch offerings: $e');
    }
  }

  // ==================== PURCHASE FLOW ====================

  /// Purchase 20 credits
  /// This is the main purchase method called from the UI
  Future<bool> purchaseCredits() async {
    if (isPurchasing.value) {
      print('[PURCHASE] Already processing a purchase');
      return false;
    }

    try {
      isPurchasing.value = true;
      isLoading.value = true;
      errorMessage.value = '';

      // Get the package
      final package = creditPackage;
      if (package == null) {
        throw Exception('No credit package available. Please try again later.');
      }

      print('[PURCHASE] Starting purchase for: ${package.storeProduct.identifier}');

      // Make the purchase using the newer API
      final purchaseResult = await Purchases.purchasePackage(package);
      
      print('[PURCHASE] Purchase successful!');

      // Add credits to user's account
      await _handleSuccessfulPurchase(purchaseResult, package);

      return true;

    } on PurchasesErrorCode catch (e) {
      _handlePurchaseError(e);
      return false;
    } catch (e) {
      print('[PURCHASE] Unknown error: $e');
      errorMessage.value = e.toString();
      
      Get.snackbar(
        'Purchase Failed',
        'An unexpected error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isPurchasing.value = false;
      isLoading.value = false;
    }
  }

  /// Handle successful purchase - add credits and log transaction
  Future<void> _handleSuccessfulPurchase(dynamic purchaseResult, Package package) async {
    try {
      // Get CreditController and add credits
      final creditController = Get.find<CreditController>();
      await creditController.addCreditsAfterPurchase(creditsPerPurchase);

      // Log purchase to Firestore for records
      await _logPurchaseToFirestore(package);

      print('[PURCHASE] Credits added successfully!');
    } catch (e) {
      print('[PURCHASE] Error adding credits: $e');
      // Even if logging fails, the user should have received their credits
      // via the addCreditsAfterPurchase call
    }
  }

  /// Log purchase to Firestore for analytics/records
  Future<void> _logPurchaseToFirestore(Package package) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null) return;

      final purchaseId = UId.getId();
      
      await FirebaseFirestore.instance
          .collection('purchase_history')
          .doc(purchaseId)
          .set({
        'id': purchaseId,
        'userId': userId,
        'productId': package.storeProduct.identifier,
        'credits': creditsPerPurchase,
        'price': package.storeProduct.price,
        'priceString': package.storeProduct.priceString,
        'currency': package.storeProduct.currencyCode,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'purchasedAt': FieldValue.serverTimestamp(),
      });

      print('[PURCHASE] Logged to Firestore: $purchaseId');
    } catch (e) {
      print('[PURCHASE] Failed to log purchase: $e');
      // Non-critical error, don't throw
    }
  }

  /// Handle RevenueCat specific purchase errors
  void _handlePurchaseError(PurchasesErrorCode error) {
    print('[PURCHASE] RevenueCat error: $error');
    
    String message;
    bool showSnackbar = true;

    switch (error) {
      case PurchasesErrorCode.purchaseCancelledError:
        message = 'Purchase was cancelled';
        showSnackbar = false; // User cancelled, no need to show error
        break;
      case PurchasesErrorCode.storeProblemError:
        message = 'There was a problem with the app store. Please try again.';
        break;
      case PurchasesErrorCode.purchaseNotAllowedError:
        message = 'Purchases are not allowed on this device.';
        break;
      case PurchasesErrorCode.purchaseInvalidError:
        message = 'The purchase was invalid. Please try again.';
        break;
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        message = 'This product is not available for purchase.';
        break;
      case PurchasesErrorCode.networkError:
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = 'Purchase failed. Please try again.';
    }

    errorMessage.value = message;

    if (showSnackbar) {
      Get.snackbar(
        'Purchase Failed',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
      );
    }
  }

  // ==================== RESTORE PURCHASES ====================

  /// Restore purchases (useful if user reinstalls app)
  /// For consumable products, this mainly syncs purchase history
  Future<void> restorePurchases() async {
    try {
      isLoading.value = true;
      
      await Purchases.restorePurchases();
      
      print('[RESTORE] Purchases restored');
      
      // For consumable credits, restore doesn't add credits back
      // Credits are one-time use. This is mainly for record syncing.
      
    } catch (e) {
      print('[RESTORE] Failed: $e');
      throw e;
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== UTILITIES ====================

  /// Refresh offerings (useful if they failed to load initially)
  Future<void> refreshOfferings() async {
    await _fetchOfferings();
  }

  /// Show the buy credits bottom sheet
  void showBuyCreditsSheet() {
    try {
      final creditController = Get.find<CreditController>();
      creditController.showBuyCreditsSheet();
    } catch (e) {
      print('[SUBSCRIPTION] CreditController not found');
    }
  }
}
