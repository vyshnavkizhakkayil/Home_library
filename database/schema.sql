-- ============================================================
--  HOME LIBRARY — Complete Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS home_library;
USE home_library;

-- ------------------------------------------------------------
-- USERS
-- ------------------------------------------------------------

CREATE TABLE users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    username      VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin', 'member') DEFAULT 'member',
    avatar_url    TEXT,
    is_active     BOOLEAN DEFAULT TRUE,
    last_login    TIMESTAMP,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- AUTHORS
-- ------------------------------------------------------------

CREATE TABLE authors (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    name             VARCHAR(255) NOT NULL,
    name_normalized  VARCHAR(255),               -- lowercase, no punctuation, for duplicate detection
                                                 -- e.g "J.K. Rowling" → "jk rowling"
    nationality      VARCHAR(100),
    bio              TEXT,
    birth_date       DATE,
    death_date       DATE,                       -- NULL if still alive
    image_url        TEXT,                       -- local file path e.g /images/authors/rowling.jpg
    website          VARCHAR(255),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
 );


-- ------------------------------------------------------------
-- CATEGORIES
-- ------------------------------------------------------------

CREATE TABLE categories (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,    -- e.g Fiction, Science, History 
    description TEXT
);

-- ------------------------------------------------------------
-- BOOKS
-- ------------------------------------------------------------

CREATE TABLE books (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    isbn            VARCHAR(20) UNIQUE,          -- scanned from barcode
    category_id     INT,
    publisher       VARCHAR(255),
    published_year  YEAR,
    total_pages     INT,
    language        VARCHAR(50) DEFAULT 'English',
    cover_image_url TEXT,                        
    description     TEXT,                        
    added_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL );


-- ------------------------------------------------------------
-- COPIES
-- One book can have multiple physical copies
-- borrowed table links to a specific copy, not just the book
-- ------------------------------------------------------------

CREATE TABLE copies (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    book_id       INT NOT NULL,
    copy_number   INT DEFAULT 1,                 -- 1st copy, 2nd copy etc
    condition     ENUM(
                      'new',
                      'good',
                      'worn',
                      'damaged'
                  ) DEFAULT 'good',
    source        ENUM(
                      'purchased',
                      'gifted',
                      'borrowed'
                  ) DEFAULT 'purchased',
    acquired_date DATE,
    notes         TEXT,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- TAGS
-- Many books can have many tags e.g favourite, school, reference
-- ------------------------------------------------------------
CREATE TABLE tags (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);



CREATE TABLE book_tags (
    book_id INT,
    tag_id  INT,
    PRIMARY KEY (book_id, tag_id),
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)  REFERENCES tags(id)  ON DELETE CASCADE
);


CREATE TABLE user_book_tags (
    user_id INT,
    book_id INT,
    tag_id  INT,
    PRIMARY KEY (user_id, book_id, tag_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)  REFERENCES tags(id)  ON DELETE CASCADE
);


-- ------------------------------------------------------------
-- AUTHORS
-- ------------------------------------------------------------

CREATE TABLE book_authors (
    book_id   INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id)   REFERENCES books(id)   ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE CASCADE
);



-- ------------------------------------------------------------
-- USER BOOKS
-- ------------------------------------------------------------

CREATE TABLE user_books (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    book_id    INT NOT NULL,
    status     ENUM(
                   'unread',
                   'reading',
                   'finished'
               ) DEFAULT 'unread',
    rating     TINYINT CHECK (rating BETWEEN 1 AND 5),
    UNIQUE KEY unique_user_book (user_id, book_id),    -- one record per user per book
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- READING SESSIONS
-- ------------------------------------------------------------

CREATE TABLE reading_sessions (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    book_id      INT NOT NULL,
    start_page   INT NOT NULL,
    end_page     INT NOT NULL,
    session_date DATE DEFAULT CURRENT_DATE,
    notes        TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- BORROWED
-- ------------------------------------------------------------

CREATE TABLE borrowed (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    copy_id     INT,
    direction   ENUM('lent', 'borrowed') NOT NULL,
    person_name VARCHAR(255) NOT NULL,
    phone       VARCHAR(20),
    borrow_date DATE DEFAULT CURRENT_DATE,
    due_date    DATE,
    return_date DATE,
    notes       TEXT,
    FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
    FOREIGN KEY (copy_id)  REFERENCES copies(id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- WISHLIST
-- ------------------------------------------------------------

CREATE TABLE wishlist (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    title           VARCHAR(255) NOT NULL,
    isbn            VARCHAR(20),
    category_id     INT,
    cover_image_url TEXT,
    description     TEXT,
    reason          TEXT,
    priority        ENUM('low', 'medium', 'high') DEFAULT 'medium',
    added_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- WISHLIST AUTHORS
-- ------------------------------------------------------------

CREATE TABLE wishlist_authors (
    wishlist_id INT,
    author_id   INT,
    PRIMARY KEY (wishlist_id, author_id),
    FOREIGN KEY (wishlist_id) REFERENCES wishlist(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id)   REFERENCES authors(id)  ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- DELETED BOOKS
-- ------------------------------------------------------------

CREATE TABLE deleted_books (
    id         INT PRIMARY KEY,
    title      VARCHAR(255),
    isbn       VARCHAR(20),
    deleted_by INT,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- ERROR LOGS
-- ------------------------------------------------------------

CREATE TABLE error_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT,                                -- who triggered it, NULL if system
    endpoint    VARCHAR(255),                       -- which API endpoint e.g /books/5
    method      VARCHAR(10),                        -- GET, POST, PUT, DELETE
    error_code  INT,                                -- HTTP status e.g 404, 500
    message     TEXT,                               -- actual error message
    stack_trace TEXT,                               -- full error details for debugging
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- ACTIVITY LOGS
-- ------------------------------------------------------------

CREATE TABLE activity_logs (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT,                                -- who did the action
    action      VARCHAR(100) NOT NULL,              -- e.g 'added_book', 'lent_copy'
    table_name  VARCHAR(100),                       -- which table was affected
    record_id   INT,                                -- which row was affected
    old_data    JSON,                               -- what the data looked like before
    new_data    JSON,                               -- what the data looks like after
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);





