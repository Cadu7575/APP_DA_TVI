import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tvi_news/models/jogador.dart';
import 'package:tvi_news/models/partida.dart';

class SumulaPdfService {
  SumulaPdfService._();
  static final SumulaPdfService instance = SumulaPdfService._();

  /// Gera e abre a prévia de impressão/compartilhamento do PDF da Súmula.
  Future<void> imprimirOuCompartilharSumula({
    required Partida partida,
    required String campeonatoNome,
    required List<Jogador> jogadoresTimeA,
    required List<Jogador> jogadoresTimeB,
    List<Lance> lances = const [],
  }) async {
    final pdf = pw.Document();
    final DateFormat formatoData = DateFormat("dd/MM/yyyy • HH'h'mm", 'pt_BR');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho Oficial
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange800,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SÚMULA OFICIAL DE JOGO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          campeonatoNome.toUpperCase(),
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'TVI NEWS ESPORTES',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Dados da Partida
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Local: ${partida.local ?? "A definir"}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'Data: ${partida.dataHora != null ? formatoData.format(partida.dataHora!) : "A definir"}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text('Rodada: ${partida.rodada}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Placar Oficial
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        partida.timeANome,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Text(
                      partida.placarA != null && partida.placarB != null
                          ? '${partida.placarA}  X  ${partida.placarB}'
                          : '   X   ',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange900),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        partida.timeBNome,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Escalações (2 Colunas)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Coluna Time A
                  pw.Expanded(
                    child: _construirTabelaJogadores(
                        partida.timeANome, jogadoresTimeA),
                  ),
                  pw.SizedBox(width: 12),
                  // Coluna Time B
                  pw.Expanded(
                    child: _construirTabelaJogadores(
                        partida.timeBNome, jogadoresTimeB),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Gols e Lances Registrados
              if (lances.isNotEmpty) ...[
                pw.Text('REGISTRO DE LANCES E GOLS',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('Min',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('Tipo',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('Atleta / Descrição',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...lances.take(8).map((l) => pw.TableRow(
                          children: [
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Text('${l.minuto}\'',
                                    style: const pw.TextStyle(fontSize: 8))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Text(l.tipoLabel,
                                    style: const pw.TextStyle(fontSize: 8))),
                            pw.Padding(
                                padding: const pw.EdgeInsets.all(3),
                                child: pw.Text(
                                    l.jogadorNome ?? l.descricao ?? '-',
                                    style: const pw.TextStyle(fontSize: 8))),
                          ],
                        )),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Campo de Assinaturas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _campoAssinatura('Capitão / Responsável (A)'),
                  _campoAssinatura('Árbitro Principal'),
                  _campoAssinatura('Capitão / Responsável (B)'),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Documento gerado automaticamente pelo App Xeh Esportes',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Exibe diálogo nativo com visualizador, impressão e compartilhamento
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sumula_${partida.timeANome}_vs_${partida.timeBNome}.pdf',
    );
  }

  pw.Widget _construirTabelaJogadores(String timeNome, List<Jogador> jogadores) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          color: PdfColors.grey300,
          child: pw.Center(
            child: pw.Text(timeNome,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Nº',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Nome do Atleta',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Pos',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            if (jogadores.isEmpty)
              pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Nenhum atleta cadastrado',
                          style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('-', style: const pw.TextStyle(fontSize: 8))),
                ],
              ),
            ...jogadores.take(15).map((j) => pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(
                            j.numero != null ? '${j.numero}' : '-',
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(j.nome,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(j.posicao ?? '-',
                            style: const pw.TextStyle(fontSize: 8))),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _campoAssinatura(String rotulo) {
    return pw.Column(
      children: [
        pw.Container(
          width: 140,
          height: 1,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 4),
        pw.Text(rotulo, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }
}
