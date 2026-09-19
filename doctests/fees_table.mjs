#!/usr/bin/env node
// qml/fees.js as a table: the same text the components import.
//
// Run: node doctests/fees_table.mjs

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "qml", "fees.js"), "utf8");
const names = [...src.matchAll(/^function\s+(\w+)\s*\(/gm)].map((m) => m[1]);
const F = new Function(`${src}\nreturn { ${names.join(", ")} };`)();

let failed = 0;
function check(label, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    if (!ok) failed++;
    console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}   got=${JSON.stringify(got)}${ok ? "" : `  want=${JSON.stringify(want)}`}`);
}

console.log("\ngwei, exactly");
check("a mainnet max fee", F.gwei("3171648910"), "3.17164891");
check("under one gwei", F.gwei("169400000"), "0.1694");
check("one wei", F.gwei("1"), "0.000000001");
check("zero", F.gwei("0"), "0");
check("whole gwei loses no digit", F.gwei("1000000000"), "1");
check("past 2^53 still exact", F.gwei("123456789012345678901"), "123456789012.345678901");
check("not wei is nothing", F.gwei("3.5"), "");

console.log("\nwhat a quote priced");
const one = { nonce: 42, gasLimit: 21000, maxFeePerGas: "3171648910", maxPriorityFeePerGas: "169400000",
              feeCeilingWeiDisplay: "0.00006", nativeSymbol: "ETH", feeSource: "feeHistory" };
const two = { nonce: 7, gasLimit: 226000, legs: [{ gasLimit: 46000 }, { gasLimit: 180000 }] };
check("one call's limit", F.gasLimits(one), ["21000"]);
check("each call's limit", F.gasLimits(two), ["46000", "180000"]);
check("one nonce per call", F.nonces(two, 2), [7, 8]);
check("no quote, no nonce", F.nonces({}, 1), []);
check("a ceiling, never the fee", F.ceiling(one, "normal", ""), "at most 0.00006 ETH (Market)");
check("fees the user set read custom", F.ceiling({ ...one, feeSource: "custom" }, "fast", ""), "at most 0.00006 ETH (custom)");
check("no ceiling, no text", F.ceiling({}, "normal", "ETH"), "");

console.log("\nthe Advanced fields as a request");
check("nothing set adds nothing", F.overrides({}, one, 1), {});
check("a lone tip takes the quote's max fee with it",
      F.overrides({ priorityFee: "0" }, one, 1), { maxFeePerGas: "3171648910", maxPriorityFeePerGas: "0" });
check("a lone max fee takes the quote's tip",
      F.overrides({ maxFee: "5000000000" }, one, 1), { maxFeePerGas: "5000000000", maxPriorityFeePerGas: "169400000" });
check("gas limits per call, null left estimated",
      F.overrides({ gasLimits: ["", " 250000 "] }, two, 2), { gasLimits: [null, "250000"] });
check("a nonce pins one call", F.overrides({ nonce: " 40 " }, one, 1), { nonce: 40 });
check("and never a bundle", F.overrides({ nonce: "7" }, two, 2), {});

console.log("\nwhat is refused before a backend sees it");
check("well formed", F.fieldError({ maxFee: "1", priorityFee: "0", nonce: "3", gasLimits: ["21000"] }, 1), "");
check("a fee in gwei", F.fieldError({ maxFee: "3.5" }, 1), "Max fee must be a whole number");
check("a nonce in words", F.fieldError({ nonce: "forty" }, 1), "Nonce must be a whole number");
check("a zero gas limit", F.fieldError({ gasLimits: ["0"] }, 1), "Gas limit must be more than zero");
check("which call's", F.fieldError({ gasLimits: ["", "x"] }, 2), "Gas limit 2 must be a whole number");

console.log("\nthe replacement note");
check("raised", F.replacesText({ replaces: { nonce: 40, raised: true } }),
      "Replaces the transaction still pending at nonce 40. Its fees are raised past that one's, as nodes require.");
check("already past it", F.replacesText({ replaces: { nonce: 40, raised: false } }),
      "Replaces the transaction still pending at nonce 40.");
check("not a replacement", F.replacesText(one), "");

console.log(`\nRESULT: ${failed ? failed + " FAILED" : "ALL PASS"}`);
process.exit(failed ? 1 : 0);
