import 'dart:convert';
import 'dart:io';

import 'package:furb_api/furb_api.dart';

void main(List<String> arguments) async {
  final env = Platform.environment;
  String? username = env['FURB_USERNAME'];
  String? password = env['FURB_PASSWORD'];

  while (username == null ||
      password == null ||
      username.isEmpty ||
      password.isEmpty) {
    print('username (without @furb.br): ');
    username = stdin.readLineSync(encoding: utf8);
    print('password: ');
    stdin.echoMode = false;
    password = stdin.readLineSync(encoding: utf8);
    stdin.echoMode = true;
  }
  final success = await FurbApi.login(username: username, password: password);
  if (success) {
    print(FurbApi.jSessionID);
    print(FurbApi.studentCode);

    await FurbApi.getBankslips();
    final timetable = await FurbApi.getTimetable();
    if (timetable != null) {
      await FurbApi.getClassFromTimetable(timetable.first);
      await FurbApi.getClassPlanFromTimetable(timetable.first);
    }
  }
}
