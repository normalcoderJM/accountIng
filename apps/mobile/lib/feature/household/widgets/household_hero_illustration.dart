import "package:flutter/material.dart";
import "package:mobile/core/app_assets.dart";

// 家庭引导页中的主插画。
//
// 单独封装后，首次引导、空状态等页面都可以复用，
// 并且可以在这里统一设置语义化标签和图片清晰度。
class HouseholdHeroIllustration extends StatelessWidget {
  const HouseholdHeroIllustration({super.key, this.width = 248});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: "一家人共同记账",
      child: Image.asset(
        AppAssets.householdOnboarding,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
