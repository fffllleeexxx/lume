import 'package:flutter/material.dart';

class CreateMenu extends StatelessWidget {
  final VoidCallback onClusterSelected;
  final VoidCallback onElementSelected;

  const CreateMenu({
    super.key,
    required this.onClusterSelected,
    required this.onElementSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF151515),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.1,
        vertical: MediaQuery.of(context).size.height * 0.2,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create',
              style: TextStyle(
                color: Color(0xFFECECE6),
                fontSize: 20,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Divider(color: Colors.white, height: 24, thickness: 0.5),
            
            // Cluster Option
            _buildCompactOption(
              icon: Icons.folder,
              title: 'Cluster',
              subtitle: 'A collection of elements',
              onTap: onClusterSelected,
            ),
            
            const SizedBox(height: 12),
            
            // Element Option
            _buildCompactOption(
              icon: Icons.add_box,
              title: 'Element',
              subtitle: 'Image, link or note',
              onTap: onElementSelected,
            ),
            
            const SizedBox(height: 16),
            
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFFECECE6),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFECECE6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: const Color(0xFF151515)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF151515),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF767673),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}