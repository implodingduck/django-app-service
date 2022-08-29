#!/bin/bash
echo "============================="
echo "Perform database migration..."
pip freeze
ls -lta /opt
ls -lta /opt/microsoft
ls -lta /opt/microsoft/msodbcsql17/lib64/
pip install pyodbc==4.0.34
ls -lta /opt
ls -lta /opt/microsoft
ls -lta /opt/microsoft/msodbcsql17/lib64/
python manage.py migrate
echo "Finished database migration..."
echo "============================="