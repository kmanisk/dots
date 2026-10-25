# Real-World Networking & Troubleshooting Guide

A practical engineering reference covering core networking concepts (MTU, TCP, UDP, DNS, TLS, SNI, DPI), grounded in real-world debugging on CachyOS, Jio 5G tethering, Counter-Strike 2 gaming constraints, and ISP censorship bypass.

---

## 1. Mental Model Validation: Theory vs Engineering Reality

### 1. Packet Encapsulation & ACKs
- **The "Capsule" Concept:** In real networking, this is formally called **Packet Encapsulation**. As application data moves down the stack, each layer wraps it with its own header:
  - **Application Data:** Raw HTTP payload, CS2 game state, or JSON response.
  - **Wrapped in TCP Segment:** Adds Source/Destination Ports, Sequence Number, ACK Number, and Window Size.
  - **Wrapped in IP Packet:** Adds Source/Destination IP addresses, Time-To-Live (TTL), and the Don't Fragment (DF) flag.
  - **Wrapped in Ethernet Frame:** Adds Source/Destination MAC addresses and Cyclic Redundancy Check (CRC) checksum.
- **Sequence Numbers & ACKs as Byte Offsets:** Sequence and ACK numbers are not arbitrary packet counts; they are **byte offsets**. The sender states: *"I have sent bytes 0 to 1400"*; the receiver replies with an ACK: *"I have acknowledged up to byte 1400; send byte 1401 next"*.

### 2. DNS & The "Internet Table"
- **Routing vs Firewalls:** 
  - `iptables` / `nftables` is strictly a **local Linux kernel firewall tool** for filtering and translating packets on your machine.
  - Global routing of IP addresses across the internet is handled by **BGP (Border Gateway Protocol)** and global router routing tables.
