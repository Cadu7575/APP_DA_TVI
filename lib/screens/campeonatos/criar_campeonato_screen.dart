import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/models/campeonato.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/services/campeonato_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela de criação de campeonato com wizard em 3 etapas.
class CriarCampeonatoScreen extends StatefulWidget {
  const CriarCampeonatoScreen({super.key});

  @override
  State<CriarCampeonatoScreen> createState() => _CriarCampeonatoScreenState();
}

class _CriarCampeonatoScreenState extends State<CriarCampeonatoScreen> {
  // ── Wizard ─────────────────────────────────────────────────────────────────
  int _etapa = 0; // 0, 1, 2
  static const int _totalEtapas = 3;
  bool _carregando = false;

  // ── Form keys ──────────────────────────────────────────────────────────────
  final _formKey0 = GlobalKey<FormState>(); // Etapa 1
  final _formKey1 = GlobalKey<FormState>(); // Etapa 2

  // ── Controllers – Etapa 1 ─────────────────────────────────────────────────
  final _nomeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  EsporteCampeonato _esporte = EsporteCampeonato.futebol;

  // ── Controllers – Etapa 2 ─────────────────────────────────────────────────
  DateTime? _dataInicio;
  DateTime? _dataFim;
  final _maxTimesCtrl = TextEditingController(text: '16');

