class LoginController {
  // Data user lengkap: username -> {password, uid, role, teamId}
  final Map<String, Map<String, String>> users = {
    'admin': {
      'password': '12345',
      'uid': 'uid_admin_001',
      'role': 'Ketua',
      'teamId': 'Tim_1',
    },
    'paneji': {
      'password': 'password',
      'uid': 'uid_paneji_002',
      'role': 'Anggota',
      'teamId': 'Tim_1',
    },
    'bwabwa': {
      'password': 'password',
      'uid': 'uid_bwabwa_003',
      'role': 'Anggota',
      'teamId': 'Tim_2',
    },
  };

  int failedAttempts = 0;

  // Kembalikan data user lengkap jika login sukses, null jika gagal
  Map<String, String>? validateLogin(String username, String password) {
    final userData = users[username];
    if (userData != null && userData['password'] == password) {
      failedAttempts = 0;
      return {
        'username': username,
        'uid': userData['uid']!,
        'role': userData['role']!,
        'teamId': userData['teamId']!,
      };
    } else {
      failedAttempts++;
      return null;
    }
  }

  bool shouldLock() => failedAttempts >= 3;
}