# 📚 Home Library App — Active Project Tracker

## 🎯 What We Are Building
A personal home library management app for two users (you and your brother) on two separate Android phones. The app manages a shared physical book collection with individual reading tracking, wishlists, borrowed books, and ISBN barcode scanning to auto-fill book details from the web.

---

## 🛠 Tech Stack

| Layer | Technology | Status |
|---|---|---|
| Android App | Kotlin + Jetpack Compose | To do |
| ISBN Scanner | CameraX + ML Kit | To do |
| HTTP Client | Retrofit | To do |
| Local Cache (Stage 2) | Room (SQLite) | To do (Later) |
| Backend API | FastAPI (Python) | Completed |
| Database | MySQL | **Currently Using** |
| Auth | JWT + bcrypt | To do |
| Book Data APIs | Google Books API + Open Library API | To do |
| Server | Developer's local PC over home Wi-Fi | To do |
| Containerization | Docker + docker-compose | To do |
| Version Control | Git | To do |

---

## 🗄️ Database Schema (17 Tables)

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

## 🚀 Progress Tracker

### ✅ Step 1 — Database Layer (Completed)
- [x] Create 17 tables
- [x] Run `triggers_final.sql`
- [x] Write and run `functions.sql` (3 stored functions)
- [ ] *Optional:* Test triggers with dummy INSERT/UPDATE/DELETE statements

### ✅ Step 2 — Docker Setup (Completed)
- [x] Install Docker Desktop (Make sure this is installed on your machine)
- [x] Create project folder structure:
  ```
  home-library/
  ├── backend/
  ├── database/
  ├── android/
  ├── images/
  ├── docker-compose.yml
  ├── .env
  └── README.md
  ```
- [x] Write `docker-compose.yml` (MySQL + FastAPI services)
- [x] Write `.env` file (DB password, JWT secret — never commit this)
- [x] Run `docker-compose up` and verify MySQL starts with schema loaded automatically
- [x] Verify data persists in Docker named volume after restart

### ✅ Step 3 — Git Setup (Completed)
- [x] Run `git init` in project root
- [x] Create `.gitignore`
- [x] Create remote repo on GitHub or GitLab
- [x] Initial commit with project structure

### ✅ Step 4 — FastAPI Backend (Completed)
- [x] Set up Python virtual environment
- [x] Install dependencies (`fastapi`, `uvicorn`, `mysql-connector-python`, `passlib`, `python-jose`, `python-dotenv`)
- [x] Create `backend/requirements.txt`
- [x] Write `backend/database.py` (MySQL connection)
- [x] Implement `backend/utils/auth.py`
- [x] Create Pydantic models in `backend/models/schemas.py`
- [x] Implement `backend/routers/auth.py` (`/register`, `/login`)
- [x] Implement `backend/routers/books.py` (includes copies endpoints)
- [x] Implement `backend/routers/authors.py`
- [x] Implement `backend/routers/borrowed.py`
- [x] Implement `backend/routers/wishlist.py`
- [x] Implement `backend/routers/reading_sessions.py`
- [x] Implement `backend/main.py` (Entry point and static files)
- [x] Test endpoints at `http://localhost:8000/docs`

### 📅 Step 5 — Kotlin Android App
- [x] Create Android Studio project
- [x] Add dependencies (`Retrofit, Hilt, CameraX, ML Kit, Coil`)
- [x] Set up Hilt and Retrofit
- [ ] UI: Login, Home, Book list, Book detail, Add book
- [ ] Feature: Barcode scanner + ISBN auto-fill
- [ ] Feature: Borrowed tracker, Wishlist, Reading session logger

### 📅 Step 6 — Offline First (Stage 2)
- [ ] Add Room local database
- [ ] Add `updated_at` and `is_synced` columns
- [ ] Implement background sync logic

---

## 📝 Notes & Rewrites Area
*Use this section to jot down any architectural changes, new table ideas, or API rewrites as the project evolves.*
