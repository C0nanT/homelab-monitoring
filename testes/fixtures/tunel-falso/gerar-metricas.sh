#!/bin/sh
# Túnel falso do smoke test: gera os /metrics fixos do Traefik e do node
# exporter e sobe o nginx que os serve (nginx.conf, portas 8082 e 9100).
#
# Os valores são calculados a partir da hora em que o smoke RODA (não ficam
# fixos no arquivo): o certificado "vencendo" está sempre a 10 dias de agora, e
# os contadores crescem com o tempo para rate()/increase() terem dados.
# Regerado a cada 5s; escreve num temporário e troca com mv (o Prometheus nunca
# lê um arquivo pela metade).
#
# Séries (para os painéis do ticket 04 e os alertas do ticket 05):
#
# Traefik (tunel:8082, job traefik; nomes e rótulos padrão do Traefik v3):
#   traefik_tls_certs_not_after{cn,sans,serial}  unix (s) em que vence
#     - conantorres.dev        vence em 10 dias (< 20: alerta de certificado DISPARA)
#     - bbcontainermodular.com vence em 60 dias (saudável)
#   traefik_service_requests_total{code,method,protocol,service}  contador
#     - conantorres@docker         só 2xx/3xx/4xx (sem 5xx)
#     - bbcontainermodular@docker  ~10% de 5xx (500 e 502) com tráfego alto
#     - api@internal               ~50% de 5xx, mas só ~0,03 req/s (1 pedido 500
#       e 1 pedido 200 por minuto): a regra de 5xx com tráfego mínimo (0,05
#       req/s) NÃO deve disparar aqui, embora a taxa de 5xx passe de 5%
#   traefik_service_request_duration_seconds_{bucket,sum,count}{code,method,protocol,service,le}
#   traefik_service_requests_bytes_total / traefik_service_responses_bytes_total
#   traefik_entrypoint_requests_total{code,entrypoint,method,protocol}  (websecure, web)
#   traefik_entrypoint_request_duration_seconds_{bucket,sum,count}
#   traefik_open_connections{entrypoint,method,protocol}
#   traefik_config_reloads_total
#
# node exporter (tunel:9100, job node):
#   node_uname_info{nodename="vps-smoke",...}  (variáveis do painel Node Exporter Full)
#   node_boot_time_seconds, node_time_seconds, node_load1/5/15
#   node_cpu_seconds_total{cpu="0|1",mode="idle|user|system|iowait|..."}  2 vCPUs
#   node_memory_{MemTotal,MemAvailable,MemFree,Buffers,Cached,SwapTotal,SwapFree}_bytes
#   node_filesystem_{size,avail,free}_bytes, _readonly, _files, _files_free
#     {device="/dev/sda1",fstype="ext4",mountpoint="/"}  60% usado (< 85%: alerta de disco NÃO dispara)
#   node_network_{receive,transmit}_bytes_total{device="eth0"}
#   node_disk_{read,written}_bytes_total, node_disk_io_time_seconds_total{device="sda"}
set -eu

PASTA=/tmp/metricas
mkdir -p "$PASTA"
INICIO="$(date +%s)"

