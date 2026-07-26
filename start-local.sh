#!/bin/sh
# Start Apache Airflow 3.x locally for side-by-side comparison with airflow-nodejs.
#
# Usage:
#   ./start-local.sh           # start everything
#   ./start-local.sh stop      # stop without removing data
#   ./start-local.sh reset     # stop + wipe all data (fresh start)
#   ./start-local.sh logs      # tail all service logs
#
#   AIRFLOW_PORT=8081 ./start-local.sh    # use different port (default: 8080)
#   AIRFLOW_PLATFORM=linux/amd64 ./start-local.sh   # force x86 image
#
set -e

COMPOSE="docker-compose -f docker-compose.local.yml"

case "${1:-start}" in
  stop)
    echo "==> Stopping Airflow..."
    $COMPOSE stop
    echo "✓ Stopped (data preserved). Run './start-local.sh' to restart."
    exit 0 ;;

  reset)
    echo "==> Stopping and wiping all Airflow data..."
    $COMPOSE down -v --remove-orphans
    echo "✓ Reset complete. Run './start-local.sh' for a fresh start."
    exit 0 ;;

  logs)
    $COMPOSE logs -f --tail=50
    exit 0 ;;

  start) ;;
  *)
    echo "Usage: $0 [start|stop|reset|logs]" >&2; exit 1 ;;
esac

# ── Pre-pull check ─────────────────────────────────────────────────────────
IMAGE="${AIRFLOW_IMAGE:-generic.ci.artifacts.walmart.com/hub-docker-release-remote/apache/airflow:3.0.0}"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Pulling Airflow image (first run — may take a few minutes)..."
  docker pull "$IMAGE"
fi

# ── Init DB on first run ──────────────────────────────────────────────────
DB_VOLUME="$(basename $(pwd))_airflow-db"
if ! docker volume inspect "$DB_VOLUME" >/dev/null 2>&1; then
  echo "==> First run: initialising database and creating admin user..."
  $COMPOSE run --rm airflow-init
fi

# ── Start services ────────────────────────────────────────────────────────
echo "==> Starting Airflow services..."
$COMPOSE up -d airflow-apiserver airflow-scheduler airflow-dag-processor

PORT="${AIRFLOW_PORT:-8080}"
echo ""
echo "✓ Apache Airflow is starting up!"
echo ""
echo "  API Server:  http://localhost:$PORT"
echo "  Login:       airflow / airflow"
echo "  API Docs:    http://localhost:$PORT/api/v2/openapi.json"
echo "  Health:      http://localhost:$PORT/api/v2/monitor/health"
echo ""
echo "  airflow-nodejs runs on: http://localhost:3000"
echo ""
echo "Commands:"
echo "  ./start-local.sh logs    — tail logs"
echo "  ./start-local.sh stop    — stop without losing data"
echo "  ./start-local.sh reset   — wipe data and start fresh"
echo ""
echo "Waiting for API server to be ready..."
for i in $(seq 1 24); do
  if curl -s -f "http://localhost:$PORT/api/v2/monitor/health" >/dev/null 2>&1; then
    echo "✓ Ready at http://localhost:$PORT"
    break
  fi
  printf "."
  sleep 5
done
