package world.humanlabs.quest.internal

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import world.humanlabs.quest.models.LaunchToken

@RunWith(RobolectricTestRunner::class)
class LaunchUrlBuilderTest {

    private val base = "https://quest.humanlabs.world"

    private fun params(url: String): Map<String, String?> {
        val uri = Uri.parse(url)
        return uri.queryParameterNames.associateWith { uri.getQueryParameter(it) }
    }

    @Test
    fun `standard mode omits signing params and maps device locale`() {
        val url = LaunchUrlBuilder.build(
            baseUrl = base,
            appId = "abcd012345",
            userId = "user-1",
            token = null,
            deviceLanguage = "es",
        )
        val p = params(url)
        assertEquals("abcd012345", p["app_id"])
        assertEquals("user-1", p["user_id"])
        assertEquals("es", p["locale"])
        assertNull(p["ts"])
        assertNull(p["nonce"])
        assertNull(p["sig"])
    }

    @Test
    fun `standard mode falls back to en for unsupported locale`() {
        val url = LaunchUrlBuilder.build(base, "app", "u", null, "fr-FR")
        assertEquals("en", params(url)["locale"])
    }

    @Test
    fun `secure mode includes signing params and signed locale`() {
        val token = LaunchToken(ts = "1700000000000", nonce = "abc123nonce", sig = "deadbeef", locale = "id")
        val url = LaunchUrlBuilder.build(
            baseUrl = base,
            appId = "abcd012345",
            userId = "user 2", // space must be encoded
            token = token,
            deviceLanguage = "es", // ignored in secure mode
        )
        val p = params(url)
        assertEquals("abcd012345", p["app_id"])
        assertEquals("user 2", p["user_id"]) // decoded back to the original
        assertEquals("1700000000000", p["ts"])
        assertEquals("abc123nonce", p["nonce"])
        assertEquals("deadbeef", p["sig"])
        assertEquals("id", p["locale"])
        // Ensure the raw URL actually percent-encodes the space.
        assert(url.contains("user_id=user%202")) { "userId should be percent-encoded: $url" }
    }

    @Test
    fun `secure mode with absent locale sends empty locale to match signed message`() {
        val token = LaunchToken(ts = "123", nonce = "n", sig = "s", locale = null)
        val url = LaunchUrlBuilder.build(base, "app", "u", token, "es")
        assertEquals("", params(url)["locale"])
    }

    @Test
    fun `locale mapping handles region tags and legacy indonesian code`() {
        assertEquals("en", LaunchUrlBuilder.mapLocale("en-US"))
        assertEquals("pt", LaunchUrlBuilder.mapLocale("pt_BR"))
        assertEquals("id", LaunchUrlBuilder.mapLocale("id"))
        assertEquals("id", LaunchUrlBuilder.mapLocale("in")) // JDK legacy code for Indonesian
        assertEquals("es", LaunchUrlBuilder.mapLocale("ES"))
        assertEquals("en", LaunchUrlBuilder.mapLocale(null))
        assertEquals("en", LaunchUrlBuilder.mapLocale(""))
        assertEquals("en", LaunchUrlBuilder.mapLocale("de"))
    }
}
