#!/usr/bin/env python3
"""
HTTP CONNECT → SOCKS5h bridge (pure Python stdlib, no external deps).

Problem:
  Go's net/http understands http:// and socks5:// proxy schemes but NOT
  socks5h://. When HTTPS_PROXY=socks5h://..., Go tries to DNS-resolve
  "socks5h" as a hostname and fails with "lookup socks5h: server misbehaving".

  We need socks5h (remote DNS) rather than socks5 (local DNS) because
  Azure Storage private endpoints only resolve to private IPs from within
  the Azure VNet — the GitHub runner can't resolve them locally.

Solution:
  Run this bridge between Go and the SSH SOCKS5 proxy:
    Go  →  HTTP CONNECT (http://127.0.0.1:BRIDGE_PORT)
        →  this script
        →  SOCKS5 with ATYP=0x03 (domain name, resolved by the proxy)
        →  ssh -D (SOCKS5 server on 127.0.0.1:SOCKS_PORT)
        →  Azure VNet via Bastion tunnel
        →  private endpoint

  Because we send the hostname in the SOCKS5 CONNECT request (ATYP=0x03),
  the SSH daemon on the jumpbox resolves it via Azure private DNS — exactly
  what socks5h:// would do if Go supported that scheme.

Usage (called by bastion-proxy.sh):
  python3 socks5h-bridge.py [bridge_port [socks_host [socks_port]]]

Defaults: bridge_port=8229, socks_host=127.0.0.1, socks_port=8228
"""

import socket
import struct
import threading
import sys

BRIDGE_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8229
SOCKS_HOST  = sys.argv[2]       if len(sys.argv) > 2 else "127.0.0.1"
SOCKS_PORT  = int(sys.argv[3])  if len(sys.argv) > 3 else 8228


def recv_exact(s: socket.socket, n: int) -> bytes:
    """
    Read exactly n bytes from s, looping over partial reads.

    socket.recv(n) may return fewer than n bytes — e.g. when a TCP segment
    arrives split across two packets.  If we don't read all n bytes before
    handing the socket to the relay, the leftover bytes corrupt the subsequent
    TLS handshake and Go sees an 'unexpected EOF'.
    """
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise RuntimeError(
                f"Connection closed after {len(buf)}/{n} bytes"
            )
        buf += chunk
    return buf


def socks5h_connect(host: str, port: int) -> socket.socket:
    """
    Open a TCP connection to host:port through the SOCKS5 proxy, passing the
    hostname (not a pre-resolved IP) so the proxy performs DNS resolution.
    This implements the socks5h behaviour using standard SOCKS5 ATYP=0x03.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((SOCKS_HOST, SOCKS_PORT))

    # --- SOCKS5 greeting ---
    # Client hello: VER=5, NMETHODS=1, METHOD=0x00 (no authentication)
    s.sendall(b"\x05\x01\x00")
    resp = recv_exact(s, 2)
    if resp != b"\x05\x00":
        raise RuntimeError(f"SOCKS5 auth negotiation failed: {resp!r}")

    # --- SOCKS5 CONNECT request ---
    # VER=5, CMD=1 (CONNECT), RSV=0, ATYP=3 (domain name)
    # DSTADDR = 1-byte length + hostname bytes
    # DSTPORT = 2-byte big-endian port
    host_b = host.encode("idna")
    request = (
        b"\x05\x01\x00\x03"
        + struct.pack("B", len(host_b))
        + host_b
        + struct.pack("!H", port)
    )
    s.sendall(request)

    # --- SOCKS5 CONNECT response ---
    # VER, REP, RSV, ATYP  (4 bytes) — must be read exactly to avoid
    # leaving bytes in the buffer that corrupt the subsequent TLS handshake.
    resp = recv_exact(s, 4)
    if resp[1] != 0x00:
        errors = {
            0x01: "general failure",
            0x02: "connection forbidden",
            0x03: "network unreachable",
            0x04: "host unreachable",
            0x05: "connection refused",
            0x06: "TTL expired",
            0x07: "command not supported",
            0x08: "address type not supported",
        }
        raise RuntimeError(
            f"SOCKS5 CONNECT failed: {errors.get(resp[1], f'REP={resp[1]:#04x}')}"
        )

    # Consume the bound address/port from the response (we don't need it,
    # but we MUST drain it exactly — any unread bytes corrupt the TLS stream).
    atyp = resp[3]
    if atyp == 0x01:    # IPv4: 4 bytes address + 2 bytes port
        recv_exact(s, 6)
    elif atyp == 0x03:  # domain: 1-byte length + n bytes address + 2 bytes port
        domain_len = recv_exact(s, 1)[0]
        recv_exact(s, domain_len + 2)
    elif atyp == 0x04:  # IPv6: 16 bytes address + 2 bytes port
        recv_exact(s, 18)

    return s


def relay(src: socket.socket, dst: socket.socket) -> None:
    """Bidirectional byte relay between two sockets (one direction)."""
    try:
        while True:
            chunk = src.recv(65536)
            if not chunk:
                break
            dst.sendall(chunk)
    except OSError:
        pass
    finally:
        for sock in (src, dst):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                sock.close()
            except OSError:
                pass


def handle_client(client: socket.socket) -> None:
    """Handle one incoming HTTP CONNECT request."""
    try:
        # Read until end of HTTP headers
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = client.recv(4096)
            if not chunk:
                return
            buf += chunk

        first_line = buf.split(b"\r\n")[0].decode(errors="replace")
        parts = first_line.split(None, 2)
        if len(parts) < 2 or parts[0].upper() != "CONNECT":
            client.sendall(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
            return

        host_port = parts[1]
        host, _, port_s = host_port.rpartition(":")
        if not host or not port_s:
            client.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        port = int(port_s)

        print(f"[bridge] CONNECT {host}:{port}", file=sys.stderr, flush=True)
        remote = socks5h_connect(host, port)
        print(f"[bridge] tunnel established → {host}:{port}", file=sys.stderr, flush=True)
        client.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")

        # Relay in both directions concurrently
        t1 = threading.Thread(target=relay, args=(client, remote), daemon=True)
        t2 = threading.Thread(target=relay, args=(remote, client), daemon=True)
        t1.start()
        t2.start()
        # Don't join — threads clean up on socket close

    except Exception as exc:
        print(f"[bridge] CONNECT failed ({host}:{port}): {exc}", file=sys.stderr, flush=True)
        try:
            client.close()
        except OSError:
            pass


def main() -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", BRIDGE_PORT))
    srv.listen(128)
    print(
        f"[bridge] HTTP CONNECT → SOCKS5h  "
        f"127.0.0.1:{BRIDGE_PORT} → {SOCKS_HOST}:{SOCKS_PORT}",
        file=sys.stderr,
        flush=True,
    )
    while True:
        try:
            client, _ = srv.accept()
            threading.Thread(target=handle_client, args=(client,), daemon=True).start()
        except OSError as exc:
            print(f"[bridge] accept error: {exc}", file=sys.stderr, flush=True)
            break


if __name__ == "__main__":
    main()
