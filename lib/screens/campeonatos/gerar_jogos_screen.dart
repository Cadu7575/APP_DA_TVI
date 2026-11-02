import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tvi_news/models/time_model.dart';
import 'package:tvi_news/services/gerador_jogos_service.dart';
import 'package:tvi_news/services/times_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

class GerarJogosScreen extends StatefulWidget {
  final String campeonatoId;
  final String campeonatoNome;

  const GerarJogosScreen({
    super.key,
    required this.campeonatoId,
    required this.campeonatoNome,
  });

  @override
  State<GerarJogosScreen> createState() => _GerarJogosScreenState();
}

class _GerarJogosScreenState extends State<GerarJogosScreen> {
  FormatoTorneio _formato = FormatoTorneio.pontosCorridos;
  DateTime _dataInicio = DateTime.now().add(const Duration(days: 1));
  int _intervaloDias = 7;
  final TextEditingController _localCtrl =
      TextEditingController(text: 'Ginásio Principal');
  bool _gerando = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _localCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentOrange,
              onPrimary: Colors.white,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dataInicio = picked);
    }
  }

  Future<void> _gerar(List<Time> times) async {
    if (times.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre pelo menos 2 times antes de gerar os jogos!'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Confirmar Geração Automática',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Serão geradas partidas para os ${times.length} times cadastrados. Deseja prosseguir?',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gerar Jogos',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _gerando = true);

    try {
      final partidas = await GeradorJogosService.instance.gerarEGravarPartidas(
        campeonatoId: widget.campeonatoId,
        faseId: 'geral',
        times: times,
        formato: _formato,
        dataInicio: _dataInicio,
        intervaloDias: _intervaloDias,
        localPadrao: _localCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sucesso! ${partidas.length} partidas geradas automaticamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        title: Text(
          'Gerador de Calendário de Jogos',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Time>>(
        stream: TimesService.instance.getTimes(widget.campeonatoId),
        builder: (context, snapshot) {
          final times = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month,
                          color: AppTheme.accentOrange, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.campeonatoNome,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${times.length} times cadastrados prontos para a tabela',
                              style: GoogleFonts.poppins(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Formato do Torneio
                Text(
                  'Formato do Torneio',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),
                _opcaoFormato(
                  titulo: 'Pontos Corridos (Turno Único)',
                  subtitulo: 'Todos contra todos em 1 turno',
                  valor: FormatoTorneio.pontosCorridos,
                ),
                _opcaoFormato(
                  titulo: 'Pontos Corridos (Ida e Volta)',
                  subtitulo: 'Todos contra todos em 2 turnos (mando invertido)',
                  valor: FormatoTorneio.idaEVolta,
                ),
                _opcaoFormato(
                  titulo: 'Mata-Mata Direto',
                  subtitulo: 'Chaves eliminatórias simples',
                  valor: FormatoTorneio.mataMata,
                ),

                const SizedBox(height: 20),

                // Configurações de Datas e Local
                Text(
                  'Agendamento e Local',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),

                // Data de início
                ListTile(
                  tileColor: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  title: Text('Data da 1ª Rodada',
                      style: GoogleFonts.poppins(color: Colors.white)),
                  subtitle: Text(_dateFormat.format(_dataInicio),
                      style:
                          GoogleFonts.poppins(color: AppTheme.accentOrange)),
                  trailing: const Icon(Icons.calendar_today,
                      color: AppTheme.accentOrange),
                  onTap: _selecionarData,
                ),

                const SizedBox(height: 12),

                // Intervalo entre rodadas
                if (_formato != FormatoTorneio.mataMata) ...[
                  Row(
                    children: [
                      Text('Intervalo entre rodadas:',
                          style:
                              GoogleFonts.poppins(color: AppTheme.textSecondary)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _intervaloDias,
                        dropdownColor: AppTheme.cardColor,
                        style: GoogleFonts.poppins(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Todo dia (1 dia)')),
                          DropdownMenuItem(value: 3, child: Text('A cada 3 dias')),
                          DropdownMenuItem(value: 7, child: Text('Semanal (7 dias)')),
                          DropdownMenuItem(value: 14, child: Text('Quinzenal (14 dias)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _intervaloDias = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Local padrão
                TextField(
                  controller: _localCtrl,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Local Padrão das Partidas',
                    labelStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.location_on,
                        color: AppTheme.accentOrange),
                  ),
                ),

                const SizedBox(height: 32),

                // Botão de Gerar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _gerando ? null : () => _gerar(times),
                    child: _gerando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'GERAR CALENDÁRIO AUTOMÁTICO',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _opcaoFormato({
    required String titulo,
    required String subtitulo,
    required FormatoTorneio valor,
  }) {
    final selecionado = _formato == valor;
    return GestureDetector(
      onTap: () => setState(() => _formato = valor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? AppTheme.accentOrange : Colors.white12,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selecionado ? AppTheme.accentOrange : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
