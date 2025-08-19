class UserModel {
  final String id;
  final String username;
  final String email;
  final String token;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user']['id'],
      username: json['user']['username'],
      email: json['user']['email'],
      token: json['token'],
    );
  }
}
