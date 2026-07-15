package com.example.homelibrary.data.repository

import com.example.homelibrary.data.remote.HomeLibraryApi
import com.example.homelibrary.data.remote.dto.BookDto
import com.example.homelibrary.util.Resource
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LibraryRepository @Inject constructor(
    private val api: HomeLibraryApi
) {
    suspend fun getAllBooks(): Resource<List<BookDto>> {
        return try {
            val response = api.getAllBooks()
            if (response.isSuccessful && response.body() != null) {
                Resource.Success(response.body()!!)
            } else {
                Resource.Error(response.errorBody()?.string() ?: "Failed to fetch books")
            }
        } catch (e: Exception) {
            Resource.Error(e.localizedMessage ?: "Couldn't reach server. Check your internet connection.")
        }
    }
}
