#property link          "https://www.earnforex.com/metatrader-indicators/macd-multi-timeframe/"
#property version       "1.03"
#property strict
#property copyright     "EarnForex.com - 2019-2026"
#property description   "This indicator will show you the MACD status on multiple timeframes."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this indicator cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window

#include <MQLTA Utils.mqh>

#property indicator_buffers 1

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0, // CURRENT CANDLE
    CLOSED_CANDLE = 1   // PREVIOUS CANDLE
};

enum ENUM_NOTIFY_MODE
{
    NOTIFY_OFF,                // Notifications Off
    NOTIFY_ALL_SIGNALS,        // All Signals Align
    NOTIFY_ABOVE_BELOW_ZERO,   // Above/Below Zero
    NOTIFY_RISE_FALL,          // Rise/Fall
    NOTIFY_ABOVE_BELOW_SIGNAL, // Above/Below Signal Line
    NOTIFY_ZERO_AND_RISEFALL,  // Above/Below Zero + Rise/Fall
    NOTIFY_ZERO_AND_SIGNAL,    // Above/Below Zero + Above/Below Signal Line
    NOTIFY_RISEFALL_AND_SIGNAL // Rise/Fall + Above/Below Signal Line
};

input string Comment_1 = "===================="; // Indicator Settings
input int MACDFastEMA = 12;                      // MACD Fast EMA Period
input int MACDSlowEMA = 26;                      // MACD Slow EMA Period
input int MACDSMA = 9;                           // MACD SMA Period
input ENUM_APPLIED_PRICE MACDAppliedPrice = PRICE_CLOSE; // MACD Applied Price
input ENUM_CANDLE_TO_CHECK CandleToCheck = CLOSED_CANDLE;  // Candle To Use For Analysis
input string Comment_2 = "===================="; // Enabled Timeframes
input bool TFM1 = true;                          // Enable Timeframe M1
input bool TFM5 = true;                          // Enable Timeframe M5
input bool TFM15 = true;                         // Enable Timeframe M15
input bool TFM30 = true;                         // Enable Timeframe M30
input bool TFH1 = true;                          // Enable Timeframe H1
input bool TFH4 = true;                          // Enable Timeframe H4
input bool TFD1 = true;                          // Enable Timeframe D1
input bool TFW1 = true;                          // Enable Timeframe W1
input bool TFMN1 = true;                         // Enable Timeframe MN1
input string Comment_3 = "===================="; // Notification Options
input ENUM_NOTIFY_MODE NotifyMode = NOTIFY_OFF;  // Notification Mode
input bool SendAlert = true;                     // Send Alert Notification
input bool SendApp = false;                      // Send Notification to Mobile
input bool SendEmail = false;                    // Send Notification via Email
input bool SendSound = false;                    // Sound Alert
input string SoundFile = "alert.wav";            // Sound File
input string Comment_4 = "===================="; // Graphical Objects
input ENUM_BASE_CORNER PanelCorner = CORNER_LEFT_UPPER; // Chart Corner
input int Xoff = 20;                             // Horizontal spacing for the control panel
input int Yoff = 20;                             // Vertical spacing for the control panel
input string IndicatorName = "MQLTA-MACDMTF";    // Indicator Name (to name the objects)

double IndCurr[9], IndPrevDiff[9], IndCurrAdd[9];

bool Positive = false;
bool Negative = false;

bool TFEnabled[9];
int TFValues[9];
string TFText[9];

double BufferZero[];

int LastAlertDirection = 2; // Direction that was on previous alert. 1 for long, -1 for short, 0 for neutral, 2 for no alert yet.

double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;
int EnabledTFCount = 0;

string IndicatorNameTextBox = "MT MACD";
string CaptionTooltip = "Multi-Timeframe MACD Indicator";
bool PanelCollapsed = false;
string GVarCollapsed; // Global variable name for saving the collapsed state.

