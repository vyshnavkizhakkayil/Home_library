-- ============================================================
-- Home Library App — Stored Functions
-- Run: mysql -u root -p home_library < functions.sql
-- ============================================================

DELIMITER $$

-- ------------------------------------------------------------
-- 1. fn_total_pages_read(user_id, book_id)
--    Returns total pages read by a user for a specific book
--    across all reading sessions.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_total_pages_read$$
CREATE FUNCTION fn_total_pages_read(
    p_user_id INT,
    p_book_id INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total INT DEFAULT 0;

    SELECT COALESCE(SUM(rs.pages_read), 0)
    INTO total
    FROM reading_sessions rs
    JOIN user_books ub ON rs.user_books_id = ub.id
    WHERE ub.user_id = p_user_id
      AND ub.book_id = p_book_id;

    RETURN total;
END$$


-- ------------------------------------------------------------
-- 2. fn_reading_progress(user_id, book_id)
--    Returns reading progress as a percentage (0.00 to 100.00)
--    based on pages_read vs total pages in the book.
--    Returns 0.00 if book has no page count.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_reading_progress$$
CREATE FUNCTION fn_reading_progress(
    p_user_id INT,
    p_book_id INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE pages_done INT DEFAULT 0;
    DECLARE total_pages INT DEFAULT 0;
    DECLARE progress DECIMAL(5,2) DEFAULT 0.00;

    -- Get total pages for the book
    SELECT COALESCE(pages, 0)
    INTO total_pages
    FROM books
    WHERE id = p_book_id;

    -- No pages recorded — can't calculate progress
    IF total_pages = 0 THEN
        RETURN 0.00;
    END IF;

    -- Get total pages read by this user for this book
    SET pages_done = fn_total_pages_read(p_user_id, p_book_id);

    -- Cap at 100.00 in case of over-logging
    SET progress = LEAST((pages_done / total_pages) * 100, 100.00);

    RETURN ROUND(progress, 2);
END$$


-- ------------------------------------------------------------
-- 3. fn_is_copy_available(copy_id)
--    Returns TRUE (1) if the copy is not currently lent out.
--    A copy is unavailable if there's an active 'lent' borrow
--    record with no return_date.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_is_copy_available$$
CREATE FUNCTION fn_is_copy_available(
    p_copy_id INT
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE active_lends INT DEFAULT 0;

    SELECT COUNT(*)
    INTO active_lends
    FROM borrowed
    WHERE copy_id = p_copy_id
      AND direction = 'lent'
      AND return_date IS NULL;

    RETURN active_lends = 0;
END$$


DELIMITER ;

-- ============================================================
-- Quick smoke tests — run manually to verify
-- ============================================================
-- SELECT fn_total_pages_read(1, 1);
-- SELECT fn_reading_progress(1, 1);
-- SELECT fn_is_copy_available(1);
-- ============================================================
