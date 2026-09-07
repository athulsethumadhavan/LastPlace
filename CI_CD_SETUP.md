# CI/CD setup for LastPlace

This document covers two things the GitHub Actions workflows in
`.github/workflows/` can't do on their own: repository *settings* that only
a human with admin access can configure, and the TestFlight secrets the
`deploy-testflight.yml` workflow needs before it can actually upload a
build.

## What the workflows already enforce

- **`ci-feature-to-dev.yml`** — runs on every pull request into `dev`.
  Blocks any PR whose source branch is `main`, runs the full test suite
  (`LastPlaceTests` + `LastPlaceUITests`), runs the Clang static analyzer,
  and deletes the source branch once the PR is merged.
- **`ci-dev-to-main.yml`** — runs on every pull request into `main`. Blocks
  any PR whose source branch is anything other than `dev`, and runs the
  full test suite again (a PR into `main` should never be trusted on the
  strength of its `dev` run alone, since `dev` may have moved since).
- **`deploy-testflight.yml`** — runs on every push to `main`, whichever way
  that push happened (a merged PR or an admin's direct push both fire it).
  Archives a Release build and uploads it to TestFlight, once the secrets
  below exist.

## Repository settings this project needs (can't be done from a workflow)

These live under the repo's **Settings** tab on GitHub, not in a YAML file,
so they need to be set up by hand once:

1. **Settings → General → Pull Requests → "Automatically delete head
   branches."** Turn this on. `ci-feature-to-dev.yml` also deletes the
   branch itself as a safety net, but this setting is the simpler, built-in
   way to get the same result and covers PRs merged before that workflow
   job runs.

2. **Settings → Branches → Branch protection rules.** Add a rule for
   `main`:
   - Require a pull request before merging.
   - Require status checks to pass before merging — select the `test` job
     from `ci-dev-to-main.yml` (and, once it's been added, the `guard-source-branch`
     job) as required checks.
   - **"Do not allow bypassing the above settings"** should be left
     **unchecked** for admins specifically — GitHub's branch protection has
     a separate "Restrict who can push to matching branches" section; leave
     admins out of that restriction (or enable "Allow specified actors to
     bypass required pull requests" for the admin account/team) so an admin
     can still push directly to `main` without opening a PR, per this
     project's rule that "main can be updated only from dev through a PR,
     but an admin may update it directly." Restrict who else can push so
     that only PRs from `dev` (enforced by `ci-dev-to-main.yml`'s guard job)
     and admin direct pushes are possible.

   Add a second rule for `dev`:
   - Require a pull request before merging, with the `test` and `analyze`
     jobs from `ci-feature-to-dev.yml` as required status checks.
   - No branch-source restriction is enforceable by GitHub's branch
     protection UI itself (it doesn't know about *source* branches, only
     who can push to the *target*) — that's why `guard-source-branch` exists
     as a workflow job instead, failing the check if the PR's head is `main`.

3. **Settings → Actions → General → Workflow permissions.** Make sure
   "Read and write permissions" is selected (or at least that `contents:
   write` is allowed) — `ci-feature-to-dev.yml`'s branch-deletion job needs
   it to delete the merged branch via the API.

## TestFlight secrets

`deploy-testflight.yml` checks whether these exist before doing anything,
and just prints a warning and skips the upload if they don't — so it's safe
to merge and use the rest of the pipeline before setting these up. Add each
one under **Settings → Secrets and variables → Actions → New repository
secret**.

### `APPLE_TEAM_ID`

Your 10-character Apple Developer Team ID. Find it at
[developer.apple.com/account](https://developer.apple.com/account) →
Membership details, or in Xcode → Settings → Accounts → (your team) →
"Team ID" next to the team name.

### `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`

An App Store Connect API key, used so the upload step never has to store an
Apple ID password or handle two-factor auth:

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → Users and
   Access → Integrations → App Store Connect API → "+" to generate a new
   key. Give it the **App Manager** role (TestFlight uploads need at least
   that).
2. Note the **Key ID** and **Issuer ID** shown on that page — these become
   `APP_STORE_CONNECT_KEY_ID` and `APP_STORE_CONNECT_ISSUER_ID` respectively.
3. Download the `.p8` private key file — **Apple only lets you download it
   once**, so keep a copy somewhere safe before adding it here.
4. Base64-encode it and put the result in `APP_STORE_CONNECT_API_KEY_BASE64`:
   ```
   base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
   ```
   then paste the clipboard contents in as the secret's value.

### `BUILD_CERTIFICATE_BASE64`, `BUILD_CERTIFICATE_PASSWORD`

A **Distribution** signing certificate, exported as a `.p12` file:

1. In Xcode → Settings → Accounts → (your team) → Manage Certificates,
   create an "Apple Distribution" certificate if one doesn't already exist.
2. In Keychain Access, find that certificate under "My Certificates," expand
   it to reveal the private key, select both the certificate and its key,
   right-click → Export 2 items…, save as a `.p12` file, and set an export
   password when prompted — that password is `BUILD_CERTIFICATE_PASSWORD`.
3. Base64-encode the `.p12` file the same way as the API key:
   ```
   base64 -i DistributionCertificate.p12 | pbcopy
   ```
   Paste that in as `BUILD_CERTIFICATE_BASE64`.

### `BUILD_PROVISION_PROFILE_BASE64`

An **App Store** distribution provisioning profile for `com.atsIOSDev.LastPlace`:

1. In [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles),
   create a new profile with type "App Store", the `com.atsIOSDev.LastPlace`
   App ID, and the distribution certificate from the previous step.
   Download the resulting `.mobileprovision` file.
2. Base64-encode it and add it as `BUILD_PROVISION_PROFILE_BASE64`:
   ```
   base64 -i LastPlace_AppStore.mobileprovision | pbcopy
   ```

### `KEYCHAIN_PASSWORD`

Not tied to any Apple account — this is just a password the workflow makes
up on the spot to lock/unlock the temporary keychain it creates for the
duration of one run. Any random string works; generate one and store it as
this secret, e.g.:
```
openssl rand -base64 24
```

## After all of this is set up

Once every secret above exists, the next push to `main` — whether from a
merged `dev → main` PR or an admin's direct push — will archive a Release
build and upload it to TestFlight automatically. The first upload for a
brand-new app still needs its "App Information" and initial TestFlight
compliance questions answered once, by hand, in App Store Connect; after
that, subsequent builds just appear in TestFlight ready to test.
