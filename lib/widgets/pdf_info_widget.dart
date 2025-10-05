import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PdfInfoWidget extends StatelessWidget {
  final String fileName;
  final int pageCount;
  final int fileSize;
  final List<String> extractedMedicaments;
  final bool isDesktop;

  const PdfInfoWidget({
    Key? key,
    required this.fileName,
    required this.pageCount,
    required this.fileSize,
    required this.extractedMedicaments,
    this.isDesktop = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDesktop ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
      ),
      color: isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec icône
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.blue.shade700,
                    size: isDesktop ? 28 : 24,
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document PDF analysé',
                        style: GoogleFonts.lato(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        fileName,
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 14 : 12,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 20 : 16),

            // Informations du fichier
            _buildInfoRow(
              icon: Icons.description,
              label: 'Pages',
              value: '$pageCount page(s)',
            ),
            SizedBox(height: isDesktop ? 12 : 8),
            _buildInfoRow(
              icon: Icons.storage,
              label: 'Taille',
              value: _formatFileSize(fileSize),
            ),
            SizedBox(height: isDesktop ? 20 : 16),

            // Médicaments trouvés
            if (extractedMedicaments.isNotEmpty) ...[
              Text(
                'Médicaments identifiés:',
                style: GoogleFonts.lato(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.green.shade700,
                ),
              ),
              SizedBox(height: isDesktop ? 12 : 8),
              Wrap(
                spacing: isDesktop ? 8 : 6,
                runSpacing: isDesktop ? 8 : 6,
                children: extractedMedicaments.map((medicament) {
                  return Chip(
                    label: Text(
                      medicament,
                      style: GoogleFonts.roboto(
                        fontSize: isDesktop ? 13 : 11,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: Colors.green.shade600,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 12 : 8,
                      vertical: isDesktop ? 8 : 4,
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Text(
                'Aucun médicament identifié',
                style: GoogleFonts.roboto(
                  fontSize: isDesktop ? 14 : 12,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: isDesktop ? 20 : 16,
          color: Colors.blue.shade600,
        ),
        SizedBox(width: isDesktop ? 12 : 8),
        Text(
          '$label: ',
          style: GoogleFonts.roboto(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: isDesktop ? 14 : 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
