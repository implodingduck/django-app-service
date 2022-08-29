#!/bin/bash
echo "-====-"
echo "Migrating DB..."
python manage.py migrate
echo "Migration done..."
echo "-====-"
echo "Starting gunicorn..."
gunicorn --bind=0.0.0.0 --timeout 600 mysite.wsgi