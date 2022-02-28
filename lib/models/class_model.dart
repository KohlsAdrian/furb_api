class ClassModel {
  final List<String> teachers;
  final List<ClassStudentModel> students;

  ClassModel({this.teachers = const [], this.students = const []});
}

class ClassStudentModel {
  final String? name;
  final String? code;

  ClassStudentModel({this.name, this.code});
}
