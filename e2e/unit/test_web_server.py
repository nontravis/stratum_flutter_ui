"""Unit tests for the static web server that serves a build with COOP and COEP headers."""

from __future__ import annotations

import urllib.error
import urllib.request
from pathlib import Path

import pytest

from stratum_e2e.web.server import StaticServer


@pytest.fixture
def build(tmp_path: Path) -> Path:
    (tmp_path / "index.html").write_text("<p>hello</p>")
    (tmp_path / "main.dart.wasm").write_bytes(b"\0asm\1\0\0\0")
    return tmp_path


def test_server_sends_the_cross_origin_isolation_headers(build: Path) -> None:
    with StaticServer(build) as server:
        response = urllib.request.urlopen(f"{server.url}/index.html")

    assert response.headers["Cross-Origin-Opener-Policy"] == "same-origin"
    assert response.headers["Cross-Origin-Embedder-Policy"] == "require-corp"
    assert response.read() == b"<p>hello</p>"


def test_server_serves_the_root_as_index_html(build: Path) -> None:
    with StaticServer(build) as server:
        body = urllib.request.urlopen(f"{server.url}/").read()

    assert body == b"<p>hello</p>"


def test_server_sends_the_headers_on_an_error_response_too(build: Path) -> None:
    with StaticServer(build) as server:
        with pytest.raises(urllib.error.HTTPError) as caught:
            urllib.request.urlopen(f"{server.url}/missing.js")

    assert caught.value.code == 404
    assert caught.value.headers["Cross-Origin-Embedder-Policy"] == "require-corp"


def test_server_types_wasm_so_the_browser_can_stream_compile_it(build: Path) -> None:
    with StaticServer(build) as server:
        response = urllib.request.urlopen(f"{server.url}/main.dart.wasm")

    assert response.headers["Content-Type"] == "application/wasm"


def test_server_listens_on_loopback_only(build: Path) -> None:
    with StaticServer(build) as server:
        assert server.url.startswith("http://127.0.0.1:")


def test_server_stops_when_the_context_exits(build: Path) -> None:
    with StaticServer(build) as server:
        url = server.url

    with pytest.raises(urllib.error.URLError):
        urllib.request.urlopen(f"{url}/index.html", timeout=2)


def test_server_refuses_a_root_that_is_not_a_folder(tmp_path: Path) -> None:
    with pytest.raises(NotADirectoryError):
        StaticServer(tmp_path / "missing")
