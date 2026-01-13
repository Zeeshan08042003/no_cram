import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionController extends GetxController {
  static const String _publicSdkKey = "goog_KKCHtzgQStGwRklQpABOAZWTTAq";

  final RxBool isInitialized = false.obs;
  final RxBool isLoading = false.obs;
  final Rx<Offerings?> offerings = Rx<Offerings?>(null);

  /// Call this once after user login
  Future<void> init(String userId) async {
    try {
      await Purchases.configure(
        PurchasesConfiguration(_publicSdkKey)
          ..appUserID = userId,
      );

      await _fetchOfferings();
      isInitialized.value = true;
    } catch (e) {
      print("RevenueCat init error: $e");
    }
  }

  /// Fetch available offerings (credit packs)
  Future<void> _fetchOfferings() async {
    try {
      offerings.value = await Purchases.getOfferings();
    } catch (e) {
      print("Failed to fetch offerings: $e");
    }
  }

  /// Purchase 20 credits ($1)
  Future<void> purchaseCredits20() async {
    try {
      isLoading.value = true;

      final currentOffering = offerings.value?.current;
      if (currentOffering == null) {
        throw Exception("No offering available");
      }

      final Package package = currentOffering.availablePackages.first;

      await Purchases.purchasePackage(package);

      /// IMPORTANT:
      /// Do NOT store credits here permanently
      /// Instead:
      /// 1. Notify backend OR
      /// 2. Update local credits temporarily
      ///
      /// Example:
      /// creditController.addCredits(20);

    } on PurchasesErrorCode catch (e) {
      print("Purchase error: $e");
    } catch (e) {
      print("Unknown purchase error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Restore purchases (mainly useful if user reinstalls app)
  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
      // Backend should re-sync credits via webhook if needed
    } catch (e) {
      print("Restore failed: $e");
    }
  }
}
