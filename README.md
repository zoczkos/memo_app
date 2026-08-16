# Vocamio (memo_app)

Flutter flashcard app with spaced repetition. Runs as a PWA on the web.

## Live app

https://zoczkos.github.io/memo_app/

## Develop

```bash
flutter pub get
flutter run -d chrome
```

## Deploy

Pushes to `main` build the web app and publish it to GitHub Pages via
[`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml).

In the GitHub repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
