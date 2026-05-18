# 📚 Home Library App — Project Status

## What We Are Building
A personal home library management app for two users (you and your brother) on two separate Android phones. The app manages a shared physical book collection with individual reading tracking, wishlists, borrowed books, and ISBN barcode scanning to auto-fill book details from the web.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Android App | Kotlin + Jetpack Compose |
| ISBN Scanner | CameraX + ML Kit |
| HTTP Client | Retrofit |
| Local Cache (Stage 2) | Room (SQLite) |
| Backend API | FastAPI (Python) |
| Database | MySQL |
| Auth | JWT + bcrypt |
| Book Data APIs | Google Books API + Open Library API |
| Server | Developer's local PC over home Wi-Fi |
| Containerization | Docker + docker-compose |
| Version Control | Git |

---

## Database — 17 Tables

| # | Table | Purpose |
|---|---|---|
| 1 | users | Login credentials, roles, profile |
| 2 | authors | Author details, bio, image, normalized name for duplicate detection |
| 3 | categories | Book genres and categories |
| 4 | tags | Shared tag reference table |
| 5 | books | Core book facts (title, isbn, pages, language, cover) |
| 6 | copies | Physical copies of a book (condition, source) |
| 7 | book_authors | Many-to-many: books ↔ authors |
| 8 | book_tags | Shared tags describing a book |
| 9 | user_books | Per-user reading status, rating, updated_at |
| 10 | user_book_tags | Personal tags per user per book |
| 11 | reading_sessions | Manual reading log per user (pages_read, started_at, ended_at) |
| 12 | borrowed | Tracks lent and borrowed copies per user |
| 13 | wishlist | Per-user wishlist of books not yet owned |
| 14 | wishlist_authors | Many-to-many: wishlist entries ↔ authors |
| 15 | deleted_books | Archive of deleted books (original_id + full JSON snapshot) |
| 16 | error_logs | Logs errors from triggers and API |
| 17 | activity_logs | Append-only audit trail of all data changes |

---

## ✅ Done

### Tables Created
- authors
- books *(status, rating, author_id dropped — handled by user_books and book_authors)*
- copies
- categories
- tags
- book_tags
- book_authors
- users
- user_books *(updated_at added)*
- user_book_tags
- reading_sessions *(redesigned — uses user_books_id, pages_read, started_at, ended_at)*
- borrowed
- wishlist
- wishlist_authors
- deleted_books *(recreated with original_id and JSON data column)*
- error_logs
- activity_logs

### Schema Decisions Made
- `status` and `rating` removed from `books` → moved to `user_books` (per-user)
- `author_id` removed from `books` → replaced by `book_authors` junction table (multi-author support)
- `reading_sessions` links to `user_books` not `books` directly — sessions are already user-scoped
- `start_date` / `finish_date` NOT stored on `user_books` — derived from `reading_sessions` queries
- `wishlist.author_id` is a proper FK to `authors` table (not a plain string) — achieves 4NF
- `deleted_books` stores full book row as JSON before deletion
- `name_normalized` on `authors` for duplicate detection when fetching from external APIs
- Two separate tag tables: `book_tags` (shared) and `user_book_tags` (personal per user)
- `borrowed` links to specific `copies`, not just `books`

---

## 🔄 In Progress

### Triggers & Functions
- `triggers_final.sql` written and ready to run
- Need to run: `mysql -u root -p home_library < triggers_final.sql`

#### Before running triggers, verify these are done:
```sql
-- 1. user_books must have updated_at
ALTER TABLE user_books ADD COLUMN updated_at DATETIME DEFAULT NULL;

-- 2. users must have updated_at
ALTER TABLE users ADD COLUMN updated_at DATETIME DEFAULT NULL;

-- 3. deleted_books must have original_id and data columns
-- (recreate if not done already)
DROP TABLE deleted_books;
CREATE TABLE deleted_books (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    original_id INT NOT NULL,
    data        JSON NOT NULL,
    deleted_by  INT,
    deleted_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL
);
```

---

## ❌ Not Started Yet

### Step 1 — Finish Database Layer
- [ ] Run `triggers_final.sql`
- [ ] Test triggers with dummy INSERT/UPDATE/DELETE statements
- [ ] Write and run `functions.sql` (3 stored functions below)

#### Stored Functions to Write
```
fn_total_pages_read(user_id, book_id)   → INT
fn_reading_progress(user_id, book_id)   → DECIMAL(5,2)  ← for progress bar in app
fn_is_copy_available(copy_id)           → BOOLEAN
```

---

