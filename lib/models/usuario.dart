import 'package:cloud_firestore/cloud_firestore.dart';

enum RoleUsuario { espectador, organizador, arbitro, admin }

class Usuario {
  final String id;
  final String nome;
  final String email;
  final RoleUsuario role;
  final List<String> campeonatosGerenciados;
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.role = RoleUsuario.organizador,
    this.campeonatosGerenciados = const [],
    required this.criadoEm,
  });

  bool get isAdmin => role == RoleUsuario.admin;
  bool get isOrganizador =>
      role == RoleUsuario.organizador || role == RoleUsuario.admin;
  bool get isArbitro => role == RoleUsuario.arbitro || role == RoleUsuario.admin;

  factory Usuario.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Usuario(
      id: doc.id,
      nome: data['nome'] ?? '',
      email: data['email'] ?? '',
      role: RoleUsuario.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'organizador'),
        orElse: () => RoleUsuario.organizador,
      ),
      campeonatosGerenciados:
          List<String>.from(data['campeonatosGerenciados'] ?? []),
      criadoEm: data['criadoEm'] != null
          ? (data['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'email': email,
      'role': role.name,
      'campeonatosGerenciados': campeonatosGerenciados,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
