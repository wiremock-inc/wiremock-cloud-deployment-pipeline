@file:DependsOn("com.squareup.okhttp3:okhttp::4.12.0")
@file:DependsOn("com.fasterxml.jackson.module:jackson-module-kotlin:2.9.7")
@file:Import("checks.kt")

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class HttpClient(
  private val baseUrl: String,
  defaultHeaders: List<Pair<String, String>>,
  private val okHttpClient: OkHttpClient = OkHttpClient(),
) {
  private val defaultHeaders: Headers = Headers.Builder()
    .apply {
      defaultHeaders.forEach { (name, value) ->
        add(name, value)
      }
    }
    .build()

  inline fun <reified T> get(url: String) = execute<T>("GET", url)

  fun post(pathAndQuery: String) { execute("POST", pathAndQuery) }

  inline fun <reified T> execute(
    method: String,
    pathAndQuery: String,
    headers: Headers = Headers.Builder().build()
  ) = execute(method, pathAndQuery, headers)
    .checkNotNull { "Call must return a body" }
    .parse<T>()

  fun execute(
    method: String,
    pathAndQuery: String,
    headers: Headers = Headers.Builder().build(),
  ): String? {
    val body = if (method.requiresBody) "".toRequestBody() else null
    val request = Request.Builder()
      .url("$baseUrl$pathAndQuery")
      .method(method, body)
      .headers(headers.newBuilder().addAll(defaultHeaders).build())
      .build()
    val response = okHttpClient.newCall(request).execute()
    return when {
      response.isSuccessful -> response.body?.string()?.ifEmpty { null }
      else -> throw Exception("$method $pathAndQuery returned ${response.code} with body ${response.body?.string()}")
    }
  }
}

val String.requiresBody get() = this == "POST" || this == "PUT" || this == "PATCH"

inline fun <reified T> String.parse(): T = jacksonObjectMapper().readValue(this, T::class.java)
