alter table public.user_tracking_metrics
  drop constraint if exists user_tracking_metrics_metric_key_check;

alter table public.user_tracking_metrics
  add constraint user_tracking_metrics_metric_key_check
  check (
    metric_key in (
      'blood_glucose',
      'carbohydrate',
      'meal_time',
      'bowel',
      'abdominal_pain',
      'bloating',
      'fatigue',
      'fat',
      'meal_amount',
      'small_meal',
      'diarrhea',
      'sodium',
      'potassium',
      'phosphorus',
      'water_intake'
    )
  );
