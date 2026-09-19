# logos-evm-tx-kit

The QML pieces every EVM app needs where it composes and reviews a transaction, so the
wallet and the dapps show one fee picker, one Advanced section and one review instead of
each keeping its own copy. The rules behind the figures stay in `tx_sender_module`; the kit
only presents what its `prepare` reply says and turns the user's choices into a request.

| Component | What it is |
|---|---|
| `FeeTierPicker` | Low / Market / Fast; `tier` is fee_module's `slow`, `normal` or `fast`. |
| `TxFeeSummary` | Network fee (a ceiling, "at most"), gas limit, max and priority fee in gwei, nonce, fee basis. |
| `TxAdvancedFields` | Max fee, priority fee and gas limit in wei per gas, and a nonce; `overrides` is what the request carries. |
| `TxReviewDialog` | The last screen before the signer: the app's rows, then the fee, nonce, any replacement and each transaction. |
| `DetailRow` | A label and a right-aligned value. |

Every component takes `quote`, the `prepare` reply as tx_sender returns it (the wallet
backend's `prepare_send` and the Uniswap backend's `quote` under `fee` both pass it on).

## The rules the components keep

- Wei stays a decimal string. `fees.js` scales it to gwei exactly; a rounded fee is a claim
  nobody made.
- Both fee fields travel together. An older fee_module prices a lone one at the tier, so a
  user who sets only the priority fee gets the quote's max fee beside it: the one on screen
  when they first typed, held until both fields are empty. A quote of the request those fields shape
  never feeds back into them.
- Gas limits are per call, in the order the app builds them; `null` leaves a call estimated.
- A nonce pins a single call. A send of several transactions shows its nonces read-only.
- The review names a pinned nonce that replaces a pending transaction (`replaces`), and says
  when its fees were raised past it.

## Using it in an app

The kit is vendored, not imported from the host: the builder stages only an app's own view
directory. `vendor.sh` copies the kit into `src/qml/kit` with a `qmldir` whose module is named
after the app, as the builder does for each view's own directory against same-named types
crossing between views in one host, and records the kit commit in `src/qml/kit/VERSION`.

```bash
../logos-evm-tx-kit/scripts/vendor.sh .          # from the app's repo, at a kit checkout
```

```qml
import "kit" as Kit

Kit.FeeTierPicker { id: tiers }
Kit.TxFeeSummary { quote: q; tier: tiers.tier; calls: 1 }
Kit.TxAdvancedFields { id: advanced; quote: q; calls: 1 }
Kit.TxReviewDialog { prefix: "review"; quote: q; callList: q.legs; onConfirmed: send() }
```

An app's CI proves its copy is the kit at the pinned commit: check out the kit at
`src/qml/kit/VERSION` and run `scripts/check.sh <app repo>`.

## Testing

```bash
node doctests/fees_table.mjs        # fees.js, the same text the components import
./doctests/run_view_probe.sh        # every component, loaded offscreen and driven
```

The probes need a Qt Quick runtime and the design system (`LOGOS_DESIGN_SYSTEM_QML`), and
skip with a message without them.
