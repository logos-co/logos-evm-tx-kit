// The kit's components, loaded and driven with fabricated `prepare` replies: a one-call send,
// a two-call swap, a replacement and a refusal. Run with doctests/run_view_probe.sh.
import QtQuick
import QtQuick.Layouts
import "../qml" as Kit

Item {
    id: probe
    width: 900
    height: 900

    property int failures: 0
    property int confirmedCount: 0
    property int cancelledCount: 0

    function check(label, got, want) {
        var ok = JSON.stringify(got) === JSON.stringify(want)
        if (!ok) probe.failures++
        console.log((ok ? "  PASS  " : "  FAIL  ") + label + "   got=" + JSON.stringify(got)
                    + (ok ? "" : "  want=" + JSON.stringify(want)))
    }
    function find(o, name) {
        if (!o) return null
        if (o.objectName === name) return o
        var kids = [].concat(o.data !== undefined ? Array.prototype.slice.call(o.data) : [],
                             o.contentItem ? [o.contentItem] : [])
        for (var i = 0; i < kids.length; ++i) {
            var hit = find(kids[i], name)
            if (hit) return hit
        }
        return null
    }
    function prop(root, name, key) {
        var o = find(root, name)
        return o ? o[key] : "<absent>"
    }

    readonly property var one: ({ ok: true, nonce: 42, gasLimit: 21000, maxFeePerGas: "3171648910",
                                  maxPriorityFeePerGas: "169400000", feeCeilingWeiDisplay: "0.00006",
                                  nativeSymbol: "ETH", feeSource: "feeHistory" })
    readonly property var two: ({ ok: true, nonce: 7, gasLimit: 226000, maxFeePerGas: "5000000000",
                                  maxPriorityFeePerGas: "2000000000", feeCeilingWeiDisplay: "0.00113",
                                  nativeSymbol: "ETH", feeSource: "feeHistory",
                                  legs: [{ gasLimit: 46000 }, { gasLimit: 180000 }] })
    readonly property var replacing: ({ ok: true, nonce: 40, gasLimit: 21000, maxFeePerGas: "372524310",
                                        maxPriorityFeePerGas: "37979581", feeCeilingWeiDisplay: "0.0000078",
                                        nativeSymbol: "ETH", feeSource: "feeHistory",
                                        replaces: { nonce: 40, raised: true } })

    ColumnLayout {
        width: parent.width
        Kit.FeeTierPicker { id: picker; label: "Fee" }
        Kit.TxFeeSummary { id: summary; quote: probe.one; tier: picker.tier }
        Kit.TxAdvancedFields { id: adv; quote: probe.one }
    }
    Kit.TxReviewDialog {
        id: review
        prefix: "review"
        rows: [{ label: "You pay", value: "0.00011 ETH", name: "reviewPay" }]
        quote: probe.one
        tier: "normal"
        callList: [{ label: "Swap ETH for USDT", to: "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45", value: "0x6400", data: "0x5ae401dc" }]
        nameOf: function (a) { return a.slice(0, 6) + "…" + a.slice(-4) }
        confirmText: "Confirm swap"
        onConfirmed: probe.confirmedCount++
        onCancelled: probe.cancelledCount++
    }

    property int phase: 0
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            probe.phase++
            if (probe.phase === 1) {
                console.log("")
                console.log("the tier picker names fee_module's tiers the way both apps did")
                check("three buttons", [prop(picker, "tierSlow", "text"), prop(picker, "tierNormal", "text"),
                                        prop(picker, "tierFast", "text")], ["Low", "Market", "Fast"])
                check("Market is the default", picker.tier, "normal")
                find(picker, "tierFast").clicked()
                check("a click picks the tier", picker.tier, "fast")

                console.log("")
                console.log("the summary of a one-call send")
                check("the ceiling, in the tier's name", prop(summary, "feeRow", "value"), "at most 0.00006 ETH (Fast)")
                check("the gas limit", prop(summary, "gasLimitRow", "value"), "21000")
                check("the max fee, in gwei", prop(summary, "maxFeeRow", "value"), "3.17164891 gwei")
                check("the tip, in gwei", prop(summary, "priorityFeeRow", "value"), "0.1694 gwei")
                check("the nonce", prop(summary, "nonceRow", "value"), "42")
                check("where the figures came from", prop(summary, "feeSourceLabel", "text"), "Fee basis: feeHistory")
                check("no fee error", prop(summary, "feeErrorLabel", "visible"), false)
                summary.calls = 2
                summary.quote = probe.two
            } else if (probe.phase === 2) {
                console.log("")
                console.log("and of a two-call swap")
                check("each call's limit", prop(summary, "gasLimitRow", "value"), "46000 + 180000")
                check("labelled as several", prop(summary, "gasLimitRow", "label"), "Gas limits")
                check("one nonce per call", prop(summary, "nonceRow", "value"), "7, 8")
                summary.calls = 1
                summary.quote = probe.replacing
            } else if (probe.phase === 3) {
                check("a replacement says so on its nonce", prop(summary, "nonceRow", "value"),
                      "40 · replaces a pending transaction")
                summary.quote = { ok: false, error: "insufficient funds for the fee" }
            } else if (probe.phase === 4) {
                check("a refusal shows instead of figures", prop(summary, "feeErrorLabel", "text"),
                      "Fee: insufficient funds for the fee")
                check("with no ceiling", prop(summary, "feeRow", "value"), "—")
                check("and no rows made of nothing", prop(summary, "maxFeeRow", "visible"), false)

                console.log("")
                console.log("the Advanced fields")
                check("closed, they add nothing", adv.overrides, {})
                check("placeholders are the quote's", prop(adv, "maxFeeField", "placeholderText"),
                      "Max fee (wei per gas, suggested 3171648910)")
                check("...every one of them", prop(adv, "nonceField", "placeholderText"), "Nonce (next is 42)")
                adv.open = true
                find(adv, "maxPriorityFeeField").text = "0"
                find(adv, "nonceField").text = "40"
                find(adv, "gasLimitField").text = "30000"
            } else if (probe.phase === 5) {
                check("a lone tip travels with the quote's max fee, a nonce and a limit with them", adv.overrides,
                      { maxFeePerGas: "3171648910", maxPriorityFeePerGas: "0", gasLimits: ["30000"], nonce: 40 })
                // The request these fields shaped is priced again: its quote must not feed back.
                adv.quote = { ok: true, nonce: 40, maxFeePerGas: "3171648910", maxPriorityFeePerGas: "0" }
                adv.quote = {}
                check("the held fee does not follow a quote of its own request", adv.overrides.maxFeePerGas, "3171648910")
                find(adv, "maxPriorityFeeField").text = ""
                check("emptied, nothing is held", [adv.heldFee, adv.overrides.maxFeePerGas], ["", undefined])
                find(adv, "maxPriorityFeeField").text = "5"
                check("an edit that unpaired the quote still holds the fee last shown", adv.overrides.maxFeePerGas, "3171648910")
                find(adv, "maxFeeField").text = "3.5"
            } else if (probe.phase === 6) {
                check("a fee in gwei is refused in words", prop(adv, "advancedError", "text"), "Max fee must be a whole number")
                adv.clear()
                adv.quote = probe.two
                adv.calls = 2
                adv.callLabels = ["Approve TKN", "Swap TKN for ETH"]
                adv.open = true
            } else if (probe.phase === 7) {
                check("cleared, nothing is left", [adv.gasTexts, prop(adv, "maxFeeField", "text"),
                      prop(adv, "maxPriorityFeeField", "text"), prop(adv, "nonceField", "text"), adv.heldFee],
                      [[], "", "", "", ""])
                check("one gas limit field per call", prop(adv, "gasLimitField_1", "placeholderText"),
                      "Swap TKN for ETH: gas limit (estimated 180000)")
                check("the nonce cannot be pinned", prop(adv, "nonceField", "readOnly"), true)
                check("...and says why", prop(adv, "nonceField", "placeholderText"),
                      "Nonces 7, 8: a send of 2 transactions cannot be pinned")
                find(adv, "gasLimitField_1").text = "250000"
                find(adv, "nonceField").text = "7"
            } else if (probe.phase === 8) {
                check("an unset limit stays estimated, and no nonce pins a bundle", adv.overrides,
                      { gasLimits: [null, "250000"] })
                adv.calls = 1
                check("a change of calls drops the limits and the pin set for the old ones",
                      [adv.overrides, prop(adv, "nonceField", "text")], [{}, ""])
                adv.calls = 2

                console.log("")
                console.log("the review")
                review.open()
            } else if (probe.phase === 9) {
                check("the app's own rows come first", prop(review, "reviewPay", "value"), "0.00011 ETH")
                check("the fee ceiling", prop(review, "reviewFee", "value"), "at most 0.00006 ETH (Market)")
                check("the nonce", prop(review, "reviewNonce", "value"), "42")
                check("no replacement to speak of", prop(review, "reviewReplaces", "visible"), false)
                check("each call, named as the app names it, and whether it carries ether",
                      prop(review, "reviewCall_0", "text"), "1. Swap ETH for USDT · 0x68b3…Fc45 · carries ether")
                check("call data only when asked", prop(review, "reviewCallData_0", "visible"), false)
                check("the signer's promise", prop(review, "reviewNote", "text"),
                      "The signer asks once for all of them. Nothing is sent until it says yes.")
                find(review, "reviewConfirm").clicked()
                find(review, "reviewCancel").clicked()
                check("confirm and back are the app's to act on", [probe.confirmedCount, probe.cancelledCount], [1, 1])
                review.quote = probe.replacing
                review.busy = true
            } else if (probe.phase === 10) {
                check("a replacement is named", prop(review, "reviewReplaces", "text"),
                      "Replaces the transaction still pending at nonce 40. Its fees are raised past that one's, as nodes require.")
                check("busy, it cannot be confirmed twice", prop(review, "reviewConfirm", "enabled"), false)
                review.pricing = true
                review.feeError = "no time left to price the swap"
            } else {
                check("pricing says so", prop(review, "reviewFee", "value"), "Pricing…")
                check("a fee refusal is shown", prop(review, "reviewFeeError", "text"), "Fee: no time left to price the swap")
                console.log("")
                console.log("RESULT: " + (probe.failures ? probe.failures + " FAILED" : "ALL PASS"))
                Qt.exit(probe.failures ? 1 : 0)
            }
        }
    }
}
