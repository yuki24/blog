##
# Configuration options
##
BUCKET='s3://yukinishijima-blog/'
SITE_DIR='_site/'
 
##
# Color stuff
##
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2; tput bold)
YELLOW=$(tput setaf 3)

function red() {
  echo "$RED$*$NORMAL"
}

function green() {
  echo "$GREEN$*$NORMAL"
}

function yellow() {
  echo "$YELLOW$*$NORMAL"
}

##
# Actual script
##

red '--> Running Jekyll'
jekyll build
echo ''

yellow '--> Uploading css files'
s3cmd sync --exclude '*.*' --include '*.css' --add-header='Content-Type: text/css' --add-header='Cache-Control: max-age=604800' --acl-public --cf-invalidate --no-preserve --verbose $SITE_DIR $BUCKET
echo ''

yellow '--> Uploading js files'
s3cmd sync --exclude '*.*' --include '*.js' --add-header='Content-Type: application/javascript' --add-header='Cache-Control: max-age=604800' --acl-public --cf-invalidate --no-preserve --verbose $SITE_DIR $BUCKET
echo ''

# Sync media files first (Cache: expire in 10weeks)
yellow '--> Uploading images (jpg, png, ico)'
s3cmd sync --exclude '*.*' --include '*.png' --include '*.jpg' --include '*.ico' --add-header='Expires: Sat, 20 Nov 2020 18:46:39 GMT' --add-header='Cache-Control: max-age=6048000' --acl-public --cf-invalidate --no-preserve --verbose $SITE_DIR $BUCKET
echo ''

# Sync html files (Cache: 2 hours)
yellow '--> Uploading html files'
s3cmd sync --exclude '*.*' --include '*.html' --add-header='Content-Type: text/html' --add-header='Cache-Control: max-age=7200, must-revalidate' --acl-public --cf-invalidate --no-preserve --verbose $SITE_DIR $BUCKET
echo ''

# Sync everything else
yellow '--> Syncing everything else'
s3cmd sync --exclude '*.sh' --delete-removed --acl-public --cf-invalidate --no-preserve --verbose $SITE_DIR $BUCKET
