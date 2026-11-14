package com.example.pwdpwdpwd

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

/**
 * Renders the TV Cast's spoken words to WAV files, which the cast server then
 * hands to the TV to play through its own speakers (`TvCastSpeech` on the Dart
 * side, channel `flashlearn/cast_speech`).
 *
 * A speech engine of its own, separate from the one the app speaks with
 * (flutter_tts): one TextToSpeech instance has one queue, so a `stop()` from
 * the app would discard a file being made, and a file being made would hold up
 * a word the app wants to say. Android keeps each client's queue apart.
 *
 * One file at a time — the language and rate are set per request, and the
 * engine applies them to what is queued next. Every request answers exactly
 * once: done, failed, or given up on after [TIMEOUT_MS].
 */
class CastSpeech(private val context: Context) {

    companion object {
        private const val TAG = "CastSpeech"
        private const val TIMEOUT_MS = 15_000L
    }

    private class Job(
        val text: String,
        val lang: String,
        val rate: Float,
        val path: String,
        val result: MethodChannel.Result,
    ) {
        var utteranceId = ""
        var startedAt = 0L
        var voice = ""
        var answered = false
    }

    private val main = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null

    /** 0 = not started, 1 = starting, 2 = ready, -1 = no engine. */
    private var engineState = 0
    private val waiting = ArrayDeque<Job>()
    private var current: Job? = null

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "synthesize" -> {
                val text = call.argument<String>("text") ?: ""
                val path = call.argument<String>("path") ?: ""
                if (text.isBlank() || path.isBlank()) {
                    result.success(false)
                    return
                }
                val lang = call.argument<String>("lang") ?: "en"
                val rate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                waiting.addLast(Job(text, lang, rate, path, result))
                ensureEngine()
                pump()
            }
            "release" -> {
                release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureEngine() {
        if (engineState != 0) return
        engineState = 1
        try {
            tts = TextToSpeech(context) { status ->
                main.post {
                    engineState = if (status == TextToSpeech.SUCCESS) 2 else -1
                    if (engineState == 2) {
                        tts?.setOnUtteranceProgressListener(listener)
                    } else {
                        Log.w(TAG, "no speech engine (status $status)")
                    }
                    pump()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "speech engine failed to start: ${e.message}")
            engineState = -1
        }
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String?) {}

        override fun onDone(utteranceId: String?) {
            main.post { finishIfCurrent(utteranceId, true) }
        }

        @Deprecated("Deprecated in Java")
        override fun onError(utteranceId: String?) {
            main.post { finishIfCurrent(utteranceId, false) }
        }

        override fun onError(utteranceId: String?, errorCode: Int) {
            main.post { finishIfCurrent(utteranceId, false) }
        }

        override fun onStop(utteranceId: String?, interrupted: Boolean) {
            main.post { finishIfCurrent(utteranceId, false) }
        }
    }

    private fun finishIfCurrent(utteranceId: String?, done: Boolean) {
        val job = current ?: return
        if (job.utteranceId != utteranceId) return
        finish(job, done)
    }

    private fun pump() {
        if (current != null) return
        if (engineState == -1) {
            while (waiting.isNotEmpty()) answer(waiting.removeFirst(), false)
            return
        }
        if (engineState != 2) return
        val job = waiting.removeFirstOrNull() ?: return
        val engine = tts ?: run {
            answer(job, false)
            pump()
            return
        }
        current = job
        job.startedAt = SystemClock.elapsedRealtime()
        try {
            job.voice = useLanguage(engine, job.lang)
            engine.setSpeechRate(job.rate)
            val target = File(job.path)
            target.parentFile?.mkdirs()
            // Written beside the target and renamed when complete, so a
            // half-made file is never served to the TV.
            val part = File(job.path + ".part")
            part.delete()
            job.utteranceId = "castspeech-" + UUID.randomUUID().toString()
            val queued = engine.synthesizeToFile(job.text, Bundle(), part, job.utteranceId)
            if (queued != TextToSpeech.SUCCESS) {
                finish(job, false)
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "synthesize failed to queue: ${e.message}")
            finish(job, false)
            return
        }
        val id = job.utteranceId
        main.postDelayed({
            val stuck = current
            if (stuck != null && stuck.utteranceId == id) {
                Log.w(TAG, "gave up after ${TIMEOUT_MS} ms (${stuck.lang})")
                try {
                    tts?.stop()
                } catch (_: Exception) {
                }
                finish(stuck, false)
            }
        }, TIMEOUT_MS)
    }

    /**
     * The voice for [lang]: Filipino by any of the names engines give it
     * ("fil-PH", "fil", Tagalog), else English — the same order the app's own
     * speech tries, so the TV hears the voice the learner hears.
     */
    private fun useLanguage(engine: TextToSpeech, lang: String): String {
        val candidates = if (lang == "fil") {
            listOf(Locale("fil", "PH"), Locale("fil"), Locale("tl", "PH"), Locale("tl"))
        } else {
            listOf(Locale.US, Locale.ENGLISH)
        }
        for (locale in candidates) {
            val available = try {
                engine.isLanguageAvailable(locale)
            } catch (_: Exception) {
                TextToSpeech.LANG_NOT_SUPPORTED
            }
            if (available >= TextToSpeech.LANG_AVAILABLE) {
                engine.setLanguage(locale)
                return locale.toLanguageTag()
            }
        }
        engine.setLanguage(Locale.US)
        return "en-US (no ${lang} voice)"
    }

    private fun finish(job: Job, done: Boolean) {
        if (current === job) current = null
        var ok = false
        val part = File(job.path + ".part")
        try {
            if (done && part.length() > 44) {
                val target = File(job.path)
                ok = part.renameTo(target)
                if (!ok) {
                    part.copyTo(target, overwrite = true)
                    ok = true
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "could not keep the file: ${e.message}")
            ok = false
        } finally {
            part.delete()
        }
        val ms = SystemClock.elapsedRealtime() - job.startedAt
        // The language and size only — never the words.
        Log.i(TAG, "file ${if (ok) "made" else "failed"} voice=${job.voice} " +
            "bytes=${if (ok) File(job.path).length() else 0} ms=$ms")
        answer(job, ok)
        pump()
    }

    private fun answer(job: Job, ok: Boolean) {
        if (job.answered) return
        job.answered = true
        try {
            job.result.success(ok)
        } catch (_: Exception) {
        }
    }

    fun release() {
        while (waiting.isNotEmpty()) answer(waiting.removeFirst(), false)
        current?.let { answer(it, false) }
        current = null
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        engineState = 0
    }
}
