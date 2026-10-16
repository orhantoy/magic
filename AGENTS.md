# Agent instructions

## Local setup

This repository uses mise to select the Ruby version declared in `mise.toml`.
Run all Ruby commands through `mise exec` so they also work in non-interactive
agent shells:

```sh
mise install
mise exec -- gem install bundler -v 2.7.2
mise exec -- bundle _2.7.2_ install
```

## Run the app

```sh
mise exec -- bundle _2.7.2_ exec puma --port 9393
```

The app is available at <http://localhost:9393/>.

## Verify the app

There is no automated test suite. After starting Puma, verify the root endpoint:

```sh
curl --fail --silent --show-error http://127.0.0.1:9393/ >/dev/null
```
