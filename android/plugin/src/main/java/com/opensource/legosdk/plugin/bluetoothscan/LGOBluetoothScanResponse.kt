package com.opensource.legosdk.plugin.bluetoothscan

import com.opensource.legosdk.core.LGOResponse

class LGOBluetoothScanResponse: LGOResponse() {

    var text: String? = null

    override fun resData(): HashMap<String, Any> {
        return hashMapOf(
            Pair("text", this.text ?: "")
        )
    }

}