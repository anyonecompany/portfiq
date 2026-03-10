/// ETF 정보 모델 — My ETF 탭 및 상세 화면에서 사용.
class EtfInfo {
  final String ticker;
  final String name;
  final String nameKr;
  final String category;
  final double expenseRatio;
  final String description;
  final List<EtfHolding> topHoldings;
  final double? currentPrice;
  final double? changePct;
  final double? changeAmount;

  const EtfInfo({
    required this.ticker,
    required this.name,
    required this.nameKr,
    required this.category,
    required this.expenseRatio,
    this.description = '',
    this.topHoldings = const [],
    this.currentPrice,
    this.changePct,
    this.changeAmount,
  });

  EtfInfo copyWith({
    String? ticker,
    String? name,
    String? nameKr,
    String? category,
    double? expenseRatio,
    String? description,
    List<EtfHolding>? topHoldings,
    double? currentPrice,
    double? changePct,
    double? changeAmount,
  }) {
    return EtfInfo(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      nameKr: nameKr ?? this.nameKr,
      category: category ?? this.category,
      expenseRatio: expenseRatio ?? this.expenseRatio,
      description: description ?? this.description,
      topHoldings: topHoldings ?? this.topHoldings,
      currentPrice: currentPrice ?? this.currentPrice,
      changePct: changePct ?? this.changePct,
      changeAmount: changeAmount ?? this.changeAmount,
    );
  }
}

/// ETF 구성종목 정보.
class EtfHolding {
  final String name;
  final String ticker;
  final double weight;

  const EtfHolding({
    required this.name,
    required this.ticker,
    required this.weight,
  });
}
