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

///|
test "protocol replays concealed composite partitions and rejects corrupt replay" {
  let config : Json = {
    "kind": "composite",
    "parts": [
      {
        "kind": "block",
        "name": "head",
        "rule": {
          "kind": "presentation",
          "concealed": "*",
          "rule": { "kind": "enum", "values": ["A", "AB"] },
        },
      },
      { "kind": "literal", "literal": " " },
      {
        "kind": "block",
        "name": "tail",
        "rule": { "kind": "regex", "source": "[A-Z]{1,2}" },
      },
    ],
  }
  fn request(replay : String) -> Json raise {
    @json.parse(
      @protocol.process(
        (
          {
            "config": config,
            "value": "ABC",
            "display": "*_ BC",
            "replay": replay,
            "op": "select",
            "start": 3,
            "end": 5,
            "text": "",
          } : Json).stringify(),
      ),
    )
  }
  assert_true(
    request("A BC")
    is {
      "ok": true,
      "state": {
        "raw": "ABC",
        "display": "*_ BC",
        "replay": "A BC",
        "value": "A BC",
        "start": 3,
        "end": 5,
        "fields": [
          { "name": "head", "value": "A", .. },
          { "name": "tail", "value": "BC", .. },
        ],
        ..
      },
      ..
    },
  )
  assert_true(request("AB C") is { "ok": false, "code": "value", .. })
  assert_true(request("bad") is { "ok": false, .. })
}

///|
test "protocol replay requires the expected display representation" {
  let response = @json.parse(
    @protocol.process(
      "{\"config\":{\"kind\":\"pattern\",\"pattern\":\"##\"},\"value\":\"12\",\"replay\":\"12\",\"op\":\"init\",\"start\":0,\"end\":0,\"text\":\"\"}",
    ),
  )
  assert_true(response is { "ok": false, "code": "config", .. })
}
