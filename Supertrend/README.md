# 🧠 SuperTrend EA (Long Only)

**Professional MQ5 Expert Advisor** that trades **only LONG positions** based on the **SuperTrend indicator**.  
Optimized for **USD pairs** and designed to capture strong bullish momentum while managing risk through dynamic stop loss, take profit, and trailing mechanisms.

---

## 📚 Index
1. [📖 Overview](#-overview)  
2. [⚙️ Inputs & Parameters](#️-inputs--parameters)  
3. [💡 Features](#-features)  
4. [🧩 Strategy Logic](#-strategy-logic)  
5. [📊 Money Management](#-money-management)  
6. [🧠 Display & Journal](#-display--journal)  
7. [⚠️ Notes](#️-notes)

---

## 📖 Overview
This EA implements a **SuperTrend-based Long strategy** using **ATR volatility filtering**.  
It identifies trend direction, opens long trades when bullish conditions align, and manages open positions with intelligent stop loss and take profit levels.

---

## ⚙️ Inputs & Parameters

| Parameter | Type | Description |
|------------|------|-------------|
| `InpATRPeriod` | `int` | ATR period used in SuperTrend calculation |
| `InpFactor` | `double` | Multiplier for ATR (defines SuperTrend sensitivity) |
| `InpStopLossPercent` | `double` | Stop Loss as a percentage of account equity |
| `InpTakeProfitPercent` | `double` | Take Profit as a percentage of account equity |
| `InpUseTrailingStop` | `bool` | Enables dynamic trailing stop |
| `InpUse100Percent` | `bool` | Whether to use full risk allocation |
| `InpRiskPercent` | `double` | Risk per trade (%) |
| `InpEnableJournal` | `bool` | Enables trade logging to file |
| `InpMagicNumber` | `int` | Unique ID for this EA’s trades |
| `InpShowUSDDisplay` | `bool` | Displays real-time profit in USD |

---

## 💡 Features

✨ **SuperTrend Core Logic** – Uses ATR-based dynamic levels to detect trend direction.  
📈 **Long-Only Strategy** – Filters out short trades for consistent directional bias.  
⚙️ **Customizable Risk Management** – Fully adjustable SL/TP percentages and trailing logic.  
💵 **USD Display** – Real-time tracking of session, position, and total profit in USD.  
🧾 **Journal Logging** – Automatically logs trades and profit data for review.  
🧮 **Account Awareness** – Dynamically adjusts position sizing based on balance and risk%.  
🔢 **Magic Number Protection** – Prevents trade overlap or interference with other EAs.

---

## 🧩 Strategy Logic
1. Calculates **ATR** using `InpATRPeriod`.  
2. Builds **SuperTrend bands** based on ATR and `InpFactor`.  
3. Opens **BUY positions** when price crosses above the SuperTrend lower band.  
4. Places **Stop Loss** and **Take Profit** using % inputs.  
5. Optionally applies **trailing stop** when trade moves in profit.  
6. Monitors open positions and closes them when trend reverses or targets are hit.

---

## 📊 Money Management
- Uses percentage-based **risk allocation** for trade sizing.  
- Can utilize **100% of capital** if `InpUse100Percent` is enabled.  
- Automatically updates **profit metrics in USD**.

---

## 🧠 Display & Journal
🖥️ **On-screen info**:
- Current trade direction  
- Active profit/loss (USD)  
- Total accumulated profit  

📁 **Log File**:
- Trade entries & exits  
- Session profit summaries  
- Time-stamped journal updates  

---

## ⚠️ Notes
- Designed for **MT5 platform** (`.mq5` format).  
- Tested primarily on **USD-based pairs**.  
- Recommended timeframe: **H1 or higher**.  
- Use with **reliable data feeds** for accurate ATR and SuperTrend values.

---

## 💾 Installation & Backtesting
1. Copy `AISuperTrendLongOnly.mq5` into your `MQL5/Experts` folder.  
2. Restart MetaTrader 5 and attach the EA to your desired chart.  
3. Adjust input parameters to your preference.  
4. Run **Strategy Tester** in "1H" timeframe for optimal results.  
5. Monitor performance using the USD display and journal logs.

---

📜 **Copyright © Professional Trading Systems**  
🧠 *Version 2.01 — Built for precision trading with simplicity.*
