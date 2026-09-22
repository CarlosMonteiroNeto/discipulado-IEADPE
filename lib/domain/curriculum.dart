/// The fixed discipleship curriculum (S11).
///
/// Mirrors the Android `AULAS_DO_DISCIPULADO` array: a session advances one
/// lesson per concluded call, an unconcluded lesson continues into the next
/// part, and the last lesson never blocks a class (later parts continue).
library;

/// The 25 lessons in order, 0-indexed. The exact titles come from the
/// reference app's strings; any change here must be deliberate.
const List<String> curriculumLessons = <String>[
  'Introdução ao discipulado',
  'História das Assembleias de Deus',
  'Tendo uma nova conduta',
  'Superando conflitos e dúvidas',
  'Introdução à Bíblia',
  'Prova do ciclo básico',
  'Conhecendo Jesus',
  'O plano de Deus para a humanidade',
  'O que é salvação',
  'O que é pecado',
  'Santificação',
  'Obediência',
  'Oração',
  'O fruto do Espírito Santo',
  'Mordomia Cristã',
  'Prova do ciclo intermediário',
  'A Igreja (O corpo de Cristo)',
  'Doutrinas, costumes, e normas da igreja',
  'O batismo com o Espírito Santo',
  'A trindade divina',
  'Heresias (falsos ensinos)',
  'O final dos tempos',
  'Ordenanças bíblicas',
  'Evangelismo',
  'Prova do ciclo avançado',
];

/// The rendered topic of one session: "Aula N — Título" or, for a repeat part,
/// "Aula N — Título (parte M)".
String lessonTopic({required int lessonIndex, required int lessonPart}) {
  if (lessonIndex < 0 || lessonIndex >= curriculumLessons.length) {
    return 'Aula ${lessonIndex + 1} (parte $lessonPart)';
  }
  final String title = curriculumLessons[lessonIndex];
  if (lessonPart <= 1) {
    return 'Aula ${lessonIndex + 1} — $title';
  }
  return 'Aula ${lessonIndex + 1} — $title (parte $lessonPart)';
}

/// One completed session that carries lesson fields, used to derive the next
/// session's lesson. `lessonFinished` reflects the supervisor's conclusion at
/// the last attendance save.
class NextLesson {
  const NextLesson({
    required this.lessonIndex,
    required this.lessonPart,
    this.lessonFinished = false,
  });

  final int lessonIndex;
  final int lessonPart;
  final bool lessonFinished;
}

/// Derives the lesson for a new session from the class's history, in date
/// order: the most recent non-canceled session decides. An unconcluded lesson
/// continues into the next part; a concluded lesson advances one lesson; past
/// the curriculum end the last lesson keeps incrementing its part (never
/// blocks a class).
NextLesson nextLesson(List<NextLesson> prior) {
  if (prior.isEmpty) {
    return const NextLesson(lessonIndex: 0, lessonPart: 1);
  }
  final NextLesson last = prior.last;
  if (!last.lessonFinished) {
    return NextLesson(
      lessonIndex: last.lessonIndex,
      lessonPart: last.lessonPart + 1,
    );
  }
  if (last.lessonIndex + 1 < curriculumLessons.length) {
    return NextLesson(lessonIndex: last.lessonIndex + 1, lessonPart: 1);
  }
  return NextLesson(
    lessonIndex: last.lessonIndex,
    lessonPart: last.lessonPart + 1,
  );
}