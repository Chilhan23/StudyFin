class StudySession {
  final int? studyId; 
  final String subject;
  final String topic;
  final int durationMinutes;
  final DateTime date;
  final bool isDone;

  StudySession({
    this.studyId,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    required this.date,
    this.isDone = false, 
  });

  Map<String, dynamic> toMap() {
    return {
      'studyId': studyId,
      'subject': subject,
      'topic': topic,
      'durationMinutes': durationMinutes,
      'date': date.toIso8601String(),
      'isDone': isDone ? 1 : 0,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      studyId: map['studyId'] as int?,
      subject: map['subject'] as String,
      topic: map['topic'] as String,
      durationMinutes: map['durationMinutes'] as int,
      date: DateTime.parse(map['date'] as String),
      isDone: (map['isDone'] as int) == 1, 
    );
  }

  StudySession copyWith({
    int? studyId,
    String? subject,
    String? topic,
    int? durationMinutes,
    DateTime? date,
    bool? isDone,
  }) {
    return StudySession(
      studyId: studyId ?? this.studyId,
      subject: subject ?? this.subject,
      topic: topic ?? this.topic,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date ?? this.date,
      isDone: isDone ?? this.isDone,
    );
  }
}