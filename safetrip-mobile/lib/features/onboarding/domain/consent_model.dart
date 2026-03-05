/// §8 consent items — 4 standard + 2 EU-only
class ConsentModel {
  final bool termsOfService;
  final bool privacyPolicy;
  final bool lbsTerms;
  final bool marketing;
  final bool? gdpr;
  final bool? firebaseTransfer;

  const ConsentModel({
    this.termsOfService = false,
    this.privacyPolicy = false,
    this.lbsTerms = false,
    this.marketing = false,
    this.gdpr,
    this.firebaseTransfer,
  });

  bool get allRequiredChecked {
    final base = termsOfService && privacyPolicy && lbsTerms;
    if (gdpr != null) return base && gdpr! && (firebaseTransfer ?? false);
    return base;
  }

  bool get allChecked => allRequiredChecked && marketing;

  ConsentModel copyWith({
    bool? termsOfService,
    bool? privacyPolicy,
    bool? lbsTerms,
    bool? marketing,
    bool? gdpr,
    bool? firebaseTransfer,
  }) {
    return ConsentModel(
      termsOfService: termsOfService ?? this.termsOfService,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      lbsTerms: lbsTerms ?? this.lbsTerms,
      marketing: marketing ?? this.marketing,
      gdpr: gdpr ?? this.gdpr,
      firebaseTransfer: firebaseTransfer ?? this.firebaseTransfer,
    );
  }
}