//+------------------------------------------------------------------+
//| Custom indicator initialization function.                        |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    CleanChart();

    if (MACDFastEMA <= 0)
    {
        Alert("Error: MACD Fast EMA Period must be greater than 0.");
    }
    if (MACDSlowEMA <= 0)
    {
        Alert("Error: MACD Slow EMA Period must be greater than 0.");
    }
    if (MACDSMA <= 0)
    {
        Alert("Error: MACD SMA Period must be greater than 0.");
    }
    if (MACDFastEMA >= MACDSlowEMA)
    {
        Alert("Error: MACD Fast EMA Period must be less than MACD Slow EMA Period.");
    }

    // Build caption with notification mode abbreviation and tooltip with full mode name.
    if (NotifyMode ==      NOTIFY_ALL_SIGNALS)         { IndicatorNameTextBox = "MT MACD: ALL";   CaptionTooltip += " - Notifications: All Signals Align"; }
    else if (NotifyMode == NOTIFY_ABOVE_BELOW_ZERO)    { IndicatorNameTextBox = "MT MACD: >/< 0"; CaptionTooltip += " - Notifications: Above/Below Zero"; }
    else if (NotifyMode == NOTIFY_RISE_FALL)           { IndicatorNameTextBox = "MT MACD: R/F";   CaptionTooltip += " - Notifications: Rise/Fall"; }
    else if (NotifyMode == NOTIFY_ABOVE_BELOW_SIGNAL)  { IndicatorNameTextBox = "MT MACD: >/< S"; CaptionTooltip += " - Notifications: Above/Below Signal Line"; }
    else if (NotifyMode == NOTIFY_ZERO_AND_RISEFALL)   { IndicatorNameTextBox = "MT MACD: 0+R/F"; CaptionTooltip += " - Notifications: Above/Below Zero + Rise/Fall"; }
    else if (NotifyMode == NOTIFY_ZERO_AND_SIGNAL)     { IndicatorNameTextBox = "MT MACD: 0+S";   CaptionTooltip += " - Notifications: Above/Below Zero + Above/Below Signal Line"; }
    else if (NotifyMode == NOTIFY_RISEFALL_AND_SIGNAL) { IndicatorNameTextBox = "MT MACD: R/F+S"; CaptionTooltip += " - Notifications: Rise/Fall + Above/Below Signal Line"; }

    // Load the collapsed state from a global variable specific to this chart.
    GVarCollapsed = IndicatorName + "-Collapsed-" + IntegerToString(ChartID());
    if (GlobalVariableCheck(GVarCollapsed))
    {
        PanelCollapsed = (GlobalVariableGet(GVarCollapsed) != 0);
        GlobalVariableDel(GVarCollapsed);
    }

    TFEnabled[0] = TFM1;
    TFEnabled[1] = TFM5;
    TFEnabled[2] = TFM15;
    TFEnabled[3] = TFM30;
    TFEnabled[4] = TFH1;
    TFEnabled[5] = TFH4;
    TFEnabled[6] = TFD1;
    TFEnabled[7] = TFW1;
    TFEnabled[8] = TFMN1;
    TFValues[0] = PERIOD_M1;
    TFValues[1] = PERIOD_M5;
    TFValues[2] = PERIOD_M15;
    TFValues[3] = PERIOD_M30;
    TFValues[4] = PERIOD_H1;
    TFValues[5] = PERIOD_H4;
    TFValues[6] = PERIOD_D1;
    TFValues[7] = PERIOD_W1;
    TFValues[8] = PERIOD_MN1;
    TFText[0] = "M1";
    TFText[1] = "M5";
    TFText[2] = "M15";
    TFText[3] = "M30";
    TFText[4] = "H1";
    TFText[5] = "H4";
    TFText[6] = "D1";
    TFText[7] = "W1";
    TFText[8] = "MN1";
    Positive = false;
    Negative = false;

    SetIndexBuffer(0, BufferZero);
    SetIndexStyle(0, DRAW_NONE);

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(40 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (PanelMovX + 1) * 4 + 2;
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    // Count enabled timeframes to pre-calculate panel height.
    for (int i = 0; i < ArraySize(TFEnabled); i++)
    {
        if (TFEnabled[i]) EnabledTFCount++;
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function.                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    CalculateLevels();

    FillBuffers();
    if (NotifyMode != NOTIFY_OFF)
    {
        Notify();
    }

    DrawPanel();
    return rates_total;
}

//+------------------------------------------------------------------+
//| Indicator deinitialization.                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanChart();
    if (reason != REASON_REMOVE) // Timeframe change, parameter change, recompilation, etc. - save the state.
    {
        GlobalVariableSet(GVarCollapsed, PanelCollapsed ? 1.0 : 0.0);
    }
}

