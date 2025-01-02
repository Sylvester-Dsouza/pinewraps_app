import 'package:flutter/material.dart';
import '../../models/address.dart';
import '../../services/api_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/address_card.dart';
import 'edit_address_screen.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  Map<String, bool> _operationLoading = {};
  List<Address> _addresses = [];
  Address? _addressesCache;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final addresses = await _apiService.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastUtils.showErrorToast('Failed to load addresses');
    }
  }

  Future<void> _deleteAddress(Address address) async {
    if (!mounted || _operationLoading[address.id!] == true) return;
    
    setState(() => _operationLoading[address.id!] = true);
    try {
      await _apiService.deleteAddress(address.id!);
      if (!mounted) return;
      setState(() {
        _addresses.removeWhere((a) => a.id == address.id);
        _operationLoading.remove(address.id);
      });
      ToastUtils.showSuccessToast('Address deleted successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => _operationLoading.remove(address.id));
      ToastUtils.showErrorToast('Failed to delete address');
    }
  }

  Future<void> _setDefaultAddress(Address address) async {
    if (!mounted || _operationLoading[address.id!] == true) return;
    
    setState(() => _operationLoading[address.id!] = true);
    try {
      final updatedAddress = await _apiService.setDefaultAddress(address.id!);
      if (!mounted) return;
      setState(() {
        // Update all addresses to not default
        _addresses = _addresses.map((a) => 
          a.copyWith(isDefault: a.id == address.id)
        ).toList();
        _operationLoading.remove(address.id);
      });
      ToastUtils.showSuccessToast('Default address updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _operationLoading.remove(address.id));
      ToastUtils.showErrorToast('Failed to set default address');
    }
  }

  Future<void> _editAddress(Address address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(address: address),
      ),
    );
    if (result == true) {
      // Force a fresh reload of addresses
      await _loadAddresses();
    }
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditAddressScreen(),
      ),
    );
    if (result == true) {
      await _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAddresses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No addresses found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _addNewAddress,
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Address'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final address = _addresses[index];
                      return AddressCard(
                        address: address,
                        isLoading: _operationLoading[address.id] ?? false,
                        onSetDefault: () => _setDefaultAddress(address),
                        onDelete: () => _deleteAddress(address),
                        onEdit: () => _editAddress(address),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAddress,
        child: const Icon(Icons.add),
      ),
    );
  }
}
