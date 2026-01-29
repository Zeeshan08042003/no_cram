---
description: Setup and configure RevenueCat credit-based subscription system
---

# RevenueCat Credit Subscription System

This workflow documents the credit-based subscription system implemented in NoCram.

## Architecture Overview

### Controllers

| Controller | File | Purpose |
|------------|------|---------|
| `CreditController` | `lib/controllers/credit_controller.dart` | Manages user credits, consumption, real-time balance, and UI dialogs |
| `SubscriptionController` | `lib/controllers/subscription_controller.dart` | Handles RevenueCat purchases, offerings, and purchase flow |

### Key Features

- **Real-time Credit Balance**: Credits sync in real-time from Firestore
- **Credit Consumption**: 1 credit per search (all modes)
- **Free Credits**: 20 credits on signup
- **Purchase**: $0.99 = 20 credits
- **No Expiry**: Credits never expire

## Firebase Remote Config Keys

Add these keys to Firebase Remote Config for RevenueCat API keys:

```
revenuecat_ios_key      - iOS RevenueCat public SDK key
revenuecat_android_key  - Android RevenueCat public SDK key
```

## RevenueCat Dashboard Setup

1. **Create Products** in App Store Connect / Google Play Console:
   - Product ID: `nocram_credits_20` (consumable)
   - Price: $0.99

2. **Configure in RevenueCat**:
   - Add the product
   - Create an Offering
   - Add a Package with the product

3. **Set Entitlements** (optional for consumables)

## Firestore Collections

### `user_credits` Collection
```json
{
  "id": "credit_doc_id",
  "userId": "user_uid",
  "totalCreditsEarned": 20,
  "remainingCredits": 20,
  "usedCredits": 0,
  "freeCreditsGranted": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `purchase_history` Collection (for analytics)
```json
{
  "id": "purchase_id",
  "userId": "user_uid",
  "productId": "nocram_credits_20",
  "credits": 20,
  "price": 0.99,
  "priceString": "$0.99",
  "currency": "USD",
  "platform": "ios|android",
  "purchasedAt": "timestamp"
}
```

## UI Components

| Widget | File | Description |
|--------|------|-------------|
| `CreditBalanceWidget` | `lib/services/widgets/credit_balance_widget.dart` | Compact credit display for app bars |
| `CreditBalanceCard` | `lib/services/widgets/credit_balance_widget.dart` | Full credit card for profile screen |
| `BuyCreditsBottomSheet` | `lib/controllers/credit_controller.dart` | Purchase flow bottom sheet |

## Integration Points

### Credit Check Before Search
Location: `lib/controllers/chat_controller.dart` → `sendMessage()`

```dart
final creditController = Get.find<CreditController>();
final hasCredits = await creditController.checkAndConsumeCredit();
if (!hasCredits) return; // Insufficient credits dialog shown
```

### Credit Display
Location: `lib/screens/chat_screen.dart` → Top app bar

```dart
const CreditBalanceWidget(compact: true)
```

### Profile Credit Card
Location: `lib/screens/profile_screen.dart`

```dart
const CreditBalanceCard()
```

## Testing

1. **Test with sandbox accounts** on iOS/Android
2. Verify credits are granted after purchase
3. Test insufficient credits flow
4. Test credit consumption on search

## Future Enhancements

- [ ] Add more credit tiers (50, 100 credits)
- [ ] Mode-based pricing (e.g., illustrations cost more)
- [ ] Credit transaction history screen
- [ ] Promotional credit codes
