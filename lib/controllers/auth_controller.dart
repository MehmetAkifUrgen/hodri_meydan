import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../data/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

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
      );
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthController(this._authService, this._firestoreService)
    : super(const AsyncValue.data(null));

  Future<void> signInAnonymously() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInAnonymously();
      if (user != null) {
        await _firestoreService.saveUser(user);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        await _firestoreService.saveUser(user);
      }
    });
  }

  Future<void> linkAccount(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.linkWithEmail(email, password);
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
