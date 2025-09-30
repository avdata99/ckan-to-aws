# Update tracking
echo "Updating CKAN core tracking"
LAST_MONTH=$(date -d '60 days ago' +'%Y-%m-%d')
ckan tracking update $LAST_MONTH
