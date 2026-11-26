import 'dart:convert';

import 'package:intl/intl.dart';

import '../data/database/app_database.dart';
import '../models/recording_item.dart';

enum ExportMode {
  transcriptOnly,
  summaryOnly,
  fullWithAiPrompt,
}

class MarkdownExporter {
  MarkdownExporter._();

  static const int splitThresholdTokens = 30000;
  static const int defaultPartMaxTokens = 28000;

  /// Generates Markdown for [detail] in the requested [mode].
  static String generate(MeetingDetailData detail, ExportMode mode) {
    final buf = StringBuffer();
    final m = detail.meeting;

    final speakerNames = detail.speakers
        .map((s) => s.displayName.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final formattedDate =
        DateFormat('yyyy-MM-dd HH:mm').format(m.createdAt.toLocal());
    final formattedDuration = TimelineMarker.formatHms(m.durationMs);

    buf.writeln('---');
    buf.writeln('title: ${_yamlString(m.title)}');
    buf.writeln('date: ${_yamlString(formattedDate)}');
    buf.writeln('duration: ${_yamlString(formattedDuration)}');
    buf.writeln('language: ${_yamlString(m.language)}');
    final yamlSpeakers =
        speakerNames.map(_yamlString).join(', ');
    buf.writeln('speakers: [$yamlSpeakers]');
    buf.writeln('---');

    if (mode == ExportMode.fullWithAiPrompt) {
      buf.writeln('# Instructions for the AI');
      buf.writeln(
        'Summarize this meeting using only the transcript below. '
        'List decisions and action items with their owners and deadlines. '
        'Flag anything uncertain as unclear, do not invent details, and '
        'write your answer in the meeting\'s main language (${m.language}).',
      );
      buf.writeln();
    }

    final summary = detail.summary;
    final includeSummary =
        mode == ExportMode.summaryOnly || mode == ExportMode.fullWithAiPrompt;
    if (includeSummary && summary != null) {
      buf.writeln('# Summary');
      if (summary.row.summary.trim().isNotEmpty) {
        buf.writeln(summary.row.summary.trim());
        buf.writeln();
      }
      _writeBulletSection(buf, '## Key points', summary.keyPoints);
      _writeBulletSection(buf, '## Decisions', summary.decisions);
      if (detail.actionItems.isNotEmpty) {
        buf.writeln('## Action items');
        for (final item in detail.actionItems) {
          final box = item.done ? '[x]' : '[ ]';
          final due = (item.dueDate != null && item.dueDate!.trim().isNotEmpty)
              ? ' (due: ${item.dueDate!.trim()})'
              : '';
          buf.writeln('- $box ${item.task} — **${item.owner}**$due');
        }
        buf.writeln();
      }
      _writeBulletSection(buf, '## Open questions', summary.openQuestions);
    } else if (mode == ExportMode.summaryOnly && summary == null) {
      buf.writeln('# Summary');
      buf.writeln('_No summary available yet._');
      buf.writeln();
    }

    if (mode == ExportMode.transcriptOnly ||
        mode == ExportMode.fullWithAiPrompt) {
      buf.writeln('# Transcript');
      final entries = _buildChronologicalTranscriptLines(detail);
      if (entries.isEmpty) {
        buf.writeln('_No transcript or markers available._');
      } else {
        for (final line in entries) {
          buf.writeln(line);
        }
      }
    }

    return buf.toString().trimRight();
  }

  /// Rough token count (~4 characters per token) for chat paste sizing.
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4).ceil();
  }

  static bool needsSplitting(String markdown) {
    return estimateTokens(markdown) > splitThresholdTokens;
  }

  /// Splits [markdown] along line boundaries into numbered parts, each with a
  /// `"Part X of Y"` header when the content exceeds [maxTokensPerPart].
  static List<String> splitIntoParts(
    String markdown, {
    int maxTokensPerPart = defaultPartMaxTokens,
  }) {
    if (estimateTokens(markdown) <= maxTokensPerPart) {
      return [markdown];
    }

    final maxCharsPerPart = (maxTokensPerPart * 4) - 32;
    final lines = markdown.split('\n');
    final rawChunks = <String>[];
    final current = StringBuffer();

    for (final line in lines) {
      if (line.length > maxCharsPerPart) {
        if (current.isNotEmpty) {
          rawChunks.add(current.toString().trimRight());
          current.clear();
        }
        for (var i = 0; i < line.length; i += maxCharsPerPart) {
          final end = (i + maxCharsPerPart < line.length)
              ? i + maxCharsPerPart
              : line.length;
          rawChunks.add(line.substring(i, end));
        }
        continue;
      }

      final nextLen = current.length + line.length + 1;
      if (current.isNotEmpty && nextLen > maxCharsPerPart) {
        rawChunks.add(current.toString().trimRight());
        current.clear();
      }
      if (current.isNotEmpty) {
        current.writeln();
      }
      current.write(line);
    }

    if (current.isNotEmpty) {
      rawChunks.add(current.toString().trimRight());
    }

    final total = rawChunks.length;
    if (total <= 1) return rawChunks;

    return List<String>.generate(
      total,
      (i) => 'Part ${i + 1} of $total\n\n${rawChunks[i]}',
      growable: false,
    );
  }

  static List<String> _buildChronologicalTranscriptLines(
    MeetingDetailData detail,
  ) {
    final timeline = <({int ms, int order, String line})>[];
    var order = 0;

    for (final entry in detail.segments) {
      final seg = entry.segment;
      final ms = (seg.startSec * 1000).round();
      final ts = TimelineMarker.formatHms(ms);
      final speaker = entry.speaker?.displayName.trim();
      final speakerLabel =
          (speaker != null && speaker.isNotEmpty) ? speaker : 'Speaker';
      timeline.add((
        ms: ms,
        order: order++,
        line: '**[$ts] $speakerLabel:** ${seg.textContent}',
      ));
    }

    for (final marker in detail.markers) {
      timeline.add((
        ms: marker.startMs,
        order: order++,
        line: marker.exportLine,
      ));
    }

    timeline.sort((a, b) {
      final cmp = a.ms.compareTo(b.ms);
      return cmp != 0 ? cmp : a.order.compareTo(b.order);
    });

    return timeline.map((e) => e.line).toList(growable: false);
  }

  static void _writeBulletSection(
    StringBuffer buf,
    String heading,
    List<String> items,
  ) {
    if (items.isEmpty) return;
    buf.writeln(heading);
    for (final item in items) {
      buf.writeln('- $item');
    }
    buf.writeln();
  }

  static String _yamlString(String raw) {
    // jsonEncode wraps in double quotes and escapes control chars, backslashes,
    // quotes, colons, and hashes safely, which is valid YAML 1.2 scalar syntax.
    return jsonEncode(raw.replaceAll('\r\n', ' ').replaceAll('\n', ' '));
  }
}
