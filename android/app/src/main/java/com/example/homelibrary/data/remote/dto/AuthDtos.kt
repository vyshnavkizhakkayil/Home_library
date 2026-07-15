package com.example.homelibrary.data.remote.dto

data class UserCreateRequest(
    val name: String,
    val username: String,
    val password: String
)

data class LoginRequest(
    val username: String,
    val password: String
)

data class TokenResponse(
    val access_token: String,
    val token_type: String
)
