# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AfterClose is a **Local-First** after-hours Taiwan stock market scanner app. It processes TWSE/TPEx market data entirely on-device, identifying anomalies and generating explainable recommendations without cloud dependencies.

**Core Principles:**
- All data fetching, analysis, and recommendations happen on-device
- Zero recurring costs (free APIs + RSS + local SQLite)
- Post-market batch processing only
- Recommendations are "attention alerts", not investment advice

## Common Commands

```bash
# Development
flutter pub get                    # Install dependencies
flutter run                        # Run app (debug mode)
flutter run --release              # Run app (release mode)

# Code Generation (after adding Drift tables or Freezed models)
dart run build_runner build --delete-conflicting-outputs

# Testing
flutter test                       # Run all tests
flutter test test/widget_test.dart # Run specific test

# Quality
flutter analyze                    # Static analysis
dart format .                      # Format code
dart format --output=none --set-exit-if-changed .  # Check formatting

# Build
flutter build apk --release        # Android APK
flutter build ios --release        # iOS (requires macOS)
```

## Architecture

### Tech Stack (Planned)

| Layer | Technology |
|:------|:-----------|
| Framework | Flutter 3.38 + Dart 3 |
| State | Riverpod 2.0 (with code generation) |
| Database | Drift (SQLite) |
| Network | Dio |
| Models | Freezed + json_serializable |
| RSS | xml package |

### Directory Structure (Target)

```
lib/
├── main.dart
├── app/                    # App configuration, routing
├── core/                   # Shared utilities, constants, exceptions
├── data/
│   ├── database/           # Drift tables, DAOs
│   ├── remote/             # API clients, RSS parsers
│   └── repositories/       # Coordinate local + remote
├── domain/
│   ├── models/             # Freezed domain models
│   └── services/           # Business logic, Rule Engine
└── presentation/
    ├── controllers/        # Riverpod Notifiers
    ├── screens/            # Full-page widgets
    └── widgets/            # Reusable components
```

### Data Flow

```
API/RSS → Repository → Drift DB → Stream → Riverpod → UI
                ↑                              ↓
            (sync only)              (UI reads local only)
```

## Key Documentation

| File | Description |
|:-----|:------------|
| [README.md](README.md) | Product specification, features, UI structure |
| [docs/RULE_ENGINE.md](docs/RULE_ENGINE.md) | Recommendation rules (R1-R8) + SQLite schema DDL |
| [.agent/skills/flutter-riverpod-architect/SKILL.md](.agent/skills/flutter-riverpod-architect/SKILL.md) | Architecture patterns and coding standards |

## Rule Engine Summary

8 rules for anomaly detection, each with a score:

| Rule | Score | Trigger |
|:-----|------:|:--------|
| REVERSAL_W2S | +35 | Weak-to-strong reversal |
| REVERSAL_S2W | +35 | Strong-to-weak reversal |
| TECH_BREAKOUT | +25 | Price breaks resistance |
| TECH_BREAKDOWN | +25 | Price breaks support |
| VOLUME_SPIKE | +18 | Volume ≥ 2x 20-day average |
| PRICE_SPIKE | +15 | Daily change ≥ 5% |
| INSTITUTIONAL_SHIFT | +12 | Institutional flow reversal |
| NEWS_RELATED | +8 | Related news detected |

Output: Top 10 stocks daily, max 2 reasons per stock.

## Data Sources

- **Taiwan Stocks**: [FinMind API](https://finmind.github.io/) (free tier)
- **News**: RSS feeds
- **US Indices**: Yahoo Finance (optional)

## Coding Standards

- Use Riverpod code generation (`@riverpod`) instead of manual providers
- Use `AsyncNotifier` / `Notifier` instead of `StateProvider`
- Keep Rule Engine as pure functions (input: data, output: reasons)
- UI should only read from local database streams, never directly from network
- Use Dart 3 features: Records, Pattern Matching, sealed classes
