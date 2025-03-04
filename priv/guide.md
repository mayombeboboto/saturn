# Export Env Variables

```bash
export POOL_SIZE=2
export PORT=4001
export PHX_HOST=localhost
export PHX_SERVER=true
export DATABASE_URL=ecto://postgres:postgres@localhost/saturn_dev
export SECRET_KEY_BASE=$(mix phx.gen.secret)
```

# Build in Prod Mode

## Compile the Elixir code

```
$ mix deps.get --only prod

Resolving Hex dependencies...
Resolution completed in 0.18s
Unchanged:
  bandit 1.6.7
  castore 1.0.11
  ...

$ MIX_ENV=prod mix compile

==> decimal
Compiling 4 files (.ex)
Generated decimal app
...
```

## Compile the web assets

If the project has JS, CSS or other assets you can also compile them with the `esbuild` wrapper that phoenix now uses:

```
$ MIX_ENV=prod mix assets.deploy

Rebuilding...

Done in 593ms.

  ../priv/static/assets/app.js  120.4kb

⚡ Done in 22ms
Check your digested files at "priv/static"
```

## Start project in prod mode

```
$ MIX_ENV=prod mix phx.server
```

# Generate an Elixir Release

```
$ MIX_ENV=prod mix release
```

# Migrations support

There is one more thing before finishing. Right now we are using a database that was created by a
mix ecto.create command. But the release we just generated has no support for running mix in
production. There is no mix command anywhere inside the \_build/prod/rel folder. So how are we
going to run the database migrations? Good question. We need a workaround that is included in the
application itself.

```elixir
defmodule Saturn.Release do
  alias Ecto.Migrator
  @app :saturn

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _, _} =
      Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)
end
```

```postgres
postgres=# CREATE DATABASE saturn_prod;
```

```bash
$ MIX_ENV=prod mix release
* assembling saturn-0.1.0 on MIX_ENV=prod
* using config/runtime.exs to configure the release at runtime

$ export PORT=4001
$ export POOL_SIZE=2
$ export PHX_SERVER=true
$ export PHX_HOST=localhost
$ export SECRET_KEY_BASE=$(mix phx.gen.secret)
$ export DATABASE_URL=ecto://postgres:postgres@localhost/saturn_prod

$ _build/prod/rel/saturn/bin/saturn eval "Saturn.Release.migrate"
14:06:32.594 [info] Migrations already up

$ _build/prod/rel/saturn/bin/saturn start
14:10:26.417 [info] Running SaturnWeb.Endpoint with Bandit 1.6.7 at :::4001 (http)
14:10:26.423 [info] Access SaturnWeb.Endpoint at https://localhost
```

## Docker image stage for running the release

`mix phx.gen.release --docker` generates both `Dockerfile` and `.dockerignore`.

```bash
$ mix phx.gen.release --docker
* creating rel/overlays/bin/server
* creating rel/overlays/bin/server.bat
* creating rel/overlays/bin/migrate
* creating rel/overlays/bin/migrate.bat
* creating lib/saturn/release.ex
lib/saturn/release.ex already exists, overwrite? [Yn] y
...

$ docker image build -t devboboto/saturn:0.1.0 .
$ docker image list
REPOSITORY          TAG     IMAGE ID       CREATED         SIZE
devboboto/saturn    latest  e269c9bc32f8   7 minutes ago   194MB
```

## Run the Docker container

Let's start a docker container for
PostgreSQL and a docker container for our Elixir/Phoenix app. And connect them using a virtual
network. Then run the migrations from the elixir app container.

```sh
$ docker network create saturn-network
```

Get a postgres docker image and boot it up binding it up to the virtual network we just created:

```sh
$ docker container run -d --network saturn-network --network-alias postgres-server -e \
    POSTGRES_PASSWORD=supersecret postgres

$ docker container exec -it CONTAINER_ID/NAME psql -U postgres
```

```sql
postgres=# CREATE DATABASE saturn_prod;
CREATE DATABASE

postres=# \q
```

Export `DATABASE_URL` environment variable.

```sh
$ export DATABASE_URL=ecto://postgres:supersecret@postgres-server/saturn_prod
```

```sh
$ docker container run -dp $PORT:$PORT -e POOL_SIZE -e PORT -e DATABASE_URL -e \
    SECRET_KEY_BASE --network saturn-network --name saturn devboboto/saturn:0.1.0

45c9484561d6a5574a466ba33c5e28f2a6b6a86af63096555d063dddb69b2d3e

$ docker container exec -it saturn bin/saturn eval "Saturn.Release.migrate"
13:39:00.980 [info] Migrations already up
```
