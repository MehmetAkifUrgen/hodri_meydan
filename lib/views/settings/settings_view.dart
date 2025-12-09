import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_view.dart';
import 'feedback_view.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1121),
      appBar: AppBar(
        title: Text(
          'Ayarlar',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Audio Settings
            _SettingsSection(
              title: "SES & TİTREŞİM",
              children: [
                _SettingsTile(
                  icon: Icons.volume_up,
                  title: "Ses Efektleri",
                  value: settingsState.isSoundEnabled,
                  onChanged: (val) => settingsController.toggleSound(val),
                ),
                _SettingsTile(
                  icon: Icons.music_note,
                  title: "Müzik",
                  value: settingsState.isMusicEnabled,
                  onChanged: (val) => settingsController.toggleMusic(val),
                ),
                _SettingsTile(
                  icon: Icons.vibration,
                  title: "Titreşim", // Haptic Feedback
                  value: settingsState.isVibrationEnabled,
                  onChanged: (val) => settingsController.toggleVibration(val),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Support Settings
            _SettingsSection(
              title: "DESTEK",
              children: [
                ListTile(
                  leading: const Icon(Icons.feedback, color: Color(0xFF00F6FF)),
                  title: const Text(
                    "Öneri & Şikayet",
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackView()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Account Settings
            _SettingsSection(
              title: "HESAP",
              children: [
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text(
                    "Çıkış Yap",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginView()),
                        (route) => false,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    "Hesabı Sil",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    // Show Confirmation Dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const Text(
                          "Hesabı Sil",
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          "Bu işlem geri alınamaz. Tüm puanlarınız ve verileriniz silinecek. Emin misiniz?",
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("İptal"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context); // Close dialog
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .deleteAccount();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginView(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              "Sil",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Hodri Meydan v1.0.0",
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withAlpha(150),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      activeTrackColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
