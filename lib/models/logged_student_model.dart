class LoggedStudentModel {
  final String? name;
  final String? cep;
  final String? address;
  final String? number;
  final String? houseType;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zipcode;
  final String? phone;
  final String? cellphone;
  final String? companyName;
  final String? companyPhoneType;
  final String? username;
  final String? personEmail;
  final String? studentEmail;

  LoggedStudentModel({
    required this.name,
    required this.cep,
    required this.address,
    required this.number,
    required this.houseType,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.zipcode,
    required this.phone,
    required this.cellphone,
    required this.companyName,
    required this.companyPhoneType,
    required this.username,
    required this.personEmail,
    required this.studentEmail,
  });

  Map<String, String?> toMap() => {
        'cep': cep,
        'address': address,
        'number': number,
        'houseType': houseType,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'zipcode': zipcode,
        'phone': phone,
        'cellphone': cellphone,
        'companyName': companyName,
        'companyPhoneType': companyPhoneType,
        'username': username,
        'personEmail': personEmail,
        'studentEmail': studentEmail,
      };
}
