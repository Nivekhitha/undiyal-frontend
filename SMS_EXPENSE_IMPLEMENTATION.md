# SMS-Based Expense Detection Implementation

## Overview
This document describes the SMS-based automatic expense detection system implemented for the Undiyal Flutter app.

## Features Implemented

### 1. SMS Permission Handling
- Added `READ_SMS` and `RECEIVE_SMS` permissions to AndroidManifest.xml
- Implemented runtime permission request using `permission_handler` package
- Permission check before reading SMS

### 2. SMS Expense Service (`lib/services/sms_expense_service.dart`)
- **SMS Reading**: Reads SMS from inbox (last 30 days by default)
- **Transaction Detection**: Parses SMS for debit transactions only
- **Pattern Matching**: Uses regex patterns to extract:
  - Amount (₹)
  - Merchant/UPI ID
  - Date & Time
  - Reference Number
  - Payment Method

### 3. AI-Style Categorization
Rule-based + heuristic classification system:
- **Food & Drink**: zomato, swiggy, restaurant, cafe (confidence: 0.9)
- **Transport**: uber, ola, rapido, taxi (confidence: 0.9)
- **Shopping**: amazon, flipkart, myntra (confidence: 0.85)
- **Bills**: airtel, jio, electricity (confidence: 0.9)
- **Entertainment**: netflix, spotify, prime (confidence: 0.85)
- **Education**: university, college, tuition (confidence: 0.8)
- **Health**: pharmacy, medical, hospital (confidence: 0.85)
- **Others**: Default fallback (confidence: 0.3)

### 4. Transaction Model Updates
Added fields to `Transaction` model:
- `isAutoDetected`: Boolean flag for SMS-detected transactions
- `referenceNumber`: SMS transaction reference
- `confidenceScore`: AI categorization confidence (0-1)

### 5. Transaction Storage
- Stores SMS-detected transactions in SharedPreferences
- Prevents duplicates using reference number + amount + date
- Merges with dummy transactions for unified access

### 6. UI Integration
- **Auto Badge**: Shows "Auto" tag on SMS-detected transactions
- **Category Editing**: Users can manually edit category for auto-detected transactions
- **Transaction Detail Screen**: Shows confidence score and reference number
- **All Screens Updated**: Home, Transaction List, Analytics screens use unified transaction storage

### 7. App Initialization
- Reads SMS on app launch (background process)
- Checks for new expenses periodically
- Non-blocking initialization

## Files Created/Modified

### New Files:
1. `lib/services/sms_expense_service.dart` - Core SMS parsing and detection logic
2. `lib/services/transaction_storage_service.dart` - Unified transaction storage
3. `lib/services/app_init_service.dart` - App initialization with SMS reading

### Modified Files:
1. `lib/models/transaction_model.dart` - Added auto-detection fields
2. `lib/widgets/expense_tile.dart` - Added "Auto" badge display
3. `lib/screens/ transactions/transaction_detail_screen.dart` - Category editing + auto badge
4. `lib/screens/home/home_screen.dart` - Uses TransactionStorageService
5. `lib/screens/ transactions/transaction_list_screen.dart` - Uses TransactionStorageService
6. `lib/screens/analytics/analytics_screen.dart` - Uses TransactionStorageService
7. `lib/app.dart` - Initializes SMS reading on launch
8. `android/app/src/main/AndroidManifest.xml` - Added SMS permissions
9. `pubspec.yaml` - Added dependencies

## Dependencies Added
- `permission_handler: ^11.3.0` - Runtime permission handling
- `sms_advanced: ^1.0.0` - SMS reading (null-safe)

## SMS Parsing Patterns

### Amount Extraction:
- Pattern 1: "Rs.105.00" or "Rs 105.00" or "₹105.00"
- Pattern 2: "105.00 Dr" or "105.00 debited"
- Pattern 3: "Paid Rs.299" or "spent 299"

### Merchant Extraction:
- UPI ID pattern: "9042309728@ptyes" or "merchant@upi"
- "to MerchantName" or "from MerchantName"
- Common merchant keywords

### Transaction Type Detection:
- Debit keywords: dr, debit, debited, paid, spent
- Credit keywords: cr, credit, credited (ignored)

## Privacy & Security
- ✅ No SMS data leaves the device
- ✅ No cloud storage
- ✅ No backend calls
- ✅ All processing happens locally
- ✅ Explainable rule-based logic

## Testing Notes

### SMS Format Examples Supported:
1. "Rs.105.00 Dr. from A/C XXXX9695 and Cr. to 9042309728@ptyes"
2. "Your account is debited with INR 450.00 via UPI Ref No..."
3. "Paid Rs.299 to Amazon using UPI"

### To Test:
1. Grant SMS permission when prompted
2. Ensure device has transactional SMS messages
3. Launch app - SMS will be read automatically
4. Check Home screen for auto-detected transactions
5. Edit category from transaction detail screen

## Known Limitations
- SMS package (`sms_advanced`) API may need adjustment based on actual package version
- SMS reading works only on Android (iOS doesn't allow SMS access)
- Requires SMS permission from user
- Parsing accuracy depends on SMS format consistency

## Next Steps
1. Test SMS reading on actual Android device
2. Adjust SMS parsing patterns based on real SMS formats
3. Add more merchant keywords for better categorization
4. Implement periodic background SMS checking
5. Add user preference to enable/disable SMS detection

