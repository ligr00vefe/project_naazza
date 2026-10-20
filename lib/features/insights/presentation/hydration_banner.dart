import 'package:flutter/material.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/word_wrap_text.dart';

/// Daily water guidance in cups only. No logging or motivational copy.
/// General adult reference: https://www.korea.kr/news/policyNewsView.do?newsId=148829504
/// One cup is 200 ml in the source; volume units are intentionally not in the UI.
class HydrationBanner extends StatelessWidget {
  const HydrationBanner({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFFEAF4FF),
        child: LayoutBuilder(
          builder: (context, box) {
            final image = Image.asset(
              'assets/images/hydration_mint_blue.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            );
            const copy = WordWrapText(
              '하루 물 5~7컵 마시기',
              style: AppDesign.sectionTitle,
            );
            if (MediaQuery.textScalerOf(context).scale(15) > 22) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: 3, child: image),
                  const Padding(padding: EdgeInsets.all(16), child: copy),
                ],
              );
            }
            return AspectRatio(
              aspectRatio: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Padding(
                    padding: EdgeInsets.only(
                      left: box.maxWidth * .48,
                      right: 12,
                    ),
                    child: const Align(
                      alignment: Alignment.center,
                      child: copy,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
