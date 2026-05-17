import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/context_ext.dart';

// ودجت الزر المخصص (Custom Button)
// يستخدم في كافة أنحاء التطبيق لتوحيد شكل الأزرار وتجربة المستخدم
class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed; // الدالة المستدعاة عند الضغط
  final String text; // النص المعروض على الزر
  final bool isOutlined; // هل الزر بإطار فقط (بدون خلفية ملونة)؟
  final bool isLoading; // هل الزر في حالة تحميل (يظهر مؤشر دوران)؟
  final double? width; // عرض الزر
  final Color? color; // لون الزر الأساسي
  final IconData? icon; // أيقونة اختيارية بجانب النص
  final double iconSize;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isOutlined = false,
    this.isLoading = false,
    this.width,
    this.color,
    this.icon,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد اللون المستخدم بناءً على اللون الممرر أو لون السمة الأساسي
    final themeColor = color ?? context.colorScheme.primary;
    
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        // تعطيل الضغط في حالة التحميل أو عدم وجود دالة
        onPressed: (isLoading || onPressed == null)
            ? null
            : () {
                // إضافة اهتزاز فيزيائي بسيط عند الضغط (Haptic Feedback)
                HapticFeedback.lightImpact();
                onPressed!();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : themeColor,
          foregroundColor: isOutlined ? themeColor : Colors.white,
          elevation: (isOutlined || isLoading) ? 0 : 8,
          shadowColor: themeColor.withValues(alpha: 0.4),
          // إضافة حدود برواز للزر إذا كان من نوع Outlined
          side: isOutlined ? BorderSide(color: themeColor, width: 2) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                // إظهار مؤشر التحميل بدلاً من النص
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOutlined ? themeColor : Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // إضافة أيقونة إذا تم توفيرها
                  if (icon != null) ...[
                    Icon(icon, size: iconSize),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
