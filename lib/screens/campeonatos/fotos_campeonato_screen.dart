import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:tvi_news/services/fotos_service.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

class FotosCampeonatoScreen extends StatefulWidget {
  final String campeonatoId;
  final bool isAdmin;
  final bool mostrarAppBar;

  const FotosCampeonatoScreen({
    super.key,
    required this.campeonatoId,
    required this.isAdmin,
    this.mostrarAppBar = false,
  });

  @override
  State<FotosCampeonatoScreen> createState() => _FotosCampeonatoScreenState();
}

class _FotosCampeonatoScreenState extends State<FotosCampeonatoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: widget.mostrarAppBar
          ? AppBar(
              title: Text(
                'Galeria de Fotos',
                style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              backgroundColor: AppTheme.bgPrimary,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppTheme.textPrimary),
            )
          : null,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              tooltip: 'Adicionar foto',
              onPressed: () => _mostrarBottomSheetAdicionar(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: StreamBuilder<List<FotoCampeonato>>(
        stream: FotosService.instance.getFotos(widget.campeonatoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: AppTheme.accentRed,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erro ao carregar fotos',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tente novamente mais tarde.',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final fotos = snapshot.data ?? [];

          if (fotos.isEmpty) {
            return _buildEstadoVazio();
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              final foto = fotos[index];
              return _buildFotoItem(foto);
            },
          );
        },
      ),
    );
  }

  Widget _buildFotoItem(FotoCampeonato foto) {
    return GestureDetector(
      onTap: () => _abrirFotoFullscreen(foto),
      onLongPress: widget.isAdmin ? () => _confirmarRemocao(foto) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: foto.url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.cardColor,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.cardColor,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.textMuted,
                  size: 28,
                ),
              ),
            ),
            if (foto.descricao.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: Text(
                    foto.descricao,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma foto do campeonato ainda',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFotoFullscreen(FotoCampeonato foto) {
    final dataFormatada =
        DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(foto.timestamp);

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            actions: [
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
                  tooltip: 'Remover foto',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _confirmarRemocao(foto);
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: foto.url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AppTheme.accentOrange),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (foto.descricao.isNotEmpty) ...[
                        Text(
                          foto.descricao,
                          style: GoogleFonts.poppins(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (foto.enviadoPorNome.isNotEmpty) ...[
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                foto.enviadoPorNome,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dataFormatada,
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarRemocao(FotoCampeonato foto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Remover Foto',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Deseja realmente remover esta foto da galeria?',
          style: GoogleFonts.poppins(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remover',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await FotosService.instance.removerFoto(widget.campeonatoId, foto.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto removida com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover foto: $e'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      }
    }
  }

  void _mostrarBottomSheetAdicionar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BottomSheetAdicionarFoto(
        campeonatoId: widget.campeonatoId,
      ),
    );
  }
}

class _BottomSheetAdicionarFoto extends StatefulWidget {
  final String campeonatoId;

  const _BottomSheetAdicionarFoto({required this.campeonatoId});

  @override
  State<_BottomSheetAdicionarFoto> createState() =>
      _BottomSheetAdicionarFotoState();
}

class _BottomSheetAdicionarFotoState extends State<_BottomSheetAdicionarFoto> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarFoto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final usuario = await AuthService.instance.usuarioAtual;

      final enviadoPorId = user?.uid ?? 'anonimo';
      final enviadoPorNome = (usuario?.nome.isNotEmpty == true)
          ? usuario!.nome
          : (user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : (user?.email?.split('@').first ?? 'Organizador'));

      await FotosService.instance.adicionarFoto(
        campeonatoId: widget.campeonatoId,
        url: _urlCtrl.text.trim(),
        descricao: _descCtrl.text.trim(),
        enviadoPorId: enviadoPorId,
        enviadoPorNome: enviadoPorNome,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto adicionada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar foto: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Adicionar Foto',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'URL da imagem',
                labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
                hintText: 'https://exemplo.com/foto.jpg',
                hintStyle: GoogleFonts.poppins(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.link, color: AppTheme.accentOrange),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a URL da imagem';
                }
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
                  return 'Informe uma URL válida (http ou https)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Legenda / Descrição',
                labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
                hintText: 'Digite uma legenda para a foto',
                hintStyle: GoogleFonts.poppins(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.chat_bubble_outline, color: AppTheme.accentOrange),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarFoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Adicionar Foto',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
