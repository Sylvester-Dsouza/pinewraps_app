import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:line_icons/line_icons.dart';
import 'config/environment.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/order_confirmation/order_confirmation_screen.dart';
import 'screens/payment/order_success_screen.dart';
import 'screens/payment/order_failed_screen.dart';
import 'screens/orders/order_history_screen.dart';
import 'screens/notifications/notification_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Flutter binding initialized");
  
  try {
    print("Initializing Firebase...");
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }
  
  // Set up the environment
  print("Setting up environment");
  setupEnvironment();
  
  // Initialize notification service
  try {
    print("Initializing notification service");
    await NotificationService().initialize();
    print("Notification service initialized");
  } catch (e) {
    print("Error initializing notification service: $e");
  }
  
  print("Running app");
  runApp(const MyApp());
}

// Helper function to set up the appropriate environment
void setupEnvironment() {
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  if (isProduction) {
    // Production mode
    EnvironmentConfig.setEnvironment(Environment.production);
    print('🚀 Running in PRODUCTION mode - Using API: ${EnvironmentConfig.apiBaseUrl}');
  } else {
    // Development mode
    EnvironmentConfig.setEnvironment(Environment.development);
    
    // Check if running in an emulator
    const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
    if (useEmulator) {
      EnvironmentConfig.useEmulator(true);
      EnvironmentConfig.usePhysicalDevice(false);
      print('🛠️ Running in DEVELOPMENT mode with EMULATOR - Using API: ${EnvironmentConfig.apiBaseUrl}');
    } else {
      // Check for physical device vs web/desktop
      const bool usePhysicalDevice = bool.fromEnvironment('USE_PHYSICAL_DEVICE', defaultValue: true);
      EnvironmentConfig.usePhysicalDevice(usePhysicalDevice);
      
      if (usePhysicalDevice) {
        print('📱 Running in DEVELOPMENT mode on PHYSICAL DEVICE - Using API: ${EnvironmentConfig.apiBaseUrl}');
      } else {
        print('🛠️ Running in DEVELOPMENT mode with LOCALHOST - Using API: ${EnvironmentConfig.apiBaseUrl}');
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: MaterialApp(
        title: 'Pinewraps',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF000000), // Black
            primary: const Color(0xFF000000), // Black
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/home': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            final initialTab = args?['initialTab'] as int?;
            return MainScreen(initialTab: initialTab);
          },
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/order-confirmation': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
            return OrderConfirmationScreen(orderId: args['orderId']);
          },
          '/order-success': (context) => const OrderSuccessScreen(),
          '/order-failed': (context) => const OrderFailedScreen(),
          '/shop': (context) => const ShopScreen(),
          '/profile/orders': (context) => const OrderHistoryScreen(),
          '/login': (context) => const LoginScreen(),
          '/notifications': (context) => const NotificationScreen(),
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int? initialTab;
  
  const MainScreen({
    super.key,
    this.initialTab,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  final CartService _cartService = CartService();
  bool _mounted = true;

  void setIndex(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _cartService.addListener(_onCartUpdate);
    
    // Set initial tab if provided
    if (widget.initialTab != null) {
      selectedIndex = widget.initialTab!;
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _cartService.removeListener(_onCartUpdate);
    super.dispose();
  }

  void _onCartUpdate() {
    if (_mounted) {
      setState(() {});
    }
  }

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    ShopScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = _cartService.cartItems.length;

    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(LineIcons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LineIcons.shoppingBag),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(LineIcons.shoppingCart),
                if (cartItemCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cartItemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LineIcons.user),
            label: 'Profile',
          ),
        ],
        currentIndex: selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
