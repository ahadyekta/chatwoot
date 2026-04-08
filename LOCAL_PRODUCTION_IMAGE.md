# Local Production Image Workflow

This guide is for building and testing the local production Docker image for Chatwoot.

All commands below assume you are in:

```bash
cd /home/ahad/projects/knowtific/chatwoot-prod/chatwoot
```

## Files used

- `docker-compose.yaml`: normal development compose file
- `docker-compose.build-prod.yaml`: overrides used only to build the local production image
- `docker-compose.production.yaml`: production runtime stack
- `docker-compose.run-prod-local.yaml`: local overrides so the production stack uses `chatwoot:production`

## Required `.env` values

Make sure these values are present in `.env` before running the local production stack:

```env
NODE_ENV=production
RAILS_ENV=production
FRONTEND_URL=http://localhost:3000
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=
POSTGRES_DATABASE=chatwoot_production
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=
```

## 1. Build the production image

```bash
docker compose \
  -f docker-compose.yaml \
  -f docker-compose.build-prod.yaml \
  build base
```

This creates the local image:

```bash
chatwoot:production
```

## 1.1 Tag the image for Docker Hub

Example versioned tag:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:v2026-04-08-1
```

Optional `latest` tag:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:latest
```

## 1.2 Push the image to Docker Hub

Log in first:

```bash
docker login
```

Push the versioned tag:

```bash
docker push ahadyekta/chatwoot:v2026-04-08-1
```

If you also tagged `latest`, push that too:

```bash
docker push ahadyekta/chatwoot:latest
```

## 2. Start Postgres

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  up -d postgres
```

## 3. Prepare the production database

Run this the first time, and again after schema changes:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  run --rm rails bundle exec rails db:chatwoot_prepare
```

If you want sample or initial data, run:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  run --rm rails bundle exec rails db:seed
```

## 4. Start the production app locally

Bring up Redis, Rails, and Sidekiq:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  up redis rails sidekiq
```

Open the app at:

```text
http://localhost:3000
```

## 5. View logs

Follow all logs:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  logs -f
```

Follow only Rails logs:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  logs -f rails
```

Follow only Sidekiq logs:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  logs -f sidekiq
```

## 6. Open a shell in the production container

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  run --rm rails sh
```

Open a Rails console:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  run --rm rails bundle exec rails console
```

## 7. Stop the local production stack

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  down
```

## 8. Stop and remove volumes

Use this when you want a fully clean local production reset:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-local.yaml \
  down -v
```

## 9. Rebuild after Dockerfile or Gem changes

```bash
docker compose \
  -f docker-compose.yaml \
  -f docker-compose.build-prod.yaml \
  build --no-cache base
```

Then start again with the runtime commands above.

## 10. Push a new image after rebuilding

Re-tag the rebuilt image:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:v2026-04-08-2
```

Push it:

```bash
docker push ahadyekta/chatwoot:v2026-04-08-2
```

## 11. Deploy the pushed image on a VPS

This repo includes a VPS runtime override file:

```text
docker-compose.run-prod-vps.yaml
```

It points the production stack to:

```text
ahadyekta/chatwoot:production
```

On the VPS, place these files together:

- `docker-compose.production.yaml`
- `docker-compose.run-prod-vps.yaml`
- `.env`

Pull the image:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  pull
```

Prepare the database:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  run --rm rails bundle exec rails db:chatwoot_prepare
```

Start the production stack:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  up -d
```

View logs:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  logs -f
```

## 12. Update the image when Chatwoot has a new release

This repo is expected to rely on `master`.
The normal flow is:

- merge your feature work into local `master`
- rebase local `master` on top of `upstream/master`
- push the updated `master` branch to `origin/master`

If `upstream` is not configured yet, add it once:

```bash
git remote add upstream https://github.com/chatwoot/chatwoot.git
git fetch upstream
```

If your work is currently on a feature branch, merge it back to `master` first:

```bash
git checkout master
git pull --ff-only origin master
git merge knowtific-labels
git push origin master
```

Update `master` from the latest Chatwoot release branch:

```bash
git checkout master
git pull --ff-only origin master
git fetch upstream
git rebase upstream/master
git push origin master
```

If you have uncommitted changes, commit or stash them before rebasing.

Rebuild the production image:

```bash
docker compose \
  -f docker-compose.yaml \
  -f docker-compose.build-prod.yaml \
  build base
```

Tag the new image:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:v2026-04-08-2
```

Push it to Docker Hub:

```bash
docker push ahadyekta/chatwoot:v2026-04-08-2
```

If you are also using the `production` tag, retag and push it:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:production
docker push ahadyekta/chatwoot:production
```

On the VPS, pull the updated image:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  pull
```

Run database preparation for the new release:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  run --rm rails bundle exec rails db:chatwoot_prepare
```

Restart the stack with the new image:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  up -d
```

Check logs after the rollout:

```bash
docker compose \
  -f docker-compose.production.yaml \
  -f docker-compose.run-prod-vps.yaml \
  logs -f
```

## Quick command sets

Build image:

```bash
docker compose -f docker-compose.yaml -f docker-compose.build-prod.yaml build base
```

Tag image:

```bash
docker tag chatwoot:production ahadyekta/chatwoot:v2026-04-08-1
```

Push image:

```bash
docker push ahadyekta/chatwoot:v2026-04-08-1
```

Pull image on VPS:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml pull
```

Prepare DB on VPS:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml run --rm rails bundle exec rails db:chatwoot_prepare
```

Start app on VPS:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml up -d
```

Update VPS after a new release:

```bash
docker compose -f docker-compose.yaml -f docker-compose.build-prod.yaml build base
docker tag chatwoot:production ahadyekta/chatwoot:v2026-04-08-2
docker push ahadyekta/chatwoot:v2026-04-08-2
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml pull
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml run --rm rails bundle exec rails db:chatwoot_prepare
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-vps.yaml up -d
```

Bring up local production dependencies:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-local.yaml up -d postgres
```

Prepare DB:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-local.yaml run --rm rails bundle exec rails db:chatwoot_prepare
```

Start app:

```bash
docker compose -f docker-compose.production.yaml -f docker-compose.run-prod-local.yaml up redis rails sidekiq
```
