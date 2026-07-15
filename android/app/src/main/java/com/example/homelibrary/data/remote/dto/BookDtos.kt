package com.example.homelibrary.data.remote.dto

data class BookCreateRequest(
    val title: String,
    val isbn: String? = null,
    val category_id: Int? = null,
    val publisher: String? = null,
    val published_year: Int? = null,
    val total_pages: Int? = null,
    val language: String = "English",
    val description: String? = null,
    val cover: String? = null,
    val author_ids: List<Int> = emptyList()
)

data class BookDto(
    val id: Int,
    val title: String,
    val isbn: String?,
    val category_id: Int?,
    val publisher: String?,
    val published_year: Int?,
    val total_pages: Int?,
    val language: String,
    val description: String?,
    val cover: String?,
    val added_at: String
)

data class CopyCreateRequest(
    val copy_number: Int = 1,
    val condition: String = "good",
    val source: String = "purchased",
    val acquired_date: String? = null,
    val notes: String? = null
)

data class CopyDto(
    val id: Int,
    val book_id: Int,
    val copy_number: Int,
    val condition: String,
    val source: String,
    val acquired_date: String?,
    val notes: String?
)
