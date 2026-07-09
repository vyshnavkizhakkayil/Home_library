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

## Key Notes for Next AI Agent

- MySQL is currently running directly in terminal (no Docker yet)
- All 17 tables have been created and verified with `SHOW TABLES`
- Triggers and functions have been created and verified in the database
- Schema follows 3NF/BCNF throughout
- Two users, two phones — data separated by `user_id` in all personal tables
- `reading_sessions` is manual — user logs sessions themselves, not automatic tracking
- Google Books API (free key) + Open Library (no key) used together for ISBN lookup
- PC must be on and running for app to work in Stage 1 (offline-first comes in Stage 2)
- `@app_current_user_id` session variable must be set by FastAPI on every DB connection before triggers can log correctly
