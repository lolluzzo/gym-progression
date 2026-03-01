import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartUpApp extends StatefulWidget {
  const StartUpApp({super.key});

  @override
  State<StartUpApp> createState() => _StartUpAppState();
}

class _StartUpAppState extends State<StartUpApp> {
  int _counter = 0;
  bool _isLoading = false;

  // Funzione per caricare i dati all'avvio
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Carica il valore salvato
  Future<void> _loadData() async {
    print("Inizio caricamento..."); // Debug in console
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      print("SharedPreferences istanziate correttamente");

      final savedValue = prefs.getInt('counter') ?? 0;

      setState(() {
        _counter = savedValue;
        _isLoading = false;
      });
      print("Caricamento completato: $_counter");
    } catch (e) {
      print("Errore durante il caricamento: $e");
      setState(() => _isLoading = false);
    }
  }

  // Salva e incrementa i dati
  Future<void> _incrementAndSave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _counter++;
    });
    await prefs.setInt('counter', _counter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gym Dashboard")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Qui puoi usare il tuo widget Loader.dart
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.fitness_center,
                      size: 50, color: Colors.orange),
                  const SizedBox(height: 20),
                  Text(
                    "Allenamenti completati: $_counter",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 30),
                  OutlinedButton.icon(
                    onPressed: _incrementAndSave,
                    icon: const Icon(Icons.add),
                    label: const Text("Registra Allenamento"),
                  ),
                  TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        _loadData();
                      },
                      child: const Text("Reset progressi",
                          style: TextStyle(color: Colors.red)))
                ],
              ),
      ),
    );
  }
}
