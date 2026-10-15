# Security

This repository holds configuration and procedures. It must never hold a
secret.

## Rules

1. **No secret is ever committed.** Not an API key, a token, a password, a
   cookie, a private key or a cloud credential.
2. **No secret is ever applied to `$HOME`.** chezmoi manages configuration,
   not secrets. A secret in a dotfile is a secret in Git.
3. **No real `.env` is ever read** by the scripts or by the agents.
4. **No AI provider token is configured** by this repository. The provider is
   authenticated with `opencode auth login`, which stores credentials outside
   the configuration.

## Files that must never be committed

`.gitignore` blocks these, and `scripts/validate-repository.sh` fails if any of
them is tracked:

| Pattern                | Examples                                  |
| ---------------------- | ----------------------------------------- |
| `.env`, `.env.*`       | `.env`, `.env.production`, `.env.local`   |
| `*.pem`, `*.key`       | private keys, certificates                |
| `*.p12`, `*.pfx`, `*.jks` | keystores                              |
| `id_rsa`, `id_ed25519` | SSH private keys                          |
| `credentials*`         | credential stores                         |
| `secrets*`             | secret directories and files              |
| `token*`               | token files                                |
| `auth.json`            | OAuth credentials                          |
| `kubeconfig`           | cluster credentials                        |
| `*.log`                | logs frequently contain tokens             |

Exceptions that are **intentionally tracked**:

- `.env.example`, `.env.*.example` — placeholders only
- `*.example`, `*.sample` — documentation samples

The exception exists only for examples. Every value in an example file must be
obviously fake.

## Placeholder rules

An example must be unusable by accident:

```dotenv
# Correct: obviously fake, obviously a placeholder.
DATABASE_URL=postgresql://user:password@localhost:5432/app
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
STRIPE_SECRET_KEY=sk_test_0000000000000000000000

# Wrong: a real-looking value invites being pasted somewhere real.
STRIPE_SECRET_KEY=sk_live_51H8xKzLkdIwHu7ix
```

## The local scanner

```bash
make validate
```

The scanner checks:

- high-confidence credential formats: AWS access key ids, GitHub tokens,
  GitLab tokens, OpenAI and Anthropic keys, Slack tokens, Google API keys,
  PEM private key headers, JWT-looking strings
- tracked filenames that look like secrets
- `.env.example` files are allowed; real `.env` files are not

**It is a heuristic, not a guarantee.** It finds what matches a pattern. It
cannot find a credential encoded, split across lines, or named something
unusual. A clean scan is not a clean repository. Read the diff.

To run only that check:

```bash
./scripts/validate-repository.sh --only secrets
```

CI runs it on every pull request.

## Where secrets belong

| Secret kind           | Where it lives                                        |
| --------------------- | ----------------------------------------------------- |
| API keys              | a password manager, exported as an environment variable |
| AI provider tokens    | `opencode auth login`, never in `opencode.jsonc`        |
| Cloud credentials     | `aws configure`, `az login`, `gcloud auth`, each with its own credential file |
| Database passwords    | a `.env` that is git-ignored, or a secret manager       |
| SSH private keys      | `~/.ssh/`, permissions `0600`, never in this repository |
| GitHub tokens         | `gh auth login`, stored by GitHub CLI                   |

Reference a secret from configuration with an environment substitution, never
with a literal:

```jsonc
{ "headers": { "Authorization": "Bearer {env:API_TOKEN}" } }
```

## SSH keys

