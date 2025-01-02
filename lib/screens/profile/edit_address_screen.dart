import 'package:flutter/material.dart';
import '../../models/address.dart';
import '../../services/api_service.dart';
import '../../utils/toast_utils.dart';

class EditAddressScreen extends StatefulWidget {
  final Address? address;

  const EditAddressScreen({super.key, this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  late String _selectedEmirate;
  bool _isDefault = false;
  AddressType _selectedAddressType = AddressType.SHIPPING;
  bool _isLoading = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Initialize with default emirate
    _selectedEmirate = 'DUBAI';
    
    if (widget.address != null) {
      _streetController.text = widget.address!.street;
      _apartmentController.text = widget.address!.apartment;
      _cityController.text = widget.address!.city;
      _pincodeController.text = widget.address!.pincode;
      // Only set emirate if it's in the valid list
      if (Address.emirates.contains(widget.address!.emirate)) {
        _selectedEmirate = widget.address!.emirate;
      }
      _isDefault = widget.address!.isDefault;
      _selectedAddressType = widget.address!.type;
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final address = Address(
        id: widget.address?.id,
        street: _streetController.text,
        apartment: _apartmentController.text,
        emirate: _selectedEmirate!,
        city: _cityController.text,
        pincode: _pincodeController.text,
        isDefault: widget.address?.isDefault ?? false,
        type: _selectedAddressType,
      );

      if (widget.address != null) {
        await _apiService.updateAddress(widget.address!.id!, address);
      } else {
        await _apiService.addAddress(address);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ToastUtils.showSuccessToast(
        widget.address != null ? 'Address updated successfully' : 'Address added successfully',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ToastUtils.showErrorToast(
        widget.address != null ? 'Failed to update address' : 'Failed to add address',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? 'Add New Address' : 'Edit Address'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(
                labelText: 'Street Address',
                hintText: 'Enter your street address',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your street address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apartmentController,
              decoration: const InputDecoration(
                labelText: 'Apartment/Area',
                hintText: 'Enter your apartment or area',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your apartment or area';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedEmirate,
              decoration: const InputDecoration(
                labelText: 'Emirate',
              ),
              items: Address.emirates.map((emirate) {
                return DropdownMenuItem(
                  value: emirate,
                  child: Text(Address.formatEmirateForDisplay(emirate)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedEmirate = value!);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an emirate';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'Enter your city',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your city';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pincodeController,
              decoration: const InputDecoration(
                labelText: 'PIN Code',
                hintText: 'Enter your PIN code',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your PIN code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'United Arab Emirates',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AddressType>(
              value: _selectedAddressType,
              decoration: const InputDecoration(
                labelText: 'Address Type',
              ),
              items: AddressType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedAddressType = value!);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Set as Default Address'),
              value: _isDefault,
              onChanged: (value) {
                setState(() => _isDefault = value);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(widget.address == null ? 'Add Address' : 'Update Address'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}
