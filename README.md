# gym_progression

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## MVP
1. Definisci il "Core" (MVP)
Prima di aggiungere grafici complicati, focalizzati sulle funzioni vitali. Per un'app di palestra, di solito sono:

Log degli allenamenti: Creazione di schede e inserimento pesi/ripetizioni.

Database esercizi: Una lista (anche statica all'inizio) con nomi e categorie (Petto, Dorso, ecc.).

Timer di recupero: Un piccolo widget essenziale tra una serie e l'altra.

2. Architettura e Stato (Fondamentale)
Non scrivere tutto in un unico file. Scegli subito come gestire i dati.

State Management: Ti consiglio Riverpod (moderno e robusto) o Provider (più semplice per iniziare). Evita di gestire tutto con setState se l'app crescerà.

Cartelle: Organizza il progetto in modo pulito:

/models: Le classi dei dati (es. Exercise, Workout).

/screens: Le pagine dell'app.

/widgets: Componenti riutilizzabili (es. il bottone personalizzato).

/services: Logica per database o API.

3. Il Database Locale
Un'app di palestra deve funzionare offline. Non vuoi che l'utente si blocchi perché il Wi-Fi della sala pesi non prende.

Isar o Hive: Database NoSQL velocissimi e facili da usare in Flutter.

SQLite (sqflite): Se preferisci il classico approccio relazionale.

4. UI/UX: Il "Look & Feel"
Le app di fitness hanno spesso un design scuro (Dark Mode) o molto energico.

Usa i Material 3 widget (già inclusi in Flutter).

Sfrutta pacchetti come fl_chart se vuoi mostrare i progressi del peso nel tempo.