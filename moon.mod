name = "vectie/moongate"

version = "0.1.4"

readme = "README.mbt.md"

repository = "https://github.com/vectie/moongate"

license = "Apache-2.0"

keywords = [ ]

description = "MoonBit-native local proxy and usage statistics gateway for the Moon suite"

import {
  "moonbitlang/async@0.16.6",
  "moonbitlang/x@0.4.50",
  "moonbitlang/regexp@0.3.5",
  "vectie/moonlib@0.1.23",
  "vectie/lepusa@0.1.4",
  "moonbit-community/rabbita@0.12.4",
}

preferred_target = "native"

options(
  bin: "moongate",
)
