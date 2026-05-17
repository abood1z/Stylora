import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// ودجت حقل الإدخال المخصص (Custom Text Field)
// صُمم ليوفر شكلاً موحداً للحقول مع ملصق (Label) علوي
class CustomTextField extends StatelessWidget {
  final String label; // النص الظاهر فوق الحقل
  final String hint; // نص التلميح داخل الحقل
  final TextEditingController? controller; // المتحكم في نص الإدخال
  final bool isPassword; // هل الحقل مخصص لكلمة مرور؟
  final TextInputType keyboardType; // نوع لوحة المفاتيح
  final IconData? prefixIcon; // أيقونة في بداية الحقل
  final String? Function(String?)? validator; // دالة التحقق من صحة الإدخال
  final Widget? suffixIcon; // ودجت في نهاية الحقل (مثل زر إظهار كلمة المرور)
  final bool obscureText; // هل يتم إخفاء النص (التحكم الخارجي)؟
  final ValueChanged<String>? onChanged; // استجابة عند تغيير النص
  final int maxLines; // عدد الأسطر المسموح بها

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.isPassword = false,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عرض ملصق الحقل (Label)
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        // حقل الإدخال الفعلي مع التنسيقات المعرفة في السمة العامة (Theme)
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            // إضافة الأيقونة الجانبية إذا وجدت
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textSecondary) : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
