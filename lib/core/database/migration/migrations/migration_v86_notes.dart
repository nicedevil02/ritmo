import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV86Notes extends Migration {
  @override
  int get version => 86;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. notes table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        title TEXT,
        body TEXT NOT NULL DEFAULT '',
        titleNormalized TEXT NOT NULL DEFAULT '',
        bodyNormalized TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL DEFAULT 'NOTE',
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        isPrivate INTEGER NOT NULL DEFAULT 0,
        isPinned INTEGER NOT NULL DEFAULT 0,
        dayKey TEXT,
        sourceModule TEXT,
        sourceEntityId TEXT,
        captureContextJson TEXT,
        wordCount INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        openedAt INTEGER,
        openCount INTEGER NOT NULL DEFAULT 0,
        reviewAt INTEGER,
        reviewStage INTEGER NOT NULL DEFAULT 0,
        trashedAt INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_status_updated ON notes(status, updatedAt DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_kind_status ON notes(kind, status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_daykey ON notes(dayKey);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_source ON notes(sourceModule, sourceEntityId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_review ON notes(reviewAt);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(isPinned, updatedAt DESC);');

    // 2. note_links table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_links (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        linkModule TEXT NOT NULL,
        linkEntityId TEXT NOT NULL,
        linkAction TEXT,
        relation TEXT NOT NULL DEFAULT 'MENTIONS',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_note_links_unique ON note_links(noteId, linkModule, linkEntityId, relation);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_note_links_target ON note_links(linkModule, linkEntityId);');

    // 3. note_tags table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_tags (
        noteId TEXT NOT NULL,
        tag TEXT NOT NULL,
        tagNormalized TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'USER',
        createdAt INTEGER NOT NULL,
        PRIMARY KEY (noteId, tagNormalized),
        FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_note_tags_norm ON note_tags(tagNormalized);');

    // 4. note_attachments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_attachments (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'IMAGE',
        fileName TEXT NOT NULL,
        relativePath TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL,
        mimeType TEXT,
        caption TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_note_attachments_note ON note_attachments(noteId);');

    // 5. note_revisions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_revisions (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        body TEXT NOT NULL,
        wordCount INTEGER NOT NULL DEFAULT 0,
        reason TEXT NOT NULL DEFAULT 'AUTOSAVE',
        createdAt INTEGER NOT NULL,
        FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_note_revisions_note ON note_revisions(noteId, createdAt DESC);');

    // 6. note_experience_meta table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_experience_meta (
        noteId TEXT PRIMARY KEY,
        lesson TEXT NOT NULL,
        contextText TEXT,
        category TEXT NOT NULL DEFAULT 'GENERAL',
        importance INTEGER NOT NULL DEFAULT 3,
        occurredOnDayKey TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        showCount INTEGER NOT NULL DEFAULT 0,
        lastShownAtDayKey TEXT,
        acknowledgedCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_experience_active ON note_experience_meta(isActive, importance DESC);');

    // 7. Insert D-02 default settings
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final defaultSettings = {
      'module_notes_enabled': 'false',
      'notes_experience_card_enabled': 'true',
      'notes_experience_card_position': 'AFTER_TASKS',
      'notes_daily_note_enabled': 'false',
      'notes_resurfacing_enabled': 'true',
      'notes_review_reminder_enabled': 'false',
      'notes_ai_autotitle_enabled': 'true',
      'notes_weekly_review_enabled': 'true',
      'notes_fts_available': 'unknown',
      'notes_fts_index_version': '1',
      'ai_domain_notes_read': 'true',
    };

    for (final entry in defaultSettings.entries) {
      try {
        await db.insert(
          'app_settings',
          {'key': entry.key, 'value': entry.value, 'updatedAt': nowMs},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('[MigrationV86Notes] Error setting default key ${entry.key}: $e');
      }
    }

    // 8. D-01 FTS5 table in independent try/catch block
    bool ftsAvailable = false;
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
          noteId UNINDEXED,
          titleN,
          bodyN,
          tagsN,
          tokenize = "unicode61 remove_diacritics 2",
          prefix = '2 3'
        );
      ''');
      ftsAvailable = true;
    } catch (e) {
      debugPrint('[MigrationV86Notes] FTS5 not available on platform: $e');
    }

    try {
      await db.insert(
        'app_settings',
        {'key': 'notes_fts_available', 'value': ftsAvailable ? 'true' : 'false', 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
