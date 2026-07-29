import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:smart_wrong_notebook/src/domain/models/question_record.dart';
import 'package:smart_wrong_notebook/src/domain/models/mastery_level.dart';
import 'package:smart_wrong_notebook/src/shared/widgets/math_content_view.dart';

class PdfExportService {
  pw.Font? _font;

  Future<pw.Font> _getFont() async {
    if (_font != null) return _font!;
    final fontData = await rootBundle.load('assets/fonts/NotoSansSC.ttf');
    _font = pw.Font.ttf(fontData);
    return _font!;
  }

  static const _accent = PdfColor.fromInt(0xFF4F46E5);
  static const _orange = PdfColor.fromInt(0xFFD97706);
  static const _green = PdfColor.fromInt(0xFF16A34A);
  static const _gray = PdfColor.fromInt(0xFF6B7280);
  static const _lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const _border = PdfColor.fromInt(0xFFE2E8F0);
  static const _dividerColor = PdfColor.fromInt(0xFFCBD5E1);
  // Semi-transparent versions (ARGB)
  static const _accentBg = PdfColor.fromInt(0x1A4F46E5);
  static const _greenBg = PdfColor.fromInt(0x0D16A34A);
  static const _orangeBg = PdfColor.fromInt(0x0DD97706);
  static const _purpleBg = PdfColor.fromInt(0x0D7C3AED);

  Future<File> generatePdf({
    required List<QuestionRecord> questions,
    String title = '错题本',
  }) async {
    final font = await _getFont();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 50,
          vertical: 56,
        ),
        header: (ctx) => _buildHeader(title),
        footer: (ctx) => _buildFooter(),
        build: (ctx) => [
          // Title block
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '导出日期：${_formatDate(DateTime.now())} ｜ 共 ${questions.length} 题',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _gray,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: _border, thickness: 1),
          pw.SizedBox(height: 8),

          // Question count summary
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Row(
              children: [
                _buildStatChip('总题数', '${questions.length}', _accent),
                pw.SizedBox(width: 12),
                _buildStatChip(
                  '待复习',
                  '${questions.where((q) => q.masteryLevel != MasteryLevel.mastered).length}',
                  _orange,
                ),
                pw.SizedBox(width: 12),
                _buildStatChip(
                  '已掌握',
                  '${questions.where((q) => q.masteryLevel == MasteryLevel.mastered).length}',
                  _green,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Question list
          for (int i = 0; i < questions.length; i++) ...[
            _buildQuestionBlock(questions[i], i + 1),
            if (i < questions.length - 1)
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Divider(color: _dividerColor, thickness: 0.5),
              ),
          ],

          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '由 AI 错题本 生成',
              style: pw.TextStyle(fontSize: 8, color: _gray),
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) {
      await exportDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/wrong_notebook_$timestamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _buildHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, color: _gray)),
          pw.Text(
            _formatDate(DateTime.now()),
            style: pw.TextStyle(fontSize: 9, color: _gray),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Container(
        height: 1,
        color: _border,
      ),
    );
  }

  pw.Widget _buildStatChip(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(_withAlpha(color.toInt(), 0x1A)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildQuestionBlock(QuestionRecord q, int index) {
    final analysis = q.analysisResult;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header: index + subject badge + mastery badge
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: [
                // Question number
                pw.Container(
                  width: 22,
                  height: 22,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _accentBg,
                    borderRadius: pw.BorderRadius.circular(11),
                  ),
                  child: pw.Text(
                    '$index',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                // Subject tag
                _buildTag(
                    q.subject.label, _accent, _accentBg),
                pw.SizedBox(width: 6),
                // Mastery tag
                _buildTag(
                  _masteryLabel(q.masteryLevel),
                  _masteryColor(q.masteryLevel),
                  PdfColor.fromInt(
                    _withAlpha(_masteryColor(q.masteryLevel).toInt(), 0x1A),
                  ),
                ),
              ],
            ),
          ),

          // Question text
          if (q.normalizedQuestionText.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: _border),
              ),
              child: pw.Text(
                MathContentView.latexToReadable(q.normalizedQuestionText),
                style: pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 8),
          ],

          // Answer
          if (analysis != null && analysis.finalAnswer.isNotEmpty) ...[
            _buildInfoRow(
              '正确答案：',
              MathContentView.latexToReadable(analysis.finalAnswer),
              _green,
              _greenBg,
            ),
          ],

          // Mistake reason
          if (analysis != null && analysis.mistakeReason.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _buildInfoRow(
              '错因分析：',
              MathContentView.latexToReadable(analysis.mistakeReason),
              _orange,
              _orangeBg,
            ),
          ],

          // Knowledge points
          if (analysis != null && analysis.knowledgePoints.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.RichText(
              text: pw.TextSpan(
                text: '知识点：',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _gray,
                  fontWeight: pw.FontWeight.bold,
                ),
                children: [
                  pw.TextSpan(
                    text: analysis.knowledgePoints.join('、'),
                    style: pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // AI Tags
          if (q.aiTags.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.RichText(
              text: pw.TextSpan(
                text: '标签：',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: _gray,
                  fontWeight: pw.FontWeight.bold,
                ),
                children: [
                  pw.TextSpan(
                    text: q.aiTags.join(', '),
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],

          // Steps
          if (analysis != null && analysis.steps.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              '解题步骤：',
              style: pw.TextStyle(
                fontSize: 9,
                color: _gray,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            for (int i = 0; i < analysis.steps.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${i + 1}. ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: _accent,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        MathContentView.latexToReadable(analysis.steps[i]),
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Study advice
          if (analysis != null && analysis.studyAdvice.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _buildInfoRow(
              '学习建议：',
              MathContentView.latexToReadable(analysis.studyAdvice),
              const PdfColor.fromInt(0xFF7C3AED),
              _purpleBg,
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildTag(String label, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          color: textColor,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(
      String label, String value, PdfColor color, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: 10),
          children: [
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  /// Combine RGB from [colorInt] (0xRRGGBB) with alpha [a] (0x00-0xFF).
  static int _withAlpha(int colorInt, int a) {
    final rgb = colorInt & 0xFFFFFF;
    return (a << 24) | rgb;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _masteryLabel(MasteryLevel level) {
    switch (level) {
      case MasteryLevel.newQuestion:
        return '未复习';
      case MasteryLevel.reviewing:
        return '复习中';
      case MasteryLevel.mastered:
        return '已掌握';
    }
  }

  PdfColor _masteryColor(MasteryLevel level) {
    switch (level) {
      case MasteryLevel.newQuestion:
        return _gray;
      case MasteryLevel.reviewing:
        return _orange;
      case MasteryLevel.mastered:
        return _green;
    }
  }
}
