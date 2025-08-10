#!/bin/bash
# Claude Webhook Service 관리 스크립트

SERVICE_NAME="claude-webhook"

case "$1" in
    start)
        echo "Starting $SERVICE_NAME service..."
        systemctl --user start $SERVICE_NAME
        ;;
    stop)
        echo "Stopping $SERVICE_NAME service..."
        systemctl --user stop $SERVICE_NAME
        ;;
    restart)
        echo "Restarting $SERVICE_NAME service..."
        systemctl --user restart $SERVICE_NAME
        ;;
    status)
        systemctl --user status $SERVICE_NAME
        ;;
    logs)
        echo "Showing logs for $SERVICE_NAME service..."
        journalctl --user -u $SERVICE_NAME -f
        ;;
    enable)
        echo "Enabling $SERVICE_NAME service for auto-start..."
        systemctl --user enable $SERVICE_NAME
        ;;
    disable)
        echo "Disabling $SERVICE_NAME service auto-start..."
        systemctl --user disable $SERVICE_NAME
        ;;
    health)
        echo "Checking service health..."
        curl -f http://localhost:3000/health || echo "Service is not responding"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable|health}"
        exit 1
        ;;
esac