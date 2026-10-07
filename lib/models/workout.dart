class ExerciseEntry {
  ExerciseEntry({
    required this.id,
    required this.name,
    this.weight = '',
    this.reps = '',
    this.alternatives = const [],
    this.chosenName,
  });

  final String id;
  final String name;
  final String weight;
  final String reps;

  /// Other forms of the exercise, like "Dumbbell press" for "Bench press".
  /// Each form keeps its own logs.
  final List<String> alternatives;

  /// The form picked last time: [name] or one of [alternatives].
  final String? chosenName;

  /// [name] followed by its [alternatives].
  List<String> get forms => [name, ...alternatives];

  /// The form being trained. Falls back to [name] when the chosen
  /// alternative was removed.
  String get activeName {
    final chosen = chosenName;
    return chosen != null && alternatives.contains(chosen) ? chosen : name;
  }

  ExerciseEntry copyWith({
    String? id,
    String? name,
    String? weight,
    String? reps,
    List<String>? alternatives,
    String? chosenName,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      alternatives: alternatives ?? this.alternatives,
      chosenName: chosenName ?? this.chosenName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'reps': reps,
      'alternatives': alternatives,
      'chosenName': chosenName,
    };
  }

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as String?) ?? '',
      reps: (json['reps'] as String?) ?? '',
      alternatives:
          ((json['alternatives'] as List<dynamic>?) ?? const []).cast<String>(),
      chosenName: json['chosenName'] as String?,
    );
  }
}

class Workout {
  Workout({
    required this.id,
    required this.name,
    required this.exercises,
    required this.updatedAt,
    this.lastCompletedWeekKey,
  });

  final String id;
  final String name;
  final List<ExerciseEntry> exercises;
  final DateTime updatedAt;
  final String? lastCompletedWeekKey;

  Workout copyWith({
    String? id,
    String? name,
    List<ExerciseEntry>? exercises,
    DateTime? updatedAt,
    String? lastCompletedWeekKey,
    bool clearCompletedWeek = false,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCompletedWeekKey: clearCompletedWeek
          ? null
          : lastCompletedWeekKey ?? this.lastCompletedWeekKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'updatedAt': updatedAt.toIso8601String(),
      'lastCompletedWeekKey': lastCompletedWeekKey,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastCompletedWeekKey: json['lastCompletedWeekKey'] as String?,
      exercises: (json['exercises'] as List<dynamic>)
          .map((exercise) =>
              ExerciseEntry.fromJson(exercise as Map<String, dynamic>))
          .toList(),
    );
  }
}
