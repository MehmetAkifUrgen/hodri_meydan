import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Replace with real AdMob IDs in production
  // Using Test IDs from https://developers.google.com/admob/android/test-ads

  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7956816566156883~7472272239';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7956816566156883~5692286700';
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7956816566156883/3066123361';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7956816566156883/1700344459';
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7956816566156883/6159190563';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7956816566156883/8126878353';
    }
    return '';
  }

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // Callbacks for waiting
  Function(RewardedAd)? _onRewardedAdLoaded;
  Function(LoadAdError)? _onRewardedAdFailedToLoad;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  void _loadInterstitialAd() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  void _loadRewardedAd() {
    if (_isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded');
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _onRewardedAdLoaded?.call(ad);
          _onRewardedAdLoaded = null;
          _onRewardedAdFailedToLoad = null;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _isRewardedLoading = false;
          _onRewardedAdFailedToLoad?.call(error);
          _onRewardedAdLoaded = null;
          _onRewardedAdFailedToLoad = null;
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // Load next
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint('InterstitialAd not ready yet.');
      _loadInterstitialAd();
    }
  }

  /// Shows rewarded ad, waiting with a loading dialog if necessary.
  void showRewardedAdWaitIfNeeded(
    BuildContext context, {
    required Function(RewardItem) onUserEarnedReward,
  }) {
    if (_rewardedAd != null) {
      _showRewardedAdInternal(_rewardedAd!, onUserEarnedReward);
    } else {
      // Show Loading Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      _onRewardedAdLoaded = (ad) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
        }
        _showRewardedAdInternal(ad, onUserEarnedReward);
      };

      _onRewardedAdFailedToLoad = (error) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Reklam yüklenemedi: ${error.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      _loadRewardedAd();
    }
  }

  void _showRewardedAdInternal(RewardedAd ad, Function(RewardItem) onReward) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(); // Load next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        onReward(reward);
      },
    );
    _rewardedAd = null;
  }
}

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  service.initialize(); // Load ads immediately
  return service;
});
