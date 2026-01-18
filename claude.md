# Postfacto - Claude Code Guide

## Project Overview

Postfacto is a free, open-source, self-hosted retrospective collaboration tool designed for distributed teams to run agile retrospectives remotely. It enables team members to share feedback, vote on topics, and track action items in real-time.

**License**: GNU Affero General Public License (AGPL-3.0)

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Backend** | Ruby on Rails | 8.x |
| **Frontend** | Hotwire (Turbo + Stimulus) | 8.x |
| **Styling** | Tailwind CSS | 4.x |
| **Language** | Ruby | 3.3.6 |
| **Database** | SQLite (dev), PostgreSQL (prod) | - |
| **Test Framework** | RSpec | 8.x |
| **Admin Dashboard** | ActiveAdmin | 2.9+ |
| **Real-time** | ActionCable + Turbo Streams | - |

## Project Structure

```
/postfacto/
├── api/                          # Rails application (port 4000)
│   ├── app/
│   │   ├── admin/               # ActiveAdmin dashboard
│   │   ├── controllers/
│   │   │   └── hotwire/         # Hotwire controllers
│   │   ├── models/              # Domain models (Retro, Item, ActionItem, User)
│   │   ├── channels/            # ActionCable WebSocket handlers
│   │   ├── views/
│   │   │   ├── hotwire/         # Hotwire ERB views
│   │   │   └── layouts/         # Layout templates
│   │   └── domain/              # Business logic
│   ├── config/                  # Rails configuration
│   ├── db/                      # Migrations & seeds
│   └── spec/                    # RSpec tests
│
├── mock-google-server/          # Mock OAuth for development
└── docker/                      # Docker configurations
```

## Key Files

- `api/app/models/retro.rb` - Main retrospective model
- `api/app/models/item.rb` - Feedback items (happy/meh/sad)
- `api/app/models/action_item.rb` - Action items to track
- `api/config/routes.rb` - Routes configuration
- `api/app/views/hotwire/` - Hotwire ERB views
- `api/app/controllers/hotwire/` - Hotwire controllers
- `.tool-versions` - Ruby and Node version pinning

## Running the Project

### Prerequisites

```bash
# Install mise (or asdf) for version management
# Ruby 3.3.6 will be auto-installed
```

### Running the App

```bash
# Install dependencies
./deps.sh

# Run the application
./run.sh

# App available at http://localhost:4000
```

### Running Tests

```bash
cd api
RAILS_ENV=test bundle exec rake db:create db:migrate
RAILS_ENV=test bundle exec rake
```

Or use the test script:
```bash
./test.sh
```

## Important Implementation Details

### Hotwire Architecture

The application uses Hotwire (Turbo + Stimulus) for the frontend:

1. **Turbo Drive** - Accelerates page navigation
2. **Turbo Frames** - Enables partial page updates
3. **Turbo Streams** - Real-time updates via ActionCable
4. **Stimulus** - Lightweight JavaScript for interactions

### Real-time Updates

Models broadcast changes via Turbo Streams:
```ruby
# In Item model
broadcasts_to :retro, inserts_by: :prepend, target: ->(item) { "#{item.category}-items" }
```

### Rails 8.x Migration Notes

1. **Enum Syntax**: Rails 7+ requires positional argument syntax:
   ```ruby
   enum :category, { happy: 'happy', meh: 'meh', sad: 'sad' }
   ```

2. **Ransack 4.x**: Requires explicit allowlisting for searchable attributes:
   ```ruby
   def self.ransackable_attributes(_auth_object = nil)
     %w[id name ...]
   end
   ```

## Database Schema

Key models:
- **Retro**: Retrospective board with slug, password, video_link
- **Item**: Feedback items with category (happy/meh/sad), vote_count
- **ActionItem**: Action items with done status
- **User**: Retro participants
- **Archive**: Historical retro data

## Routes

All routes are Hotwire-based (ERB views with Turbo Streams):
- `GET /` - List retros
- `GET /retros/:slug` - Show retro
- `POST /retros/:retro_id/items` - Create item (Turbo Stream response)
- `POST /retros/:retro_id/items/:id/vote` - Vote on item
- `PATCH /retros/:retro_id/items/:id/done` - Mark item done

## Common Tasks

### Adding a new migration
```bash
cd api
bundle exec rails generate migration AddFieldToModel field:type
RAILS_ENV=development bundle exec rake db:migrate
RAILS_ENV=test bundle exec rake db:migrate
```

### Running specific tests
```bash
cd api && RAILS_ENV=test bundle exec rspec spec/path/to/spec.rb
```

## Deployment

Single-stage Docker build via the root `Dockerfile`. No frontend build step required.

```bash
docker build -t postfacto .
docker run -p 4000:4000 -e DATABASE_URL=postgres://... postfacto
```
