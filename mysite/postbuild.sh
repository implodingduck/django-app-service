#!/bin/bash
echo "============================="
echo "Perform database migration..."
pip freeze
python manage.py migrate
echo "Finished database migration..."
echo "============================="