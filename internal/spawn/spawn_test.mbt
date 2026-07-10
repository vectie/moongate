///|
test "getpid" {
  ignore(@spawn.getpid())
  ignore(@spawn.getppid())
}

///|
async test "Manager::spawn" {
  let t = @test.Test("Manager::spawn")
  @mock.run(t, mock => {
    let manager = @spawn.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let process = manager.spawn("sleep", ["2"])
    json_inspect(process.pid, content=0)
  })
}

///|
async test "Manager::wait" {
  let t = @test.Test("Manager::wait")
  @mock.run(t, mock => {
    let manager = @spawn.Manager::new(cwd=mock.cwd.path())
    mock.group.spawn_bg(() => manager.start(), no_wait=true)
    let process = manager.spawn("sleep", ["2"])
    let status = process.wait()
    json_inspect(status, content=0)
  })
}

///|
async test "spawn/env" {
  let t = @test.Test("spawn/env")
  @mock.run(t, _ => {
    let process = @spawn.spawn("sh", ["-c", "echo $TEST_ENV_VAR"], env={
      "TEST_ENV_VAR": "hello_world",
    })
    json_inspect(process.status, content=0)
    json_inspect(process.stdout.to_string(), content="hello_world\n")
  })
}

///|
async test "redirect-stdin" {
  let t = @test.Test("redirect-stdin")
  @mock.run(t, _ => {
    let process = @spawn.spawn("cat", [], stdin="Hello, World!\n")
    json_inspect(process.status, content=0)
    inspect(
      process.stdout,
      content=(
        #|Hello, World!
        #|
      ),
    )
  })
}

///|
async test "spawn/failed" {
  let t = @test.Test("spawn/failed")
  @mock.run(t, _ => {
    let process = @spawn.spawn("sh", ["-c", "exit 42"])
    json_inspect(
      (try process.check() catch {
        error => Err(error)
      } noraise {
        value => Ok(value)
      })
      .to_json()
      .transform(@json.Replacer::exclude(["elapsed"])),
      content={
        "Err": [
          "Failed",
          {
            "exec": "sh",
            "args": ["-c", "exit 42"],
            "status": 42,
            "stdout": "",
            "stderr": "",
          },
        ],
      },
    )
  })
}
