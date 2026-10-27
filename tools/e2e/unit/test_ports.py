"""Unit tests for ephemeral port allocation."""

from __future__ import annotations

import socket

from stratum_e2e.ports import free_port


def test_free_port_is_bindable() -> None:
    port = free_port()
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.bind(("127.0.0.1", port))
        server.listen(1)


def test_free_port_in_range() -> None:
    assert 0 < free_port() < 65536
