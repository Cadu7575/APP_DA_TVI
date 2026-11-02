import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/usuario.dart';

/// Serviço responsável por toda a autenticação de usuários via Firebase Auth,
/// incluindo login, cadastro, logout e leitura de perfil no Firestore.
class AuthService {
  AuthService._();

  /// Instância singleton do serviço.
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Stream do usuário atualmente logado.
  /// Emite [null] quando o usuário faz logout.
  Stream<Usuario?> get usuarioStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      return _buscarUsuarioNoFirestore(firebaseUser.uid);
    });
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Retorna o [Usuario] atual lendo os dados do Firestore.
  /// Retorna [null] se nenhum usuário estiver logado.
  Future<Usuario?> get usuarioAtual async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _buscarUsuarioNoFirestore(firebaseUser.uid);
  }

  // ---------------------------------------------------------------------------
  // Métodos públicos
  // ---------------------------------------------------------------------------

  /// Realiza o login com [email] e [password].
  ///
  /// Lança [Exception] com mensagem em português em caso de erro.
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  /// Cria uma nova conta de usuário com [nome], [email] e [password].
  ///
  /// Após criar a conta no Firebase Auth, salva o documento do usuário
  /// na coleção `usuarios/{uid}` com role padrão de organizador.
  ///
  /// Lança [Exception] com mensagem em português em caso de erro.
  Future<void> cadastrar(String nome, String email, String password) async {
    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credencial.user!.uid;

      // Salva o perfil no Firestore com role padrão espectador
      // (somente admin pode promover para árbitro ou organizador)
      final novoUsuario = Usuario(
        id: uid,
        nome: nome.trim(),
        email: email.trim(),
        role: RoleUsuario.espectador,
        campeonatosGerenciados: const [],
        criadoEm: DateTime.now(),
      );

      await _firestore
          .collection('usuarios')
          .doc(uid)
          .set(novoUsuario.toFirestore());
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e.code));
    }
  }

  /// Realiza o logout do usuário atual.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Verifica se o usuário logado possui role de admin no Firestore.
  ///
  /// Retorna [false] caso nenhum usuário esteja logado ou em caso de erro.
  Future<bool> isAdmin() async {
    try {
      final usuario = await usuarioAtual;
      return usuario?.isAdmin ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Métodos privados
  // ---------------------------------------------------------------------------

  /// Busca e retorna o [Usuario] correspondente ao [uid] no Firestore.
  /// Retorna [null] se o documento não existir.
  Future<Usuario?> _buscarUsuarioNoFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;
      return Usuario.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Converte códigos de erro do Firebase Auth em mensagens amigáveis em português.
  String _traduzirErroAuth(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou senha inválidos.';
      case 'email-already-in-use':
        return 'Email já cadastrado. Tente fazer login.';
      case 'invalid-email':
        return 'Email inválido. Verifique o endereço informado.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta conta foi desativada. Entre em contato com o suporte.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede.';
      default:
        return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }
}
