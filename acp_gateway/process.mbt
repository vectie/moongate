///|
priv struct Frames {
  reader : &@io.Reader
  mut pending : Bytes
  mut offset : Int32
}

///|
// ACP framing is newline-delimited UTF-8, not LSP Content-Length framing.
// Decode only after assembling a complete frame (UTF-8 can cross pipe reads).
async fn Frames::next(self : Frames) -> Json {
  let frame = Buffer()
  for ;; {
    if self.offset == self.pending.length() {
      guard self.reader.read_some(max_len=8192) is Some(bytes) else {
        raise protocol_error("Agent exited before completing the ACP response")
      }
      self.pending = bytes
      self.offset = 0
    }
    let start = self.offset
    while self.offset < self.pending.length() &&
          self.pending[self.offset] != b'\n' {
      self.offset += 1
    }
    frame.write_bytes(self.pending[start:self.offset])
    if frame.length() > 1048576 {
      raise protocol_error("ACP frame exceeds 1 MiB")
    }
    if self.offset < self.pending.length() {
      self.offset += 1
      return @json.parse(@utf8.decode(frame.to_bytes())) catch {
        _ => raise protocol_error("Agent stdout contains invalid ACP JSON")
      }
    }
  }
}

///|
async fn Bridge::complete(
  self : Bridge,
  chat : ChatRequest,
  on_text : async (String) -> Unit,
) -> (String, String) {
  let (child_stdin, input) = @process.write_to_process()
  defer input.close()
  let (output, child_stdout) = @process.read_from_process()
  defer output.close()
  let (errors, child_stderr) = @process.read_from_process()
  defer errors.close()
  @async.with_task_group(group => {
    group.spawn_bg(() => {
      let code = @process.run(
        self.command,
        self.args,
        stdin=child_stdin,
        stdout=child_stdout,
        stderr=child_stderr,
        cwd=self.cwd,
        cancel_handler=@process.hard_cancel(),
      )
      if code != 0 {
        raise protocol_error("ACP agent process exited unsuccessfully")
      }
    })
    // Drain without retaining or forwarding provider diagnostics/credentials.
    group.spawn_bg(() => {
      while errors.read_some(max_len=8192) is Some(_) {
        ()
      }
    })
    let frames : Frames = { reader: output, pending: b"", offset: 0, }
    let rpc : Rpc = {
      read: () => frames.next(),
      write: json => input.write("\{json.stringify()}\n"),
      next_id: 1,
      selected_model: None,
    }
    let result = rpc.complete(self.cwd, chat, on_text)
    // A request owns its child process. Success, timeout, client-write failure
    // and protocol failure all cancel and reap it; no pooled conversation state.
    group.return_immediately(result)
    result
  })
}
