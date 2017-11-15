package com.opensource.legosdk.plugin.bluetoothscan

import com.opensource.legosdk.core.*
import org.json.JSONObject

class LGOBluetoothScan: LGOModule() {

    override fun buildWithJSONObject(obj: JSONObject, context: LGORequestContext): LGORequestable? {
        val request = LGOBluetoothScanRequest(context)
        
        return LGOBluetoothScanOperation(request)
    }

}