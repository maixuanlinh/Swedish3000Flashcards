package com.linapps.swedish3000

import com.android.billingclient.api.Purchase
import com.linapps.swedish3000.data.*
import org.junit.Assert.*
import org.junit.Test
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64

class PlayEntitlementsTest {
    @Test fun googleSignatureMustMatchTheExactPurchasePayload() {
        val pair=KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val json="""{"packageName":"com.linapps.swedish3000","productId":"complete"}"""
        val signer=Signature.getInstance("SHA1withRSA").apply { initSign(pair.private);update(json.toByteArray()) }
        val signature=Base64.getEncoder().encodeToString(signer.sign())
        val publicKey=Base64.getEncoder().encodeToString(pair.public.encoded)
        assertTrue(verifyPlaySignature(json,signature,publicKey))
        assertFalse(verifyPlaySignature(json.replace("complete","other"),signature,publicKey))
        assertFalse(verifyPlaySignature(json,signature.reversed(),publicKey))
    }

    @Test fun onlyVerifiedCompletedProductUnlocksAndNeedsAcknowledgementOnce() {
        val records=listOf(
            PurchaseEvidence(0,setOf("complete"),Purchase.PurchaseState.PENDING,true,false),
            PurchaseEvidence(1,setOf("other"),Purchase.PurchaseState.PURCHASED,true,false),
            PurchaseEvidence(2,setOf("complete"),Purchase.PurchaseState.PURCHASED,false,false),
            PurchaseEvidence(3,setOf("complete"),Purchase.PurchaseState.PURCHASED,true,false),
            PurchaseEvidence(4,setOf("complete"),Purchase.PurchaseState.PURCHASED,true,true))
        val result=resolvePurchases("complete",records)
        assertEquals(3,result.ownedIndex)
        assertTrue(result.pending)
        assertEquals(setOf(3),result.acknowledge)
    }

    @Test fun pendingOrUnverifiedPurchaseNeverUnlocksPremium() {
        val result=resolvePurchases("complete",listOf(
            PurchaseEvidence(0,setOf("complete"),Purchase.PurchaseState.PENDING,true,false),
            PurchaseEvidence(1,setOf("complete"),Purchase.PurchaseState.PURCHASED,false,false)))
        assertNull(result.ownedIndex)
        assertTrue(result.pending)
        assertTrue(result.acknowledge.isEmpty())
    }
}
