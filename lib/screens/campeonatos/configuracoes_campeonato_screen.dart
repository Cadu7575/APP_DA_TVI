import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tvi_news/models/campeonato.dart';
import 'package:tvi_news/screens/campeonatos/gerar_jogos_screen.dart';
import 'package:tvi_news/screens/campeonatos/times_screen.dart';
import 'package:tvi_news/services/campeonato_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

class ConfiguracoesCampeonatoScreen extends StatefulWidget {
  final Campeonato campeonato;

  const ConfiguracoesCampeonatoScreen({super.key, required this.campeonato});

  @override
  State<ConfiguracoesCampeonatoScreen> createState() =>
      _ConfiguracoesCampeonatoScreenState();
}

class _ConfiguracoesCampeonatoScreenState
    extends State<ConfiguracoesCampeonatoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _localCtrl;
  late final TextEditingController _logoCtrl;
  late final TextEditingController _bannerCtrl;

  late StatusCampeonato _status;
  DateTime? _dataInicio;
  DateTime? _dataFim;

  int _pontosVitoria = 3;
  int _pontosEmpate = 1;
  int _pontosDerrota = 0;
  String _suspensaoVermelho = '1 vermelho';
  String _suspensaoAmarelo = '3 amarelos';
  bool _zerarCartoesFinal = true;

  bool _salvando = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final c = widget.campeonato;
    _nomeCtrl = TextEditingController(text: c.nome);
    _descCtrl = TextEditingController(text: c.descricao);
    _localCtrl = TextEditingController(text: c.local ?? '');
    _logoCtrl = TextEditingController(text: c.logoUrl ?? '');
    _bannerCtrl = TextEditingController();

    _status = c.status;
    _dataInicio = c.dataInicio;
    _dataFim = c.dataFim;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descCtrl.dispose();
    _localCtrl.dispose();
    _logoCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(bool isInicio) async {
    final atual = isInicio ? (_dataInicio ?? DateTime.now()) : (_dataFim ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accentOrange,
            surface: AppTheme.cardColor,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final cAtualizado = Campeonato(
        id: widget.campeonato.id,
        nome: _nomeCtrl.text.trim(),
        descricao: _descCtrl.text.trim(),
        esporte: widget.campeonato.esporte,
        status: _status,
        organizadorId: widget.campeonato.organizadorId,
        organizadorNome: widget.campeonato.organizadorNome,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        local: _localCtrl.text.trim(),
        logoUrl: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
        categorias: widget.campeonato.categorias,
        maxTimes: widget.campeonato.maxTimes,
        patrocinadores: widget.campeonato.patrocinadores,
        criadoEm: widget.campeonato.criadoEm,
      );

      await CampeonatoService.instance.atualizarCampeonato(cAtualizado);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: Text(
          'Configurações do Campeonato',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppTheme.accentOrange,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Salvar',
                    style: GoogleFonts.poppins(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 1. DADOS BÁSICOS ──────────────────────────────────────────────
            _secaoHeader('Dados básicos'),
            _cardContainer([
              TextFormField(
                controller: _nomeCtrl,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: _inputDeco('Título / Nome da Divisão'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: _inputDeco('Descrição do Campeonato'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _logoCtrl,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: _inputDeco('URL da Foto / Brasão Oficial'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _seletorDataField(
                      rotulo: 'Data de início',
                      data: _dataInicio,
                      onTap: () => _selecionarData(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _seletorDataField(
                      rotulo: 'Data de término',
                      data: _dataFim,
                      onTap: () => _selecionarData(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localCtrl,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: _inputDeco('Locais / Ginásios Principais'),
              ),
            ]),

            const SizedBox(height: 20),

            // ── 2. ESTRUTURA DO CAMPEONATO ────────────────────────────────────
            _secaoHeader('Campeonato'),
            _cardContainer([
              _itemAcao(
                icon: Icons.shield_outlined,
                titulo: 'Equipes Inscritas',
                subtitulo: 'Gerenciar times, logos e responsáveis',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TimesScreen(
                        campeonatoId: widget.campeonato.id,
                        campeonatoNome: widget.campeonato.nome,
                        isOrganizador: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              _itemAcao(
                icon: Icons.groups_outlined,
                titulo: 'Jogadores e Atletas',
                subtitulo: 'Inscrições, números de camisa e posições',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TimesScreen(
                        campeonatoId: widget.campeonato.id,
                        campeonatoNome: widget.campeonato.nome,
                        isOrganizador: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              _itemAcao(
                icon: Icons.calendar_month,
                titulo: 'Gerador de Partidas e Calendário',
                subtitulo: 'Montagem automática da tabela e confrontos',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GerarJogosScreen(
                        campeonatoId: widget.campeonato.id,
                        campeonatoNome: widget.campeonato.nome,
                      ),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 20),

            // ── 3. DIVULGAÇÃO & STATUS ────────────────────────────────────────
            _secaoHeader('Divulgação e Status'),
            _cardContainer([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status do Campeonato:',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13),
                  ),
                  DropdownButton<StatusCampeonato>(
                    value: _status,
                    dropdownColor: AppTheme.cardColor,
                    style: GoogleFonts.poppins(
                        color: AppTheme.accentOrange, fontWeight: FontWeight.bold),
                    items: StatusCampeonato.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (novo) {
                      if (novo != null) setState(() => _status = novo);
                    },
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 20),

            // ── 4. REGRAS DO ESPORTE & PONTUAÇÃO ──────────────────────────────
            _secaoHeader('Configurações do esporte'),
            _cardContainer([
              _dropdownConfig(
                rotulo: 'Pontos por Vitória',
                valor: '$_pontosVitoria',
                opcoes: ['3', '2', '1'],
                onChanged: (v) => setState(() => _pontosVitoria = int.parse(v!)),
              ),
              _dropdownConfig(
                rotulo: 'Pontos por Empate',
                valor: '$_pontosEmpate',
                opcoes: ['1', '0'],
                onChanged: (v) => setState(() => _pontosEmpate = int.parse(v!)),
              ),
              _dropdownConfig(
                rotulo: 'Pontos por Derrota',
                valor: '$_pontosDerrota',
                opcoes: ['0', '1'],
                onChanged: (v) => setState(() => _pontosDerrota = int.parse(v!)),
              ),
              _dropdownConfig(
                rotulo: 'Suspensão (Cartão Vermelho)',
                valor: _suspensaoVermelho,
                opcoes: ['1 vermelho', '2 vermelhos', 'Não suspende'],
                onChanged: (v) => setState(() => _suspensaoVermelho = v!),
              ),
              _dropdownConfig(
                rotulo: 'Suspensão (Cartão Amarelo)',
                valor: _suspensaoAmarelo,
                opcoes: ['3 amarelos', '2 amarelos', 'Não suspende'],
                onChanged: (v) => setState(() => _suspensaoAmarelo = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.accentOrange,
                title: Text(
                  'Zerar cartões para a fase final',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  'Atletas iniciam o mata-mata sem pendências de cartões amarelos',
                  style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11),
                ),
                value: _zerarCartoesFinal,
                onChanged: (v) => setState(() => _zerarCartoesFinal = v),
              ),
            ]),

            const SizedBox(height: 30),

            // Botão grande de salvar
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'SALVAR TODAS AS ALTERAÇÕES',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Helpers visuais ────────────────────────────────────────────────────────

  Widget _secaoHeader(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        titulo,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentOrange,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _cardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
      filled: true,
      fillColor: AppTheme.bgSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _seletorDataField({
    required String rotulo,
    required DateTime? data,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: AppTheme.accentOrange),
                const SizedBox(width: 6),
                Text(
                  data != null ? _dateFormat.format(data) : 'Definir',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemAcao({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.accentOrange, size: 22),
      ),
      title: Text(
        titulo,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitulo,
        style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  Widget _dropdownConfig({
    required String rotulo,
    required String valor,
    required List<String> opcoes,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
          DropdownButton<String>(
            value: valor,
            dropdownColor: AppTheme.cardColor,
            style: GoogleFonts.poppins(color: AppTheme.accentOrange, fontWeight: FontWeight.bold),
            items: opcoes
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
