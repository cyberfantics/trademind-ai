# TradeMind AI

TradeMind is a Flutter app plus a Python signal and automation engine,
built Jul–Sep 2026. It shows trade signals, a journal, PnL tracking,
and a Gemini AI chat coach, with Bybit API integration and Discord
alerts in the Python engine.

**Paper-trading mode is the default. This is not financial advice,
and no profit claims are made.**

## What is public here, and what is not

- **Public in this repository:** the project description on this page,
  and the existing web scaffold files (`package.json`, `server.js`,
  `vercel.json`) that were already in this repository.
- **Private, not published in this repository:** the Python
  signal/automation engine. It is not in this repo, and no Python
  engine files are included here. A fixed v7.7 version of the engine
  (fee and slippage adjusted backtests, kill switch, daily-loss halt,
  and max open positions cap) has been prepared locally only and
  will not be uploaded unless the owner says otherwise.
- **Flutter app:** the app is described publicly here. The Flutter
  `lib/` Dart files are not uploaded in this step, and this
  repository alone does not contain a complete runnable Flutter
  project (no `pubspec.yaml` or platform folders are claimed here).

## Features described

- Live, active, and closed trade signals, with entry levels,
  stop loss, take-profit targets, and trade outcomes.
- Firebase authentication, trading journals, saved AI conversations,
  and an AI trading coach.
- Sharing signals and AI responses as text, images, and PDFs.
- A Python engine for technical indicators, recent-candle backtesting,
  Discord alerts, SQLite storage, risk controls, and Bybit
  demo-trading integration.

Technologies described: Flutter, Dart, Firebase, Python, Gemini API,
REST APIs, SQLite, Pandas, NumPy, Bybit API.

## Images / Screenshots

No verified TradeMind app screenshots exist in this repository.
No screenshot files are linked here, and no placeholder image URLs
are used.

Screenshots will be added here when the app images are supplied.
The exact files needed are:

- `images/trademind-signals-screen.png` — signals list screen
- `images/trademind-ai-chat-screen.png` — Gemini AI chat coach screen
- `images/trademind-journal-screen.png` — journal screen
- `images/trademind-pnl-screen.png` — PnL tracking screen
- `images/trademind-app-icon.png` — app icon, if one is to be shown

Until those files are supplied and verified in the repository,
this section stays as a placeholder note only.

## Limitations, stated honestly

- No App Store or Google Play listing is claimed for TradeMind.
- Backtest results from earlier fee-free versions were overstated
  and should not be quoted as expected returns. The locally
  prepared v7.7 engine adjusts for fee and slippage, but it is
  not published here.
- Lookahead was not fully audited, overfitting risk remains, and
  results need out-of-sample and forward paper testing.
