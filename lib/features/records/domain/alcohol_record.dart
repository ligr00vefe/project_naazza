const drinkTypes = ['소주', '맥주', '막걸리', '와인', '위스키', '하이볼', '기타'];
const glassSizes = <String, int>{
  '소주잔': 50,
  '맥주컵 300': 300,
  '맥주컵 500': 500,
  '맥주컵 1L': 1000,
  '막걸리잔': 200,
  '와인잔': 150,
  '위스키잔': 30,
  '머그잔 250': 250,
  '머그잔 350': 350,
  '소주병': 360,
  '맥주병 330': 330,
  '맥주병 500': 500,
  '맥주캔 355': 355,
  '맥주캔 500': 500,
  '맥주 페트 1L': 1000,
  '맥주 페트 1.6L': 1600,
};
List<String> drinkContainers(String drink) => [
  '소주잔',
  '맥주컵 300',
  '맥주컵 500',
  '맥주컵 1L',
  '막걸리잔',
  '와인잔',
  '위스키잔',
  '머그잔 250',
  '머그잔 350',
  if (drink == '소주') '소주병',
  if (drink == '맥주') ...[
    '맥주병 330',
    '맥주병 500',
    '맥주캔 355',
    '맥주캔 500',
    '맥주 페트 1L',
    '맥주 페트 1.6L',
  ],
  '직접 입력',
];
String defaultGlass(String drink) => switch (drink) {
  '맥주' || '하이볼' => '맥주컵 500',
  '막걸리' => '막걸리잔',
  '와인' => '와인잔',
  '위스키' => '위스키잔',
  '기타' => '머그잔 250',
  _ => '소주잔',
};
String containerUnit(String glass) => glass.contains('병')
    ? '병'
    : glass.contains('캔')
    ? '캔'
    : glass.contains('페트')
    ? '페트'
    : '잔';
String drinkNumber(num value) => !value.isFinite
    ? '0'
    : value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
List<Map<String, Object?>> alcoholItems(Map<String, Object?> data) {
  final items = (data['items'] as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList();
  return items.isNotEmpty
      ? items
      : [
          {
            'drink_type': data['drink_type'],
            'servings': data['servings'],
            'glass_label': data['glass_label'],
            'glass_ml': data['glass_ml'],
            'total_ml': data['total_ml'],
          },
        ];
}

String alcoholItemLabel(Map<String, Object?> item) =>
    '${item['drink_type']} · ${item['servings']}${containerUnit(item['glass_label']?.toString() ?? '')} · ${item['glass_label']} (${item['glass_ml']} cc) · 총 ${item['total_ml']} cc';
