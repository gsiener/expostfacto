#!/bin/bash
#
# Postfacto, a free, open-source and self-hosted retro tool aimed at helping
# remote teams.
#
# Copyright (C) 2016 - Present Pivotal Software, Inc.
#
# This program is free software: you can redistribute it and/or modify
#
# it under the terms of the GNU Affero General Public License as
#
# published by the Free Software Foundation, either version 3 of the
#
# License, or (at your option) any later version.
#
#
#
# This program is distributed in the hope that it will be useful,
#
# but WITHOUT ANY WARRANTY; without even the implied warranty of
#
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#
# GNU Affero General Public License for more details.
#
#
#
# You should have received a copy of the GNU Affero General Public License
#
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
set -e

export BASE_DIR="$(dirname "$0")"
export RAILS_ENV="development"

# Parse configuration

ADMIN_EMAIL="${ADMIN_EMAIL:-email@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-password}"

USE_MOCK_GOOGLE=false
if [[ " $* " == *' --no-auth '* ]]; then
  echo "Disabling login capability (create retros via admin interface)"
  GOOGLE_OAUTH_CLIENT_ID=""
elif [[ -n "$GOOGLE_OAUTH_CLIENT_ID" ]]; then
  echo "Using Google OAuth authentication"
else
  echo "Using mock Google authentication server"
  echo " - specify --no-auth to disable login"
  echo " - set GOOGLE_OAUTH_CLIENT_ID to use real Google OAuth"
  USE_MOCK_GOOGLE=true
fi

export USE_MOCK_GOOGLE
export GOOGLE_OAUTH_CLIENT_ID

# Migrate database and create Admin user

pushd "$BASE_DIR/api" >/dev/null
  echo "Migrating database..."
  bundle exec rake db:create db:migrate
  ADMIN_EMAIL="$ADMIN_EMAIL" ADMIN_PASSWORD="$ADMIN_PASSWORD" bundle exec rake admin:create_user
popd >/dev/null

echo ""
echo "Created admin user '$ADMIN_EMAIL' with password '$ADMIN_PASSWORD'"
echo "Log in to http://localhost:4000/admin to administer"
echo ""
echo "App available at http://localhost:4000/"
echo ""

# Start mock google server in background if needed

if [[ "$USE_MOCK_GOOGLE" == "true" ]]; then
  export GOOGLE_AUTH_ENDPOINT="http://localhost:3100/auth"
  npm --prefix="$BASE_DIR/mock-google-server" start &
  MOCK_PID=$!
  trap "kill $MOCK_PID 2>/dev/null" EXIT
fi

# Launch API server

cd "$BASE_DIR/api"
bundle exec rails server -b 0.0.0.0 -p 4000 -e "$RAILS_ENV"
