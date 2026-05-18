-- =============================================================
--  HOME LIBRARY — TRIGGERS & STORED PROCEDURES (MySQL 8.0+)
--
--  Order of creation matters:
--    Section 0  — Helper stored procedures
--    Section 1  — activity_logs immutability guard
--    Section 2  — Zone 1: reference data (authors, categories, tags)
--    Section 3  — Zone 2: bridge layer (user_books, copies)
--    Section 4  — Zone 3: activity layer (reading_sessions, borrowed)
--    Section 5  — Zone 4: archive on book delete
--    Section 6  — Activity logging triggers (all main tables)
--
--  Session contract (set by the backend on every connection):
--    SET @app_current_user_id = <user_id>;
--
--  NOTE: MySQL does not support autonomous transactions.
--  If the parent transaction rolls back, activity_log and
--  error_log inserts within the same transaction roll back too.
--  This is expected and acceptable — a failed operation leaves
--  no orphaned log rows.
--
--  TRIGGERS SKIPPED (not needed):
--    trg_user_books_dates_insert  — start_date/finish_date not in schema
--    trg_user_books_dates_update  — same reason, covered by reading_sessions
-- =============================================================

DELIMITER $$


-- =============================================================
--  SECTION 0 — HELPER STORED PROCEDURES
--  These are called by triggers throughout the file.
--  Create them first.
-- =============================================================

DROP PROCEDURE IF EXISTS sp_log_activity$$
CREATE PROCEDURE sp_log_activity(
  IN p_table_name  VARCHAR(64),
  IN p_action      VARCHAR(10),    -- 'INSERT' | 'UPDATE' | 'DELETE'
  IN p_record_id   INT,
  IN p_user_id     INT,
  IN p_old_data    JSON,
  IN p_new_data    JSON
)
BEGIN
  INSERT INTO activity_logs (
    table_name, action, record_id, user_id, old_data, new_data, created_at
  ) VALUES (
    p_table_name, p_action, p_record_id, p_user_id, p_old_data, p_new_data, NOW()
  );
END$$


DROP PROCEDURE IF EXISTS sp_log_error$$
CREATE PROCEDURE sp_log_error(
  IN p_trigger_name   VARCHAR(64),
  IN p_table_name     VARCHAR(64),
  IN p_error_message  TEXT,
  IN p_context        JSON
)
BEGIN
  INSERT INTO error_logs (
    trigger_name, table_name, error_message, context, created_at
  ) VALUES (
    p_trigger_name, p_table_name, p_error_message, p_context, NOW()
  );
END$$


-- =============================================================
--  SECTION 1 — activity_logs: IMMUTABILITY GUARD
--  activity_logs is append-only. No row may ever be changed
--  or removed after it has been written.
-- =============================================================

DROP TRIGGER IF EXISTS trg_activity_logs_no_update$$
CREATE TRIGGER trg_activity_logs_no_update
  BEFORE UPDATE ON activity_logs
  FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'activity_logs is append-only — UPDATE is not permitted.';
END$$


DROP TRIGGER IF EXISTS trg_activity_logs_no_delete$$
CREATE TRIGGER trg_activity_logs_no_delete
  BEFORE DELETE ON activity_logs
  FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'activity_logs is append-only — DELETE is not permitted.';
END$$


-- =============================================================
--  SECTION 2 — ZONE 1: Reference data guards
--  authors, categories, tags are lookup tables that many
--  other tables reference. We block deletes that would orphan
--  those references and return a meaningful error message.
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- authors: block delete while the author is still credited
-- on any book or referenced in any wishlist.
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_author_delete$$
CREATE TRIGGER trg_guard_author_delete
  BEFORE DELETE ON authors
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM book_authors
  WHERE author_id = OLD.id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete author — they are still credited on one or more books. Remove from book_authors first.';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM wishlist_authors
  WHERE author_id = OLD.id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete author — they are referenced in one or more wishlists.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- categories: block delete while any book uses this category.
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_category_delete$$
CREATE TRIGGER trg_guard_category_delete
  BEFORE DELETE ON categories
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM books
  WHERE category_id = OLD.id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete category — it is assigned to one or more books. Reassign those books first.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- tags: block delete while the tag is in use globally
-- (book_tags) or personally (user_book_tags).
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_tag_delete$$
CREATE TRIGGER trg_guard_tag_delete
  BEFORE DELETE ON tags
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM book_tags
  WHERE tag_id = OLD.id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete tag — it is still used in book_tags.';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM user_book_tags
  WHERE tag_id = OLD.id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete tag — it is still used in user_book_tags.';
  END IF;
