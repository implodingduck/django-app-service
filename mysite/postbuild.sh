#!/bin/bash
echo "Perform database migration..."
python manage.py migrate
echo "Finished database migration..."