//+------------------------------------------------------------------+
//| Processes key presses and mouse clicks.                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key pressed.
        {
            ChartIndicatorDelete(0, 0, IndicatorName);
        }
    }
    else if (id == CHARTEVENT_OBJECT_CLICK) // Timeframe switching or panel minimize/maximize.
    {
        if (sparam == PanelMinMax)
        {
            PanelCollapsed = !PanelCollapsed;
            CleanChart();
            DrawPanel();
        }
        else if (StringFind(sparam, "-P-TF-") >= 0)
        {
            string ClickDesc = ObjectGetString(0, sparam, OBJPROP_TEXT);
            ChangeChartPeriod(ClickDesc);
        }
    }
}

//+------------------------------------------------------------------+
//| Deletes all chart objects created by the indicator.              |
//+------------------------------------------------------------------+
void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName + "-");
}

//+------------------------------------------------------------------+
//| Switch chart timeframe.                                          |
//+------------------------------------------------------------------+
void ChangeChartPeriod(string Button)
{
    StringReplace(Button, "*", "");
    int NewPeriod = 0;
    if (Button == "M1") NewPeriod = PERIOD_M1;
    if (Button == "M5") NewPeriod = PERIOD_M5;
    if (Button == "M15") NewPeriod = PERIOD_M15;
    if (Button == "M30") NewPeriod = PERIOD_M30;
    if (Button == "H1") NewPeriod = PERIOD_H1;
    if (Button == "H4") NewPeriod = PERIOD_H4;
    if (Button == "D1") NewPeriod = PERIOD_D1;
    if (Button == "W1") NewPeriod = PERIOD_W1;
    if (Button == "MN1") NewPeriod = PERIOD_MN1;
    if (NewPeriod != 0) ChartSetSymbolPeriod(0, Symbol(), NewPeriod);
}

//+------------------------------------------------------------------+
//| Main function to detect Positive, Negative, Uncertain state.     |
//+------------------------------------------------------------------+
void CalculateLevels()
{
    int EnabledCount = 0;
    int PositiveCount = 0;
    int NegativeCount = 0;
    Positive = false;
    Negative = false;
    int Shift = 0;
    if (CandleToCheck == CLOSED_CANDLE) Shift = 1;
    int MaxBars = MACDSlowEMA + Shift + 1;
    ArrayInitialize(IndCurr, 0);
    ArrayInitialize(IndPrevDiff, 0);
    ArrayInitialize(IndCurrAdd, 0);
    for(int i = 0; i < ArraySize(IndCurr); i++)
    {
        if (!TFEnabled[i]) continue;
        if (iBars(Symbol(), TFValues[i]) < MaxBars)
        {
            MaxBars = iBars(Symbol(), TFValues[i]);
            Print("Please load more historical candles. Current calculation only on ", MaxBars, " bars for timeframe ", TFText[i], ".");
            if (MaxBars < 0)
            {
                break;
            }
        }
        EnabledCount++;
        double MACDCurrMain = iMACD(Symbol(), TFValues[i], MACDFastEMA, MACDSlowEMA, MACDSMA, MACDAppliedPrice, MODE_MAIN, Shift);
        double MACDCurrSign = iMACD(Symbol(), TFValues[i], MACDFastEMA, MACDSlowEMA, MACDSMA, MACDAppliedPrice, MODE_SIGNAL, Shift);
        double MACDPrevMain = iMACD(Symbol(), TFValues[i], MACDFastEMA, MACDSlowEMA, MACDSMA, MACDAppliedPrice, MODE_MAIN, Shift + 1);
        if (MACDCurrMain > 0)
        {
            IndCurr[i] = 1;
        }
        else if (MACDCurrMain <= 0)
        {
            IndCurr[i] = -1;
        }
        if (MACDCurrMain > MACDPrevMain)
        {
            IndPrevDiff[i] = 1;
        }
        else if (MACDCurrMain < MACDPrevMain)
        {
            IndPrevDiff[i] = -1;
        }
        if (MACDCurrMain > MACDCurrSign)
        {
            IndCurrAdd[i] = 1;
        }
        else if (MACDCurrMain < MACDCurrSign)
        {
            IndCurrAdd[i] = -1;
        }
        if (IndCurr[i] == 1 && IndPrevDiff[i] == 1 && IndCurrAdd[i] == 1) PositiveCount++;
        else if (IndCurr[i] == -1 && IndPrevDiff[i] == -1 && IndCurrAdd[i] == -1) NegativeCount++;
    }
    if (PositiveCount == EnabledCount) Positive = true;
    else if (NegativeCount == EnabledCount) Negative = true;
}

