//+------------------------------------------------------------------+
//|                                  SuperTrend_EA_USD.mq5           |
//|         Professional MQ5 SuperTrend EA—USD (Only LONG)           |
//+------------------------------------------------------------------+
#property copyright "Professional Trading Systems"
#property version   "2.01"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

//--- Inputs
input int      InpATRPeriod = 10;
input double   InpFactor = 3.0;
input double   InpStopLossPercent = 2.0;
input double   InpTakeProfitPercent = 6.0;
input bool     InpUseTrailingStop = true;
input bool     InpUse100Percent = true;
input double   InpRiskPercent = 100.0;
input bool     InpEnableJournal = true;
input int      InpMagicNumber = 123456;
input bool     InpShowUSDDisplay = true;

//--- Buffers, handles, vars
double         atrBuffer[];
double         supertrendUp[];
double         supertrendDown[];
double         direction[];
int            atrHandle;
datetime       lastBarTime;
double         entryPrice = 0.0;
double         currentStopLoss = 0.0;
double         currentTakeProfit = 0.0;
bool           isPositionOpen = false;

//--- USD journal/display
double         sessionProfitUSD = 0.0;
double         currentPositionProfitUSD = 0.0;
double         totalProfitUSD = 0.0;
string         journalFileName;
int            journalHandle;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    if(atrHandle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator: ", GetLastError());
        return INIT_FAILED;
    }
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(supertrendUp, true);
    ArraySetAsSeries(supertrendDown, true);
    ArraySetAsSeries(direction, true);
    ArrayResize(supertrendUp, 1000);
    ArrayResize(supertrendDown, 1000);
    ArrayResize(direction, 1000);
    trade.SetExpertMagicNumber(InpMagicNumber);
    if(InpEnableJournal)
        InitializeJournal();
    lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(InpShowUSDDisplay) CreateUSDDisplay();
    Print("SuperTrend EA (USD Version - Long Only) initialized successfully");
    LogToJournal("EA_INIT", "SuperTrend EA USD Version LONG ONLY initialized");
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    ObjectsDeleteAll(0, "USD_");
    if(InpEnableJournal && journalHandle != INVALID_HANDLE) FileClose(journalHandle);
}
//+------------------------------------------------------------------+
void OnTick()
{
    UpdateUSDProfitDisplay();
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;
    CalculateSuperTrend();
    CheckPositionStatus();
    ProcessTradingLogic();
    if(InpUseTrailingStop && isPositionOpen) UpdateTrailingStop();
    if(InpShowUSDDisplay) UpdateUSDDisplay();
}
//+------------------------------------------------------------------+
void CalculateSuperTrend()
{
    if(CopyBuffer(atrHandle, 0, 0, 100, atrBuffer) <= 0) return;
    for(int i = 99; i >= 0; i--)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        double close = iClose(_Symbol, PERIOD_CURRENT, i);
        double hl2 = (high + low) / 2.0;
        double atr = atrBuffer[i];
        double upperband = hl2 + (InpFactor * atr);
        double lowerband = hl2 - (InpFactor * atr);
        double finalUpperband = upperband, finalLowerband = lowerband;
        if(i < 99)
        {
            double prevClose = iClose(_Symbol, PERIOD_CURRENT, i + 1);
            if(upperband < supertrendUp[i + 1] || prevClose > supertrendUp[i + 1])
                finalUpperband = upperband;
            else
                finalUpperband = supertrendUp[i + 1];
            if(lowerband > supertrendDown[i + 1] || prevClose < supertrendDown[i + 1])
                finalLowerband = lowerband;
            else
                finalLowerband = supertrendDown[i + 1];
        }
        supertrendUp[i] = finalUpperband;
        supertrendDown[i] = finalLowerband;
        if(i < 99)
        {
            if(direction[i + 1] == 1.0 && close <= finalLowerband)
                direction[i] = -1.0;
            else if(direction[i + 1] == -1.0 && close >= finalUpperband)
                direction[i] = 1.0;
            else
                direction[i] = direction[i + 1];
        }
        else
            direction[i] = close <= finalLowerband ? -1.0 : 1.0;
    }
}
//+------------------------------------------------------------------+
void CheckPositionStatus()
{
    isPositionOpen = false; 
    currentPositionProfitUSD = 0.0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
            {
                isPositionOpen = true;
                entryPrice = position.PriceOpen();
                currentPositionProfitUSD = position.Profit() + position.Swap() + position.Commission();
                break;
            }
        }
    }
}
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, 1);
    double currentOpen = iOpen(_Symbol, PERIOD_CURRENT, 1);
    bool isBullish = direction[1] > 0;
    bool isBearish = direction[1] < 0;
    bool wasBullish = direction[2] > 0;
    bool wasBearish = direction[2] < 0;
    bool isGreenCandle = currentClose > currentOpen;
    bool isRedCandle = currentClose < currentOpen;
    // Only long trades: ENTRY = new bullish trend + green candle, EXIT = bullish trend reverses to bearish + red candle
    bool freshBullishTrend = wasBearish && isBullish && isGreenCandle;
    bool entryCondition = freshBullishTrend && !isPositionOpen;
    bool trendReversalExit = wasBullish && isBearish && isRedCandle;
    bool exitCondition = trendReversalExit && isPositionOpen;
    if(entryCondition) ExecuteBuyOrder();
    if(exitCondition) ExecuteCloseOrder("Bearish Exit - Trend Reversal");
}
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double lotSize = CalculateLotSize();
    double potentialProfit = 0.0, potentialLoss = 0.0;
    if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, lotSize, ask, ask * (1.0 + InpTakeProfitPercent / 100.0), potentialProfit)) {
        Print("OrderCalcProfit for TP failed! Error:", GetLastError());
        potentialProfit = 0.0;
    }
    if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, lotSize, ask, ask * (1.0 - InpStopLossPercent / 100.0), potentialLoss)) {
        Print("OrderCalcProfit for SL failed! Error:", GetLastError());
        potentialLoss = 0.0;
    }
    double stopLoss = ask * (1.0 - InpStopLossPercent / 100.0);
    double takeProfit = ask * (1.0 + InpTakeProfitPercent / 100.0);
    stopLoss = NormalizeDouble(stopLoss, _Digits);
    takeProfit = NormalizeDouble(takeProfit, _Digits);
    if(trade.Buy(lotSize, _Symbol, ask, stopLoss, takeProfit, "SuperTrend Bullish Entry"))
    {
        entryPrice = ask;
        currentStopLoss = stopLoss;
        currentTakeProfit = takeProfit;
        string message = StringFormat("BUY ORDER EXECUTED - Lot: %.2f, Entry: %.5f, SL: %.5f (Loss: $%.2f), TP: %.5f (Profit: $%.2f)", 
                                    lotSize, ask, stopLoss, potentialLoss, takeProfit, potentialProfit);
        Print(message);
        LogToJournal("BUY_ORDER", message);
    }
    else
    {
        string error = StringFormat("BUY ORDER FAILED - Error: %d", GetLastError());
        Print(error);
        LogToJournal("BUY_ERROR", error);
    }
}
//+------------------------------------------------------------------+
void ExecuteCloseOrder(string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
            {
                double closePrice = position.Type() == POSITION_TYPE_BUY ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double profit = position.Profit() + position.Swap() + position.Commission();
                if(trade.PositionClose(position.Ticket()))
                {
                    sessionProfitUSD += profit;
                    totalProfitUSD += profit;
                    string message = StringFormat("POSITION CLOSED - %s - Profit: $%.2f, Close Price: %.5f, Session Total: $%.2f", 
                                                reason, profit, closePrice, sessionProfitUSD);
                    Print(message);
                    LogToJournal("CLOSE_ORDER", message);
                }
                else
                {
                    string error = StringFormat("CLOSE ORDER FAILED - Error: %d", GetLastError());
                    Print(error);
                    LogToJournal("CLOSE_ERROR", error);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(!InpUse100Percent)
    {
        double riskAmount = account.Balance() * (InpRiskPercent / 100.0);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double stopLossPoints = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) * (InpStopLossPercent / 100.0)) / _Point;
        double lotSize = riskAmount / (stopLossPoints * tickValue);
        return NormalizeDouble(lotSize, 2);
    }
    double balance = account.Balance();
    double marginRequired = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    if(marginRequired > 0)
    {
        double maxLots = balance / marginRequired;
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        maxLots = MathMax(minLot, MathMin(maxLots * 0.95, maxLot));
        return NormalizeDouble(maxLots, 2);
    }
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
}
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber && position.Type() == POSITION_TYPE_BUY)
            {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double atrValue = atrBuffer[0];
                double newStopLoss = currentPrice - (InpFactor * atrValue);
                newStopLoss = NormalizeDouble(newStopLoss, _Digits);
                double potentialTrailingLoss = 0.0;
                if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, position.Volume(), position.PriceOpen(), newStopLoss, potentialTrailingLoss)) {
                    Print("OrderCalcProfit for trailing SL failed! Error: ", GetLastError());
                    potentialTrailingLoss = 0.0;
                }
                if(newStopLoss > position.StopLoss() && newStopLoss < currentPrice)
                {
                    if(trade.PositionModify(position.Ticket(), newStopLoss, position.TakeProfit()))
                    {
                        string message = StringFormat("TRAILING STOP UPDATED - New SL: %.5f (Max Loss: $%.2f)", newStopLoss, potentialTrailingLoss);
                        Print(message);
                        LogToJournal("TRAILING_STOP", message);
                        currentStopLoss = newStopLoss;
                    }
                }
            }
        }
    }
}
//--- (USD display, journaling, and helper functions as before) ---
void CreateUSDDisplay() {/* ... */}
void UpdateUSDDisplay() {/* ... */}
void UpdateUSDProfitDisplay()
{
    double tempCurrentProfit = 0.0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(position.SelectByIndex(i))
        {
            if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
            {
                tempCurrentProfit += position.Profit() + position.Swap() + position.Commission();
            }
        }
    }
    currentPositionProfitUSD = tempCurrentProfit;
}
void InitializeJournal()
{
    journalFileName = StringFormat("SuperTrend_USD_Journal_%s_%s.txt", _Symbol, TimeToString(TimeCurrent(), TIME_DATE));
    journalHandle = FileOpen(journalFileName, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(journalHandle != INVALID_HANDLE)
    {
        string header = StringFormat("=== SuperTrend EA LONG ONLY Trading Journal ===\nSymbol: %s\nAccount: %d\nBalance: $%.2f\nDate: %s\n\n",
                                   _Symbol, account.Login(), account.Balance(), TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
        FileWrite(journalHandle, header);
        FileFlush(journalHandle);
    }
}
void LogToJournal(string action, string message)
{
    if(!InpEnableJournal || journalHandle == INVALID_HANDLE) return;
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    double currentBalance = account.Balance();
    double currentEquity = account.Equity();
    double currentProfit = account.Profit();
    string logEntry = StringFormat("[%s] %s: %s | Balance: $%.2f | Equity: $%.2f | Floating P/L: $%.2f | Session: $%.2f",
                                 timestamp, action, message, currentBalance, currentEquity, currentProfit, sessionProfitUSD);
    FileWrite(journalHandle, logEntry);
    FileFlush(journalHandle);
}
void OnTrade()
{
    if(InpEnableJournal)
    {
        string message = StringFormat("Trade event - Balance: $%.2f, Equity: $%.2f, Current Position P/L: $%.2f", 
                                    account.Balance(), account.Equity(), currentPositionProfitUSD);
        LogToJournal("TRADE_EVENT", message);
    }
}
double GetOverallProfitLoss()
{
    return sessionProfitUSD + currentPositionProfitUSD;
}
