class UserModel {
  final String uid;
  final String username;
  final String email;
  final String image;
  final int playerRating;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.image = '',
    this.playerRating = 1200,

  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['id'],
      username: json['username'],
      email: json['email'],
      image: json['image'] ?? '',
      playerRating: json['playerRating'] ?? 1200,
    );
  }

}


// class UserModel {
//   final String id;
//   final String username;
//   final String email;
//   final String token;

//   UserModel({
//     required this.id,
//     required this.username,
//     required this.email,
//     required this.token,
//   });

//   factory UserModel.fromJson(Map<String, dynamic> json) {
//     return UserModel(
//       id: json['user']['id'],
//       username: json['user']['username'],
//       email: json['user']['email'],
//       token: json['token'],
//     );
//   }
// }
