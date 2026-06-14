///|
#external
pub type Null

///|
extern "c" fn c_null() -> Null = "moonbit_moonstat_c_null"

///|
pub let null : Null = c_null()
