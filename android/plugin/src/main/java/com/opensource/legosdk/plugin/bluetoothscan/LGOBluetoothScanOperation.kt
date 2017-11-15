package com.opensource.legosdk.plugin.bluetoothscan

import com.opensource.legosdk.core.LGORequestable
import com.opensource.legosdk.core.LGOResponse

/**
 * Created by cuiminghui on 2017/10/17.
 */
class LGOBluetoothScanOperation(val request: LGOBluetoothScanRequest): LGORequestable() {

    override fun requestSynchronize(): LGOResponse {
        return LGOBluetoothScanResponse().accept(null)
    }

    override fun requestAsynchronize(callbackBlock: (LGOResponse) -> Unit) {
        callbackBlock.invoke(requestSynchronize())
    }

}