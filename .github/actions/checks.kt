inline fun <T : Any> T?.requireNotNull(lazyMessage: () -> Any): T = requireNotNull(this, lazyMessage)

inline fun <T : Any> T?.checkNotNull(lazyMessage: () -> Any): T = checkNotNull(this, lazyMessage)
