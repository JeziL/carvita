import 'package:carvita/core/constants/app_colors.dart';
import 'package:carvita/core/widgets/gradient_background.dart';
import 'package:carvita/i18n/generated/app_localizations.dart';
import 'package:flutter/material.dart';


class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.privacyPolicy),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                SizedBox(height: 32),
                Icon(Icons.verified_user_outlined, size: 128, color: AppColors.iconOnPrimary.withValues(alpha: 0.8)),
                SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.privacyHeadline,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                Container(
                  padding: EdgeInsets.only(left: 8, right: 8),
                  child: Column(
                    spacing: 20,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Icon(Icons.cloud_off_outlined, color: AppColors.textWhite),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.privacyLocalStorage,
                              style: TextStyle(fontSize: 16, color: AppColors.textWhite),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Icon(Icons.pan_tool_outlined, color: AppColors.textWhite),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.privacyControl,
                              style: TextStyle(fontSize: 16, color: AppColors.textWhite),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
