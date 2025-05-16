import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// 광고 서비스
///
/// 앱 내 광고를 관리하는 서비스 (배너, 전면, 보상형 광고)
class AdService extends ChangeNotifier {
  // 싱글톤 인스턴스
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 광고 초기화 상태
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 광고 표시 확률 (50%로 증가)
  final int _adProbability = 50; // 30%에서 50%로 증가

  // 광고 로드 재시도 횟수 제한 (무한 로드 방지)
  int _interstitialRetryCount = 0;
  int _rewardedRetryCount = 0;
  final int _maxRetryCount = 3; // 최대 3번까지만 재시도

  // 광고 ID (패키지명: com.reaf.spinefairy)
  final String _bannerAdUnitId =
      _isTestMode()
          ? 'ca-app-pub-3940256099942544/6300978111' // 테스트 ID
          : 'ca-app-pub-1075071967728463/4492654010'; // 실제 배너 광고 ID

  final String _interstitialAdUnitId =
      _isTestMode()
          ? 'ca-app-pub-3940256099942544/1033173712' // 테스트 ID
          : 'ca-app-pub-1075071967728463/9494824982'; // 실제 전면 광고 ID

  final String _rewardedAdUnitId =
      _isTestMode()
          ? 'ca-app-pub-3940256099942544/5224354917' // 테스트 ID
          : 'ca-app-pub-1075071967728463/6392877280'; // 실제 보상형 광고 ID (5분 집중시간)

  // 테스트 모드 여부 확인 (더 안정적인 방식)
  static bool _isTestMode() {
    // AdMob 문서에 따르면 릴리스 모드에서는 실제 광고 ID를 사용해야 함
    // 디버그 또는 프로필 모드에서만 테스트 ID 사용
    return kDebugMode || kProfileMode;
  }

  // 광고 객체
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // 보상형 광고 로드 상태
  bool _rewardedAdIsLoading = false;

  // 광고 로드 중인지 추적
  bool _interstitialAdIsLoading = false;

  // 마지막 광고 표시 시간 추적 (사용자 경험을 위해)
  DateTime? _lastInterstitialAdTime;

  // 휴식 시간 종료 여부 플래그
  bool _isRestCompleted = false;

  bool _isAdEnabled = true;
  bool _isAdLoaded = false;

  // 광고가 활성화되어 있는지 확인
  bool get isAdEnabled => _isAdEnabled;

  // 광고가 로드되었는지 확인
  bool get isAdLoaded => _isAdLoaded;

  // 휴식 시간 종료 설정
  void setRestCompleted(bool completed) {
    _isRestCompleted = completed;
    if (completed) {
      print('🔄 휴식 시간 종료, 전면 광고 로드 시작');
      loadInterstitialAd();
    }
  }

