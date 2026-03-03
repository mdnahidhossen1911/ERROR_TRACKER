/// Optional user context attached to every error report.
/// Never store passwords or sensitive PII.
class UserInfo {
  const UserInfo({
    this.id,
    this.email,
    this.name,
    this.extra,
  });

  final String? id;
  final String? email;
  final String? name;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (extra != null) 'extra': extra,
      };
}
