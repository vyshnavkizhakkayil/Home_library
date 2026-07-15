package com.example.homelibrary.data.repository

import com.example.homelibrary.data.remote.HomeLibraryApi
import com.example.homelibrary.data.remote.dto.LoginRequest
import com.example.homelibrary.data.remote.dto.TokenResponse
import com.example.homelibrary.util.Resource
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val api: HomeLibraryApi
) {
    suspend fun login(request: LoginRequest): Resource<TokenResponse> {
        return try {
            val response = api.login(username = request.username, password = request.password)
            if (response.isSuccessful && response.body() != null) {
                Resource.Success(response.body()!!)
            } else {
                Resource.Error(response.errorBody()?.string() ?: "An unknown error occurred")
            }
        } catch (e: Exception) {
            Resource.Error(e.localizedMessage ?: "Couldn't reach server. Check your internet connection.")
        }
    }
}
