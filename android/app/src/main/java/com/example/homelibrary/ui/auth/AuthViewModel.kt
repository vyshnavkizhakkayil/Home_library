package com.example.homelibrary.ui.auth

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.homelibrary.data.remote.dto.LoginRequest
import com.example.homelibrary.data.repository.AuthRepository
import com.example.homelibrary.util.Resource
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val repository: AuthRepository
) : ViewModel() {

    private val _username = mutableStateOf("")
    val username: State<String> = _username

    private val _password = mutableStateOf("")
    val password: State<String> = _password

    private val _isLoading = mutableStateOf(false)
    val isLoading: State<Boolean> = _isLoading

    private val _errorMessage = mutableStateOf<String?>(null)
    val errorMessage: State<String?> = _errorMessage

    fun onUsernameChange(newValue: String) {
        _username.value = newValue
    }

    fun onPasswordChange(newValue: String) {
        _password.value = newValue
    }

    fun login(onSuccess: () -> Unit) {
        _isLoading.value = true
        _errorMessage.value = null
        
        viewModelScope.launch {
            val result = repository.login(LoginRequest(_username.value, _password.value))
            _isLoading.value = false
            
            when (result) {
                is Resource.Success -> {
                    // For now, we simply invoke the success callback.
                    // In a real app, you would save the token to SharedPreferences/DataStore here.
                    onSuccess()
                }
                is Resource.Error -> {
                    _errorMessage.value = result.message ?: "Failed to log in"
                }
                else -> Unit
            }
        }
    }
}
