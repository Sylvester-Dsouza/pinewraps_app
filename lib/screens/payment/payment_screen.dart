import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:app_links/app_links.dart';
import '../../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final String reference;
  final Function(bool) onPaymentComplete;

  const PaymentScreen({
    Key? key,
    required this.paymentUrl,
    required this.orderId,
    required this.reference,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late WebViewController _controller;
  final _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isCompleted = false;
  AppLinks? _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setupWebView();
    _setupDeepLinkHandling();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');
            final uri = Uri.parse(request.url);
            
            // Check if this is a redirect back to our app
            if (uri.host == 'pinewraps-api.onrender.com' && 
                uri.path.contains('/payments/mobile-callback')) {
              _handlePaymentCallback(uri);
              return NavigationDecision.prevent;
            }
            
            // Allow all other navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _setupDeepLinkHandling() async {
    _appLinks = AppLinks();

    // Handle incoming links when app is in foreground
    _linkSubscription = _appLinks?.uriLinkStream.listen((Uri? uri) {
      if (uri != null && !_isCompleted) {
        print('Received deep link: ${uri.toString()}');
        _handlePaymentCallback(uri);
      }
    }, onError: (err) {
      print('Deep link error: $err');
    });

    // Handle case where app is opened from terminated state
    try {
      final uri = await _appLinks?.getInitialAppLink();
      if (uri != null && !_isCompleted) {
        print('Received initial deep link: ${uri.toString()}');
        _handlePaymentCallback(uri);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }

  Future<void> _handlePaymentCallback(Uri uri) async {
    if (_isCompleted || _isProcessing) return;
    
    print('Handling payment callback: ${uri.toString()}');
    setState(() => _isProcessing = true);
    
    try {
      // Check if payment was cancelled
      if (uri.queryParameters['cancelled'] == 'true') {
        print('Payment was cancelled');
        _completePayment(false);
        return;
      }

      // Get reference from URL or use the one passed to widget
      final reference = uri.queryParameters['ref'] ?? widget.reference;

      // Wait for confirmation using the merchant order ID (reference)
      print('Waiting for payment confirmation...');
      final success = await _paymentService.verifyPayment(reference);
      print('Payment ${success ? 'successful' : 'failed'}');
      _completePayment(success);
    } catch (e) {
      print('Error handling payment callback: $e');
      _completePayment(false);
    }
  }

  void _completePayment(bool success) {
    if (_isCompleted) return;
    
    print('Completing payment: ${success ? 'success' : 'failure'}');
    _isCompleted = true;
    
    if (mounted) {
      // Pop all screens up to the root
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Navigate to success or failure screen
      if (success) {
        Navigator.pushReplacementNamed(context, '/order-success');
      } else {
        Navigator.pushReplacementNamed(context, '/order-failed');
      }
      
      // Call the completion callback
      widget.onPaymentComplete(success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isCompleted && !_isProcessing) {
          _completePayment(false);
        }
        return _isCompleted;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: _isProcessing ? null : IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _completePayment(false),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading || _isProcessing)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _isProcessing 
                          ? 'Processing payment...\nPlease wait'
                          : 'Loading...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
