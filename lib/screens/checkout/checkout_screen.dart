import 'package:flutter/material.dart';
import '../payment/payment_screen.dart';
import '../../services/cart_service.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../models/address.dart';
import '../../models/customer_details.dart';
import '../../models/cart_item.dart'; // Added CartItem import
import 'dart:math'; // Added dart:math import for max/min functions
import 'dart:convert'; // Added import for dart:convert
import 'package:firebase_auth/firebase_auth.dart'; // Added import for Firebase Authentication

enum DeliveryMethod { storePickup, standardDelivery }

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final VoidCallback onCheckoutComplete;

  const CheckoutScreen({
    Key? key,
    required this.cartItems,
    required this.onCheckoutComplete,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartService _cartService = CartService();
  final ApiService _apiService = ApiService();
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _couponController = TextEditingController();
  final _giftMessageController = TextEditingController();
  final _giftRecipientNameController = TextEditingController();
  final _giftRecipientPhoneController = TextEditingController();
  final pointsController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();

  // Read-only flags
  bool _firstNameReadOnly = false;
  bool _lastNameReadOnly = false;
  bool _emailReadOnly = false;
  bool _phoneReadOnly = false;

  // UAE Emirates with proper formatting for both UI display and backend compatibility
  final List<String> _emirates = [
    'Abu Dhabi',
    'Dubai',
    'Sharjah',
    'Ajman',
    'Umm Al Quwain',
    'Ras Al Khaimah',
    'Fujairah',
  ];

  // Backend format for emirates (used for API calls)
  final Map<String, String> _backendEmirates = {
    'Abu Dhabi': 'ABU_DHABI',
    'Dubai': 'DUBAI',
    'Sharjah': 'SHARJAH',
    'Ajman': 'AJMAN',
    'Umm Al Quwain': 'UMM_AL_QUWAIN',
    'Ras Al Khaimah': 'RAS_AL_KHAIMAH',
    'Fujairah': 'FUJAIRAH',
  };

  String? _selectedEmirate; // For UI display
  double _deliveryCharge = 0;

  final List<String> _pickupTimeSlots = [
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
    '7:00 PM',
    '8:00 PM',
    '9:00 PM',
  ];

  final Map<String, List<Map<String, dynamic>>> _deliveryTimeSlots = {
    'Dubai': [
      {
        'slot': '11am-1pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
      {
        'slot': '1pm-4pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
      {'slot': '4pm-7pm', 'cutoff': '11:00', 'nextDay': false}, // 11am same day
      {'slot': '7pm-10pm', 'cutoff': '16:00', 'nextDay': false}, // 4pm same day
    ],
    'Sharjah': [
      {'slot': '4pm-9pm', 'cutoff': '11:00', 'nextDay': false}, // 11am same day
    ],
    'Ajman': [
      {
        'slot': '5pm-9:30pm',
        'cutoff': '11:00',
        'nextDay': false
      }, // 11am same day
    ],
    'Abu Dhabi': [
      {
        'slot': '5pm-9:30pm',
        'cutoff': '11:00',
        'nextDay': false
      }, // 11am same day
    ],
    'Al Ain': [
      {
        'slot': '4pm-10pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
    ],
    'Ras Al Khaimah': [
      {
        'slot': '4pm-10pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
    ],
    'Umm Al Quwain': [
      {
        'slot': '4pm-10pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
    ],
    'Fujairah': [
      {
        'slot': '4pm-10pm',
        'cutoff': '20:00',
        'nextDay': true
      }, // 8pm previous day
    ],
  };

  DeliveryMethod _selectedDeliveryMethod = DeliveryMethod.standardDelivery;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isValidatingCoupon = false;
  String? _couponError;
  String? _appliedCouponCode;
  bool _isCouponApplied = false;
  double _couponDiscount = 0;
  bool _isLoading = false;
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;
  CustomerDetails? _customerDetails;
  bool _isPointsRedeemed = false;
  static const double POINTS_REDEMPTION_RATE = 1 / 4; // 4 points = 1 AED
  double _total = 0;
  bool _isGift = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _loadCustomerDetails();
    _phoneReadOnly = false; // Make phone number always editable
    _calculateTotal(); // Initialize total on startup

    // Initialize emirate with a valid value from the _emirates list
    _selectedEmirate = _emirates[1]; // Dubai is at index 1

    // Initialize recipient phone with UAE country code
    _giftRecipientPhoneController.text = '+971 ';
  }

  Future<void> _checkAuthentication() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      if (!mounted) return;
      // Show a message and navigate to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to continue with checkout'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  double _calculateSubTotal() {
    double subtotal = 0;
    for (var item in widget.cartItems) {
      subtotal += item.price * item.quantity;
    }
    return subtotal;
  }

  double _calculateTotalBeforeDiscounts() {
    return _calculateSubTotal();
  }

  double _calculateTotal() {
    // Start with subtotal
    double total = _calculateSubTotal();
    print('Subtotal: $total');

    // Apply coupon discount
    if (_isCouponApplied && _couponDiscount > 0) {
      total = max(0, total - _couponDiscount);
      print('After coupon discount: $total');
    }

    // Apply points redemption
    if (_isPointsRedeemed) {
      final pointsDiscount = _calculatePointsDiscount();
      total = max(0, total - pointsDiscount);
      print('After points discount: $total');
    }

    // Add delivery charge
    if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) {
      total += _deliveryCharge;
      print('After delivery charge: $total');
    }

    // Update state
    setState(() {
      _total = max(0, total);
    });

    print('Final total: $_total');
    return _total;
  }

  double _calculatePointsDiscount() {
    if (!_isPointsRedeemed || _customerDetails == null) return 0;

    final pointsToRedeem = int.tryParse(pointsController.text) ?? 0;
    if (pointsToRedeem <= 0) return 0;

    // Calculate points value (4 points = 1 AED)
    final pointsValue = pointsToRedeem * POINTS_REDEMPTION_RATE;

    // Ensure points discount doesn't exceed remaining total after coupon
    final remainingTotal =
        _calculateSubTotal() - (_isCouponApplied ? _couponDiscount : 0);
    return min(pointsValue, remainingTotal);
  }

  Future<void> _loadCustomerDetails() async {
    try {
      final response = await _apiService.sendRequest(
        '/customers/profile',
        method: 'GET',
      );

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Failed to load customer details');
      }

      final customerData = response.data['data'];

      setState(() {
        // Set customer details
        _customerDetails = CustomerDetails(
          id: customerData['id'],
          firstName: customerData['firstName'],
          lastName: customerData['lastName'],
          email: customerData['email'],
          phone: customerData['phone'] ?? '',
          rewardPoints: customerData['rewardPoints'] ?? 0,
        );

        // Set form fields
        _firstNameController.text = customerData['firstName'];
        _lastNameController.text = customerData['lastName'];
        _emailController.text = customerData['email'];

        // Format phone number with UAE country code
        String phone = customerData['phone'] ?? '';
        if (!phone.startsWith('+971')) {
          phone = phone.startsWith('0')
              ? '+971${phone.substring(1)}'
              : '+971$phone';
        }
        _phoneController.text = phone;

        // Make fields read-only except phone
        _firstNameReadOnly = true;
        _lastNameReadOnly = true;
        _emailReadOnly = true;
        _phoneReadOnly = false;

        // Set addresses
        _savedAddresses = (customerData['addresses'] as List)
            .map((addr) => Address(
                  name: 'Billing Address',
                  street: addr['street'],
                  apartment: addr['apartment'] ?? '',
                  emirate: addr['emirate'],
                  city: addr['city'],
                  pincode: addr['pincode'] ?? '',
                  isDefault: addr['isDefault'] ?? false,
                ))
            .toList();

        // Set default address if available
        if (_savedAddresses.isNotEmpty) {
          _selectedAddress = _savedAddresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => _savedAddresses.first,
          );
          _updateShippingFields(_selectedAddress!);
        }

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer details: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load customer details. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime firstDate;

    if (_selectedDeliveryMethod == DeliveryMethod.storePickup) {
      // For store pickup, allow same day with 3 hour buffer
      final currentHour = now.hour;
      if (currentHour >= 21) {
        // After 9 PM
        firstDate = today.add(const Duration(days: 1)); // Start from tomorrow
      } else {
        firstDate = today; // Start from today
      }
    } else {
      // For delivery, start from tomorrow
      firstDate = today.add(const Duration(days: 1));
    }

    final lastDate = today.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.grey[800]!, // header background
              onPrimary: Colors.white, // header text
              onSurface: Colors.black87, // calendar text
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[800], // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null; // Reset time slot when date changes
      });
    }
  }

  List<String> _getAvailableTimeSlots() {
    final now = DateTime.now();
    final selectedDate = _selectedDate;

    if (selectedDate == null) return [];

    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    final isTomorrow = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day + 1;

    if (_selectedDeliveryMethod == DeliveryMethod.storePickup) {
      // For store pickup, use fixed time slots

      // If not today, return all time slots
      if (!isToday) {
        return List.from(_pickupTimeSlots);
      }

      // For same day pickup, filter slots based on current time + 3 hours buffer
      final currentHour = now.hour;
      return _pickupTimeSlots.where((slot) {
        final slotParts = slot.split(':');
        int slotHour = int.tryParse(slotParts[0].trim()) ?? 0;
        final isPM = slot.toLowerCase().contains('pm');

        // Convert to 24-hour format
        if (isPM && slotHour != 12) {
          slotHour += 12;
        } else if (!isPM && slotHour == 12) {
          slotHour = 0;
        }

        // Slot is available if it's at least 3 hours from now
        return slotHour > (currentHour + 3);
      }).toList();
    } else {
      // For delivery, use emirate-specific slots
      final currentEmirate =
          _selectedEmirate ?? _emirates[1]; // Default to Dubai

      // Find the matching key in _deliveryTimeSlots
      final emirateKey = _deliveryTimeSlots.keys.firstWhere(
        (key) => key.toUpperCase() == currentEmirate.toUpperCase(),
        orElse: () => _emirates[1], // Default to Dubai
      );

      if (_deliveryTimeSlots[emirateKey] == null) return [];

      final currentHour = now.hour;
      final currentMinute = now.minute;
      final currentTime =
          currentHour * 60 + currentMinute; // Convert to minutes

      return _deliveryTimeSlots[emirateKey]!
          .where((slot) {
            final cutoffParts = slot['cutoff'].split(':');
            final cutoffHour = int.parse(cutoffParts[0]);
            final cutoffMinute = int.parse(cutoffParts[1]);
            final cutoffTime = cutoffHour * 60 + cutoffMinute;

            if (slot['nextDay']) {
              // For next day delivery slots
              if (isToday) {
                // If selected date is today, these slots are not available
                return false;
              } else if (isTomorrow) {
                // If selected date is tomorrow, check against today's cutoff
                return currentTime < cutoffTime;
              }
              // For any other future date, slot is available
              return true;
            } else {
              // For same day delivery slots
              if (!isToday) {
                // Future dates are always available for same day slots
                return true;
              }
              // For today, check current time against cutoff
              return currentTime < cutoffTime;
            }
          })
          .map((slot) => slot['slot'] as String)
          .toList();
    }
  }

  Future<void> _validateCoupon(String code) async {
    final couponCode = _couponController.text.trim();
    if (couponCode.isEmpty) {
      _showMessage('Please enter a coupon code', isError: true);
      return;
    }

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
      _couponDiscount = 0;
    });

    try {
      final subtotal = _calculateSubTotal(); // Use subtotal for validation
      print('Validating coupon: $couponCode with subtotal: $subtotal');
      final response = await _apiService.validateCoupon(couponCode, subtotal);
      final data = response.data['data'];

      if (data != null) {
        setState(() {
          _appliedCouponCode = couponCode;
          _isCouponApplied = true;
          _couponDiscount = (data['discount'] as num).toDouble();
          _showMessage('Coupon applied successfully!', isError: false);
        });
        _calculateTotal();
      }
    } on ApiException catch (e) {
      print('ApiException during coupon validation: ${e.message}');
      setState(() {
        _couponError = e.message;
        _appliedCouponCode = null;
        _isCouponApplied = false;
        _couponDiscount = 0;
      });
      _showMessage(e.message, isError: true);
    } catch (e) {
      print('Error during coupon validation: $e');
      setState(() {
        _couponError = 'Failed to validate coupon';
        _appliedCouponCode = null;
        _isCouponApplied = false;
        _couponDiscount = 0;
      });
      _showMessage('Failed to validate coupon', isError: true);
    } finally {
      setState(() {
        _isValidatingCoupon = false;
      });
      _calculateTotal();
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0;
      _isCouponApplied = false;
      _couponController.clear();
    });
  }

  bool _validateGiftFields() {
    if (!_isGift) return true;

    return _giftRecipientNameController.text.isNotEmpty &&
        _giftRecipientPhoneController.text.isNotEmpty &&
        RegExp(r'^\+971[0-9]{9}$').hasMatch(_giftRecipientPhoneController.text
            .replaceAll(RegExp(r'[\s\-()]'), '')) &&
        _giftMessageController.text.isNotEmpty;
  }

  Future<void> _placeOrder() async {
    try {
      // Step 1: Validate Form and Cart
      if (!_formKey.currentState!.validate() || !_validateGiftFields()) {
        _showMessage('Please fill in all required fields correctly',
            isError: true);
        return;
      }

      if (widget.cartItems.isEmpty) {
        _showMessage('Your cart is empty', isError: true);
        return;
      }

      if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) {
        if (_selectedEmirate == null || _selectedEmirate!.isEmpty) {
          _showMessage('Please select an emirate for delivery', isError: true);
          return;
        }

        if (_streetController.text.trim().isEmpty ||
            _cityController.text.trim().isEmpty) {
          _showMessage('Please provide complete delivery address',
              isError: true);
          return;
        }
      }

      if (_selectedDate == null || _selectedTimeSlot == null) {
        _showMessage('Please select a date and time slot', isError: true);
        return;
      }

      // Step 3: Validate Points Redemption
      if (_isPointsRedeemed) {
        final points = int.tryParse(pointsController.text);
        if (points == null || points <= 0) {
          _showMessage('Please enter a valid number of points to redeem',
              isError: true);
          return;
        }

        if (points > _customerDetails!.rewardPoints) {
          _showMessage('You cannot redeem more points than you have available',
              isError: true);
          return;
        }
      }

      setState(() => _isLoading = true);

      // Step 4: Build and Send Order Data
      final orderData = _buildOrderData();
      print('Sending order data: ${json.encode(orderData)}');

      final response = await _apiService.createOrder(orderData);

      print('API Response: ${json.encode(response)}');

      // Step 5: Handle Response
      print('Success response data: ${json.encode(response)}');

      String? orderId;
      String? paymentUrl;

      // Extract data from response
      if (response.containsKey('order') && response['order'] is Map) {
        orderId = response['order']['id'].toString();
      } else if (response.containsKey('id')) {
        orderId = response['id'].toString();
      }

      if (response.containsKey('paymentUrl')) {
        paymentUrl = response['paymentUrl'].toString();
      }

      print('Extracted order ID: $orderId');
      print('Extracted payment URL: $paymentUrl');

      // If we have a payment URL but no order ID, use the payment URL directly
      if ((orderId == null || orderId.isEmpty) &&
          paymentUrl != null &&
          paymentUrl.isNotEmpty) {
        print('Using payment URL directly: $paymentUrl');
        await _navigateToPaymentWebView(paymentUrl);
        return;
      }

      // If we have an order ID, process payment
      if (orderId != null && orderId.isNotEmpty) {
        await _processPayment(orderId);
        return;
      }

      throw Exception(
          'Could not extract order ID or payment URL from response: ${json.encode(response)}');
    } catch (e) {
      print('Error placing order: $e');
      setState(() => _isLoading = false);

      String errorMessage = 'Failed to place order. ';
      if (e.toString().contains('Authentication error')) {
        errorMessage += 'Please log in again.';
      } else if (e.toString().contains('Validation error')) {
        errorMessage += 'Please check your input.';
      } else if (e.toString().contains('Server error')) {
        final parts = e.toString().split('Server error:');
        errorMessage += parts.length > 1
            ? parts[1]
            : 'Please try again later or contact support.';
      } else {
        errorMessage += e.toString();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _processPayment(String orderId) async {
    try {
      // Get payment URL from payment service
      final paymentData = await _paymentService.createPaymentOrder(
        orderId: orderId,
      );

      if (!mounted) return;

      // Show payment screen
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            paymentUrl: paymentData['paymentUrl']!,
            orderId: orderId,
            reference: paymentData['reference']!,
            onPaymentComplete: (success) {
              if (success) {
                // Clear cart and show success message
                _cartService.clearCart();

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/orders',
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment failed. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );

      if (paymentResult == false) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToPaymentWebView(String paymentUrl) async {
    try {
      if (!mounted) return;

      // Generate a unique reference for this payment
      final reference = 'direct_${DateTime.now().millisecondsSinceEpoch}';

      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            paymentUrl: paymentUrl,
            orderId: 'pending', // Order ID will be assigned after payment
            reference: reference,
            onPaymentComplete: (success) {
              if (success) {
                // Clear cart and show success message
                _cartService.clearCart();

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/orders',
                  (route) => false,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment failed. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );

      if (paymentResult == false) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error navigating to payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open payment page: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildOrderData() {
    final subtotal = _calculateSubTotal();
    final total = _calculateTotal();

    // Format time slot to 24-hour format
    String formatTimeSlot(String? timeSlot) {
      if (timeSlot == null) return '';

      // Parse the time slot (e.g., "5:00 PM")
      final parts = timeSlot.split(' ');
      if (parts.length != 2) return timeSlot;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return timeSlot;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      final minutes = timeParts[1];
      final isPM = parts[1].toUpperCase() == 'PM';

      // Convert to 24-hour format
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return '${hour.toString().padLeft(2, '0')}:$minutes';
    }

    // Calculate delivery charge based on emirate
    final isDelivery =
        _selectedDeliveryMethod == DeliveryMethod.standardDelivery;
    final selectedEmirate = _selectedEmirate;
    final deliveryCharge = isDelivery
        ? (_backendEmirates[selectedEmirate] == 'DUBAI' ? 30 : 50)
        : 0;

    return {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'idempotencyKey': DateTime.now().millisecondsSinceEpoch.toString(),
      'deliveryMethod': _selectedDeliveryMethod == DeliveryMethod.storePickup
          ? 'PICKUP'
          : 'DELIVERY',
      'items': widget.cartItems
          .map((item) => {
                'name': item.product.name,
                'variant': ((item.selectedSize?.isNotEmpty == true
                            ? item.selectedSize
                            : item.selectedFlavour?.isNotEmpty == true
                                ? item.selectedFlavour
                                : '') ??
                        '')
                    .toUpperCase(),
                'price': item.totalPrice.floor(),
                'quantity': item.quantity,
                'cakeWriting': item.cakeText ?? '',
              })
          .toList(),
      'subtotal': subtotal.floor(),
      'total': total.floor(),
      'paymentMethod': 'CREDIT_CARD',
      'isGift': _isGift,
      'emirate': _selectedEmirate != null
          ? _backendEmirates[_selectedEmirate]
          : null, // Always include emirate
      'deliveryCharge': deliveryCharge, // Always include deliveryCharge
      if (_isGift) ...{
        'giftMessage': _giftMessageController.text.trim(),
        'giftRecipientName': _giftRecipientNameController.text.trim(),
        'giftRecipientPhone': _giftRecipientPhoneController.text.trim(),
      },
      'pointsRedeemed':
          _isPointsRedeemed ? int.tryParse(pointsController.text) ?? 0 : 0,
      if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) ...{
        'streetAddress': _streetController.text.trim(),
        'apartment': _apartmentController.text.trim(),
        'city': _cityController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'deliveryDate': _selectedDate?.toIso8601String().split('T')[0],
        'deliveryTimeSlot': _selectedTimeSlot != null
            ? formatTimeSlot(_selectedTimeSlot)
            : null,
        'deliveryInstructions': _deliveryInstructionsController.text.trim(),
      } else ...{
        'streetAddress': '', // Add empty strings for required fields
        'apartment': '',
        'city': '',
        'pincode': '',
        'pickupDate': _selectedDate?.toIso8601String().split('T')[0],
        'pickupTimeSlot': _selectedTimeSlot != null
            ? formatTimeSlot(_selectedTimeSlot)
            : null,
        'storeLocation': 'Dubai Main Store',
      },
      if (_couponController.text.isNotEmpty)
        'couponCode': _couponController.text,
    };
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _couponController.dispose();
    _giftMessageController.dispose();
    _giftRecipientNameController.dispose();
    _giftRecipientPhoneController.dispose();
    pointsController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildContactForm(),
                  const SizedBox(height: 24),
                  _buildDeliveryOptions(),
                  const SizedBox(height: 24),
                  if (_selectedDeliveryMethod ==
                      DeliveryMethod.standardDelivery) ...[
                    _buildShippingForm(),
                    const SizedBox(height: 24),
                  ],
                  _buildTimeSlotSelector(),
                  const SizedBox(height: 24),
                  _buildGiftSection(),
                  const SizedBox(height: 24),
                  _buildRewardPointsSection(),
                  const SizedBox(height: 24),
                  _buildCouponSection(),
                  const SizedBox(height: 24),
                  _buildOrderItemsSection(),
                  const SizedBox(height: 24),
                  _buildPriceBreakdown(),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _placeOrder,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Place Order - ${_cartService.totalPrice.toStringAsFixed(2)} AED',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contact Information'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                readOnly: _firstNameReadOnly,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                readOnly: _lastNameReadOnly,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          readOnly: _emailReadOnly,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          readOnly: _phoneReadOnly,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            // Validate UAE phone number format
            if (!RegExp(r'^\+971[0-9]{9}$')
                .hasMatch(value.replaceAll(RegExp(r'[\s\-()]'), ''))) {
              return 'Please enter a valid UAE phone number (+971XXXXXXXXX)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Delivery Options'),
        const SizedBox(height: 16),
        Column(
          children: [
            _buildDeliveryMethodCard(
              DeliveryMethod.storePickup,
              'Store Pickup',
              'Pick up from our store',
              Icons.store,
            ),
            const SizedBox(height: 16),
            _buildDeliveryMethodCard(
              DeliveryMethod.standardDelivery,
              'Standard Delivery',
              'Delivery to your address',
              Icons.local_shipping,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
      validator: validator,
    );
  }

  Widget _buildDeliveryMethodCard(
    DeliveryMethod method,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedDeliveryMethod == method;
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.black87 : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedDeliveryMethod = method;
          _selectedTimeSlot =
              null; // Reset time slot when delivery method changes
        }),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.black87 : Colors.grey[600],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.black87 : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Radio<DeliveryMethod>(
                value: method,
                groupValue: _selectedDeliveryMethod,
                onChanged: (value) => setState(() {
                  _selectedDeliveryMethod = value!;
                  _selectedTimeSlot =
                      null; // Reset time slot when delivery method changes
                }),
                activeColor: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingForm() {
    if (_selectedDeliveryMethod != DeliveryMethod.standardDelivery) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildTextField(
          controller: _streetController,
          label: 'Street Address',
          validator: (value) => value?.isEmpty ?? true
              ? 'Please enter your street address'
              : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _apartmentController,
          label: 'Apartment/Villa/Office (Optional)',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cityController,
          label: 'City',
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your city' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedEmirate, // Set initial value
          decoration: const InputDecoration(
            labelText: 'Emirate',
            border: OutlineInputBorder(),
          ),
          items: _emirates.map((emirate) {
            return DropdownMenuItem(
              value: emirate,
              child: Text(emirate),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmirate =
                  value ?? _emirates.first; // Use the exact value from the list
              _updateDeliveryCharge();
            });
          },
          validator: (value) =>
              value == null ? 'Please select an emirate' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _pincodeController,
          label: 'Pincode',
          keyboardType: TextInputType.number,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter your pincode' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _deliveryInstructionsController,
          label: 'Delivery Instructions (Optional)',
          maxLines: 3,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }

  void _updateShippingFields(Address address) {
    _streetController.text = address.street;
    _apartmentController.text = address.apartment;
    _cityController.text = address.city;

    // Set selected emirate by finding matching value in _emirates list
    final addressEmirate = address.emirate;
    // Find the UI display emirate that matches the backend format
    String? displayEmirate;
    for (var entry in _backendEmirates.entries) {
      if (entry.value == addressEmirate ||
          entry.value.toUpperCase() == addressEmirate.toUpperCase()) {
        displayEmirate = entry.key;
        break;
      }
    }

    if (displayEmirate != null && _emirates.contains(displayEmirate)) {
      _selectedEmirate = displayEmirate;
    } else {
      _selectedEmirate = 'Dubai'; // Default to Dubai
    }

    _pincodeController.text = address.pincode;
  }

  void _updateDeliveryCharge() {
    if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery) {
      final selectedEmirate = _selectedEmirate;
      // Set delivery charge based on emirate
      setState(() {
        if (selectedEmirate == null) {
          _deliveryCharge = 30; // Default to Dubai charge
        } else if (_backendEmirates[selectedEmirate] == 'DUBAI') {
          // Use display name
          _deliveryCharge = 30;
        } else {
          _deliveryCharge = 50;
        }
      });
    } else {
      setState(() {
        _deliveryCharge = 0;
      });
    }
    // Recalculate total
    _calculateTotal();
  }

  Widget _buildTimeSlotSelector() {
    List<String> timeSlots = _getAvailableTimeSlots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery &&
            _selectedEmirate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.grey[700]),
                  const SizedBox(width: 12),
                  Text(
                    'Delivery Charge: ${_deliveryCharge.toInt()} AED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? _selectedDeliveryMethod == DeliveryMethod.storePickup
                          ? 'Select Pickup Date'
                          : 'Select Delivery Date'
                      : getFormattedDate(),
                  style: TextStyle(
                    color: _selectedDate == null
                        ? Colors.grey[600]
                        : Colors.grey[800],
                    fontSize: 16,
                    fontWeight: _selectedDate == null
                        ? FontWeight.normal
                        : FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_selectedDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              'Please select a date',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedTimeSlot, // Set initial value
          decoration: InputDecoration(
            labelText: _selectedDeliveryMethod == DeliveryMethod.storePickup
                ? 'Select Pickup Time'
                : 'Select Delivery Time',
            labelStyle: TextStyle(color: Colors.grey[700]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: timeSlots
              .map((slot) => DropdownMenuItem(
                    value: slot,
                    child: Text(
                      slot,
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ))
              .toList(),
          onChanged: timeSlots.isEmpty
              ? null
              : (value) {
                  setState(() => _selectedTimeSlot = value);
                },
          validator: (value) =>
              value == null ? 'Please select a time slot' : null,
          hint: Text(
            timeSlots.isEmpty
                ? _selectedDate == null
                    ? 'Select a date first'
                    : 'No time slots available'
                : 'Select a time slot',
            style: TextStyle(color: Colors.grey[600]),
          ),
          icon: Icon(Icons.access_time, color: Colors.grey[700]),
          dropdownColor: Colors.grey[50],
          style: TextStyle(color: Colors.grey[800], fontSize: 16),
        ),
      ],
    );
  }

  String getFormattedDate() {
    if (_selectedDate == null) return '';
    return '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
  }

  Widget _buildGiftSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Gift Options'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Send as a Gift',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _isGift,
                onChanged: (value) {
                  setState(() {
                    _isGift = value;
                    if (!value) {
                      // Clear gift fields when turning off
                      _giftRecipientNameController.clear();
                      _giftRecipientPhoneController.clear();
                      _giftMessageController.clear();
                    } else {
                      // Re-initialize phone with country code when turning on
                      _giftRecipientPhoneController.text = '+971 ';
                    }
                  });
                },
              ),
              if (_isGift) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _giftRecipientNameController,
                  label: "Recipient's Name",
                  validator: (value) => value?.isEmpty ?? true
                      ? "Please enter recipient's name"
                      : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _giftRecipientPhoneController,
                  label: "Recipient's Phone",
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter recipient's phone number";
                    }
                    // Clean the phone number
                    final cleanPhone =
                        value.replaceAll(RegExp(r'[\s\-()]'), '');
                    // Validate UAE phone number format
                    if (!RegExp(r'^\+971[0-9]{9}$').hasMatch(cleanPhone)) {
                      return 'Please enter a valid UAE phone number (+971 XX XXX XXXX)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _giftMessageController,
                  label: 'Gift Message',
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Please enter a gift message'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardPointsSection() {
    // Calculate points to be earned based on tier rate
    double pointRate = 0.07; // Default GREEN tier rate
    if (_customerDetails != null) {
      switch (_customerDetails!.rewardTier) {
        case 'PLATINUM':
          pointRate = 0.20; // 20%
          break;
        case 'GOLD':
          pointRate = 0.15; // 15%
          break;
        case 'SILVER':
          pointRate = 0.12; // 12%
          break;
        default:
          pointRate = 0.07; // GREEN (7%)
      }
    }

    // Calculate points based on total before any discounts (includes delivery)
    // For example: 100 AED * 0.07 = 7 points for GREEN tier
    int pointsToEarn = (_calculateTotalBeforeDiscounts() * pointRate).floor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Rewards'),
          const SizedBox(height: 8),
          Text(
            'You will earn $pointsToEarn points with this order!',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_customerDetails != null) ...[
            const SizedBox(height: 8),
            Text(
              'Your current tier: ${_customerDetails!.rewardTier}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Earn ${(pointRate * 100).toStringAsFixed(0)}% points on every order',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (_customerDetails != null &&
              _customerDetails!.rewardPoints > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Available Points: ${_customerDetails!.rewardPoints}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can redeem your points for a discount (4 points = 1 AED)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pointsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points to Redeem',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabled: !_isPointsRedeemed,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isPointsRedeemed
                      ? () {
                          setState(() {
                            _isPointsRedeemed = false;
                            pointsController.clear();
                          });
                        }
                      : () {
                          if (pointsController.text.isNotEmpty) {
                            setState(() {
                              _isPointsRedeemed = true;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isPointsRedeemed ? 'Remove' : 'Redeem'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have a Coupon?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      labelText: 'Enter Coupon Code',
                      hintText: 'Enter your coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      errorText: _couponError,
                      enabled: !_isCouponApplied,
                    ),
                    onFieldSubmitted: (value) => _validateCoupon(value),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isCouponApplied)
                  ElevatedButton(
                    onPressed: _removeCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Remove'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isValidatingCoupon
                        ? null
                        : () => _validateCoupon(_couponController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: _isValidatingCoupon
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Apply'),
                  ),
              ],
            ),
            if (_couponError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _couponError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    // Force recalculation of total
    final currentTotal = _calculateTotal();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPriceRow(
              'Subtotal',
              _calculateSubTotal().toInt(),
            ),
            if (_isCouponApplied && _couponDiscount > 0)
              _buildPriceRow(
                'Coupon Discount ($_appliedCouponCode)',
                _couponDiscount.toInt(),
                isDeduction: true,
              ),
            if (_isPointsRedeemed)
              _buildPriceRow(
                'Points Redeemed',
                _calculatePointsDiscount().toInt(),
                isDeduction: true,
              ),
            if (_selectedDeliveryMethod == DeliveryMethod.standardDelivery)
              _buildPriceRow(
                'Delivery Charge',
                _deliveryCharge.toInt(),
              ),
            const Divider(height: 32),
            _buildPriceRow(
              'Total',
              currentTotal.toInt(),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, int amount,
      {bool isDeduction = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}$amount AED',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDeduction ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cartItems.length,
            itemBuilder: (context, index) {
              final item = widget.cartItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: item.product.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.product.imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.cake,
                              size: 30, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.selectedSize != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Size: ${item.selectedSize}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (item.selectedFlavour != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Flavour: ${item.selectedFlavour}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                          // Display selected options for cake flavors
                          if (item.selectedOptions
                              .containsKey('cakeFlavors')) ...[
                            const SizedBox(height: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected ${item.selectedOptions['variationType']?.toLowerCase() ?? 'flavor'}s:',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ...((item.selectedOptions['cakeFlavors']
                                            as List<dynamic>?) ??
                                        [])
                                    .map((flavor) {
                                  return Text(
                                    'Cake ${flavor['cakeNumber']}: ${flavor['flavor']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                          // Display other selected options
                          if (item.selectedOptions.isNotEmpty &&
                              !item.selectedOptions
                                  .containsKey('cakeFlavors') &&
                              !item.selectedOptions
                                  .containsKey('cakeText')) ...[
                            const SizedBox(height: 4),
                            ...item.selectedOptions.entries
                                .where((entry) =>
                                    entry.key != 'variationType' &&
                                    entry.key != 'size' &&
                                    entry.key != 'flavour')
                                .map((entry) {
                              return Text(
                                '${entry.key.substring(0, 1).toUpperCase()}${entry.key.substring(1)}: ${entry.value}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ],
                          if (item.cakeText != null &&
                              item.cakeText!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Text: ${item.cakeText}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price and Quantity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.price.toInt()} AED',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
