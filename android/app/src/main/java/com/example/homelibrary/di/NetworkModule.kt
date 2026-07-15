package com.example.homelibrary.di

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    // Using 10.0.2.2 which is the special alias to your host loopback interface (localhost) from the Android emulator
    private const val BASE_URL = "http://10.0.2.2:8000/"

    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideHomeLibraryApi(retrofit: Retrofit): com.example.homelibrary.data.remote.HomeLibraryApi {
        return retrofit.create(com.example.homelibrary.data.remote.HomeLibraryApi::class.java)
    }
}
