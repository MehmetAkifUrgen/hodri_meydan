import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../data/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
// firestoreServiceProvider is imported from firestore_service.dart

// Auth State Changes Stream
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Current User Stream (Firestore Data)
final userProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(firestoreServiceProvider).getUserStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(
        ref.watch(authServiceProvider),
        ref.watch(firestoreServiceProvider),
        ref.watch(notificationServiceProvider),
      );
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;

  AuthController(
    this._authService,
    this._firestoreService,
    this._notificationService,
  ) : super(const AsyncValue.data(null));

  Future<void> _saveFcmToken(User user) async {
    final token = await _notificationService.getToken();
    if (token != null) {
      await _firestoreService.saveFcmToken(user.uid, token);
    }
  }

  Future<void> signInAnonymously() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInAnonymously();
      if (user != null) {
        await _firestoreService.saveUser(user);
        await _saveFcmToken(user);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        await _firestoreService.saveUser(user);
        await _saveFcmToken(user);
      }
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInWithEmail(email, password);
      // Don't need to saveUser here usually as it might exist?
      // But update lastActive is good.
      if (user != null) {
        await _firestoreService.saveUser(user);
        await _saveFcmToken(user);
      }
    });
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signUpWithEmail(email, password);
      if (user != null) {
        // Update display name
        await user.updateDisplayName(username);
        // Save to Firestore
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
        // Re-fetch user to be sure? Actually just updating user object locally is fine but better to be safe.
        // Actually `user` object is fresh.
        // We need to create a UserModel with this username.
        // `saveUser` extracts data from `User` object.
        // So we must update the `User` object's displayName first.

        // Wait, `updateDisplayName` is async.
        // Let's create a customUserModel passed to saveUser?
        // `saveUser` takes `User`.
        // Let's manually creating the map?
        // Or simpler:
        await _firestoreService.saveUser(user, usernameOverride: username);
        await _saveFcmToken(user);
      }
    });
  }

  Future<void> linkAccount(
    String email,
    String password,
    String username,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.linkWithEmail(email, password);
      final user = _authService.currentUser;
      if (user != null) {
        await user.updateDisplayName(username);
        // Update existing user doc with new email and username
        // We use saveUser which handles "update but keep existing fields" via ID match
        // But saveUser logic:
        // if userDoc.exists -> updates 'lastActive'.
        // We want to force update username/email fields too.
        // Let's call a specific update or modify saveUser?
        // Actually, since UID is same, we just need to update specific fields.
        await _firestoreService.saveUser(user, usernameOverride: username);
        // Note: saveUser might need tweaking if it only updates 'lastActive' on existence.
        // Checking FirestoreService again:
        // if (exists) -> update('lastActive') only.
        // So we need to manually update email/username here or improve saveUser.
        // Let's doing it manually here for safety.
        await _firestoreService.updateUserProfile(user.uid, username, email);
      }
    });
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInWithApple();
      if (user != null) {
        await _firestoreService.saveUser(user);
        await _saveFcmToken(user);
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.signOut());
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = _authService.currentUser;
      if (user != null) {
        // 1. Delete Firestore Data
        await _firestoreService.deleteUserData(user.uid);
        // 2. Delete Auth Account
        await user.delete();
      }
    });
  }
}
