class AppUser {
  const AppUser({required this.uid, required this.phone, required this.name, this.email});

  final String uid;
  final String phone;
  final String name;
  final String? email;
}