END$$


-- =============================================================
--  SECTION 3 — ZONE 2: Bridge layer
--  user_books  — duplicate guard
--  copies      — block delete on active loan
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- user_books: prevent inserting the same book twice for the
-- same user. The unique constraint on (user_id, book_id)
-- enforces this at the DB level; this trigger provides a
-- readable error before that constraint fires.
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_duplicate_user_book$$
CREATE TRIGGER trg_guard_duplicate_user_book
  BEFORE INSERT ON user_books
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM user_books
  WHERE user_id = NEW.user_id
    AND book_id = NEW.book_id;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This book is already in the user\'s library.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- copies: block hard-deletion of a copy that is currently
-- on an active loan (return_date IS NULL).
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_guard_copy_delete$$
CREATE TRIGGER trg_guard_copy_delete
  BEFORE DELETE ON copies
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM borrowed
  WHERE copy_id = OLD.id
    AND return_date IS NULL;

  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot delete this copy — it has an active loan. Return it first.';
  END IF;
END$$


-- =============================================================
--  SECTION 4 — ZONE 3: Activity layer
--  reading_sessions — validation + progress sync to user_books
--  borrowed         — open-loan guard + date coherence
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- reading_sessions: validate before INSERT.
--   Rule 1: user_books row must exist and belong to this user
--   Rule 2: ended_at must be strictly after started_at
--   Rule 3: pages_read cannot be negative
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_validate_reading_session_insert$$
CREATE TRIGGER trg_validate_reading_session_insert
  BEFORE INSERT ON reading_sessions
  FOR EACH ROW
BEGIN
  DECLARE v_owner_id INT;

  SELECT user_id INTO v_owner_id
  FROM user_books
  WHERE id = NEW.user_books_id;

  IF v_owner_id IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: the referenced user_books row does not exist.';
  END IF;

  IF v_owner_id != NEW.user_id THEN
    CALL sp_log_error(
      'trg_validate_reading_session_insert',
      'reading_sessions',
      'user_id mismatch on reading session insert',
      JSON_OBJECT(
        'session_user_id', NEW.user_id,
        'owner_user_id',   v_owner_id,
        'user_books_id',   NEW.user_books_id
      )
    );
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: user_id does not match the owner of this user_books record.';
  END IF;

  IF NEW.ended_at IS NOT NULL AND NEW.ended_at <= NEW.started_at THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: ended_at must be after started_at.';
  END IF;

  IF NEW.pages_read < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: pages_read cannot be negative.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- reading_sessions: same validations on UPDATE
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_validate_reading_session_update$$
CREATE TRIGGER trg_validate_reading_session_update
  BEFORE UPDATE ON reading_sessions
  FOR EACH ROW
BEGIN
  IF NEW.ended_at IS NOT NULL AND NEW.ended_at <= NEW.started_at THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: ended_at must be after started_at.';
  END IF;

  IF NEW.pages_read < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'reading_sessions: pages_read cannot be negative.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- reading_sessions → user_books: progress sync
-- After any write to reading_sessions, recalculate
-- total pages read and auto-update status on user_books.
--   unread  → reading  (first session logged)
--   reading → finished (total pages read >= book total_pages)
-- Three separate triggers required by MySQL syntax.
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_sync_progress_insert$$
CREATE TRIGGER trg_sync_progress_insert
  AFTER INSERT ON reading_sessions
  FOR EACH ROW
BEGIN
  DECLARE v_total_pages_read INT DEFAULT 0;
  DECLARE v_book_pages       INT;

  SELECT COALESCE(SUM(pages_read), 0) INTO v_total_pages_read
  FROM reading_sessions
  WHERE user_books_id = NEW.user_books_id;

  SELECT b.total_pages INTO v_book_pages
  FROM user_books ub
  JOIN books b ON b.id = ub.book_id
  WHERE ub.id = NEW.user_books_id;

  UPDATE user_books
  SET
    status = CASE
               WHEN v_book_pages IS NOT NULL
                AND v_total_pages_read >= v_book_pages
                AND status NOT IN ('finished', 'abandoned')
               THEN 'finished'
               WHEN status = 'unread'
               THEN 'reading'
               ELSE status
             END,
    updated_at = NOW()
  WHERE id = NEW.user_books_id;
END$$


DROP TRIGGER IF EXISTS trg_sync_progress_update$$
CREATE TRIGGER trg_sync_progress_update
  AFTER UPDATE ON reading_sessions
  FOR EACH ROW