gerar_traefik() { # agora t(segundos desde o início)
  agora="$1" t="$2"
  # Contadores: base + taxa por segundo * t.
  ok_cnt=$((5000 + 20 * t))
  bb_ok=$((9000 + 18 * t))
  bb_500=$((700 + t))
  bb_502=$((300 + t))
  cat <<FIM
# HELP traefik_tls_certs_not_after Certificate expiration timestamp
# TYPE traefik_tls_certs_not_after gauge
traefik_tls_certs_not_after{cn="conantorres.dev",sans="conantorres.dev,www.conantorres.dev",serial="1001"} $((agora + 10 * 86400))
traefik_tls_certs_not_after{cn="bbcontainermodular.com",sans="bbcontainermodular.com,www.bbcontainermodular.com",serial="1002"} $((agora + 60 * 86400))
# HELP traefik_service_requests_total How many HTTP requests processed on a service, partitioned by status code, protocol, and method.
# TYPE traefik_service_requests_total counter
traefik_service_requests_total{code="200",method="GET",protocol="http",service="conantorres@docker"} $ok_cnt
traefik_service_requests_total{code="304",method="GET",protocol="http",service="conantorres@docker"} $((300 + t))
traefik_service_requests_total{code="404",method="GET",protocol="http",service="conantorres@docker"} $((40 + t / 10))
traefik_service_requests_total{code="200",method="GET",protocol="http",service="bbcontainermodular@docker"} $bb_ok
traefik_service_requests_total{code="200",method="POST",protocol="http",service="bbcontainermodular@docker"} $((1000 + 2 * t))
traefik_service_requests_total{code="500",method="GET",protocol="http",service="bbcontainermodular@docker"} $bb_500
traefik_service_requests_total{code="502",method="GET",protocol="http",service="bbcontainermodular@docker"} $bb_502
traefik_service_requests_total{code="200",method="GET",protocol="http",service="api@internal"} $((3 + t / 60))
traefik_service_requests_total{code="500",method="GET",protocol="http",service="api@internal"} $((1 + t / 60))
# HELP traefik_service_request_duration_seconds How long it took to process the request on a service, partitioned by status code, protocol, and method.
# TYPE traefik_service_request_duration_seconds histogram
FIM
  for s in conantorres@docker bbcontainermodular@docker; do
    n=$((1000 + 10 * t))
    echo "traefik_service_request_duration_seconds_bucket{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\",le=\"0.1\"} $((n * 70 / 100))"
    echo "traefik_service_request_duration_seconds_bucket{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\",le=\"0.3\"} $((n * 90 / 100))"
    echo "traefik_service_request_duration_seconds_bucket{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\",le=\"1.2\"} $((n * 98 / 100))"
    echo "traefik_service_request_duration_seconds_bucket{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\",le=\"5\"} $n"
    echo "traefik_service_request_duration_seconds_bucket{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\",le=\"+Inf\"} $n"
    echo "traefik_service_request_duration_seconds_sum{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\"} $((n / 8))"
    echo "traefik_service_request_duration_seconds_count{code=\"200\",method=\"GET\",protocol=\"http\",service=\"$s\"} $n"
  done
  cat <<FIM
# HELP traefik_service_requests_bytes_total The total size of requests in bytes handled by a service, partitioned by status code, protocol, and method.
# TYPE traefik_service_requests_bytes_total counter
traefik_service_requests_bytes_total{code="200",method="GET",protocol="http",service="conantorres@docker"} $((ok_cnt * 400))
traefik_service_requests_bytes_total{code="200",method="GET",protocol="http",service="bbcontainermodular@docker"} $((bb_ok * 450))
# HELP traefik_service_responses_bytes_total The total size of responses in bytes handled by a service, partitioned by status code, protocol, and method.
# TYPE traefik_service_responses_bytes_total counter
traefik_service_responses_bytes_total{code="200",method="GET",protocol="http",service="conantorres@docker"} $((ok_cnt * 15000))
traefik_service_responses_bytes_total{code="200",method="GET",protocol="http",service="bbcontainermodular@docker"} $((bb_ok * 22000))
# HELP traefik_entrypoint_requests_total How many HTTP requests processed on an entrypoint, partitioned by status code, protocol, and method.
# TYPE traefik_entrypoint_requests_total counter
traefik_entrypoint_requests_total{code="200",entrypoint="websecure",method="GET",protocol="http"} $((ok_cnt + bb_ok))
traefik_entrypoint_requests_total{code="500",entrypoint="websecure",method="GET",protocol="http"} $bb_500
traefik_entrypoint_requests_total{code="502",entrypoint="websecure",method="GET",protocol="http"} $bb_502
traefik_entrypoint_requests_total{code="308",entrypoint="web",method="GET",protocol="http"} $((500 + 2 * t))
# HELP traefik_entrypoint_request_duration_seconds How long it took to process the request on an entrypoint, partitioned by status code, protocol, and method.
# TYPE traefik_entrypoint_request_duration_seconds histogram
traefik_entrypoint_request_duration_seconds_bucket{code="200",entrypoint="websecure",method="GET",protocol="http",le="0.1"} $(((ok_cnt + bb_ok) * 70 / 100))
traefik_entrypoint_request_duration_seconds_bucket{code="200",entrypoint="websecure",method="GET",protocol="http",le="0.3"} $(((ok_cnt + bb_ok) * 90 / 100))
traefik_entrypoint_request_duration_seconds_bucket{code="200",entrypoint="websecure",method="GET",protocol="http",le="1.2"} $(((ok_cnt + bb_ok) * 98 / 100))
traefik_entrypoint_request_duration_seconds_bucket{code="200",entrypoint="websecure",method="GET",protocol="http",le="5"} $((ok_cnt + bb_ok))
traefik_entrypoint_request_duration_seconds_bucket{code="200",entrypoint="websecure",method="GET",protocol="http",le="+Inf"} $((ok_cnt + bb_ok))
traefik_entrypoint_request_duration_seconds_sum{code="200",entrypoint="websecure",method="GET",protocol="http"} $(((ok_cnt + bb_ok) / 8))
traefik_entrypoint_request_duration_seconds_count{code="200",entrypoint="websecure",method="GET",protocol="http"} $((ok_cnt + bb_ok))
# HELP traefik_open_connections How many open connections exist, by entryPoint and protocol
# TYPE traefik_open_connections gauge
traefik_open_connections{entrypoint="websecure",method="GET",protocol="http"} $((5 + t % 7))
traefik_open_connections{entrypoint="web",method="GET",protocol="http"} 1
traefik_open_connections{entrypoint="metricas",method="GET",protocol="http"} 1
# HELP traefik_config_reloads_total Config reloads
# TYPE traefik_config_reloads_total counter
traefik_config_reloads_total 4
FIM
}

