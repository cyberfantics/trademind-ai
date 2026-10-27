import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Better than authStateChanges for email verification/profile reload changes.
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await _ensureUserDocument(credential.user);

    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'Account could not be created. Please try again.',
      );
    }

    await user.sendEmailVerification();

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email.trim(),
      'emailVerified': false,
      'role': 'user',
      'subscriptionStatus': 'free',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return credential;
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'Please login first.',
      );
    }

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'Please login again.',
      );
    }

    if (refreshedUser.emailVerified) {
      await markEmailVerified();
      return;
    }

    await refreshedUser.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;

    if (user == null) return false;

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null) return false;

    if (refreshedUser.emailVerified) {
      await markEmailVerified();
      return true;
    }

    return false;
  }

  Future<void> markEmailVerified() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'emailVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deleteCurrentUnverifiedAccount() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null) return;

    if (refreshedUser.emailVerified) {
      throw FirebaseAuthException(
        code: 'already-verified',
        message: 'Verified accounts cannot be deleted from this screen.',
      );
    }

    final uid = refreshedUser.uid;

    await _db.collection('users').doc(uid).delete().catchError((_) async {});

    await refreshedUser.delete();
  }

  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email,
        'emailVerified': user.emailVerified,
        'role': 'user',
        'subscriptionStatus': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'email': user.email,
        'emailVerified': user.emailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