BEGIN
  DECLARE v_total_pages_read INT DEFAULT 0;
  DECLARE v_book_pages       INT;

  SELECT COALESCE(SUM(pages_read), 0) INTO v_total_pages_read
  FROM reading_sessions
  WHERE user_books_id = NEW.user_books_id;

  SELECT b.total_pages INTO v_book_pages
  FROM user_books ub
  JOIN books b ON b.id = ub.book_id
  WHERE ub.id = NEW.user_books_id;

  UPDATE user_books
  SET
    status = CASE
               WHEN v_book_pages IS NOT NULL
                AND v_total_pages_read >= v_book_pages
                AND status NOT IN ('finished', 'abandoned')
               THEN 'finished'
               WHEN status = 'unread'
               THEN 'reading'
               ELSE status
             END,
    updated_at = NOW()
  WHERE id = NEW.user_books_id;
END$$


DROP TRIGGER IF EXISTS trg_sync_progress_delete$$
CREATE TRIGGER trg_sync_progress_delete
  AFTER DELETE ON reading_sessions
  FOR EACH ROW
BEGIN
  DECLARE v_total_pages_read INT DEFAULT 0;
  DECLARE v_book_pages       INT;

  SELECT COALESCE(SUM(pages_read), 0) INTO v_total_pages_read
  FROM reading_sessions
  WHERE user_books_id = OLD.user_books_id;

  SELECT b.total_pages INTO v_book_pages
  FROM user_books ub
  JOIN books b ON b.id = ub.book_id
  WHERE ub.id = OLD.user_books_id;

  UPDATE user_books
  SET
    status = CASE
               WHEN v_book_pages IS NOT NULL
                AND v_total_pages_read >= v_book_pages
                AND status NOT IN ('finished', 'abandoned')
               THEN 'finished'
               WHEN v_total_pages_read = 0
               THEN 'unread'
               ELSE status
             END,
    updated_at = NOW()
  WHERE id = OLD.user_books_id;
END$$


-- ─────────────────────────────────────────────────────────────
-- borrowed: validate before INSERT.
--   Rule 1: no other open loan exists on this copy
--   Rule 2: due_date must be in the future
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_validate_borrow_insert$$
CREATE TRIGGER trg_validate_borrow_insert
  BEFORE INSERT ON borrowed
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  SELECT COUNT(*) INTO v_count
  FROM borrowed
  WHERE copy_id     = NEW.copy_id
    AND return_date IS NULL;

  IF v_count > 0 THEN
    CALL sp_log_error(
      'trg_validate_borrow_insert',
      'borrowed',
      'Attempted to borrow a copy that already has an active loan',
      JSON_OBJECT('copy_id', NEW.copy_id, 'requested_by', NEW.user_id)
    );
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'This copy already has an active loan. It must be returned before it can be borrowed again.';
  END IF;

  IF NEW.due_date IS NOT NULL AND NEW.due_date <= CURDATE() THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'due_date must be a future date.';
  END IF;
END$$


-- ─────────────────────────────────────────────────────────────
-- borrowed: validate before UPDATE.
--   a) Recording a return  (setting return_date)
--   b) Changing copy_id    (re-check the new copy is free)
-- ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_validate_borrow_update$$
CREATE TRIGGER trg_validate_borrow_update
  BEFORE UPDATE ON borrowed
  FOR EACH ROW
BEGIN
  DECLARE v_count INT DEFAULT 0;

  IF NEW.copy_id != OLD.copy_id THEN
    SELECT COUNT(*) INTO v_count
    FROM borrowed
    WHERE copy_id     = NEW.copy_id
      AND return_date IS NULL;

    IF v_count > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The target copy already has an active loan.';
    END IF;
  END IF;

  IF NEW.return_date IS NOT NULL AND NEW.return_date < NEW.borrow_date THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'return_date cannot be before borrow_date.';
  END IF;
END$$


-- =============================================================
--  SECTION 5 — ZONE 4: Archive on book delete
--  Copies the full books row into deleted_books as JSON
--  BEFORE the row is removed, preserving all metadata.
-- =============================================================

DROP TRIGGER IF EXISTS trg_archive_deleted_book$$
CREATE TRIGGER trg_archive_deleted_book
  BEFORE DELETE ON books
  FOR EACH ROW
