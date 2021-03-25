#!/bin/bash
if [ -n "${POSTGRES_PASSWORD:-}" ]; then
  export DATABASE_URL="psql://postgres:${POSTGRES_PASSWORD}@db:5432/postgres"
fi

sleep 30

# DEBUG set in .env
if [ ${DEBUG:-0} = 1 ]; then
    log_level="debug"
else
    log_level="info"
fi

sleep 10
echo "==> $(date +%H:%M:%S) ==> Running Celery beat <=="
exec celery -A safe_transaction_service.taskapp beat -S django_celery_beat.schedulers:DatabaseScheduler --loglevel $log_level