gerar_node() { # agora t
  agora="$1" t="$2"
  boot=$((INICIO - 864000))
  gib=1073741824
  cat <<FIM
# HELP node_uname_info Labeled system information as provided by the uname system call.
# TYPE node_uname_info gauge
node_uname_info{domainname="(none)",machine="x86_64",nodename="vps-smoke",release="6.8.0-smoke",sysname="Linux",version="#1 SMP"} 1
# HELP node_boot_time_seconds Node boot time, in unixtime.
# TYPE node_boot_time_seconds gauge
node_boot_time_seconds $boot
# HELP node_time_seconds System time in seconds since epoch (1970).
# TYPE node_time_seconds gauge
node_time_seconds $agora
# HELP node_load1 1m load average.
# TYPE node_load1 gauge
node_load1 0.42
# HELP node_load5 5m load average.
# TYPE node_load5 gauge
node_load5 0.35
# HELP node_load15 15m load average.
# TYPE node_load15 gauge
node_load15 0.30
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
FIM
  # 2 vCPUs, ~20% ocupadas: a cada segundo, 0.75 idle, 0.15 user, 0.06 system, 0.04 iowait.
  for c in 0 1; do
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"idle\"} $((800000 + t * 75 / 100))"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"user\"} $((150000 + t * 15 / 100))"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"system\"} $((60000 + t * 6 / 100))"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"iowait\"} $((40000 + t * 4 / 100))"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"irq\"} 0"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"softirq\"} 900"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"steal\"} 300"
    echo "node_cpu_seconds_total{cpu=\"$c\",mode=\"nice\"} 10"
  done
  cat <<FIM
# HELP node_memory_MemTotal_bytes Memory information field MemTotal_bytes.
# TYPE node_memory_MemTotal_bytes gauge
node_memory_MemTotal_bytes 3972005888
# HELP node_memory_MemAvailable_bytes Memory information field MemAvailable_bytes.
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 1986002944
# HELP node_memory_MemFree_bytes Memory information field MemFree_bytes.
# TYPE node_memory_MemFree_bytes gauge
node_memory_MemFree_bytes 524288000
# HELP node_memory_Buffers_bytes Memory information field Buffers_bytes.
# TYPE node_memory_Buffers_bytes gauge
node_memory_Buffers_bytes 104857600
# HELP node_memory_Cached_bytes Memory information field Cached_bytes.
# TYPE node_memory_Cached_bytes gauge
node_memory_Cached_bytes 1258291200
# HELP node_memory_SwapTotal_bytes Memory information field SwapTotal_bytes.
# TYPE node_memory_SwapTotal_bytes gauge
node_memory_SwapTotal_bytes $((2 * gib))
# HELP node_memory_SwapFree_bytes Memory information field SwapFree_bytes.
# TYPE node_memory_SwapFree_bytes gauge
node_memory_SwapFree_bytes $((2 * gib - 104857600))
# HELP node_filesystem_size_bytes Filesystem size in bytes.
# TYPE node_filesystem_size_bytes gauge
node_filesystem_size_bytes{device="/dev/sda1",fstype="ext4",mountpoint="/"} $((80 * gib))
# HELP node_filesystem_avail_bytes Filesystem space available to non-root users in bytes.
# TYPE node_filesystem_avail_bytes gauge
node_filesystem_avail_bytes{device="/dev/sda1",fstype="ext4",mountpoint="/"} $((32 * gib))
# HELP node_filesystem_free_bytes Filesystem free space in bytes.
# TYPE node_filesystem_free_bytes gauge
node_filesystem_free_bytes{device="/dev/sda1",fstype="ext4",mountpoint="/"} $((36 * gib))
# HELP node_filesystem_readonly Filesystem read-only status.
# TYPE node_filesystem_readonly gauge
node_filesystem_readonly{device="/dev/sda1",fstype="ext4",mountpoint="/"} 0
# HELP node_filesystem_files Filesystem total file nodes.
# TYPE node_filesystem_files gauge
node_filesystem_files{device="/dev/sda1",fstype="ext4",mountpoint="/"} 5242880
# HELP node_filesystem_files_free Filesystem total free file nodes.
# TYPE node_filesystem_files_free gauge
node_filesystem_files_free{device="/dev/sda1",fstype="ext4",mountpoint="/"} 4718592
# HELP node_network_receive_bytes_total Network device statistic receive_bytes.
# TYPE node_network_receive_bytes_total counter
node_network_receive_bytes_total{device="eth0"} $((900000000 + 250000 * t))
# HELP node_network_transmit_bytes_total Network device statistic transmit_bytes.
# TYPE node_network_transmit_bytes_total counter
node_network_transmit_bytes_total{device="eth0"} $((2500000000 + 600000 * t))
# HELP node_disk_read_bytes_total The total number of bytes read successfully.
# TYPE node_disk_read_bytes_total counter
node_disk_read_bytes_total{device="sda"} $((400000000 + 50000 * t))
# HELP node_disk_written_bytes_total The total number of bytes written successfully.
# TYPE node_disk_written_bytes_total counter
node_disk_written_bytes_total{device="sda"} $((700000000 + 120000 * t))
# HELP node_disk_io_time_seconds_total Total seconds spent doing I/Os.
# TYPE node_disk_io_time_seconds_total counter
node_disk_io_time_seconds_total{device="sda"} $((3000 + t / 50))
FIM
}

gerar() {
  agora="$(date +%s)"
  t=$((agora - INICIO))
  gerar_traefik "$agora" "$t" >"$PASTA/traefik.prom.tmp"
  mv "$PASTA/traefik.prom.tmp" "$PASTA/traefik.prom"
  gerar_node "$agora" "$t" >"$PASTA/node.prom.tmp"
  mv "$PASTA/node.prom.tmp" "$PASTA/node.prom"
}

# Só gera e sai (útil para conferir a saída com o promtool).
if [ "${1:-}" = "--uma-vez" ]; then
  gerar
  cat "$PASTA/${2:-traefik}.prom"
  exit 0
fi

gerar
(while sleep 5; do gerar; done) &
exec nginx -g 'daemon off;'
