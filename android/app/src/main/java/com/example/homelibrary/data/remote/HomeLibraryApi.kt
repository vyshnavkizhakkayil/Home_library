package com.example.homelibrary.data.remote

import com.example.homelibrary.data.remote.dto.*
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface HomeLibraryApi {

    // Auth
    @POST("auth/register")
    suspend fun registerUser(
        @Body request: UserCreateRequest
    ): Response<UserCreateRequest>

    @FormUrlEncoded
    @POST("auth/login")
    suspend fun login(
        @Field("username") username: String,
        @Field("password") password: String
    ): Response<TokenResponse>

    // Books
    @GET("books/")
    suspend fun getAllBooks(): Response<List<BookDto>>

    @POST("books/")
    suspend fun createBook(
        @Body request: BookCreateRequest
    ): Response<BookDto>
    
    @GET("books/{book_id}")
    suspend fun getBook(
        @Path("book_id") bookId: Int
    ): Response<BookDto>
}
