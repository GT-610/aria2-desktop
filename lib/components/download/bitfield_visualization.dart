import 'package:flutter/material.dart';
import 'package:aria2_desktop/models/download_task.dart';
import 'package:aria2_desktop/utils/format_utils.dart';

/// Bitfield visualization component
/// Used to display the download status of torrent pieces in a grid format
class BitfieldVisualization extends StatelessWidget {
  final DownloadTask task;

  const BitfieldVisualization({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    // Get bitfield directly from the task object
    String? bitfield = task.bitfield;
    
    if (bitfield == null || bitfield.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No piece information available for this task',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'The task may not have started or no piece data is available',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Parse bitfield into piece status array
    List<int> pieces = parseHexBitfield(bitfield);
    
    // Calculate statistics
    int totalPieces = pieces.length;
    int completedPieces = pieces.where((piece) => piece == 15).length; // Fully downloaded (f)
    int partialPieces = pieces.where((piece) => piece > 0 && piece < 15).length; // Partially downloaded (1-14)
    int missingPieces = pieces.where((piece) => piece == 0).length; // Not downloaded (0)
    
    // Calculate completion percentage
    double completionPercentage = totalPieces > 0 
      ? ((completedPieces + partialPieces * 0.5) / totalPieces) * 100 
      : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics section
        Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Piece Statistics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pieces:'),
                    Text('$totalPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.green, margin: EdgeInsets.only(right: 8)),
                        Text('Completed:'),
                      ],
                    ),
                    Text('$completedPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.yellow, margin: EdgeInsets.only(right: 8)),
                        Text('Partial:'),
                      ],
                    ),
                    Text('$partialPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.grey, margin: EdgeInsets.only(right: 8)),
                        Text('Missing:'),
                      ],
                    ),
                    Text('$missingPieces'),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 4),
                Text('Piece Completion: ${completionPercentage.toStringAsFixed(2)}%', textAlign: TextAlign.right),
              ],
            ),
          ),
        ),
        
        // Download status visualization grid
        Text('Download Status Distribution:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        _buildPiecesGrid(pieces),
        
        // Legend explanation
        SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legend:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.green, margin: EdgeInsets.only(right: 8)),
                    Text('Fully Downloaded (f)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.lightGreen, margin: EdgeInsets.only(right: 8)),
                    Text('High Completion (8-b)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.yellow, margin: EdgeInsets.only(right: 8)),
                    Text('Medium Completion (4-7)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.orange, margin: EdgeInsets.only(right: 8)),
                    Text('Low Completion (1-3)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.grey, margin: EdgeInsets.only(right: 8)),
                    Text('Not Downloaded (0)'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the piece grid visualization
  /// Dynamically adjusts piece size based on the total number of pieces
  Widget _buildPiecesGrid(List<int> pieces) {
    // Determine grid size based on the number of pieces
    double pieceSize = pieces.length > 1000 ? 4.0 : (pieces.length > 500 ? 6.0 : 8.0);
    
    return Wrap(
      spacing: 1.0,
      runSpacing: 1.0,
      children: List.generate(pieces.length, (index) {
        return Container(
          width: pieceSize,
          height: pieceSize,
          decoration: BoxDecoration(
            color: getPieceColor(pieces[index]),
            border: Border.all(width: 0.5, color: Colors.black.withOpacity(0.1)),
          ),
        );
      }),
    );
  }
}