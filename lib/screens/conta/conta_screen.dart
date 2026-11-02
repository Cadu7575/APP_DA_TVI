import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/models/usuario.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela de Conta — exibe login/cadastro quando não autenticado
/// e o perfil do usuário quando autenticado.
class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  // ── Estado de navegação interna ────────────────────────────────────────────
  bool _mostrarCadastro = false;
  bool _carregando = false;
  bool _senhaVisivel = false;
  bool _senhaConfVisivel = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();

  // ── Cache do usuário logado ────────────────────────────────────────────────
  Usuario? _usuarioLogado;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _carregarUsuario() async {
    final u = await AuthService.instance.usuarioAtual;
    if (mounted) setState(() => _usuarioLogado = u);
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppTheme.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarSucesso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.login(
        _emailCtrl.text.trim(),
        _senhaCtrl.text,
      );
      await _carregarUsuario();
      _mostrarSucesso('Bem-vindo de volta!');
    } catch (e) {
      _mostrarErro(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.cadastrar(
        _nomeCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _senhaCtrl.text,
      );
      await _carregarUsuario();
      _mostrarSucesso('Conta criada com sucesso! Bem-vindo!');
    } catch (e) {
      _mostrarErro(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _sair() async {
    setState(() => _carregando = true);
    await AuthService.instance.logout();
    if (mounted) {
      setState(() {
        _usuarioLogado = null;
        _mostrarCadastro = false;
        _carregando = false;
        _emailCtrl.clear();
        _senhaCtrl.clear();
        _nomeCtrl.clear();
      });
    }
  }

  // ── Role label + cor ──────────────────────────────────────────────────────

  String _roleLabel(RoleUsuario role) {
    switch (role) {
      case RoleUsuario.admin:
        return 'Admin';
      case RoleUsuario.organizador:
        return 'Organizador';
      case RoleUsuario.arbitro:
        return 'Árbitro';
      case RoleUsuario.espectador:
        return 'Espectador';
    }
  }

  Color _roleCor(RoleUsuario role) {
    switch (role) {
      case RoleUsuario.admin:
        return AppTheme.accentRed;
      case RoleUsuario.organizador:
        return AppTheme.accentOrange;
      case RoleUsuario.arbitro:
        return Colors.teal;
      case RoleUsuario.espectador:
        return AppTheme.textSecondary;
    }
  }

  // ── InputDecoration padrão ────────────────────────────────────────────────

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
      filled: true,
      fillColor: AppTheme.bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentOrange, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentRed, width: 1.8),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text(
          'Minha Conta',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),
      body: _carregando && _usuarioLogado == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            )
          : _usuarioLogado != null
              ? _buildPerfilLogado()
              : _buildFormulario(),
    );
  }

  // ── Tela de perfil (logado) ───────────────────────────────────────────────

  Widget _buildPerfilLogado() {
    final u = _usuarioLogado!;
    final inicial = u.nome.isNotEmpty ? u.nome[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Avatar
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.accentOrange,
            child: Text(
              inicial,
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Nome
          Text(
            u.nome,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          // Email
          Text(
            u.email,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Role chip
          Chip(
            label: Text(
              _roleLabel(u.role),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
            backgroundColor: _roleCor(u.role),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 40),

          // Divider
          Container(
            height: 1,
            color: AppTheme.cardColor,
          ),

          const SizedBox(height: 24),

          // Info cards
          _buildInfoCard(
            Icons.badge_outlined,
            'ID do Usuário',
            u.id,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            Icons.calendar_today_outlined,
            'Membro desde',
            _formatarData(u.criadoEm),
          ),
          if (u.campeonatosGerenciados.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoCard(
              Icons.emoji_events_outlined,
              'Campeonatos gerenciados',
              '${u.campeonatosGerenciados.length} campeonato(s)',
            ),
          ],

          const SizedBox(height: 40),

          // Botão Sair
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _carregando ? null : _sair,
              icon: _carregando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppTheme.accentOrange,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.logout, color: AppTheme.accentOrange),
              label: Text(
                'Sair da conta',
                style: GoogleFonts.poppins(
                  color: AppTheme.accentOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String titulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  valor,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime dt) {
    final meses = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    return '${dt.day} de ${meses[dt.month - 1]} de ${dt.year}';
  }

  // ── Formulário (não logado) ───────────────────────────────────────────────

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppTheme.accentOrange,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _mostrarCadastro ? 'Criar conta' : 'Entrar na sua conta',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mostrarCadastro
                        ? 'Preencha os dados para criar sua conta'
                        : 'Use seu email e senha para acessar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Campo nome (apenas no cadastro)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _mostrarCadastro
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _nomeCtrl,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: _inputDeco('Nome completo', Icons.person_outline),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            // Campo email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco('Email', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe seu email';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Campo senha
            TextFormField(
              controller: _senhaCtrl,
              obscureText: !_senhaVisivel,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco('Senha', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _senhaVisivel ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _senhaVisivel = !_senhaVisivel),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe sua senha';
                if (_mostrarCadastro && v.length < 6) {
                  return 'A senha deve ter pelo menos 6 caracteres';
                }
                return null;
              },
            ),

            // Confirmar senha (apenas no cadastro)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _mostrarCadastro
                  ? Column(
                      children: [
                        const SizedBox(height: 16),
                        TextFormField(
                          obscureText: !_senhaConfVisivel,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                          ),
                          decoration: _inputDeco(
                            'Confirmar senha',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _senhaConfVisivel
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _senhaConfVisivel = !_senhaConfVisivel,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Confirme sua senha';
                            }
                            if (v != _senhaCtrl.text) {
                              return 'As senhas não coincidem';
                            }
                            return null;
                          },
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 28),

            // Botão principal
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _carregando
                    ? null
                    : (_mostrarCadastro ? _cadastrar : _entrar),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.accentOrange.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _mostrarCadastro ? 'Criar conta' : 'Entrar',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Toggle login / cadastro
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _mostrarCadastro = !_mostrarCadastro;
                    _formKey.currentState?.reset();
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: _mostrarCadastro
                            ? 'Já tem uma conta? '
                            : 'Não tem conta? ',
                      ),
                      TextSpan(
                        text: _mostrarCadastro ? 'Entrar' : 'Cadastre-se',
                        style: GoogleFonts.poppins(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
