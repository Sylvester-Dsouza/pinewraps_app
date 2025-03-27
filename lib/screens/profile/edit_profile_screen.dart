import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../utils/toast_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      print('Loading customer profile data...');
      final customer = await _apiService.getCurrentCustomer();
      print('Customer data received: ${customer.toJson()}');
      
      setState(() {
        _firstNameController.text = customer.firstName ?? '';
        _lastNameController.text = customer.lastName ?? '';
        _emailController.text = customer.email ?? '';
        _phoneController.text = customer.phone != null ? customer.phone!.replaceFirst('+971', '') : '';
        _selectedDate = customer.birthDate;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile data: $e');
      setState(() => _isLoading = false);
      ToastUtils.showErrorToast('Failed to load profile data: ${e.toString()}');
    }
  }

  Future<void> _selectDate() async {
    // Calculate the date 18 years ago from today
    final DateTime now = DateTime.now();
    final DateTime maxDate = DateTime(now.year - 18, now.month, now.day);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? maxDate,
      firstDate: DateTime(1900),
      lastDate: maxDate,
      // Add custom validation message
      errorInvalidText: 'You must be at least 18 years old',
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Add +971 prefix to phone number if not already present
      String phoneNumber = _phoneController.text.trim();
      if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+971')) {
        phoneNumber = '+971$phoneNumber';
      }

      // Use AuthService instead of ApiService directly
      final authService = AuthService();
      final result = await authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: phoneNumber.isEmpty ? null : phoneNumber,
      );
      
      print('Profile updated successfully: $result');
      
      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success
      ToastUtils.showSuccessToast('Profile updated successfully');
    } catch (e) {
      print('Error updating profile: $e');
      if (!mounted) return;
      ToastUtils.showErrorToast('Failed to update profile: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      hintText: '55 555 5555',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+971',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 9) {
                          return 'Please enter a valid UAE phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      enabled: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        child: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                    if (FirebaseAuth.instance.currentUser?.providerData
                            .first.providerId !=
                        'google.com') ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement password reset
                        },
                        child: const Text('Reset Password'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
