import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const GlassButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ??
              AppTheme.darkSurfaceVariant.withOpacity(0.7),
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: borderColor ?? AppTheme.glassAccent,
              width: 1.5,
            ),
          ),
          disabledBackgroundColor:
              AppTheme.darkSurfaceVariant.withOpacity(0.4),
          disabledForegroundColor: AppTheme.textSecondary,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.glassAccent,
                  ),
                ),
              )
            : Text(
                label,
                style: textStyle ??
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
              ),
      ),
    );
  }
}