  // 초기화 함수
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Google 모바일 광고 초기화 - 로그 추가
      print('🔄 광고 서비스 초기화 시작');
      print(
        '📊 현재 실행 모드: ${kReleaseMode
            ? "릴리스"
            : kProfileMode
            ? "프로필"
            : "디버그"}',
      );
      print('📝 테스트 모드: ${_isTestMode()}');
      print('📝 배너 광고 ID: $_bannerAdUnitId');
      print('📝 전면 광고 ID: $_interstitialAdUnitId');
      print('📝 보상형 광고 ID: $_rewardedAdUnitId');

      final initFuture = MobileAds.instance.initialize();

      // 초기화 완료 대기
      await initFuture;
      print('✅ 광고 SDK 초기화 완료');

      // 현재 모드 확인
      print('📱 실행 모드: ${kReleaseMode ? "릴리스" : "디버그/프로필"}');
      print('📝 전면 광고 ID: $_interstitialAdUnitId');

      // 추가 디버그 정보
      MobileAds.instance.getVersionString().then((version) {
        print('📊 Google Mobile Ads SDK 버전: $version');
      });

      // 최소한의 설정만 사용
      final RequestConfiguration config = RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        testDeviceIds: [], // 테스트 장치 ID를 여기에 추가할 수 있습니다
      );
      MobileAds.instance.updateRequestConfiguration(config);
      print('✅ 광고 설정 구성 완료');

      _isInitialized = true;

      // 앱 시작 시 배너 광고만 미리 로드 (전면 광고는 휴식 종료 시에만 로드)
      loadBannerAd();
      loadRewardedAd(); // 보상형 광고는 사용자가 명시적으로 요청할 것이므로 미리 로드
      print('🔄 초기 광고 로드 요청됨 (배너 및 보상형)');

      await _loadAdStatus();
    } catch (e) {
      // 오류 발생 시 초기화 실패 처리
      print('❌ 광고 초기화 실패: $e');
      _isInitialized = false;
    }
    return;
  }

  // 광고 상태 불러오기
  Future<void> _loadAdStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAdEnabled = prefs.getBool('ad_enabled') ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('광고 상태 불러오기 오류: $e');
    }
  }

  // 광고 활성화 상태 설정
  Future<void> setEnabled(bool enabled) async {
    if (_isAdEnabled == enabled) return;

    _isAdEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ad_enabled', enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('광고 상태 저장 오류: $e');
    }
  }

  // 광고 로드 상태 설정
  void setAdLoaded(bool loaded) {
    _isAdLoaded = loaded;
    notifyListeners();
  }

  // 배너 광고 로드
  Future<void> loadBannerAd() async {
    try {
      if (!_isInitialized) {
        print('🔄 배너 광고 로드 전 초기화 시도');
        await initialize();
      }

      // 이미 로드된 배너가 있으면 새로 로드하지 않음
      if (_bannerAd != null) {
        print('ℹ️ 배너 광고가 이미 로드되어 있음');
        return;
      }

      print('🔄 배너 광고 로드 시작');
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ 배너 광고 로드 성공');
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ 배너 광고 로드 실패: ${error.message}, 코드: ${error.code}');
            ad.dispose();
            _bannerAd = null;

            // 배너 광고는 3분 후에 다시 시도
            Future.delayed(const Duration(minutes: 3), loadBannerAd);
          },
        ),
      );

      await _bannerAd?.load();
    } catch (e) {
      print('❌ 배너 광고 로드 예외 발생: $e');
      _bannerAd = null;

      // 배너 광고는 3분 후에 다시 시도
      Future.delayed(const Duration(minutes: 3), loadBannerAd);
    }
  }

  // 전면 광고 로드
  Future<void> loadInterstitialAd() async {
    if (_interstitialAdIsLoading || _interstitialAd != null) return;

    // 재시도 횟수 제한 (3회까지)
    if (_interstitialRetryCount >= _maxRetryCount) {
      print('ℹ️ 전면 광고 로드 최대 재시도 횟수 초과, 더 이상 시도하지 않음');
      _interstitialRetryCount = 0; // 일정 시간 후 다시 시도하기 위해 리셋
      return;
    }

    try {
      if (!_isInitialized) {
        print('🔄 전면 광고 로드 전 초기화 시도');
        await initialize();
      }

      print('🔄 전면 광고 로드 시작');
      _interstitialAdIsLoading = true;

      InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            print('✅ 전면 광고 로드 성공');
            _interstitialAd = ad;
            _interstitialAdIsLoading = false;
            _interstitialRetryCount = 0; // 성공 시 재시도 카운트 리셋
          },
          onAdFailedToLoad: (error) {
            print('❌ 전면 광고 로드 실패: ${error.message}, 코드: ${error.code}');
            _interstitialAd = null;
            _interstitialAdIsLoading = false;
            _interstitialRetryCount++; // 실패 시 재시도 카운트 증가

            // 실패 시 2분 후 다시 시도 (최대 재시도 횟수 이내인 경우만)
            if (_interstitialRetryCount < _maxRetryCount) {
              print(
                'ℹ️ 전면 광고 로드 실패 재시도 예정 ($_interstitialRetryCount/$_maxRetryCount)',
              );
              Future.delayed(const Duration(minutes: 2), loadInterstitialAd);
            } else {
              print('ℹ️ 전면 광고 로드 최대 재시도 횟수 도달, 15분 후 재시도 예정');
              // 한동안 시도하지 않다가 15분 후 다시 시도
              Future.delayed(const Duration(minutes: 15), () {
                _interstitialRetryCount = 0;
                loadInterstitialAd();
              });
            }
          },
        ),
      );
    } catch (e) {
      print('❌ 전면 광고 로드 예외 발생: $e');
      _interstitialAd = null;
      _interstitialAdIsLoading = false;
      _interstitialRetryCount++;
    }
  }

  // 보상형 광고 로드
  Future<void> loadRewardedAd() async {
    if (_rewardedAdIsLoading || _rewardedAd != null) return;

    // 재시도 횟수 제한 (3회까지)
    if (_rewardedRetryCount >= _maxRetryCount) {
      print('ℹ️ 보상형 광고 로드 최대 재시도 횟수 초과, 더 이상 시도하지 않음');
      _rewardedRetryCount = 0; // 일정 시간 후 다시 시도하기 위해 리셋
      return;
    }

    try {
      if (!_isInitialized) {
        print('🔄 보상형 광고 로드 전 초기화 시도');
        await initialize();
      }

      print('🔄 보상형 광고 로드 시작');
      _rewardedAd?.dispose();
      _rewardedAdIsLoading = true;

      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            print('✅ 보상형 광고 로드 성공');
            _rewardedAd = ad;
            _rewardedAdIsLoading = false;
            _rewardedRetryCount = 0; // 성공 시 재시도 카운트 리셋

            // 보상형 광고 콜백 설정
            _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print('ℹ️ 보상형 광고 닫힘');
                ad.dispose();
                _rewardedAd = null;
                _rewardedAdIsLoading = false;
                loadRewardedAd(); // 다음 광고 로드
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print('❌ 보상형 광고 표시 실패: ${error.message}');
                ad.dispose();
                _rewardedAd = null;
                _rewardedAdIsLoading = false;
                loadRewardedAd(); // 다음 광고 로드
              },
            );
          },
          onAdFailedToLoad: (error) {
            print('❌ 보상형 광고 로드 실패: ${error.message}, 코드: ${error.code}');
            _rewardedAd = null;
            _rewardedAdIsLoading = false;
            _rewardedRetryCount++; // 실패 시 재시도 카운트 증가

            // 실패 시 3분 후 다시 시도 (최대 재시도 횟수 이내인 경우만)
            if (_rewardedRetryCount < _maxRetryCount) {
              print(
                'ℹ️ 보상형 광고 로드 실패 재시도 예정 ($_rewardedRetryCount/$_maxRetryCount)',
              );
              Future.delayed(const Duration(minutes: 3), loadRewardedAd);
            } else {
              print('ℹ️ 보상형 광고 로드 최대 재시도 횟수 도달, 20분 후 재시도 예정');
              // 한동안 시도하지 않다가 20분 후 다시 시도
              Future.delayed(const Duration(minutes: 20), () {
                _rewardedRetryCount = 0;
                loadRewardedAd();
              });
            }
          },
        ),
      );
    } catch (e) {
      print('❌ 보상형 광고 로드 예외 발생: $e');
      _rewardedAd = null;
      _rewardedAdIsLoading = false;
      _rewardedRetryCount++;
    }
  }

  // 배너 광고 위젯 가져오기
  BannerAd? getBannerAd() {
    if (_bannerAd == null && !_rewardedAdIsLoading) {
      loadBannerAd(); // 배너 광고가 없으면 로드 시도
    }
    return _bannerAd;
  }

  // 전면 광고 표시
  Future<void> showInterstitialAd() async {
    // 휴식 시간이 완료되지 않았으면 광고 표시하지 않음
    if (!_isRestCompleted) {
      print('ℹ️ 휴식 시간이 완료되지 않아 전면 광고 표시 안 함');
      return;
    }

    // 사용자 경험을 위해 광고 표시 간격 확인 (최소 2분)
    if (_lastInterstitialAdTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastInterstitialAdTime!);
      if (difference.inMinutes < 2) {
        print(
          'ℹ️ 광고 표시 무시: 마지막 광고 이후 ${difference.inSeconds}초 지남 (최소 120초 필요)',
        );
        // 2분 이내에 이미 광고를 표시했으면 무시
        return;
      }
    }

    if (!_isInitialized) {
      print('🔄 광고 표시 전 초기화 시도');
      await initialize();
    }

    print('🔄 전면 광고 표시 시도');

    if (_interstitialAd == null) {
      print('ℹ️ 표시할 전면 광고 없음, 새 광고 로드 시작');
      // 광고가 로드되지 않았으면 로드 시작하고 반환
      if (!_interstitialAdIsLoading) {
        loadInterstitialAd();
      }
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('✅ 전면 광고 표시됨');
        // 광고가 표시되면 휴식 완료 플래그 리셋
        _isRestCompleted = false;
      },
      onAdDismissedFullScreenContent: (ad) {
        print('ℹ️ 전면 광고 닫힘');
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialAdTime = DateTime.now();

        // 표시 후에는 바로 다음 광고를 로드하지 않음
        // 다음 휴식 시간 종료 시에만 로드
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('❌ 전면 광고 표시 실패: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
      },
    );

    try {
      await _interstitialAd!.show();
      print('🎬 전면 광고 표시 함수 호출됨');
      _interstitialAd = null;
    } catch (e) {
      print('❌ 전면 광고 표시 중 예외 발생: $e');
      _interstitialAd?.dispose();
      _interstitialAd = null;
    }

    return;
  }

  /// 보상형 광고 표시
  ///
  /// 광고 시청 완료 시 true 반환, 그렇지 않으면 false 반환
  Future<bool> showRewardedAd() async {
    try {
      if (!_isInitialized) {
        print('🔄 보상형 광고 표시 전 초기화 시도');
        await initialize();
      }

      print('🔄 보상형 광고 표시 시도');

      // 광고가 없으면 새로 로드
      if (_rewardedAd == null) {
        print('ℹ️ 표시할 보상형 광고 없음, 새 광고 로드 시작');
        if (!_rewardedAdIsLoading) {
          loadRewardedAd();
          // 광고 로드에 시간이 필요하므로 잠시 대기
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // 광고 로드 재확인
      if (_rewardedAd == null) {
        print('❌ 보상형 광고 로드되지 않음');
        return false;
      }

      // 결과를 반환할 Completer 생성
      final Completer<bool> rewardCompleter = Completer<bool>();

      // 광고가 완료되면 true 반환
      _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('✅ 보상형 광고 표시됨');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('ℹ️ 보상형 광고 닫힘');
          ad.dispose();
          _rewardedAd = null;
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(false); // 사용자가 보상을 받지 못하고 닫음
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('❌ 보상형 광고 표시 실패: ${error.message}');
          ad.dispose();
          _rewardedAd = null;
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(false);
          }
        },
      );

      // 광고 표시
      await _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) {
          print('🎁 사용자가 보상 획득: ${reward.amount} ${reward.type}');
          if (!rewardCompleter.isCompleted) {
            rewardCompleter.complete(true);
          }
        },
      );

      // 타임아웃 설정 (30초)
      Future.delayed(const Duration(seconds: 30), () {
        if (!rewardCompleter.isCompleted) {
          print('⏱️ 보상형 광고 타임아웃');
          rewardCompleter.complete(false);
        }
      });

      return rewardCompleter.future;
    } catch (e) {
      print('❌ 보상형 광고 표시 중 예외 발생: $e');
      return false;
    }
  }

  // 광고 표시 여부 결정 (확률 기반)
  bool shouldShowAd() {
    if (!_isInitialized) {
      print('ℹ️ 광고 표시 결정: 초기화되지 않음');
      return false;
    }

    // 디버그 모드에서는 항상 표시
    if (_isTestMode()) {
      print('ℹ️ 광고 표시 결정: 테스트 모드에서 항상 표시');
      return true;
    }

    // 휴식 완료 시에만 전면 광고 표시
    if (!_isRestCompleted) {
      print('ℹ️ 광고 표시 결정: 휴식 시간이 완료되지 않아 표시 안 함');
      return false;
    }

    // 광고 표시 간격 확인 (마지막 광고 표시 후 최소 3분)
    if (_lastInterstitialAdTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastInterstitialAdTime!);
      if (difference.inMinutes < 3) {
        print('ℹ️ 광고 표시 결정: 마지막 광고 후 ${difference.inMinutes}분 지남 (최소 3분 필요)');
        return false;
      }
    }

    // 릴리스 모드에서는 확률 기반으로 표시 (50%)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final shouldShow = random < _adProbability;
    print(
      'ℹ️ 광고 표시 결정: ${shouldShow ? "표시" : "표시 안 함"} (확률 $_adProbability%, 값: $random)',
    );
    return shouldShow;
  }

  // 리소스 해제
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    print('♻️ 광고 서비스 리소스 해제됨');
  }
}
