# SOP: ElemBio Cloud API key setup and run status check

Oct 19, 2026 · @SchistoDan (Dan Parsons)

## Purpose
This SOP stores an ElemBio Cloud API key securely on the NHM HPC so it loads on every login, then lists recent AVITI runs with their status and headline metrics in one command. The one-time setup takes about 5 minutes.

## Prerequisites
- An HPC account with a bash login shell.
- An ElemBio Cloud API key, created in the ElemBio Cloud console under account settings. It needs at least the `runs` (or `runs:read`) scope. Grant only the scopes you need.
- `jq` on your `PATH`. If it is missing, run `conda install -c conda-forge jq` in any conda environment.

## One-time setup
The key lives in a private file that only you can read, and `~/.bashrc` loads it at login. Never paste the key directly into `~/.bashrc`.

1. Create a private directory called `.secrets/`:
```bash
mkdir -p ~/.secrets && chmod 700 ~/.secrets
```

2. Enter the key when prompted with `ElemBio API key: ` without it appearing on screen or in shell history.
```bash
read -rs -p "ElemBio API key: " k; echo
```

3. Write the key to the secrets file, clear the variable and lock the file:
```bash
(umask 077; printf 'export ELEMBIO_API_KEY=%q\n' "$k" > ~/.secrets/elembio.env)
unset k
chmod 600 ~/.secrets/elembio.env
```

4. Add these lines to the end of `~/.bashrc`, which can be found in your `home/` directory:
```bash
# ElemBio Cloud API
export ELEMBIO_API_URL=https://cloud-api.usw2.elembio.io
[ -f ~/.secrets/elembio.env ] && source ~/.secrets/elembio.env
```

5. Log out, log back in, and verify with:
```bash
ls -l ~/.secrets/elembio.env          # expect -rw------- for the permissions string
echo "${ELEMBIO_API_KEY:0:4}"         # expect first 4 characters of API key
curl -sSf "$ELEMBIO_API_URL/v1/auth" -H "x-api-key: $ELEMBIO_API_KEY" | jq
```

> The last command should return your `tenantId` and the key's `scopes`.

## Checking recent runs
This command lists every run created in the last 30 days as an aligned table: name, status, start and completion times (UTC), total reads, %Q30 and run description.

```bash
curl -sSf --get "$ELEMBIO_API_URL/v1/runs" \
  --data-urlencode "filter=time_created>=30d" \
  -H "x-api-key: $ELEMBIO_API_KEY" \
  | jq -r '["NAME","STATUS","STARTED","COMPLETED","READS","Q30","DESCRIPTION"],
           (.runs[] | [.name, (.status|sub("RUN_STATUS_";"")),
            (.timeStarted // "-")[0:16], (.timeCompleted // "-")[0:16],
            (.metrics.sequencing.totalReads // "-"),
            (.metrics.sequencing.q30 // "-"), (.description // "-")]) | @tsv' \
  | column -t -s $'\t'
```

- **Change the window:** edit `30d` (for example `7d`, `100d` or `1mo`), or use a date such as `time_created>=2026-09-01`.
- **Spotting a live run:** a run in progress shows `-` under COMPLETED
- Results are capped at 100 runs per request. Add `--data-urlencode "pageSize=1000"` for longer windows.

## Troubleshooting and notes
See [Element Biosciences Cloud API URL](https://docs.elembio.io/developers/api/#description/introduction) for details on errors and additional commands.

A Getting Started guide on using the API can be found [here](https://docs.elembio.io/developers/api/getting-started/).
