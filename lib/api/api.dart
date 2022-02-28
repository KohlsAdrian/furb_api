import 'dart:async';

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:furb_api/models/bankslip_model.dart';
import 'package:furb_api/models/class_model.dart';
import 'package:furb_api/models/plan_model.dart';
import 'package:furb_api/models/timetable_model.dart';
import 'package:http/http.dart' as http;

enum TimetablePeriod {
  firstHalf,
  secondHalf,
}

class FurbApi {
  static const _base = 'https://www.furb.br';
  static const _redirectUrl = '$_base/academico/servicosAcademicos';

  static const _uTimetable =
      '$_base/academico/uHorario'; //get hidden student code (hacky)
  static const _uFinancial =
      '$_base/academico/uFinanca'; //get hidden codes for query (hacky)

  static const _loginUrl = '$_base/academico/validaLogon';
  static const _timetableUrl = '$_base/academico/userHorario';
  static const _bankslipUrl = '$_base/academico/consaFinanca';

  static String? _jSessionId;
  static String? _studentCode;

  static Map<String, String> get _sessionHeader =>
      {'Cookie': 'JSESSIONID=$_jSessionId'};

  static String? get jSessionID => _jSessionId;
  static String? get studentCode => _studentCode;

  static Timer? _refresh;

  static Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      var response = await http.post(
        Uri.parse(_loginUrl),
        body: {
          'nm_login': username,
          'ds_senha': password,
          'nome_servlet': _redirectUrl,
        },
      );
      if (response.statusCode == 302) {
        final location = response.headers['location'];
        if (location != null && location.contains('jsessionid')) {
          final cookie = response.headers['set-cookie'];
          _jSessionId = cookie?.split(';').first.replaceAll('JSESSIONID=', '');

          /// Hacky way to get studentCode 💩
          response = await http.get(
            Uri.parse('$_uTimetable;JSESSIONID=$_jSessionId'),
            headers: _sessionHeader,
          );
          if (response.statusCode == 200) {
            final body = response.body;
            final page = BeautifulSoup(body);
            final input = page.find('input', attrs: {'name': 'cd_aluno'});
            _studentCode = input?['value'];

            if (_studentCode != null && _jSessionId != null) {
              _refresh = Timer.periodic(Duration(minutes: 1), (timer) {
                login(username: username, password: password);
                print('refreshed session');
              });

              return true;
            }

            /// end of Hacky way to get studentCode 💩
          }
        }
      }
    } catch (e) {
      print(e);
    }

    return false;
  }

  static Future<List<BankslipModel>?> getBankslips() async {
    try {
      var response = await http.get(
        Uri.parse(_uFinancial),
        headers: _sessionHeader,
      );

      if (response.statusCode == 200) {
        var body = response.body;
        var page = BeautifulSoup(body);

        final link =
            page.findAll('input', attrs: {'name': 'vinculo'}).first['value'];
        final name =
            page.findAll('input', attrs: {'name': 'nome'}).first['value'];
        final course =
            page.findAll('input', attrs: {'name': 'curso'}).first['value'];
        final courseType =
            page.findAll('input', attrs: {'name': 'ds_vinculo'}).first['value'];

        response = await http.post(
          Uri.parse(_bankslipUrl),
          headers: _sessionHeader,
          body: {
            'vinculo': link,
            'nome': name,
            'curso': course,
            'ds_vinculo': courseType,
          },
        );

        if (response.statusCode == 200) {
          body = response.body;
          page = BeautifulSoup(body);

          final tables = page.findAll('table');
          final rows = tables.last.findAll('tr').toList();

          final bankslips = <BankslipModel>[];

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            final tds = row.findAll('td');
            bankslips.add(BankslipModel(
              expireDate: tds[0].text.trim(),
              healthInsurance: tds[1].text.trim(),
              value: tds[2].text.trim(),
              discount: tds[3].text.trim(),
              deduction: tds[4].text.trim(),
              addition: tds[5].text.trim(),
              penalty: tds[6].text.trim(),
              paymentDate: tds[7].text.trim(),
              paidValue: tds[8].text.trim(),
              url: tds[9].find('a')?['href'],
            ));
          }
          return bankslips;
        }
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  static Future<List<PlanModel>?> getClassPlanFromTimetable(
    TimetableModel timetableModel,
  ) async {
    try {
      final url = '$_base${timetableModel.coursePlan}';
      final response = await http.get(
        Uri.parse(url),
        headers: _sessionHeader,
      );

      if (response.statusCode == 200) {
        final body = response.body;
        final page = BeautifulSoup(body);

        final tables = page.findAll('table', attrs: {'border': '1'});

        final sections = <PlanModel>[];

        for (final table in tables) {
          List<String> newSections = [];
          final plaintText = table.getText();
          newSections.addAll(plaintText.split('\n'));
          newSections.removeWhere((element) => element.isEmpty);
          sections.add(PlanModel(sections: newSections));
        }
        return sections;
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  static Future<ClassModel?> getClassFromTimetable(
    TimetableModel timetableModel,
  ) async {
    try {
      final url = '$_base${timetableModel.courseClass}';
      final response = await http.get(
        Uri.parse(url),
        headers: _sessionHeader,
      );

      if (response.statusCode == 200) {
        final body = response.body;
        final page = BeautifulSoup(body);

        final tables = page.findAll('table');

        final teachers = tables[0]
            .findAll('font')
            .where((e) => e.findAll('b').isEmpty)
            .map((e) => e.text)
            .toList();

        final mStudents = tables[3]
            .findAll('font')
            .where((e) => e.findAll('b').isEmpty)
            .toList();

        final students = <ClassStudentModel>[];
        for (int i = 0; i < mStudents.length; i += 2) {
          final name = mStudents[i].text;
          final code = mStudents[i + 1].text;
          students.add(ClassStudentModel(name: name, code: code));
        }
        return ClassModel(
          teachers: teachers,
          students: students,
        );
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  static Future<List<TimetableModel>?> getTimetable({
    int? year,
    TimetablePeriod? period,
  }) async {
    try {
      final now = DateTime.now();
      year ??= now.year;
      period ??= now.month < 6
          ? TimetablePeriod.firstHalf
          : TimetablePeriod.secondHalf;

      final url = '$_timetableUrl;JSESSIONID=$_jSessionId';
      final response = await http.post(
        Uri.parse(url),
        headers: _sessionHeader,
        body: {
          'cd_aluno': _studentCode,
          'dt_anoati': '$year',
          'dt_semati': (period.index + 1).toString(),
        },
      );
      if (response.statusCode == 200) {
        final body = response.body;
        final page = BeautifulSoup(body);
        final table = page.find('table', attrs: {'class': 'bodyTable'});
        final rows = table?.findAll('tr');
        final timetable = <TimetableModel>[];
        for (int i = 1; i < rows!.length - 3; i++) {
          final row = rows[i];
          final tds = row.findAll('td');
          timetable.add(TimetableModel(
            coursePlan: tds[0].find('a')?['href'],
            courseClass: tds[1].find('a')?['href'],
            name: tds[1].text,
            course: tds[2].text,
            academicCredit: tds[3].text,
            financialCredit: tds[4].text,
            day0: _clearDirt(tds[5].innerHtml),
            day1: _clearDirt(tds[6].innerHtml),
            day2: _clearDirt(tds[7].innerHtml),
            day3: _clearDirt(tds[8].innerHtml),
            day4: _clearDirt(tds[9].innerHtml),
            day5: _clearDirt(tds[10].innerHtml),
          ));
        }
        return timetable;
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  Future<bool> logout() async {
    _studentCode = null;
    _jSessionId = null;
    _refresh?.cancel();
    _refresh = null;
    return true;
  }

  static String _clearDirt(String content) =>
      content.replaceAll('<br>', '_').replaceAll('&nbsp;', '').trim();
}
