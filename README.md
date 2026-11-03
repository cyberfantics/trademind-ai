# TradeMind AI

TradeMind AI is a trading companion built with Flutter and Python, combining trade signals, portfolio tracking, trading journals, and AI-assisted market analysis in one platform.

The project includes a mobile application and a separate Python-based trading engine. The mobile app provides the interface for monitoring trades, reviewing performance, maintaining a trading journal, and interacting with an AI trading coach. The Python engine handles market data, technical indicators, signal generation, risk management, and exchange integration.

## Features

- **Trade Signals:** View active and completed trades, including entry prices, stop-loss levels, take-profit targets, and outcomes.
- **Trading Journal:** Record trades and review trading activity.
- **Performance Tracking:** Monitor profit and loss (PnL) and trading history.
- **AI Trading Coach:** Chat with Gemini-powered AI for trading-related assistance.
- **Signal Sharing:** Share trading signals and AI conversations as text, images, or PDF files.
- **Exchange Integration:** Connect with Bybit for market data and demo trading.
- **Discord Notifications:** Receive trading alerts through Discord.
- **Risk Management:** Includes position limits, daily loss protection, and a trading kill switch.

## Technology Stack

| Component | Technologies |
|---|---|
| Mobile Application | Flutter, Dart |
| Authentication & Backend | Firebase |
| AI Integration | Google Gemini API |
| Trading Engine | Python |
| Data Analysis | Pandas, NumPy |
| Storage | SQLite |
| Exchange Integration | Bybit API |
| Notifications | Discord |

## Repository Structure

This repository currently contains the project documentation and existing web scaffold files.

The Flutter application source code and Python trading engine are maintained separately and are not included in this public repository.

## Trading Mode

Paper trading is the default mode. The project also includes Bybit demo-trading integration for testing trading strategies without using real funds.

**Disclaimer:** TradeMind AI is a software project for trading analysis and automation. It does not guarantee profits or provide personalized financial advice. Trading involves financial risk.
