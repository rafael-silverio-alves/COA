import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import '../models/operacao_executada.dart';

class PdfService {
  // Paleta enterprise
  static const PdfColor _grafite = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _grafiteClaro = PdfColor.fromInt(0xFF374151);
  static const PdfColor _cinza = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _cinzaClaro = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _borda = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _branco = PdfColors.white;
  static const PdfColor _textoSuave = PdfColor.fromInt(0xFFD1D5DB);

  static const PdfColor _verde = PdfColor.fromInt(0xFF059669);
  static const PdfColor _azul = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _amarelo = PdfColor.fromInt(0xFFD97706);
  static const PdfColor _vermelho = PdfColor.fromInt(0xFFDC2626);

  Future<void> gerarRelatorioOperacoes({
    required List<OperacaoExecutada> operacoes,
    required Map<String, int> resumo,
    required Map<String, dynamic> insights,
    required List<Map<String, dynamic>> pivosProntosParaPlantio,
    required String filtroPivo,
    required String filtroOperacao,
    required DateTimeRange? filtroData,
    required String nomeUsuario,
    required DateTime dataGeracao,
  }) async {
    final pdf = pw.Document();
    final totalOperacoes = resumo.values.fold(0, (a, b) => a + b);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _cabecalho(nomeUsuario, dataGeracao, filtroPivo, filtroOperacao, filtroData),
            pw.SizedBox(height: 18),
            _secaoResumo(resumo, totalOperacoes, pivosProntosParaPlantio.length),
            pw.SizedBox(height: 16),
            _secaoIndicadores(insights),
            pw.SizedBox(height: 16),
            _secaoPivosProntos(pivosProntosParaPlantio),
            pw.Spacer(),
            _rodape(),
          ],
        ),
      ),
    );

    // Gera o PDF e faz download no navegador
    final pdfBytes = await pdf.save();

    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'SIGA_Relatorio_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      )
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================
  pw.Widget _cabecalho(
    String nomeUsuario,
    DateTime dataGeracao,
    String filtroPivo,
    String filtroOperacao,
    DateTimeRange? filtroData,
  ) {
    final filtrosAtivos = <String>[];
    if (filtroPivo != 'Todos') filtrosAtivos.add('Pivô: $filtroPivo');
    if (filtroOperacao != 'Todas') filtrosAtivos.add('Operação: $filtroOperacao');
    if (filtroData != null) {
      filtrosAtivos.add(
        'Período: ${_fmt(filtroData.start)} – ${_fmt(filtroData.end)}',
      );
    }
    final filtrosTexto = filtrosAtivos.isEmpty
        ? 'Sem filtros aplicados'
        : filtrosAtivos.join('   ·   ');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _grafite,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIGA',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _branco,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Relatório Operacional',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _textoSuave,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Gerado em ${_fmt(dataGeracao)} às ${_hora(dataGeracao)}',
                    style: pw.TextStyle(fontSize: 8, color: _textoSuave),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'por $nomeUsuario',
                    style: pw.TextStyle(fontSize: 8, color: _textoSuave),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _grafiteClaro,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'FILTROS  ',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _textoSuave,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    filtrosTexto,
                    style: pw.TextStyle(fontSize: 8, color: _branco),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESUMO GERAL
  // ============================================================
  pw.Widget _secaoResumo(
    Map<String, int> resumo,
    int total,
    int prontos,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloSecao('Resumo Geral'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _cardStatus('Concluído', resumo['Concluído'] ?? 0, _verde),
            pw.SizedBox(width: 6),
            _cardStatus('Em andamento', resumo['Em andamento'] ?? 0, _azul),
            pw.SizedBox(width: 6),
            _cardStatus('Planejada', resumo['Planejada'] ?? 0, _amarelo),
            pw.SizedBox(width: 6),
            _cardStatus('Atrasada', resumo['Atrasada'] ?? 0, _vermelho),
            pw.SizedBox(width: 6),
            _cardStatus('Dispensada', resumo['Dispensada'] ?? 0, _cinza),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: _cinzaClaro,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: _borda, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total de operações',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _grafiteClaro,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$total',
                      style: pw.TextStyle(
                        fontSize: 13,
                        color: _grafite,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: _verde,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Pivôs prontos para plantio',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _branco,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '$prontos',
                      style: pw.TextStyle(
                        fontSize: 13,
                        color: _branco,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cardStatus(String label, int valor, PdfColor cor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: _branco,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _borda, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 5,
              height: 5,
              decoration: pw.BoxDecoration(color: cor, shape: pw.BoxShape.circle),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '$valor',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _grafite,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, color: _cinza),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INDICADORES
  // ============================================================
  pw.Widget _secaoIndicadores(Map<String, dynamic> insights) {
    final totalRealizado =
        (insights['totalRealizado'] as num?)?.toDouble() ?? 0;
    final totalAExecutar =
        (insights['totalAExecutar'] as num?)?.toDouble() ?? 0;
    final dias = insights['diasAExecutar'] as int? ?? 0;
    final capacidade = (insights['capacidadeTotal'] as num?)?.toDouble() ?? 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloSecao('Indicadores'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _indicador('Realizado', '${totalRealizado.toStringAsFixed(0)} ha', _verde),
            pw.SizedBox(width: 6),
            _indicador('A executar', '${totalAExecutar.toStringAsFixed(0)} ha', _amarelo),
            pw.SizedBox(width: 6),
            _indicador('Tempo necessário', '$dias dias', _azul),
            pw.SizedBox(width: 6),
            _indicador(
              'Capacidade',
              '${capacidade.toStringAsFixed(1)} ha/dia',
              _grafiteClaro,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _indicador(String label, String valor, PdfColor cor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _branco,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: _borda, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 18,
              height: 3,
              decoration: pw.BoxDecoration(
                color: cor,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(height: 7),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _grafite,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7, color: _cinza),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PIVÔS PRONTOS PARA PLANTIO
  // ============================================================
  pw.Widget _secaoPivosProntos(List<Map<String, dynamic>> prontos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tituloSecao('Pivôs prontos para plantio'),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borda, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: _grafite,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'PIVÔ',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _branco,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'ÚLTIMA OPERAÇÃO',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _branco,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'CONCLUÍDAS',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _branco,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'PLANTIO',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _branco,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (prontos.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  child: pw.Center(
                    child: pw.Text(
                      'Nenhum pivô pronto para plantio no momento.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _cinza,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...prontos.map((p) {
                  final plantio = p['plantio'] as DateTime?;
                  final concluidas = p['concluidas'] as int? ?? 0;
                  final operacoes = p['operacoes'] as int? ?? 0;
                  final anterior = p['anterior'] as String?;

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: _borda, width: 0.5),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Row(
                            children: [
                              pw.Container(
                                width: 6,
                                height: 6,
                                decoration: pw.BoxDecoration(
                                  color: _verde,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Text(
                                p['nome'] as String? ?? '—',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _grafite,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            anterior ?? '—',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: _grafiteClaro,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '$concluidas/$operacoes',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: _grafiteClaro,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            plantio != null ? _fmt(plantio) : '—',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _grafite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  pw.Widget _tituloSecao(String titulo) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3,
          height: 13,
          decoration: pw.BoxDecoration(
            color: _grafite,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          titulo.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _grafite,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  pw.Widget _rodape() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _borda, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'SIGA · Sistema de Gestão Agrícola',
            style: pw.TextStyle(fontSize: 7, color: _cinza),
          ),
          pw.Text(
            'Documento gerado automaticamente',
            style: pw.TextStyle(
              fontSize: 7,
              color: _cinza,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _hora(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}