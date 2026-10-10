/// User-facing descriptions of the seven Bristol stool forms.
/// Reference: University Hospitals Plymouth NHS Trust, Bristol Stool Chart.
enum BowelForm {
  hardPieces(1, '딱딱한 조각', '작고 단단한 조각이 따로 있어요'),
  lumpy(2, '딱딱하게 뭉침', '단단한 덩어리가 길게 이어져요'),
  cracked(3, '표면이 갈라짐', '길쭉한 형태에 작은 갈라짐이 있어요'),
  smooth(4, '매끈하고 부드러움', '길쭉하고 매끈하게 형태가 잡혀 있어요'),
  softPieces(5, '부드러운 조각', '부드러운 조각의 가장자리가 또렷해요'),
  loose(6, '무르고 퍼짐', '조각이 퍼지고 가장자리가 흐릿해요'),
  watery(7, '물처럼 묽음', '형태 없이 거의 액체에 가까워요');

  const BowelForm(this.type, this.label, this.description);
  final int type;
  final String label;
  final String description;

  static BowelForm? fromType(Object? value) {
    for (final form in values) {
      if (form.type == value) return form;
    }
    return null;
  }

  static String recordLabel(Object? type) => fromType(type)?.label ?? '형태 미기록';
}
