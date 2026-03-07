import 'dart:ui';

/// DOC-T3-WLC-029 §3.7 — 3-language welcome screen copy
/// Locale detection: device locale → fallback to Korean
class WelcomeStrings {
  WelcomeStrings._();

  static const _ko = 'ko';
  static const _en = 'en';
  static const _ja = 'ja';

  /// Get current language key from device locale
  static String _langKey() {
    final locale = PlatformDispatcher.instance.locale;
    final lang = locale.languageCode;
    if (lang == _en) return _en;
    if (lang == _ja) return _ja;
    return _ko; // fallback
  }

  // ─ Slide titles (§3.2 Phase 2) ─────────────────────────────────
  static const _slideTitles = {
    _ko: ['여행, 더 안전하게', '일정부터 위치까지, 함께', '누군가 지켜보고 있어요', '지금 시작하세요'],
    _en: ['Travel, Safer Together', 'Plans to Location, All in One', "Someone's Got Your Back", 'Get Started Now'],
    _ja: ['旅行を、もっと安全に', 'スケジュールから位置情報まで、一緒に', '誰かが見守っています', '今すぐ始めましょう'],
  };

  static const _slideSubtitles = {
    _ko: [
      'SafeTrip과 함께라면\n어디든 안심하고 떠날 수 있어요',
      '멤버들의 실시간 위치와\n여행 일정을 한눈에 확인하세요',
      '가디언 기능을 통해\n소중한 사람의 안전을 지켜주세요',
      'SafeTrip으로 더 즐겁고\n안전한 여행을 시작해볼까요?',
    ],
    _en: [
      'With SafeTrip, travel anywhere\nwith peace of mind',
      'Check real-time locations\nand trip schedules at a glance',
      'Keep your loved ones safe\nwith the Guardian feature',
      'Ready to start a safer\nand more enjoyable trip?',
    ],
    _ja: [
      'SafeTripと一緒なら\nどこでも安心して出発できます',
      'メンバーのリアルタイム位置と\n旅行スケジュールを一目で確認',
      'ガーディアン機能で\n大切な人の安全を守りましょう',
      'SafeTripでもっと楽しく\n安全な旅を始めませんか？',
    ],
  };

  // ─ Slide accessibility labels (§3.5) ───────────────────────────
  static const _slideSemantics = {
    _ko: [
      '슬라이드 1: 여행 안전을 상징하는 방패 일러스트',
      '슬라이드 2: 함께하는 여행을 상징하는 그룹 일러스트',
      '슬라이드 3: 보호를 상징하는 가디언 일러스트',
      '슬라이드 4: SafeTrip 시작하기',
    ],
    _en: [
      'Slide 1: Shield illustration symbolizing travel safety',
      'Slide 2: Group illustration symbolizing traveling together',
      'Slide 3: Guardian illustration symbolizing protection',
      'Slide 4: Get started with SafeTrip',
    ],
    _ja: [
      'スライド1：旅行の安全を象徴する盾のイラスト',
      'スライド2：一緒に旅行することを象徴するグループイラスト',
      'スライド3：保護を象徴するガーディアンイラスト',
      'スライド4：SafeTripを始めましょう',
    ],
  };

  // ─ Button / UI strings ──────────────────────────────────────────
  static const _skip = {_ko: '건너뛰기', _en: 'Skip', _ja: 'スキップ'};
  static const _next = {_ko: '다음', _en: 'Next', _ja: '次へ'};
  static const _getStarted = {_ko: '시작하기', _en: 'Get Started', _ja: '始める'};

  // Purpose select (§3.2 Phase 3)
  static const _purposeTitle = {
    _ko: '어떤 목적으로 SafeTrip을\n사용하시나요?',
    _en: 'How would you like to\nuse SafeTrip?',
    _ja: 'SafeTripをどのように\nお使いになりますか？',
  };
  static const _createTrip = {_ko: '여행 만들기', _en: 'Create a Trip', _ja: '旅行を作成'};
  static const _enterCode = {_ko: '초대코드 입력', _en: 'Enter Invite Code', _ja: '招待コードを入力'};
  static const _demoTour = {_ko: '먼저 둘러보기', _en: 'Explore First', _ja: 'まず見てみる'};
  static const _guardianJoin = {_ko: '가디언으로 참여', _en: 'Join as Guardian', _ja: 'ガーディアンとして参加'};
  static const _demoTourLink = {_ko: '로그인 없이 먼저 둘러보기', _en: 'Explore without signing in', _ja: 'ログインなしで見てみる'};
  static const _inviteCodeManualHint = {
    _ko: '초대코드를 직접 입력해 주세요.',
    _en: 'Please enter the invite code manually.',
    _ja: '招待コードを直接入力してください。',
  };

  // §3.6 A/B CTA variant B: "안전 여행 시작"
  static const _createTripSafety = {
    _ko: '안전 여행 시작',
    _en: 'Start Safe Trip',
    _ja: '安全な旅を始める',
  };

  // §3.5, §3.7: Dot indicator semantics (3-language)
  static const _dotSemanticsFormat = {
    _ko: '슬라이드 %d / %d',
    _en: 'Slide %d of %d',
    _ja: 'スライド %d / %d',
  };

  // ─ Public getters ──────────────────────────────────────────────
  static List<String> get slideTitles => _slideTitles[_langKey()]!;
  static List<String> get slideSubtitles => _slideSubtitles[_langKey()]!;
  static List<String> get slideSemantics => _slideSemantics[_langKey()]!;
  static String get skip => _skip[_langKey()]!;
  static String get next => _next[_langKey()]!;
  static String get getStarted => _getStarted[_langKey()]!;
  static String get purposeTitle => _purposeTitle[_langKey()]!;
  static String get createTrip => _createTrip[_langKey()]!;
  static String get enterCode => _enterCode[_langKey()]!;
  static String get demoTour => _demoTour[_langKey()]!;
  static String get guardianJoin => _guardianJoin[_langKey()]!;
  static String get demoTourLink => _demoTourLink[_langKey()]!;
  static String get inviteCodeManualHint => _inviteCodeManualHint[_langKey()]!;

  /// §3.6: A/B CTA variant — returns create trip label for given variant
  static String createTripForVariant(String variant) {
    if (variant == 'safety') return _createTripSafety[_langKey()]!;
    return _createTrip[_langKey()]!; // default
  }

  /// §3.5, §3.7: Localized dot indicator semantics label
  static String dotSemantics(int current, int total) {
    final fmt = _dotSemanticsFormat[_langKey()]!;
    return fmt.replaceFirst('%d', '$current').replaceFirst('%d', '$total');
  }
}
