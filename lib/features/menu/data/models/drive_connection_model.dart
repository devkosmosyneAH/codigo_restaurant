import 'package:restaurant_app/features/menu/domain/entities/drive_connection.dart';

/// Modelo de datos: DriveConnection.
///
/// Serialización SQLite para la entidad [DriveConnection].
class DriveConnectionModel extends DriveConnection {
  const DriveConnectionModel({
    required super.id,
    required super.restaurantId,
    required super.folderId,
    required super.folderName,
    required super.ownerEmail,
    required super.publicShareEnabled,
    required super.createdBy,
    required super.createdAt,
    required super.updatedAt,
  });

  factory DriveConnectionModel.fromMap(Map<String, dynamic> map) {
    return DriveConnectionModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      folderId: map['folder_id'] as String,
      folderName: map['folder_name'] as String,
      ownerEmail: map['owner_email'] as String? ?? '',
      publicShareEnabled: (map['public_share_enabled'] as int?) == 1,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'folder_id': folderId,
      'folder_name': folderName,
      'owner_email': ownerEmail,
      'public_share_enabled': publicShareEnabled ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DriveConnectionModel.fromEntity(DriveConnection entity) {
    return DriveConnectionModel(
      id: entity.id,
      restaurantId: entity.restaurantId,
      folderId: entity.folderId,
      folderName: entity.folderName,
      ownerEmail: entity.ownerEmail,
      publicShareEnabled: entity.publicShareEnabled,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
