import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Tu od razu prosimy o scope do Sheets:
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Upewniamy się, że użytkownik jest zalogowany (jak nie – pokazuje okienko logowania).
  Future<GoogleSignInAccount?> ensureSignedIn() async {
    var user = _googleSignIn.currentUser;
    if (user != null) return user;

    // Spróbuj po cichu, jeśli już wcześniej dawał zgody
    user = await _googleSignIn.signInSilently();
    if (user != null) return user;

    // Jak nie – normalne logowanie
    return await _googleSignIn.signIn();
  }

  /// Pobieramy access token do użycia w Authorization: Bearer <token>
  Future<String?> getAccessToken() async {
    final user = await ensureSignedIn();
    if (user == null) return null;

    final auth = await user.authentication;
    return auth.accessToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
