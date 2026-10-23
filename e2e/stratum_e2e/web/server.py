"""Static file server for a Flutter web build (design section 8)."""

from __future__ import annotations

import functools
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import TracebackType

LOOPBACK_ADDRESS = "127.0.0.1"


class _IsolatedHandler(SimpleHTTPRequestHandler):
    """Serves files with the headers that cross-origin isolate the page.

    Without them the Wasm build silently falls back to `main.dart.js`.
    """

    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".mjs": "text/javascript",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, format: str, *args: object) -> None:
        """Drop the per-request log line; pytest owns the output."""


class StaticServer:
    """Serves [root] on a free loopback port while the `with` block runs."""

    def __init__(self, root: Path) -> None:
        if not root.is_dir():
            raise NotADirectoryError(f"{root} is not a folder")
        handler = functools.partial(_IsolatedHandler, directory=str(root))
        self._httpd = ThreadingHTTPServer((LOOPBACK_ADDRESS, 0), handler)
        self._thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)

    @property
    def url(self) -> str:
        """The base URL, `http://127.0.0.1:<port>`, with no trailing slash."""
        return f"http://{LOOPBACK_ADDRESS}:{self._httpd.server_port}"

    def __enter__(self) -> StaticServer:
        self._thread.start()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self._httpd.shutdown()
        self._httpd.server_close()
        self._thread.join()
