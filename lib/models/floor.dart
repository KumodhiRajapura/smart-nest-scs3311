import 'package:cloud_firestore/cloud_firestore.dart';

import 'json_utils.dart';

/// A house floor and the abstract grid overlaid on its plan image.
///
/// The grid is stored here rather than on each device so that the whole floor
/// can be re-scaled by editing one document -- device coordinates stay valid
/// as long as they are inside [gridCols] x [gridRows].
class Floor {
  const Floor({
    required this.id,
    required this.name,
    required this.level,
    this.planImageUrl,
    this.gridCols = 8,
    this.gridRows = 8,
    this.createdAt,
  });

  factory Floor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Floor(
      id: doc.id,
      name: asString(data['name'], fallback: 'Floor'),
      level: asInt(data['level']),
      planImageUrl: asStringOrNull(data['planImageUrl']),
      gridCols: asInt(data['gridCols'], fallback: 8),
      gridRows: asInt(data['gridRows'], fallback: 8),
      createdAt: asDate(data['createdAt']),
    );
  }

  final String id;
  final String name;

  /// Ground floor is 0. Used for ordering the floor tabs.
  final int level;

  /// Asset path or remote URL of the plan image the grid sits on top of.
  final String? planImageUrl;

  final int gridCols;
  final int gridRows;
  final DateTime? createdAt;

  int get cellCount => gridCols * gridRows;

  bool containsCell(int x, int y) =>
      x >= 0 && y >= 0 && x < gridCols && y < gridRows;

  Map<String, dynamic> toMap() => {
        'name': name,
        'level': level,
        'planImageUrl': planImageUrl,
        'gridCols': gridCols,
        'gridRows': gridRows,
      };

  Floor copyWith({
    String? name,
    int? level,
    String? planImageUrl,
    int? gridCols,
    int? gridRows,
  }) =>
      Floor(
        id: id,
        name: name ?? this.name,
        level: level ?? this.level,
        planImageUrl: planImageUrl ?? this.planImageUrl,
        gridCols: gridCols ?? this.gridCols,
        gridRows: gridRows ?? this.gridRows,
        createdAt: createdAt,
      );
}
