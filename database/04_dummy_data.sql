-- ============================================================
-- Home Library App — Dummy Data & Trigger Testing
-- ============================================================

-- 1. Simulate the FastAPI backend setting the current user for auditing
SET @app_current_user_id = 1;

-- 2. Insert Users
INSERT INTO users (name, username, password_hash, role) VALUES 
('Vyshnav', 'vyshnav', 'dummyhash1', 'admin'),
('Brother', 'brother', 'dummyhash2', 'member');

-- 3. Insert Categories
INSERT INTO categories (name, description) VALUES 
('Fantasy', 'Magic and adventure'),
('Sci-Fi', 'Space and future tech');

-- 4. Insert Authors
INSERT INTO authors (name, name_normalized) VALUES 
('J.R.R. Tolkien', 'jrrtolkien'),
('Frank Herbert', 'frankherbert');

-- 5. Insert Books (Will trigger trg_log_books_insert)
INSERT INTO books (title, isbn, category_id, total_pages) VALUES 
('The Hobbit', '9780547928227', 1, 310),
('Dune', '9780441172719', 2, 412);

-- 6. Insert Book Authors
INSERT INTO book_authors (book_id, author_id) VALUES 
(1, 1), (2, 2);

-- 7. Insert Copies
INSERT INTO copies (book_id, copy_number, `condition`, source) VALUES 
(1, 1, 'good', 'purchased'),
(2, 1, 'new', 'gifted');

-- 8. Insert User Books (Will trigger trg_log_user_books_insert)
INSERT INTO user_books (user_id, book_id, status, rating) VALUES 
(1, 1, 'reading', NULL),
(1, 2, 'unread', NULL);

-- 9. Insert Reading Sessions (Will trigger trg_log_reading_insert, etc.)
INSERT INTO reading_sessions (user_books_id, user_id, pages_read, started_at, ended_at) VALUES 
(1, 1, 50, '2026-07-09 10:00:00', '2026-07-09 11:00:00');

-- 10. Test UPDATE (Will trigger trg_log_books_update)
UPDATE books SET total_pages = 320 WHERE id = 1;

-- 11. Test DELETE (Will trigger trg_log_user_books_delete)
DELETE FROM user_books WHERE user_id = 1 AND book_id = 2;
