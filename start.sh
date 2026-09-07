#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Always address Compose by file path so the project name (and therefore the
# volume name) stays the same no matter which directory we are standing in.
COMPOSE=(docker compose -f "$PROJECT_ROOT/docker-compose.yml")

echo "🚀 Starting KIRA-UI project..."

# --- 1. Check / install Poetry ---
if ! command -v poetry &> /dev/null; then
  echo "📥 Poetry not found. Installing it now..."
  curl -sSL https://install.python-poetry.org | python3 -

  # Add Poetry to PATH for this session (default install location)
  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v poetry &> /dev/null; then
    echo "❌ Poetry was installed but is not on your PATH."
    echo "   Add this to your shell config (~/.zshrc or ~/.bashrc) and restart your terminal:"
    echo '   export PATH="$HOME/.local/bin:$PATH"'
    exit 1
  fi
  echo "✅ Poetry installed successfully."
else
  echo "✅ Poetry already installed."
fi

# --- 2. Check Docker ---
if ! command -v docker &> /dev/null; then
  echo "❌ Docker is not installed."
  echo "   Download and install Docker Desktop: https://www.docker.com/products/docker-desktop/"
  exit 1
fi

if ! docker info &> /dev/null; then
  echo "❌ Docker is installed but not running. Open Docker Desktop and try again."
  exit 1
fi
echo "✅ Docker is running."

# --- 3. Create .env if missing ---
cd "$BACKEND_DIR"

ENV_WAS_GENERATED=false

if [ ! -f ".env" ]; then
  echo "📝 backend/.env not found. Generating one..."

  RANDOM_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | head -c 24)

  cat > .env <<EOF
POSTGRES_DB=kira_ui
POSTGRES_USER=kira_user
POSTGRES_PASSWORD=${RANDOM_PASSWORD}
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
EOF

  ENV_WAS_GENERATED=true
  echo "✅ backend/.env created with a randomly generated password."
else
  echo "✅ backend/.env already exists."
fi

# Read the credentials back so every later step uses the same source of truth
DB_NAME=$(grep '^POSTGRES_DB=' .env | cut -d '=' -f2-)
DB_USER=$(grep '^POSTGRES_USER=' .env | cut -d '=' -f2-)
DB_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d '=' -f2-)
DB_HOST=$(grep '^POSTGRES_HOST=' .env | cut -d '=' -f2-)
DB_PORT=$(grep '^POSTGRES_PORT=' .env | cut -d '=' -f2-)

# --- 4. Install project dependencies ---
echo "📦 Installing dependencies with Poetry..."
poetry install --no-root

# --- 5. Start the Postgres container ---
echo "🐳 Starting the Postgres container..."
"${COMPOSE[@]}" up -d --wait db
echo "✅ Database container is up."

# --- 6. Verify the credentials actually work ---
# Postgres only applies POSTGRES_USER/POSTGRES_PASSWORD when it initializes the
# data volume for the FIRST time. After that it ignores them, so a regenerated
# .env silently stops matching the database that is already in the volume.
#
# This check MUST run from the host, exactly the way Django connects. Probing
# from inside the container proves nothing: initdb writes a default pg_hba.conf
# containing
#     local all all           trust
#     host  all all 127.0.0.1/32 trust
# so "docker exec ... psql -h 127.0.0.1" is trusted and accepts ANY password.
# Connections from the host arrive through the Docker bridge instead, so they
# fall through to the appended "host all all all scram-sha-256" rule — the only
# rule that actually validates the password.
echo "🔐 Verifying database credentials..."

db_auth_ok() {
  DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_USER="$DB_USER" \
  DB_PASSWORD="$DB_PASSWORD" DB_NAME="$DB_NAME" \
  poetry run python -c '
import os, sys
import psycopg2
try:
    psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        dbname=os.environ["DB_NAME"],
        connect_timeout=5,
    ).close()
except Exception:
    sys.exit(1)
' &> /dev/null
}

if db_auth_ok; then
  echo "✅ Credentials OK."
else
  echo "⚠️  The password in backend/.env does not match the database."
  if [ "$ENV_WAS_GENERATED" = true ]; then
    echo "   (a new .env was just generated, but the Docker volume still holds"
    echo "    the database created by an earlier run)"
  fi
  echo "🔧 Trying to resync it on the existing database (no data loss)..."

  # The local unix socket is trusted, so we can log in without a password and
  # simply set the role's password to whatever .env currently says.
  # Double any single quote so the SQL string literal stays well-formed.
  ESCAPED_PASSWORD=${DB_PASSWORD//\'/\'\'}

  if docker exec kira-ui-db \
       psql -U "$DB_USER" -d "$DB_NAME" \
       -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$ESCAPED_PASSWORD';" &> /dev/null \
     && db_auth_ok; then
    echo "✅ Password resynced. Your data was preserved."
  else
    echo ""
    echo "❌ Could not resync — the role or database is missing from the volume."
    echo "   Recreating the volume is the way out, but ALL DATABASE DATA WILL BE LOST."
    echo ""
    read -r -p "   Reset the database volume now? [y/N] " RESET_ANSWER

    if [[ "$RESET_ANSWER" =~ ^[Yy]$ ]]; then
      echo "🧹 Removing the old volume and recreating the database..."
      "${COMPOSE[@]}" down -v
      "${COMPOSE[@]}" up -d --wait db

      if db_auth_ok; then
        echo "✅ Database recreated with the current credentials."
      else
        echo "❌ Still cannot authenticate. Check 'docker logs kira-ui-db'."
        exit 1
      fi
    else
      echo "❌ Aborted. Run 'docker compose down -v' when you are ready to reset."
      exit 1
    fi
  fi
fi

# --- 7. Run migrations ---
echo "🔧 Applying migrations..."
poetry run python manage.py migrate

# --- 8. Start the Django server ---
echo "🎉 Starting the Django server..."
poetry run python manage.py runserver
