package com.example.homelibrary.ui.navigation

sealed class Screen(val route: String) {
    object Login : Screen("login")
    object Home : Screen("home")
    object BookDetail : Screen("book_detail/{bookId}") {
        fun createRoute(bookId: Int) = "book_detail/$bookId"
    }
}