//+------------------------------------------------------------------+
//| Fills indicator buffers.                                         |
//+------------------------------------------------------------------+
void FillBuffers()
{
    if (Positive) BufferZero[0] = 1;
    if (Negative) BufferZero[0] = -1;
    if (!Positive && !Negative) BufferZero[0] = 0;
}

//+------------------------------------------------------------------+
//| Checks if all enabled timeframes agree for a given signal array. |
//| Returns 1 if all positive, -1 if all negative, 0 if mixed.       |
//+------------------------------------------------------------------+
int CheckAllAgree(double &SignalArray[])
{
    int PositiveCount = 0;
    int NegativeCount = 0;
    int EnabledCount = 0;
    for (int i = 0; i < ArraySize(TFEnabled); i++)
    {
        if (!TFEnabled[i]) continue;
        EnabledCount++;
        if (SignalArray[i] == 1) PositiveCount++;
        if (SignalArray[i] == -1) NegativeCount++;
    }
    if (EnabledCount == 0) return 0;
    if (PositiveCount == EnabledCount) return 1;
    if (NegativeCount == EnabledCount) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Returns the overall signal direction for the current notify mode.|
//| Returns 1 for long, -1 for short, 0 for uncertain/mixed.         |
//+------------------------------------------------------------------+
int GetNotifyDirection(int ZeroSignal, int RiseFallSignal, int SignalLineSignal)
{
										 
    if (NotifyMode == NOTIFY_ALL_SIGNALS)
    {
        if (Positive) return 1;
        if (Negative) return -1;
        return 0;
    }
    if (NotifyMode == NOTIFY_ABOVE_BELOW_ZERO)
    {
        return ZeroSignal;
    }
    if (NotifyMode == NOTIFY_RISE_FALL)
    {
        return RiseFallSignal;
    }
    if (NotifyMode == NOTIFY_ABOVE_BELOW_SIGNAL)
    {
        return SignalLineSignal;
    }
    // Combined modes: both components must agree for a clear direction.
    int FirstSignal = 0;
    int SecondSignal = 0;
    if (NotifyMode == NOTIFY_ZERO_AND_RISEFALL)
    {
        FirstSignal = ZeroSignal;
        SecondSignal = RiseFallSignal;
    }
    else if (NotifyMode == NOTIFY_ZERO_AND_SIGNAL)
    {
        FirstSignal = ZeroSignal;
        SecondSignal = SignalLineSignal;
    }
    else if (NotifyMode == NOTIFY_RISEFALL_AND_SIGNAL)
    {
        FirstSignal = RiseFallSignal;
        SecondSignal = SignalLineSignal;
    }
    if (FirstSignal == 1 && SecondSignal == 1) return 1;
    if (FirstSignal == -1 && SecondSignal == -1) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Builds the notification text for a fully formed signal.          |
//| Only called when Direction is 1 (long) or -1 (short).            |
//+------------------------------------------------------------------+
string BuildSituationString(int Direction)
{
    if (NotifyMode == NOTIFY_ALL_SIGNALS)
    {
        if (Direction == 1) return "ALL BULLISH";
        return "ALL BEARISH";
    }
    if (NotifyMode == NOTIFY_ABOVE_BELOW_ZERO)
    {
        if (Direction == 1) return "ABOVE ZERO";
        return "BELOW ZERO";
    }
    if (NotifyMode == NOTIFY_RISE_FALL)
    {
        if (Direction == 1) return "RISING";
        return "FALLING";
    }
    if (NotifyMode == NOTIFY_ABOVE_BELOW_SIGNAL)
    {
        if (Direction == 1) return "ABOVE SIGNAL LINE";
        return "BELOW SIGNAL LINE";
    }
    if (NotifyMode == NOTIFY_ZERO_AND_RISEFALL)
    {
        if (Direction == 1) return "ABOVE ZERO and RISING";
        return "BELOW ZERO and FALLING";
    }
    if (NotifyMode == NOTIFY_ZERO_AND_SIGNAL)
    {
        if (Direction == 1) return "ABOVE ZERO and ABOVE SIGNAL LINE";
        return "BELOW ZERO and BELOW SIGNAL LINE";
    }
    if (NotifyMode == NOTIFY_RISEFALL_AND_SIGNAL)
    {
        if (Direction == 1) return "RISING and ABOVE SIGNAL LINE";
        return "FALLING and BELOW SIGNAL LINE";
    }
    return "";
}

//+------------------------------------------------------------------+
//| Alert processing.                                                |
//+------------------------------------------------------------------+
void Notify()
{
    if (NotifyMode == NOTIFY_OFF) return;
    if (!SendAlert && !SendApp && !SendEmail && !SendSound) return;

    int ZeroSignal = CheckAllAgree(IndCurr);
    int RiseFallSignal = CheckAllAgree(IndPrevDiff);
    int SignalLineSignal = CheckAllAgree(IndCurrAdd);

    int Direction = GetNotifyDirection(ZeroSignal, RiseFallSignal, SignalLineSignal);

    if (LastAlertDirection == 2)
    {
        LastAlertDirection = Direction; // Avoid initial alert when just attaching the indicator to the chart.
        return;
    }
    if (Direction == 0) return; // Do not alert on uncertain or mixed signals.
    if (Direction == LastAlertDirection) return; // Avoid alerting about the same signal.
    LastAlertDirection = Direction;

    string SituationString = BuildSituationString(Direction);

    if (SendAlert)
    {
        string AlertText = IndicatorName + " - " + Symbol() + " Notification. MACD: " + SituationString + ".";
        Alert(AlertText);
    }
    if (SendEmail)
    {
        string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
        string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n\r\n" + IndicatorName + " Notification for " + Symbol() + "\r\n\r\n";
        EmailBody += "MACD:  " + SituationString + "\r\n\r\n";
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email: " + IntegerToString(GetLastError()) + ".");
    }
    if (SendApp)
    {
        string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " - MACD:  " + SituationString + ".";
        if (!SendNotification(AppText)) Print("Error sending notification: " + IntegerToString(GetLastError()) + ".");
    }
    if (SendSound)
    {
        PlaySound(SoundFile);
    }
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelMinMax = IndicatorName + "-P-MINMAX";
string PanelSig = IndicatorName + "-P-SIG";
//+------------------------------------------------------------------+
//| Main panel drawing function.                                     |
//+------------------------------------------------------------------+
void DrawPanel()
{
    int Rows = 1;

    int TotalRows;
    if (PanelCollapsed)
        TotalRows = 1; // Header only.
    else
        TotalRows = 1 + EnabledTFCount + 1; // Header + TF rows + signal row.
    int PanelHeight = (PanelMovY + 1) * TotalRows + 3;

    // Calculate base offsets and direction multipliers depending on the chart corner.
    // For right corners, the panel is shifted left by its width.
    // For lower corners, the panel is shifted up by its height.
    int BaseX = Xoff;
    int BaseY = Yoff;
    int MulX = 1;
    int MulY = 1;
    if (PanelCorner == CORNER_RIGHT_UPPER || PanelCorner == CORNER_RIGHT_LOWER)
    {
        BaseX = Xoff + PanelRecX;
        MulX = -1;
    }
    if (PanelCorner == CORNER_LEFT_LOWER || PanelCorner == CORNER_RIGHT_LOWER)
    {
        BaseY = Yoff + PanelHeight;
        MulY = -1;
    }

    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSet(PanelBase, OBJPROP_XDISTANCE, BaseX);
    ObjectSet(PanelBase, OBJPROP_YDISTANCE, BaseY);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSet(PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, PanelBase, OBJPROP_CORNER, PanelCorner);

    DrawEdit(PanelLabel,
             BaseX + MulX * 2,
             BaseY + MulY * 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             CaptionTooltip,
             ALIGN_CENTER,
             "Consolas",
             IndicatorNameTextBox,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);
    ObjectSetInteger(0, PanelLabel, OBJPROP_CORNER, PanelCorner);

    // Minimize/maximize button in the top-right corner of the header.
    // For upper corners, collapsed shows down arrow (expand downward), expanded shows up arrow (collapse upward).
    // For lower corners, the arrows are reversed since the panel expands upward.
    bool BottomCorner = (PanelCorner == CORNER_LEFT_LOWER || PanelCorner == CORNER_RIGHT_LOWER);
    bool ShowDownArrow = (PanelCollapsed && !BottomCorner) || (!PanelCollapsed && BottomCorner);
    string MinMaxText = ShowDownArrow ? CharToString(226) : CharToString(225);
    DrawEdit(PanelMinMax,
             BaseX + MulX * (PanelLabX - PanelMovY + 2),
             BaseY + MulY * 2,
             PanelMovY,
             PanelLabY,
             true,
             8,
             PanelCollapsed ? "Expand Panel" : "Collapse Panel",
             ALIGN_CENTER,
             "Wingdings",
             MinMaxText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);
    ObjectSetInteger(0, PanelMinMax, OBJPROP_CORNER, PanelCorner);

    if (!PanelCollapsed)
    {
        for (int i = 0; i < ArraySize(IndCurr); i++)
        {
            if (!TFEnabled[i]) continue;
            string TFRowObj = IndicatorName + "-P-TF-" + TFText[i];
            string IndCurrObj = IndicatorName + "-P-ICURR-V-" + TFText[i];
            string IndPrevDiffObj = IndicatorName + "-P-PREVDIFF-V-" + TFText[i];
            string IndCurrAddObj = IndicatorName + "-P-CURRADD-V-" + TFText[i];
            string TFRowText = TFText[i];
            string IndCurrText = "";
            string IndPrevDiffText = "";
            string IndCurrAddText = "";
            string IndCurrToolTip = "";
            string IndPrevDiffToolTip = "";
            string IndCurrAddToolTip = "";

            color IndCurrBackColor = clrKhaki;
            color IndCurrTextColor = clrNavy;
            color IndPrevDiffBackColor = clrKhaki;
            color IndPrevDiffTextColor = clrNavy;
            color IndCurrAddBackColor = clrKhaki;
            color IndCurrAddTextColor = clrNavy;

            // Highlight the current chart timeframe with a different background.
            color TFLabelBackColor = clrKhaki;
            if (TFValues[i] == Period()) TFLabelBackColor = clrLightSteelBlue;

            if (IndCurr[i] == 1)
            {
                IndCurrText = CharToString(225); // Up arrow.
                IndCurrToolTip = "MACD Above Zero";
                IndCurrBackColor = clrDarkGreen;
                IndCurrTextColor = clrWhite;
            }
            else if (IndCurr[i] == -1)
            {
                IndCurrText = CharToString(226); // Down arrow.
                IndCurrToolTip = "MACD Below Zero";
                IndCurrBackColor = clrDarkRed;
                IndCurrTextColor = clrWhite;
            }
            if (IndPrevDiff[i] == 1)
            {
                IndPrevDiffText = CharToString(225); // Up arrow.
                IndPrevDiffToolTip = "Current MACD Above Previous MACD";
                IndPrevDiffBackColor = clrDarkGreen;
                IndPrevDiffTextColor = clrWhite;
            }
            else if (IndPrevDiff[i] == -1)
            {
                IndPrevDiffText = CharToString(226); // Down arrow.
                IndPrevDiffToolTip = "Current MACD Below Previous MACD";
                IndPrevDiffBackColor = clrDarkRed;
                IndPrevDiffTextColor = clrWhite;
            }

            if (IndCurrAdd[i] == 1)
            {
                IndCurrAddText = CharToString(225); // Up arrow.
                IndCurrAddToolTip = "Currently MACD Line Above Signal Line";
                IndCurrAddBackColor = clrDarkGreen;
                IndCurrAddTextColor = clrWhite;
            }
            else if (IndCurrAdd[i] == -1)
            {
                IndCurrAddText = CharToString(226); // Down arrow.
                IndCurrAddToolTip = "Currently MACD Line Below Signal Line";
                IndCurrAddBackColor = clrDarkRed;
                IndCurrAddTextColor = clrWhite;
            }

            int RowY = BaseY + MulY * ((PanelMovY + 1) * Rows + 2);

            DrawEdit(TFRowObj,
                     BaseX + MulX * 2,
                     RowY,
                     PanelMovX,
                     PanelLabY,
                     true,
                     8,
                     "Situation Detected in the Timeframe",
                     ALIGN_CENTER,
                     "Consolas",
                     TFRowText,
                     false,
                     clrNavy,
                     TFLabelBackColor,
                     clrBlack);
            ObjectSetInteger(0, TFRowObj, OBJPROP_CORNER, PanelCorner);

            DrawEdit(IndCurrObj,
                     BaseX + MulX * (PanelMovX + 4),
                     RowY,
                     PanelMovX,
                     PanelLabY,
                     true,
                     8,
                     IndCurrToolTip,
                     ALIGN_CENTER,
                     "Wingdings",
                     IndCurrText,
                     false,
                     IndCurrTextColor,
                     IndCurrBackColor,
                     clrBlack);
            ObjectSetInteger(0, IndCurrObj, OBJPROP_CORNER, PanelCorner);

            DrawEdit(IndPrevDiffObj,
                     BaseX + MulX * (PanelMovX * 2 + 6),
                     RowY,
                     PanelMovX,
                     PanelLabY,
                     true,
                     8,
                     IndPrevDiffToolTip,
                     ALIGN_CENTER,
                     "Wingdings",
                     IndPrevDiffText,
                     false,
                     IndPrevDiffTextColor,
                     IndPrevDiffBackColor,
                     clrBlack);
            ObjectSetInteger(0, IndPrevDiffObj, OBJPROP_CORNER, PanelCorner);

            DrawEdit(IndCurrAddObj,
                     BaseX + MulX * (PanelMovX * 3 + 8),
                     RowY,
                     PanelMovX,
                     PanelLabY,
                     true,
                     8,
                     IndCurrAddToolTip,
                     ALIGN_CENTER,
                     "Wingdings",
                     IndCurrAddText,
                     false,
                     IndCurrAddTextColor,
                     IndCurrAddBackColor,
                     clrBlack);
            ObjectSetInteger(0, IndCurrAddObj, OBJPROP_CORNER, PanelCorner);

            Rows++;
        }
        string SigText = "";
        color SigColor = clrNavy;
        color SigBack = clrKhaki;
        if (Positive)
        {
            SigText = "Rising";
            SigColor = clrWhite;
            SigBack = clrDarkGreen;
        }
        if (Negative)
							   
        {
            SigText = "Falling";
            SigColor = clrWhite;
            SigBack = clrDarkRed;
        }
        if (!Positive && !Negative)
        {
            SigText = "Uncertain";
        }

        DrawEdit(PanelSig,
                 BaseX + MulX * 2,
                 BaseY + MulY * ((PanelMovY + 1) * Rows + 2),
                 PanelLabX,
                 PanelLabY,
                 true,
                 8,
                 "Situation Considering All Timeframes",
                 ALIGN_CENTER,
                 "Consolas",
                 SigText,
                 false,
                 SigColor,
                 SigBack,
                 clrBlack);
        ObjectSetInteger(0, PanelSig, OBJPROP_CORNER, PanelCorner);

        Rows++;
    }

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}
//+------------------------------------------------------------------+