package com.linapps.swedish3000.data

import com.linapps.swedish3000.domain.Entitlement
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

interface EntitlementRepository {
    val access: StateFlow<Entitlement>
    suspend fun refresh()
}
/** No billing or local unlock flag. Replace at the application composition root later. */
class FreeEntitlementRepository : EntitlementRepository {
    private val state = MutableStateFlow(Entitlement.UNKNOWN)
    override val access = state.asStateFlow()
    override suspend fun refresh() { state.value = Entitlement.FREE }
}
