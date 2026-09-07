#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

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

if [ ! -f ".env" ]; then
  echo "📝 backend/.env not found. Generating one..."

  RANDOM_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | head -c 24)

  cat > .env <<EOF
POSTGRES_DB=kira_ui
POSTGRES_USER=kira_user
POSTGRES_PASSWORD=${RANDOM_PASSWORD}
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
EOF

  echo "✅ backend/.env created with a randomly generated password."
else
  echo "✅ backend/.env already exists."
fi

# --- 4. Install project dependencies ---
echo "📦 Installing dependencies with Poetry..."
poetry install

# --- 5. Start the Postgres container ---
echo "🐳 Starting the Postgres container..."
cd "$PROJECT_ROOT"
docker compose up -d db

# --- 6. Wait for Postgres to be ready ---
echo "⏳ Waiting for the database to become available..."
DB_USER=$(grep POSTGRES_USER backend/.env | cut -d '=' -f2)
until docker exec kira-ui-db pg_isready -U "$DB_USER" &> /dev/null; do
  sleep 1
done
echo "✅ Database is ready!"

# --- 7. Run migrations ---
cd "$BACKEND_DIR"
echo "🔧 Applying migrations..."
poetry run python manage.py migrate

# --- 8. Start the Django server ---
echo "🎉 Starting the Django server..."
poetry run python manage.py runserver