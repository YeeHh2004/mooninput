///|
test "protocol complete state and typed rejection" {
  let response = @json.parse(
    @protocol.process(
      "{\"config\":{\"kind\":\"date\"},\"value\":\"20261002\",\"op\":\"init\",\"start\":0,\"end\":0,\"text\":\"\"}",
    ),
  )
  assert_true(
    response
    is {
      "ok": true,
      "state": { "value": "2026-10-02", "status": "complete", .. },
      ..
    },
  )
}

///|
test "malformed protocol never throws" {
  for
    text in [
      "null", "{}", "[]", "invalid", "{\"config\":{\"kind\":\"date\"},\"start\":0.5}",
    ] {
    let response = @json.parse(@protocol.process(text))
    assert_true(response is { "ok": false, "code": "config", .. })
  }
}
