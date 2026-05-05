import 'package:flutter/material.dart';

class TopicData {
  final String label;
  final Color  color;
  const TopicData({required this.label, required this.color});
}

class TopicPill extends StatelessWidget {
  final TopicData    topic;
  final bool         isActive;
  final VoidCallback onTap;

  const TopicPill({
    super.key,
    required this.topic,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? topic.color.withOpacity(0.12) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: isActive ? topic.color : const Color(0xFFE9ECEF),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          topic.label,
          style: TextStyle(
            fontSize:   12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color:      isActive ? topic.color : const Color(0xFF6C757D),
          ),
        ),
      ),
    );
  }
}