class LoginController {
  // Multiple user (username : password)
  final Map<String, String> users = {
    'admin': '12345',
    'paneji': 'password',
    'bwabwa': 'password',
  };

  int failedAttempts = 0;
  bool isLocked = false;

  bool validateLogin(String username, String password) {
    if (users.containsKey(username) && users[username] == password) {
      failedAttempts = 0;
      return true;
    } else {
      failedAttempts++;
      return false;
    }
  }

  bool shouldLock() => failedAttempts >= 3;
}
