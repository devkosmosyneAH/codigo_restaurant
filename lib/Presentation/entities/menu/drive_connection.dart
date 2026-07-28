import 'package:equatable/equatable.dart';

/// Conexión Drive asociada a un tenant (restaurante).
///
/// Identifica de forma única (UUID) la subcarpeta en Google Drive donde se
/// almacenan las imágenes públicas del menú del restaurante. Esta carpeta
/// se comparte con permiso "anyone with the link, reader" para que la página
/// pública y el QR puedan mostrar imágenes sin requerir autenticación OAuth.
///
/// El restaurantId tiene un índice único: cada tenant tiene a lo sumo una
/// conexión Drive activa a la vez.
class DriveConnection extends Equatable {
  /// UUID v4 generado en creación. Identificador interno estable.
  final String id;

  /// Tenant propietario de la conexión.
  final String restaurantId;

  /// fileId de Google Drive de la subcarpeta del tenant.
  final String folderId;

  /// Nombre humano-legible de la carpeta en Drive.
  final String folderName;

  /// Email de la cuenta Google con la que se creó la conexión.
  /// Usado para detectar y advertir si el admin cambia de cuenta.
  final String ownerEmail;

  /// True si la carpeta está compartida públicamente (anyone with link).
  final bool publicShareEnabled;

  /// Usuario interno del sistema que creó la conexión.
  final String createdBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DriveConnection({
    required this.id,
    required this.restaurantId,
    required this.folderId,
    required this.folderName,
    required this.ownerEmail,
    required this.publicShareEnabled,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  DriveConnection copyWith({
    String? folderId,
    String? folderName,
    String? ownerEmail,
    bool? publicShareEnabled,
    DateTime? updatedAt,
  }) {
    return DriveConnection(
      id: id,
      restaurantId: restaurantId,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      publicShareEnabled: publicShareEnabled ?? this.publicShareEnabled,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    restaurantId,
    folderId,
    folderName,
    ownerEmail,
    publicShareEnabled,
    createdBy,
    createdAt,
    updatedAt,
  ];
}
