import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_wrong_notebook/src/app/providers.dart';
import 'package:smart_wrong_notebook/src/domain/models/question_record.dart';
import 'package:smart_wrong_notebook/src/domain/models/subject.dart';
import 'package:smart_wrong_notebook/src/features/export/pdf_export_service.dart';

enum PdfExportScope {
  all,
  filtered,
  bySubject,
}

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key});

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
  PdfExportScope _scope = PdfExportScope.filtered;
  Subject? _selectedSubject;
  bool _isExporting = false;
  double? _progress;

  final _service = PdfExportService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allQuestionsAsync = ref.watch(questionListProvider);
    final filteredQuestionsAsync = ref.watch(filteredQuestionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出 PDF'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          // 标题区
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_on_doc,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '导出为 A4 PDF 文稿',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '将错题整理成 A4 格式文档，可打印或分享',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 范围选择
          Text(
            '导出范围',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          _ScopeOption(
            icon: CupertinoIcons.square_list_fill,
            title: '当前筛选结果',
            subtitle: '仅导出错题本中当前筛选出的题目',
            isSelected: _scope == PdfExportScope.filtered,
            onTap: () => setState(() => _scope = PdfExportScope.filtered),
            trailing: filteredQuestionsAsync.when(
              data: (q) => Text('${q.length} 题'),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Text('加载失败'),
            ),
          ),
          const SizedBox(height: 8),

          _ScopeOption(
            icon: CupertinoIcons.tray_full_fill,
            title: '全部错题',
            subtitle: '导出错题本中的所有题目',
            isSelected: _scope == PdfExportScope.all,
            onTap: () => setState(() => _scope = PdfExportScope.all),
            trailing: allQuestionsAsync.when(
              data: (q) => Text('${q.length} 题'),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Text('加载失败'),
            ),
          ),
          const SizedBox(height: 8),

          _ScopeOption(
            icon: CupertinoIcons.bookmark_fill,
            title: '按科目选择',
            subtitle: '选择一个科目，导出其下所有错题',
            isSelected: _scope == PdfExportScope.bySubject,
            onTap: () => setState(() => _scope = PdfExportScope.bySubject),
          ),

          // Subject selector
          if (_scope == PdfExportScope.bySubject) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Subject>(
                  value: _selectedSubject,
                  isExpanded: true,
                  hint: Text(
                    '请选择科目',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  items: Subject.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: <Widget>[
                              Icon(s.icon, size: 18, color: s.color),
                              const SizedBox(width: 10),
                              Text(s.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (s) => setState(() => _selectedSubject = s),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 预览信息
          allQuestionsAsync.when(
            data: (all) {
              final selected = _getQuestions(all);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text,
                        color: Color(0xFF4F46E5),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '将导出 ',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${selected.length} 道错题',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Export button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _exportPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(CupertinoIcons.share),
              label: Text(
                _isExporting ? '正在生成...' : '生成并导出 PDF',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),

          if (_progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${(_progress! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<QuestionRecord> _getQuestions(List<QuestionRecord> all) {
    switch (_scope) {
      case PdfExportScope.filtered:
        return ref.read(filteredQuestionListProvider).valueOrNull ?? [];
      case PdfExportScope.all:
        return all;
      case PdfExportScope.bySubject:
        if (_selectedSubject == null) return [];
        return all
            .where((q) => q.subject == _selectedSubject)
            .toList();
    }
  }

  Future<void> _exportPdf() async {
    final scaffold = ScaffoldMessenger.of(context);
    final allQuestions = ref.read(questionListProvider).valueOrNull ?? [];

    final selected = _getQuestions(allQuestions);
    if (selected.isEmpty) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('没有符合条件的错题可以导出')),
      );
      return;
    }

    if (_scope == PdfExportScope.bySubject && _selectedSubject == null) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('请先选择一个科目')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0.0;
    });

    try {
      _animateProgress();

      final file = await _service.generatePdf(
        questions: selected,
        title: _scope == PdfExportScope.bySubject && _selectedSubject != null
            ? '${_selectedSubject!.label}错题本'
            : '错题本',
      );

      setState(() => _progress = 1.0);

      if (!context.mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '导出 ${selected.length} 道错题（PDF格式）',
      );

      scaffold.showSnackBar(
        SnackBar(content: Text('成功导出 ${selected.length} 道错题')),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
        _progress = null;
      });
    }
  }

  void _animateProgress() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted || !_isExporting) return false;
      setState(() {
        _progress = (_progress! + 0.15).clamp(0.0, 0.9);
      });
      return _progress! < 0.9;
    });
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEEF2FF)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : colorScheme.outlineVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 20,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : colorScheme.outlineVariant,
              ),
          ],
        ),
      ),
    );
  }
}
