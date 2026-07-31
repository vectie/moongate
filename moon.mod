name = "vectie/moonstat"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/vectie/moonstat"

license = "Apache-2.0"

keywords = [ ]

description = "Retired pre-MoonGate implementation retained for legacy-state migration"

import {
  "moonbitlang/async@0.16.6",
  "moonbitlang/x@0.4.40",
  "moonbitlang/regexp@0.3.5",
  "vectie/moonlib@0.1.9",
  "vectie/lepusa@0.1.0",
  "moonbit-community/rabbita@0.12.4",
}

preferred_target = "native"

options(
  bin: "moonstat",
)
