import 'package:flutter/material.dart';

class HouseholdHeroIllustration extends StatelessWidget {
  const HouseholdHeroIllustration({super.key, this.width = 240});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // 告诉系统辅助功能 这是一个有含义的图片
      image: true,
      label: "一家人共同记账",
      // ExcludeSemantics 避免里面的image再被重复朗读
      child: ExcludeSemantics(
        child: Image.asset(
          "assets/images/household/family_onboarding.png",
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