```bash
# A dedicated key for automation, never a reused personal key.
ssh-keygen -t ed25519 -C "dev-environment-chezmoi" -f ~/.ssh/chezmoi_deploy_key

# Register the public key as a deploy key on the repository, read only.
# Read the public half.
cat ~/.ssh/chezmoi_deploy_key.pub

# Trust the host key to avoid an interactive prompt.
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

Never commit `id_rsa`, `id_ed25519` or any `.pub` key that belongs to a
personal account. `.gitignore` blocks them.

## `.env` files

- The scripts never read a real `.env`. `scripts/validate-repository.sh` only
  inspects tracked filenames.
- `bootstrap.sh` never sources a `.env`.
- chezmoi's `.chezmoiignore` excludes `**/.env` and `**/.env.*` from the
  managed state, so `chezmoi add $HOME` cannot sweep one in.
- The OpenCode configuration asks before reading a `.env` file and denies
  `~/.ssh`, `~/.aws` and `~/.netrc` outright.
- Commit only `.env.example`.

## AI provider tokens

This repository does not configure a provider.

```bash
# Authenticate interactively. Credentials go where OpenCode keeps them,
# not into a file in this repository.
opencode auth login

# Confirm what is authenticated.
opencode auth list
```

`opencode.jsonc` contains no `model`, no `providers` and no credentials. If a
future change needs a value from an environment variable, use `{env:NAME}` and
never a literal.

## Agent permissions as a security control

The permissions in `opencode.jsonc` are a guardrail, not a sandbox. They
reduce accidents; they do not contain an adversary.

What is denied outright:

- `rm -rf`, `sudo`, `mkfs`
- `git push --force`, `git reset --hard`, `git clean -fdx`
- reading `~/.ssh`, `~/.aws`, `~/.netrc`
- reading `.env`, `.env.*`, `*.pem`, `*.key` without confirmation

What requires confirmation:

- `git push`, `git commit`, `git rebase`
- `terraform apply`, `terraform destroy`
- `docker push`, `docker system prune`
- `npm publish`, `pnpm publish`
- `gh pr merge`, `gh release`
- piping a download into a shell

Project-level configuration can refine these rules, so treat them as a strong
default rather than a guarantee.

## Docker

`scripts/install-docker.sh` uses the official convenience script from
`https://get.docker.com` over TLS, after an explicit confirmation.

Before running it on a sensitive machine, review it:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://get.docker.com -o /tmp/get-docker.sh
less /tmp/get-docker.sh
```

Adding a user to the `docker` group is equivalent to granting root. The script
asks for confirmation and explains the consequence.

## Supply chain

Third-party installers are fetched over HTTPS with TLS 1.2 forced:

```bash
curl --proto '=https' --tlsv1.2 -fsSL ...
```

Installers are downloaded to a temporary file and removed afterwards. Nothing
in this repository pipes a download straight into a shell except
`install-development-tools.sh` for starship, and it warns first.

Before adding a dependency:

- confirm the package name, to avoid typosquatting
- prefer the official registry
- say in one sentence why the standard library and the existing dependencies
  are insufficient

## Responding to accidental exposure

Assume a committed secret is compromised. Rotating is the only real fix;
deleting the commit is not.

1. **Stop the bleeding first.** Revoke or rotate the credential immediately:
   - GitHub token: *Settings -> Developer settings -> Personal access tokens*
   - AWS key: deactivate in IAM, then create a new one
   - Database password: change it, then update every consumer
   - SSH key: remove the public key from every host and account

2. **Remove it from the repository.**

   ```bash
   git filter-repo --invert-paths --path path/to/secret.txt
   # or, for a single file that was never meant to exist:
   git rm --cached path/to/secret.txt
   ```

3. **Force-push the rewritten history** to every branch and tag, and ask every
   collaborator to re-clone. Do this only with Luis's confirmation; it rewrites
   shared history.

4. **Verify removal.**

   ```bash
   ./scripts/validate-repository.sh --only secrets
   git log --all --full-history -- path/to/secret.txt
   ```

5. **Check for misuse.** Review access logs for the window the credential was
   valid.

6. **Add a guard.** If the value had a recognisable shape, add the pattern to
   `SECRET_PATTERNS` in `scripts/validate-repository.sh`.

## What is never done here

- No secret is read, even to check whether one exists in a specific file.
- No `git push` is performed automatically.
- No credential is verified against a live service.
- No security control is disabled to make something work.