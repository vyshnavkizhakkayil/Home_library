# 📝 Home Library App — Changelog

*This file tracks all significant changes, commands run, and files modified during development so we have a clear history to backtrack if needed.*

---

## [2026-07-09]
- **Database Layer Finished (Step 1)**: 
  - Verified that all 17 database tables were created successfully.
  - Verified that triggers from `triggers_final.sql` were created successfully.
  - Wrote and executed `03_functions.sql` to create `fn_total_pages_read`, `fn_reading_progress`, and `fn_is_copy_available`.
- **Documentation Restructuring**: 
  - Created `project_tracker.md` to act as an active, living checklist for the remaining project steps.
  - Cleaned up `project_status.md` by removing the "In Progress" and "Not Started" task lists. It now acts as a constant architectural blueprint.
  - Created `changelog.md` (this file) to record all future changes and decisions for easy backtracking.
  - Created `database/04_dummy_data.sql` to test database triggers and structure.
- **Docker Setup Started (Step 2)**:
  - Created folder structure (`backend`, `android`, `images/books`, `images/authors`).
  - Created `.env` file with MySQL and FastAPI environment variables.
  - Created `.gitignore` file to ignore `.env`, Python cache, and DB data.
  - Created `docker-compose.yml` to run MySQL 8.0 and mount `database/` scripts for automatic initialization on startup.
