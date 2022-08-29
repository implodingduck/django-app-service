#!/bin/bash

python manage migrate
gunicorn --bind=0.0.0.0 --timeout 600 mysite.wsgi