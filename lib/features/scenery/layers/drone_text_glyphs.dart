import 'dart:math' as math;
import 'dart:ui' as ui;

/// Dot-matrix sky-text for the drone show: the bitmap font and the layout that
/// turns a word into the normalized [DotCell]s the drone formation flies into.
/// Isolated from the drone kinematics so each can be read (and tested) alone.

/// One drone-text dot: a normalized backdrop-space [center] plus the cell's
/// normalized [width]/[height].
class DotCell {
  const DotCell(this.center, this.width, this.height);

  final ui.Offset center;
  final double width;
  final double height;
}

/// A dot-matrix glyph: one `'0'`/`'1'` string per row (7 rows, ≤5 wide).
class DotGlyph {
  const DotGlyph(this.rows);

  final List<String> rows;

  int get width => rows.first.length;
}

/// Lays [text] out as a row of normalized [DotCell]s packed into the sky-text
/// band. Returns a single tiny placeholder cell when the text yields no lit dots.
List<DotCell> textDotCells(String text) {
  const glyphGap = 1;
  const spaceWidth = 2;
  final rawCells = <({int x, int y})>[];
  var cursor = 0.0;
  for (final codePoint in text.runes) {
    final char = String.fromCharCode(codePoint).toUpperCase();
    if (char == ' ') {
      cursor += spaceWidth;
      continue;
    }
    final glyph = dotGlyphFor(char);
    for (var y = 0; y < glyph.rows.length; y++) {
      final row = glyph.rows[y];
      for (var x = 0; x < row.length; x++) {
        if (row.codeUnitAt(x) == 49) {
          rawCells.add((x: cursor.round() + x, y: y));
        }
      }
    }
    cursor += glyph.width + glyphGap;
  }

  if (rawCells.isEmpty) {
    return const [DotCell(ui.Offset(0.5, 0.22), 0.01, 0.01)];
  }

  rawCells.sort((a, b) {
    final x = a.x.compareTo(b.x);
    return x != 0 ? x : a.y.compareTo(b.y);
  });

  final width = math.max(cursor - glyphGap, 1);
  const rows = 7;
  const targetWidth = 0.3;
  const targetHeight = 0.08;
  const left = 0.35;
  const top = 0.205;
  final cellWidth = targetWidth / width;
  const cellHeight = targetHeight / rows;
  return [
    for (final cell in rawCells)
      DotCell(
        ui.Offset(
          left + (cell.x + 0.5) * cellWidth,
          top + (cell.y + 0.5) * cellHeight,
        ),
        cellWidth,
        cellHeight,
      ),
  ];
}

/// The dot-matrix bitmap for [char] (the caller uppercases), falling back to a
/// "?"-like glyph for unknown characters. Only the letters the drone show spells
/// ("Omah Lay" / "Moving") are defined.
DotGlyph dotGlyphFor(String char) {
  return switch (char) {
    'O' => const DotGlyph([
      '01110',
      '10001',
      '10001',
      '10001',
      '10001',
      '10001',
      '01110',
    ]),
    'M' => const DotGlyph([
      '10001',
      '11011',
      '10101',
      '10101',
      '10001',
      '10001',
      '10001',
    ]),
    'V' => const DotGlyph([
      '10001',
      '10001',
      '10001',
      '10001',
      '01010',
      '01010',
      '00100',
    ]),
    'I' => const DotGlyph([
      '111',
      '010',
      '010',
      '010',
      '010',
      '010',
      '111',
    ]),
    'N' => const DotGlyph([
      '10001',
      '11001',
      '10101',
      '10011',
      '10001',
      '10001',
      '10001',
    ]),
    'G' => const DotGlyph([
      '01110',
      '10001',
      '10000',
      '10111',
      '10001',
      '10001',
      '01110',
    ]),
    'A' => const DotGlyph([
      '01110',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ]),
    'H' => const DotGlyph([
      '10001',
      '10001',
      '10001',
      '11111',
      '10001',
      '10001',
      '10001',
    ]),
    'L' => const DotGlyph([
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '10000',
      '11111',
    ]),
    'Y' => const DotGlyph([
      '10001',
      '01010',
      '00100',
      '00100',
      '00100',
      '00100',
      '00100',
    ]),
    _ => const DotGlyph([
      '111',
      '001',
      '010',
      '010',
      '000',
      '010',
      '000',
    ]),
  };
}
