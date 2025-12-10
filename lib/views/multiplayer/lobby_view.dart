import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/multiplayer_controller.dart';
import '../../services/ad_service.dart';
import '../../services/firestore_service.dart';
import 'multiplayer_quiz_view.dart';
import '../minigame/multiplayer_name_city_view.dart';
import '../../controllers/auth_controller.dart';

class LobbyView extends ConsumerStatefulWidget {
  const LobbyView({super.key});

  @override
  ConsumerState<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends ConsumerState<LobbyView> {
  final TextEditingController _codeController = TextEditingController();

  void _showNoLivesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Yetersiz Can!",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Oyuna girmek için canınız yetersiz. Reklam izleyerek can kazanabilirsiniz.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tamam", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _watchAdForLife(context);
            },
            child: const Text("İzle (+3 ❤️)"),
          ),
        ],
      ),
    );
  }

  void _watchAdForLife(BuildContext context) {
    final controller = ref.read(multiplayerControllerProvider.notifier);
    final uid = controller.userId;

    ref
        .read(adServiceProvider)
        .showRewardedAdWaitIfNeeded(
          context,
          onUserEarnedReward: (reward) {
            ref.read(firestoreServiceProvider).updateLives(uid, 3);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tebrikler! +3 Can kazandın."),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
  }

  void _checkLivesAndAction(VoidCallback action) {
    final userAsync = ref.read(userProvider);
    final user = userAsync.value;

    if (user != null && user.lives > 0) {
      action();
    } else {
      _showNoLivesDialog(context);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multiplayerControllerProvider);
    final controller = ref.read(multiplayerControllerProvider.notifier);

    // Listen for errors
    ref.listen<MultiplayerState>(multiplayerControllerProvider, (
      previous,
      next,
    ) {
      // Error Handling
      if (next.error != null && next.error != previous?.error) {
        // Check if it's a "no lives" error for multiplayer
        if (next.error!.contains('canı yok') ||
            next.error!.contains('Canı yok')) {
          _showNoLivesDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Info/Status Handling
      if (next.statusMessage != null &&
          next.statusMessage != previous?.statusMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.statusMessage!),
            backgroundColor: Colors.blueAccent, // Use Blue for info
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // IF in a room, show Waiting Room UI (Modern Design)
    if (state.currentRoomId != null) {
      return _buildWaitingRoom(
        context,
        state.currentRoomId!,
        controller,
        state,
      );
    }

    // ELSE show Join/Create UI (Modern Design)
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'ÇOK OYUNCULU',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          // Add subtle background gradients if needed used in design
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 80), // Top spacing for AppBar
                    // Actions Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernActionCard(
                                  context,
                                  title: 'ODA KUR',
                                  subtitle: 'Arkadaşlarınla',
                                  icon: Icons.add_circle_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                  onTap: state.isLoading
                                      ? null
                                      : () => _checkLivesAndAction(
                                          () => controller.createRoom(),
                                        ),
                                  isSmall: true,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildModernActionCard(
                                  context,
                                  title: 'HIZLI OYNA',
                                  subtitle: 'Rastgele Katıl',
                                  icon: Icons.flash_on,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  onTap: state.isLoading
                                      ? null
                                      : () => _checkLivesAndAction(
                                          () => controller.quickMatch(),
                                        ),
                                  isSmall: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Explicit Join Button
                          GestureDetector(
                            onTap: () => _checkLivesAndAction(
                              () => _showJoinByCodeDialog(context, controller),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF191834).withAlpha(150),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withAlpha(30),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.keyboard,
                                      color: Colors.purple,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'KODLA KATIL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Text(
                                        'Oda kodu gir',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white24,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Active Rooms Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AÇIK ODALAR',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.dialpad,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              _checkLivesAndAction(() {
                                _showJoinByCodeDialog(context, controller);
                              });
                            },
                            tooltip: 'Kod ile Katıl',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Active Rooms List
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: controller.availableRoomsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'Hata: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final rooms = snapshot.data ?? [];

                  if (rooms.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 64,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Açık oda yok',
                                style: TextStyle(color: Colors.white24),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final room = rooms[index];
                      final players = room['players'] as List;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 6,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF191834).withAlpha(150),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.tag,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Oda #${room['id']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${players.length}/8 Oyuncu',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  controller.joinRoom(room['id']);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withAlpha(20),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('KATIL'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: rooms.length),
                  );
                },
              ),

              if (state.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom(
    BuildContext context,
    String roomId,
    MultiplayerController controller,
    MultiplayerState state,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: controller.roomStream(roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Let local state clear via controller update
                controller.onRoomClosed();
              });
              return const Center(child: CircularProgressIndicator());
            }

            final players = List<String>.from(data['players'] ?? []);
            final playersData =
                data['playersData'] as Map<String, dynamic>? ?? {};
            final readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
            final hostId = data['hostId'] as String?;
            final selectedCategory =
                data['selectedCategory'] as String? ?? 'Genel';
            final isHost = hostId == controller.userId;
            final isReady = readyPlayers.contains(controller.userId);

            final gameType = data['gameType'] as String? ?? 'quiz';

            // Check if game started
            if (data['status'] == 'playing') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Deduct Life locally before entering game
                debugPrint("DEBUG: Deducting life for Quiz mode (Client-side)");
                ref
                    .read(firestoreServiceProvider)
                    .updateLives(controller.userId, -1);

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MultiplayerQuizView(roomId: roomId),
                  ),
                );
              });
            } else if (data['status'] == 'playing_nameCity') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Deduct Life locally before entering game
                debugPrint(
                  "DEBUG: Deducting life for NameCity mode (Client-side)",
                );
                ref
                    .read(firestoreServiceProvider)
                    .updateLives(controller.userId, -1);

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MultiplayerNameCityView(
                      roomId: roomId,
                      letters: List<String>.from(data['letters'] ?? []),
                      initialRound: data['currentRound'] ?? 1,
                      endTime: data['endTime'] ?? 0,
                      initialCategories: List<String>.from(
                        data['currentCategories'] ?? [],
                      ),
                      gameDuration: data['gameDuration'] as int? ?? 60,
                    ),
                  ),
                );
              });
            }

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => controller.leaveRoom(),
                      ),
                      Expanded(
                        child: Text(
                          'LOBİ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Room Code & Category (Combined Card)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF191834).withAlpha(128),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(80),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Room Code & Game Type
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ODA KODU',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    roomId,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Game Type Selector
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'OYUN TÜRÜ',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isHost)
                                DropdownButton<String>(
                                  value: gameType,
                                  dropdownColor: const Color(0xFF1E293B),
                                  underline: Container(),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onChanged: (val) {
                                    if (val != null) {
                                      controller.setGameType(roomId, val);
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'quiz',
                                      child: Text('Bilgi Yarışması'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'nameCity',
                                      child: Text('İsim Şehir'),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  gameType == 'nameCity'
                                      ? 'İsim Şehir'
                                      : 'Bilgi Yarışması',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),

                      // Options (Category or Duration)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (gameType == 'nameCity') ...[
                            const Text(
                              'SÜRE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isHost)
                              DropdownButton<int>(
                                value: (data['gameDuration'] as int?) ?? 60,
                                dropdownColor: const Color(0xFF1E293B),
                                underline: Container(),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.setGameDuration(roomId, val);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 60,
                                    child: Text('60 Saniye'),
                                  ),
                                  DropdownMenuItem(
                                    value: 90,
                                    child: Text('90 Saniye'),
                                  ),
                                  DropdownMenuItem(
                                    value: 120,
                                    child: Text('120 Saniye'),
                                  ),
                                ],
                              )
                            else
                              Text(
                                '${(data['gameDuration'] as int?) ?? 60} Saniye',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                          ] else ...[
                            // Quiz: Category Selector
                            const Text(
                              'KATEGORİ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isHost)
                              DropdownButton<String>(
                                value: (state.categories.isEmpty)
                                    ? 'Genel'
                                    : (state.categories.contains(
                                            selectedCategory,
                                          )
                                          ? selectedCategory
                                          : state.categories.first),
                                dropdownColor: const Color(0xFF1E293B),
                                underline: Container(),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.setCategory(roomId, val);
                                  }
                                },
                                items:
                                    (state.categories.isEmpty
                                            ? [
                                                'Genel',
                                                'Sinema',
                                                'Tarih',
                                                'Coğrafya',
                                                'Spor',
                                                'Bilim',
                                              ]
                                            : state.categories)
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                              )
                            else
                              Text(
                                selectedCategory,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Error Display
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Players Label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OYUNCULAR (${players.length}/8)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      if (index < players.length) {
                        final playerId = players[index];
                        final isMe = playerId == controller.userId;
                        final isPlayerHost = playerId == hostId;
                        final isPlayerReady = readyPlayers.contains(playerId);

                        return _buildPlayerSlot(
                          context,
                          index,
                          isMe: isMe,
                          isHost: isPlayerHost,
                          isReady: isPlayerReady,
                          playerData:
                              playersData[playerId] as Map<String, dynamic>?,
                        );
                      } else {
                        return _buildEmptySlot(context);
                      }
                    },
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1121).withAlpha(240),
                    border: const Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: isHost
                            ? ElevatedButton(
                                onPressed:
                                    (players.isNotEmpty &&
                                        readyPlayers.length == players.length)
                                    ? () => controller.startMultiplayerGame(
                                        roomId,
                                      )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor: Colors.white10,
                                ),
                                child: state.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        (players.isEmpty)
                                            ? 'OYUNCU BEKLENİYOR...'
                                            : (readyPlayers.length ==
                                                  players.length)
                                            ? 'OYUNU BAŞLAT'
                                            : 'HERKES HAZIR DEĞİL',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              )
                            : ElevatedButton(
                                onPressed: () => controller.toggleReady(roomId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isReady
                                      ? Colors.redAccent
                                      : Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  isReady ? 'HAZIR DEĞİLİM' : 'HAZIRIM',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          // ignore: deprecated_member_use
                          Share.share(
                            'Hodri Meydan oynuyorum! Oda Kodu: $roomId\nGel ve bana katıl!',
                          );
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Arkadaşlarını Davet Et'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showJoinByCodeDialog(
    BuildContext context,
    MultiplayerController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191834),
          title: const Text(
            'Kodla Katıl',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Oda Kodu (123456)',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                if (_codeController.text.length == 6) {
                  Navigator.pop(context);
                  controller.joinRoom(_codeController.text);
                }
              },
              child: const Text('Katıl'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: isSmall ? 140 : null,
        decoration: BoxDecoration(
          color: const Color(0xFF191834).withAlpha(150),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(
    BuildContext context,
    int index, {
    bool isMe = false,
    bool isHost = false,
    bool isReady = false,
    Map<String, dynamic>? playerData,
  }) {
    final avatarUrl = playerData?['avatar'] as String?;
    final username = playerData?['username'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191834).withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: isMe
            ? Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isMe
                    ? Theme.of(context).colorScheme.secondary.withAlpha(50)
                    : Colors.white10,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Icon(
                        Icons.person,
                        color: isMe
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.white,
                        size: 30,
                      )
                    : null,
              ),
              if (isHost)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
              if (isReady &&
                  !isHost) // Host is implied ready or marked differently
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isMe ? 'Sen' : (username ?? 'Oyuncu ${index + 1}'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            isHost ? 'Kurucu' : (isReady ? 'Hazır' : 'Bekliyor'),
            style: TextStyle(
              color: isHost
                  ? Colors.amber
                  : (isReady ? Colors.greenAccent[400] : Colors.white24),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white10,
          style: BorderStyle.solid,
        ), // Dashed border needs a package or custom painter, using solid for now
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, color: Colors.white24, size: 30),
          const SizedBox(height: 8),
          Text(
            'Davet Et',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
