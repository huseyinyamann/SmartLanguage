import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/oauth_clients.dart';

/// Kullanıcının girişi iptal ettiğini belirtir — arayüzde hata gösterilmez.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Giriş akışının kullanıcıya gösterilebilir hatası.
class SignInFailure implements Exception {
  const SignInFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Firebase Auth + Google Sign-In sarmalayıcısı.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  bool _initialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// google_sign_in 7.x tek seferlik kurulum ister.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _google.initialize(
      clientId: !kIsWeb && Platform.isIOS ? OAuthClients.iosClientId : null,
      serverClientId: OAuthClients.serverClientId,
    );
    _initialized = true;
  }

  /// Google hesabıyla giriş yapar ve Firebase oturumu açar.
  ///
  /// Kullanıcı vazgeçerse [SignInCancelled], başka bir sorunda
  /// [SignInFailure] fırlatır.
  Future<UserCredential> signInWithGoogle() async {
    final credential = await _googleCredential();
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw SignInFailure(_firebaseMessageFor(e));
    }
  }

  /// Apple hesabıyla giriş yapar ve Firebase oturumu açar.
  ///
  /// Kullanıcı vazgeçerse [SignInCancelled], başka bir sorunda
  /// [SignInFailure] fırlatır.
  Future<UserCredential> signInWithApple() async {
    final credential = await _appleCredential();
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw SignInFailure(_firebaseMessageFor(e));
    }
  }

  /// E-posta ve şifreyle giriş yapar.
  ///
  /// Hesap yoksa veya şifre yanlışsa [SignInFailure] fırlatır.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw SignInFailure(_firebaseMessageFor(e));
    }
  }

  /// E-posta ve şifreyle yeni hesap oluşturur ve oturum açar.
  ///
  /// E-posta zaten kullanımdaysa veya şifre çok zayıfsa [SignInFailure]
  /// fırlatır.
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw SignInFailure(_firebaseMessageFor(e));
    }
  }

  /// Firebase Auth kullanıcısını kalıcı olarak siler.
  ///
  /// Firestore verisi bu metottan **önce** ayrı olarak silinmelidir
  /// (`UserRepository.deleteAllData`) — kullanıcı silindikten sonra
  /// güvenlik kuralları kendi verisine bile erişimine izin vermez.
  ///
  /// Oturum yakın zamanda açılmadıysa Firebase yeniden kimlik doğrulama
  /// isteyebilir; bu durumda aynı sağlayıcıyla (Google/Apple) tekrar
  /// doğrulama istenir. Kullanıcı vazgeçerse [SignInCancelled], başka bir
  /// sorunda [SignInFailure] fırlatır.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        throw SignInFailure(_firebaseMessageFor(e));
      }

      final isApple = user.providerData.any((p) => p.providerId == 'apple.com');
      final credential = isApple
          ? await _appleCredential()
          : await _googleCredential();

      try {
        await user.reauthenticateWithCredential(credential);
        await user.delete();
      } on FirebaseAuthException catch (e2) {
        throw SignInFailure(_firebaseMessageFor(e2));
      }
    }

    // En iyi çaba: yerel Google yetkilendirmesini de iptal et. Hesap zaten
    // silindiği için burada başarısız olması kullanıcıya yansıtılmaz.
    try {
      await _ensureInitialized();
      await _google.disconnect();
    } catch (_) {
      // yut — hesap silme zaten tamamlandı.
    }
  }

  Future<AuthCredential> _googleCredential() async {
    await _ensureInitialized();

    if (!_google.supportsAuthenticate()) {
      throw const SignInFailure('Bu cihazda Google ile giriş desteklenmiyor.');
    }

    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      throw SignInFailure(_messageFor(e));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const SignInFailure(
        'Google kimlik bilgisi alınamadı, tekrar dener misin?',
      );
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  Future<AuthCredential> _appleCredential() async {
    final rawNonce = _generateNonce();
    final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelled();
      }
      throw SignInFailure(_appleMessageFor(e));
    }

    return OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _appleMessageFor(SignInWithAppleAuthorizationException e) =>
      switch (e.code) {
        AuthorizationErrorCode.canceled => 'Giriş iptal edildi.',
        AuthorizationErrorCode.failed =>
          'Giriş yapılamadı, tekrar dener misin?',
        AuthorizationErrorCode.invalidResponse =>
          'Apple girişinde bir sorun oluştu.',
        AuthorizationErrorCode.notHandled =>
          'Giriş isteği işlenemedi, tekrar dener misin?',
        AuthorizationErrorCode.notInteractive =>
          'Giriş ekranı açılamadı, tekrar dener misin?',
        _ => 'Giriş yapılamadı, tekrar dener misin?',
      };

  Future<void> signOut() async {
    await _ensureInitialized();
    await _google.signOut();
    await _auth.signOut();
  }

  String _messageFor(GoogleSignInException e) => switch (e.code) {
    GoogleSignInExceptionCode.canceled => 'Giriş iptal edildi.',
    GoogleSignInExceptionCode.interrupted =>
      'Bağlantı koptu, tekrar dener misin?',
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Uygulama yapılandırmasında bir sorun var.',
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google giriş yapılandırmasında bir sorun var.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Giriş ekranı açılamadı, tekrar dener misin?',
    _ => 'Giriş yapılamadı, tekrar dener misin?',
  };

  String _firebaseMessageFor(FirebaseAuthException e) => switch (e.code) {
    'account-exists-with-different-credential' =>
      'Bu e-posta başka bir giriş yöntemiyle kayıtlı.',
    'invalid-credential' => 'E-posta veya şifre hatalı.',
    'user-not-found' => 'Bu e-posta ile kayıtlı bir hesap bulunamadı.',
    'wrong-password' => 'Şifre hatalı, tekrar dener misin?',
    'email-already-in-use' => 'Bu e-posta zaten kullanımda.',
    'weak-password' => 'Şifre en az 6 karakter olmalı.',
    'invalid-email' => 'E-posta adresi geçersiz görünüyor.',
    'too-many-requests' =>
      'Çok fazla deneme yapıldı, biraz sonra tekrar dener misin?',
    'operation-not-allowed' => 'Bu giriş yöntemi şu anda kullanılamıyor.',
    'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
    'network-request-failed' => 'İnternet bağlantını kontrol edip tekrar dene.',
    _ => 'Giriş yapılamadı, tekrar dener misin?',
  };
}