  // ── Estado – Etapa 3 ──────────────────────────────────────────────────────
  final List<String> _categorias = ['Adulto', 'Sub-20', 'Feminino'];
  final _novaCategCtrl = TextEditingController();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _localCtrl.dispose();
    _maxTimesCtrl.dispose();
    _novaCategCtrl.dispose();
    super.dispose();
  }

  // ── Navegação entre etapas ────────────────────────────────────────────────

  void _avancar() {
    bool valido = true;
    if (_etapa == 0) valido = _formKey0.currentState?.validate() ?? false;
    if (_etapa == 1) valido = _formKey1.currentState?.validate() ?? false;
    if (!valido) return;

    if (_etapa < _totalEtapas - 1) {
      setState(() => _etapa++);
    } else {
      _criarCampeonato();
    }
  }

  void _voltar() {
    if (_etapa > 0) setState(() => _etapa--);
  }

  // ── Criação ───────────────────────────────────────────────────────────────

  Future<void> _criarCampeonato() async {
    setState(() => _carregando = true);

    try {
      final usuario = await AuthService.instance.usuarioAtual;
      if (usuario == null) {
        _mostrarErro('Você precisa estar logado para criar um campeonato.');
        setState(() => _carregando = false);
        return;
      }

      final novoId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final campeonato = Campeonato(
        id: novoId,
        nome: _nomeCtrl.text.trim(),
        descricao: _descCtrl.text.trim(),
        esporte: _esporte,
        status: StatusCampeonato.inscricoesAbertas,
        organizadorId: usuario.id,
        organizadorNome: usuario.nome,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        local: _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim(),
        maxTimes: int.tryParse(_maxTimesCtrl.text) ?? 16,
        categorias: List.from(_categorias),
        criadoEm: DateTime.now(),
      );

      await CampeonatoService.instance.criarCampeonato(campeonato);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Campeonato criado com sucesso! 🏆',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      _mostrarErro(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
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

  // ── DatePicker ────────────────────────────────────────────────────────────

  Future<void> _selecionarData({required bool ehInicio}) async {
    final agora = DateTime.now();
    final inicial = ehInicio
        ? (_dataInicio ?? agora)
        : (_dataFim ?? _dataInicio ?? agora);

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: agora.subtract(const Duration(days: 365)),
      lastDate: agora.add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentOrange,
            onPrimary: Colors.white,
            surface: AppTheme.cardColor,
            onSurface: AppTheme.textPrimary,
          ),
          dialogBackgroundColor: AppTheme.bgSecondary,
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        if (ehInicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
    }
  }

  // ── Helpers visuais ───────────────────────────────────────────────────────

  InputDecoration _inputDeco(String label, {IconData? icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
      hintStyle: GoogleFonts.poppins(
        color: AppTheme.textMuted,
        fontSize: 13,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: AppTheme.textSecondary, size: 20)
          : null,
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
        borderSide: const BorderSide(
          color: AppTheme.accentOrange,
          width: 1.8,
        ),
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

  String _formatarData(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        elevation: 0,
        leading: BackButton(
          color: AppTheme.textPrimary,
          onPressed: _etapa > 0 ? _voltar : () => Navigator.pop(context),
        ),
        title: Text(
          'Criar Campeonato',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _buildProgressBar(),
        ),
      ),
      body: Column(
        children: [
          // Labels das etapas
          _buildEtapaHeader(),

          // Conteúdo da etapa
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(_etapa),
                child: _buildEtapaAtual(),
              ),
            ),
          ),

          // Botões de navegação
          _buildBotoesNavegacao(),
        ],
      ),
    );
  }

  // ── Barra de progresso ────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final progresso = (_etapa + 1) / _totalEtapas;
    return LinearProgressIndicator(
      value: progresso,
      backgroundColor: AppTheme.cardColor,
      valueColor:
          const AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
      minHeight: 4,
    );
  }

  // ── Header com nomes das etapas ───────────────────────────────────────────

  Widget _buildEtapaHeader() {
    final etapas = ['Dados Básicos', 'Período', 'Categorias'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalEtapas, (i) {
          final ativa = i == _etapa;
          final concluida = i < _etapa;
          return Row(
            children: [
              if (i > 0)
                Container(
                  width: 32,
                  height: 1,
                  color: concluida || ativa
                      ? AppTheme.accentOrange
                      : AppTheme.cardColor,
                ),
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ativa
                          ? AppTheme.accentOrange
                          : concluida
                              ? AppTheme.accentOrange.withValues(alpha: 0.5)
                              : AppTheme.cardColor,
                      border: Border.all(
                        color: ativa || concluida
                            ? AppTheme.accentOrange
                            : AppTheme.textSecondary,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: concluida
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ativa
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etapas[i],
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: ativa
                          ? AppTheme.accentOrange
                          : AppTheme.textSecondary,
                      fontWeight: ativa ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Etapa atual ────────────────────────────────────────────────────────────

  Widget _buildEtapaAtual() {
    switch (_etapa) {
      case 0:
        return _buildEtapa1();
      case 1:
        return _buildEtapa2();
      case 2:
        return _buildEtapa3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Etapa 1: Dados Básicos ────────────────────────────────────────────────

  Widget _buildEtapa1() {
    final esportes = [
      (EsporteCampeonato.futebol, '⚽ Futebol'),
      (EsporteCampeonato.futsal, '⚽ Futsal'),
      (EsporteCampeonato.basquete, '🏀 Basquete'),
      (EsporteCampeonato.volei, '🏐 Vôlei'),
      (EsporteCampeonato.handebol, '🤾 Handebol'),
      (EsporteCampeonato.outro, '🏆 Outro'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKey0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Nome do campeonato *'),
            TextFormField(
              controller: _nomeCtrl,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco(
                'Ex.: Copa TVI 2025',
                icon: Icons.emoji_events_outlined,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'O nome é obrigatório' : null,
            ),

            const SizedBox(height: 20),
            _sectionTitle('Descrição (opcional)'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco(
                'Descreva o campeonato...',
                hint: 'Regulamento, patrocinadores, etc.',
              ),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Esporte'),
            DropdownButtonFormField<EsporteCampeonato>(
              value: _esporte,
              dropdownColor: AppTheme.cardColor,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco('Selecione o esporte', icon: Icons.sports),
              items: esportes
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.$1,
                      child: Text(e.$2,
                          style: GoogleFonts.poppins(
                              color: AppTheme.textPrimary)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _esporte = v);
              },
            ),

            const SizedBox(height: 20),
            _sectionTitle('Local / Cidade (opcional)'),
            TextFormField(
              controller: _localCtrl,
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco(
                'Ex.: Itapetininga - SP',
                icon: Icons.location_on_outlined,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Etapa 2: Período ──────────────────────────────────────────────────────

  Widget _buildEtapa2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Data de início'),
            _datePickerTile(
              label: _dataInicio != null
                  ? _formatarData(_dataInicio!)
                  : 'Selecionar data',
              icone: Icons.calendar_today_outlined,
              onTap: () => _selecionarData(ehInicio: true),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Data de término'),
            _datePickerTile(
              label: _dataFim != null
                  ? _formatarData(_dataFim!)
                  : 'Selecionar data',
              icone: Icons.event_outlined,
              onTap: () => _selecionarData(ehInicio: false),
            ),

            const SizedBox(height: 20),
            _sectionTitle('Número máximo de times'),
            TextFormField(
              controller: _maxTimesCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(color: AppTheme.textPrimary),
              decoration: _inputDeco(
                'Máximo de times',
                icon: Icons.group_outlined,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 2) {
                  return 'Informe um número válido (mínimo 2)';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required IconData icone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardColor),
        ),
        child: Row(
          children: [
            Icon(icone, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: label.startsWith('Selecionar')
                      ? AppTheme.textMuted
                      : AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 3: Categorias ───────────────────────────────────────────────────

  Widget _buildEtapa3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Categorias do campeonato'),
          Text(
            'Adicione as categorias que participarão. Toque no "×" para remover.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 16),

          // Chips de categorias
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._categorias.map(
                (cat) => GestureDetector(
                  onTap: () => setState(() => _categorias.remove(cat)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.accentOrange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.accentOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.close,
                          size: 14,
                          color: AppTheme.accentOrange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Botão adicionar
              GestureDetector(
                onTap: _mostrarDialogCategoria,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Adicionar',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Resumo final
          _buildResumo(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _mostrarDialogCategoria() {
    _novaCategCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nova categoria',
          style: GoogleFonts.poppins(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: _novaCategCtrl,
          autofocus: true,
          style: GoogleFonts.poppins(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ex.: Sub-17, Master...',
            hintStyle: GoogleFonts.poppins(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.bgPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.cardColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.accentOrange,
                width: 1.8,
              ),
            ),
          ),
          onSubmitted: (_) => _adicionarCategoria(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _adicionarCategoria(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Adicionar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _adicionarCategoria(BuildContext ctx) {
    final nova = _novaCategCtrl.text.trim();
    if (nova.isNotEmpty && !_categorias.contains(nova)) {
      setState(() => _categorias.add(nova));
    }
    Navigator.pop(ctx);
  }

  Widget _buildResumo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accentOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.summarize_outlined,
                color: AppTheme.accentOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumo do campeonato',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _resumoLinha('Nome', _nomeCtrl.text.trim()),
          _resumoLinha('Esporte', _esporteLabel(_esporte)),
          if (_localCtrl.text.isNotEmpty)
            _resumoLinha('Local', _localCtrl.text.trim()),
          if (_dataInicio != null)
            _resumoLinha('Início', _formatarData(_dataInicio!)),
          if (_dataFim != null)
            _resumoLinha('Término', _formatarData(_dataFim!)),
          _resumoLinha(
            'Máx. times',
            '${_maxTimesCtrl.text.isEmpty ? 16 : _maxTimesCtrl.text}',
          ),
          _resumoLinha(
            'Categorias',
            _categorias.isEmpty ? 'Nenhuma' : _categorias.join(', '),
          ),
        ],
      ),
    );
  }

  Widget _resumoLinha(String chave, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$chave:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor.isEmpty ? '—' : valor,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _esporteLabel(EsporteCampeonato e) {
    switch (e) {
      case EsporteCampeonato.futebol:
        return '⚽ Futebol';
      case EsporteCampeonato.futsal:
        return '⚽ Futsal';
      case EsporteCampeonato.basquete:
        return '🏀 Basquete';
      case EsporteCampeonato.volei:
        return '🏐 Vôlei';
      case EsporteCampeonato.handebol:
        return '🤾 Handebol';
      case EsporteCampeonato.outro:
        return '🏆 Outro';
    }
  }

  // ── Botões de navegação ────────────────────────────────────────────────────

  Widget _buildBotoesNavegacao() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: AppTheme.bgPrimary,
        border: Border(top: BorderSide(color: AppTheme.cardColor)),
      ),
      child: Row(
        children: [
          if (_etapa > 0) ...[
            OutlinedButton(
              onPressed: _carregando ? null : _voltar,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.textSecondary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Voltar',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _carregando ? null : _avancar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.accentOrange.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                        _etapa < _totalEtapas - 1
                            ? 'Próximo'
                            : 'Criar Campeonato',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Utilidade ─────────────────────────────────────────────────────────────

  Widget _sectionTitle(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
