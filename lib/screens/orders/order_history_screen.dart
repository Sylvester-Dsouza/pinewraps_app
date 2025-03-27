import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _apiService = ApiService();
  final _authService = AuthService();
  final _scrollController = ScrollController();
  final _limit = 10;
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user email directly (no async needed now)
      String? email = _authService.getCurrentUserEmail();
      
      // Try to get customer details if email isn't available from Firebase
      if (email == null || email.isEmpty) {
        try {
          // Try to get from API service's cached customer
          final customerDetails = await _apiService.getCurrentCustomer();
          email = customerDetails.email;
          print('Using email from cached customer: $email');
        } catch (e) {
          print('Error getting cached customer: $e');
        }
      }
      
      // If still no email, redirect to login
      if (email == null || email.isEmpty) {
        setState(() {
          _error = 'Please login to view your orders';
          _isLoading = false;
        });
        
        // Show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to view your orders'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Optional: Navigate to login screen after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
        
        return;
      }
      
      print('Fetching orders for email: $email');
      
      // Use the new method to get all orders (online + POS)
      OrdersResponse orders;
      try {
        orders = await _apiService.getAllOrdersByEmail(
          email: email,
          page: _page, 
          limit: _limit
        );
        
        // Add more detailed logging
        print('Orders response received:');
        print('Total orders: ${orders.pagination.total}');
        print('Page: ${orders.pagination.page}');
        print('Results count: ${orders.results.length}');
        if (orders.results.isNotEmpty) {
          print('First order ID: ${orders.results.first.id}');
          print('First order status: ${orders.results.first.status}');
        } else {
          print('No orders returned in results array');
        }
        
        // Clear cache to force status refresh
        await _apiService.clearOrdersCache();
        
        setState(() {
          _orders = orders.results;
          _hasMore = orders.pagination.total > _orders.length;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading orders from API: $e');
        
        // Show an appropriate error message based on the exception
        String errorMessage = 'Could not load your orders. Please try again later.';
        
        if (e is ApiException) {
          if (e.statusCode == 401) {
            errorMessage = 'Please login to view your orders';
            // Navigate to login after a brief delay
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            });
          } else if (e.statusCode == 404) {
            errorMessage = 'No orders found.';
          } else if (e.statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = e.message;
          }
        }
        
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _error = 'Could not load your orders. Please try again later.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user email directly (no async needed now)
      String? email = _authService.getCurrentUserEmail();
      
      // Try to get customer details if email isn't available from Firebase
      if (email == null || email.isEmpty) {
        try {
          // Try to get from API service's cached customer
          final customerDetails = await _apiService.getCurrentCustomer();
          email = customerDetails.email;
        } catch (e) {
          print('Error getting cached customer: $e');
        }
      }
      
      // If still no email, show error
      if (email == null || email.isEmpty) {
        setState(() {
          _error = 'Please login to view your orders';
          _isLoading = false;
        });
        return;
      }
      
      // Clear cache to force status refresh
      await _apiService.clearOrdersCache();
      
      // Use the new method to get more orders (online + POS)
      final orders = await _apiService.getAllOrdersByEmail(
        email: email,
        page: _page + 1, 
        limit: _limit
      );
      
      setState(() {
        _orders.addAll(orders.results);
        _page++;
        _hasMore = orders.pagination.total > _orders.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    _page = 1;
    _hasMore = true;
    await _loadOrders();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadOrders,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrdersWidget() {
    return const Center(
      child: Text(
        'No orders found. Place your first order today!',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _orders.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final order = _orders[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(order: order),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${order.orderNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(order.createdAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        _buildStatusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(1),
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${order.items.length} ${order.items.length == 1 ? 'Item' : 'Items'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'AED ${order.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailsScreen(order: order),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case OrderStatus.CANCELLED:
        bgColor = Colors.red[50]!;
        textColor = Colors.red;
        text = 'Cancelled';
        break;
      case OrderStatus.PROCESSING:
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        text = 'Processing';
        break;
      case OrderStatus.DELIVERED:
        bgColor = Colors.green[50]!;
        textColor = Colors.green;
        text = 'Delivered';
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        text = status.toString().split('.').last;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _page = 1;
                _orders = [];
              });
              _loadOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _orders.isEmpty
                    ? _buildErrorWidget()
                    : _orders.isEmpty
                        ? _buildEmptyOrdersWidget()
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                _page = 1;
                                _orders = [];
                                _hasMore = true;
                              });
                              await _loadOrders();
                            },
                            child: _buildOrderList(),
                          ),
          ),
        ],
      ),
    );
  }
}
