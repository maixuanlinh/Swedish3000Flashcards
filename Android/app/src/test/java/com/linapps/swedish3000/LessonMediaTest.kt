package com.linapps.swedish3000

import android.app.Application
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.linapps.swedish3000.data.*
import kotlinx.coroutines.test.runTest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowStatFs
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],application=Application::class)
class LessonMediaTest {
    private lateinit var context: Context
    private val data="first-recording-second-recording".toByteArray()
    private val key=recordingKey("sv-SE","ett äpple")
    private val checksum=mediaHash(data)
    private val packName="pack-$checksum.bin"
    @Before fun setup() {
        context=ApplicationProvider.getApplicationContext()
        File(context.filesDir,"lesson-media").deleteRecursively()
        File(context.cacheDir,"lesson-media").deleteRecursively()
        ShadowStatFs.registerStats(File(context.filesDir,"lesson-media").path,1_000_000,1_000_000,1_000_000)
    }
    private fun manifest()=JSONObject().put("format","sisu-lesson-media-v1").put("version","a".repeat(64))
        .put("packs",JSONArray().put(JSONObject().put("file",packName).put("bytes",data.size).put("sha256",checksum).put("starter",false)))
        .put("assets",JSONArray().put(JSONObject().put("key",key).put("pack",packName).put("offset",6).put("bytes",9).put("sha256",mediaHash(data.copyOfRange(6,15)))))
    @Test fun onlineLoadsOnlyRequestedBytesAndReusesVerifiedCache() = runTest {
        var requests=0
        val media=LessonMedia(context,::manifest,MediaSource { _,start,end ->
            requests++;assertEquals(6L,start);assertEquals(14L,end)
            MediaResponse(206,"bytes 6-14/${data.size}",ByteArrayInputStream(data.copyOfRange(6,15)))
        })
        assertArrayEquals("recording".toByteArray(),media.load(key))
        assertArrayEquals("recording".toByteArray(),media.load(key))
        assertEquals(1,requests)
        media.refresh();assertFalse(media.status.value.ready)
    }
    @Test fun interruptedDownloadResumesAndIsAvailableAfterAppRestartWithoutNetwork() = runTest {
        var calls=0
        val media=LessonMedia(context,::manifest,MediaSource { _,start,end ->
            calls++;assertNull(end)
            if(calls==1) MediaResponse(200,null,ByteArrayInputStream(data.copyOfRange(0,4)))
            else { assertEquals(4L,start);MediaResponse(206,"bytes 4-${data.size-1}/${data.size}",ByteArrayInputStream(data.copyOfRange(4,data.size))) }
        })
        assertTrue(runCatching { media.download(media.catalog.packs.getValue(packName)) }.isFailure)
        media.download(media.catalog.packs.getValue(packName))
        assertTrue(media.status.value.ready)
        val restarted=LessonMedia(context,::manifest,MediaSource { _,_,_ -> throw IOException("No network") })
        assertArrayEquals("recording".toByteArray(),restarted.load(key))
        restarted.refresh();assertTrue(restarted.status.value.ready)
    }
    @Test fun incorrectBytesAndRangesAreRejectedWithoutSavingAnOfflinePack() = runTest {
        val wrongRange=LessonMedia(context,::manifest,MediaSource { _,_,_ -> MediaResponse(206,"bytes 0-8/${data.size}",ByteArrayInputStream(ByteArray(9))) })
        assertTrue(runCatching { wrongRange.load(key) }.isFailure)
        val corrupt=LessonMedia(context,::manifest,MediaSource { _,_,_ -> MediaResponse(200,null,ByteArrayInputStream(ByteArray(data.size))) })
        assertTrue(runCatching { corrupt.download(corrupt.catalog.packs.getValue(packName)) }.isFailure)
        corrupt.refresh();assertFalse(corrupt.status.value.ready)
        assertFalse(File(context.filesDir,"lesson-media/$packName").exists())
    }
    @Test fun hostsWithoutRangeSupportStillWorkWithBoundedVerifiedPacks() = runTest {
        val media=LessonMedia(context,::manifest,MediaSource { _,_,_ -> MediaResponse(200,null,ByteArrayInputStream(data)) })
        assertArrayEquals("recording".toByteArray(),media.load(key))
    }
    @Test fun removingDownloadsPreservesLearningAndPersonalArtwork() = runTest {
        val personal=File(context.filesDir,"personal-proof.jpg").apply { writeText("keep") }
        val media=LessonMedia(context,::manifest,MediaSource { _,_,_ -> MediaResponse(200,null,ByteArrayInputStream(data)) })
        media.download(media.catalog.packs.getValue(packName))
        context.getSharedPreferences("study-settings",0).edit().putBoolean("englishFirst",false).commit()
        media.removeDownloads()
        assertEquals("keep",personal.readText())
        assertFalse(context.getSharedPreferences("study-settings",0).getBoolean("englishFirst",true))
        assertFalse(media.status.value.ready)
    }
    @Test fun manifestRejectsTraversalAndAssetsOutsidePackBounds() {
        val bad=manifest();bad.getJSONArray("packs").getJSONObject(0).put("file","../progress.db")
        assertTrue(runCatching { MediaCatalog(bad) }.isFailure)
        val oversized=manifest();oversized.getJSONArray("assets").getJSONObject(0).put("offset",data.size)
        assertTrue(runCatching { MediaCatalog(oversized) }.isFailure)
    }
    @Test fun lowStorageStopsBeforeRequestingNetworkData() = runTest {
        ShadowStatFs.registerStats(File(context.filesDir,"lesson-media").path,10,10,10)
        var requests=0
        val media=LessonMedia(context,::manifest,MediaSource { _,_,_ -> requests++;throw IOException("Should not request") })
        val failure=runCatching { media.download(media.catalog.packs.getValue(packName)) }.exceptionOrNull()
        assertTrue(failure?.message.orEmpty().contains("storage"))
        assertEquals(0,requests)
    }
    @Test fun completedPartialFileAfterProcessDeathCommitsWithoutRedownloading() = runTest {
        val folder=File(context.filesDir,"lesson-media").apply { mkdirs() }
        File(folder,"$packName.part").writeBytes(data)
        val media=LessonMedia(context,::manifest,MediaSource { _,_,_ -> throw IOException("No network") })
        media.download(media.catalog.packs.getValue(packName))
        assertTrue(media.status.value.ready)
        assertArrayEquals("recording".toByteArray(),media.load(key))
    }
    @Test fun corruptSavedPackIsNotReportedAsAvailableOffline() = runTest {
        val folder=File(context.filesDir,"lesson-media").apply { mkdirs() }
        File(folder,packName).writeBytes(ByteArray(data.size))
        val media=LessonMedia(context,::manifest,MediaSource { _,_,_ -> throw IOException("No network") })
        media.refresh()
        assertFalse(media.status.value.ready)
        assertTrue(media.missingPacks().isNotEmpty())
    }
}
