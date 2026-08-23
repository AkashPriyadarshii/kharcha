import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final String merchantName;
  final String? fallbackEmoji;
  final String? fallbackColor;
  final double size;

  const BrandLogo({
    super.key,
    required this.merchantName,
    this.fallbackEmoji,
    this.fallbackColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final lowerName = merchantName.toLowerCase();
    final domain = lowerName.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final fallbackBgColor = fallbackColor != null 
        ? Color(int.parse('FF${fallbackColor!.replaceFirst('#', '')}', radix: 16))
        : const Color(0xFF8D99AE);
        
    final brandColor = _getBrandColor(lowerName);

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: brandColor ?? fallbackBgColor,
        child: Image.network(
          'https://logo.clearbit.com/$domain.com',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to text/emoji if offline or no logo found
            return Center(
              child: Text(
                fallbackEmoji ?? _getInitials(merchantName),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.45,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length > 1 ? 2 : 1).toUpperCase();
  }

  Color? _getBrandColor(String name) {
    final colors = {
      'netflix': '#E50914',
      'spotify': '#1DB954',
      'youtube': '#FF0000',
      'disney': '#113CCF',
      'sony': '#000000',
      'zee': '#6C2E91',
      'voot': '#E5007E',
      'swiggy': '#FC8019',
      'zomato': '#E23744',
      'blinkit': '#FFC800',
      'zepto': '#9B51E0',
      'dominos': '#0066B3',
      'mcdonalds': '#FFC600',
      'kfc': '#F40027',
      'starbucks': '#00704A',
      'hdfc': '#004C8F',
      'icici': '#F37021',
      'axis': '#97144D',
      'sbi': '#22409A',
      'kotak': '#EF3829',
      'yes bank': '#0066CC',
      'idfc': '#8B0000',
      'indusind': '#98272B',
      'pnb': '#0E2B5C',
      'paytm': '#00B9F1',
      'phonepe': '#5F259F',
      'google pay': '#4285F4',
      'cred': '#000000',
      'amazon pay': '#FF9900',
      'airtel': '#E52E2D',
      'jio': '#2A3890',
      'vodafone': '#E60000',
      'idea': '#FDD922',
      'bsnl': '#0078BF',
      'amazon': '#FF9900',
      'flipkart': '#027CD5',
      'myntra': '#FF3F6C',
      'ajio': '#2C4152',
      'nykaa': '#FC2779',
      'meesho': '#F43397',
      'uber': '#000000',
      'ola': '#93CE25',
      'rapido': '#FFC800',
      'irctc': '#FB792B',
      'groww': '#00D09C',
      'zerodha': '#387ED1',
      'upstox': '#5E72E4',
      'angel': '#5B2D90',
      '1mg': '#FC574E',
      'pharmeasy': '#10847E',
      'netmeds': '#24AEB1',
      'apollo': '#0066B3',
      'practo': '#1EBEA5',
      'cult': '#FF3278',
      'gym': '#F15B2A'
    };

    for (final entry in colors.entries) {
      if (name.contains(entry.key)) {
        return Color(int.parse('FF${entry.value.replaceFirst('#', '')}', radix: 16));
      }
    }
    return null;
  }
}
