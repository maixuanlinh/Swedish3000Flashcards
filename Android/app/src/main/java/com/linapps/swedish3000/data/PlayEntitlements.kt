package com.linapps.swedish3000.data

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import com.linapps.swedish3000.BuildConfig
import com.linapps.swedish3000.domain.Entitlement
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import kotlin.coroutines.resume

internal data class PurchaseEvidence(val index: Int,val products: Set<String>,val state: Int,val verified: Boolean,val acknowledged: Boolean)
internal data class PurchaseResolution(val ownedIndex: Int?,val pending: Boolean,val acknowledge: Set<Int>)
internal fun resolvePurchases(productId: String,records: List<PurchaseEvidence>): PurchaseResolution {
    val owned=records.filter { productId in it.products && it.state==Purchase.PurchaseState.PURCHASED && it.verified }
    return PurchaseResolution(owned.firstOrNull()?.index,records.any { productId in it.products && it.state==Purchase.PurchaseState.PENDING },owned.filterNot { it.acknowledged }.map { it.index }.toSet())
}
internal fun verifyPlaySignature(originalJson: String,signature: String,licenseKey: String): Boolean = runCatching {
    val key=KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(Base64.getMimeDecoder().decode(licenseKey)))
    Signature.getInstance("SHA1withRSA").run { initVerify(key);update(originalJson.toByteArray(Charsets.UTF_8));verify(Base64.getMimeDecoder().decode(signature)) }
}.getOrDefault(false)

/** Only a signed, purchased Google Play record grants access. No local unlock switch. */
class PlayEntitlementRepository(context: Context): EntitlementRepository, PurchasesUpdatedListener {
    private val proofs=context.getSharedPreferences("play-purchase-proof",Context.MODE_PRIVATE)
    private val scope=CoroutineScope(SupervisorJob()+Dispatchers.Main.immediate)
    private val mutex=Mutex()
    private val state=MutableStateFlow(Entitlement.UNKNOWN)
    override val access=state.asStateFlow()
    val price=MutableStateFlow<String?>(null)
    val message=MutableStateFlow<String?>(null)
    val busy=MutableStateFlow(false)
    val configured get()=BuildConfig.PLAY_PRODUCT_ID.isNotBlank() && BuildConfig.PLAY_LICENSE_KEY.isNotBlank()
    private var product: ProductDetails?=null
    private val client=BillingClient.newBuilder(context.applicationContext).setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection().build()
    init {
        if(configured) runCatching {
            val json=proofs.getString("purchase",null) ?: return@runCatching
            val signature=proofs.getString("signature",null) ?: return@runCatching
            val purchase=Purchase(json,signature)
            if(BuildConfig.PLAY_PRODUCT_ID in purchase.products && purchase.purchaseState==Purchase.PurchaseState.PURCHASED && verified(purchase)) state.value=Entitlement.COMPLETE
        }
    }
    private suspend fun connect(): Boolean {
        if(client.isReady) return true
        return withTimeoutOrNull(15000) { suspendCancellableCoroutine { continuation ->
            client.startConnection(object: BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) { if(continuation.isActive) continuation.resume(result.responseCode==BillingClient.BillingResponseCode.OK) }
                override fun onBillingServiceDisconnected() {}
            })
        } } ?: false
    }
    override suspend fun refresh() = mutex.withLock {
        if(!configured) { state.value=Entitlement.FREE;return@withLock }
        if(!connect()) { if(state.value==Entitlement.UNKNOWN) state.value=Entitlement.FREE;message.value="Google Play is unavailable. Connect to the Play Store and try Restore Purchases.";return@withLock }
        val purchases=suspendCancellableCoroutine<Pair<BillingResult,List<Purchase>>> { c ->
            client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { result, values -> if(c.isActive) c.resume(result to values) }
        }
        if(purchases.first.responseCode==BillingClient.BillingResponseCode.OK) applyPurchases(purchases.second)
        else { if(state.value==Entitlement.UNKNOWN) state.value=Entitlement.FREE;message.value="Purchase access could not be checked. Try Restore Purchases." }
        val result=suspendCancellableCoroutine<Pair<BillingResult,QueryProductDetailsResult>> { c ->
            val item=QueryProductDetailsParams.Product.newBuilder().setProductId(BuildConfig.PLAY_PRODUCT_ID).setProductType(BillingClient.ProductType.INAPP).build()
            client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(listOf(item)).build()) { response, details -> if(c.isActive) c.resume(response to details) }
        }
        product=if(result.first.responseCode==BillingClient.BillingResponseCode.OK) result.second.productDetailsList.firstOrNull() else null
        price.value=product?.oneTimePurchaseOfferDetails?.formattedPrice
    }
    private fun verified(purchase: Purchase): Boolean = runCatching {
        check(org.json.JSONObject(purchase.originalJson).getString("packageName")==BuildConfig.APPLICATION_ID)
        verifyPlaySignature(purchase.originalJson,purchase.signature,BuildConfig.PLAY_LICENSE_KEY)
    }.getOrDefault(false)
    private fun applyPurchases(purchases: List<Purchase>) {
        val resolution=resolvePurchases(BuildConfig.PLAY_PRODUCT_ID,purchases.mapIndexed { index,purchase -> PurchaseEvidence(index,purchase.products.toSet(),purchase.purchaseState,verified(purchase),purchase.isAcknowledged) })
        val proof=resolution.ownedIndex?.let(purchases::get)
        state.value=if(proof!=null) Entitlement.COMPLETE else Entitlement.FREE
        if(proof==null) proofs.edit().clear().apply()
        else proofs.edit().putString("purchase",proof.originalJson).putString("signature",proof.signature).apply()
        if(resolution.pending) message.value="Your purchase is pending. Lessons unlock after Google Play confirms payment."
        resolution.acknowledge.map(purchases::get).forEach { p -> client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()) { result ->
            if(result.responseCode!=BillingClient.BillingResponseCode.OK) message.value="Google Play could not finish confirming your purchase. Reopen the app while connected to retry."
        } }
    }
    fun restore() { scope.launch { busy.value=true;try { refresh();if(access.value==Entitlement.COMPLETE) message.value="Premium restored." else if(configured) message.value="No completed Premium purchase was found for this Google Account." else message.value="Google Play purchases are not available in this installation. The complete A set is included for free." } finally { busy.value=false } } }
    fun purchase(activity: Activity) {
        if(busy.value) return
        val product=product ?: run { message.value="Premium is not ready yet. Check your Play Store connection and try again.";return }
        val offer=product.oneTimePurchaseOfferDetails ?: run { message.value="Premium is not available for this Google Play account.";return }
        val detail=BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).apply { offer.offerToken?.let { setOfferToken(it) } }.build()
        val result=client.launchBillingFlow(activity,BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(detail)).build())
        busy.value=result.responseCode==BillingClient.BillingResponseCode.OK
        if(!busy.value) message.value="The purchase could not start. Please try again in Google Play."
    }
    override fun onPurchasesUpdated(result: BillingResult,purchases: MutableList<Purchase>?) {
        busy.value=false
        if(result.responseCode==BillingClient.BillingResponseCode.OK || result.responseCode==BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) scope.launch { refresh() }
        else if(result.responseCode!=BillingClient.BillingResponseCode.USER_CANCELED) message.value="Google Play could not complete the purchase. Please try again."
    }
}
