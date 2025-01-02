import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _apiService = ApiService();
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
      final orders = await _apiService.getOrders(page: _page, limit: _limit);
      setState(() {
        _orders = orders.results;
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

  Future<void> _loadMoreOrders() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _apiService.getOrders(page: _page + 1, limit: _limit);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: _isLoading && _orders.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: $_error',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No orders yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your order history will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _orders.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _orders.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
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
                                              child: Text(
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
                      ),
      ),
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
}
