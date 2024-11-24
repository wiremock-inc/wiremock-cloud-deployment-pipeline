#!/usr/bin/env kotlin

@file:Import("../http.main.kts")

import java.time.Duration
import java.time.Instant

DataDog(
  baseUrl = "https://datadog.wiremockapi.cloud",
  ddApiKey = args[0],
  ddApplicationKey = args[1],
)
.muteMonitor(
  name = args[2],
  duration = args.getOrNull(3)?.toDuration(),
)

class DataDog(
  baseUrl: String = "https://api.datadoghq.com",
  ddApiKey: String,
  ddApplicationKey: String,
) {

  private val http: HttpClient = HttpClient(
    baseUrl = baseUrl,
    defaultHeaders = listOf(
      "Accept" to "application/json",
      "DD-API-KEY" to ddApiKey,
      "DD-APPLICATION-KEY" to ddApplicationKey,
    )
  )

  fun muteMonitor(name: String, duration: Duration?) {
    getMonitors()
      .firstOrNull { it.name == name }
      .requireNotNull { "Unknown monitor $name" }
      .mute(duration)
  }

  private fun getMonitors() = http.get<Monitors>("/api/v1/monitor/search").monitors

  private fun Monitor.mute(duration: Duration?) {
    val query = when {
      duration == null -> ""
      else -> "?end=${Instant.now().plus(duration).epochSecond}"
    }
    http.post("/api/v1/monitor/$id/mute$query")
  }
}

data class Monitors(val monitors: List<Monitor>)

data class Monitor(val name: String, val id: String)

fun String.toDuration(): Duration = Duration.parse(this)
