import 'package:flutter/material.dart';

class SuggestionCard extends StatelessWidget {
  final String       text;
  final VoidCallback onTap;

  const SuggestionCard({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9ECEF)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines:  2,
          overflow:  TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.w500,
            color:      Color(0xFF374151),
            height:     1.4,
          ),
        ),
      ),
    );
  }
}