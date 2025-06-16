#!/bin/bash

echo "⏳ Menunggu Kafka siap..."
sleep 5

echo "🔧 Membuat topik-topik internal Kafka Connect..."
for topic in connect-configs connect-offsets connect-status; do
  kafka-topics --bootstrap-server kafka:9092 \
    --create --if-not-exists \
    --topic $topic \
    --replication-factor 1 \
    --partitions 1 \
    --config cleanup.policy=compact
done

echo "✅ Topik internal berhasil dibuat."
