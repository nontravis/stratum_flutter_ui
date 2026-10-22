"""Ephemeral port allocation for locally spawned servers."""

from __future__ import annotations

import socket


def free_port() -> int:
    """Return a TCP port the OS currently reports free on 127.0.0.1.

    A race can still hand the port to a peer between this call and the caller's
    bind; Appium retries from a fresh port rather than caching one.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])
