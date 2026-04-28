import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import '../models/operacao_executada.dart';

class PdfService {
  Future<void> gerarRelatorioOperacoes({
    required List<OperacaoExecutada> operacoes,
    required Map<String, int> resumo,
    required Map<String, dynamic> insights,
    required String filtroPivo,
    required String filtroOperacao,
    required DateTimeRange? filtroData,
    required String nomeUsuario,
    required DateTime dataGeracao,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy');

    // Ordenar operações: Concluídas, Atrasadas, Em andamento, Planejadas, Dispensadas
    final ordenadas = <OperacaoExecutada>[];
    ordenadas.addAll(operacoes.where((op) => op.status == 'concluida').toList());
    ordenadas.addAll(operacoes.where((op) => op.status == 'atrasada').toList());
    ordenadas.addAll(operacoes.where((op) => op.status == 'em_andamento').toList());
    ordenadas.addAll(operacoes.where((op) => op.status == 'planejada').toList());
    ordenadas.addAll(operacoes.where((op) => op.status == 'dispensada').toList());

    // Página 1 - Resumo
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _titulo(),
            pw.SizedBox(height: 15),
            _informacoes(nomeUsuario, dataGeracao, filtroPivo, filtroOperacao, filtroData, ordenadas.length, df),
            pw.SizedBox(height: 20),
            _metricasOperacionais(insights),
            pw.SizedBox(height: 20),
            _resumoOperacoes(resumo, ordenadas.length),
          ],
        ),
      ),
    );

    // Páginas seguintes - Lista completa de operações
    const itemsPerPage = 20;
    final totalPages = (ordenadas.length / itemsPerPage).ceil();
    
    for (var i = 0; i < ordenadas.length; i += itemsPerPage) {
      final end = (i + itemsPerPage < ordenadas.length) ? i + itemsPerPage : ordenadas.length;
      final pageOps = ordenadas.sublist(i, end);
      final pageNum = (i ~/ itemsPerPage) + 1;
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          build: (context) => _listaOperacoes(pageOps, df, i + 1, end, ordenadas.length, pageNum, totalPages),
        ),
      );
    }

    // Download
    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'relatorio_operacoes_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  pw.Widget _titulo() {
    return pw.Column(
      children: [
        pw.Text('SIGA APP', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
        pw.SizedBox(height: 5),
        pw.Text('RELATORIO DE OPERACOES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Sistema de Gestao Agricola', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _informacoes(String nome, DateTime data, String pivo, String op, DateTimeRange? periodo, int total, DateFormat df) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('INFORMACOES DO RELATORIO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _linha('Data de emissao'),
                  _linha('Gerado por'),
                  _linha('Periodo analisado'),
                  _linha('Filtro pivo'),
                  _linha('Filtro operacao'),
                  _linha('Total de operacoes'),
                ],
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _linhaValor('${df.format(data)} ${DateFormat('HH:mm').format(data)}'),
                  _linhaValor(nome),
                  _linhaValor(periodo != null ? '${df.format(periodo.start)} a ${df.format(periodo.end)}' : 'Todos os periodos'),
                  _linhaValor(pivo == 'Todos' ? 'Todos os pivos' : pivo),
                  _linhaValor(op == 'Todas' ? 'Todas as operacoes' : op),
                  _linhaValor(total.toString()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _linha(String label) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
    );
  }

  pw.Widget _linhaValor(String valor) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(valor, style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
    );
  }

  pw.Widget _metricasOperacionais(Map<String, dynamic> insights) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('METRICAS OPERACIONAIS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            _metricaCard('Total Realizado', '${(insights['totalRealizado'] ?? 0).toStringAsFixed(0)} ha'),
            _metricaCard('Total a Executar', '${(insights['totalAExecutar'] ?? 0).toStringAsFixed(0)} ha'),
            _metricaCard('Dias Necessarios', '${insights['diasAExecutar'] ?? 0} dias'),
            _metricaCard('Rendimento Medio', '${(insights['rendimentoMedio'] ?? 0).toStringAsFixed(1)} ha/dia'),
          ],
        ),
      ],
    );
  }

  pw.Widget _metricaCard(String titulo, String valor) {
    return pw.Container(
      width: 120,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(titulo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 4),
          pw.Text(valor, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  pw.Widget _resumoOperacoes(Map<String, int> resumo, int total) {
    final items = [
      {'name': 'Concluidas', 'value': resumo['Concluído'] ?? 0, 'color': PdfColors.green},
      {'name': 'Atrasadas', 'value': resumo['Atrasada'] ?? 0, 'color': PdfColors.red},
      {'name': 'Em andamento', 'value': resumo['Em andamento'] ?? 0, 'color': PdfColors.blue},
      {'name': 'Planejadas', 'value': resumo['Planejada'] ?? 0, 'color': PdfColors.orange},
      {'name': 'Dispensadas', 'value': resumo['Dispensada'] ?? 0, 'color': PdfColors.grey},
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('RESUMO DAS OPERACOES', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 10),
        // Cards de quantidade
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return _cardQuantidade(item['name'] as String, item['value'] as int);
          }).toList(),
        ),
        pw.SizedBox(height: 16),
        // Barra de distribuição
        pw.Text('DISTRIBUICAO POR STATUS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 25,
          width: 400,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: items.map((item) {
              final value = item['value'] as int;
              final percent = total > 0 ? value / total : 0.0;
              return pw.Expanded(
                flex: (percent * 100).toInt(),
                child: pw.Container(color: item['color'] as PdfColor),
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          alignment: pw.WrapAlignment.center,
          spacing: 15,
          runSpacing: 5,
          children: items.map((item) {
            final value = item['value'] as int;
            if (value == 0) return pw.SizedBox.shrink();
            final percent = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0';
            return pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(width: 12, height: 12, color: item['color'] as PdfColor),
                pw.SizedBox(width: 6),
                pw.Text('${item['name']}: $value ($percent%)', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _cardQuantidade(String titulo, int valor) {
    PdfColor corFundo;
    if (titulo == 'Concluidas') corFundo = PdfColors.green;
    else if (titulo == 'Atrasadas') corFundo = PdfColors.red;
    else if (titulo == 'Em andamento') corFundo = PdfColors.blue;
    else if (titulo == 'Planejadas') corFundo = PdfColors.orange;
    else corFundo = PdfColors.grey;
    
    return pw.Container(
      width: 100,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor(corFundo.red, corFundo.green, corFundo.blue, 0.5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(titulo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(height: 4),
          pw.Text(valor.toString(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
    );
  }

  pw.Widget _listaOperacoes(List<OperacaoExecutada> ops, DateFormat df, int inicio, int fim, int total, int pagina, int totalPaginas) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('DETALHAMENTO DAS OPERACOES', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
        pw.SizedBox(height: 5),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Mostrando operacoes $inicio a $fim de $total', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text('Pagina $pagina de $totalPaginas', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 12),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(1.8),
            5: pw.FlexColumnWidth(0.9),
            6: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _th('Operacao'),
                _th('Pivo'),
                _th('Status'),
                _th('Area (ha)'),
                _th('Janela de Execucao'),
                _th('Rendimento'),
                _th('Dias'),
              ],
            ),
            ...ops.map((op) => pw.TableRow(
              children: [
                _tdCenter(_removerAcentos(op.operacaoNome ?? '-')),
                _tdCenter(_removerAcentos(op.pivoNome ?? '-')),
                _buildStatusCell(op, df),
                _tdCenter(op.areaTotal?.toStringAsFixed(0) ?? '-'),
                _tdCenter('${df.format(op.getDataInicioJanelaCalculada())} a ${df.format(op.getDataFimJanelaCalculada())}'),
                _tdCenter('${op.rendimentoHaDia?.toStringAsFixed(1) ?? 0} ha/dia'),
                _tdCenter(op.getDiasNecessarios().toString()),
              ],
            )),
          ],
        ),
        
        pw.SizedBox(height: 15),
        pw.Center(
          child: pw.Text(
            'Relatorio gerado automaticamente pelo SIGA App',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
    );
  }

  pw.Widget _th(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
    );
  }

  pw.Widget _tdCenter(String text) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, color: PdfColors.black)),
    );
  }

  pw.Widget _buildStatusCell(OperacaoExecutada op, DateFormat df) {
    String statusText = op.getStatusText();
    String status = op.status;
    
    final isAtrasadaReal = op.isRealmenteAtrasada;
    
    PdfColor cor;
    if (status == 'concluida') cor = PdfColors.green;
    else if (status == 'em_andamento') cor = PdfColors.blue;
    else if (status == 'atrasada') cor = PdfColors.red;
    else if (status == 'dispensada') cor = PdfColors.grey;
    else cor = PdfColors.orange;
    
    if (isAtrasadaReal && status != 'atrasada' && status != 'concluida' && status != 'dispensada') {
      cor = PdfColors.red;
      statusText = '$statusText (Atrasada)';
    }
    
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.all(3),
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColor(cor.red, cor.green, cor.blue, 0.15),
          borderRadius: pw.BorderRadius.circular(3),
          border: isAtrasadaReal && status != 'atrasada' 
              ? pw.Border.all(color: PdfColors.red, width: 0.5) 
              : null,
        ),
        child: pw.Text(statusText, style: pw.TextStyle(fontSize: 7, color: cor, fontWeight: pw.FontWeight.bold)),
      ),
    );
  }

  String _removerAcentos(String texto) {
    if (texto == 'Todos') return 'Todos';
    if (texto == 'Todas') return 'Todas';
    
    final comAcentos = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    final semAcentos = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    
    for (int i = 0; i < comAcentos.length; i++) {
      texto = texto.replaceAll(comAcentos[i], semAcentos[i]);
    }
    return texto;
  }
}