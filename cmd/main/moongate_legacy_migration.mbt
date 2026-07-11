///|
priv struct LegacyStateMigration {
  mut copied : Int
  mut identical : Int
  conflicts : Array[String]
  errors : Array[String]
}

///|
fn legacy_state_migration() -> LegacyStateMigration {
  { copied: 0, identical: 0, conflicts: [], errors: [] }
}

///|
fn migration_string_array(values : Array[String]) -> Json {
  Json::array(values.map(fn(value) { Json::string(value) }))
}

///|
fn migration_file_permission(relative_path : String) -> Int {
  let lower = relative_path.to_lower()
  if lower.contains("auth") ||
    lower.contains("token") ||
    lower.contains("credential") ||
    lower.contains("secret") ||
    lower.contains("key") {
    0o600
  } else {
    0o644
  }
}

///|
async fn migrate_legacy_state_entry(
  source_root : String,
  destination_root : String,
  source_path : String,
  state : LegacyStateMigration,
) -> Unit {
  let relative = @pathx.relative(source_root, source_path)
  let destination = @pathx.join(destination_root, relative)
  let kind = @fs.kind(source_path, follow_symlink=false) catch {
    _ => {
      state.errors.push("\{relative}: unable to inspect source")
      return
    }
  }
  match kind {
    Directory => {
      @fsx.make_directory(destination, recursive=true, exists_ok=true) catch {
        _ => {
          state.errors.push("\{relative}: unable to create destination directory")
          return
        }
      }
      let entries = @fsx.list_directory(source_path) catch {
        _ => {
          state.errors.push("\{relative}: unable to list source directory")
          return
        }
      }
      for entry in entries {
        migrate_legacy_state_entry(
          source_root,
          destination_root,
          entry.path,
          state,
        )
      }
    }
    Regular => {
      let source_bytes = @fs.read_file(source_path) catch {
        _ => {
          state.errors.push("\{relative}: unable to read source")
          return
        }
      }
      if @fs.exists(destination) {
        let destination_bytes = @fs.read_file(destination) catch {
          _ => {
            state.errors.push("\{relative}: unable to read destination")
            return
          }
        }
        if source_bytes.binary() == destination_bytes.binary() {
          state.identical += 1
        } else {
          state.conflicts.push(relative)
        }
        return
      }
      @fsx.make_directory(
        @pathx.dirname(destination),
        recursive=true,
        exists_ok=true,
      ) catch {
        _ => {
          state.errors.push("\{relative}: unable to create destination parent")
          return
        }
      }
      @fs.write_file(
        destination,
        source_bytes,
        create_mode=CreateNew,
        permission=migration_file_permission(relative),
      ) catch {
        _ => {
          state.errors.push("\{relative}: unable to write destination")
          return
        }
      }
      state.copied += 1
    }
    SymLink => state.errors.push("{relative}: symbolic links are not migrated")
    _ => state.errors.push("{relative}: unsupported filesystem entry")
  }
}

///|
fn legacy_state_migration_receipt(
  migration_id : String,
  source : String,
  destination : String,
  source_present : Bool,
  state : LegacyStateMigration,
) -> Json {
  let accepted = state.conflicts.is_empty() && state.errors.is_empty()
  {
    "contract_id": "moonsuite.product-state-migration.v1",
    "migration_id": migration_id,
    "product_id": "moongate",
    "legacy_product_id": "moonstat",
    "source": source,
    "destination": destination,
    "source_present": source_present,
    "copied_files": state.copied,
    "identical_files": state.identical,
    "conflicts": migration_string_array(state.conflicts),
    "errors": migration_string_array(state.errors),
    "source_deleted": false,
    "accepted": accepted,
  }
}

///|
async fn migrate_legacy_moongate_state(args : Array[String]) -> Unit {
  let root = parse_string_arg(args, "--root").unwrap_or(".")
  let migration_id = parse_string_arg(args, "--migration-id").unwrap_or(
    "moonstat-to-moongate",
  )
  if !safe_session_id(migration_id) {
    fail("MoonGate migration id must be a safe slug")
  }
  let source = root + "/.moonsuite/products/moonstat"
  let destination = root + "/.moonsuite/products/moongate"
  let state = legacy_state_migration()
  let source_present = @fs.exists(source)
  if source_present {
    @fsx.make_directory(destination, recursive=true, exists_ok=true)
    let entries = @fsx.list_directory(source) catch {
      _ => {
        state.errors.push(".: unable to list legacy product state")
        []
      }
    }
    for entry in entries {
      migrate_legacy_state_entry(source, destination, entry.path, state)
    }
  }
  let receipt = legacy_state_migration_receipt(
    migration_id,
    source,
    destination,
    source_present,
    state,
  )
  let receipt_dir = destination + "/migrations"
  @fsx.make_directory(receipt_dir, recursive=true, exists_ok=true)
  let receipt_path = receipt_dir + "/" + migration_id + ".json"
  @fs.write_file(
    receipt_path,
    @encoding/utf8.encode(receipt.stringify(indent=2) + "\n"),
    create_mode=CreateOrTruncate,
    permission=0o600,
  )
  println(receipt.stringify(indent=2))
}
