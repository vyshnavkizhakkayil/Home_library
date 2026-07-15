package com.example.homelibrary.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.example.homelibrary.ui.auth.LoginScreen
import com.example.homelibrary.ui.home.HomeScreen

@Composable
fun NavGraph(
    navController: NavHostController,
    startDestination: String = Screen.Login.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(route = Screen.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }
        
        composable(route = Screen.Home.route) {
            HomeScreen(
                onBookClick = { bookId ->
                    navController.navigate(Screen.BookDetail.createRoute(bookId))
                },
                onAddBookClick = {
                    // Navigate to Add Book (or Barcode Scanner)
                }
            )
        }
        
        composable(route = Screen.BookDetail.route) { backStackEntry ->
            val bookId = backStackEntry.arguments?.getString("bookId")
            // Placeholder for Book Detail Screen
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "Book Detail Screen for Book ID: $bookId")
            }
        }
    }
}
