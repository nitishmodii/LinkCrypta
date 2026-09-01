import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'services/encryption_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/activity_log_service.dart';
import 'services/autofill_framework_service.dart';
import 'services/browser_extension_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/master_password_screen.dart';
import 'screens/home/profile/privacy_policy_screen.dart';
import 'screens/home/profile/terms_of_service_screen.dart';
import 'screens/home/profile/about_screen.dart';
import 'screens/browser_extension_screen.dart';
import 'utils/constants.dart';
import 'utils/googlesign.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  
  try {
    // Initialize Hive
    await Hive.initFlutter();
    
    // Initialize services
    await GoogleSignInService.initialize();
    await StorageService.initialize();
    await SyncService.initialize();
    await ActivityLogService.initialize();
    
    // Auto-start Browser Extension server
    BrowserExtensionService().startServer().catchError((e) {
      print('Browser extension service auto-start failed: $e');
    });
    
    runApp(const LinkCryptaApp());
  } catch (e) {
    print('Error initializing app: $e');
    // Still run the app even if services fail to initialize
    runApp(const LinkCryptaApp());
  }
}

class LinkCryptaApp extends StatefulWidget {
  const LinkCryptaApp({super.key});

  @override
  State<LinkCryptaApp> createState() => _LinkCryptaAppState();
}

class _LinkCryptaAppState extends State<LinkCryptaApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize AutofillFrameworkService after the first frame so the
    // Provider (DataProvider) is available in the widget tree. This will
    // register method call handlers and sync stored passwords to the
    // platform autofill storage so the Android AutofillService can query
    // and request save/import actions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final navContext = _navigatorKey.currentContext;
        if (navContext != null) {
          final dataProvider = Provider.of<DataProvider>(navContext, listen: false);
          AutofillFrameworkService.instance.initialize(dataProvider).catchError((e) {
            print('AutofillFramework: initialize error: $e');
          });
        } else {
          print('AutofillFramework: navigator context not available on init');
        }
      } catch (e) {
        print('AutofillFramework: Failed to schedule initialize: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When the app resumes, attempt to import any new credentials saved by the
      // Android Autofill Service so they show up in the app without manual steps.
      try {
        final navContext = _navigatorKey.currentContext;
        if (navContext != null) {
          final dataProvider = Provider.of<DataProvider>(navContext, listen: false);
          AutofillFrameworkService.instance.forceImportNewCredentials(dataProvider).catchError((e) {
          // Log error, but don't crash on lifecycle events
          print('Lifecycle importNewCredentials error: $e');
          });
        }
      } catch (e) {
        print('Error triggering autofill import on resume: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Get the base themes
          final lightTheme = _buildLightTheme();
          final darkTheme = _buildDarkTheme();
          
          // Apply color scheme and text scale factor
          final Color primaryColor = themeProvider.getPrimaryColor();
          final textScaleFactor = themeProvider.textScaleFactor;
          
          // Create modified light theme
          final modifiedLightTheme = lightTheme.copyWith(
            colorScheme: lightTheme.colorScheme.copyWith(
              primary: primaryColor,
              secondary: primaryColor.withOpacity(0.8),
              tertiary: primaryColor.withOpacity(0.6),
            ),
            textTheme: lightTheme.textTheme,
          );
          
          // Create modified dark theme
          final modifiedDarkTheme = darkTheme.copyWith(
            colorScheme: darkTheme.colorScheme.copyWith(
              primary: primaryColor,
              secondary: primaryColor.withOpacity(0.8),
              tertiary: primaryColor.withOpacity(0.6),
            ),
            textTheme: darkTheme.textTheme,
          );
          
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: modifiedLightTheme,
            darkTheme: modifiedDarkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScaleFactor),
                ),
                child: child!,
              );
            },
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/login': (context) => const LoginScreen(),
          '/master-password': (context) => const MasterPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/privacy-policy': (context) => const PrivacyPolicyScreen(),
          '/terms-of-service': (context) => const TermsOfServiceScreen(),
          '/about': (context) => const AboutScreen(),
          '/browser-extension': (context) => const BrowserExtensionScreen(),
        },
      );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.light,
        background: AppConstants.backgroundColor,
        surface: AppConstants.surfaceColor,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppConstants.primaryColor,
        titleTextStyle: AppConstants.titleLarge.copyWith(
          color: AppConstants.primaryColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.dark,
        background: const Color(0xFF0F172A),
        surface: const Color(0xFF1E293B),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: AppConstants.titleLarge.copyWith(
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        color: const Color(0xFF1E293B),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade900,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
