package com.example.homelibrary.ui.home

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.homelibrary.data.remote.dto.BookDto
import com.example.homelibrary.data.repository.LibraryRepository
import com.example.homelibrary.util.Resource
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val repository: LibraryRepository,
) : ViewModel() {

    private val _books = mutableStateOf<List<BookDto>>(value = emptyList())
    val books: State<List<BookDto>> = _books

    private val _isLoading = mutableStateOf(value = false)
    val isLoading: State<Boolean> = _isLoading

    private val _errorMessage = mutableStateOf<String?>(value = null)
    val errorMessage: State<String?> = _errorMessage

    init {
        loadBooks()
    }

    fun loadBooks() {
        _isLoading.value = true
        _errorMessage.value = null
        
        viewModelScope.launch {
            val result = repository.getAllBooks()
            _isLoading.value = false
            
            when (result) {
                is Resource.Success -> {
                    _books.value = result.data ?: emptyList()
                }
                is Resource.Error -> {
                    _errorMessage.value = result.message ?: "Failed to load books"
                }
                else -> Unit
            }
        }
    }
}