BEGIN
  INSERT INTO deleted_books (
    original_id,
    data,
    deleted_by,
    deleted_at
  ) VALUES (
    OLD.id,
    JSON_OBJECT(
      'id',             OLD.id,
      'title',          OLD.title,
      'isbn',           OLD.isbn,
      'category_id',    OLD.category_id,
      'total_pages',    OLD.total_pages,
      'published_year', OLD.published_year,
      'created_at',     OLD.added_at
    ),
    @app_current_user_id,
    NOW()
  );
END$$


-- =============================================================
--  SECTION 6 — ACTIVITY LOGGING TRIGGERS
--
--  One AFTER INSERT / UPDATE / DELETE per main table.
--  Each trigger calls sp_log_activity with a JSON snapshot
--  of the relevant columns.
-- =============================================================

-- ── users ─────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_users_insert$$
CREATE TRIGGER trg_log_users_insert
  AFTER INSERT ON users FOR EACH ROW
BEGIN
  CALL sp_log_activity('users', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'username', NEW.username, 'created_at', NEW.created_at));
END$$

DROP TRIGGER IF EXISTS trg_log_users_update$$
CREATE TRIGGER trg_log_users_update
  AFTER UPDATE ON users FOR EACH ROW
BEGIN
  CALL sp_log_activity('users', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'username', OLD.username),
    JSON_OBJECT('id', NEW.id, 'username', NEW.username));
END$$

DROP TRIGGER IF EXISTS trg_log_users_delete$$
CREATE TRIGGER trg_log_users_delete
  AFTER DELETE ON users FOR EACH ROW
BEGIN
  CALL sp_log_activity('users', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'username', OLD.username),
    NULL);
END$$


-- ── books ─────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_books_insert$$
CREATE TRIGGER trg_log_books_insert
  AFTER INSERT ON books FOR EACH ROW
BEGIN
  CALL sp_log_activity('books', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'title', NEW.title, 'isbn', NEW.isbn, 'category_id', NEW.category_id));
END$$

DROP TRIGGER IF EXISTS trg_log_books_update$$
CREATE TRIGGER trg_log_books_update
  AFTER UPDATE ON books FOR EACH ROW
BEGIN
  CALL sp_log_activity('books', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'title', OLD.title, 'isbn', OLD.isbn),
    JSON_OBJECT('id', NEW.id, 'title', NEW.title, 'isbn', NEW.isbn));
END$$

DROP TRIGGER IF EXISTS trg_log_books_delete$$
CREATE TRIGGER trg_log_books_delete
  AFTER DELETE ON books FOR EACH ROW
BEGIN
  CALL sp_log_activity('books', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'title', OLD.title, 'isbn', OLD.isbn),
    NULL);
END$$


-- ── copies ────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_copies_insert$$
CREATE TRIGGER trg_log_copies_insert
  AFTER INSERT ON copies FOR EACH ROW
BEGIN
  CALL sp_log_activity('copies', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'book_id', NEW.book_id, 'condition', NEW.condition));
END$$

DROP TRIGGER IF EXISTS trg_log_copies_update$$
CREATE TRIGGER trg_log_copies_update
  AFTER UPDATE ON copies FOR EACH ROW
BEGIN
  CALL sp_log_activity('copies', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'book_condition', OLD.book_condition, 'source', OLD.source),
    JSON_OBJECT('id', NEW.id, 'book_condition', NEW.book_condition, 'source', NEW.source));
END$$

DROP TRIGGER IF EXISTS trg_log_copies_delete$$sh
CREATE TRIGGER trg_log_copies_delete
  AFTER DELETE ON copies FOR EACH ROW
BEGIN
  CALL sp_log_activity('copies', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'book_id', OLD.book_id),
    NULL);
END$$


-- ── user_books ────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_user_books_insert$$
CREATE TRIGGER trg_log_user_books_insert
  AFTER INSERT ON user_books FOR EACH ROW
BEGIN
  CALL sp_log_activity('user_books', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'user_id', NEW.user_id, 'book_id', NEW.book_id, 'status', NEW.status));
END$$

DROP TRIGGER IF EXISTS trg_log_user_books_update$$
CREATE TRIGGER trg_log_user_books_update
  AFTER UPDATE ON user_books FOR EACH ROW
BEGIN
  CALL sp_log_activity('user_books', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'status', OLD.status, 'rating', OLD.rating),
    JSON_OBJECT('id', NEW.id, 'status', NEW.status, 'rating', NEW.rating));
END$$

DROP TRIGGER IF EXISTS trg_log_user_books_delete$$
CREATE TRIGGER trg_log_user_books_delete
  AFTER DELETE ON user_books FOR EACH ROW
