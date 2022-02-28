import 'dart:async';

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:furb_api/models/timetable_model.dart';
import 'package:http/http.dart' as http;

enum TimetablePeriod {
  firstHalf,
  secondHalf,
}

class FurbApi {
  static const _redirectUrl =
      'https://www.furb.br/academico/servicosAcademicos';

  static const _uTimetable =
      'https://www.furb.br/academico/uHorario'; //get hidden student code (hacky)
  static const _loginUrl = 'https://www.furb.br/academico/validaLogon';
  static const _timetableUrl = 'https://www.furb.br/academico/userHorario';

  static String? _jSessionId;
  static String? _studentCode;

  static Map<String, String> get _sessionHeader =>
      {'Cookie': 'JSESSIONID=$_jSessionId'};

  static String? get jSessionID => _jSessionId;
  static String? get studentCode => _studentCode;

  static Future<bool> login({
    required String username,
    required String password,
  }) async {
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

          return _studentCode != null;
          /// end of Hacky way to get studentCode 💩
        }
      }
    }

    return false;
  }

  static Future<List<TimetableClassModel>?> getTimetable({
    int? year,
    TimetablePeriod? period,
  }) async {
    final now = DateTime.now();
    year ??= now.year;
    period ??=
        now.month < 6 ? TimetablePeriod.firstHalf : TimetablePeriod.secondHalf;

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
      final timetable = <TimetableClassModel>[];
      for (int i = 1; i < rows!.length - 3; i++) {
        final row = rows[i];
        final tds = row.findAll('td');
        timetable.add(TimetableClassModel(
          name: tds[1].text,
          course: tds[2].text,
          academicCredit: tds[3].text,
          financialCredit: tds[4].text,
          day0: tds[5]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
          day1: tds[6]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
          day2: tds[7]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
          day3: tds[8]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
          day4: tds[9]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
          day5: tds[10]
              .innerHtml
              .replaceAll('<br>', '_')
              .replaceAll('&nbsp;', '')
              .trim(),
        ));
      }
      return timetable;
    }
    return null;
  }
}
