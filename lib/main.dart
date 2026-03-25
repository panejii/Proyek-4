import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/helpers/log_helper.dart';
import 'package:logbook_app_020/features/onboarding/onboarding_view.dart';
import 'package:hive_flutter/hive_flutter.dart'; 

void main() async {
  // Wajib untuk operasi asinkron sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();
  // Load ENV
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  Hive.registerAdapter(LogbookAdapter()); // WAJIB: Sesuai nama di .g.dart
  await Hive.openBox<Logbook>(
    'offline_logs',
  );

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logbook App 020',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Menampilkan halaman onboarding sebagai awal
      home: const OnboardingView(),
    );
  }
}