BEGIN
  CALL sp_log_activity('user_books', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'user_id', OLD.user_id, 'book_id', OLD.book_id, 'status', OLD.status),
    NULL);
END$$


-- ── reading_sessions ──────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_reading_insert$$
CREATE TRIGGER trg_log_reading_insert
  AFTER INSERT ON reading_sessions FOR EACH ROW
BEGIN
  CALL sp_log_activity('reading_sessions', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'user_books_id', NEW.user_books_id,
                'pages_read', NEW.pages_read, 'started_at', NEW.started_at));
END$$

DROP TRIGGER IF EXISTS trg_log_reading_update$$
CREATE TRIGGER trg_log_reading_update
  AFTER UPDATE ON reading_sessions FOR EACH ROW
BEGIN
  CALL sp_log_activity('reading_sessions', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'pages_read', OLD.pages_read, 'ended_at', OLD.ended_at),
    JSON_OBJECT('id', NEW.id, 'pages_read', NEW.pages_read, 'ended_at', NEW.ended_at));
END$$

DROP TRIGGER IF EXISTS trg_log_reading_delete$$
CREATE TRIGGER trg_log_reading_delete
  AFTER DELETE ON reading_sessions FOR EACH ROW
BEGIN
  CALL sp_log_activity('reading_sessions', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'user_books_id', OLD.user_books_id, 'pages_read', OLD.pages_read),
    NULL);
END$$


-- ── borrowed ──────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_borrowed_insert$$
CREATE TRIGGER trg_log_borrowed_insert
  AFTER INSERT ON borrowed FOR EACH ROW
BEGIN
  CALL sp_log_activity('borrowed', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'copy_id', NEW.copy_id, 'user_id', NEW.user_id,
                'borrow_date', NEW.borrow_date, 'due_date', NEW.due_date));
END$$

DROP TRIGGER IF EXISTS trg_log_borrowed_update$$
CREATE TRIGGER trg_log_borrowed_update
  AFTER UPDATE ON borrowed FOR EACH ROW
BEGIN
  CALL sp_log_activity('borrowed', 'UPDATE', NEW.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'return_date', OLD.return_date, 'due_date', OLD.due_date),
    JSON_OBJECT('id', NEW.id, 'return_date', NEW.return_date, 'due_date', NEW.due_date));
END$$

DROP TRIGGER IF EXISTS trg_log_borrowed_delete$$
CREATE TRIGGER trg_log_borrowed_delete
  AFTER DELETE ON borrowed FOR EACH ROW
BEGIN
  CALL sp_log_activity('borrowed', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'copy_id', OLD.copy_id, 'user_id', OLD.user_id),
    NULL);
END$$


-- ── wishlist ──────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_log_wishlist_insert$$
CREATE TRIGGER trg_log_wishlist_insert
  AFTER INSERT ON wishlist FOR EACH ROW
BEGIN
  CALL sp_log_activity('wishlist', 'INSERT', NEW.id, @app_current_user_id,
    NULL,
    JSON_OBJECT('id', NEW.id, 'user_id', NEW.user_id, 'title', NEW.title));
END$$

DROP TRIGGER IF EXISTS trg_log_wishlist_delete$$
CREATE TRIGGER trg_log_wishlist_delete
  AFTER DELETE ON wishlist FOR EACH ROW
BEGIN
  CALL sp_log_activity('wishlist', 'DELETE', OLD.id, @app_current_user_id,
    JSON_OBJECT('id', OLD.id, 'user_id', OLD.user_id, 'title', OLD.title),
    NULL);
END$$


DELIMITER ;


-- =============================================================
--  QUICK REFERENCE — trigger and procedure count
--
--  Stored procedures     2   (sp_log_activity, sp_log_error)
--
--  activity_logs         2   (no-update guard, no-delete guard)
--  authors               1   (delete guard)
--  categories            1   (delete guard)
--  tags                  1   (delete guard)
--  user_books            4   (dupe guard, sync ×3, log ×3)
--  copies                4   (delete guard, log ×3)
--  reading_sessions      8   (validate ×2, sync ×3, log ×3)
--  borrowed              5   (validate ×2, log ×3)
--  books                 4   (archive on delete, log ×3)
--  wishlist              2   (log insert, log delete)
--  users                 3   (log ×3)
--
--  Total triggers:      35
--
--  SKIPPED (not needed):
--  trg_user_books_dates_insert  — start_date/finish_date not in schema
--  trg_user_books_dates_update  — same reason
-- =============================================================
