import 'dart:async';

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:furb_api/furb_api.dart';
import 'package:http/http.dart' as http;

enum TimetablePeriod {
  firstHalf,
  secondHalf,
}

class FurbApi {
  static const _base = 'https://www.furb.br/academico';
  static const _redirectUrl = '$_base/servicosAcademicos';

  static const _uTimetable =
      '$_base/uHorario'; //get hidden student code (hacky)
  static const _uFinancial =
      '$_base/uFinanca'; //get hidden codes for query (hacky)

  static const _loginUrl = '$_base/validaLogon';
  static const _timetableUrl = '$_base/userHorario';
  static const _bankslipUrl = '$_base/consaFinanca';
  static const _studentUrl = '$_base/alteraEndereco1';

  static String? _jSessionId;
  static String? _studentCode;
  static LoggedStudentModel? _loggedStudent;

  static Map<String, String> get _sessionHeader =>
      {'Cookie': 'JSESSIONID=$_jSessionId'};

  static String? get jSessionID => _jSessionId;
  static String? get studentCode => _studentCode;
  static LoggedStudentModel? get loggedStudent => _loggedStudent;

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
              final studentModel = await _getStudent();
              _loggedStudent = studentModel;
              return _loggedStudent != null;
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

  static Future<LoggedStudentModel?> _getStudent() async {
    try {
      final response = await http.get(
        Uri.parse(_studentUrl),
        headers: _sessionHeader,
      );

      if (response.statusCode == 200) {
        var body = response.body;
        var page = BeautifulSoup(body);

        final table = page.find('table');
        final tr = table?.findAll('tr');
        if (tr != null) {
          final studentModel = LoggedStudentModel(
            cep: tr[1].findAll('td')[1].text,
            address: tr[2].findAll('td')[1].text,
            number: tr[3].findAll('td')[1].text,
            houseType: tr[4].findAll('td')[1].text,
            neighborhood: tr[5].findAll('td')[1].text,
            city: tr[6].findAll('td')[1].text,
            state: tr[7].findAll('td')[1].text,
            zipcode: tr[8].findAll('td')[1].text,
            phone: tr[9].findAll('td')[1].text,
            cellphone: tr[10].findAll('td')[1].text,
            companyName: tr[11].findAll('td')[1].text,
            companyPhoneType: tr[12].findAll('td')[1].text.trim(),
            username: tr[13].findAll('td')[1].text,
            personEmail: tr[14].findAll('td')[1].text,
            studentEmail: tr[15].findAll('td')[1].text,
          );
          return studentModel;
        }
      }
    } catch (e) {
      print(e.toString());
    }
    return null;
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

  static Future<PlanModel?> getClassPlanFromTimetable(
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

        final mainDiv = page.find('div', id: 'modificado');
        final tables = mainDiv?.findAll('table', attrs: {'border': '1'});
        if (tables == null) return null;

        final sections = <List<String>>[];

        for (final table in tables) {
          List<String> newSections = [];
          final plaintText = table.text;
          newSections.addAll(plaintText.split('\n'));
          newSections.removeWhere((element) => element.isEmpty);
          sections.add(newSections);
        }
        return PlanModel(
          rawPage: mainDiv?.innerHtml,
          sections: sections,
        );
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
            day0: _clearTags(tds[5].innerHtml),
            day1: _clearTags(tds[6].innerHtml),
            day2: _clearTags(tds[7].innerHtml),
            day3: _clearTags(tds[8].innerHtml),
            day4: _clearTags(tds[9].innerHtml),
            day5: _clearTags(tds[10].innerHtml),
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
    return true;
  }

  static String _clearTags(String content) => content
      .replaceAll('<br>', '\n')
      .replaceAll('&nbsp;&nbsp;', '\n')
      .replaceAll('&nbsp;', '\n');
}
