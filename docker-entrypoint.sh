#!/bin/sh
#set -e

dns_wait_hosts="${DNS_WAIT_HOSTS:-discord.com www.twitch.tv}"
dns_wait_timeout="${DNS_WAIT_TIMEOUT:-60}"
dns_wait_interval="${DNS_WAIT_INTERVAL:-3}"

if [ "$dns_wait_timeout" -gt 0 ]; then
    echo "Waiting for DNS resolution before starting JMusicBot..."
    elapsed=0
    while :; do
        all_resolved=1
        for host in $dns_wait_hosts; do
            if ! getent hosts "$host" >/dev/null 2>&1; then
                all_resolved=0
                break
            fi
        done

        if [ "$all_resolved" -eq 1 ]; then
            break
        fi

        if [ "$elapsed" -ge "$dns_wait_timeout" ]; then
            echo "DNS wait timed out after ${dns_wait_timeout}s; starting JMusicBot anyway."
            break
        fi

        sleep "$dns_wait_interval"
        elapsed=$((elapsed + dns_wait_interval))
    done
fi

# Check if the config directory is empty
if [ -z "$(ls -A /jmb/config)" ]; then
    echo "Config directory is empty. Copying default config..."
    cp /jmb/reference/config.txt /jmb/config/config.txt
fi

chmod -R 755 /jmb/config && chown -R 10000:10001 /jmb/config

exec su-exec appuser java -jar -Dnogui=true /jmb/JMusicBot.jar
