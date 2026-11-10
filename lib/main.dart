import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final store = PracticeStore(PreferencesRepository());
  await store.load();
  runApp(DiceMathApp(store: store));
}

class DiceMathApp extends StatelessWidget {
  const DiceMathApp({required this.store, super.key});
  final PracticeStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dice Math',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: HomeScreen(store: store),
  );
}