- **The DNS Resolution Hierarchy:**
  When a browser or program queries `google.com`:
  1. It checks the local application cache (browser) and the operating system resolver cache (`systemd-resolved` on `127.0.0.53:53`).
  2. If not cached locally, it queries a recursive resolver (`1.1.1.1` or the ISP's DNS).
  3. The recursive resolver walks the global hierarchy: **Root Servers (`.`)** -> **TLD Servers (`.com`)** -> **Authoritative Nameservers (`google.com`)**.
  4. The resulting IP address is returned to your system and cached with a Time-To-Live (TTL).

---

## 2. Core Networking Primitives

### Maximum Transmission Unit (MTU) & Packet Fragmentation
- **Definition:** The maximum size (in bytes) of a single data packet that an interface can transmit without breaking it into pieces.
- **Standard Ethernet MTU:** 1500 bytes (typical LAN/Wi-Fi standard: 20 bytes IPv4 header + 20 bytes TCP header + 1460 bytes payload).
- **Tethered / Cellular MTU (1372–1420 bytes):** Cellular networks (like Jio 5G) wrap your packets inside tunnel encapsulation headers (e.g. GTP, 464XLAT, IPv6-in-IPv4). Because the outer tunnel consumes header space, the usable inner MTU is smaller (e.g. 1372 bytes on this laptop's `Wired connection 1`).
- **Fragmentation & The "Don't Fragment" (DF) Flag:**
  - When a packet is larger than the route's MTU, intermediate routers must either fragment it into smaller pieces or drop it.
  - Modern TCP/UDP packets often have the IP `DF` (Don't Fragment) bit set. If a 1500-byte packet hits a 1372-byte bottleneck with DF set, the packet is silently dropped or an ICMP "Fragmentation Needed" packet is returned.
- **Why Changing MTU Breaks Gaming (CS2):**
  - Counter-Strike 2 communicates via Steam Datagram Relay (SDR) and UDP on ports 27015–27050.
  - UDP has no built-in handshake or recovery: if an interface MTU is misconfigured or mismatched with the mobile network, game state packets get dropped or fragmented improperly, causing severe in-game stutter, "packet loss %", or disconnects.
  - **Golden Invariant:** Never modify the interface MTU arbitrarily unless specifically tuning for an end-to-end path.

### TCP vs UDP: Mechanics & Real-World Use Cases
| Dimension | TCP (Transmission Control Protocol) | UDP (User Datagram Protocol) |
| :--- | :--- | :--- |
| **Connection State** | Connection-oriented (requires 3-way handshake) | Connectionless (fire and forget) |
| **Reliability** | Guaranteed delivery (ACKs, retransmissions on loss) | Unreliable (dropped packets stay dropped) |
| **Ordering** | Strict packet sequencing and stream reassembly | Packets can arrive out of order |
| **Overhead** | 20-byte header, window scaling, congestion control | 8-byte header, minimal protocol overhead |
| **Primary Use Cases** | Web browsing (HTTP/1.1, HTTP/2), SSH, file transfer | Fast-paced gaming (CS2), VoIP, DNS queries, HTTP/3 (QUIC) |

#### The TCP 3-Way Handshake
```text
Client                                  Server
  |                                       |
  | -------- SYN (Seq=X) ---------------> |  1. Client requests connection
  | <------- SYN-ACK (Seq=Y, Ack=X+1) --- |  2. Server acknowledges & agrees
  | -------- ACK (Ack=Y+1) -------------> |  3. Connection ESTABLISHED
  |                                       |
```
- **TCP RST (Reset Packet):** A flag sent to immediately kill a connection without a graceful close. Used by firewalls and ISP DPI middleboxes to forcibly terminate banned connections.

#### Why Gaming Uses UDP Instead of TCP
In CS2, you need the absolute latest player coordinates. If a packet containing enemy positions is dropped at millisecond 100, TCP would pause all subsequent packets, wait for a retransmission timeout, and retransmit the old packet at millisecond 200 (causing rubber-banding). UDP discards the old packet and immediately delivers the newest packet at millisecond 110, reducing perceived latency.

---

## 3. The DNS Pipeline: UDP 53 vs DoT (853) vs DoH (443)

### How DNS Works
DNS maps human-readable names (`github.com`) to machine IP addresses (`20.207.73.82`). When an application requests an address:
1. Application checks internal cache -> System DNS stub (`systemd-resolved` on `127.0.0.53:53`).
2. Resolver stub forwards query to upstream DNS servers (`1.1.1.1`, `8.8.8.8`).
3. Upstream returns IP records: Type `A` (IPv4), Type `AAAA` (IPv6), or Type `HTTPS` (Type 65).

### Transport Comparison
```text
Plain UDP 53  : [ Client ] ---> (Unencrypted UDP Port 53) ---> [ ISP / DNS ]
                Flaw: Open to ISP snooping, transparent interception, and 0.0.0.0 spoofing.

DoT (Port 853): [ Client ] === (TLS Encrypted TCP Port 853) ===> [ Public DNS ]
                Flaw: Dedicated port. Mobile carriers (Jio) frequently drop or throttle port 853.

DoH (Port 443): [ Client ] === (TLS Encrypted inside HTTPS 443) ===> [ Public DNS ]
                Strength: Indistinguishable from regular web traffic. Cannot be filtered by port.
```

### The 5-Second DoT Stalling Loop
On Linux with `systemd-resolved`, setting `DNSOverTLS=opportunistic` tells the resolver: *"Try TLS on port 853 first. If it fails, fall back to UDP."*

When connected to mobile carriers like Jio 5G:
1. Jio silently drops outgoing TCP SYN packets on port 853.
2. `systemd-resolved` waits for the TCP connection timeout (**5 full seconds**).
3. After 5 seconds, it logs: `Using degraded feature set UDP+EDNS0 instead of TLS+EDNS0 for DNS server 9.9.9.9`.
4. If multiple servers are listed, it tries the next one and stalls for another 5 seconds.
5. Because a modern webpage loads 20–50 subdomains, these 5-second stalls compound, making the network feel completely dead despite 500+ Mbps raw speedtest results.

---

## 4. How ISPs Block Websites: The 3 Tiers of Censorship

### Tier 1: DNS Hijacking / Spoofing
- **Mechanism:** The user's device sends a standard UDP port 53 query to resolve a domain.
- **The Block:** The ISP's DNS server either returns `0.0.0.0`, an NXDOMAIN error, or redirects the query to a government warning notice (`blocked.jio.com`).
- **Bypass:** Switch to third-party encrypted DNS (Cloudflare DoH or Google DoH).

### Tier 2: IP Blackholing (BGP Null-Routing)
- **Mechanism:** The ISP drops all traffic routed toward specific target IP addresses.
- **Limitation:** Ineffective when blocked sites sit behind Cloudflare, Fastly, or AWS CloudFront, because thousands of legal domains share the exact same IP pool. Blocking the IP would take down collateral websites.

### Tier 3: SNI-Based Deep Packet Inspection (DPI)
- **Mechanism:** Even when DNS is resolved and the IP is reachable, HTTPS connections require a TLS handshake.
- **The Vulnerability (Plaintext SNI):** Because the server hosts multiple websites on one IP, the client must declare which domain it wants via the `server_name` extension in the `ClientHello` packet. This happens **before** encryption is established!
- **The Block:**
  ```text
  Client                                          Cloudflare Edge
    |                                                    |
    | --- [TCP 3-Way Handshake SYN, SYN-ACK, ACK] -----> | (Succeeds)
    |                                                    |
    | --- [TLS ClientHello (SNI="vegamoviess.build")] -> |
    |           |                                        |
    |      [Jio DPI Router]                              |
    |      - Inspects SNI in plaintext                   |
    |      - Matches blacklist                           |
    |      - Fires spoofed TCP RST (Reset) ------------> | (Connection Killed)
    | <--- TCP RST (Connection reset by peer) ---------- |
  ```

---

## 5. The Investigation & Empirical Proof

During live troubleshooting of `https://vegamoviess.build/`, we proved ISP DPI mechanics step-by-step:

### Test 1: Standard Curl (Failed)
```bash
$ curl -Iv https://vegamoviess.build/
* Host vegamoviess.build:443 was resolved to 172.67.204.133
* Trying 172.67.204.133:443...
* Connected to 172.67.204.133 (172.67.204.133) port 443
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* Recv failure: Connection reset by peer
* OpenSSL SSL_connect: Connection reset by peer in connection to vegamoviess.build:443
curl: (35) Recv failure: Connection reset by peer
```
*Finding:* TCP connection succeeded, but the moment `ClientHello` with the target SNI was transmitted, an injected `TCP RST` severed the connection.

### Test 2: Connecting to the Same IP with a Allowed SNI (Succeeded)
```bash
$ curl -Iv --resolve cloudflare.com:443:172.67.204.133 https://cloudflare.com/
* Trying 172.67.204.133:443...
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
```
*Finding:* The IP `172.67.204.133` is not blocked. Only the plaintext SNI string `vegamoviess.build` triggers the RST.

### Test 3: TCP Packet Splitting / Fragmentation Proof (Bypassed)
We wrote a Python socket test that captured the exact 1533-byte `ClientHello` and transmitted it in two distinct TCP segments (50 bytes in packet 1, 1483 bytes in packet 2):
```python
# Connect to Cloudflare edge IP
s.connect(('172.67.204.133', 443))

# Send split packet across TCP stream
s.sendall(client_hello[:50])
time.sleep(0.05)
s.sendall(client_hello[50:])

# Result:
# SUCCESS: Received 3739 bytes from Cloudflare! First byte: 22 (TLS ServerHello)
```
*Finding:* The ISP's DPI middlebox is stateless and checks only single incoming packets. Because the domain string was split across packet boundaries, the DPI failed to detect the SNI, allowing Cloudflare to complete the handshake.

---

## 6. The Solution Architecture

### Fix 1: System-Level DNS (`systemd-resolved`)
Eliminated the port 853 timeout stalls in `/etc/systemd/resolved.conf.d/99-custom-dns.conf`:
- `DNSOverTLS=no`: Tells the system resolver never to attempt port 853, eliminating the 5-second timeout loops.
- `Domains=~.`: Designates public DNS (`1.1.1.1`, `8.8.8.8`) as the authoritative routing domain for all hostnames, stopping leaks to the phone's tethering forwarder.

### Fix 2: Browser-Level ECH (Encrypted Client Hello)
Cloudflare edge nodes support **ECH (RFC 9460 / Draft ECH)**. 

1. When Brave has **Secure DNS (DoH)** enabled, it queries Cloudflare DoH (`https://cloudflare-dns.com/dns-query`) for the Type 65 `HTTPS` record of `vegamoviess.build`.
2. Cloudflare returns the ECH public key (`public_name: cloudflare-ech.com`).
3. Brave encrypts the true SNI (`vegamoviess.build`) using that key and wraps it inside an outer packet where the visible SNI is `cloudflare-ech.com`.
4. Jio's DPI inspects the packet, sees only `cloudflare-ech.com` (which is allowed), and forwards it.
5. Cloudflare decrypts the inner SNI, connects to `vegamoviess.build`, and serves the website without VPN or proxies.

---

## 7. Practical Learning Roadmap: From Theory to Systems Engineer

Rather than memorizing abstract 7-layer OSI diagrams, real-world network engineering progresses through four hands-on implementation phases:

```text
Phase 1: Packet Observability (See raw traffic on the wire)
   │
Phase 2: Socket Programming (Write raw networking code)
   │
Phase 3: Linux Kernel Plumbing (Routing, firewalls, interfaces)
   │
Phase 4: High-Level Protocols (HTTP/2, QUIC/HTTP/3, Reverse Proxies)
```

### Phase 1: Packet Observability
- **Core Skill:** Inspect real traffic moving across interfaces rather than imagining theoretical diagrams.
- **Mental Milestone:** Witnessing a live TCP 3-way handshake (`SYN -> SYN-ACK -> ACK`), payload transmission, and termination (`FIN` or `RST`).
- **Hands-on Task:** Capture an outbound HTTPS request using a TUI packet sniffer (`termshark` or `tcpdump`).
  - `tcp.flags.syn == 1 and tcp.flags.ack == 0`: Watch new outbound TCP connections initiate.
  - `tcp.flags.reset == 1`: See the exact TCP RST packets that firewalls or ISP DPIs inject when blocking a connection.
  - `dns`: Inspect the raw query names, record types (`A`, `AAAA`, `HTTPS`), and response TTLs.

### Phase 2: Raw Socket Programming
Every network API—whether in Node.js, Go, Rust, or Python—is built on top of POSIX Berkeley Sockets. Sockets are simply file descriptors in the Linux kernel that read and write bytes over network interfaces instead of disk drives.

#### Core Server Lifecycle
```text
socket() -> bind() -> listen() -> accept() -> recv() / send() -> close()
```

#### Core Client Lifecycle
```text
socket() -> connect() -> sendall() -> recv() -> close()
```

#### Hands-on Task 1 (Pure Socket HTTP GET):
```python
import socket

# 1. Open raw TCP stream socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# 2. Connect to web server on port 80
s.connect(("example.com", 80))

# 3. Transmit HTTP 1.1 request bytes
s.sendall(b"GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n")

# 4. Stream response chunks until connection closes
response = b""
while True:
    chunk = s.recv(4096)
    if not chunk:
        break
    response += chunk

print(response.decode())
s.close()
```
*Analysis:* Inspect the response: the HTTP status code (`200 OK`), headers (`Content-Length`, `Server`), and the HTML payload. Seeing how high-level APIs map directly to raw socket bytes demystifies the entire stack.

#### Hands-on Task 2 (Multi-Client Chat Server):
Write a non-blocking TCP echo/chat server using Python's `selectors` module or C `epoll`. Manage incoming client file descriptors, buffers, and partial packet reassembly without threading.

#### Hands-on Task 3 (Raw UDP DNS Client):
Pack a raw 12-byte binary DNS header, construct a question for `example.com`, transmit over UDP to `1.1.1.1:53`, and unpack the byte offset response.

### Phase 3: Linux Kernel Plumbing & System State
This bridges code to operating systems. This is what solved your tethering and CS2 constraints:

#### 1. Interfaces, Subnets & Routing
- **Subnetting & CIDR:** Understanding why `/24` represents 256 addresses (`255.255.255.0`) and `/32` represents a single host.
- **Routing Metrics:** Understanding why prioritized routing (e.g. Ethernet/tethering metric `50` vs Wi-Fi metric `600` in `/etc/NetworkManager/conf.d/30-metric-priority.conf`) guarantees deterministic gateway selection.
- **Commands to master:**
  ```bash
  ip -br addr show       # Brief interface list and IP assignments
  ip route show          # Kernel routing table and default gateways
  ss -tulpn              # Active listening ports and associated PIDs
  ```

#### 2. Linux Packet Filtering (`nftables` / `iptables`)
- **Packet Traversals:**
  - `PREROUTING`: Inspect packets before routing decisions.
  - `FORWARD`: Packets passing through your machine to another device (tethering/Waydroid/Docker).
  - `INPUT` / `OUTPUT`: Packets destined for or created by local processes.
- **NAT (Network Address Translation):** How Masquerading allows multiple local virtual machines (Docker, Waydroid) to share a single public IP.

### Phase 4: Modern Application Transport & Infrastructure
1. **HTTP/1.1 vs HTTP/2 vs HTTP/3:**
   - **HTTP/1.1:** Head-of-line blocking (one request per TCP connection at a time unless pipelined).
   - **HTTP/2:** Binary framing, multiplexing multiple parallel streams over one TCP pipe.
   - **HTTP/3 (QUIC):** Built directly on **UDP** to eliminate TCP-level head-of-line blocking and connection migration delays during network handoffs.
2. **Reverse Proxies & Load Balancers:**
   - Configuring Caddy, Nginx, or HAProxy for TLS termination, load balancing, and header manipulation.
3. **Encrypted Transport Standards:**
   - TLS 1.3 key exchange (ECDHE, forward secrecy).
   - Encrypted Client Hello (ECH) mechanisms.

---

## 8. Terminal-First (TUI) Networking Arsenal

Avoid heavy, bloated Qt/Electron GUI sniffers like full Wireshark. The following lightweight, terminal-native tools provide professional observability directly inside your terminal emulator.

### 1. `termshark` — The Terminal Replacement for Wireshark
- **What it is:** A full-featured terminal UI for `tshark` inspired by Wireshark.
- **Strengths:** Gives you the classic Wireshark 3-pane layout (Packet List, Packet Tree Details, Hex/Byte Dump) directly inside `kitty` / `foot` / `alacritty` without GUI overhead.
- **Installation:** `sudo pacman -S termshark` (Available in `cachyos-extra-v3` / `extra`).
- **Essential Usage:**
  ```bash
  # Sniff active Wi-Fi interface live
  termshark -i wlan0

  # Sniff tethered USB interface live
  termshark -i enp0s20f0u5

  # Launch with pre-filtered display filter (e.g. only DNS or TCP resets)
  termshark -i any -Y "tcp.flags.reset == 1"
  termshark -i any -Y "dns"
  ```
- **Navigation Chords:**
  - `Tab`: Cycle between Packet List, Packet Details, and Hex Dump panes.
  - `/`: Search / apply display filters.
  - `q`: Quit.

### 2. `bandwhich` — Live Process & Connection Bandwidth Monitor
- **What it is:** A terminal utility written in Rust that displays live bandwidth utilization.
- **Strengths:** Correlates network socket bandwidth with the actual local **Process Name (and PID)**, local port, and remote destination IP/hostname.
- **Installation:** `sudo pacman -S bandwhich` (Available in `extra`).
- **Essential Usage:**
  ```bash
  # Monitor all interfaces with process attribution
  sudo bandwhich

  # Monitor a specific interface
  sudo bandwhich -i wlan0

  # Show raw IP addresses instead of performing reverse DNS resolution
  sudo bandwhich -n
  ```

### 3. `trippy` (`trip`) — Interactive Network Diagnostic & Latency TUI
- **What it is:** A high-performance Ratatui-based diagnostic tool combining `traceroute` and `ping`.
- **Strengths:** Traces the full hop-by-hop route across the internet to any server, showing real-time packet loss %, min/avg/max/stddev latency, jitter, Autonomous System Numbers (ASN), and geo-location.
- **Installation:** `sudo pacman -S trippy` (Available in `cachyos-extra-v3` / `extra`).
- **Essential Usage:**
  ```bash
  # Trace route to Cloudflare DNS
  trip 1.1.1.1

  # Trace route to Steam gaming server with UDP packets
  trip -p udp 162.254.197.1

  # Trace route to web host over HTTPS port
  trip -p tcp -P 443 google.com
  ```
- **Interactive Controls:**
  - `c`: Toggle column views.
  - `f`: Freeze / unfreeze live packet polling.
  - `q`: Quit.

### 4. `mitmproxy` — Interactive HTTP/HTTPS & API Interceptor
- **What it is:** A console/TUI proxy for inspecting, intercepting, and replaying HTTP/1, HTTP/2, and WebSocket traffic.
- **Strengths:** Inspect API requests, headers, query parameters, payloads, and JSON responses directly in the terminal.
- **Installation:** `sudo pacman -S mitmproxy` (Available in `extra`).
- **Essential Usage:**
  ```bash
  # Launch interactive TUI proxy on port 8080
  mitmproxy -p 8080
  ```
  *(Point your browser or script to HTTP proxy `127.0.0.1:8080` to inspect live calls).*

### 5. `iftop` — Bandwidth Flow Monitor
- **What it is:** A minimal curses utility displaying real-time bandwidth pairs (`Host A <=> Host B`).
- **Installation:** `sudo pacman -S iftop` (Available in `cachyos-extra-v3` / `extra`).
- **Essential Usage:**
  ```bash
  sudo iftop -i wlan0 -P -N
  ```
  *(`-P` displays port numbers; `-N` prevents DNS resolution delays).*

---

### Comparison Matrix: Which TUI Tool to Use When

| Objective | Recommended TUI Tool | Key Advantage |
| :--- | :--- | :--- |
| **Inspect raw packet bytes & TLS handshakes** | `termshark` | Wireshark 3-pane layout, full filter syntax, zero GUI bloat. |
| **Find which app/PID is consuming bandwidth** | `bandwhich` | Real-time process correlation (shows PID, binary name, speed). |
| **Debug ping spikes, packet loss & route hops** | `trippy` (`trip`) | Modern traceroute + ping, jitter statistics, hop loss breakdown. |
| **Inspect REST APIs, HTTP headers & payloads** | `mitmproxy` | Interactive request/response inspector and replay console. |
| **Quick glance at network interface throughput** | `iftop` | Extremely lightweight, shows top active host pairs. |

---

## 9. Developer Reference: Networking APIs & Diagnostics

### Python Low-Level Socket Primitives
```python
import socket
import ssl

# 1. Create raw TCP socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(5.0)

# 2. Connect to IP and port
s.connect(("1.1.1.1", 443))

# 3. Wrap socket with TLS context
ctx = ssl.create_default_context()
tls_socket = ctx.wrap_socket(s, server_hostname="cloudflare-dns.com")

# 4. Send HTTP request
request = b"GET /dns-query?name=google.com&type=A HTTP/1.1\r\nHost: cloudflare-dns.com\r\nAccept: application/dns-json\r\nConnection: close\r\n\r\n"
tls_socket.sendall(request)

# 5. Read response
response = tls_socket.recv(4096)
print(response.decode(errors="ignore"))
tls_socket.close()
```

### Essential Linux Diagnostic Commands
- **Interface & Link State:** `ip addr show`, `ip link show`
- **Routing Table & Metrics:** `ip route show`
- **DNS Stub & Scopes:** `resolvectl status`, `resolvectl query <domain>`
- **Live Sockets & Ports:** `ss -tulpn` (TCP/UDP listening ports and PIDs)
- **Detailed TLS Handshake Debug:** `curl -Iv --doh-url https://cloudflare-dns.com/dns-query https://<domain>`
- **Check ECH DNS Record:**
  ```bash
  curl -s -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=<domain>&type=HTTPS" | jq .
  ```
- **Packet Capture Analysis:** `tcpdump -i any -nn "port 443 or port 53"`