### Step 2 — Docker Setup
- [ ] Install Docker Desktop
- [ ] Create project folder structure:
```
home-library/
├── backend/
├── database/
│   ├── schema.sql
│   ├── triggers_final.sql
│   └── functions.sql
├── android/
├── images/
│   ├── books/
│   └── authors/
├── docker-compose.yml
├── .env
├── .gitignore
└── README.md
```
- [ ] Write `docker-compose.yml` (MySQL + FastAPI services)
- [ ] Write `.env` file (DB password, JWT secret — never commit this)
- [ ] Run `docker-compose up` and verify MySQL starts with schema loaded automatically
- [ ] Verify data persists in Docker named volume after restart

---

### Step 3 — Git Setup
- [ ] Run `git init` in project root
- [ ] Create `.gitignore`:
```
.env
__pycache__/
*.pyc
venv/
mysql/data/
images/
build/
.gradle/
local.properties
```
- [ ] Create remote repo on GitHub or GitLab
- [ ] Initial commit with project structure
- [ ] Create `dev` branch for all development work
- [ ] Use `feature/*` branches for individual features

---

### Step 4 — FastAPI Backend
- [ ] Set up Python virtual environment
- [ ] Install dependencies:
```
fastapi uvicorn mysql-connector-python passlib python-jose python-dotenv
```
- [ ] Write `database.py` — MySQL connection
- [ ] Auth endpoints:
  - POST `/register`
  - POST `/login` → returns JWT token
- [ ] Books endpoints:
  - GET `/books`
  - POST `/books`
  - PUT `/books/{id}`
  - DELETE `/books/{id}`
  - GET `/isbn/{isbn}` → Google Books first, Open Library fallback
- [ ] Authors endpoints:
  - GET `/authors`
  - POST `/authors`
- [ ] Copies endpoints:
  - GET `/copies`
  - POST `/copies`
- [ ] Borrowed endpoints:
  - GET `/borrowed`
  - POST `/borrowed`
  - PUT `/borrowed/{id}` → mark as returned
- [ ] Wishlist endpoints:
  - GET `/wishlist`
  - POST `/wishlist`
  - DELETE `/wishlist/{id}`
  - PUT `/wishlist/{id}/move-to-library` → moves entry to books table
- [ ] Reading sessions endpoints:
  - GET `/reading-sessions`
  - POST `/reading-sessions`
- [ ] Static file serving → GET `/images/books/{filename}`
- [ ] Test all endpoints at `http://localhost:8000/docs` (FastAPI auto-docs)

---

### Step 5 — Kotlin Android App
- [ ] Create new Android Studio project (Empty Compose Activity)
- [ ] Add dependencies to `build.gradle`:
```
Retrofit, Hilt, Room, CameraX, ML Kit, Coil (image loading)
```
- [ ] Set up Hilt dependency injection
- [ ] Set up Retrofit with base URL pointing to PC's local IP
- [ ] **Login screen** — username/password, POST /login, store JWT
- [ ] **Home screen** — dashboard with quick stats
- [ ] **Book list screen** — list of books with covers, filter by status
- [ ] **Book detail screen** — full info, reading progress bar, sessions list
- [ ] **Add book screen** — manual form + ISBN scan button
- [ ] **CameraX + ML Kit** — barcode scanner for ISBN
- [ ] **ISBN auto-fill** — scan → call /isbn/{isbn} → populate form
- [ ] **Borrowed tracker screen** — lent out and borrowed lists with due dates
- [ ] **Wishlist screen** — per-user wishlist with priority indicators
- [ ] **Reading session logger** — log pages read, start/end time, notes

---

### Step 6 — Offline First (Stage 2 — Later)
- [ ] Add Room local SQLite database to Android project
- [ ] Add `updated_at` and `is_synced` columns to relevant tables
- [ ] Implement background sync logic — push unsynced rows to server when connected
- [ ] App reads/writes to Room first, FastAPI server is secondary

---

## Key Notes for Next AI Agent

- MySQL is currently running directly in terminal (no Docker yet)
- All 17 tables have been created and verified with `SHOW TABLES`
- `triggers_final.sql` is ready to run — see In Progress section above
- Schema follows 3NF/BCNF throughout
- Two users, two phones — data separated by `user_id` in all personal tables
- `reading_sessions` is manual — user logs sessions themselves, not automatic tracking
- Google Books API (free key) + Open Library (no key) used together for ISBN lookup
- PC must be on and running for app to work in Stage 1 (offline-first comes in Stage 2)
- `@app_current_user_id` session variable must be set by FastAPI on every DB connection before triggers can log correctly
