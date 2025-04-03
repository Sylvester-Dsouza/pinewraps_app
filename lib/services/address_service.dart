import '../models/address.dart';
import 'api_service.dart';

class AddressService {
  final ApiService _apiService = ApiService();

  Future<Address> saveAddress(Address address) async {
    try {
      // If the address has an ID, it's an update, otherwise it's a new address
      if (address.id != null && address.id!.isNotEmpty) {
        return await _apiService.updateAddress(address.id!, address);
      } else {
        return await _apiService.addAddress(address);
      }
    } catch (e) {
      print('Error saving address: $e');
      rethrow;
    }
  }
}
