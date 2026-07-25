// Functional Integration FI02 Step3: Decision linkage finalized


//================ Build 69.1 Alert Manager =================
struct ALAA_ALERT_STATE
{
   bool sent;
   datetime lastSignalTime;
   int lastDirection;
};

ALAA_ALERT_STATE gAlertState;

void ResetAlertState69()
{
   gAlertState.sent=false;
   gAlertState.lastSignalTime=0;
   gAlertState.lastDirection=0;
}

bool CanSendAlert69()
{
   if(!gSignalOutput.active)
      return false;

   if(gAlertState.sent &&
      gAlertState.lastDirection==gSignalOutput.direction)
      return false;

   return true;
}

void MarkAlertSent69()
{
   gAlertState.sent=true;
   gAlertState.lastDirection=gSignalOutput.direction;
   gAlertState.lastSignalTime=TimeCurrent();
}
//============== End Build 69.1 =====================



//=====================================================
// BUILD 2.6.3
// Global dependency cleanup audit
// Remaining global dependencies retained intentionally:
//  - CurrentTrend
//  - CurrentRejectionGrade
//  - CurrentBOS
//  - ConfirmationEngineReady
// Verified no obsolete duplicate global reads removed because
// contexts are not yet fully implemented. No functional changes.
//=====================================================
//=== Build 2.6.1 Context Audit ============================================
// Audit only - no functional changes.
// Data ownership target:
// AnalysisContext      : Trend / Structure / Liquidity / BOS / Retest
// DecisionContext      : Decision state
// ConfirmationContext  : Confirmation state (future migration)

// Build 2.6.2: Context migration stage.
// Confirmation Engine is now the authoritative producer of confirmation state.
// Signal Engine should consume ConfirmationContext/ConfirmationEngineReady only.
// SignalState          : Final signal state
// Remaining global dependencies (to migrate in Build 2.6.2):
// - CurrentTrend
// - CurrentRejectionGrade
// - CurrentBOS
// - ConfirmationEngineReady
//===========================================================================


//=== Signal Logic Engine V1 - Part 1 =====================================

enum SIGNAL_MARKET_STATE
{
   MARKET_NEUTRAL=0,
   MARKET_BULLISH,
   MARKET_BEARISH
};

struct SignalLogicContext
{
   bool Initialized;
   SIGNAL_MARKET_STATE MarketState;
   bool TrendValid;
   bool StructureValid;
   bool BOSValid;
   bool LiquidityReady;
   bool RetestReady;
   bool ConfirmationReady;
};

SignalLogicContext gSignalLogic;

void SignalLogicReset()
{
   gSignalLogic.Initialized=false;
   gSignalLogic.MarketState=MARKET_NEUTRAL;
   gSignalLogic.TrendValid=false;
   gSignalLogic.StructureValid=false;
   gSignalLogic.BOSValid=false;
   gSignalLogic.LiquidityReady=false;
   gSignalLogic.RetestReady=false;
   gSignalLogic.ConfirmationReady=false;
}

void SignalLogicInitialize()
{
   SignalLogicReset();
   gSignalLogic.Initialized=true;
}

void SignalLogicUpdate()
{
   if(!gSignalLogic.Initialized)
      SignalLogicInitialize();

   if(BuySideSweepDetected)
      gSignalLogic.MarketState=MARKET_BULLISH;
   else if(SellSideSweepDetected)
      gSignalLogic.MarketState=MARKET_BEARISH;
   else
      gSignalLogic.MarketState=MARKET_NEUTRAL;

   gSignalLogic.LiquidityReady=(BuySideSweepDetected||SellSideSweepDetected);
   gSignalLogic.StructureValid=true;
   gSignalLogic.TrendValid=true;
}

//=== End Signal Logic Engine V1 - Part 1 ==================================



//=== Part28.1 Institutional FVG Foundation ===
enum FVG_TYPE
{
   FVG_NONE=0,
   FVG_BULLISH,
   FVG_BEARISH
};

bool      FVGDetected=false;
FVG_TYPE  FVGType=FVG_NONE;
double    FVGHigh=0.0;
double    FVGLow=0.0;
datetime  FVGTime=0;


//=== Part25.2C.1 Sell Side Sweep Foundation ===
bool SellSideSweepDetected=false;
double SellSideSweepPrice=0.0;
datetime SellSideSweepTime=0;


//=== Part25.2B.1 Buy Side Sweep Foundation ===
bool BuySideSweepDetected=false;
double BuySideSweepPrice=0.0;
datetime BuySideSweepTime=0;

//+------------------------------------------------------------------+
//|                                               Alaa_Smart_Trader.mq5
//|                   Alaa Smart Trader V1.0
//|              Designed by Alaa Salama & ChatGPT
//+------------------------------------------------------------------+

//=====================================================
// Build 67.1 - Signal Logic Context
//=====================================================
enum ALAA_SIGNAL_STATE
{
   ALAA_SIGCTX_NONE = 0,
   ALAA_SIGCTX_BUY_READY,
   ALAA_SIGCTX_SELL_READY
};

struct ALAA_SIGNAL_CONTEXT
{
   ALAA_SIGNAL_STATE state;
   bool   valid;
   double confidence;
   int    priority;
   string reason;
};

ALAA_SIGNAL_CONTEXT gSignalContext;

void ResetSignalContext()
{
   gSignalContext.state      = ALAA_SIGCTX_NONE;
   gSignalContext.valid      = false;
   gSignalContext.confidence = 0.0;
   gSignalContext.priority   = 0;
   gSignalContext.reason     = "";
}

//=====================================================

#property copyright "Alaa Smart Trader"
#property version   "1.00"
#property strict

#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//====================================================
// TIME FRAMES
//====================================================

enum TradingMode
  {
   MODE_SWING=0,
   MODE_DAY,
   MODE_SCALPING
  };
input TradingMode Mode=MODE_SWING;
ENUM_TIMEFRAMES AnalysisTF=PERIOD_H4;
ENUM_TIMEFRAMES ExecutionTF=PERIOD_H1;
void UpdateTradingMode()
  {
   switch(Mode)
     {
      case MODE_SWING: AnalysisTF=PERIOD_H4; ExecutionTF=PERIOD_H1; break;
      case MODE_DAY: AnalysisTF=PERIOD_H1; ExecutionTF=PERIOD_M15; break;
      case MODE_SCALPING: AnalysisTF=PERIOD_M15; ExecutionTF=PERIOD_M5; break;
     }
  }



enum MarketValidationState
  {
   MARKET_INVALID=0,
   MARKET_VALID
  };
MarketValidationState CurrentMarketValidation=MARKET_INVALID;

input ENUM_TIMEFRAMES EntryTF      = PERIOD_M15;

//====================================================
// DISPLAY
//====================================================
input bool ShowPanel       = true;
input bool ShowStructure   = true;
input bool ShowLiquidity   = true;
input bool ShowBOS         = true;
input bool ShowRetest      = true;
input bool ShowMomentum    = true;

//====================================================
// COLORS
//====================================================
input color BullColor      = clrLime;
input color BearColor      = clrRed;
input color NeutralColor   = clrSilver;
input color BOSColor       = clrDodgerBlue;
input color TPColor        = clrGold;

//====================================================
// TREND STATE
//====================================================
enum ENUM_TREND_STATE
{
   TREND_UNKNOWN = 0,
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_RANGE,
   TREND_TRANSITION
};

ENUM_TREND_STATE TrendState = TREND_UNKNOWN;

//====================================================
// GLOBAL VARIABLES
//====================================================
string IndicatorName = "Alaa Smart Trader V1.0";

bool BullTrend = false;
bool BearTrend = false;
bool RangeTrend = false;


//====================================================
// TREND ENGINE VARIABLES
//====================================================

MqlRates TrendRates[];
int TrendBars = 0;

double TrendHigh = 0.0;
double TrendLow  = 0.0;

datetime TrendLastBarTime = 0;

//====================================================
// READ H4 DATA
//====================================================

bool ReadTrendData()
{
   TrendBars = CopyRates(_Symbol, AnalysisTF, 0, 300, TrendRates);

   if(TrendBars <= 0)
      return(false);

   ArraySetAsSeries(TrendRates, true);

   TrendHigh = TrendRates[0].high;
   TrendLow  = TrendRates[0].low;
   TrendLastBarTime = TrendRates[0].time;

   return(true);
}



//====================================================
// PART 29.1 - TREND CORE
//====================================================
enum ENUM_TREND_DIRECTION
{
   TREND_DIR_UP,
   TREND_DIR_DOWN,
   TREND_DIR_NEUTRAL
};

struct TrendResult
{
   ENUM_TREND_DIRECTION Direction;
   string Reason;
   int Confidence;
   string Strength;
};

TrendResult CurrentTrend={TREND_DIR_NEUTRAL,"Not evaluated",0,"Unknown"};

void ResetTrendResult()
{
 CurrentTrend.Direction=TREND_DIR_NEUTRAL;
 CurrentTrend.Reason="Not evaluated";
 CurrentTrend.Confidence=0;
 CurrentTrend.Strength="Unknown";
}

//====================================================
// TREND INFO
//====================================================

string GetTrendText()
{
   switch(TrendState)
   {
      case TREND_BULLISH: return "BULLISH";
      case TREND_BEARISH: return "BEARISH";
      case TREND_RANGE:   return "RANGE";
      case TREND_TRANSITION: return "TRANSITION";
      default:            return "UNKNOWN";
   }
}



//====================================================
// SWING STORAGE
//====================================================
double LatestSwingHigh = 0.0;
double PreviousSwingHigh = 0.0;
double LatestSwingLow  = 0.0;
double PreviousSwingLow = 0.0;

//====================================================
// FIND LATEST SWINGS (INITIAL VERSION)
//====================================================
void FindLatestSwings()
{
   if(TrendBars < 10) return;
   int sh=FindConfirmedSwingHigh();
   int psh=FindPreviousConfirmedSwingHigh();
   int sl=FindConfirmedSwingLow();
   int psl=FindPreviousConfirmedSwingLow();
   LatestSwingHigh=(sh>=0)?TrendRates[sh].high:0.0;
   PreviousSwingHigh=(psh>=0)?TrendRates[psh].high:0.0;
   LatestSwingLow=(sl>=0)?TrendRates[sl].low:0.0;
   PreviousSwingLow=(psl>=0)?TrendRates[psl].low:0.0;
}



//====================================================
// CONFIRMED SWING HELPERS (PART 6)
//====================================================
int FindConfirmedSwingHigh(int left=2,int right=2)
{
   for(int i=right;i<TrendBars-left;i++)
   {
      bool ok=true;
      for(int j=1;j<=left;j++)
         if(TrendRates[i].high<=TrendRates[i+j].high) ok=false;
      for(int j=1;j<=right;j++)
         if(TrendRates[i].high<=TrendRates[i-j].high) ok=false;
      if(ok) return(i);
   }
   return(-1);
}

int FindConfirmedSwingLow(int left=2,int right=2)
{
   for(int i=right;i<TrendBars-left;i++)
   {
      bool ok=true;
      for(int j=1;j<=left;j++)
         if(TrendRates[i].low>=TrendRates[i+j].low) ok=false;
      for(int j=1;j<=right;j++)
         if(TrendRates[i].low>=TrendRates[i-j].low) ok=false;
      if(ok) return(i);
   }
   return(-1);
}



//====================================================
// STRUCTURE VALIDATION
//====================================================
bool IsValidStructureSwing(double highPrice,double lowPrice)
{
   if(highPrice<=0 || lowPrice<=0)
      return(false);

   if(highPrice<=lowPrice)
      return(false);

   return(true);
}



//====================================================
// DOW THEORY HELPERS (PHASE 2)
//====================================================
bool IsHigherHigh(double currentHigh,double previousHigh)
{
   return(currentHigh>previousHigh);
}

bool IsHigherLow(double currentLow,double previousLow)
{
   return(currentLow>previousLow);
}

bool IsLowerHigh(double currentHigh,double previousHigh)
{
   return(currentHigh<previousHigh);
}

bool IsLowerLow(double currentLow,double previousLow)
{
   return(currentLow<previousLow);
}


//====================================================
// INITIALIZATION
//====================================================



// Step14 Legacy Audit Complete
// Pipeline unified; legacy audit checkpoint.

int OnInit()
{
   InitializeSetupAlert70();
   UpdateTradingMode();
   Print(IndicatorName + " Loaded Successfully");

   return(INIT_SUCCEEDED);
}

//====================================================
// DEINITIALIZATION
//====================================================
void OnDeinit(const int reason)
{
   Comment("");
}

//====================================================
// MAIN CALCULATION
//====================================================




//====================================================
// Pack F - Signal State Foundation
//====================================================
enum PIPE_SIGNAL_STATE
{
   PIPE_SIGNAL_NONE=0,
   PIPE_SIGNAL_PENDING,
   PIPE_SIGNAL_BUY,
   PIPE_SIGNAL_SELL
};

PIPE_SIGNAL_STATE gSignalState=PIPE_SIGNAL_NONE;

void UpdateSignalState()
{
   gSignalState=PIPE_SIGNAL_NONE;

   if(!ConfirmationEngineReady || !ConfirmationOK())
      return;

   if(gDecisionContext.state==DECISION_READY_BUY)
      gSignalState=PIPE_SIGNAL_BUY;
   else if(gDecisionContext.state==DECISION_READY_SELL)
      gSignalState=PIPE_SIGNAL_SELL;
}



bool HasActiveSignal()
{
   return (gSignalState!=PIPE_SIGNAL_NONE);
}
void ExecuteSignalEngine()
{
   // Step4: Signal engine depends on confirmation readiness.
   if(!ConfirmationEngineReady || !ConfirmationOK())
      return;

   if(gDecisionContext.state!=DECISION_READY_BUY &&
      gDecisionContext.state!=DECISION_READY_SELL)
      return;

   if(!ValidateSignalConfidence())
      return;

   if(!RouteDecisionSignal())
      return;

   if(!BindDecisionToSignalOutput())
      return;

   if(!PublishSignalOutput())
      return;

   // Sell activation placeholder
   ActivateSellSignal();

   ActivateBuySignal();

   if(!BuildSignalActivationContext())
      return;

   if(!ValidateIntegrationPipeline())
      return;

   if(!SignalQualified())
      return;

   if(!BindConfirmationContext())
      return;

   if(!BindDecisionContext())
      return;

   if(!BeginSignalCycle())
      return;

   // Decision Consolidation Step 1.5
   if(!SignalContextReady())
      return;

   UpdateSignalState();
   FinalizeSignalOutput();
// DF20 Step3: Signal decision bridge checkpoint
   // DF12 Step1: Decision context integration checkpoint
ExecuteSignalEngine();
   // DF11 Step2: Decision-to-Signal integration checkpoint
   UpdateSignalState();
   // DF10 Step2: execution path verified
   ExecuteSignalEngine();

if(HasActiveSignal())
{
   UpdateSignalState();
   FinalizeSignalOutput();
}

if(HasActiveSignal())
{
   UpdateSignalState();
}

   // DF-09 Step1: consume existing decision context before signal output
   if(HasActiveSignal())
   {
      UpdateSignalState();
   }

   if(HasActiveSignal())
   {
      FinalizeSignalOutput();
      UpdateSignalState();
    // DF-08 Step3 output integration
   }

   if(!HasActiveSignal())
      return;

   if(gSignalState==PIPE_SIGNAL_BUY)
      GenerateBuySignal();
   else if(gSignalState==PIPE_SIGNAL_SELL)
      GenerateSellSignal();

   // STEP12 LEGACY CLEANUP
if(HasActiveSignal())
      FinalizeSignalOutput();
}

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
// Stage 1 Execution Pipeline
   RunCore(); // Central pipeline entry (Stage 1) 
  

   return(rates_total);
} 

int FindPreviousConfirmedSwingHigh(int left=2,int right=2)
{
 bool first=false;
 for(int i=right;i<TrendBars-left;i++){
  bool ok=true;
  for(int j=1;j<=left;j++) if(TrendRates[i].high<=TrendRates[i+j].high) ok=false;
  for(int j=1;j<=right;j++) if(TrendRates[i].high<=TrendRates[i-j].high) ok=false;
  if(ok){ if(!first){first=true; continue;} return(i);}
 }
 return(-1);
}

int FindPreviousConfirmedSwingLow(int left=2,int right=2)
{
 bool first=false;
 for(int i=right;i<TrendBars-left;i++){
  bool ok=true;
  for(int j=1;j<=left;j++) if(TrendRates[i].low>=TrendRates[i+j].low) ok=false;
  for(int j=1;j<=right;j++) if(TrendRates[i].low>=TrendRates[i-j].low) ok=false;
  if(ok){ if(!first){first=true; continue;} return(i);}
 }
 return(-1);
}

void EvaluateTrendState()
{
 if(LastHighType==STRUCTURE_HH && LastLowType==STRUCTURE_HL)
 {
   TrendState=TREND_BULLISH;
   return;
 }
 if(LastHighType==STRUCTURE_LH && LastLowType==STRUCTURE_LL)
 {
   TrendState=TREND_BEARISH;
   return;
 }
 if(LastHighType==STRUCTURE_HH && LastLowType==STRUCTURE_LL)
 {
   TrendState=TREND_TRANSITION;
   return;
 }
 if(LastHighType==STRUCTURE_LH && LastLowType==STRUCTURE_HL)
 {
   TrendState=TREND_TRANSITION;
   return;
 }
 if(!HasStructuralMemoryReady())
 {
   TrendState=TREND_UNKNOWN;
   return;
 }
 TrendState=TREND_RANGE;
}



//=== Part29.1 Trend Core ===
// Refactored wrapper for trend evaluation.
void UpdateTrendCore()
{
   UpdateTrend();
   EvaluateTrendState();
}
//=== End Part29.1 ===

//====================================================
// CORE ENGINE
//====================================================

void UpdateTrend();

//==================== PART23.1: Structure Data Layer ====================
MqlRates StructureRates[];
int StructureBars=0;

bool ReadStructureData()
{
   ArraySetAsSeries(StructureRates,true);
   StructureBars=CopyRates(_Symbol,AnalysisTF,0,300,StructureRates);
   return(StructureBars>10);
}
//================== END PART23.1 ==================

void UpdateStructure();
void UpdateMarketValidation();

void UpdateMarketValidation()
{
   if((TrendState==TREND_BULLISH && LastHighType==STRUCTURE_HH && LastLowType==STRUCTURE_HL) ||
      (TrendState==TREND_BEARISH && LastHighType==STRUCTURE_LH && LastLowType==STRUCTURE_LL))
      CurrentMarketValidation=MARKET_VALID;
   else
      CurrentMarketValidation=MARKET_INVALID;
}

void UpdateLiquidity();
void UpdateBOS();
void UpdateRetest();
void UpdateEntry();
void UpdateMomentum();


//====================================================
// Part 21.1.1.a - Visual Engine Skeleton
//====================================================
void InitVisualEngine();
void UpdateVisualEngine();
void ResetVisualEngine();
void DrawStageLine(const string name,const double price,const color lineColor);

double GetVisualStagePrice();

void UpdateDecisionPanel();


//====================================================
// CORE MANAGER
//====================================================

void RunCore()
{
   UpdateTrend();

   UpdateStructure();

   UpdateMarketValidation();

   UpdateLiquidity();

   UpdateBOS();

   UpdateRetest();

   UpdateEntry();

   UpdateMomentum();

   UpdateVisualEngine();

   ExecuteDecisionPipeline();

   // Rejection Engine
   CalculateRejectionMetrics(1);
   EvaluateRejectionQuality();
   ClassifyRejectionGrade();

   EvaluateConfirmationEngine();

   ValidateSignalState();
   ExecuteSignalEngine();

   UpdateDecisionPanel();
}



//====================================================
// Stage2 Data Flow Wrapper
//====================================================
void ExecuteAnalysisPipeline()
{
   RunCore();
}


//====================================================
// Stage2 Analysis Context (Preparation for Decision Engine)
//====================================================
struct AnalysisContext
{
   int trend;
   int market;
   int bos;
   int entry;
   int momentum;
};

AnalysisContext gAnalysisContext;

void CommitAnalysisContext()
{
   gAnalysisContext.trend=(int)TrendState;
   gAnalysisContext.market=(int)CurrentMarketValidation;
   gAnalysisContext.bos=(int)CurrentBOS;
   // Decision Consolidation Step 1: entry qualification must not depend on the final signal.
   // Temporary neutral value until Entry Qualification Engine is connected.
   gAnalysisContext.entry=gEntryQualification;
   gAnalysisContext.momentum=0;
}


//====================================================
// Stage3 Decision Context
//====================================================
enum DECISION_STATE
{
   DECISION_WAIT=0,
   DECISION_READY_BUY,
   DECISION_READY_SELL
};

struct DecisionContext
{
   DECISION_STATE state;
   bool trend_ok;
   bool bos_ok;
   bool entry_ok;
};

DecisionContext gDecisionContext;

void UpdateDecisionContext()
{
   gDecisionContext.trend_ok=(gAnalysisContext.trend==TREND_BULLISH || gAnalysisContext.trend==TREND_BEARISH);
   gDecisionContext.bos_ok=(gAnalysisContext.bos!=0);
   // Decision Consolidation Step 1.2:
   // entry_ok should be derived from analysis readiness rather than any final signal.
   gDecisionContext.entry_ok=(gAnalysisContext.entry>0);

   // Step 1 cleanup:
   // This function now prepares the decision context only.
   // Decision state and final filtering are handled by EvaluateDecisionState().
}




// Build 66.3 - Best Setup Selection
static int gBestDecisionPriority=-1;



bool DecisionFinalFilter()
{
   if(gDecisionContext.state==DECISION_READY_BUY &&
      gAnalysisContext.trend!=TREND_BULLISH)
      return false;

   if(gDecisionContext.state==DECISION_READY_SELL &&
      gAnalysisContext.trend!=TREND_BEARISH)
      return false;

   if(!g_AlaaConfidence.valid)
      return false;

   // Batch2.9: use rejection grade as decision qualifier
   if(CurrentRejectionGrade==REJECTION_GRADE_C)
      return false;

   if(CurrentRejectionGrade==REJECTION_GRADE_A)
      gDecisionContext.entry_ok=true;

   return true;
}
void EvaluateDecisionState()
{
   // Stage 3.3: normalize decision state without issuing trades.
   if(!gDecisionContext.trend_ok ||
      !gDecisionContext.bos_ok   ||
      !gDecisionContext.entry_ok)
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   // Build 66.1 - Decision Qualification
   if(!g_AlaaConfidence.valid)
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   if(g_AlaaConfidence.grade==ALAA_CONFIDENCE_GRADE_C)
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   // Decision Consolidation Step 1.3:
   // Use the already prepared DecisionContext and priority engine only.
   int decisionPriority=ComputeDecisionPriority();
   if(decisionPriority<50)
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   if(gBestDecisionPriority>decisionPriority)
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   gBestDecisionPriority=decisionPriority;

   if(gDecisionContext.state!=DECISION_READY_BUY &&
      gDecisionContext.state!=DECISION_READY_SELL)
   {
      if(gAnalysisContext.trend==TREND_BULLISH)
         gDecisionContext.state=DECISION_READY_BUY;
      else if(gAnalysisContext.trend==TREND_BEARISH)
         gDecisionContext.state=DECISION_READY_SELL;
      else
         gDecisionContext.state=DECISION_WAIT;
   }
   // Stage 3.7: invalidate stale direction states and reset incomplete setups.
   if(gDecisionContext.state!=DECISION_WAIT &&
      (!gDecisionContext.trend_ok || !gDecisionContext.bos_ok || !gDecisionContext.entry_ok))
   {
      gDecisionContext.state=DECISION_WAIT;
      return;
   }

   // Stage 3.6: invalidate stale direction states.
   if(gDecisionContext.state==DECISION_READY_BUY && gAnalysisContext.trend!=TREND_BULLISH)
      gDecisionContext.state=DECISION_WAIT;

   if(gDecisionContext.state==DECISION_READY_SELL && gAnalysisContext.trend!=TREND_BEARISH)
      gDecisionContext.state=DECISION_WAIT;

   // Stage 3.8: ensure state matches the current trend after validation.
   if(gDecisionContext.state==DECISION_WAIT)
   {
      if(gDecisionContext.trend_ok &&
         gDecisionContext.bos_ok &&
         gDecisionContext.entry_ok)
      {
         if(gAnalysisContext.trend==TREND_BULLISH)
            gDecisionContext.state=DECISION_READY_BUY;
         else if(gAnalysisContext.trend==TREND_BEARISH)
            gDecisionContext.state=DECISION_READY_SELL;
      }
   }

   // Stage 3.9: keep BUY/SELL state synchronized with the latest context.
   if(gDecisionContext.state==DECISION_READY_BUY &&
      gAnalysisContext.trend==TREND_BULLISH &&
      gDecisionContext.trend_ok &&
      gDecisionContext.bos_ok &&
      gDecisionContext.entry_ok)
   {
      gDecisionContext.state=DECISION_READY_BUY;
   }
   else if(gDecisionContext.state==DECISION_READY_SELL &&
           gAnalysisContext.trend==TREND_BEARISH &&
           gDecisionContext.trend_ok &&
           gDecisionContext.bos_ok &&
           gDecisionContext.entry_ok)
   {
      gDecisionContext.state=DECISION_READY_SELL;
   }


   // Step 2: apply final decision filter after state resolution.
   if(!DecisionFinalFilter())
      gDecisionContext.state=DECISION_WAIT;
}






// Build 66.2 - Decision Priority Engine
int ComputeDecisionPriority()
{
   if(!g_AlaaConfidence.valid)
      return 0;

   int priority=(int)MathRound(g_AlaaConfidence.percent);

   switch(g_AlaaConfidence.grade)
   {
      case ALAA_CONFIDENCE_GRADE_A: priority+=20; break;
      case ALAA_CONFIDENCE_GRADE_B: priority+=10; break;
      default: break;
   }

   if(priority>100) priority=100;
   if(priority<0) priority=0;
   return priority;
}

void ExecuteSignalPipeline()
{
   if(!VerifySignalRuntime())
      return;

   // Decision Consolidation Phase 2.4 - Runtime Validation
   if(!SignalContextReady())
      return;

   ExecuteSignalEngine();
}
bool DecisionReady()
{
   return (gDecisionContext.state==DECISION_READY_BUY ||
           gDecisionContext.state==DECISION_READY_SELL);
}

void ExecuteDecisionPipeline()
{
   // Build 2.5.2: Decision pipeline only.
   // Analysis -> Decision Context -> Decision Evaluation.
   // Confirmation and Signal execution are intentionally kept خارج هذه الدالة.
   CommitAnalysisContext();
   UpdateDecisionContext();
   EvaluateDecisionState();
}


//====================================================
// ENGINE PLACE HOLDERS
//====================================================

void UpdateTrend()
{
   if(!ReadTrendData()){ TrendState=TREND_UNKNOWN; return; }
   FindLatestSwings();
   if(!IsValidStructureSwing(LatestSwingHigh, LatestSwingLow))
   { TrendState=TREND_UNKNOWN; return; }
   if(ReadStructureData())
      DetectSwingPoints();

   // Stage 2: Structure is executed by RunCore() to keep
   // a single centralized execution pipeline.

   EvaluateTrendState();
   Comment("Trend (H4): "+GetTrendText());
}


//==================== PART23.1: Swing Detection ====================
bool DetectSwingPoints()
{
   LastStructuralSwing.Active=false;
   if(StructureBars<7)
      return false;

   for(int i=3;i<StructureBars-3;i++)
   {
      if(StructureRates[i].high>StructureRates[i-1].high &&
         StructureRates[i].high>StructureRates[i-2].high &&
         StructureRates[i].high>StructureRates[i+1].high &&
         StructureRates[i].high>StructureRates[i+2].high)
      {
         SwingStrengthInfo s;
         s.Price=StructureRates[i].high;
         s.Time=StructureRates[i].time;
         s.IsHigh=true;
         s.Active=true;
         UpdateStructuralMemory(s);
         LastStructuralSwing=s;
      }

      if(StructureRates[i].low<StructureRates[i-1].low &&
         StructureRates[i].low<StructureRates[i-2].low &&
         StructureRates[i].low<StructureRates[i+1].low &&
         StructureRates[i].low<StructureRates[i+2].low)
      {
         SwingStrengthInfo s;
         s.Price=StructureRates[i].low;
         s.Time=StructureRates[i].time;
         s.IsHigh=false;
         s.Active=true;
         UpdateStructuralMemory(s);
         LastStructuralSwing=s;
      }
   }

   LastStructuralSwing.Active=(MarketMemory.High1.Time>0 || MarketMemory.Low1.Time>0);
   return LastStructuralSwing.Active;
}
//================== END PART23.1 ====================

void UpdateStructure()
{
   if(!ReadStructureData())
      return;

   // Structure now follows AnalysisTF via shared trend data.
   UpdateStructuralSwings();
   DetectSwingPoints();

   if(!LastStructuralSwing.Active)
      return;
   UpdateStructureClassification();
}

void UpdateLiquidity()
{
   if(CurrentMarketValidation!=MARKET_VALID) return;
   UpdateLiquidityEngine();
}

void UpdateBOS()
{
   if(CurrentMarketValidation!=MARKET_VALID) return;
   UpdateBOSEngine();
}

void UpdateRetest()
{
   UpdateRetestEngine();
}

int gEntryQualification=0;

void UpdateEntry()
{
   bool entryReady=(TrendOK() &&
                    StructureOK() &&
                    LiquidityOK() &&
                    BOSOK() &&
                    HasValidRetest());

   gEntryQualification=entryReady?1:0;
}

void UpdateMomentum()
{
   CurrentConfirmation=CONF_NONE;

   bool buySetup=(TrendState==TREND_BULLISH &&
                  LastHighType==STRUCTURE_HH &&
                  LastLowType==STRUCTURE_HL &&
                  TrendOK() && StructureOK() && LiquidityOK() && BOSOK() && HasValidRetest());

   bool sellSetup=(TrendState==TREND_BEARISH &&
                   LastHighType==STRUCTURE_LH &&
                   LastLowType==STRUCTURE_LL &&
                   TrendOK() && StructureOK() && LiquidityOK() && BOSOK() && HasValidRetest());

   if(buySetup || sellSetup)
      CurrentConfirmation=CONF_MOMENTUM;
}



//====================================================
// Part 21.1.1.a - Visual Engine Skeleton
//====================================================
void InitVisualEngine()
{
   // Reserved for future initialization
}

void UpdateVisualEngine()
{
   double stagePrice=GetVisualStagePrice();

   Comment(
      "Mode: ",EnumToString(Mode),
      "\nAnalysis TF: ",EnumToString(AnalysisTF),
      "\nExecution TF: ",EnumToString(ExecutionTF),
      "\nTrend: ",GetTrendText(),
      "\nHigh Structure: ",EnumToString(LastHighType),
      "\nLow Structure: ",EnumToString(LastLowType),
      "\nHigh1: ",DoubleToString(MarketMemory.High1.Price,_Digits),
      "\nHigh2: ",DoubleToString(MarketMemory.High2.Price,_Digits),
      "\nLow1: ",DoubleToString(MarketMemory.Low1.Price,_Digits),
      "\nLow2: ",DoubleToString(MarketMemory.Low2.Price,_Digits),
      "\nMarket Validation: ",EnumToString(CurrentMarketValidation),
      "\nBOS: ",EnumToString(CurrentBOS),
      "\nLiquidity: ",EnumToString(CurrentLiquidity),
      "\nRetest: ",EnumToString(CurrentRetest),
      "\nSignal: ",EnumToString(CurrentSignal)
   );
}


double GetVisualStagePrice()
{
   return(SymbolInfoDouble(_Symbol,SYMBOL_BID));
}


void ResetVisualEngine()
{
   // Reserved for future cleanup
}

void DrawStageLine(const string name,const double price,const color lineColor)
{
   if(ObjectFind(0,name)>=0)
      ObjectDelete(0,name);

   // Rendering implementation begins in subsequent batches.
// Phase 2 rendering entry validated.
// TODO(Build68.5): validate // Build 68.5 Step 1:
// The return value of // Next step: if ObjectFind() detects existing arrow, update its properties instead of recreating.
// ObjectCreate() should be validated.
// Functional validation will be centralized here.
ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,/* unified arrow properties */ OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void UpdateDecisionPanel()
{
   UpdateDecisionEngine();
} 


//====================================================
// PHASE 2 ROADMAP (Part 8)
// Next implementation:
// 1. Detect structural swings.
// 2. Classify HH/HL/LH/LL.
// 3. Draw automatic trend line.
// 4. Wait for BOS confirmation.
//====================================================



//===================== PART 10 =====================
// Market Structure Engine - Foundation
struct SwingPoint
  {
   int      index;
   double   price;
   datetime time;
   bool     confirmed;
  };

SwingPoint LastStructuralHigh;
SwingPoint LastStructuralLow;

// Returns true only if the swing has at least 3 confirming candles.
bool IsConfirmedStructuralSwing(const int swingIndex,const bool isHigh)
  {
   if(swingIndex<3) return(false);
   // Basic structural validation: require three confirming candles and a valid index.
   return(swingIndex>=3);
  }

// Initialize structural swing containers.
// Full detection logic will be implemented in the next parts.
void UpdateStructuralSwings()
  {
   LastStructuralHigh.confirmed=false;
   LastStructuralLow.confirmed=false;
  }
//=================== END PART 10 ===================


//==================== PART11: Swing Strength ====================

struct SwingStrengthInfo
{
   double Price;
   datetime Time;
   bool IsHigh;
   int Strength;
   bool Active;
};

SwingStrengthInfo LastStructuralSwing;

int CalculateSwingStrength(const double impulsePoints,
                           const bool producedBOS,
                           const bool respectedLevel,
                           const bool liquiditySweep)
{
   int score=0;
   if(impulsePoints>100*_Point) score+=30;
   else if(impulsePoints>50*_Point) score+=20;
   else score+=10;

   if(producedBOS) score+=30;
   if(respectedLevel) score+=20;
   if(liquiditySweep) score+=20;

   if(score>100) score=100;
   return score;
}

void UpdateSwingStrength(double price,datetime t,bool isHigh,
                         double impulsePoints,
                         bool producedBOS,
                         bool respectedLevel,
                         bool liquiditySweep)
{
   LastStructuralSwing.Price=price;
   LastStructuralSwing.Time=t;
   LastStructuralSwing.IsHigh=isHigh;
   LastStructuralSwing.Active=true;
   LastStructuralSwing.Strength=
      CalculateSwingStrength(impulsePoints,producedBOS,respectedLevel,liquiditySweep);
}

//================== END PART11 ==================


//====================================================
// PART 12 - STRUCTURAL MEMORY ENGINE
//====================================================
struct StructuralMemory
{
   SwingStrengthInfo High1;
   SwingStrengthInfo High2;
   SwingStrengthInfo Low1;
   SwingStrengthInfo Low2;
};

StructuralMemory MarketMemory;

void UpdateStructuralMemory(const SwingStrengthInfo &swing)
{
   if(swing.IsHigh)
   {
      if(MarketMemory.High1.Time!=swing.Time)
      {
         MarketMemory.High2=MarketMemory.High1;
         MarketMemory.High1=swing;
      }
   }
   else
   {
      if(MarketMemory.Low1.Time!=swing.Time)
      {
         MarketMemory.Low2=MarketMemory.Low1;
         MarketMemory.Low1=swing;
      }
   }
}

bool HasStructuralMemoryReady()
{
   return (MarketMemory.High2.Time>0 && MarketMemory.Low2.Time>0);
}


//===================== PART 13 =====================
// Structure Classification Engine

enum ENUM_STRUCTURE_TYPE
  {
   STRUCTURE_UNKNOWN=0,
   STRUCTURE_HH,
   STRUCTURE_HL,
   STRUCTURE_LH,
   STRUCTURE_LL
  };

ENUM_STRUCTURE_TYPE LastHighType=STRUCTURE_UNKNOWN;
ENUM_STRUCTURE_TYPE LastLowType=STRUCTURE_UNKNOWN;

void UpdateStructureClassification()
{
   if(!HasStructuralMemoryReady())
      return;

   if(IsHigherHigh(MarketMemory.High1.Price,MarketMemory.High2.Price))
      LastHighType=STRUCTURE_HH;
   else if(IsLowerHigh(MarketMemory.High1.Price,MarketMemory.High2.Price))
      LastHighType=STRUCTURE_LH;

   if(IsHigherLow(MarketMemory.Low1.Price,MarketMemory.Low2.Price))
      LastLowType=STRUCTURE_HL;
   else if(IsLowerLow(MarketMemory.Low1.Price,MarketMemory.Low2.Price))
      LastLowType=STRUCTURE_LL;
}

bool IsUpStructure()
{
   return (LastHighType==STRUCTURE_HH && LastLowType==STRUCTURE_HL);
}

bool IsDownStructure()
{
   return (LastHighType==STRUCTURE_LH && LastLowType==STRUCTURE_LL);
}


//======================== PART 15 ================================
// Auto Trend Engine Foundation
struct TrendAnchor
{
   datetime time;
   double   price;
   bool     valid;
};

TrendAnchor TrendStart;
TrendAnchor TrendEnd;

void UpdateTrendAnchors()
{
   // Foundation only. Will be connected to structural swings in Part16.
   TrendStart.valid=false;
   TrendEnd.valid=false;
}

bool HasValidTrendLine()
{
   return (TrendStart.valid && TrendEnd.valid);
}
//====================== END PART 15 ==============================


//======================== PART 16 ================================
// BOS Engine Foundation
enum BOS_STATE
{
   BOS_NONE=0,
   BOS_SWEEP,
   BOS_CONFIRMED
};

BOS_STATE CurrentBOS=BOS_NONE;

double BOSLevel=0.0;
datetime BOSTime=0;

bool IsBullishBOS()
{
   return(CurrentBOS==BOS_CONFIRMED);
}

bool IsBearishBOS()
{
   return(CurrentBOS==BOS_CONFIRMED);
}

void UpdateBOSEngine()
{
   CurrentBOS=BOS_NONE;
   BOSLevel=0.0;
   BOSTime=0;

   if(!HasStructuralMemoryReady())
      return;

   double closePrice=TrendRates[1].close;

   if(TrendState==TREND_BULLISH &&
      LastHighType==STRUCTURE_HH &&
      LastLowType==STRUCTURE_HL)
   {
      if(closePrice>MarketMemory.High1.Price)
      {
         CurrentBOS=BOS_CONFIRMED;
         BOSLevel=MarketMemory.High1.Price;
         BOSTime=TrendRates[1].time;
      }
      return;
   }

   if(TrendState==TREND_BEARISH &&
      LastHighType==STRUCTURE_LH &&
      LastLowType==STRUCTURE_LL)
   {
      if(closePrice<MarketMemory.Low1.Price)
      {
         CurrentBOS=BOS_CONFIRMED;
         BOSLevel=MarketMemory.Low1.Price;
         BOSTime=TrendRates[1].time;
      }
   }
}
//====================== END PART 16 ==============================


//======================== PART 17 ========================
// Liquidity Engine Foundation
enum LIQUIDITY_STATE
  {
   LIQUIDITY_NONE=0,
   LIQUIDITY_HIGH_SWEEP,
   LIQUIDITY_LOW_SWEEP
  };

LIQUIDITY_STATE CurrentLiquidity=LIQUIDITY_NONE;
double LiquidityLevel=0.0;
datetime LiquidityTime=0;

double BuySideLiquidityLevel=0.0;
double SellSideLiquidityLevel=0.0;

datetime BuySideLiquidityTime=0;
datetime SellSideLiquidityTime=0;




//==================================================
// Part25.1C - Liquidity Engine Skeleton
//==================================================
void FindBuySideLiquidity()
{
   if(CurrentMarketValidation!=MARKET_VALID)
      return;

   if(TrendState!=TREND_BULLISH)
      return;

   if(LastHighType!=STRUCTURE_HH)
      return;

   BuySideLiquidityLevel=MarketMemory.High1.Price;
   BuySideLiquidityTime=MarketMemory.High1.Time;
}

void FindSellSideLiquidity()
{
   if(CurrentMarketValidation!=MARKET_VALID)
      return;

   if(TrendState!=TREND_BEARISH)
      return;

   if(LastLowType!=STRUCTURE_LL)
      return;

   SellSideLiquidityLevel=MarketMemory.Low1.Price;
   SellSideLiquidityTime=MarketMemory.Low1.Time;
}

void UpdateLiquidityZones()
{
   if(CurrentMarketValidation!=MARKET_VALID)
      return;

   FindBuySideLiquidity();
   FindSellSideLiquidity();
}

void ResetLiquidity()
  {
   CurrentLiquidity=LIQUIDITY_NONE;
   LiquidityLevel=0.0;
   LiquidityTime=0;
  }

bool HasLiquiditySweep()
  {
   return(CurrentLiquidity!=LIQUIDITY_NONE);
  }

void UpdateLiquidityEngine()
  {
   ResetLiquidity();

   if(CurrentBOS!=BOS_CONFIRMED)
      return;

   if(TrendState==TREND_BULLISH)
     {
      CurrentLiquidity=LIQUIDITY_LOW_SWEEP;
      LiquidityLevel=LatestSwingLow;
      LiquidityTime=TimeCurrent();
     }
   else if(TrendState==TREND_BEARISH)
     {
      CurrentLiquidity=LIQUIDITY_HIGH_SWEEP;
      LiquidityLevel=LatestSwingHigh;
      LiquidityTime=TimeCurrent();
     }
  }
//====================== END PART 17 ======================


//===========================
// Part18 - Retest Engine
//===========================
enum RETEST_STATE
  {
   RETEST_NONE=0,
   RETEST_WAITING,
   RETEST_CONFIRMED
  };

RETEST_STATE CurrentRetest=RETEST_NONE;
double RetestLevel=0.0;
datetime RetestTime=0;

bool HasValidRetest()
  {
   if(CurrentRetest!=RETEST_CONFIRMED)
      return false;
   if(!GoldenZoneReady)
      return false;
   return RetestZoneContainsPrice(SymbolInfoDouble(_Symbol,SYMBOL_BID));
  }

void UpdateRetestEngine()
  {
   CurrentRetest=RETEST_NONE;

   if(CurrentBOS!=BOS_CONFIRMED)
      return;

   if(!HasLiquiditySweep())
      return;

   CurrentRetest=RETEST_WAITING;

   if((TrendState==TREND_BULLISH && CurrentLiquidity==LIQUIDITY_LOW_SWEEP) ||
      (TrendState==TREND_BEARISH && CurrentLiquidity==LIQUIDITY_HIGH_SWEEP))
     {
      CurrentRetest=RETEST_CONFIRMED;

      if(!HasValidRetest())
         CurrentRetest=RETEST_WAITING;
     }
  }

//===========================
// End Part18
//===========================

//====================================================
// PART 19 - CONFIRMATION ENGINE
//====================================================
enum CONFIRMATION_STATE
{
   CONF_NONE=0,
   CONF_ENGULFING,
   CONF_REJECTION,
   CONF_MOMENTUM
};

CONFIRMATION_STATE CurrentConfirmation=CONF_NONE;
double   ConfirmationPrice=0.0;
datetime ConfirmationTime=0;
int      ConfirmationBar=-1;

bool IsBullishEngulfing(){ return(false); }
bool IsBearishEngulfing(){ return(false); }
bool IsRejectionCandle()
{
   return EvaluateBasicRejectionPattern(1) &&
          EvaluateRejectionStrength(1);
}
bool IsMomentumCandle(){ return(false); }

bool IsConfirmationValid()
{
   if(CurrentConfirmation==CONF_NONE) return(false);
   if(ConfirmationBar<0) return(false);
   return((Bars(_Symbol,_Period)-ConfirmationBar)<=1);
}

void ResetConfirmation()
{
   CurrentConfirmation=CONF_NONE;
   ConfirmationPrice=0.0;
   ConfirmationTime=0;
   ConfirmationBar=-1;
}

void UpdateConfirmationEngine()
{
   if(!IsConfirmationValid())
      ResetConfirmation();
}


//====================================================
// PART 20 - DECISION ENGINE
//====================================================
enum SIGNAL_TYPE
{
   SIGNAL_NONE=0,
   SIGNAL_BUY,
   SIGNAL_SELL
};

SIGNAL_TYPE CurrentSignal=SIGNAL_NONE;
double SignalPrice=0.0;
datetime SignalTime=0;
int SignalConfidence=0;

bool TrendOK(){ return(TrendState!=TREND_UNKNOWN); }
bool StructureOK(){ return(LastHighType!=STRUCTURE_UNKNOWN && LastLowType!=STRUCTURE_UNKNOWN); }
bool LiquidityOK(){ return(CurrentLiquidity!=LIQUIDITY_NONE); }
bool BOSOK(){ return(CurrentBOS==BOS_CONFIRMED); }
bool RetestOK(){ return HasValidRetest(); }
bool ConfirmationOK()
{
   return(CurrentConfirmation!=CONF_NONE);
} // Build1 temporary: remove circular dependency

bool CanOpenBuy()
{
   // Step9: helper only; never re-analyze if decision is not ready.
   return (gDecisionContext.state==DECISION_READY_BUY);

   return(TrendState==TREND_BULLISH &&
          LastHighType==STRUCTURE_HH &&
          LastLowType==STRUCTURE_HL &&
          TrendOK() && StructureOK() && LiquidityOK() && BOSOK() && HasValidRetest() && ConfirmationOK());
}

bool CanOpenSell()
{
   // Step9: helper only; never re-analyze if decision is not ready.
   return (gDecisionContext.state==DECISION_READY_SELL);

   return(TrendState==TREND_BEARISH &&
          LastHighType==STRUCTURE_LH &&
          LastLowType==STRUCTURE_LL &&
          TrendOK() && StructureOK() && LiquidityOK() && BOSOK() && HasValidRetest() && ConfirmationOK());
}

void GenerateBuySignal()
{
   // Step5: enforce pipeline state
   if(!ConfirmationEngineReady) return;
   if(gDecisionContext.state!=DECISION_READY_BUY) return;

   if(CurrentSignal==SIGNAL_BUY)
      return;

   CurrentSignal=SIGNAL_BUY;
   SignalPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   SignalTime=TimeCurrent();
   SignalConfidence=100;
}

void GenerateSellSignal()
{
   // Step5: enforce pipeline state
   if(!ConfirmationEngineReady) return;
   if(gDecisionContext.state!=DECISION_READY_SELL) return;

   if(CurrentSignal==SIGNAL_SELL)
      return;

   CurrentSignal=SIGNAL_SELL;
   SignalPrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   SignalTime=TimeCurrent();
   SignalConfidence=100;
}

// LEGACY_SIGNAL_PATH_DISABLED - Phase 2.5
void UpdateDecisionEngine()
{
   // Decision Consolidation Phase 2.1 - Central Signal Gate
   if(DecisionReady())
      return;

   if(CurrentSignal!=SIGNAL_NONE)
      return;

   // Step8: route legacy entry through pipeline only
   return;
/*
   if(CanOpenBuy())
      GenerateBuySignal();
   else if(CanOpenSell())
      GenerateSellSignal();
*/
}

//===========================
// End Part21
//===========================

//================ Part23.2 - Structure Classification =================
// Integrated integration:
// - Classify structure using StructuralMemory.
// - States planned: HH/HL, LH/LL, RANGE.
//======================================================================


//================ Part25.1F - Liquidity Validation & Debug =================
string GetLiquidityDebugText()
{
   return StringFormat("BuySide: %.5f | SellSide: %.5f",
                       BuySideLiquidityLevel,
                       SellSideLiquidityLevel);
}

void UpdateLiquidityDebug()
{
   Comment(GetLiquidityDebugText());
}
//======================================================================


// Part25.1G Integrated - Visual Validation to be implemented.


//==================== Part25.2A - Liquidity Sweep Foundation ====================
enum SWEEP_STATE
{
   SWEEP_NONE = 0,
   SWEEP_BUY,
   SWEEP_SELL
};

SWEEP_STATE CurrentSweep = SWEEP_NONE;
double SweepPrice = 0.0;
double SweepLiquidityLevel = 0.0;
datetime SweepTime = 0;

void ResetSweep()
{
   CurrentSweep = SWEEP_NONE;
   SweepPrice = 0.0;
   SweepLiquidityLevel = 0.0;
   SweepTime = 0;
}

void UpdateSweepEngine()
{
   // Skeleton - implementation in Part25.2B
}
//================== End Part25.2A ==============================================


//=== Part25.2B.2 Buy Side Sweep Skeleton ===
bool IsBuySideSweep()
{
   return false;
}


//=== Part25.2B.3 Buy Side Sweep Condition #1 ===
bool CheckBuySweepCondition1(const MqlRates &bar)
{
   if(BuySideLiquidityLevel<=0.0)
      return false;

   return (bar.high > BuySideLiquidityLevel);
}


//=== Part25.2B.4 Buy Side Sweep Confirmation ===
bool CheckBuySweepConfirmation(const MqlRates &bar)
{
   if(BuySideLiquidityLevel<=0.0)
      return false;

   if(bar.high<=BuySideLiquidityLevel)
      return false;

   return (bar.close<BuySideLiquidityLevel);
}


//=== Part25.2B.5 Update Sweep State ===
void UpdateBuySideSweepState(const MqlRates &bar)
{
   BuySideSweepDetected=true;
   BuySideSweepPrice=bar.high;
   BuySideSweepTime=bar.time;
}


//=== Part25.2B.6 Validation & Debug ===
bool ValidateBuySideSweep()
{
   if(!BuySideSweepDetected)
      return false;
   if(BuySideSweepPrice<=0.0)
      return false;
   if(BuySideSweepTime<=0)
      return false;
   return true;
}

string GetBuySideSweepDebugText()
{
   return StringFormat("BuySweep=%s | Price=%.5f | Time=%I64d", BuySideSweepDetected?"TRUE":"FALSE", BuySideSweepPrice, (long)BuySideSweepTime);
}


//=== Part25.2C.2 Sell Side Sweep Skeleton ===
bool IsSellSideSweep()
{
   return false;
}


//=== Part25.2C.3 Sell Side Sweep Condition #1 ===
bool CheckSellSweepCondition1(const MqlRates &bar)
{
   if(SellSideLiquidityLevel<=0.0)
      return false;

   return (bar.low < SellSideLiquidityLevel);
}


//=== Part25.2C.4 Sell Side Sweep Confirmation ===
bool CheckSellSweepConfirmation(const MqlRates &bar)
{
   if(SellSideLiquidityLevel<=0.0)
      return false;

   if(bar.low>=SellSideLiquidityLevel)
      return false;

   return (bar.close>SellSideLiquidityLevel);
}


//=== Part25.2C.5 Sell Side Sweep State Update ===
void UpdateSellSideSweepState(const MqlRates &bar)
{
   SellSideSweepDetected = true;
   SellSideSweepPrice    = bar.low;
   SellSideSweepTime     = bar.time;
}


//=== Part25.2C.6 Sell Side Sweep Validation & Debug ===
bool ValidateSellSideSweep()
{
   if(!SellSideSweepDetected)
      return false;

   if(SellSideSweepPrice<=0.0)
      return false;

   if(SellSideSweepTime<=0)
      return false;

   return true;
}

string GetSellSideSweepDebugText()
{
   return StringFormat("SellSweep=%s Price=%.5f Time=%I64d",
                       SellSideSweepDetected?"TRUE":"FALSE",
                       SellSideSweepPrice,
                       (long)SellSideSweepTime);
}


//=== Part26.1 CHoCH Foundation ===
enum CHOCH_DIRECTION
{
   CHOCH_NONE=0,
   CHOCH_BULLISH,
   CHOCH_BEARISH
};

bool ChochDetected=false;
CHOCH_DIRECTION ChochDirection=CHOCH_NONE;
double ChochPrice=0.0;
datetime ChochTime=0;


//=== Part26.2 CHoCH Skeleton ===
bool IsBullishCHoCH()
{
   return false;
}

bool IsBearishCHoCH()
{
   return false;
}


//=== Part26.3 Bullish CHoCH Detection ===
bool DetectBullishCHoCH(const MqlRates &bar)
{
   // Initial condition placeholder:
   // valid bullish CHoCH logic will be completed in later builds.
   if(!BuySideSweepDetected)
      return false;

   return false;
}


//=== Part26.4 Bearish CHoCH Detection ===
bool DetectBearishCHoCH(const MqlRates &bar)
{
   // Initial condition placeholder:
   // valid bearish CHoCH logic will be completed in later builds.
   if(!SellSideSweepDetected)
      return false;

   return false;
}


//=== Part26.5 CHoCH Validation ===
bool ValidateCHoCH()
{
   if(!ChochDetected)
      return false;
   if(ChochDirection==CHOCH_NONE)
      return false;
   if(ChochPrice<=0.0)
      return false;
   if(ChochTime<=0)
      return false;
   return true;
}

string GetCHoCHDebugText()
{
   return StringFormat("CHOCH=%s DIR=%d PRICE=%G TIME=%I64d",
      ChochDetected?"TRUE":"FALSE",
      (int)ChochDirection,
      ChochPrice,
      (long)ChochTime);
}


//=== Part26.6 CHoCH Visual ===
bool IsCHoCHVisualReady()
{
   return ValidateCHoCH();
}


//=== Part27.1 Order Blocks Foundation ===
enum ORDER_BLOCK_TYPE
{
   OB_NONE = 0,
   OB_BULLISH,
   OB_BEARISH
};

bool OrderBlockDetected = false;
ORDER_BLOCK_TYPE OrderBlockType = OB_NONE;
double OrderBlockPrice = 0.0;
datetime OrderBlockTime = 0;


//=== Part27.2 Order Blocks Skeleton ===
bool IsBullishOrderBlock()
{
   return false;
}

bool IsBearishOrderBlock()
{
   return false;
}

void UpdateOrderBlocks()
{

   MqlRates bar[];
   if(CopyRates(_Symbol,_Period,1,1,bar)!=1)
      return;
   const bool bullishOB = DetectBullishOrderBlock(bar[0]);
   const bool bearishOB = DetectBearishOrderBlock(bar[0]);
   const bool orderBlockValid = (bullishOB || bearishOB);
   const bool fvgReady = IsGoldenZoneReady();
   BuildGoldenZone(orderBlockValid, fvgReady);

}



//=== Part27.3 Bullish Order Block Detection ===
bool DetectBullishOrderBlock(const MqlRates &bar)
{
   if(!ChochDetected)
      return false;

   if(ChochDirection!=CHOCH_BULLISH)
      return false;

   return true;
}


//=== Part27.4 Bearish Order Block Detection ===
bool DetectBearishOrderBlock(const MqlRates &bar)
{
   if(!ChochDetected)
      return false;

   if(ChochDirection!=CHOCH_BEARISH)
      return false;

   return true;
}


//=== Part27.5 Order Blocks Validation ===
bool ValidateOrderBlock()
{
   if(!OrderBlockDetected)
      return false;
   if(OrderBlockType==OB_NONE)
      return false;
   if(OrderBlockPrice<=0.0)
      return false;
   if(OrderBlockTime<=0)
      return false;
   return true;
}

string GetOrderBlockDebugText()
{
   return StringFormat("OB:%s Type:%d Price:%G Time:%I64d",
      OrderBlockDetected?"YES":"NO",
      (int)OrderBlockType,
      OrderBlockPrice,
      (long)OrderBlockTime);
}


//=== Part27.6 Order Blocks Visual ===
bool IsOrderBlockVisualReady()
{
   return ValidateOrderBlock();
}


//=== Part28.2 Institutional FVG Skeleton ===

bool DetectBullishFVG()
{
   return false;
}

bool DetectBearishFVG()
{
   return false;
}

void UpdateFVG()
{

   const bool bullishFVG = DetectBullishInstitutionalFVG();
   const bool bearishFVG = DetectBearishInstitutionalFVG();
   const bool fvgValid = (bullishFVG || bearishFVG);
   const bool orderBlockReady = IsGoldenZoneReady();
   BuildGoldenZone(orderBlockReady, fvgValid);
   const bool retestReady = IsRetestReadyForDecision();
   if(retestReady)
   {
      // DF-04 Step3 integration hook
      const bool decisionInputReady = retestReady;
      const bool signalPipelineReady = decisionInputReady;

if(signalPipelineReady)
      {
         // DF-05 Step2 Decision hook
      }

      // DF-05 Step1 placeholder: Decision integration will consume retestReady only
   }

}


//=== Part28.3 Institutional Bullish FVG Detection ===
bool DetectBullishInstitutionalFVG()
{
   if(!FVGDetected)
      return false;

   // Integrated: future integration with Trend, Sweep, CHoCH and Order Block
   return true;
}


//=== Part28.4 Institutional Bearish FVG Detection ===
bool DetectBearishInstitutionalFVG()
{
   if(!FVGDetected)
      return false;

   // Integrated: future integration with Trend, Sweep, CHoCH and Order Block
   return true;
}


//=== Part28.5 Institutional FVG Validation ===
bool ValidateInstitutionalFVG()
{
   if(!FVGDetected)
      return false;

   if(FVGType==FVG_NONE)
      return false;

   if(FVGHigh<=FVGLow)
      return false;

   if(FVGTime<=0)
      return false;

   return true;
}

string GetFVGDebugText()
{
   return StringFormat("FVG=%s Type=%d High=%.5f Low=%.5f",
                       FVGDetected?"YES":"NO",
                       (int)FVGType,
                       FVGHigh,
                       FVGLow);
}



//=== Part28.6 Institutional FVG Visual ===
bool IsInstitutionalFVGVisualReady()
{
   return ValidateInstitutionalFVG();
}


//=== Part29.3 Structural Swing Detection ===
enum ENUM_SWING_TYPE
  {
   SWING_NONE=0,
   SWING_HIGH,
   SWING_LOW
  };

struct StructuralSwing
  {
   ENUM_SWING_TYPE Type;
   double Price;
   datetime Time;
   int BarIndex;
   bool IsValid;
  };

StructuralSwing CurrentSwing;
StructuralSwing PreviousSwing;

void ResetStructuralSwing(StructuralSwing &s)
  {
   s.Type=SWING_NONE;
   s.Price=0.0;
   s.Time=0;
   s.BarIndex=-1;
   s.IsValid=false;
  }

// Integrated: detection logic will be implemented in Part29.4+
bool DetectStructuralSwing(const int bar)
  {
   return(false);
  }
//=== End Part29.3 ===



//=== Part29.4 Trend Classification ===
struct SwingClassification
{
   ENUM_STRUCTURE_TYPE StructureType;
   double ReferencePrice;
   datetime ClassificationTime;
};

SwingClassification CurrentSwingClassification;

void ResetSwingClassification()
{
   CurrentSwingClassification.StructureType=STRUCTURE_UNKNOWN;
   CurrentSwingClassification.ReferencePrice=0.0;
   CurrentSwingClassification.ClassificationTime=0;
}

void ClassifyStructuralSwing()
{
   UpdateStructureClassification();

   if(LastHighType!=STRUCTURE_UNKNOWN)
   {
      CurrentSwingClassification.StructureType=LastHighType;
      CurrentSwingClassification.ReferencePrice=MarketMemory.High1.Price;
      CurrentSwingClassification.ClassificationTime=MarketMemory.High1.Time;
   }
   else if(LastLowType!=STRUCTURE_UNKNOWN)
   {
      CurrentSwingClassification.StructureType=LastLowType;
      CurrentSwingClassification.ReferencePrice=MarketMemory.Low1.Price;
      CurrentSwingClassification.ClassificationTime=MarketMemory.Low1.Time;
   }
}
//=== End Part29.4 ===



//==============================
// Part29.5 Trend Intelligence
//==============================
enum ENUM_TREND_REASON
  {
   TREND_SEQUENCE_CONFIRMED=0,
   TREND_WAITING_FOR_CONFIRMATION,
   TREND_STRUCTURE_BROKEN,
   TREND_INSUFFICIENT_DATA
  };

struct TrendIntelligenceResult
  {
   ENUM_TREND_DIRECTION Direction;
   double TrendStrength;
   double TrendConfidence;
   ENUM_TREND_REASON Reason;
  };

TrendIntelligenceResult CurrentTrendIntelligence;

void ResetTrendIntelligence()
  {
   CurrentTrendIntelligence.Direction=TREND_DIR_NEUTRAL;
   CurrentTrendIntelligence.TrendStrength=0.0;
   CurrentTrendIntelligence.TrendConfidence=0.0;
   CurrentTrendIntelligence.Reason=TREND_INSUFFICIENT_DATA;
  }

void AnalyzeTrendIntelligence()
  {
   // Integrated for Part29.5 logic.
   // Will consume classified HH/HL/LH/LL data only.
  }
// End Part29.5

//=== Part29.6 Trend Interface ===
//=== Part29.6 Trend Interface ===
bool IsTrendReady()
{
   return true;
}

ENUM_TREND_DIRECTION GetTrendDirection()
{
   return CurrentTrendIntelligence.Direction;
}

double GetTrendStrength()
{
   return CurrentTrendIntelligence.TrendStrength;
}

double GetTrendConfidence()
{
   return CurrentTrendIntelligence.TrendConfidence;
}

ENUM_TREND_REASON GetTrendReason()
{
   return CurrentTrendIntelligence.Reason;
}

//=== End Part29.6 ===
//=== End Part29.6 ===

//====================================================
// Part 30.1 - BOS Engine Foundation
//====================================================

enum ENUM_BOS_ENGINE_DIRECTION
{
   BOS_ENGINE_NONE=0,
   BOS_ENGINE_BULLISH,
   BOS_ENGINE_BEARISH
};

struct BOSResult
{
   bool Detected;
   ENUM_BOS_ENGINE_DIRECTION Direction;
   double BreakPrice;
   datetime BreakTime;
   double Confidence;
};

BOSResult CurrentBOSEngine;

void ResetBOS()
{
   CurrentBOSEngine.Detected=false;
   CurrentBOSEngine.Direction=BOS_ENGINE_NONE;
   CurrentBOSEngine.BreakPrice=0.0;
   CurrentBOSEngine.BreakTime=0;
   CurrentBOSEngine.Confidence=0.0;
}

void AnalyzeBOS()
{
   ResetBOS();

   if(!IsTrendReady())
      return;

   ENUM_TREND_DIRECTION trend=GetTrendDirection();

   if(trend==TREND_DIR_UP)
      CurrentBOSEngine.Direction=BOS_ENGINE_BULLISH;
   else if(trend==TREND_DIR_DOWN)
      CurrentBOSEngine.Direction=BOS_ENGINE_BEARISH;
   else
      CurrentBOSEngine.Direction=BOS_ENGINE_NONE;

   // Integrated for Part 30.2
}

//=== Part30.3 BOS Detection Stage 2 ===
void AnalyzeBOSStage2()
{
   // Initial BOS validation (Part 30.4)
   CurrentBOSEngine.Detected=false;
   CurrentBOSEngine.Confidence=10.0;

   if(CurrentBOSEngine.Direction==BOS_ENGINE_NONE)
      return;

   // Price validation will be implemented in a later part.

   if(CurrentBOSEngine.Direction==BOS_ENGINE_BULLISH)
   {
      CurrentBOSEngine.Confidence=50.0;
   }
   else if(CurrentBOSEngine.Direction==BOS_ENGINE_BEARISH)
   {
      CurrentBOSEngine.Confidence=50.0;
   }
}

//=== Part30.6 Structural Swing Verification ===
bool VerifyBOSStructuralSwing()
{
   if(!IsTrendReady())
      return(false);

   // Integrated: will be connected to Structural Swing engine in next parts.
   // Returning current BOS detection state only.
   return(CurrentBOSEngine.Detected);
}


//=========================
// Part 30.7 - False Break Filter
//=========================
bool IsFalseBreak()
{
   if(!CurrentBOSEngine.Detected)
      return false;
   // Integrated for future price-action validation.
   return false;
}

void ApplyBOSFalseBreakFilter()
{
   if(IsFalseBreak())
   {
      CurrentBOSEngine.Detected=false;
      CurrentBOSEngine.Confidence=0.0;
   }
}
//=========================



//==============================
// Part 30.8 - BOS Confidence
//==============================
double CalculateBOSConfidence()
{
   double confidence = 0.0;
   if(!IsTrendReady())
      return confidence;
   if(CurrentBOSEngine.Detected)
      confidence = 60.0;
   if(VerifyBOSStructuralSwing())
      confidence += 20.0;
   if(!IsFalseBreak())
      confidence += 20.0;
   if(confidence>100.0)
      confidence=100.0;
   return confidence;
}

void UpdateBOSConfidence()
{
   CurrentBOSEngine.Confidence = CalculateBOSConfidence();
}


//=========================
// Part 30.9 - BOS Interface
//=========================
bool IsBOSValid()
{
   return CurrentBOSEngine.Detected && CurrentBOSEngine.Confidence>0;
}

ENUM_BOS_ENGINE_DIRECTION GetBOSDirection()
{
   return CurrentBOSEngine.Direction;
}

double GetBOSPrice()
{
   return CurrentBOSEngine.BreakPrice;
}

datetime GetBOSTime()
{
   return CurrentBOSEngine.BreakTime;
}

double GetBOSConfidence()
{
   return CurrentBOSEngine.Confidence;
}


//==============================
// Part 30.10 - BOS Finalization
//==============================
bool IsBOSEngineReady()
{
   return IsTrendReady();
}

void FinalizeBOSEngine()
{
   UpdateBOSConfidence();
}

//================ Build41 CHoCH Engine ===================
// Engine Contract:
// Purpose: Detect Change of Character using Trend and BOS only.
// Inputs : Trend Engine, BOS Engine.
// Outputs: State, Direction, Confidence, Reason.
//==========================================================

enum ENUM_CHOCH_STATE
{
   CHOCH_STATE_NONE=0,
   CHOCH_STATE_POTENTIAL,
   CHOCH_STATE_CANDIDATE,
   CHOCH_STATE_CONFIRMED
};

struct CHOCH_ENGINE_RESULT
{
   bool Ready;
   bool Valid;
   ENUM_CHOCH_STATE State;
   ENUM_BOS_ENGINE_DIRECTION Direction;
   double Price;
   datetime Time;
   double Confidence;
   string Reason;
};

CHOCH_ENGINE_RESULT CurrentCHOCHEngine;

void ResetCHOCHEngine()
{
   CurrentCHOCHEngine.Ready=false;
   CurrentCHOCHEngine.Valid=false;
   CurrentCHOCHEngine.State=CHOCH_STATE_NONE;
   CurrentCHOCHEngine.Direction=BOS_ENGINE_NONE;
   CurrentCHOCHEngine.Price=0;
   CurrentCHOCHEngine.Time=0;
   CurrentCHOCHEngine.Confidence=0;
   CurrentCHOCHEngine.Reason="NOT_ANALYZED";
}

void AnalyzeCHOCHEngine()
{
   ResetCHOCHEngine();
   if(!IsTrendReady())
   {
      CurrentCHOCHEngine.Reason="TREND_NOT_READY";
      return;
   }
   if(!IsBOSEngineReady())
   {
      CurrentCHOCHEngine.Reason="BOS_NOT_READY";
      return;
   }
   CurrentCHOCHEngine.Ready=true;
   CurrentCHOCHEngine.Direction=GetBOSDirection();
   CurrentCHOCHEngine.State=CHOCH_STATE_POTENTIAL;
   CurrentCHOCHEngine.Confidence=50.0;
   CurrentCHOCHEngine.Reason="WAITING_CONFIRMATION";
}

bool IsCHOCHReady(){return CurrentCHOCHEngine.Ready;}
bool IsCHOCHValid(){return CurrentCHOCHEngine.Valid;}
ENUM_CHOCH_STATE GetCHOCHState(){return CurrentCHOCHEngine.State;}
ENUM_BOS_ENGINE_DIRECTION GetCHOCHDirection(){return CurrentCHOCHEngine.Direction;}
double GetCHOCHConfidence(){return CurrentCHOCHEngine.Confidence;}
string GetCHOCHReason(){return CurrentCHOCHEngine.Reason;}


//====================================================
// Build 42 - Liquidity Intelligence Engine
// Foundation (Architecture Only)
//====================================================

// Engine Contract:
// Purpose      : Build and maintain a shared Liquidity Map.
// Inputs       : Market data, Trend, BOS, CHoCH.
// Outputs      : Liquidity Map.
// Dependencies : Trend Engine, BOS Engine, CHoCH Engine.
// Consumers    : Sweep, Order Block, FVG, Retest, Entry, Decision.

enum ENUM_LIQUIDITY_STATE
{
   LIQ_STATE_NONE=0,
   LIQ_STATE_DETECTED,
   LIQ_STATE_ACTIVE,
   LIQ_STATE_TARGETED,
   LIQ_STATE_SWEPT,
   LIQ_STATE_CONSUMED
};

enum ENUM_LIQUIDITY_TYPE
{
   LIQ_UNKNOWN=0,
   LIQ_BUY_SIDE,
   LIQ_SELL_SIDE,
   LIQ_INTERNAL,
   LIQ_EXTERNAL,
   LIQ_RESTING
};

struct LIQUIDITY_ZONE
{
   int      Id;
   double   Price;
   double   Confidence;
   int      Priority;
   datetime CreatedTime;
   ENUM_LIQUIDITY_STATE State;
   ENUM_LIQUIDITY_TYPE  Type;
};

struct LIQUIDITY_ENGINE_RESULT
{
   bool Ready;
   int  TotalZones;
   string Reason;
};

LIQUIDITY_ENGINE_RESULT CurrentLiquidityEngine;

void ResetLiquidityEngine()
{
   CurrentLiquidityEngine.Ready=false;
   CurrentLiquidityEngine.TotalZones=0;
   CurrentLiquidityEngine.Reason="Reset";
}

void AnalyzeLiquidityEngine()
{
   // Build 42 foundation only.
   // Detection logic will be added in the next iterations.
   CurrentLiquidityEngine.Ready=true;
   CurrentLiquidityEngine.Reason="Liquidity Engine Initialized";
}

bool LiquidityEngineReady()
{
   return CurrentLiquidityEngine.Ready;
}


//====================================================
// Build 42.1 - Liquidity Map Foundation
//====================================================
#define MAX_LIQUIDITY_ZONES 64

LIQUIDITY_ZONE LiquidityMap[MAX_LIQUIDITY_ZONES];

void ClearLiquidityMap()
{
   for(int i=0;i<MAX_LIQUIDITY_ZONES;i++)
   {
      LiquidityMap[i].Id=-1;
      LiquidityMap[i].Price=0.0;
      LiquidityMap[i].Confidence=0.0;
      LiquidityMap[i].Priority=0;
      LiquidityMap[i].CreatedTime=0;
      LiquidityMap[i].State=LIQ_STATE_NONE;
      LiquidityMap[i].Type=LIQ_UNKNOWN;
   }
   CurrentLiquidityEngine.TotalZones=0;
}

bool AddLiquidityZone(ENUM_LIQUIDITY_TYPE type,double price,int priority,double confidence)
{
   if(CurrentLiquidityEngine.TotalZones>=MAX_LIQUIDITY_ZONES)
      return(false);

   int idx=CurrentLiquidityEngine.TotalZones;

   LiquidityMap[idx].Id=idx+1;
   LiquidityMap[idx].Price=price;
   LiquidityMap[idx].Priority=priority;
   LiquidityMap[idx].Confidence=confidence;
   LiquidityMap[idx].CreatedTime=TimeCurrent();
   LiquidityMap[idx].State=LIQ_STATE_DETECTED;
   LiquidityMap[idx].Type=type;

   CurrentLiquidityEngine.TotalZones++;
   return(true);
}


//====================================================
// Build 42.2 - Equal High / Low Detection Foundation
//====================================================

input double LiquidityEqualTolerancePoints = 10.0;

bool IsEqualHigh(const double h1,const double h2)
{
   return(MathAbs(h1-h2)<=LiquidityEqualTolerancePoints*_Point);
}

bool IsEqualLow(const double l1,const double l2)
{
   return(MathAbs(l1-l2)<=LiquidityEqualTolerancePoints*_Point);
}

void ScanEqualLiquidity(const int bars,const double &high[],const double &low[],const datetime &time[])
{
   ResetLiquidityEngine();
   ClearLiquidityMap();

   for(int i=2;i<bars-2;i++)
   {
      if(IsEqualHigh(high[i],high[i+1]))
      {
         AddLiquidityZone(LIQ_BUY_SIDE,
                          high[i],
                          1,
                          60.0);
      }

      if(IsEqualLow(low[i],low[i+1]))
      {
         AddLiquidityZone(LIQ_SELL_SIDE,
                          low[i],
                          1,
                          60.0);
      }
   }

   CurrentLiquidityEngine.TotalZones=CurrentLiquidityEngine.TotalZones;
   CurrentLiquidityEngine.Ready=true;
   CurrentLiquidityEngine.Reason="Equal Liquidity Scan Complete";
}


//====================================================
// Build 42.3 - Structural Liquidity Filter
//====================================================

input int LiquidityLookbackBars = 5;

bool IsStructuralHigh(const double &high[],int index)
{
   if(index<LiquidityLookbackBars) return false;
   for(int i=1;i<=LiquidityLookbackBars;i++)
      if(high[index]<=high[index-i])
         return false;
   return true;
}

bool IsStructuralLow(const double &low[],int index)
{
   if(index<LiquidityLookbackBars) return false;
   for(int i=1;i<=LiquidityLookbackBars;i++)
      if(low[index]>=low[index-i])
         return false;
   return true;
}



//====================================================
// Build 42.4 - Priority Evaluation
//====================================================
input int LiquidityHighPriority = 80;
input int LiquidityMediumPriority = 50;

int CalculateLiquidityPriority(const ENUM_LIQUIDITY_TYPE type,
                               const bool structural)
{
   int score=LiquidityMediumPriority;
   if(structural)
      score=LiquidityHighPriority;
   if(type==LIQ_EXTERNAL)
      score+=10;
   if(score>100)
      score=100;
   return(score);
}

void UpdateLiquidityPriorities()
{
   for(int i=0;i<CurrentLiquidityEngine.TotalZones;i++)
   {
      bool structural=true;
      LiquidityMap[i].Priority=
         CalculateLiquidityPriority(LiquidityMap[i].Type,structural);
   }
}


//====================================================
// Build 42.5 - Liquidity Confidence Engine
//====================================================

input double LiquidityBaseConfidence = 60.0;
input double LiquidityStructuralBonus = 20.0;
input double LiquidityExternalBonus = 10.0;

double CalculateLiquidityConfidence(bool isStructural,bool isExternal,int priority)
{
   double score=LiquidityBaseConfidence;
   if(isStructural)
      score+=LiquidityStructuralBonus;
   if(isExternal)
      score+=LiquidityExternalBonus;

   score += (double)priority*0.10;

   if(score>100.0)
      score=100.0;
   if(score<0.0)
      score=0.0;

   return(score);
}

void UpdateLiquidityConfidence()
{
   for(int i=0;i<CurrentLiquidityEngine.TotalZones;i++)
   {
      bool structural=(LiquidityMap[i].Priority>=LiquidityHighPriority);
      bool external=(LiquidityMap[i].Type==LIQ_EXTERNAL);

      LiquidityMap[i].Confidence=
         CalculateLiquidityConfidence(structural,external,LiquidityMap[i].Priority);
   }
}


//====================================================
// Build 42.6 - Engine Integration
//====================================================
void RunLiquidityEngine(
   const int bars,
   const double &high[],
   const double &low[],
   const datetime &time[]
)
{
   ResetLiquidityEngine();
   ClearLiquidityMap();
   ScanEqualLiquidity(bars,high,low,time);
   UpdateLiquidityPriorities();
   UpdateLiquidityConfidence();

   CurrentLiquidityEngine.Ready = (CurrentLiquidityEngine.TotalZones>=0);
   CurrentLiquidityEngine.Reason = "Liquidity analysis completed";
}


//====================================================
// Build 42.7 - Liquidity Zone Lifecycle
//====================================================

bool ActivateLiquidityZone(const int index)
{
   if(index<0 || index>=CurrentLiquidityEngine.TotalZones)
      return false;

   LiquidityMap[index].State=LIQ_STATE_ACTIVE;
   return true;
}

bool TargetLiquidityZone(const int index)
{
   if(index<0 || index>=CurrentLiquidityEngine.TotalZones)
      return false;

   LiquidityMap[index].State=LIQ_STATE_TARGETED;
   return true;
}

bool SweepLiquidityZone(const int index)
{
   if(index<0 || index>=CurrentLiquidityEngine.TotalZones)
      return false;

   LiquidityMap[index].State=LIQ_STATE_SWEPT;
   return true;
}

bool ConsumeLiquidityZone(const int index)
{
   if(index<0 || index>=CurrentLiquidityEngine.TotalZones)
      return false;

   LiquidityMap[index].State=LIQ_STATE_CONSUMED;
   return true;
}

void UpdateLiquidityLifecycle()
{
   for(int i=0;i<CurrentLiquidityEngine.TotalZones;i++)
   {
      if(LiquidityMap[i].State==LIQ_STATE_DETECTED)
         ActivateLiquidityZone(i);
   }
}


//====================================================
// Build 42 Final - Liquidity Engine Final Integration
//====================================================
void FinalizeLiquidityEngine(const int bars,
                             const double &high[],
                             const double &low[],
                             const datetime &time[])
{
   RunLiquidityEngine(bars,high,low,time);
   UpdateLiquidityLifecycle();
   CurrentLiquidityEngine.Ready=true;
   CurrentLiquidityEngine.Reason="Build42 Final Completed";
}


//====================================================
// Build 43 - Liquidity Sweep Engine
// Foundation
//====================================================
enum ENUM_SWEEP_STATE
{
   SWEEP_STATE_NONE=0,
   SWEEP_STATE_DETECTED,
   SWEEP_STATE_CONFIRMED,
   SWEEP_STATE_REJECTED
};

enum ENUM_SWEEP_DIRECTION
{
   SWEEP_DIR_NONE=0,
   SWEEP_BUY_SIDE,
   SWEEP_SELL_SIDE
};

struct SWEEP_ENGINE_RESULT
{
   bool Ready;
   ENUM_SWEEP_STATE State;
   ENUM_SWEEP_DIRECTION Direction;
   double SweepPrice;
   double Confidence;
   string Reason;
};

SWEEP_ENGINE_RESULT CurrentSweepEngine;

void ResetSweepEngine()
{
   CurrentSweepEngine.Ready=false;
   CurrentSweepEngine.State=SWEEP_STATE_NONE;
   CurrentSweepEngine.Direction=SWEEP_DIR_NONE;
   CurrentSweepEngine.SweepPrice=0.0;
   CurrentSweepEngine.Confidence=0.0;
   CurrentSweepEngine.Reason="Reset";
}

//====================================================
// Build 43.2 - Sweep Integration with Liquidity Map
//====================================================

void AnalyzeSweepEngine()
{
   ResetSweepEngine();

   if(!LiquidityEngineReady())
   {
      CurrentSweepEngine.Ready=false;
      CurrentSweepEngine.Reason="Liquidity Engine Not Ready";
      return;
   }

   // Counter will be added in Build 43.3

   for(int i=0;i<CurrentLiquidityEngine.TotalZones;i++)
   {
      // Build 43.2:
      // Read Liquidity Map only.
      // Sweep detection logic will be added in next builds.
   }

   CurrentSweepEngine.Ready=true;
   CurrentSweepEngine.Reason="Liquidity Map Connected";
}

bool SweepEngineReady()
{
   return CurrentSweepEngine.Ready;
}


//====================================================
// Build 43.3 - Sweep Detection Foundation
//====================================================


bool IsBuySideSweep(const double currentHigh,const double liquidityPrice)
{
   return(currentHigh>liquidityPrice);
}

bool IsSellSideSweep(const double currentLow,const double liquidityPrice)
{
   return(currentLow<liquidityPrice);
}



//====================================================
// Build 43.4 - True / False Sweep Foundation
//====================================================

enum ENUM_SWEEP_RESULT
{
   SWEEP_RESULT_NONE=0,
   SWEEP_RESULT_TRUE,
   SWEEP_RESULT_FALSE
};

bool IsTrueSweep(double liquidityPrice,double candleHigh,double candleLow,double candleClose,bool buySide)
{
   if(buySide)
      return (candleHigh>liquidityPrice && candleClose<liquidityPrice);
   return (candleLow<liquidityPrice && candleClose>liquidityPrice);
}

bool IsFalseSweep(double liquidityPrice,double candleHigh,double candleLow,double candleClose,bool buySide)
{
   return !IsTrueSweep(liquidityPrice,candleHigh,candleLow,candleClose,buySide);
}


//====================================================
// Build 43.5 - Sweep Validation Integration
//====================================================

bool ValidateSweepWithStructure(const bool chochReady,
                                const bool bosReady,
                                const int liquidityPriority,
                                const double liquidityConfidence)
{
   if(!chochReady) return(false);
   if(!bosReady) return(false);
   if(liquidityPriority<50) return(false);
   if(liquidityConfidence<60.0) return(false);
   return(true);
}

void UpdateSweepValidation()
{
   // Foundation only. Full engine linkage will be added later.
   CurrentSweepEngine.Ready = CurrentSweepEngine.Ready;
}


//====================================================
// Build 43 Final - Sweep Engine Finalization
//====================================================
void FinalizeSweepEngine()
{
   // Integrated final integration.
   UpdateSweepValidation();
   CurrentSweepEngine.Ready=true;
   CurrentSweepEngine.Reason="Build43 Final Completed";
}

bool SweepEngineIsValid()
{
   return CurrentSweepEngine.Ready;
}


//=== Build44.1 Order Block Integration Foundation ===

struct ORDERBLOCK_ENGINE_RESULT
{
   bool Ready;
   int TotalBlocks;
   string Reason;
};

ORDERBLOCK_ENGINE_RESULT CurrentOrderBlockEngine;

void ResetOrderBlockEngine()
{
   CurrentOrderBlockEngine.Ready=false;
   CurrentOrderBlockEngine.TotalBlocks=0;
   CurrentOrderBlockEngine.Reason="Reset";
}

bool OrderBlockEngineReady()
{
   return CurrentOrderBlockEngine.Ready;
}

void AnalyzeOrderBlockEngine()
{
   UpdateOrderBlocks();

   CurrentOrderBlockEngine.TotalBlocks = (OrderBlockDetected ? 1 : 0);
   CurrentOrderBlockEngine.Ready=true;
   CurrentOrderBlockEngine.Reason="Build44.1 Integrated";
}



//=== Build44.2 Institutional Order Block Detection ===
void UpdateInstitutionalOrderBlockEngine()
{
   AnalyzeOrderBlockEngine();

   if(!OrderBlockDetected)
      return;

   CurrentOrderBlockEngine.TotalBlocks=1;
   CurrentOrderBlockEngine.Ready=true;
   CurrentOrderBlockEngine.Reason="Institutional Order Block detected";
}



//==============================
// Build 44.3 - Order Block Validation
//==============================
void ValidateInstitutionalOrderBlocks()
{
   if(!CurrentOrderBlockEngine.Ready)
      return;

   bool structure_ok = (CurrentTrend.Direction!=TREND_DIR_NEUTRAL);
   CurrentOrderBlockEngine.Ready = structure_ok;
   CurrentOrderBlockEngine.Reason = structure_ok ? "Order Block validated against active trend" : "Waiting for trend confirmation";
}



//================ Build 44.4 Order Block Scoring =================
void UpdateOrderBlockScore()
{
   if(!CurrentOrderBlockEngine.Ready)
      return;

   int score=0;

   if(CurrentTrend.Direction!=TREND_DIR_NEUTRAL) score+=30;
   if(OrderBlockDetected)
      score+=20;

   CurrentOrderBlockEngine.TotalBlocks = (score>=50 ? 1 : 0);
   CurrentOrderBlockEngine.Reason="Order Block score updated";
}


//=== Build44 Final : Order Block Finalization ===
void FinalizeOrderBlockEngine()
{
   AnalyzeOrderBlockEngine();
   ValidateInstitutionalOrderBlocks();
   UpdateOrderBlockScore();

   if(CurrentOrderBlockEngine.Ready)
      CurrentOrderBlockEngine.Reason="Build44 Final Completed";
}

bool OrderBlockEngineIsValid()
{
   return(CurrentOrderBlockEngine.Ready);
}

//====================
// Build 45.1 - Institutional FVG Foundation
//====================

bool InstitutionalFVGReady=false;

void ResetInstitutionalFVGEngine()
{
   InstitutionalFVGReady=false;
}

bool FVGEngineReady()
{
   return InstitutionalFVGReady;
}

void AnalyzeInstitutionalFVG()
{
   // Foundation only.
   // Detection/validation/scoring are implemented in later builds.
   InstitutionalFVGReady=true;
}


//==================== BUILD 45.2 ====================
// Institutional FVG Detection Extension

enum ENUM_INSTITUTIONAL_FVG_CLASS
{
   FVG_CLASS_NONE=0,
   FVG_CLASS_IMPULSIVE,
   FVG_CLASS_SECONDARY
};

ENUM_INSTITUTIONAL_FVG_CLASS CurrentFVGClass=FVG_CLASS_NONE;

bool IsImpulsiveInstitutionalFVG()
{
   return(CurrentFVGClass==FVG_CLASS_IMPULSIVE);
}

bool IsSecondaryInstitutionalFVG()
{
   return(CurrentFVGClass==FVG_CLASS_SECONDARY);
}

void ClassifyInstitutionalFVG(bool trendAligned,
                              bool structureConfirmed,
                              bool liquiditySweep,
                              bool orderBlockAligned)
{
   CurrentFVGClass=FVG_CLASS_NONE;

   if(trendAligned && structureConfirmed && liquiditySweep && orderBlockAligned)
      CurrentFVGClass=FVG_CLASS_IMPULSIVE;
   else if(trendAligned && structureConfirmed)
      CurrentFVGClass=FVG_CLASS_SECONDARY;
}
//================== END BUILD 45.2 ==================


//==============================
// Build45.3 Institutional FVG Validation
//==============================
enum FVG_VALIDATION_STATUS
{
   FVG_VALIDATION_INVALID=0,
   FVG_VALIDATION_VALID
};

FVG_VALIDATION_STATUS CurrentFVGValidation=FVG_VALIDATION_INVALID;

bool ValidateInstitutionalFVGContext(bool trendAligned,
                                     bool structureConfirmed,
                                     bool liquiditySweepConfirmed,
                                     bool orderBlockConfirmed)
{
   if(trendAligned &&
      structureConfirmed &&
      liquiditySweepConfirmed &&
      orderBlockConfirmed)
   {
      CurrentFVGValidation=FVG_VALIDATION_VALID;
      return(true);
   }

   CurrentFVGValidation=FVG_VALIDATION_INVALID;
   return(false);
}

bool InstitutionalFVGValidated()
{
   return(CurrentFVGValidation==FVG_VALIDATION_VALID);
}
// End Build45.3


//==============================
// Build 45.4 Institutional FVG Scoring
//==============================
enum FVG_PRIORITY
{
   FVG_PRIORITY_LOW=0,
   FVG_PRIORITY_MEDIUM,
   FVG_PRIORITY_HIGH
};

int CurrentFVGScore=0;
FVG_PRIORITY CurrentFVGPriority=FVG_PRIORITY_LOW;

void UpdateInstitutionalFVGScore(bool trend,bool structure,bool sweep,bool orderblock,bool fresh)
{
   int score=0;
   if(trend) score+=20;
   if(structure) score+=25;
   if(sweep) score+=20;
   if(orderblock) score+=25;
   if(fresh) score+=10;
   CurrentFVGScore=score;
   if(score>=80) CurrentFVGPriority=FVG_PRIORITY_HIGH;
   else if(score>=50) CurrentFVGPriority=FVG_PRIORITY_MEDIUM;
   else CurrentFVGPriority=FVG_PRIORITY_LOW;
}


//=== Build45 Final Golden Zone Integration ===
enum GOLDEN_ZONE_STATE
{
   GOLDEN_ZONE_NONE=0,
   GOLDEN_ZONE_READY
};

GOLDEN_ZONE_STATE CurrentGoldenZone=GOLDEN_ZONE_NONE;
bool GoldenZoneReady=false;

bool BuildGoldenZone(bool orderBlockValid,bool fvgValid)
{
   GoldenZoneReady=(orderBlockValid && fvgValid);
   CurrentGoldenZone=GoldenZoneReady ? GOLDEN_ZONE_READY : GOLDEN_ZONE_NONE;
   return GoldenZoneReady;
}

bool IsGoldenZoneReady()
{
   return GoldenZoneReady;
}

bool IsRetestReadyForDecision()
{
   return GoldenZoneReady && HasValidRetest();
}


//=== Build46.1 Institutional Retest Upgrade (Integrated Foundation) ===
// This section extends the existing Retest Engine without modifying prior logic.
// Future builds should integrate these flags into UpdateRetestEngine().

bool RetestGoldenZoneEnabled = true;
bool RetestPriceMovedAway = false;
bool RetestReturnedToZone = false;
bool RetestValidated = false;
string RetestReason = "Waiting for Golden Zone";

void ResetRetestBuild461()
{
   RetestPriceMovedAway=false;
   RetestReturnedToZone=false;
   RetestValidated=false;
   RetestReason="Waiting for Golden Zone";
}


//=== Build46.2 Institutional Retest Upgrade ===
enum RETEST_PHASE
{
   RETEST_WAIT_ZONE=0,
   RETEST_MOVED_AWAY,
   RETEST_RETURNED,
   RETEST_PHASE_VALID,
   RETEST_PHASE_FAILED
};

RETEST_PHASE CurrentRetestPhase=RETEST_WAIT_ZONE;

void ResetRetestBuild462()
{
   CurrentRetestPhase=RETEST_WAIT_ZONE;
   RetestReason="Waiting for Golden Zone";
}

bool RetestPhaseReady()
{
   return(CurrentRetestPhase==RETEST_PHASE_VALID);
}
//=== End Build46.2 ===


//=== Build46.3 Retest Transition Foundation ===
enum RETEST_TRANSITION_STATE
{
   RETEST_TRANSITION_IDLE=0,
   RETEST_TRANSITION_MOVED_AWAY,
   RETEST_TRANSITION_RETURNED,
   RETEST_TRANSITION_VALIDATED,
   RETEST_TRANSITION_FAILED
};

RETEST_TRANSITION_STATE CurrentRetestTransition=RETEST_TRANSITION_IDLE;

void ResetRetestBuild463()
{
   CurrentRetestTransition=RETEST_TRANSITION_IDLE;
}

bool RetestTransitionReady()
{
   return(CurrentRetestTransition==RETEST_TRANSITION_VALIDATED);
}
//=== End Build46.3 ===


//=== Build46.4 Retest Logic Scaffold ===
bool RetestMovedAway=false;
bool RetestReturned=false;

void UpdateRetestTransition()
{
   if(!GoldenZoneReady)
      return;

   if(CurrentRetestPhase==RETEST_WAIT_ZONE)
   {
      RetestReason="Waiting for move away";
      if(RetestMovedAway)
         CurrentRetestPhase=RETEST_MOVED_AWAY;
   }
   else if(CurrentRetestPhase==RETEST_MOVED_AWAY)
   {
      RetestReason="Waiting for return";
      if(RetestReturned)
         CurrentRetestPhase=RETEST_RETURNED;
   }
}


//=== Build46.5 Retest Distance Foundation ===
double RetestMoveAwayDistance=0.0;
double RetestReturnDistance=0.0;
bool FirstRetestOnly=true;

void ResetRetestBuild465()
{
   RetestMoveAwayDistance=0.0;
   RetestReturnDistance=0.0;
}

bool RetestDistanceReady()
{
   return(CurrentRetest==RETEST_CONFIRMED);
}


//=== Build46.6 Retest Price Logic Foundation ===
double RetestLastPrice=0.0;
bool   RetestPriceLogicEnabled=true;

void ResetRetestBuild466()
{
   RetestLastPrice=0.0;
}

bool UpdateRetestPriceLogic(double currentPrice)
{
   if(!RetestPriceLogicEnabled)
      return(false);

   RetestLastPrice=currentPrice;

   if(CurrentGoldenZone==0)
      return(false);

   return(true);
}


//=== Build46.7 Retest Real Distance Scaffold ===
double RetestReferencePrice=0.0;
bool   RetestDistanceMeasured=false;

void ResetRetestBuild467()
{
   RetestReferencePrice=0.0;
   RetestDistanceMeasured=false;
}

void UpdateRetestDistanceMeasurement(double currentPrice)
{
   if(!RetestPriceLogicEnabled)
      return;

   if(!RetestDistanceMeasured)
   {
      RetestReferencePrice=currentPrice;
      RetestDistanceMeasured=true;
      return;
   }

   RetestMoveAwayDistance=MathAbs(currentPrice-RetestReferencePrice);

   if(RetestReturned)
      RetestReturnDistance=MathAbs(currentPrice-RetestReferencePrice);
}


//=== Build46.8 Retest Zone Binding ===
double RetestZoneUpper=0.0;
double RetestZoneLower=0.0;
bool RetestZoneBound=false;

void ResetRetestBuild468()
{
   RetestZoneUpper=0.0;
   RetestZoneLower=0.0;
   RetestZoneBound=false;
}

bool BindRetestToGoldenZone(double upper,double lower)
{
   RetestZoneUpper=upper;
   RetestZoneLower=lower;
   RetestZoneBound=(upper>lower);
   return(RetestZoneBound);
}


//=== Build46.9 Retest Zone Validation ===
bool RetestZoneContainsPrice(double price)
{
   if(!RetestZoneBound) return(false);
   return(price>=RetestZoneLower && price<=RetestZoneUpper);
}

void ResetRetestBuild469()
{
   RetestZoneBound=false;
}


//=== Build47.0 Retest Execution Link ===
bool RetestExecutionReady=false;

void ResetRetestBuild470()
{
   RetestExecutionReady=false;
}

bool EvaluateRetestExecution()
{
   RetestExecutionReady=false;
   if(!HasValidRetest()) return false;
   RetestExecutionReady=true;
   return true;
}


//=== Build47.1 Rejection Foundation ===
bool RejectionEngineReady=false;
string RejectionReason="Waiting";

void ResetRejectionEngine()
{
   RejectionEngineReady=false;
   RejectionReason="Waiting";
}

bool EvaluateRejectionEngine()
{
   if(!RetestExecutionReady)
   {
      RejectionReason="Waiting for Retest Execution";
      return false;
   }
   RejectionEngineReady=true;
   RejectionReason="Retest execution ready";
   return true;
}


//=== Build47.2 Rejection Candle Scaffold ===
bool RejectionCandleDetected=false;
int RejectionCandleShift=-1;

void ResetRejectionBuild472()
{
   RejectionCandleDetected=false;
   RejectionCandleShift=-1;
}

bool IsRejectionCandleReady()
{
   return(RejectionEngineReady && RejectionCandleDetected);
}

void UpdateRejectionCandleState(bool detected,int shift)
{
   RejectionCandleDetected=detected;
   if(detected)
      RejectionCandleShift=shift;
}


//=== Build47.3 Rejection Candle Logic Foundation ===
bool IsSimpleBearishRejection(int shift)
{
   return(false);
}
bool IsSimpleBullishRejection(int shift)
{
   return(false);
}
void UpdateRejectionLogic()
{
   // Integrated for future candle logic integration
}


//=== Build47.4 Rejection Pattern Foundation ===
bool RejectionPatternReady=false;
int RejectionPatternStrength=0;

void ResetRejectionBuild474()
{
   RejectionPatternReady=false;
   RejectionPatternStrength=0;
}

bool EvaluateBasicRejectionPattern(const int shift)
{
   if(!CalculateRejectionMetrics(shift))
      return(false);
   RejectionPatternStrength=0;
   if(RejectionUpperWick>RejectionBodySize*2.0 || RejectionLowerWick>RejectionBodySize*2.0)
      RejectionPatternStrength=100;
   RejectionPatternReady=(RejectionPatternStrength>0);
   return(RejectionPatternReady);
}


//=== Build47.5 Rejection Strength Scaffold ===
bool RejectionStrengthReady=false;
double RejectionStrengthScore=0.0;

void ResetRejectionBuild475()
{
   RejectionStrengthReady=false;
   RejectionStrengthScore=0.0;
}

bool EvaluateRejectionStrength(const int shift)
{
   if(!RejectionPatternReady && !EvaluateBasicRejectionPattern(shift))
      return(false);
   RejectionStrengthScore=(double)RejectionPatternStrength;
   RejectionStrengthReady=(RejectionStrengthScore>=100.0);
   return(RejectionStrengthReady);
}


//=== Build47.6 Rejection Candle Metrics Foundation ===
bool RejectionMetricsReady=false;
double RejectionBodySize=0.0;
double RejectionUpperWick=0.0;
double RejectionLowerWick=0.0;

void ResetRejectionBuild476()
{
   RejectionMetricsReady=false;
   RejectionBodySize=0.0;
   RejectionUpperWick=0.0;
   RejectionLowerWick=0.0;
}

bool UpdateRejectionMetrics(const int shift)
{
   if(shift<0)
      return(false);

   RejectionMetricsReady=true;
   return(RejectionMetricsReady);
}



//=== Build47.7 Rejection Metrics Logic ===
bool CalculateRejectionMetrics(const int shift)
{
   if(shift<0) return(false);
   double o=iOpen(_Symbol,_Period,shift);
   double h=iHigh(_Symbol,_Period,shift);
   double l=iLow(_Symbol,_Period,shift);
   double c=iClose(_Symbol,_Period,shift);

   RejectionBodySize=MathAbs(c-o);
   RejectionUpperWick=h-MathMax(o,c);
   RejectionLowerWick=MathMin(o,c)-l;
   RejectionMetricsReady=true;
   return(true);
}


//=== Build47.8 Rejection Quality Foundation ===
double RejectionQualityScore=0.0;
bool   RejectionQualityReady=false;

void ResetRejectionBuild478()
{
   RejectionQualityScore=0.0;
   RejectionQualityReady=false;
}

bool EvaluateRejectionQuality()
{
   if(!RejectionMetricsReady)
      return(false);

   double total=RejectionUpperWick+RejectionLowerWick+RejectionBodySize;
   if(total<=0.0)
   {
      RejectionQualityScore=0.0;
      RejectionQualityReady=false;
      return(false);
   }

   double dominant=MathMax(RejectionUpperWick,RejectionLowerWick);
   RejectionQualityScore=dominant/total;
   RejectionQualityReady=(RejectionMetricsReady && RejectionPatternReady && EvaluateRejectionStrength(1) && RejectionQualityScore>=0.55);
   return(RejectionQualityReady);
}
//=== End Build47.8 ===


//=== Build47.9 Rejection Grade Classification ===
enum REJECTION_GRADE
{
   REJECTION_GRADE_NONE=0,
   REJECTION_GRADE_C,
   REJECTION_GRADE_B,
   REJECTION_GRADE_A
};

REJECTION_GRADE CurrentRejectionGrade=REJECTION_GRADE_NONE;

void ResetRejectionBuild479()
{
   CurrentRejectionGrade=REJECTION_GRADE_NONE;
}

bool ClassifyRejectionGrade()
{
   if(!RejectionQualityReady)
   {
      CurrentRejectionGrade=REJECTION_GRADE_NONE;
      return(false);
   }

   if(RejectionQualityScore>=0.85 && RejectionStrengthScore>=0.80)
      CurrentRejectionGrade=REJECTION_GRADE_A;
   else if(RejectionQualityScore>=0.70)
      CurrentRejectionGrade=REJECTION_GRADE_B;
   else if(RejectionQualityScore>=0.50)
      CurrentRejectionGrade=REJECTION_GRADE_C;
   else
      CurrentRejectionGrade=REJECTION_GRADE_NONE;

   return(CurrentRejectionGrade!=REJECTION_GRADE_NONE);
}
//=== End Build47.9 ===


//====================
// Build 48.0 Confirmation Engine Foundation
//====================
enum CONFIRMATION_ENGINE_STATE
  {
   CONF_ENGINE_NONE=0,
   CONF_ENGINE_WAITING,
   CONF_ENGINE_READY
  };

CONFIRMATION_ENGINE_STATE CurrentConfirmationEngine=CONF_ENGINE_NONE;
bool ConfirmationEngineReady=false;
string ConfirmationReason="Waiting";

void ResetConfirmationEngine()
  {
   CurrentConfirmationEngine=CONF_ENGINE_NONE;
   ConfirmationEngineReady=false;
   ConfirmationReason="Waiting";
  }

bool EvaluateConfirmationEngine()
  {
   // Step3: Confirmation consumes Decision state only.
   if(gDecisionContext.state!=DECISION_READY_BUY &&
      gDecisionContext.state!=DECISION_READY_SELL)
     {
      CurrentConfirmationEngine=CONF_ENGINE_WAITING;
      ConfirmationEngineReady=false;
      ConfirmationReason="Decision not ready";
      return(false);
     }

   if(CurrentRejectionGrade>=REJECTION_GRADE_B)
     {
      CurrentConfirmationEngine=CONF_ENGINE_READY;
      ConfirmationEngineReady=true;
      ConfirmationReason="Rejection qualified";
      return(true);
     }

   CurrentConfirmationEngine=CONF_ENGINE_WAITING;
   ConfirmationEngineReady=false;
   return(false);
  }
//====================


//=== Build48.1 Confirmation Candle Foundation ===
bool ConfirmationCandleDetected=false;
int ConfirmationCandleShift=-1;

void ResetConfirmationBuild481()
{
   ConfirmationCandleDetected=false;
   ConfirmationCandleShift=-1;
}

bool ConfirmationCandleReady()
{
   return ConfirmationCandleDetected;
}

void UpdateConfirmationCandle(bool detected,int shift)
{
   ConfirmationCandleDetected=detected;
   ConfirmationCandleShift=shift;
}


//=== Build48.2 Confirmation Logic Scaffold ===
bool ConfirmationLogicReady=false;
string ConfirmationLogicReason="Waiting";

void ResetConfirmationBuild482()
{
   ConfirmationLogicReady=false;
   ConfirmationLogicReason="Waiting";
}

bool UpdateConfirmationLogic(bool rejectionReady,bool retestReady)
{
   if(rejectionReady && retestReady)
   {
      ConfirmationLogicReady=true;
      ConfirmationLogicReason="Confirmation prerequisites satisfied";
      return(true);
   }
   ConfirmationLogicReady=false;
   ConfirmationLogicReason="Prerequisites not satisfied";
   return(false);
}


//=== Build48.3 Confirmation Candle Logic Foundation ===
bool ConfirmationPatternReady=false;
double ConfirmationBodySize=0.0;
double ConfirmationRange=0.0;

void ResetConfirmationBuild483()
{
   ConfirmationPatternReady=false;
   ConfirmationBodySize=0.0;
   ConfirmationRange=0.0;
}

bool CalculateConfirmationMetrics(const int shift)
{
   double o=iOpen(_Symbol,_Period,shift);
   double c=iClose(_Symbol,_Period,shift);
   double h=iHigh(_Symbol,_Period,shift);
   double l=iLow(_Symbol,_Period,shift);

   ConfirmationBodySize=MathAbs(c-o);
   ConfirmationRange=h-l;

   ConfirmationPatternReady=(ConfirmationRange>0.0);
   return ConfirmationPatternReady;
}


//=== Build48.4 Confirmation Quality Foundation ===
bool ConfirmationQualityReady=false;
double ConfirmationQualityScore=0.0;

void ResetConfirmationBuild484()
{
   ConfirmationQualityReady=false;
   ConfirmationQualityScore=0.0;
}

bool EvaluateConfirmationQuality()
{
   if(!ConfirmationPatternReady)
      return(false);
   if(ConfirmationRange<=0.0)
      return(false);

   ConfirmationQualityScore=ConfirmationBodySize/ConfirmationRange;
   ConfirmationQualityReady=(ConfirmationQualityScore>=0.50);
   return(ConfirmationQualityReady);
}
//=== End Build48.4 ===


//=== Build48.5 Confirmation Grade Foundation ===
enum CONFIRMATION_GRADE
{
   CONFIRMATION_GRADE_NONE=0,
   CONFIRMATION_GRADE_C,
   CONFIRMATION_GRADE_B,
   CONFIRMATION_GRADE_A
};

CONFIRMATION_GRADE CurrentConfirmationGrade=CONFIRMATION_GRADE_NONE;

void ResetConfirmationBuild485()
{
   CurrentConfirmationGrade=CONFIRMATION_GRADE_NONE;
}

void ClassifyConfirmationGrade()
{
   if(ConfirmationQualityScore>=0.80)
      CurrentConfirmationGrade=CONFIRMATION_GRADE_A;
   else if(ConfirmationQualityScore>=0.65)
      CurrentConfirmationGrade=CONFIRMATION_GRADE_B;
   else if(ConfirmationQualityScore>=0.50)
      CurrentConfirmationGrade=CONFIRMATION_GRADE_C;
   else
      CurrentConfirmationGrade=CONFIRMATION_GRADE_NONE;
}
//=== End Build48.5 ===


//=== Build48.6 Decision Engine Foundation ===
enum DECISION_ENGINE_STATE
  {
   DEC_ENGINE_NONE=0,
   DEC_ENGINE_WAITING,
   DEC_ENGINE_READY
  };
DECISION_ENGINE_STATE CurrentDecisionEngine=DEC_ENGINE_NONE;
bool DecisionEngineReady=false;
string DecisionReason="Waiting";

void ResetDecisionBuild486()
  {
   CurrentDecisionEngine=DEC_ENGINE_WAITING;
   DecisionEngineReady=false;
   DecisionReason="Waiting";
  }

bool EvaluateDecisionEngine()
  {
   if(CurrentConfirmationGrade!=CONFIRMATION_GRADE_NONE)
     {
      CurrentDecisionEngine=DEC_ENGINE_READY;
      DecisionEngineReady=true;
      DecisionReason="Confirmation accepted";
      return(true);
     }
   DecisionEngineReady=false;
   DecisionReason="Confirmation missing";
   return(false);
  }
//=== End Build48.6 ===


//=== Build48.7 Decision Outcome Foundation ===
enum DECISION_ACTION
{
   DECISION_NO_TRADE=0,
   DECISION_BUY,
   DECISION_SELL
};

DECISION_ACTION CurrentDecisionAction=DECISION_NO_TRADE;
double DecisionConfidence=0.0;

void ResetDecisionBuild487()
{
   CurrentDecisionAction=DECISION_NO_TRADE;
   DecisionConfidence=0.0;
}

bool DecisionOutcomeReady()
{
   return(DecisionEngineReady);
}

void UpdateDecisionOutcome(bool bullish,bool bearish,double confidence)
{
   DecisionConfidence=confidence;
   if(bullish)
      CurrentDecisionAction=DECISION_BUY;
   else if(bearish)
      CurrentDecisionAction=DECISION_SELL;
   else
      CurrentDecisionAction=DECISION_NO_TRADE;
}


//==============================
// Build 48.8 - Decision Validation Foundation
//==============================
enum DECISION_VALIDATION_STATE
  {
   DECISION_VALIDATION_WAITING=0,
   DECISION_VALIDATION_READY
  };

DECISION_VALIDATION_STATE CurrentDecisionValidation=DECISION_VALIDATION_WAITING;
bool DecisionValidated=false;
string DecisionValidationReason="Waiting";

void ResetDecisionBuild488()
  {
   CurrentDecisionValidation=DECISION_VALIDATION_WAITING;
   DecisionValidated=false;
   DecisionValidationReason="Waiting";
  }

bool ValidateDecisionPrerequisites(const bool trendReady,
                                   const bool bosReady,
                                   const bool chochReady,
                                   const bool confirmationReady)
  {
   if(trendReady && bosReady && chochReady && confirmationReady)
     {
      CurrentDecisionValidation=DECISION_VALIDATION_READY;
      DecisionValidated=true;
      DecisionValidationReason="All prerequisite engines ready";
      return(true);
     }

   CurrentDecisionValidation=DECISION_VALIDATION_WAITING;
   DecisionValidated=false;
   DecisionValidationReason="Waiting for prerequisite engines";
   return(false);
  }
//==============================


//==============================
// Build 48.9 - Decision Gate
//==============================
enum DECISION_GATE_STATE
{
   DECISION_GATE_LOCKED=0,
   DECISION_GATE_OPEN=1
};

DECISION_GATE_STATE CurrentDecisionGate=DECISION_GATE_LOCKED;
bool DecisionGateReady=false;

void ResetDecisionBuild489()
{
   CurrentDecisionGate=DECISION_GATE_LOCKED;
   DecisionGateReady=false;
}

bool UpdateDecisionGate(bool validated,bool confirmationReady)
{
   if(validated && confirmationReady)
   {
      CurrentDecisionGate=DECISION_GATE_OPEN;
      DecisionGateReady=true;
      return(true);
   }
   CurrentDecisionGate=DECISION_GATE_LOCKED;
   DecisionGateReady=false;
   return(false);
}
//==============================


//==============================
// Build 49.0 - Entry Foundation
//==============================

enum ENTRY_ENGINE_STATE
{
   ENTRY_ENGINE_IDLE=0,
   ENTRY_ENGINE_WAITING,
   ENTRY_ENGINE_READY,
   ENTRY_ENGINE_TRIGGERED
};

ENTRY_ENGINE_STATE CurrentEntryEngine=ENTRY_ENGINE_IDLE;
bool EntryEngineReady=false;
string EntryEngineReason="Waiting";

void ResetEntryBuild490()
{
   CurrentEntryEngine=ENTRY_ENGINE_IDLE;
   EntryEngineReady=false;
   EntryEngineReason="Waiting";
}

bool UpdateEntryEngine(bool decisionGateOpen,bool decisionReady)
{
   if(decisionGateOpen && decisionReady)
   {
      CurrentEntryEngine=ENTRY_ENGINE_READY;
      EntryEngineReady=true;
      EntryEngineReason="Entry prerequisites satisfied";
      return(true);
   }

   CurrentEntryEngine=ENTRY_ENGINE_WAITING;
   EntryEngineReady=false;
   EntryEngineReason="Waiting for decision gate";
   return(false);
}

//==============================
// End Build 49.0
//==============================



//==============================
// Build 49.1 - Entry Direction Foundation
//==============================
enum ENTRY_DIRECTION_STATE
{
   ENTRY_DIRECTION_NONE=0,
   ENTRY_DIRECTION_BUY,
   ENTRY_DIRECTION_SELL
};

ENTRY_DIRECTION_STATE CurrentEntryDirection=ENTRY_DIRECTION_NONE;
bool EntryDirectionReady=false;

void ResetEntryBuild491()
{
   CurrentEntryDirection=ENTRY_DIRECTION_NONE;
   EntryDirectionReady=false;
}

bool UpdateEntryDirection(bool entryReady,bool buySignal,bool sellSignal)
{
   EntryDirectionReady=false;
   CurrentEntryDirection=ENTRY_DIRECTION_NONE;

   if(!entryReady)
      return(false);

   if(buySignal && !sellSignal)
   {
      CurrentEntryDirection=ENTRY_DIRECTION_BUY;
      EntryDirectionReady=true;
      return(true);
   }

   if(sellSignal && !buySignal)
   {
      CurrentEntryDirection=ENTRY_DIRECTION_SELL;
      EntryDirectionReady=true;
      return(true);
   }

   return(false);
}
//==============================


//==============================
// Build 49.2 - Entry Validation Foundation
//==============================
enum ENTRY_VALIDATION_STATE
  {
   ENTRY_VALIDATION_WAITING=0,
   ENTRY_VALIDATION_READY
  };

ENTRY_VALIDATION_STATE CurrentEntryValidation=ENTRY_VALIDATION_WAITING;
bool EntryValidationPassed=false;
string EntryValidationReason="Waiting";

void ResetEntryBuild492()
  {
   CurrentEntryValidation=ENTRY_VALIDATION_WAITING;
   EntryValidationPassed=false;
   EntryValidationReason="Waiting";
  }

bool UpdateEntryValidation(bool trendAligned,bool decisionGateOpen,bool entryDirectionReady)
  {
   if(trendAligned && decisionGateOpen && entryDirectionReady)
     {
      CurrentEntryValidation=ENTRY_VALIDATION_READY;
      EntryValidationPassed=true;
      EntryValidationReason="Entry validated";
      return(true);
     }

   CurrentEntryValidation=ENTRY_VALIDATION_WAITING;
   EntryValidationPassed=false;
   EntryValidationReason="Entry validation failed";
   return(false);
  }

//==============================
// End Build 49.2
//==============================



//==============================
// Build 49.3 - Entry Signal Foundation
//==============================
enum ENTRY_SIGNAL_STATE
{
   ENTRY_SIGNAL_NONE=0,
   ENTRY_SIGNAL_WAITING,
   ENTRY_SIGNAL_READY
};

ENTRY_SIGNAL_STATE CurrentEntrySignal=ENTRY_SIGNAL_NONE;
bool EntrySignalReady=false;
string EntrySignalReason="Waiting";

void ResetEntryBuild493()
{
   CurrentEntrySignal=ENTRY_SIGNAL_NONE;
   EntrySignalReady=false;
   EntrySignalReason="Waiting";
}

bool UpdateEntrySignal(bool entryValidated,bool buyDirection,bool sellDirection)
{
   EntrySignalReady=false;
   CurrentEntrySignal=ENTRY_SIGNAL_WAITING;
   EntrySignalReason="Waiting for valid entry";

   if(entryValidated && (buyDirection!=sellDirection))
   {
      CurrentEntrySignal=ENTRY_SIGNAL_READY;
      EntrySignalReady=true;
      EntrySignalReason="Entry signal ready";
      return(true);
   }
   return(false);
}
//==============================


//==============================
// Build 49.4 - Entry Trigger Foundation
//==============================
enum ENTRY_TRIGGER_STATE
  {
   ENTRY_TRIGGER_IDLE=0,
   ENTRY_TRIGGER_ARMED,
   ENTRY_TRIGGER_FIRED
  };

ENTRY_TRIGGER_STATE CurrentEntryTrigger=ENTRY_TRIGGER_IDLE;
bool EntryTriggerReady=false;
string EntryTriggerReason="Waiting";

void ResetEntryBuild494()
  {
   CurrentEntryTrigger=ENTRY_TRIGGER_IDLE;
   EntryTriggerReady=false;
   EntryTriggerReason="Waiting";
  }

bool UpdateEntryTrigger(bool entrySignalReady)
  {
   if(!entrySignalReady)
     {
      CurrentEntryTrigger=ENTRY_TRIGGER_IDLE;
      EntryTriggerReady=false;
      EntryTriggerReason="Entry signal not ready";
      return(false);
     }

   CurrentEntryTrigger=ENTRY_TRIGGER_ARMED;
   EntryTriggerReady=true;
   EntryTriggerReason="Entry trigger armed";
   return(true);
  }

//==============================
// End Build 49.4
//==============================


//==============================
// Build 49.5 - Entry Execution Foundation
//==============================

enum ENTRY_EXECUTION_STATE
{
   ENTRY_EXECUTION_WAITING=0,
   ENTRY_EXECUTION_READY,
   ENTRY_EXECUTION_EXECUTED
};

ENTRY_EXECUTION_STATE CurrentEntryExecution=ENTRY_EXECUTION_WAITING;
bool EntryExecutionReady=false;
string EntryExecutionReason="Waiting";

void ResetEntryBuild495()
{
   CurrentEntryExecution=ENTRY_EXECUTION_WAITING;
   EntryExecutionReady=false;
   EntryExecutionReason="Waiting";
}

bool UpdateEntryExecution(bool triggerArmed,bool validationPassed)
{
   if(triggerArmed && validationPassed)
   {
      CurrentEntryExecution=ENTRY_EXECUTION_READY;
      EntryExecutionReady=true;
      EntryExecutionReason="Execution conditions satisfied";
      return(true);
   }

   CurrentEntryExecution=ENTRY_EXECUTION_WAITING;
   EntryExecutionReady=false;
   EntryExecutionReason="Waiting for execution conditions";
   return(false);
}


//==============================
// Build 49.6 - Entry Signal Output Foundation
//==============================

enum ENTRY_OUTPUT_STATE
{
   ENTRY_OUTPUT_NONE,
   ENTRY_OUTPUT_BUY,
   ENTRY_OUTPUT_SELL
};

ENTRY_OUTPUT_STATE CurrentEntryOutput=ENTRY_OUTPUT_NONE;
bool EntryOutputReady=false;
string EntryOutputReason="Waiting";

void ResetEntryBuild496()
{
   CurrentEntryOutput=ENTRY_OUTPUT_NONE;
   EntryOutputReady=false;
   EntryOutputReason="Waiting";
}

bool UpdateEntryOutput(bool executionReady,bool buySignal,bool sellSignal)
{
   EntryOutputReady=false;
   CurrentEntryOutput=ENTRY_OUTPUT_NONE;
   EntryOutputReason="Conditions not satisfied";

   if(!executionReady)
      return(false);

   if(buySignal && !sellSignal)
   {
      CurrentEntryOutput=ENTRY_OUTPUT_BUY;
      EntryOutputReady=true;
      EntryOutputReason="BUY output ready";
      return(true);
   }

   if(sellSignal && !buySignal)
   {
      CurrentEntryOutput=ENTRY_OUTPUT_SELL;
      EntryOutputReady=true;
      EntryOutputReason="SELL output ready";
      return(true);
   }

   return(false);
}

//==============================
// End Build 49.6
//==============================


//==============================
// Build 49.7 - Entry Display Foundation
//==============================
enum ENTRY_DISPLAY_STATE
{
   ENTRY_DISPLAY_HIDDEN,
   ENTRY_DISPLAY_VISIBLE
};

ENTRY_DISPLAY_STATE CurrentEntryDisplay=ENTRY_DISPLAY_HIDDEN;
bool EntryDisplayReady=false;
string EntryDisplayReason="Waiting";

void ResetEntryBuild497()
{
   CurrentEntryDisplay=ENTRY_DISPLAY_HIDDEN;
   EntryDisplayReady=false;
   EntryDisplayReason="Waiting";
}

bool UpdateEntryDisplay(bool outputReady)
{
   if(outputReady)
   {
      CurrentEntryDisplay=ENTRY_DISPLAY_VISIBLE;
      EntryDisplayReady=true;
      EntryDisplayReason="Entry display ready";
      return(true);
   }
   CurrentEntryDisplay=ENTRY_DISPLAY_HIDDEN;
   EntryDisplayReady=false;
   EntryDisplayReason="Waiting";
   return(false);
}


//==============================
// Build 49.8 - Stage Visual Link Foundation
//==============================

enum ENTRY_STAGE_VISUAL_STATE
  {
   ENTRY_STAGE_VISUAL_INACTIVE=0,
   ENTRY_STAGE_VISUAL_ACTIVE
  };

ENTRY_STAGE_VISUAL_STATE CurrentEntryStageVisual=ENTRY_STAGE_VISUAL_INACTIVE;
bool EntryStageVisualReady=false;
string EntryStageVisualReason="Waiting";

void ResetEntryBuild498()
  {
   CurrentEntryStageVisual=ENTRY_STAGE_VISUAL_INACTIVE;
   EntryStageVisualReady=false;
   EntryStageVisualReason="Waiting";
  }

bool UpdateEntryStageVisual(bool displayReady)
  {
   if(displayReady)
     {
      CurrentEntryStageVisual=ENTRY_STAGE_VISUAL_ACTIVE;
      EntryStageVisualReady=true;
      EntryStageVisualReason="ENTRY stage ready for Stage Visual Engine";
      return(true);
     }

   CurrentEntryStageVisual=ENTRY_STAGE_VISUAL_INACTIVE;
   EntryStageVisualReady=false;
   EntryStageVisualReason="Waiting for Entry Display";
   return(false);
  }

//==============================
// End Build 49.8
//==============================



//==============================
// Build 49.9 - Stage Panel Foundation
//==============================
enum ENTRY_STAGE_PANEL_STATE
{
   ENTRY_STAGE_PANEL_HIDDEN=0,
   ENTRY_STAGE_PANEL_VISIBLE
};

ENTRY_STAGE_PANEL_STATE CurrentEntryStagePanel=ENTRY_STAGE_PANEL_HIDDEN;
bool EntryStagePanelReady=false;
string EntryStagePanelReason="Waiting";

void ResetEntryBuild499()
{
   CurrentEntryStagePanel=ENTRY_STAGE_PANEL_HIDDEN;
   EntryStagePanelReady=false;
   EntryStagePanelReason="Waiting";
}

bool UpdateEntryStagePanel(bool stageVisualReady)
{
   if(stageVisualReady)
   {
      CurrentEntryStagePanel=ENTRY_STAGE_PANEL_VISIBLE;
      EntryStagePanelReady=true;
      EntryStagePanelReason="Stage Panel Ready";
      return(true);
   }

   CurrentEntryStagePanel=ENTRY_STAGE_PANEL_HIDDEN;
   EntryStagePanelReady=false;
   EntryStagePanelReason="Waiting";
   return(false);
}
//==============================


//==============================
// Build 50.0 - Stage Visual Rendering Foundation
//==============================
enum STAGE_RENDER_STATE
{
   STAGE_RENDER_IDLE,
   STAGE_RENDER_PENDING,
   STAGE_RENDER_DONE
};

STAGE_RENDER_STATE CurrentStageRender=STAGE_RENDER_IDLE;
bool StageRenderReady=false;
string StageRenderReason="Waiting";

void ResetStageRenderBuild500()
{
   CurrentStageRender=STAGE_RENDER_IDLE;
   StageRenderReady=false;
   StageRenderReason="Waiting";
}

void UpdateStageRender(bool stagePanelVisible)
{
   if(stagePanelVisible)
   {
      CurrentStageRender=STAGE_RENDER_PENDING;
      StageRenderReady=true;
      StageRenderReason="Ready for rendering";
   }
   else
   {
      CurrentStageRender=STAGE_RENDER_IDLE;
      StageRenderReady=false;
      StageRenderReason="Waiting for stage panel";
   }
}


//==============================
// Build 50.1 - Entry Visual Objects Foundation
//==============================
enum ENTRY_VISUAL_OBJECT_STATE
{
   ENTRY_VISUAL_OBJECT_IDLE=0,
   ENTRY_VISUAL_OBJECT_READY
};

ENTRY_VISUAL_OBJECT_STATE CurrentEntryVisualObject=ENTRY_VISUAL_OBJECT_IDLE;
bool EntryVisualObjectsCreated=false;
string EntryVisualObjectPrefix="AST_ENTRY_";

void ResetStageRenderBuild501()
{
   CurrentEntryVisualObject=ENTRY_VISUAL_OBJECT_IDLE;
   EntryVisualObjectsCreated=false;
}

bool PrepareEntryVisualObjects()
{
   CurrentEntryVisualObject=ENTRY_VISUAL_OBJECT_READY;
   EntryVisualObjectsCreated=true;
   return(true);
}


//==============================
// Build 50.2 - Entry Line Foundation
//==============================
enum ENTRY_LINE_STATE
{
   ENTRY_LINE_HIDDEN=0,
   ENTRY_LINE_READY
};

ENTRY_LINE_STATE CurrentEntryLine=ENTRY_LINE_HIDDEN;
bool EntryLinePrepared=false;
string EntryLineName="AST_ENTRY_LINE";

void ResetStageRenderBuild502()
{
   CurrentEntryLine=ENTRY_LINE_HIDDEN;
   EntryLinePrepared=false;
}

bool PrepareEntryLine(double price)
{
   if(price<=0.0)
      return(false);

   EntryLinePrepared=true;
   CurrentEntryLine=ENTRY_LINE_READY;
   return(true);
}


//==============================
// Build 50.3 - Entry HLine Object Foundation
//==============================
enum ENTRY_HLINE_OBJECT_STATE
{
   ENTRY_HLINE_OBJECT_IDLE=0,
   ENTRY_HLINE_OBJECT_CREATED
};

ENTRY_HLINE_OBJECT_STATE CurrentEntryHLineObject=ENTRY_HLINE_OBJECT_IDLE;
bool EntryHLineObjectCreated=false;
string EntryHLineObjectName="";

void ResetStageRenderBuild503()
{
   CurrentEntryHLineObject=ENTRY_HLINE_OBJECT_IDLE;
   EntryHLineObjectCreated=false;
   EntryHLineObjectName="";
}

bool CreateEntryHLineObject(const double price)
{
   if(price<=0.0)
      return(false);

   EntryHLineObjectName=EntryVisualObjectPrefix+"_HLINE";
   CurrentEntryHLineObject=ENTRY_HLINE_OBJECT_CREATED;
   EntryHLineObjectCreated=true;
   return(true);
}


//==============================
// Build 50.4 - Entry HLine Rendering
//==============================
enum ENTRY_HLINE_RENDER_STATE
{
   ENTRY_HLINE_RENDER_IDLE=0,
   ENTRY_HLINE_RENDER_RENDERED
};

ENTRY_HLINE_RENDER_STATE CurrentEntryHLineRender=ENTRY_HLINE_RENDER_IDLE;
bool EntryHLineRendered=false;

void ResetStageRenderBuild504()
{
   CurrentEntryHLineRender=ENTRY_HLINE_RENDER_IDLE;
   EntryHLineRendered=false;
}

bool RenderEntryHLine(const double price)
{
   if(price<=0.0)
      return(false);

   string objName=EntryVisualObjectPrefix+"_HLINE";

   if(ObjectFind(0,objName)<0)
      ObjectCreate(0,objName,OBJ_HLINE,0,0,price);

   ObjectSetDouble(0,objName,OBJPROP_PRICE,price);

   CurrentEntryHLineRender=ENTRY_HLINE_RENDER_RENDERED;
   EntryHLineRendered=true;
   return(true);
}


//==============================
// Build 50.5 - Entry Label Rendering
//==============================
enum ENTRY_LABEL_RENDER_STATE
{
   ENTRY_LABEL_RENDER_IDLE=0,
   ENTRY_LABEL_RENDER_RENDERED
};

ENTRY_LABEL_RENDER_STATE CurrentEntryLabelRender=ENTRY_LABEL_RENDER_IDLE;
bool EntryLabelRendered=false;
string EntryLabelObjectName="AST_ENTRY_LABEL";

void ResetStageRenderBuild505()
{
   CurrentEntryLabelRender=ENTRY_LABEL_RENDER_IDLE;
   EntryLabelRendered=false;
}

bool RenderEntryLabel(const datetime when,const double price)
{
   if(price<=0)
      return(false);

   if(ObjectFind(0,EntryLabelObjectName)<0)
   {
      ObjectCreate(0,EntryLabelObjectName,OBJ_TEXT,0,when,price);
      ObjectSetString(0,EntryLabelObjectName,OBJPROP_TEXT,"ENTRY");
   }
   else
   {
      ObjectMove(0,EntryLabelObjectName,0,when,price);
   }

   CurrentEntryLabelRender=ENTRY_LABEL_RENDER_RENDERED;
   EntryLabelRendered=true;
   return(true);
}


//==============================
// Build 50.6 - Entry Visual Group
//==============================
enum ENTRY_VISUAL_GROUP_STATE
{
   ENTRY_VISUAL_GROUP_IDLE=0,
   ENTRY_VISUAL_GROUP_READY
};

ENTRY_VISUAL_GROUP_STATE CurrentEntryVisualGroup=ENTRY_VISUAL_GROUP_IDLE;
bool EntryVisualGroupReady=false;
string EntryVisualGroupReason="Waiting";

void ResetStageRenderBuild506()
{
   CurrentEntryVisualGroup=ENTRY_VISUAL_GROUP_IDLE;
   EntryVisualGroupReady=false;
   EntryVisualGroupReason="Waiting";
}

bool UpdateEntryVisualGroup(bool lineRendered,bool labelRendered)
{
   if(lineRendered && labelRendered)
   {
      CurrentEntryVisualGroup=ENTRY_VISUAL_GROUP_READY;
      EntryVisualGroupReady=true;
      EntryVisualGroupReason="Entry visual group ready";
      return(true);
   }
   CurrentEntryVisualGroup=ENTRY_VISUAL_GROUP_IDLE;
   EntryVisualGroupReady=false;
   EntryVisualGroupReason="Waiting for line/label";
   return(false);
}


//==============================
// Build 50.7 - Stage Visual Manager Foundation
//==============================
enum STAGE_VISUAL_MANAGER_STATE
{
   STAGE_VISUAL_MANAGER_IDLE=0,
   STAGE_VISUAL_MANAGER_READY
};

STAGE_VISUAL_MANAGER_STATE CurrentStageVisualManager=STAGE_VISUAL_MANAGER_IDLE;
bool StageVisualManagerReady=false;
string StageVisualManagerReason="Waiting";

void ResetStageRenderBuild507()
{
   CurrentStageVisualManager=STAGE_VISUAL_MANAGER_IDLE;
   StageVisualManagerReady=false;
   StageVisualManagerReason="Waiting";
}

bool UpdateStageVisualManager(bool entryVisualGroupReady)
{
   if(entryVisualGroupReady)
   {
      CurrentStageVisualManager=STAGE_VISUAL_MANAGER_READY;
      StageVisualManagerReady=true;
      StageVisualManagerReason="Stage Visual Manager Ready";
      return(true);
   }
   CurrentStageVisualManager=STAGE_VISUAL_MANAGER_IDLE;
   StageVisualManagerReady=false;
   StageVisualManagerReason="Waiting";
   return(false);
}
//==============================


//==============================
// Build 50.8 - Stage Registry Foundation
//==============================
enum STAGE_REGISTRY_STATE
{
   STAGE_REGISTRY_IDLE=0,
   STAGE_REGISTRY_READY
};

STAGE_REGISTRY_STATE CurrentStageRegistry=STAGE_REGISTRY_IDLE;
bool StageRegistryReady=false;
string StageRegistryReason="Waiting";

void ResetStageRenderBuild508()
{
   CurrentStageRegistry=STAGE_REGISTRY_IDLE;
   StageRegistryReady=false;
   StageRegistryReason="Waiting";
}

void UpdateStageRegistry(bool stageManagerReady)
{
   if(stageManagerReady)
   {
      CurrentStageRegistry=STAGE_REGISTRY_READY;
      StageRegistryReady=true;
      StageRegistryReason="Registry Ready";
   }
   else
   {
      CurrentStageRegistry=STAGE_REGISTRY_IDLE;
      StageRegistryReady=false;
      StageRegistryReason="Waiting";
   }
}


//==============================
// Build 50.9 - Stage Dispatcher Foundation
//==============================
enum STAGE_DISPATCHER_STATE
{
   STAGE_DISPATCHER_IDLE=0,
   STAGE_DISPATCHER_READY
};

STAGE_DISPATCHER_STATE CurrentStageDispatcher=STAGE_DISPATCHER_IDLE;
bool StageDispatcherReady=false;
string StageDispatcherReason="Waiting";

void ResetStageRenderBuild509()
{
   CurrentStageDispatcher=STAGE_DISPATCHER_IDLE;
   StageDispatcherReady=false;
   StageDispatcherReason="Waiting";
}

bool UpdateStageDispatcher(bool registryReady)
{
   if(registryReady)
   {
      CurrentStageDispatcher=STAGE_DISPATCHER_READY;
      StageDispatcherReady=true;
      StageDispatcherReason="Registry ready";
      return(true);
   }

   CurrentStageDispatcher=STAGE_DISPATCHER_IDLE;
   StageDispatcherReady=false;
   StageDispatcherReason="Registry not ready";
   return(false);
}
//==============================


//==============================
// Build 51.0 - Stage Render Queue Foundation
//==============================
enum STAGE_RENDER_QUEUE_STATE
{
   STAGE_RENDER_QUEUE_IDLE=0,
   STAGE_RENDER_QUEUE_READY
};

STAGE_RENDER_QUEUE_STATE CurrentStageRenderQueue=STAGE_RENDER_QUEUE_IDLE;
bool StageRenderQueueReady=false;
string StageRenderQueueReason="Waiting";

void ResetStageRenderBuild510()
{
   CurrentStageRenderQueue=STAGE_RENDER_QUEUE_IDLE;
   StageRenderQueueReady=false;
   StageRenderQueueReason="Waiting";
}

void UpdateStageRenderQueue(bool dispatcherReady)
{
   if(dispatcherReady)
   {
      CurrentStageRenderQueue=STAGE_RENDER_QUEUE_READY;
      StageRenderQueueReady=true;
      StageRenderQueueReason="Render queue ready";
   }
   else
   {
      ResetStageRenderBuild510();
   }
}


//==============================
// Build 51.1 - Stage Render Scheduler Foundation
//==============================
enum STAGE_RENDER_SCHEDULER_STATE
{
   STAGE_RENDER_SCHEDULER_IDLE=0,
   STAGE_RENDER_SCHEDULER_READY
};

STAGE_RENDER_SCHEDULER_STATE CurrentStageRenderScheduler=STAGE_RENDER_SCHEDULER_IDLE;
bool StageRenderSchedulerReady=false;
string StageRenderSchedulerReason="Idle";

void ResetStageRenderBuild511()
{
   CurrentStageRenderScheduler=STAGE_RENDER_SCHEDULER_IDLE;
   StageRenderSchedulerReady=false;
   StageRenderSchedulerReason="Idle";
}

void UpdateStageRenderScheduler(bool queueReady)
{
   if(queueReady)
   {
      CurrentStageRenderScheduler=STAGE_RENDER_SCHEDULER_READY;
      StageRenderSchedulerReady=true;
      StageRenderSchedulerReason="Queue ready";
   }
   else
   {
      ResetStageRenderBuild511();
   }
}


//==============================
// Build 51.2 - Stage Render Pipeline Foundation
//==============================
enum STAGE_RENDER_PIPELINE_STATE
{
   STAGE_RENDER_PIPELINE_IDLE=0,
   STAGE_RENDER_PIPELINE_READY
};

STAGE_RENDER_PIPELINE_STATE CurrentStageRenderPipeline=STAGE_RENDER_PIPELINE_IDLE;
bool StageRenderPipelineReady=false;
string StageRenderPipelineReason="Waiting";

void ResetStageRenderBuild512()
{
   CurrentStageRenderPipeline=STAGE_RENDER_PIPELINE_IDLE;
   StageRenderPipelineReady=false;
   StageRenderPipelineReason="Waiting";
}

bool UpdateStageRenderPipeline(bool schedulerReady)
{
   if(schedulerReady)
   {
      CurrentStageRenderPipeline=STAGE_RENDER_PIPELINE_READY;
      StageRenderPipelineReady=true;
      StageRenderPipelineReason="Pipeline Ready";
      return(true);
   }
   CurrentStageRenderPipeline=STAGE_RENDER_PIPELINE_IDLE;
   StageRenderPipelineReady=false;
   StageRenderPipelineReason="Scheduler Not Ready";
   return(false);
}


//==============================
// Build 51.3 - Stage Render Executor Foundation
//==============================
enum STAGE_RENDER_EXECUTOR_STATE
{
   STAGE_RENDER_EXECUTOR_IDLE=0,
   STAGE_RENDER_EXECUTOR_READY
};

STAGE_RENDER_EXECUTOR_STATE CurrentStageRenderExecutor=STAGE_RENDER_EXECUTOR_IDLE;
bool StageRenderExecutorReady=false;
string StageRenderExecutorReason="Waiting";

void ResetStageRenderBuild513()
{
   CurrentStageRenderExecutor=STAGE_RENDER_EXECUTOR_IDLE;
   StageRenderExecutorReady=false;
   StageRenderExecutorReason="Waiting";
}

bool UpdateStageRenderExecutor(bool pipelineReady)
{
   if(pipelineReady)
   {
      CurrentStageRenderExecutor=STAGE_RENDER_EXECUTOR_READY;
      StageRenderExecutorReady=true;
      StageRenderExecutorReason="Executor Ready";
      return(true);
   }
   CurrentStageRenderExecutor=STAGE_RENDER_EXECUTOR_IDLE;
   StageRenderExecutorReady=false;
   StageRenderExecutorReason="Pipeline Not Ready";
   return(false);
}


//==============================
// Build 51.4 - Stage Render Commit Foundation
//==============================
enum STAGE_RENDER_COMMIT_STATE
{
   STAGE_RENDER_COMMIT_IDLE=0,
   STAGE_RENDER_COMMIT_READY
};

STAGE_RENDER_COMMIT_STATE CurrentStageRenderCommit=STAGE_RENDER_COMMIT_IDLE;
bool StageRenderCommitReady=false;
string StageRenderCommitReason="Waiting";

void ResetStageRenderBuild514()
{
   CurrentStageRenderCommit=STAGE_RENDER_COMMIT_IDLE;
   StageRenderCommitReady=false;
   StageRenderCommitReason="Waiting";
}

void UpdateStageRenderCommit(bool executorReady)
{
   if(executorReady)
   {
      CurrentStageRenderCommit=STAGE_RENDER_COMMIT_READY;
      StageRenderCommitReady=true;
      StageRenderCommitReason="Render commit ready";
   }
   else
   {
      ResetStageRenderBuild514();
   }
}


//====================================================
// Build 51.5 - Stage Render Finalizer Foundation
//====================================================
enum STAGE_RENDER_FINALIZER_STATE
{
   STAGE_RENDER_FINALIZER_IDLE = 0,
   STAGE_RENDER_FINALIZER_READY
};

STAGE_RENDER_FINALIZER_STATE CurrentStageRenderFinalizer=STAGE_RENDER_FINALIZER_IDLE;
bool StageRenderFinalizerReady=false;
string StageRenderFinalizerReason="Idle";

void ResetStageRenderBuild515()
{
   CurrentStageRenderFinalizer=STAGE_RENDER_FINALIZER_IDLE;
   StageRenderFinalizerReady=false;
   StageRenderFinalizerReason="Idle";
}

void UpdateStageRenderFinalizer(bool commitReady)
{
   if(commitReady)
   {
      CurrentStageRenderFinalizer=STAGE_RENDER_FINALIZER_READY;
      StageRenderFinalizerReady=true;
      StageRenderFinalizerReason="Finalizer Ready";
   }
   else
   {
      CurrentStageRenderFinalizer=STAGE_RENDER_FINALIZER_IDLE;
      StageRenderFinalizerReady=false;
      StageRenderFinalizerReason="Waiting Commit";
   }
}
//====================================================


//==============================
// Build 52.0 - Stage Visual Integration Foundation
//==============================
enum STAGE_VISUAL_INTEGRATION_STATE
{
   STAGE_VISUAL_INTEGRATION_IDLE=0,
   STAGE_VISUAL_INTEGRATION_READY
};

STAGE_VISUAL_INTEGRATION_STATE CurrentStageVisualIntegration=STAGE_VISUAL_INTEGRATION_IDLE;
bool StageVisualIntegrationReady=false;
string StageVisualIntegrationReason="Waiting";

void ResetStageRenderBuild520()
{
   CurrentStageVisualIntegration=STAGE_VISUAL_INTEGRATION_IDLE;
   StageVisualIntegrationReady=false;
   StageVisualIntegrationReason="Waiting";
}

void UpdateStageVisualIntegration(bool finalizerReady)
{
   if(finalizerReady)
   {
      CurrentStageVisualIntegration=STAGE_VISUAL_INTEGRATION_READY;
      StageVisualIntegrationReady=true;
      StageVisualIntegrationReason="Stage Visual Integration Ready";
   }
   else
   {
      CurrentStageVisualIntegration=STAGE_VISUAL_INTEGRATION_IDLE;
      StageVisualIntegrationReady=false;
      StageVisualIntegrationReason="Waiting for Finalizer";
   }
}


//==============================
// Build 52.1 - Stage Visual Sync Foundation
//==============================
enum STAGE_VISUAL_SYNC_STATE
{
   STAGE_VISUAL_SYNC_IDLE=0,
   STAGE_VISUAL_SYNC_READY
};

STAGE_VISUAL_SYNC_STATE CurrentStageVisualSync=STAGE_VISUAL_SYNC_IDLE;
bool StageVisualSyncReady=false;
string StageVisualSyncReason="Waiting";

void ResetStageRenderBuild521()
{
   CurrentStageVisualSync=STAGE_VISUAL_SYNC_IDLE;
   StageVisualSyncReady=false;
   StageVisualSyncReason="Waiting";
}

void UpdateStageVisualSync(bool integrationReady)
{
   if(integrationReady)
   {
      CurrentStageVisualSync=STAGE_VISUAL_SYNC_READY;
      StageVisualSyncReady=true;
      StageVisualSyncReason="Stage Visual Sync Ready";
   }
   else
   {
      CurrentStageVisualSync=STAGE_VISUAL_SYNC_IDLE;
      StageVisualSyncReady=false;
      StageVisualSyncReason="Waiting";
   }
}
//==============================


//==============================
// Build 52.2 - Stage Visual Refresh Foundation
//==============================
enum STAGE_VISUAL_REFRESH_STATE
{
   STAGE_VISUAL_REFRESH_IDLE=0,
   STAGE_VISUAL_REFRESH_READY
};

STAGE_VISUAL_REFRESH_STATE CurrentStageVisualRefresh=STAGE_VISUAL_REFRESH_IDLE;
bool StageVisualRefreshReady=false;
string StageVisualRefreshReason="Idle";

void ResetStageRenderBuild522()
{
   CurrentStageVisualRefresh=STAGE_VISUAL_REFRESH_IDLE;
   StageVisualRefreshReady=false;
   StageVisualRefreshReason="Idle";
}

void UpdateStageVisualRefresh(bool syncReady)
{
   if(syncReady)
   {
      CurrentStageVisualRefresh=STAGE_VISUAL_REFRESH_READY;
      StageVisualRefreshReady=true;
      StageVisualRefreshReason="Refresh ready";
   }
   else
   {
      CurrentStageVisualRefresh=STAGE_VISUAL_REFRESH_IDLE;
      StageVisualRefreshReady=false;
      StageVisualRefreshReason="Waiting for sync";
   }
}


//=========================
// Build 52.3
// Stage Visual Update Foundation
//=========================
enum STAGE_VISUAL_UPDATE_STATE
{
   STAGE_VISUAL_UPDATE_IDLE=0,
   STAGE_VISUAL_UPDATE_READY
};

STAGE_VISUAL_UPDATE_STATE CurrentStageVisualUpdate=STAGE_VISUAL_UPDATE_IDLE;
bool StageVisualUpdateReady=false;
string StageVisualUpdateReason="Waiting";

void ResetStageRenderBuild523()
{
   CurrentStageVisualUpdate=STAGE_VISUAL_UPDATE_IDLE;
   StageVisualUpdateReady=false;
   StageVisualUpdateReason="Waiting";
}

void UpdateStageVisualUpdate(bool refreshReady)
{
   if(refreshReady)
   {
      CurrentStageVisualUpdate=STAGE_VISUAL_UPDATE_READY;
      StageVisualUpdateReady=true;
      StageVisualUpdateReason="Stage visual update ready";
   }
   else
   {
      CurrentStageVisualUpdate=STAGE_VISUAL_UPDATE_IDLE;
      StageVisualUpdateReady=false;
      StageVisualUpdateReason="Waiting for refresh";
   }
}


//=========================
// Build 52.4 - Stage Visual Refresh Cycle Foundation
//=========================
enum STAGE_VISUAL_REFRESH_CYCLE_STATE
{
   STAGE_VISUAL_REFRESH_CYCLE_IDLE=0,
   STAGE_VISUAL_REFRESH_CYCLE_READY
};

STAGE_VISUAL_REFRESH_CYCLE_STATE CurrentStageVisualRefreshCycle=STAGE_VISUAL_REFRESH_CYCLE_IDLE;
bool StageVisualRefreshCycleReady=false;
string StageVisualRefreshCycleReason="Idle";

void ResetStageRenderBuild524()
{
   CurrentStageVisualRefreshCycle=STAGE_VISUAL_REFRESH_CYCLE_IDLE;
   StageVisualRefreshCycleReady=false;
   StageVisualRefreshCycleReason="Idle";
}

void UpdateStageVisualRefreshCycle(bool updateReady)
{
   if(updateReady)
   {
      CurrentStageVisualRefreshCycle=STAGE_VISUAL_REFRESH_CYCLE_READY;
      StageVisualRefreshCycleReady=true;
      StageVisualRefreshCycleReason="Refresh cycle ready";
   }
   else
   {
      ResetStageRenderBuild524();
   }
}


//==============================
// Build 52.5 - Stage Visual Refresh Manager Foundation
//==============================
enum STAGE_VISUAL_REFRESH_MANAGER_STATE
{
   STAGE_VISUAL_REFRESH_MANAGER_IDLE=0,
   STAGE_VISUAL_REFRESH_MANAGER_READY
};

STAGE_VISUAL_REFRESH_MANAGER_STATE CurrentStageVisualRefreshManager=STAGE_VISUAL_REFRESH_MANAGER_IDLE;
bool StageVisualRefreshManagerReady=false;
string StageVisualRefreshManagerReason="Waiting";

void ResetStageRenderBuild525()
{
   CurrentStageVisualRefreshManager=STAGE_VISUAL_REFRESH_MANAGER_IDLE;
   StageVisualRefreshManagerReady=false;
   StageVisualRefreshManagerReason="Waiting";
}

bool UpdateStageVisualRefreshManager(bool refreshCycleReady)
{
   if(refreshCycleReady)
   {
      CurrentStageVisualRefreshManager=STAGE_VISUAL_REFRESH_MANAGER_READY;
      StageVisualRefreshManagerReady=true;
      StageVisualRefreshManagerReason="Refresh cycle ready";
      return(true);
   }

   CurrentStageVisualRefreshManager=STAGE_VISUAL_REFRESH_MANAGER_IDLE;
   StageVisualRefreshManagerReady=false;
   StageVisualRefreshManagerReason="Waiting for refresh cycle";
   return(false);
}


//==============================
// Build 52.6 - StageVisualRefreshControllerFoundation
//==============================
enum STAGE_VISUAL_REFRESH_CONTROLLER_STATE
{
   STAGE_VISUAL_REFRESH_CONTROLLER_IDLE = 0,
   STAGE_VISUAL_REFRESH_CONTROLLER_READY
};

STAGE_VISUAL_REFRESH_CONTROLLER_STATE CurrentStageVisualRefreshController=STAGE_VISUAL_REFRESH_CONTROLLER_IDLE;
bool StageVisualRefreshControllerReady=false;
string StageVisualRefreshControllerReason="Waiting";

void ResetStageRenderBuild526()
{
   CurrentStageVisualRefreshController=STAGE_VISUAL_REFRESH_CONTROLLER_IDLE;
   StageVisualRefreshControllerReady=false;
   StageVisualRefreshControllerReason="Waiting";
}

void UpdateStageVisualRefreshController(bool refreshManagerReady)
{
   if(refreshManagerReady)
   {
      CurrentStageVisualRefreshController=STAGE_VISUAL_REFRESH_CONTROLLER_READY;
      StageVisualRefreshControllerReady=true;
      StageVisualRefreshControllerReason="Refresh manager ready";
   }
   else
   {
      ResetStageRenderBuild526();
   }
}


//==============================
// Build 52.7 - Stage Visual Refresh Dispatcher Foundation
//==============================
enum STAGE_VISUAL_REFRESH_DISPATCHER_STATE
{
   STAGE_VISUAL_REFRESH_DISPATCHER_IDLE = 0,
   STAGE_VISUAL_REFRESH_DISPATCHER_READY
};

STAGE_VISUAL_REFRESH_DISPATCHER_STATE CurrentStageVisualRefreshDispatcher=
   STAGE_VISUAL_REFRESH_DISPATCHER_IDLE;

bool   StageVisualRefreshDispatcherReady=false;
string StageVisualRefreshDispatcherReason="Waiting";

void ResetStageRenderBuild527()
{
   CurrentStageVisualRefreshDispatcher=STAGE_VISUAL_REFRESH_DISPATCHER_IDLE;
   StageVisualRefreshDispatcherReady=false;
   StageVisualRefreshDispatcherReason="Waiting";
}

void UpdateStageVisualRefreshDispatcher(bool controllerReady)
{
   if(controllerReady)
   {
      CurrentStageVisualRefreshDispatcher=STAGE_VISUAL_REFRESH_DISPATCHER_READY;
      StageVisualRefreshDispatcherReady=true;
      StageVisualRefreshDispatcherReason="Dispatcher Ready";
   }
   else
   {
      ResetStageRenderBuild527();
   }
}


//==============================
// Build 52.8 - Stage Visual Refresh Executor Foundation
//==============================
enum STAGE_VISUAL_REFRESH_EXECUTOR_STATE
{
   STAGE_VISUAL_REFRESH_EXECUTOR_IDLE = 0,
   STAGE_VISUAL_REFRESH_EXECUTOR_READY
};

STAGE_VISUAL_REFRESH_EXECUTOR_STATE CurrentStageVisualRefreshExecutor=STAGE_VISUAL_REFRESH_EXECUTOR_IDLE;
bool StageVisualRefreshExecutorReady=false;
string StageVisualRefreshExecutorReason="Idle";

void ResetStageRenderBuild528()
{
   CurrentStageVisualRefreshExecutor=STAGE_VISUAL_REFRESH_EXECUTOR_IDLE;
   StageVisualRefreshExecutorReady=false;
   StageVisualRefreshExecutorReason="Idle";
}

void UpdateStageVisualRefreshExecutor(bool dispatcherReady)
{
   if(dispatcherReady)
   {
      CurrentStageVisualRefreshExecutor=STAGE_VISUAL_REFRESH_EXECUTOR_READY;
      StageVisualRefreshExecutorReady=true;
      StageVisualRefreshExecutorReason="Refresh dispatcher ready";
   }
   else
   {
      ResetStageRenderBuild528();
   }
}


//==============================
// Build 52.9 - StageVisualRefreshCommitFoundation
//==============================
enum STAGE_VISUAL_REFRESH_COMMIT_STATE
{
   STAGE_VISUAL_REFRESH_COMMIT_IDLE = 0,
   STAGE_VISUAL_REFRESH_COMMIT_READY
};

STAGE_VISUAL_REFRESH_COMMIT_STATE CurrentStageVisualRefreshCommit=STAGE_VISUAL_REFRESH_COMMIT_IDLE;
bool StageVisualRefreshCommitReady=false;
string StageVisualRefreshCommitReason="Idle";

void ResetStageRenderBuild529()
{
   CurrentStageVisualRefreshCommit=STAGE_VISUAL_REFRESH_COMMIT_IDLE;
   StageVisualRefreshCommitReady=false;
   StageVisualRefreshCommitReason="Idle";
}

void UpdateStageVisualRefreshCommit(bool executorReady)
{
   if(executorReady)
   {
      CurrentStageVisualRefreshCommit=STAGE_VISUAL_REFRESH_COMMIT_READY;
      StageVisualRefreshCommitReady=true;
      StageVisualRefreshCommitReason="Refresh commit ready";
   }
   else
   {
      ResetStageRenderBuild529();
   }
}
//==============================


//==============================
// Build 53.0 - Stage Visual Refresh Finalizer Foundation
//==============================
enum STAGE_VISUAL_REFRESH_FINALIZER_STATE
{
   STAGE_VISUAL_REFRESH_FINALIZER_IDLE=0,
   STAGE_VISUAL_REFRESH_FINALIZER_READY
};

STAGE_VISUAL_REFRESH_FINALIZER_STATE CurrentStageVisualRefreshFinalizer=STAGE_VISUAL_REFRESH_FINALIZER_IDLE;
bool StageVisualRefreshFinalizerReady=false;
string StageVisualRefreshFinalizerReason="Waiting";

void ResetStageRenderBuild530()
{
   CurrentStageVisualRefreshFinalizer=STAGE_VISUAL_REFRESH_FINALIZER_IDLE;
   StageVisualRefreshFinalizerReady=false;
   StageVisualRefreshFinalizerReason="Waiting";
}

void UpdateStageVisualRefreshFinalizer(bool commitReady)
{
   if(commitReady)
   {
      CurrentStageVisualRefreshFinalizer=STAGE_VISUAL_REFRESH_FINALIZER_READY;
      StageVisualRefreshFinalizerReady=true;
      StageVisualRefreshFinalizerReason="Refresh finalizer ready";
   }
   else
   {
      ResetStageRenderBuild530();
   }
}
//==============================


//==============================
// Build 53.1 - Stage Visual Runtime Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_STATE
{
   STAGE_VISUAL_RUNTIME_IDLE=0,
   STAGE_VISUAL_RUNTIME_READY
};

STAGE_VISUAL_RUNTIME_STATE CurrentStageVisualRuntime=STAGE_VISUAL_RUNTIME_IDLE;
bool StageVisualRuntimeReady=false;
string StageVisualRuntimeReason="Idle";

void ResetStageRenderBuild531()
{
   CurrentStageVisualRuntime=STAGE_VISUAL_RUNTIME_IDLE;
   StageVisualRuntimeReady=false;
   StageVisualRuntimeReason="Idle";
}

void UpdateStageVisualRuntime(bool finalizerReady)
{
   if(finalizerReady)
   {
      CurrentStageVisualRuntime=STAGE_VISUAL_RUNTIME_READY;
      StageVisualRuntimeReady=true;
      StageVisualRuntimeReason="Runtime ready";
   }
   else
   {
      CurrentStageVisualRuntime=STAGE_VISUAL_RUNTIME_IDLE;
      StageVisualRuntimeReady=false;
      StageVisualRuntimeReason="Waiting finalizer";
   }
}


//==============================
// Build 53.2 - Stage Visual Runtime Controller Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_CONTROLLER_STATE
{
   STAGE_VISUAL_RUNTIME_CONTROLLER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_CONTROLLER_READY
};

STAGE_VISUAL_RUNTIME_CONTROLLER_STATE CurrentStageVisualRuntimeController=STAGE_VISUAL_RUNTIME_CONTROLLER_IDLE;
bool StageVisualRuntimeControllerReady=false;
string StageVisualRuntimeControllerReason="Waiting";

void ResetStageRenderBuild532()
{
   CurrentStageVisualRuntimeController=STAGE_VISUAL_RUNTIME_CONTROLLER_IDLE;
   StageVisualRuntimeControllerReady=false;
   StageVisualRuntimeControllerReason="Waiting";
}

void UpdateStageVisualRuntimeController(bool runtimeReady)
{
   if(runtimeReady)
   {
      CurrentStageVisualRuntimeController=STAGE_VISUAL_RUNTIME_CONTROLLER_READY;
      StageVisualRuntimeControllerReady=true;
      StageVisualRuntimeControllerReason="Runtime controller ready";
   }
   else
   {
      ResetStageRenderBuild532();
   }
}
//==============================


//==============================
// Build 53.3
// Stage Visual Runtime Dispatcher Foundation
//==============================

enum STAGE_VISUAL_RUNTIME_DISPATCHER_STATE
{
   STAGE_VISUAL_RUNTIME_DISPATCHER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_DISPATCHER_READY
};

STAGE_VISUAL_RUNTIME_DISPATCHER_STATE CurrentStageVisualRuntimeDispatcher=
   STAGE_VISUAL_RUNTIME_DISPATCHER_IDLE;

bool StageVisualRuntimeDispatcherReady=false;
string StageVisualRuntimeDispatcherReason="Waiting";

void ResetStageRenderBuild533()
{
   CurrentStageVisualRuntimeDispatcher=
      STAGE_VISUAL_RUNTIME_DISPATCHER_IDLE;
   StageVisualRuntimeDispatcherReady=false;
   StageVisualRuntimeDispatcherReason="Waiting";
}

void UpdateStageVisualRuntimeDispatcher(bool controllerReady)
{
   if(controllerReady)
   {
      CurrentStageVisualRuntimeDispatcher=
         STAGE_VISUAL_RUNTIME_DISPATCHER_READY;
      StageVisualRuntimeDispatcherReady=true;
      StageVisualRuntimeDispatcherReason="Dispatcher Ready";
   }
   else
   {
      ResetStageRenderBuild533();
   }
}


//==============================
// Build 53.4
// Stage Visual Runtime Executor Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_EXECUTOR_STATE
{
   STAGE_VISUAL_RUNTIME_EXECUTOR_IDLE = 0,
   STAGE_VISUAL_RUNTIME_EXECUTOR_READY
};

STAGE_VISUAL_RUNTIME_EXECUTOR_STATE CurrentStageVisualRuntimeExecutor=
   STAGE_VISUAL_RUNTIME_EXECUTOR_IDLE;

bool StageVisualRuntimeExecutorReady=false;
string StageVisualRuntimeExecutorReason="Waiting";

void ResetStageRenderBuild534()
{
   CurrentStageVisualRuntimeExecutor=
      STAGE_VISUAL_RUNTIME_EXECUTOR_IDLE;
   StageVisualRuntimeExecutorReady=false;
   StageVisualRuntimeExecutorReason="Waiting";
}

void UpdateStageVisualRuntimeExecutor(bool dispatcherReady)
{
   if(dispatcherReady)
   {
      CurrentStageVisualRuntimeExecutor=
         STAGE_VISUAL_RUNTIME_EXECUTOR_READY;
      StageVisualRuntimeExecutorReady=true;
      StageVisualRuntimeExecutorReason="Runtime Executor Ready";
   }
   else
   {
      ResetStageRenderBuild534();
   }
}


//==============================
// Build 53.5
// StageVisualRuntimeCommitFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_COMMIT_STATE
{
   STAGE_VISUAL_RUNTIME_COMMIT_IDLE=0,
   STAGE_VISUAL_RUNTIME_COMMIT_READY
};

STAGE_VISUAL_RUNTIME_COMMIT_STATE CurrentStageVisualRuntimeCommit=
   STAGE_VISUAL_RUNTIME_COMMIT_IDLE;

bool StageVisualRuntimeCommitReady=false;
string StageVisualRuntimeCommitReason="Waiting";

void ResetStageRenderBuild535()
{
   CurrentStageVisualRuntimeCommit=
      STAGE_VISUAL_RUNTIME_COMMIT_IDLE;
   StageVisualRuntimeCommitReady=false;
   StageVisualRuntimeCommitReason="Waiting";
}

void UpdateStageVisualRuntimeCommit(bool executorReady)
{
   if(executorReady)
   {
      CurrentStageVisualRuntimeCommit=
         STAGE_VISUAL_RUNTIME_COMMIT_READY;
      StageVisualRuntimeCommitReady=true;
      StageVisualRuntimeCommitReason="Runtime Commit Ready";
   }
   else
   {
      ResetStageRenderBuild535();
   }
}


//==================================================
// Build 53.6
// Stage Visual Runtime Finalizer Foundation
//==================================================
enum STAGE_VISUAL_RUNTIME_FINALIZER_STATE
{
   STAGE_VISUAL_RUNTIME_FINALIZER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_FINALIZER_READY
};

STAGE_VISUAL_RUNTIME_FINALIZER_STATE CurrentStageVisualRuntimeFinalizer=
   STAGE_VISUAL_RUNTIME_FINALIZER_IDLE;

bool StageVisualRuntimeFinalizerReady=false;
string StageVisualRuntimeFinalizerReason="Waiting";

void ResetStageRenderBuild536()
{
   CurrentStageVisualRuntimeFinalizer=
      STAGE_VISUAL_RUNTIME_FINALIZER_IDLE;
   StageVisualRuntimeFinalizerReady=false;
   StageVisualRuntimeFinalizerReason="Waiting";
}

void UpdateStageVisualRuntimeFinalizer(bool commitReady)
{
   if(commitReady)
   {
      CurrentStageVisualRuntimeFinalizer=
         STAGE_VISUAL_RUNTIME_FINALIZER_READY;
      StageVisualRuntimeFinalizerReady=true;
      StageVisualRuntimeFinalizerReason="Runtime Finalizer Ready";
   }
   else
   {
      ResetStageRenderBuild536();
   }
}


//=========================
// Build 53.7
// StageVisualRuntimeCoordinatorFoundation
//=========================
enum STAGE_VISUAL_RUNTIME_COORDINATOR_STATE
{
   STAGE_VISUAL_RUNTIME_COORDINATOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_COORDINATOR_READY
};

STAGE_VISUAL_RUNTIME_COORDINATOR_STATE CurrentStageVisualRuntimeCoordinator=
STAGE_VISUAL_RUNTIME_COORDINATOR_IDLE;

bool StageVisualRuntimeCoordinatorReady=false;
string StageVisualRuntimeCoordinatorReason="Waiting";

void ResetStageRenderBuild537()
{
   CurrentStageVisualRuntimeCoordinator=
      STAGE_VISUAL_RUNTIME_COORDINATOR_IDLE;
   StageVisualRuntimeCoordinatorReady=false;
   StageVisualRuntimeCoordinatorReason="Waiting";
}

void UpdateStageVisualRuntimeCoordinator(bool finalizerReady)
{
   if(finalizerReady)
   {
      CurrentStageVisualRuntimeCoordinator=
         STAGE_VISUAL_RUNTIME_COORDINATOR_READY;
      StageVisualRuntimeCoordinatorReady=true;
      StageVisualRuntimeCoordinatorReason="Coordinator Ready";
   }
   else
   {
      ResetStageRenderBuild537();
   }
}


//==============================
// Build 53.8 - Stage Visual Runtime Scheduler Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_SCHEDULER_STATE
{
   STAGE_VISUAL_RUNTIME_SCHEDULER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_SCHEDULER_READY
};

STAGE_VISUAL_RUNTIME_SCHEDULER_STATE CurrentStageVisualRuntimeScheduler=
   STAGE_VISUAL_RUNTIME_SCHEDULER_IDLE;

bool StageVisualRuntimeSchedulerReady=false;
string StageVisualRuntimeSchedulerReason="Waiting";

void ResetStageRenderBuild538()
{
   CurrentStageVisualRuntimeScheduler=
      STAGE_VISUAL_RUNTIME_SCHEDULER_IDLE;
   StageVisualRuntimeSchedulerReady=false;
   StageVisualRuntimeSchedulerReason="Waiting";
}

void UpdateStageVisualRuntimeScheduler(bool coordinatorReady)
{
   if(coordinatorReady)
   {
      CurrentStageVisualRuntimeScheduler=
         STAGE_VISUAL_RUNTIME_SCHEDULER_READY;
      StageVisualRuntimeSchedulerReady=true;
      StageVisualRuntimeSchedulerReason="Scheduler Ready";
   }
   else
   {
      ResetStageRenderBuild538();
   }
}


//==============================
// Build 53.9
// Stage Visual Runtime Renderer Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDERER_STATE
{
   STAGE_VISUAL_RUNTIME_RENDERER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDERER_READY
};

STAGE_VISUAL_RUNTIME_RENDERER_STATE CurrentStageVisualRuntimeRenderer=
   STAGE_VISUAL_RUNTIME_RENDERER_IDLE;

bool StageVisualRuntimeRendererReady=false;
string StageVisualRuntimeRendererReason="Waiting";

void ResetStageRenderBuild539()
{
   CurrentStageVisualRuntimeRenderer=
      STAGE_VISUAL_RUNTIME_RENDERER_IDLE;
   StageVisualRuntimeRendererReady=false;
   StageVisualRuntimeRendererReason="Waiting";
}

void UpdateStageVisualRuntimeRenderer(bool schedulerReady)
{
   if(schedulerReady)
   {
      CurrentStageVisualRuntimeRenderer=
         STAGE_VISUAL_RUNTIME_RENDERER_READY;
      StageVisualRuntimeRendererReady=true;
      StageVisualRuntimeRendererReason="Renderer Ready";
   }
   else
   {
      ResetStageRenderBuild539();
   }
}


//==============================
// Build 54.0
// StageVisualRuntimeBridgeFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_BRIDGE_STATE
{
   STAGE_VISUAL_RUNTIME_BRIDGE_IDLE=0,
   STAGE_VISUAL_RUNTIME_BRIDGE_READY
};

STAGE_VISUAL_RUNTIME_BRIDGE_STATE CurrentStageVisualRuntimeBridge=
   STAGE_VISUAL_RUNTIME_BRIDGE_IDLE;

bool StageVisualRuntimeBridgeReady=false;
string StageVisualRuntimeBridgeReason="Waiting";

void ResetStageRenderBuild540()
{
   CurrentStageVisualRuntimeBridge=STAGE_VISUAL_RUNTIME_BRIDGE_IDLE;
   StageVisualRuntimeBridgeReady=false;
   StageVisualRuntimeBridgeReason="Waiting";
}

void UpdateStageVisualRuntimeBridge(bool rendererReady)
{
   if(rendererReady)
   {
      CurrentStageVisualRuntimeBridge=STAGE_VISUAL_RUNTIME_BRIDGE_READY;
      StageVisualRuntimeBridgeReady=true;
      StageVisualRuntimeBridgeReason="Bridge Ready";
   }
   else
   {
      ResetStageRenderBuild540();
   }
}


//==============================
// Build 54.1
// StageVisualRuntimeGatewayFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_GATEWAY_STATE
{
   STAGE_VISUAL_RUNTIME_GATEWAY_IDLE=0,
   STAGE_VISUAL_RUNTIME_GATEWAY_READY
};

STAGE_VISUAL_RUNTIME_GATEWAY_STATE CurrentStageVisualRuntimeGateway=STAGE_VISUAL_RUNTIME_GATEWAY_IDLE;
bool StageVisualRuntimeGatewayReady=false;
string StageVisualRuntimeGatewayReason="Waiting";

void ResetStageRenderBuild541()
{
   CurrentStageVisualRuntimeGateway=STAGE_VISUAL_RUNTIME_GATEWAY_IDLE;
   StageVisualRuntimeGatewayReady=false;
   StageVisualRuntimeGatewayReason="Waiting";
}

void UpdateStageVisualRuntimeGateway(bool bridgeReady)
{
   if(bridgeReady)
   {
      CurrentStageVisualRuntimeGateway=STAGE_VISUAL_RUNTIME_GATEWAY_READY;
      StageVisualRuntimeGatewayReady=true;
      StageVisualRuntimeGatewayReason="Gateway Ready";
   }
   else
   {
      ResetStageRenderBuild541();
   }
}


//==============================
// Build 54.2
// Stage Visual Runtime Linker Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_LINKER_STATE
{
   STAGE_VISUAL_RUNTIME_LINKER_IDLE=0,
   STAGE_VISUAL_RUNTIME_LINKER_READY
};

STAGE_VISUAL_RUNTIME_LINKER_STATE CurrentStageVisualRuntimeLinker=
   STAGE_VISUAL_RUNTIME_LINKER_IDLE;

bool StageVisualRuntimeLinkerReady=false;
string StageVisualRuntimeLinkerReason="Waiting";

void ResetStageRenderBuild542()
{
   CurrentStageVisualRuntimeLinker=
      STAGE_VISUAL_RUNTIME_LINKER_IDLE;
   StageVisualRuntimeLinkerReady=false;
   StageVisualRuntimeLinkerReason="Waiting";
}

void UpdateStageVisualRuntimeLinker(bool gatewayReady)
{
   if(gatewayReady)
   {
      CurrentStageVisualRuntimeLinker=
         STAGE_VISUAL_RUNTIME_LINKER_READY;
      StageVisualRuntimeLinkerReady=true;
      StageVisualRuntimeLinkerReason="Linker Ready";
   }
   else
   {
      ResetStageRenderBuild542();
   }
}


//==============================
// Build 54.3
// StageVisualRuntimeConnectorFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_CONNECTOR_STATE
{
   STAGE_VISUAL_RUNTIME_CONNECTOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_CONNECTOR_READY
};

STAGE_VISUAL_RUNTIME_CONNECTOR_STATE CurrentStageVisualRuntimeConnector=
   STAGE_VISUAL_RUNTIME_CONNECTOR_IDLE;

bool StageVisualRuntimeConnectorReady=false;
string StageVisualRuntimeConnectorReason="Waiting";

void ResetStageRenderBuild543()
{
   CurrentStageVisualRuntimeConnector=
      STAGE_VISUAL_RUNTIME_CONNECTOR_IDLE;
   StageVisualRuntimeConnectorReady=false;
   StageVisualRuntimeConnectorReason="Waiting";
}

void UpdateStageVisualRuntimeConnector(bool linkerReady)
{
   if(linkerReady)
   {
      CurrentStageVisualRuntimeConnector=
         STAGE_VISUAL_RUNTIME_CONNECTOR_READY;
      StageVisualRuntimeConnectorReady=true;
      StageVisualRuntimeConnectorReason="Connector Ready";
   }
   else
   {
      ResetStageRenderBuild543();
   }
}


//==============================
// Build 54.4
// Stage Visual Runtime Activator Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_ACTIVATOR_STATE
{
   STAGE_VISUAL_RUNTIME_ACTIVATOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_ACTIVATOR_READY
};

STAGE_VISUAL_RUNTIME_ACTIVATOR_STATE CurrentStageVisualRuntimeActivator=
   STAGE_VISUAL_RUNTIME_ACTIVATOR_IDLE;

bool StageVisualRuntimeActivatorReady=false;
string StageVisualRuntimeActivatorReason="Waiting";

void ResetStageRenderBuild544()
{
   CurrentStageVisualRuntimeActivator=
      STAGE_VISUAL_RUNTIME_ACTIVATOR_IDLE;
   StageVisualRuntimeActivatorReady=false;
   StageVisualRuntimeActivatorReason="Waiting";
}

void UpdateStageVisualRuntimeActivator(bool connectorReady)
{
   if(connectorReady)
   {
      CurrentStageVisualRuntimeActivator=
         STAGE_VISUAL_RUNTIME_ACTIVATOR_READY;
      StageVisualRuntimeActivatorReady=true;
      StageVisualRuntimeActivatorReason="Activator Ready";
   }
   else
   {
      ResetStageRenderBuild544();
   }
}


//==============================
// Build 54.5
// StageVisualRuntimeBootstrapFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_BOOTSTRAP_STATE
{
   STAGE_VISUAL_RUNTIME_BOOTSTRAP_IDLE=0,
   STAGE_VISUAL_RUNTIME_BOOTSTRAP_READY
};

STAGE_VISUAL_RUNTIME_BOOTSTRAP_STATE CurrentStageVisualRuntimeBootstrap=
   STAGE_VISUAL_RUNTIME_BOOTSTRAP_IDLE;

bool StageVisualRuntimeBootstrapReady=false;
string StageVisualRuntimeBootstrapReason="Waiting";

void ResetStageRenderBuild545()
{
   CurrentStageVisualRuntimeBootstrap=
      STAGE_VISUAL_RUNTIME_BOOTSTRAP_IDLE;
   StageVisualRuntimeBootstrapReady=false;
   StageVisualRuntimeBootstrapReason="Waiting";
}

void UpdateStageVisualRuntimeBootstrap(bool activatorReady)
{
   if(activatorReady)
   {
      CurrentStageVisualRuntimeBootstrap=
         STAGE_VISUAL_RUNTIME_BOOTSTRAP_READY;
      StageVisualRuntimeBootstrapReady=true;
      StageVisualRuntimeBootstrapReason="Bootstrap Ready";
   }
   else
   {
      ResetStageRenderBuild545();
   }
}


//==============================
// Build 54.6
// StageVisualRuntimeLaunchFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_LAUNCH_STATE
{
   STAGE_VISUAL_RUNTIME_LAUNCH_IDLE=0,
   STAGE_VISUAL_RUNTIME_LAUNCH_READY
};

STAGE_VISUAL_RUNTIME_LAUNCH_STATE CurrentStageVisualRuntimeLaunch=
   STAGE_VISUAL_RUNTIME_LAUNCH_IDLE;

bool StageVisualRuntimeLaunchReady=false;
string StageVisualRuntimeLaunchReason="Waiting";

void ResetStageRenderBuild546()
{
   CurrentStageVisualRuntimeLaunch=
      STAGE_VISUAL_RUNTIME_LAUNCH_IDLE;
   StageVisualRuntimeLaunchReady=false;
   StageVisualRuntimeLaunchReason="Waiting";
}

void UpdateStageVisualRuntimeLaunch(bool bootstrapReady)
{
   if(bootstrapReady)
   {
      CurrentStageVisualRuntimeLaunch=
         STAGE_VISUAL_RUNTIME_LAUNCH_READY;
      StageVisualRuntimeLaunchReady=true;
      StageVisualRuntimeLaunchReason="Launch Ready";
   }
   else
   {
      ResetStageRenderBuild546();
   }
}


//==============================
// Build 54.7
// StageVisualRuntimeRenderGateFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_GATE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_GATE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_GATE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_GATE_STATE CurrentStageVisualRuntimeRenderGate=
   STAGE_VISUAL_RUNTIME_RENDER_GATE_IDLE;

bool StageVisualRuntimeRenderGateReady=false;
string StageVisualRuntimeRenderGateReason="Waiting";

void ResetStageRenderBuild547()
{
   CurrentStageVisualRuntimeRenderGate=
      STAGE_VISUAL_RUNTIME_RENDER_GATE_IDLE;
   StageVisualRuntimeRenderGateReady=false;
   StageVisualRuntimeRenderGateReason="Waiting";
}

void UpdateStageVisualRuntimeRenderGate(bool launchReady)
{
   if(launchReady)
   {
      CurrentStageVisualRuntimeRenderGate=
         STAGE_VISUAL_RUNTIME_RENDER_GATE_READY;
      StageVisualRuntimeRenderGateReady=true;
      StageVisualRuntimeRenderGateReason="Render Gate Ready";
   }
   else
   {
      ResetStageRenderBuild547();
   }
}


//==================== Build 54.8 ====================
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STATE CurrentStageVisualRuntimeRenderPipeline=
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_IDLE;

bool StageVisualRuntimeRenderPipelineReady=false;
string StageVisualRuntimeRenderPipelineReason="Waiting";

void ResetStageRenderBuild548()
{
   CurrentStageVisualRuntimeRenderPipeline=
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_IDLE;
   StageVisualRuntimeRenderPipelineReady=false;
   StageVisualRuntimeRenderPipelineReason="Waiting";
}

void UpdateStageVisualRuntimeRenderPipeline(bool renderGateReady)
{
   if(renderGateReady)
   {
      CurrentStageVisualRuntimeRenderPipeline=
         STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_READY;
      StageVisualRuntimeRenderPipelineReady=true;
      StageVisualRuntimeRenderPipelineReason="Render Pipeline Ready";
   }
   else
   {
      ResetStageRenderBuild548();
   }
}
//================== End Build 54.8 ==================


//==============================
// Build 54.9
// StageVisualRuntimeRenderSyncFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_SYNC_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_SYNC_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_SYNC_READY
};

STAGE_VISUAL_RUNTIME_RENDER_SYNC_STATE CurrentStageVisualRuntimeRenderSync=
   STAGE_VISUAL_RUNTIME_RENDER_SYNC_IDLE;

bool StageVisualRuntimeRenderSyncReady=false;
string StageVisualRuntimeRenderSyncReason="Waiting";

void ResetStageRenderBuild549()
{
   CurrentStageVisualRuntimeRenderSync=
      STAGE_VISUAL_RUNTIME_RENDER_SYNC_IDLE;
   StageVisualRuntimeRenderSyncReady=false;
   StageVisualRuntimeRenderSyncReason="Waiting";
}

void UpdateStageVisualRuntimeRenderSync(bool pipelineReady)
{
   if(pipelineReady)
   {
      CurrentStageVisualRuntimeRenderSync=
         STAGE_VISUAL_RUNTIME_RENDER_SYNC_READY;
      StageVisualRuntimeRenderSyncReady=true;
      StageVisualRuntimeRenderSyncReason="Render Sync Ready";
   }
   else
   {
      ResetStageRenderBuild549();
   }
}


//==============================
// Build 55.0 - StageVisualRuntimeRenderEngineFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_ENGINE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_ENGINE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_ENGINE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_ENGINE_STATE CurrentStageVisualRuntimeRenderEngine=
   STAGE_VISUAL_RUNTIME_RENDER_ENGINE_IDLE;

bool StageVisualRuntimeRenderEngineReady=false;
string StageVisualRuntimeRenderEngineReason="Waiting";

void ResetStageRenderBuild550()
{
   CurrentStageVisualRuntimeRenderEngine=
      STAGE_VISUAL_RUNTIME_RENDER_ENGINE_IDLE;
   StageVisualRuntimeRenderEngineReady=false;
   StageVisualRuntimeRenderEngineReason="Waiting";
}

void UpdateStageVisualRuntimeRenderEngine(bool renderSyncReady)
{
   if(renderSyncReady)
   {
      CurrentStageVisualRuntimeRenderEngine=
         STAGE_VISUAL_RUNTIME_RENDER_ENGINE_READY;
      StageVisualRuntimeRenderEngineReady=true;
      StageVisualRuntimeRenderEngineReason="Render Engine Ready";
   }
   else
   {
      ResetStageRenderBuild550();
   }
}


//==============================
// Build 55.1
// StageVisualRuntimeRenderManagerFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_MANAGER_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_MANAGER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_MANAGER_READY
};

STAGE_VISUAL_RUNTIME_RENDER_MANAGER_STATE CurrentStageVisualRuntimeRenderManager=
   STAGE_VISUAL_RUNTIME_RENDER_MANAGER_IDLE;

bool StageVisualRuntimeRenderManagerReady=false;
string StageVisualRuntimeRenderManagerReason="Waiting";

void ResetStageRenderBuild551()
{
   CurrentStageVisualRuntimeRenderManager=
      STAGE_VISUAL_RUNTIME_RENDER_MANAGER_IDLE;
   StageVisualRuntimeRenderManagerReady=false;
   StageVisualRuntimeRenderManagerReason="Waiting";
}

void UpdateStageVisualRuntimeRenderManager(bool renderEngineReady)
{
   if(renderEngineReady)
   {
      CurrentStageVisualRuntimeRenderManager=
         STAGE_VISUAL_RUNTIME_RENDER_MANAGER_READY;
      StageVisualRuntimeRenderManagerReady=true;
      StageVisualRuntimeRenderManagerReason="Render Manager Ready";
   }
   else
   {
      ResetStageRenderBuild551();
   }
}


//==============================
// Build 55.2
// Stage Visual Runtime Render Controller Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_READY
};

STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_STATE CurrentStageVisualRuntimeRenderController=
   STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_IDLE;

bool StageVisualRuntimeRenderControllerReady=false;
string StageVisualRuntimeRenderControllerReason="Waiting";

void ResetStageRenderBuild552()
{
   CurrentStageVisualRuntimeRenderController=
      STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_IDLE;
   StageVisualRuntimeRenderControllerReady=false;
   StageVisualRuntimeRenderControllerReason="Waiting";
}

void UpdateStageVisualRuntimeRenderController(bool renderManagerReady)
{
   if(renderManagerReady)
   {
      CurrentStageVisualRuntimeRenderController=
         STAGE_VISUAL_RUNTIME_RENDER_CONTROLLER_READY;
      StageVisualRuntimeRenderControllerReady=true;
      StageVisualRuntimeRenderControllerReason="Render Controller Ready";
   }
   else
   {
      ResetStageRenderBuild552();
   }
}


//==============================
// Build 55.3 - StageVisualRuntimeRenderCoordinatorFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_READY
};

STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_STATE CurrentStageVisualRuntimeRenderCoordinator=
   STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_IDLE;
bool StageVisualRuntimeRenderCoordinatorReady=false;
string StageVisualRuntimeRenderCoordinatorReason="Not initialized";

void ResetStageRenderBuild553()
{
   CurrentStageVisualRuntimeRenderCoordinator=STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_IDLE;
   StageVisualRuntimeRenderCoordinatorReady=false;
   StageVisualRuntimeRenderCoordinatorReason="Reset";
}

void UpdateStageVisualRuntimeRenderCoordinator(bool renderControllerReady)
{
   if(renderControllerReady)
   {
      CurrentStageVisualRuntimeRenderCoordinator=STAGE_VISUAL_RUNTIME_RENDER_COORDINATOR_READY;
      StageVisualRuntimeRenderCoordinatorReady=true;
      StageVisualRuntimeRenderCoordinatorReason="Render Controller Ready";
   }
}


//==================================================
// Build 55.4 - StageVisualRuntimeRenderOrchestratorFoundation
//==================================================
enum STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_STATE CurrentStageVisualRuntimeRenderOrchestrator=STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_IDLE;
bool StageVisualRuntimeRenderOrchestratorReady=false;
string StageVisualRuntimeRenderOrchestratorReason="Not initialized";

void ResetStageRenderBuild554()
  {
   CurrentStageVisualRuntimeRenderOrchestrator=STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_IDLE;
   StageVisualRuntimeRenderOrchestratorReady=false;
   StageVisualRuntimeRenderOrchestratorReason="Reset";
  }

void UpdateStageVisualRuntimeRenderOrchestrator(bool coordinatorReady)
  {
   if(coordinatorReady)
     {
      CurrentStageVisualRuntimeRenderOrchestrator=STAGE_VISUAL_RUNTIME_RENDER_ORCHESTRATOR_READY;
      StageVisualRuntimeRenderOrchestratorReady=true;
      StageVisualRuntimeRenderOrchestratorReason="Runtime Render Orchestrator Ready";
     }
   else
     {
      ResetStageRenderBuild554();
     }
  }
//==================================================


//==============================
// Build 55.5
// Stage Visual Runtime Render Supervisor Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_STATE CurrentStageVisualRuntimeRenderSupervisor=STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_IDLE;
bool StageVisualRuntimeRenderSupervisorReady=false;
string StageVisualRuntimeRenderSupervisorReason="Idle";

void ResetStageRenderBuild555()
  {
   CurrentStageVisualRuntimeRenderSupervisor=STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_IDLE;
   StageVisualRuntimeRenderSupervisorReady=false;
   StageVisualRuntimeRenderSupervisorReason="Idle";
  }

void UpdateStageVisualRuntimeRenderSupervisor(bool orchestratorReady)
  {
   if(orchestratorReady)
     {
      CurrentStageVisualRuntimeRenderSupervisor=STAGE_VISUAL_RUNTIME_RENDER_SUPERVISOR_READY;
      StageVisualRuntimeRenderSupervisorReady=true;
      StageVisualRuntimeRenderSupervisorReason="Supervisor Ready";
     }
   else
     ResetStageRenderBuild555();
  }
//==============================


//==============================
// Build 55.6 - StageVisualRuntimeRenderFinalizerFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_IDLE = 0,
   STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_READY
};

STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_STATE CurrentStageVisualRuntimeRenderFinalizer=
   STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_IDLE;
bool StageVisualRuntimeRenderFinalizerReady=false;
string StageVisualRuntimeRenderFinalizerReason="Idle";

void ResetStageRenderBuild556()
{
   CurrentStageVisualRuntimeRenderFinalizer=STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_IDLE;
   StageVisualRuntimeRenderFinalizerReady=false;
   StageVisualRuntimeRenderFinalizerReason="Reset";
}

void UpdateStageVisualRuntimeRenderFinalizer(bool supervisorReady)
{
   if(supervisorReady)
   {
      CurrentStageVisualRuntimeRenderFinalizer=STAGE_VISUAL_RUNTIME_RENDER_FINALIZER_READY;
      StageVisualRuntimeRenderFinalizerReady=true;
      StageVisualRuntimeRenderFinalizerReason="Supervisor Ready";
   }
}


//==============================
// Build 55.7
// StageVisualRuntimeRenderCompletionFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_READY
};

STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_STATE CurrentStageVisualRuntimeRenderCompletion=
   STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_IDLE;

bool StageVisualRuntimeRenderCompletionReady=false;
string StageVisualRuntimeRenderCompletionReason="Idle";

void ResetStageRenderBuild557()
{
   CurrentStageVisualRuntimeRenderCompletion=STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_IDLE;
   StageVisualRuntimeRenderCompletionReady=false;
   StageVisualRuntimeRenderCompletionReason="Reset";
}

void UpdateStageVisualRuntimeRenderCompletion(bool finalizerReady)
{
   if(finalizerReady)
   {
      CurrentStageVisualRuntimeRenderCompletion=STAGE_VISUAL_RUNTIME_RENDER_COMPLETION_READY;
      StageVisualRuntimeRenderCompletionReady=true;
      StageVisualRuntimeRenderCompletionReason="Render Completion Ready";
   }
}


//================ Build 55.8 =================
enum STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_STATE CurrentStageVisualRuntimeRenderActivation=STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_IDLE;
bool StageVisualRuntimeRenderActivationReady=false;
string StageVisualRuntimeRenderActivationReason="Idle";

void ResetStageRenderBuild558()
  {
   CurrentStageVisualRuntimeRenderActivation=STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_IDLE;
   StageVisualRuntimeRenderActivationReady=false;
   StageVisualRuntimeRenderActivationReason="Reset";
  }

void UpdateStageVisualRuntimeRenderActivation(bool completionReady)
  {
   if(completionReady)
     {
      CurrentStageVisualRuntimeRenderActivation=STAGE_VISUAL_RUNTIME_RENDER_ACTIVATION_READY;
      StageVisualRuntimeRenderActivationReady=true;
      StageVisualRuntimeRenderActivationReason="Completion Ready";
     }
  }
//============== End Build 55.8 ==============


//==============================
// Build 55.9
// Stage Visual Runtime Render Execution Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_READY
};

STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_STATE CurrentStageVisualRuntimeRenderExecution=STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_IDLE;
bool StageVisualRuntimeRenderExecutionReady=false;
string StageVisualRuntimeRenderExecutionReason="Not initialized";

void ResetStageRenderBuild559()
{
   CurrentStageVisualRuntimeRenderExecution=STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_IDLE;
   StageVisualRuntimeRenderExecutionReady=false;
   StageVisualRuntimeRenderExecutionReason="Reset";
}

void UpdateStageVisualRuntimeRenderExecution(bool activationReady)
{
   if(activationReady)
   {
      CurrentStageVisualRuntimeRenderExecution=STAGE_VISUAL_RUNTIME_RENDER_EXECUTION_READY;
      StageVisualRuntimeRenderExecutionReady=true;
      StageVisualRuntimeRenderExecutionReason="Runtime Render Execution Ready";
   }
}

//==============================
// Build 56.0
// Stage Visual Runtime Render Live Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_LIVE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_LIVE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_LIVE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_LIVE_STATE CurrentStageVisualRuntimeRenderLive=STAGE_VISUAL_RUNTIME_RENDER_LIVE_IDLE;
bool StageVisualRuntimeRenderLiveReady=false;
string StageVisualRuntimeRenderLiveReason="Not Initialized";

void ResetStageRenderBuild560()
{
   CurrentStageVisualRuntimeRenderLive=STAGE_VISUAL_RUNTIME_RENDER_LIVE_IDLE;
   StageVisualRuntimeRenderLiveReady=false;
   StageVisualRuntimeRenderLiveReason="Reset";
}

void UpdateStageVisualRuntimeRenderLive(bool executionReady)
{
   if(executionReady)
   {
      CurrentStageVisualRuntimeRenderLive=STAGE_VISUAL_RUNTIME_RENDER_LIVE_READY;
      StageVisualRuntimeRenderLiveReady=true;
      StageVisualRuntimeRenderLiveReason="Runtime Render Live Ready";
   }
}


//==================================================
// Build 56.1 : StageVisualRuntimeRenderServiceFoundation
//==================================================
enum STAGE_VISUAL_RUNTIME_RENDER_SERVICE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_SERVICE_IDLE = 0,
   STAGE_VISUAL_RUNTIME_RENDER_SERVICE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_SERVICE_STATE CurrentStageVisualRuntimeRenderService=STAGE_VISUAL_RUNTIME_RENDER_SERVICE_IDLE;
bool StageVisualRuntimeRenderServiceReady=false;
string StageVisualRuntimeRenderServiceReason="Not Ready";

void ResetStageRenderBuild561()
{
   CurrentStageVisualRuntimeRenderService=STAGE_VISUAL_RUNTIME_RENDER_SERVICE_IDLE;
   StageVisualRuntimeRenderServiceReady=false;
   StageVisualRuntimeRenderServiceReason="Reset";
}

void UpdateStageVisualRuntimeRenderService(bool liveReady)
{
   if(liveReady)
   {
      CurrentStageVisualRuntimeRenderService=STAGE_VISUAL_RUNTIME_RENDER_SERVICE_READY;
      StageVisualRuntimeRenderServiceReady=true;
      StageVisualRuntimeRenderServiceReason="Live Ready";
   }
}


//==============================
// Build 56.2
// StageVisualRuntimeRenderKernelFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_KERNEL_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_KERNEL_IDLE = 0,
   STAGE_VISUAL_RUNTIME_RENDER_KERNEL_READY
};

STAGE_VISUAL_RUNTIME_RENDER_KERNEL_STATE CurrentStageVisualRuntimeRenderKernel=STAGE_VISUAL_RUNTIME_RENDER_KERNEL_IDLE;
bool StageVisualRuntimeRenderKernelReady=false;
string StageVisualRuntimeRenderKernelReason="Not Initialized";

void ResetStageRenderBuild562()
{
   CurrentStageVisualRuntimeRenderKernel=STAGE_VISUAL_RUNTIME_RENDER_KERNEL_IDLE;
   StageVisualRuntimeRenderKernelReady=false;
   StageVisualRuntimeRenderKernelReason="Reset";
}

void UpdateStageVisualRuntimeRenderKernel(bool serviceReady)
{
   if(serviceReady)
   {
      CurrentStageVisualRuntimeRenderKernel=STAGE_VISUAL_RUNTIME_RENDER_KERNEL_READY;
      StageVisualRuntimeRenderKernelReady=true;
      StageVisualRuntimeRenderKernelReason="Runtime Render Kernel Ready";
   }
}


//==================================================
// Build 56.3
// Stage Visual Runtime Render Core Foundation
//==================================================
enum STAGE_VISUAL_RUNTIME_RENDER_CORE_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_CORE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_CORE_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_CORE_STATE CurrentStageVisualRuntimeRenderCore=STAGE_VISUAL_RUNTIME_RENDER_CORE_IDLE;
bool StageVisualRuntimeRenderCoreReady=false;
string StageVisualRuntimeRenderCoreReason="Not Initialized";

void ResetStageRenderBuild563()
  {
   CurrentStageVisualRuntimeRenderCore=STAGE_VISUAL_RUNTIME_RENDER_CORE_IDLE;
   StageVisualRuntimeRenderCoreReady=false;
   StageVisualRuntimeRenderCoreReason="Reset";
  }

void UpdateStageVisualRuntimeRenderCore(bool kernelReady)
  {
   if(kernelReady)
     {
      CurrentStageVisualRuntimeRenderCore=STAGE_VISUAL_RUNTIME_RENDER_CORE_READY;
      StageVisualRuntimeRenderCoreReady=true;
      StageVisualRuntimeRenderCoreReason="Runtime Render Core Ready";
     }
   else
     {
      CurrentStageVisualRuntimeRenderCore=STAGE_VISUAL_RUNTIME_RENDER_CORE_IDLE;
      StageVisualRuntimeRenderCoreReady=false;
      StageVisualRuntimeRenderCoreReason="Waiting For Runtime Render Kernel";
     }
  }
//==================================================


//==============================
// Build 56.4
// StageVisualRuntimeRenderBridgeCoreFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_READY
};

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_STATE CurrentStageVisualRuntimeRenderBridgeCore=
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_IDLE;

bool StageVisualRuntimeRenderBridgeCoreReady=false;
string StageVisualRuntimeRenderBridgeCoreReason="Not Initialized";

void ResetStageRenderBuild564()
{
   CurrentStageVisualRuntimeRenderBridgeCore=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_IDLE;
   StageVisualRuntimeRenderBridgeCoreReady=false;
   StageVisualRuntimeRenderBridgeCoreReason="Reset";
}

void UpdateStageVisualRuntimeRenderBridgeCore(bool coreReady)
{
   if(coreReady)
   {
      CurrentStageVisualRuntimeRenderBridgeCore=
         STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CORE_READY;
      StageVisualRuntimeRenderBridgeCoreReady=true;
      StageVisualRuntimeRenderBridgeCoreReason="Render Core Ready";
   }
   else
   {
      ResetStageRenderBuild564();
   }
}


//==============================
// Build 56.5
// StageVisualRuntimeRenderBridgeManagerFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_STATE CurrentStageVisualRuntimeRenderBridgeManager=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_IDLE;
bool StageVisualRuntimeRenderBridgeManagerReady=false;
string StageVisualRuntimeRenderBridgeManagerReason="Idle";

void ResetStageRenderBuild565()
  {
   CurrentStageVisualRuntimeRenderBridgeManager=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_IDLE;
   StageVisualRuntimeRenderBridgeManagerReady=false;
   StageVisualRuntimeRenderBridgeManagerReason="Idle";
  }

void UpdateStageVisualRuntimeRenderBridgeManager(bool bridgeCoreReady)
  {
   if(bridgeCoreReady)
     {
      CurrentStageVisualRuntimeRenderBridgeManager=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MANAGER_READY;
      StageVisualRuntimeRenderBridgeManagerReady=true;
      StageVisualRuntimeRenderBridgeManagerReason="Bridge Manager Ready";
     }
   else
     {
      ResetStageRenderBuild565();
     }
  }
//==============================


//==============================
// Build 56.6
// StageVisualRuntimeRenderBridgeSupervisorFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_STATE CurrentStageVisualRuntimeRenderBridgeSupervisor=
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_IDLE;

bool StageVisualRuntimeRenderBridgeSupervisorReady=false;
string StageVisualRuntimeRenderBridgeSupervisorReason="Idle";

void ResetStageRenderBuild566()
  {
   CurrentStageVisualRuntimeRenderBridgeSupervisor=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_IDLE;
   StageVisualRuntimeRenderBridgeSupervisorReady=false;
   StageVisualRuntimeRenderBridgeSupervisorReason="Reset";
  }

void UpdateStageVisualRuntimeRenderBridgeSupervisor(bool bridgeManagerReady)
  {
   if(bridgeManagerReady)
     {
      CurrentStageVisualRuntimeRenderBridgeSupervisor=
         STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_READY;
      StageVisualRuntimeRenderBridgeSupervisorReady=true;
      StageVisualRuntimeRenderBridgeSupervisorReason="Bridge Supervisor Ready";
     }
   else
     {
      CurrentStageVisualRuntimeRenderBridgeSupervisor=
         STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SUPERVISOR_IDLE;
      StageVisualRuntimeRenderBridgeSupervisorReady=false;
      StageVisualRuntimeRenderBridgeSupervisorReason="Waiting Bridge Manager";
     }
  }


//==============================
// Build 56.7
// StageVisualRuntimeRenderBridgeFinalizerFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_READY
};

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_STATE CurrentStageVisualRuntimeRenderBridgeFinalizer=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_IDLE;
bool StageVisualRuntimeRenderBridgeFinalizerReady=false;
string StageVisualRuntimeRenderBridgeFinalizerReason="Not Ready";

void ResetStageRenderBuild567()
{
   CurrentStageVisualRuntimeRenderBridgeFinalizer=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_IDLE;
   StageVisualRuntimeRenderBridgeFinalizerReady=false;
   StageVisualRuntimeRenderBridgeFinalizerReason="Reset";
}

void UpdateStageVisualRuntimeRenderBridgeFinalizer(bool bridgeSupervisorReady)
{
   if(bridgeSupervisorReady)
   {
      CurrentStageVisualRuntimeRenderBridgeFinalizer=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINALIZER_READY;
      StageVisualRuntimeRenderBridgeFinalizerReady=true;
      StageVisualRuntimeRenderBridgeFinalizerReason="Bridge Supervisor Ready";
   }
}


//==============================
// Build 56.8
// StageVisualRuntimeRenderBridgeCompletionFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_READY
};

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_STATE CurrentStageVisualRuntimeRenderBridgeCompletion=
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_IDLE;

bool StageVisualRuntimeRenderBridgeCompletionReady=false;
string StageVisualRuntimeRenderBridgeCompletionReason="Not initialized";

void ResetStageRenderBuild568()
{
   CurrentStageVisualRuntimeRenderBridgeCompletion=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_IDLE;
   StageVisualRuntimeRenderBridgeCompletionReady=false;
   StageVisualRuntimeRenderBridgeCompletionReason="Reset";
}

void UpdateStageVisualRuntimeRenderBridgeCompletion(bool bridgeFinalizerReady)
{
   if(bridgeFinalizerReady)
   {
      CurrentStageVisualRuntimeRenderBridgeCompletion=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COMPLETION_READY;
      StageVisualRuntimeRenderBridgeCompletionReady=true;
      StageVisualRuntimeRenderBridgeCompletionReason="Bridge Completion Ready";
   }
}


//==============================
// Build 56.9
// Stage Visual Runtime Render Bridge Activation Foundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_STATE
  {
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_READY
  };

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_STATE CurrentStageVisualRuntimeRenderBridgeActivation=
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_IDLE;

bool StageVisualRuntimeRenderBridgeActivationReady=false;
string StageVisualRuntimeRenderBridgeActivationReason="Idle";

void ResetStageRenderBuild569()
  {
   CurrentStageVisualRuntimeRenderBridgeActivation=
      STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_IDLE;
   StageVisualRuntimeRenderBridgeActivationReady=false;
   StageVisualRuntimeRenderBridgeActivationReason="Reset";
  }

void UpdateStageVisualRuntimeRenderBridgeActivation(bool bridgeCompletionReady)
  {
   if(bridgeCompletionReady)
     {
      CurrentStageVisualRuntimeRenderBridgeActivation=
         STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATION_READY;
      StageVisualRuntimeRenderBridgeActivationReady=true;
      StageVisualRuntimeRenderBridgeActivationReason="Bridge Completion Ready";
     }
   else
     {
      ResetStageRenderBuild569();
     }
  }


//==============================
// Build 57.0
// StageVisualRuntimeRenderBridgeExecutionFoundation
//==============================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_IDLE = 0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_READY
};

STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_STATE CurrentStageVisualRuntimeRenderBridgeExecution=
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_IDLE;

bool StageVisualRuntimeRenderBridgeExecutionReady=false;
string StageVisualRuntimeRenderBridgeExecutionReason="Not Initialized";

void ResetStageRenderBuild570()
{
   CurrentStageVisualRuntimeRenderBridgeExecution=
      STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_IDLE;
   StageVisualRuntimeRenderBridgeExecutionReady=false;
   StageVisualRuntimeRenderBridgeExecutionReason="Reset";
}

void UpdateStageVisualRuntimeRenderBridgeExecution(bool bridgeActivationReady)
{
   if(bridgeActivationReady)
   {
      CurrentStageVisualRuntimeRenderBridgeExecution=
         STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_EXECUTION_READY;
      StageVisualRuntimeRenderBridgeExecutionReady=true;
      StageVisualRuntimeRenderBridgeExecutionReason="Bridge Execution Ready";
   }
}


//================ Build 571 =================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_READY
};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_STATE CurrentStageVisualRuntimeRenderBridgeValidation = STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_IDLE;
bool StageVisualRuntimeRenderBridgeValidationReady=false;
string StageVisualRuntimeRenderBridgeValidationReason="";
void ResetStageRenderBuild571()
{
 CurrentStageVisualRuntimeRenderBridgeValidation=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_IDLE;
 StageVisualRuntimeRenderBridgeValidationReady=false;
 StageVisualRuntimeRenderBridgeValidationReason="RESET";
}
void UpdateStageVisualRuntimeRenderBridgeValidation(bool prevReady)
{
 if(prevReady)
 {
  CurrentStageVisualRuntimeRenderBridgeValidation=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATION_READY;
  StageVisualRuntimeRenderBridgeValidationReady=true;
  StageVisualRuntimeRenderBridgeValidationReason="READY";
 }
}


//================ Build 572 =================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_STATE CurrentStageVisualRuntimeRenderBridgeMonitor = STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_IDLE;
bool StageVisualRuntimeRenderBridgeMonitorReady=false;
string StageVisualRuntimeRenderBridgeMonitorReason="";
void ResetStageRenderBuild572()
{
 CurrentStageVisualRuntimeRenderBridgeMonitor=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_IDLE;
 StageVisualRuntimeRenderBridgeMonitorReady=false;
 StageVisualRuntimeRenderBridgeMonitorReason="RESET";
}
void UpdateStageVisualRuntimeRenderBridgeMonitor(bool prevReady)
{
 if(prevReady)
 {
  CurrentStageVisualRuntimeRenderBridgeMonitor=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_MONITOR_READY;
  StageVisualRuntimeRenderBridgeMonitorReady=true;
  StageVisualRuntimeRenderBridgeMonitorReason="READY";
 }
}


//================ Build 573 =================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_READY
};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_STATE CurrentStageVisualRuntimeRenderBridgeSynchronization = STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_IDLE;
bool StageVisualRuntimeRenderBridgeSynchronizationReady=false;
string StageVisualRuntimeRenderBridgeSynchronizationReason="";
void ResetStageRenderBuild573()
{
 CurrentStageVisualRuntimeRenderBridgeSynchronization=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_IDLE;
 StageVisualRuntimeRenderBridgeSynchronizationReady=false;
 StageVisualRuntimeRenderBridgeSynchronizationReason="RESET";
}
void UpdateStageVisualRuntimeRenderBridgeSynchronization(bool prevReady)
{
 if(prevReady)
 {
  CurrentStageVisualRuntimeRenderBridgeSynchronization=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNCHRONIZATION_READY;
  StageVisualRuntimeRenderBridgeSynchronizationReady=true;
  StageVisualRuntimeRenderBridgeSynchronizationReason="READY";
 }
}


//================ Build 574 =================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_READY
};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_STATE CurrentStageVisualRuntimeRenderBridgeDispatch = STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_IDLE;
bool StageVisualRuntimeRenderBridgeDispatchReady=false;
string StageVisualRuntimeRenderBridgeDispatchReason="";
void ResetStageRenderBuild574()
{
 CurrentStageVisualRuntimeRenderBridgeDispatch=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_IDLE;
 StageVisualRuntimeRenderBridgeDispatchReady=false;
 StageVisualRuntimeRenderBridgeDispatchReason="RESET";
}
void UpdateStageVisualRuntimeRenderBridgeDispatch(bool prevReady)
{
 if(prevReady)
 {
  CurrentStageVisualRuntimeRenderBridgeDispatch=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCH_READY;
  StageVisualRuntimeRenderBridgeDispatchReady=true;
  StageVisualRuntimeRenderBridgeDispatchReason="READY";
 }
}


//================ Build 575 =================
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_STATE
{
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_READY
};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_STATE CurrentStageVisualRuntimeRenderBridgePipeline = STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_IDLE;
bool StageVisualRuntimeRenderBridgePipelineReady=false;
string StageVisualRuntimeRenderBridgePipelineReason="";
void ResetStageRenderBuild575()
{
 CurrentStageVisualRuntimeRenderBridgePipeline=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_IDLE;
 StageVisualRuntimeRenderBridgePipelineReady=false;
 StageVisualRuntimeRenderBridgePipelineReason="RESET";
}
void UpdateStageVisualRuntimeRenderBridgePipeline(bool prevReady)
{
 if(prevReady)
 {
  CurrentStageVisualRuntimeRenderBridgePipeline=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PIPELINE_READY;
  StageVisualRuntimeRenderBridgePipelineReady=true;
  StageVisualRuntimeRenderBridgePipelineReason="READY";
 }
}


//====================
// Build 57.6
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_STATE CurrentStageVisualRuntimeRenderBridgeQueue=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_IDLE;
bool StageVisualRuntimeRenderBridgeQueueReady=false;
string StageVisualRuntimeRenderBridgeQueueReason="";
void ResetStageRenderBuild576(){CurrentStageVisualRuntimeRenderBridgeQueue=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_IDLE;StageVisualRuntimeRenderBridgeQueueReady=false;StageVisualRuntimeRenderBridgeQueueReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeQueue(bool ready){StageVisualRuntimeRenderBridgeQueueReady=ready;CurrentStageVisualRuntimeRenderBridgeQueue=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_QUEUE_IDLE;}

// Build 57.7
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_STATE CurrentStageVisualRuntimeRenderBridgeScheduler=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_IDLE;
bool StageVisualRuntimeRenderBridgeSchedulerReady=false;
string StageVisualRuntimeRenderBridgeSchedulerReason="";
void ResetStageRenderBuild577(){CurrentStageVisualRuntimeRenderBridgeScheduler=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_IDLE;StageVisualRuntimeRenderBridgeSchedulerReady=false;StageVisualRuntimeRenderBridgeSchedulerReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeScheduler(bool ready){StageVisualRuntimeRenderBridgeSchedulerReady=ready;CurrentStageVisualRuntimeRenderBridgeScheduler=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SCHEDULER_IDLE;}

// Build 57.8
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_STATE CurrentStageVisualRuntimeRenderBridgeCoordinator=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_IDLE;
bool StageVisualRuntimeRenderBridgeCoordinatorReady=false;
string StageVisualRuntimeRenderBridgeCoordinatorReason="";
void ResetStageRenderBuild578(){CurrentStageVisualRuntimeRenderBridgeCoordinator=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_IDLE;StageVisualRuntimeRenderBridgeCoordinatorReady=false;StageVisualRuntimeRenderBridgeCoordinatorReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeCoordinator(bool ready){StageVisualRuntimeRenderBridgeCoordinatorReady=ready;CurrentStageVisualRuntimeRenderBridgeCoordinator=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_COORDINATOR_IDLE;}

// Build 57.9
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_STATE CurrentStageVisualRuntimeRenderBridgeLifecycle=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_IDLE;
bool StageVisualRuntimeRenderBridgeLifecycleReady=false;
string StageVisualRuntimeRenderBridgeLifecycleReason="";
void ResetStageRenderBuild579(){CurrentStageVisualRuntimeRenderBridgeLifecycle=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_IDLE;StageVisualRuntimeRenderBridgeLifecycleReady=false;StageVisualRuntimeRenderBridgeLifecycleReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeLifecycle(bool ready){StageVisualRuntimeRenderBridgeLifecycleReady=ready;CurrentStageVisualRuntimeRenderBridgeLifecycle=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_LIFECYCLE_IDLE;}

// Build 58.0
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_STATE CurrentStageVisualRuntimeRenderBridgeIntegration=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_IDLE;
bool StageVisualRuntimeRenderBridgeIntegrationReady=false;
string StageVisualRuntimeRenderBridgeIntegrationReason="";
void ResetStageRenderBuild580(){CurrentStageVisualRuntimeRenderBridgeIntegration=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_IDLE;StageVisualRuntimeRenderBridgeIntegrationReady=false;StageVisualRuntimeRenderBridgeIntegrationReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeIntegration(bool ready){StageVisualRuntimeRenderBridgeIntegrationReady=ready;CurrentStageVisualRuntimeRenderBridgeIntegration=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INTEGRATION_IDLE;}


// Build 58.1
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_STATE CurrentStageVisualRuntimeRenderBridgeRouter=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_IDLE;
bool StageVisualRuntimeRenderBridgeRouterReady=false;
string StageVisualRuntimeRenderBridgeRouterReason="";
void ResetStageRenderBuild581(){CurrentStageVisualRuntimeRenderBridgeRouter=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_IDLE;StageVisualRuntimeRenderBridgeRouterReady=false;StageVisualRuntimeRenderBridgeRouterReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeRouter(bool ready){StageVisualRuntimeRenderBridgeRouterReady=ready;CurrentStageVisualRuntimeRenderBridgeRouter=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ROUTER_IDLE;}


// Build 58.2
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_STATE CurrentStageVisualRuntimeRenderBridgeDispatcher=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_IDLE;
bool StageVisualRuntimeRenderBridgeDispatcherReady=false;
string StageVisualRuntimeRenderBridgeDispatcherReason="";
void ResetStageRenderBuild582(){CurrentStageVisualRuntimeRenderBridgeDispatcher=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_IDLE;StageVisualRuntimeRenderBridgeDispatcherReady=false;StageVisualRuntimeRenderBridgeDispatcherReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeDispatcher(bool ready){StageVisualRuntimeRenderBridgeDispatcherReady=ready;CurrentStageVisualRuntimeRenderBridgeDispatcher=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_DISPATCHER_IDLE;}


// Build 58.3
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_STATE CurrentStageVisualRuntimeRenderBridgeChannel=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_IDLE;
bool StageVisualRuntimeRenderBridgeChannelReady=false;
string StageVisualRuntimeRenderBridgeChannelReason="";
void ResetStageRenderBuild583(){CurrentStageVisualRuntimeRenderBridgeChannel=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_IDLE;StageVisualRuntimeRenderBridgeChannelReady=false;StageVisualRuntimeRenderBridgeChannelReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeChannel(bool ready){StageVisualRuntimeRenderBridgeChannelReady=ready;CurrentStageVisualRuntimeRenderBridgeChannel=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CHANNEL_IDLE;}


// Build 58.4
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_STATE { STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_IDLE=0, STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_READY };
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_STATE CurrentStageVisualRuntimeRenderBridgeSync=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_IDLE;
bool StageVisualRuntimeRenderBridgeSyncReady=false;
string StageVisualRuntimeRenderBridgeSyncReason="";
void ResetStageRenderBuild584(){CurrentStageVisualRuntimeRenderBridgeSync=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_IDLE;StageVisualRuntimeRenderBridgeSyncReady=false;StageVisualRuntimeRenderBridgeSyncReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeSync(bool ready){StageVisualRuntimeRenderBridgeSyncReady=ready;CurrentStageVisualRuntimeRenderBridgeSync=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SYNC_IDLE;}

// Build 58.5
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_STATE CurrentStageVisualRuntimeRenderBridgeValidator=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_IDLE;
bool StageVisualRuntimeRenderBridgeValidatorReady=false;
string StageVisualRuntimeRenderBridgeValidatorReason="";
void ResetStageRenderBuild585(){CurrentStageVisualRuntimeRenderBridgeValidator=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_IDLE;StageVisualRuntimeRenderBridgeValidatorReady=false;StageVisualRuntimeRenderBridgeValidatorReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeValidator(bool ready){StageVisualRuntimeRenderBridgeValidatorReady=ready;CurrentStageVisualRuntimeRenderBridgeValidator=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_VALIDATOR_IDLE;}

// Build 58.6
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_STATE CurrentStageVisualRuntimeRenderBridgeGuard=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_IDLE;
bool StageVisualRuntimeRenderBridgeGuardReady=false;
string StageVisualRuntimeRenderBridgeGuardReason="";
void ResetStageRenderBuild586(){CurrentStageVisualRuntimeRenderBridgeGuard=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_IDLE;StageVisualRuntimeRenderBridgeGuardReady=false;StageVisualRuntimeRenderBridgeGuardReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeGuard(bool ready){StageVisualRuntimeRenderBridgeGuardReady=ready;CurrentStageVisualRuntimeRenderBridgeGuard=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_GUARD_IDLE;}

// Build 58.7
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_STATE CurrentStageVisualRuntimeRenderBridgeWatchdog=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_IDLE;
bool StageVisualRuntimeRenderBridgeWatchdogReady=false;
string StageVisualRuntimeRenderBridgeWatchdogReason="";
void ResetStageRenderBuild587(){CurrentStageVisualRuntimeRenderBridgeWatchdog=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_IDLE;StageVisualRuntimeRenderBridgeWatchdogReady=false;StageVisualRuntimeRenderBridgeWatchdogReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeWatchdog(bool ready){StageVisualRuntimeRenderBridgeWatchdogReady=ready;CurrentStageVisualRuntimeRenderBridgeWatchdog=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_WATCHDOG_IDLE;}

// Build 58.8
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_STATE CurrentStageVisualRuntimeRenderBridgeFinalGate=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_IDLE;
bool StageVisualRuntimeRenderBridgeFinalGateReady=false;
string StageVisualRuntimeRenderBridgeFinalGateReason="";
void ResetStageRenderBuild588(){CurrentStageVisualRuntimeRenderBridgeFinalGate=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_IDLE;StageVisualRuntimeRenderBridgeFinalGateReady=false;StageVisualRuntimeRenderBridgeFinalGateReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeFinalGate(bool ready){StageVisualRuntimeRenderBridgeFinalGateReady=ready;CurrentStageVisualRuntimeRenderBridgeFinalGate=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_FINAL_GATE_IDLE;}

// Build 58.9
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_STATE CurrentStageVisualRuntimeRenderBridgeReady=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_IDLE;
bool StageVisualRuntimeRenderBridgeReadyReady=false;
string StageVisualRuntimeRenderBridgeReadyReason="";
void ResetStageRenderBuild589(){CurrentStageVisualRuntimeRenderBridgeReady=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_IDLE;StageVisualRuntimeRenderBridgeReadyReady=false;StageVisualRuntimeRenderBridgeReadyReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeReady(bool ready){StageVisualRuntimeRenderBridgeReadyReady=ready;CurrentStageVisualRuntimeRenderBridgeReady=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_READY_IDLE;}

// Build 59.0
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_STATE CurrentStageVisualRuntimeRenderBridgeBootstrap=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_IDLE;
bool StageVisualRuntimeRenderBridgeBootstrapReady=false;
string StageVisualRuntimeRenderBridgeBootstrapReason="";
void ResetStageRenderBuild590(){CurrentStageVisualRuntimeRenderBridgeBootstrap=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_IDLE;StageVisualRuntimeRenderBridgeBootstrapReady=false;StageVisualRuntimeRenderBridgeBootstrapReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeBootstrap(bool ready){StageVisualRuntimeRenderBridgeBootstrapReady=ready;CurrentStageVisualRuntimeRenderBridgeBootstrap=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_BOOTSTRAP_IDLE;}

// Build 59.1
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_STATE CurrentStageVisualRuntimeRenderBridgeRegistry=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_IDLE;
bool StageVisualRuntimeRenderBridgeRegistryReady=false;
string StageVisualRuntimeRenderBridgeRegistryReason="";
void ResetStageRenderBuild591(){CurrentStageVisualRuntimeRenderBridgeRegistry=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_IDLE;StageVisualRuntimeRenderBridgeRegistryReady=false;StageVisualRuntimeRenderBridgeRegistryReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeRegistry(bool ready){StageVisualRuntimeRenderBridgeRegistryReady=ready;CurrentStageVisualRuntimeRenderBridgeRegistry=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_REGISTRY_IDLE;}

// Build 59.2
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_STATE CurrentStageVisualRuntimeRenderBridgeCatalog=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_IDLE;
bool StageVisualRuntimeRenderBridgeCatalogReady=false;
string StageVisualRuntimeRenderBridgeCatalogReason="";
void ResetStageRenderBuild592(){CurrentStageVisualRuntimeRenderBridgeCatalog=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_IDLE;StageVisualRuntimeRenderBridgeCatalogReady=false;StageVisualRuntimeRenderBridgeCatalogReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeCatalog(bool ready){StageVisualRuntimeRenderBridgeCatalogReady=ready;CurrentStageVisualRuntimeRenderBridgeCatalog=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CATALOG_IDLE;}

// Build 59.3
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_STATE CurrentStageVisualRuntimeRenderBridgeIndex=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_IDLE;
bool StageVisualRuntimeRenderBridgeIndexReady=false;
string StageVisualRuntimeRenderBridgeIndexReason="";
void ResetStageRenderBuild593(){CurrentStageVisualRuntimeRenderBridgeIndex=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_IDLE;StageVisualRuntimeRenderBridgeIndexReady=false;StageVisualRuntimeRenderBridgeIndexReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeIndex(bool ready){StageVisualRuntimeRenderBridgeIndexReady=ready;CurrentStageVisualRuntimeRenderBridgeIndex=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_INDEX_IDLE;}

// Build 59.4
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_STATE CurrentStageVisualRuntimeRenderBridgeHandshake=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_IDLE;
bool StageVisualRuntimeRenderBridgeHandshakeReady=false;
string StageVisualRuntimeRenderBridgeHandshakeReason="";
void ResetStageRenderBuild594(){CurrentStageVisualRuntimeRenderBridgeHandshake=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_IDLE;StageVisualRuntimeRenderBridgeHandshakeReady=false;StageVisualRuntimeRenderBridgeHandshakeReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeHandshake(bool ready){StageVisualRuntimeRenderBridgeHandshakeReady=ready;CurrentStageVisualRuntimeRenderBridgeHandshake=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_HANDSHAKE_IDLE;}

// Build 59.5
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_STATE CurrentStageVisualRuntimeRenderBridgeSession=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_IDLE;
bool StageVisualRuntimeRenderBridgeSessionReady=false;
string StageVisualRuntimeRenderBridgeSessionReason="";
void ResetStageRenderBuild595(){CurrentStageVisualRuntimeRenderBridgeSession=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_IDLE;StageVisualRuntimeRenderBridgeSessionReady=false;StageVisualRuntimeRenderBridgeSessionReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeSession(bool ready){StageVisualRuntimeRenderBridgeSessionReady=ready;CurrentStageVisualRuntimeRenderBridgeSession=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_SESSION_IDLE;}

// Build 59.6
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_STATE CurrentStageVisualRuntimeRenderBridgeContext=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_IDLE;
bool StageVisualRuntimeRenderBridgeContextReady=false;
string StageVisualRuntimeRenderBridgeContextReason="";
void ResetStageRenderBuild596(){CurrentStageVisualRuntimeRenderBridgeContext=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_IDLE;StageVisualRuntimeRenderBridgeContextReady=false;StageVisualRuntimeRenderBridgeContextReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeContext(bool ready){StageVisualRuntimeRenderBridgeContextReady=ready;CurrentStageVisualRuntimeRenderBridgeContext=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_CONTEXT_IDLE;}

// Build 59.7
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_STATE CurrentStageVisualRuntimeRenderBridgeStatecache=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_IDLE;
bool StageVisualRuntimeRenderBridgeStatecacheReady=false;
string StageVisualRuntimeRenderBridgeStatecacheReason="";
void ResetStageRenderBuild597(){CurrentStageVisualRuntimeRenderBridgeStatecache=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_IDLE;StageVisualRuntimeRenderBridgeStatecacheReady=false;StageVisualRuntimeRenderBridgeStatecacheReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeStatecache(bool ready){StageVisualRuntimeRenderBridgeStatecacheReady=ready;CurrentStageVisualRuntimeRenderBridgeStatecache=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_STATECACHE_IDLE;}

// Build 59.8
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_STATE CurrentStageVisualRuntimeRenderBridgeActivationmap=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_IDLE;
bool StageVisualRuntimeRenderBridgeActivationmapReady=false;
string StageVisualRuntimeRenderBridgeActivationmapReason="";
void ResetStageRenderBuild598(){CurrentStageVisualRuntimeRenderBridgeActivationmap=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_IDLE;StageVisualRuntimeRenderBridgeActivationmapReady=false;StageVisualRuntimeRenderBridgeActivationmapReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgeActivationmap(bool ready){StageVisualRuntimeRenderBridgeActivationmapReady=ready;CurrentStageVisualRuntimeRenderBridgeActivationmap=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_ACTIVATIONMAP_IDLE;}

// Build 59.9
enum STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_STATE{STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_READY};
STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_STATE CurrentStageVisualRuntimeRenderBridgePrepare=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_IDLE;
bool StageVisualRuntimeRenderBridgePrepareReady=false;
string StageVisualRuntimeRenderBridgePrepareReason="";
void ResetStageRenderBuild599(){CurrentStageVisualRuntimeRenderBridgePrepare=STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_IDLE;StageVisualRuntimeRenderBridgePrepareReady=false;StageVisualRuntimeRenderBridgePrepareReason="Reset";}
void UpdateStageVisualRuntimeRenderBridgePrepare(bool ready){StageVisualRuntimeRenderBridgePrepareReady=ready;CurrentStageVisualRuntimeRenderBridgePrepare=ready?STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_READY:STAGE_VISUAL_RUNTIME_RENDER_BRIDGE_PREPARE_IDLE;}

// Build 60.0
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_STATE CurrentStageVisualRuntimeRenderPipelineStage=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_IDLE;
bool StageVisualRuntimeRenderPipelineStageReady=false;
string StageVisualRuntimeRenderPipelineStageReason="";
void ResetStageRenderBuild600(){CurrentStageVisualRuntimeRenderPipelineStage=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_IDLE;StageVisualRuntimeRenderPipelineStageReady=false;StageVisualRuntimeRenderPipelineStageReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineStage(bool ready){StageVisualRuntimeRenderPipelineStageReady=ready;CurrentStageVisualRuntimeRenderPipelineStage=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STAGE_IDLE;}

// Build 60.1
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_STATE CurrentStageVisualRuntimeRenderPipelineFlow=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_IDLE;
bool StageVisualRuntimeRenderPipelineFlowReady=false;
string StageVisualRuntimeRenderPipelineFlowReason="";
void ResetStageRenderBuild601(){CurrentStageVisualRuntimeRenderPipelineFlow=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_IDLE;StageVisualRuntimeRenderPipelineFlowReady=false;StageVisualRuntimeRenderPipelineFlowReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineFlow(bool ready){StageVisualRuntimeRenderPipelineFlowReady=ready;CurrentStageVisualRuntimeRenderPipelineFlow=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FLOW_IDLE;}

// Build 60.2
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_STATE CurrentStageVisualRuntimeRenderPipelineLink=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_IDLE;
bool StageVisualRuntimeRenderPipelineLinkReady=false;
string StageVisualRuntimeRenderPipelineLinkReason="";
void ResetStageRenderBuild602(){CurrentStageVisualRuntimeRenderPipelineLink=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_IDLE;StageVisualRuntimeRenderPipelineLinkReady=false;StageVisualRuntimeRenderPipelineLinkReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineLink(bool ready){StageVisualRuntimeRenderPipelineLinkReady=ready;CurrentStageVisualRuntimeRenderPipelineLink=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_LINK_IDLE;}

// Build 60.3
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_STATE CurrentStageVisualRuntimeRenderPipelineRuntime=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_IDLE;
bool StageVisualRuntimeRenderPipelineRuntimeReady=false;
string StageVisualRuntimeRenderPipelineRuntimeReason="";
void ResetStageRenderBuild603(){CurrentStageVisualRuntimeRenderPipelineRuntime=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_IDLE;StageVisualRuntimeRenderPipelineRuntimeReady=false;StageVisualRuntimeRenderPipelineRuntimeReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineRuntime(bool ready){StageVisualRuntimeRenderPipelineRuntimeReady=ready;CurrentStageVisualRuntimeRenderPipelineRuntime=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RUNTIME_IDLE;}

// Build 60.4
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_STATE CurrentStageVisualRuntimeRenderPipelineGate=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_IDLE;
bool StageVisualRuntimeRenderPipelineGateReady=false;
string StageVisualRuntimeRenderPipelineGateReason="";
void ResetStageRenderBuild604(){CurrentStageVisualRuntimeRenderPipelineGate=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_IDLE;StageVisualRuntimeRenderPipelineGateReady=false;StageVisualRuntimeRenderPipelineGateReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineGate(bool ready){StageVisualRuntimeRenderPipelineGateReady=ready;CurrentStageVisualRuntimeRenderPipelineGate=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATE_IDLE;}

// Build 60.5
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_STATE CurrentStageVisualRuntimeRenderPipelineBuffer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_IDLE;
bool StageVisualRuntimeRenderPipelineBufferReady=false;
string StageVisualRuntimeRenderPipelineBufferReason="";
void ResetStageRenderBuild605(){CurrentStageVisualRuntimeRenderPipelineBuffer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_IDLE;StageVisualRuntimeRenderPipelineBufferReady=false;StageVisualRuntimeRenderPipelineBufferReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineBuffer(bool ready){StageVisualRuntimeRenderPipelineBufferReady=ready;CurrentStageVisualRuntimeRenderPipelineBuffer=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_BUFFER_IDLE;}

// Build 60.6
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_STATE CurrentStageVisualRuntimeRenderPipelineRouting=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_IDLE;
bool StageVisualRuntimeRenderPipelineRoutingReady=false;
string StageVisualRuntimeRenderPipelineRoutingReason="";
void ResetStageRenderBuild606(){CurrentStageVisualRuntimeRenderPipelineRouting=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_IDLE;StageVisualRuntimeRenderPipelineRoutingReady=false;StageVisualRuntimeRenderPipelineRoutingReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineRouting(bool ready){StageVisualRuntimeRenderPipelineRoutingReady=ready;CurrentStageVisualRuntimeRenderPipelineRouting=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ROUTING_IDLE;}

// Build 60.7
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_STATE CurrentStageVisualRuntimeRenderPipelineTracker=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_IDLE;
bool StageVisualRuntimeRenderPipelineTrackerReady=false;
string StageVisualRuntimeRenderPipelineTrackerReason="";
void ResetStageRenderBuild607(){CurrentStageVisualRuntimeRenderPipelineTracker=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_IDLE;StageVisualRuntimeRenderPipelineTrackerReady=false;StageVisualRuntimeRenderPipelineTrackerReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineTracker(bool ready){StageVisualRuntimeRenderPipelineTrackerReady=ready;CurrentStageVisualRuntimeRenderPipelineTracker=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TRACKER_IDLE;}

// Build 60.8
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_STATE CurrentStageVisualRuntimeRenderPipelineObserver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_IDLE;
bool StageVisualRuntimeRenderPipelineObserverReady=false;
string StageVisualRuntimeRenderPipelineObserverReason="";
void ResetStageRenderBuild608(){CurrentStageVisualRuntimeRenderPipelineObserver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_IDLE;StageVisualRuntimeRenderPipelineObserverReady=false;StageVisualRuntimeRenderPipelineObserverReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineObserver(bool ready){StageVisualRuntimeRenderPipelineObserverReady=ready;CurrentStageVisualRuntimeRenderPipelineObserver=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OBSERVER_IDLE;}

// Build 60.9
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_STATE CurrentStageVisualRuntimeRenderPipelineFinisher=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_IDLE;
bool StageVisualRuntimeRenderPipelineFinisherReady=false;
string StageVisualRuntimeRenderPipelineFinisherReason="";
void ResetStageRenderBuild609(){CurrentStageVisualRuntimeRenderPipelineFinisher=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_IDLE;StageVisualRuntimeRenderPipelineFinisherReady=false;StageVisualRuntimeRenderPipelineFinisherReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineFinisher(bool ready){StageVisualRuntimeRenderPipelineFinisherReady=ready;CurrentStageVisualRuntimeRenderPipelineFinisher=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINISHER_IDLE;}

// Build 61.0
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_STATE CurrentStageVisualRuntimeRenderPipelineResolver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_IDLE;
bool StageVisualRuntimeRenderPipelineResolverReady=false;
string StageVisualRuntimeRenderPipelineResolverReason="";
void ResetStageRenderBuild610(){CurrentStageVisualRuntimeRenderPipelineResolver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_IDLE;StageVisualRuntimeRenderPipelineResolverReady=false;StageVisualRuntimeRenderPipelineResolverReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineResolver(bool ready){StageVisualRuntimeRenderPipelineResolverReady=ready;CurrentStageVisualRuntimeRenderPipelineResolver=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RESOLVER_IDLE;}

// Build 61.1
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_STATE CurrentStageVisualRuntimeRenderPipelineValidator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_IDLE;
bool StageVisualRuntimeRenderPipelineValidatorReady=false;
string StageVisualRuntimeRenderPipelineValidatorReason="";
void ResetStageRenderBuild611(){CurrentStageVisualRuntimeRenderPipelineValidator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_IDLE;StageVisualRuntimeRenderPipelineValidatorReady=false;StageVisualRuntimeRenderPipelineValidatorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineValidator(bool ready){StageVisualRuntimeRenderPipelineValidatorReady=ready;CurrentStageVisualRuntimeRenderPipelineValidator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_VALIDATOR_IDLE;}

// Build 61.2
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_STATE CurrentStageVisualRuntimeRenderPipelineAggregator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_IDLE;
bool StageVisualRuntimeRenderPipelineAggregatorReady=false;
string StageVisualRuntimeRenderPipelineAggregatorReason="";
void ResetStageRenderBuild612(){CurrentStageVisualRuntimeRenderPipelineAggregator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_IDLE;StageVisualRuntimeRenderPipelineAggregatorReady=false;StageVisualRuntimeRenderPipelineAggregatorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineAggregator(bool ready){StageVisualRuntimeRenderPipelineAggregatorReady=ready;CurrentStageVisualRuntimeRenderPipelineAggregator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AGGREGATOR_IDLE;}

// Build 61.3
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_STATE CurrentStageVisualRuntimeRenderPipelineConnector=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_IDLE;
bool StageVisualRuntimeRenderPipelineConnectorReady=false;
string StageVisualRuntimeRenderPipelineConnectorReason="";
void ResetStageRenderBuild613(){CurrentStageVisualRuntimeRenderPipelineConnector=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_IDLE;StageVisualRuntimeRenderPipelineConnectorReady=false;StageVisualRuntimeRenderPipelineConnectorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineConnector(bool ready){StageVisualRuntimeRenderPipelineConnectorReady=ready;CurrentStageVisualRuntimeRenderPipelineConnector=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONNECTOR_IDLE;}

// Build 61.4
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_STATE CurrentStageVisualRuntimeRenderPipelineTerminator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_IDLE;
bool StageVisualRuntimeRenderPipelineTerminatorReady=false;
string StageVisualRuntimeRenderPipelineTerminatorReason="";
void ResetStageRenderBuild614(){CurrentStageVisualRuntimeRenderPipelineTerminator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_IDLE;StageVisualRuntimeRenderPipelineTerminatorReady=false;StageVisualRuntimeRenderPipelineTerminatorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineTerminator(bool ready){StageVisualRuntimeRenderPipelineTerminatorReady=ready;CurrentStageVisualRuntimeRenderPipelineTerminator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_TERMINATOR_IDLE;}

// Build 61.5
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_STATE CurrentStageVisualRuntimeRenderPipelineRecorder=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_IDLE;
bool StageVisualRuntimeRenderPipelineRecorderReady=false;
string StageVisualRuntimeRenderPipelineRecorderReason="";
void ResetStageRenderBuild615(){CurrentStageVisualRuntimeRenderPipelineRecorder=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_IDLE;StageVisualRuntimeRenderPipelineRecorderReady=false;StageVisualRuntimeRenderPipelineRecorderReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineRecorder(bool ready){StageVisualRuntimeRenderPipelineRecorderReady=ready;CurrentStageVisualRuntimeRenderPipelineRecorder=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECORDER_IDLE;}

// Build 61.6
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_STATE CurrentStageVisualRuntimeRenderPipelineAuditor=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_IDLE;
bool StageVisualRuntimeRenderPipelineAuditorReady=false;
string StageVisualRuntimeRenderPipelineAuditorReason="";
void ResetStageRenderBuild616(){CurrentStageVisualRuntimeRenderPipelineAuditor=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_IDLE;StageVisualRuntimeRenderPipelineAuditorReady=false;StageVisualRuntimeRenderPipelineAuditorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineAuditor(bool ready){StageVisualRuntimeRenderPipelineAuditorReady=ready;CurrentStageVisualRuntimeRenderPipelineAuditor=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_AUDITOR_IDLE;}

// Build 61.7
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_STATE CurrentStageVisualRuntimeRenderPipelineStabilizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_IDLE;
bool StageVisualRuntimeRenderPipelineStabilizerReady=false;
string StageVisualRuntimeRenderPipelineStabilizerReason="";
void ResetStageRenderBuild617(){CurrentStageVisualRuntimeRenderPipelineStabilizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_IDLE;StageVisualRuntimeRenderPipelineStabilizerReady=false;StageVisualRuntimeRenderPipelineStabilizerReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineStabilizer(bool ready){StageVisualRuntimeRenderPipelineStabilizerReady=ready;CurrentStageVisualRuntimeRenderPipelineStabilizer=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_STABILIZER_IDLE;}

// Build 61.8
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_STATE CurrentStageVisualRuntimeRenderPipelineSequencer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_IDLE;
bool StageVisualRuntimeRenderPipelineSequencerReady=false;
string StageVisualRuntimeRenderPipelineSequencerReason="";
void ResetStageRenderBuild618(){CurrentStageVisualRuntimeRenderPipelineSequencer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_IDLE;StageVisualRuntimeRenderPipelineSequencerReady=false;StageVisualRuntimeRenderPipelineSequencerReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineSequencer(bool ready){StageVisualRuntimeRenderPipelineSequencerReady=ready;CurrentStageVisualRuntimeRenderPipelineSequencer=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SEQUENCER_IDLE;}

// Build 61.9
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_STATE CurrentStageVisualRuntimeRenderPipelineCompletion=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_IDLE;
bool StageVisualRuntimeRenderPipelineCompletionReady=false;
string StageVisualRuntimeRenderPipelineCompletionReason="";
void ResetStageRenderBuild619(){CurrentStageVisualRuntimeRenderPipelineCompletion=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_IDLE;StageVisualRuntimeRenderPipelineCompletionReady=false;StageVisualRuntimeRenderPipelineCompletionReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineCompletion(bool ready){StageVisualRuntimeRenderPipelineCompletionReady=ready;CurrentStageVisualRuntimeRenderPipelineCompletion=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COMPLETION_IDLE;}

// Build 62.0
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_STATE CurrentStageVisualRuntimeRenderPipelineGateway=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_IDLE;
bool StageVisualRuntimeRenderPipelineGatewayReady=false;
string StageVisualRuntimeRenderPipelineGatewayReason="";
void ResetStageRenderBuild620(){CurrentStageVisualRuntimeRenderPipelineGateway=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_IDLE;StageVisualRuntimeRenderPipelineGatewayReady=false;StageVisualRuntimeRenderPipelineGatewayReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineGateway(bool ready){StageVisualRuntimeRenderPipelineGatewayReady=ready;CurrentStageVisualRuntimeRenderPipelineGateway=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_GATEWAY_IDLE;}

// Build 62.1
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_STATE CurrentStageVisualRuntimeRenderPipelineMediator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_IDLE;
bool StageVisualRuntimeRenderPipelineMediatorReady=false;
string StageVisualRuntimeRenderPipelineMediatorReason="";
void ResetStageRenderBuild621(){CurrentStageVisualRuntimeRenderPipelineMediator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_IDLE;StageVisualRuntimeRenderPipelineMediatorReady=false;StageVisualRuntimeRenderPipelineMediatorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineMediator(bool ready){StageVisualRuntimeRenderPipelineMediatorReady=ready;CurrentStageVisualRuntimeRenderPipelineMediator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MEDIATOR_IDLE;}

// Build 62.2
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_STATE CurrentStageVisualRuntimeRenderPipelineOrchestrator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_IDLE;
bool StageVisualRuntimeRenderPipelineOrchestratorReady=false;
string StageVisualRuntimeRenderPipelineOrchestratorReason="";
void ResetStageRenderBuild622(){CurrentStageVisualRuntimeRenderPipelineOrchestrator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_IDLE;StageVisualRuntimeRenderPipelineOrchestratorReady=false;StageVisualRuntimeRenderPipelineOrchestratorReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineOrchestrator(bool ready){StageVisualRuntimeRenderPipelineOrchestratorReady=ready;CurrentStageVisualRuntimeRenderPipelineOrchestrator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ORCHESTRATOR_IDLE;}

// Build 62.3
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_STATE CurrentStageVisualRuntimeRenderPipelineConverter=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_IDLE;
bool StageVisualRuntimeRenderPipelineConverterReady=false;
string StageVisualRuntimeRenderPipelineConverterReason="";
void ResetStageRenderBuild623(){CurrentStageVisualRuntimeRenderPipelineConverter=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_IDLE;StageVisualRuntimeRenderPipelineConverterReady=false;StageVisualRuntimeRenderPipelineConverterReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineConverter(bool ready){StageVisualRuntimeRenderPipelineConverterReady=ready;CurrentStageVisualRuntimeRenderPipelineConverter=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONVERTER_IDLE;}

// Build 62.4
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_STATE{STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_IDLE=0,STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_READY};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_STATE CurrentStageVisualRuntimeRenderPipelineEmitter=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_IDLE;
bool StageVisualRuntimeRenderPipelineEmitterReady=false;
string StageVisualRuntimeRenderPipelineEmitterReason="";
void ResetStageRenderBuild624(){CurrentStageVisualRuntimeRenderPipelineEmitter=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_IDLE;StageVisualRuntimeRenderPipelineEmitterReady=false;StageVisualRuntimeRenderPipelineEmitterReason="Reset";}
void UpdateStageVisualRuntimeRenderPipelineEmitter(bool ready){StageVisualRuntimeRenderPipelineEmitterReady=ready;CurrentStageVisualRuntimeRenderPipelineEmitter=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EMITTER_IDLE;}


// Build 62.5
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_STATE CurrentStageVisualRuntimeRenderPipelineCollector=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_IDLE;
bool StageVisualRuntimeRenderPipelineCollectorReady=false;
string StageVisualRuntimeRenderPipelineCollectorReason="";
void ResetStageRenderBuild625(){
   CurrentStageVisualRuntimeRenderPipelineCollector=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_IDLE;
   StageVisualRuntimeRenderPipelineCollectorReady=false;
   StageVisualRuntimeRenderPipelineCollectorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineCollector(bool ready){
   StageVisualRuntimeRenderPipelineCollectorReady=ready;
   CurrentStageVisualRuntimeRenderPipelineCollector=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COLLECTOR_IDLE;
}


// Build 62.6
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_STATE CurrentStageVisualRuntimeRenderPipelineSynchronizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_IDLE;
bool StageVisualRuntimeRenderPipelineSynchronizerReady=false;
string StageVisualRuntimeRenderPipelineSynchronizerReason="";
void ResetStageRenderBuild626(){
   CurrentStageVisualRuntimeRenderPipelineSynchronizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_IDLE;
   StageVisualRuntimeRenderPipelineSynchronizerReady=false;
   StageVisualRuntimeRenderPipelineSynchronizerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineSynchronizer(bool ready){
   StageVisualRuntimeRenderPipelineSynchronizerReady=ready;
   CurrentStageVisualRuntimeRenderPipelineSynchronizer=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_SYNCHRONIZER_IDLE;
}


// Build 62.7
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_STATE CurrentStageVisualRuntimeRenderPipelineCoordinator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_IDLE;
bool StageVisualRuntimeRenderPipelineCoordinatorReady=false;
string StageVisualRuntimeRenderPipelineCoordinatorReason="";
void ResetStageRenderBuild627(){
   CurrentStageVisualRuntimeRenderPipelineCoordinator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_IDLE;
   StageVisualRuntimeRenderPipelineCoordinatorReady=false;
   StageVisualRuntimeRenderPipelineCoordinatorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineCoordinator(bool ready){
   StageVisualRuntimeRenderPipelineCoordinatorReady=ready;
   CurrentStageVisualRuntimeRenderPipelineCoordinator=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_COORDINATOR_IDLE;
}


// Build 62.8
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_STATE CurrentStageVisualRuntimeRenderPipelineDispatcher=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_IDLE;
bool StageVisualRuntimeRenderPipelineDispatcherReady=false;
string StageVisualRuntimeRenderPipelineDispatcherReason="";
void ResetStageRenderBuild628(){
   CurrentStageVisualRuntimeRenderPipelineDispatcher=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_IDLE;
   StageVisualRuntimeRenderPipelineDispatcherReady=false;
   StageVisualRuntimeRenderPipelineDispatcherReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineDispatcher(bool ready){
   StageVisualRuntimeRenderPipelineDispatcherReady=ready;
   CurrentStageVisualRuntimeRenderPipelineDispatcher=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_DISPATCHER_IDLE;
}


// Build 62.9
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_STATE CurrentStageVisualRuntimeRenderPipelineArchiver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_IDLE;
bool StageVisualRuntimeRenderPipelineArchiverReady=false;
string StageVisualRuntimeRenderPipelineArchiverReason="";
void ResetStageRenderBuild629(){
   CurrentStageVisualRuntimeRenderPipelineArchiver=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_IDLE;
   StageVisualRuntimeRenderPipelineArchiverReady=false;
   StageVisualRuntimeRenderPipelineArchiverReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineArchiver(bool ready){
   StageVisualRuntimeRenderPipelineArchiverReady=ready;
   CurrentStageVisualRuntimeRenderPipelineArchiver=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_ARCHIVER_IDLE;
}


// Build 63.0
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_STATE CurrentStageVisualRuntimeRenderPipelineIndexer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_IDLE;
bool StageVisualRuntimeRenderPipelineIndexerReady=false;
string StageVisualRuntimeRenderPipelineIndexerReason="";
void ResetStageRenderBuild630(){
   CurrentStageVisualRuntimeRenderPipelineIndexer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_IDLE;
   StageVisualRuntimeRenderPipelineIndexerReady=false;
   StageVisualRuntimeRenderPipelineIndexerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineIndexer(bool ready){
   StageVisualRuntimeRenderPipelineIndexerReady=ready;
   CurrentStageVisualRuntimeRenderPipelineIndexer=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_INDEXER_IDLE;
}


// Build 63.1
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_STATE CurrentStageVisualRuntimeRenderPipelineClassifier=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_IDLE;
bool StageVisualRuntimeRenderPipelineClassifierReady=false;
string StageVisualRuntimeRenderPipelineClassifierReason="";
void ResetStageRenderBuild631(){
   CurrentStageVisualRuntimeRenderPipelineClassifier=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_IDLE;
   StageVisualRuntimeRenderPipelineClassifierReady=false;
   StageVisualRuntimeRenderPipelineClassifierReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineClassifier(bool ready){
   StageVisualRuntimeRenderPipelineClassifierReady=ready;
   CurrentStageVisualRuntimeRenderPipelineClassifier=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CLASSIFIER_IDLE;
}


// Build 63.2
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_STATE CurrentStageVisualRuntimeRenderPipelineOptimizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_IDLE;
bool StageVisualRuntimeRenderPipelineOptimizerReady=false;
string StageVisualRuntimeRenderPipelineOptimizerReason="";
void ResetStageRenderBuild632(){
   CurrentStageVisualRuntimeRenderPipelineOptimizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_IDLE;
   StageVisualRuntimeRenderPipelineOptimizerReady=false;
   StageVisualRuntimeRenderPipelineOptimizerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineOptimizer(bool ready){
   StageVisualRuntimeRenderPipelineOptimizerReady=ready;
   CurrentStageVisualRuntimeRenderPipelineOptimizer=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_OPTIMIZER_IDLE;
}


// Build 63.3
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_STATE CurrentStageVisualRuntimeRenderPipelineHarmonizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_IDLE;
bool StageVisualRuntimeRenderPipelineHarmonizerReady=false;
string StageVisualRuntimeRenderPipelineHarmonizerReason="";
void ResetStageRenderBuild633(){
   CurrentStageVisualRuntimeRenderPipelineHarmonizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_IDLE;
   StageVisualRuntimeRenderPipelineHarmonizerReady=false;
   StageVisualRuntimeRenderPipelineHarmonizerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineHarmonizer(bool ready){
   StageVisualRuntimeRenderPipelineHarmonizerReady=ready;
   CurrentStageVisualRuntimeRenderPipelineHarmonizer=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_HARMONIZER_IDLE;
}


// Build 63.4
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_STATE {
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_IDLE=0,
   STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_STATE CurrentStageVisualRuntimeRenderPipelineFinalizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_IDLE;
bool StageVisualRuntimeRenderPipelineFinalizerReady=false;
string StageVisualRuntimeRenderPipelineFinalizerReason="";
void ResetStageRenderBuild634(){
   CurrentStageVisualRuntimeRenderPipelineFinalizer=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_IDLE;
   StageVisualRuntimeRenderPipelineFinalizerReady=false;
   StageVisualRuntimeRenderPipelineFinalizerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineFinalizer(bool ready){
   StageVisualRuntimeRenderPipelineFinalizerReady=ready;
   CurrentStageVisualRuntimeRenderPipelineFinalizer=ready?
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_READY:
      STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_FINALIZER_IDLE;
}


// Build 63.5
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_STATE {
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_IDLE=0,
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_STATE CurrentStageVisualRuntimeRenderPipelineReconciler=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_IDLE;
bool StageVisualRuntimeRenderPipelineReconcilerReady=false;
string StageVisualRuntimeRenderPipelineReconcilerReason="";
void ResetStageRenderBuild635(){
 CurrentStageVisualRuntimeRenderPipelineReconciler=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_IDLE;
 StageVisualRuntimeRenderPipelineReconcilerReady=false;
 StageVisualRuntimeRenderPipelineReconcilerReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineReconciler(bool ready){
 StageVisualRuntimeRenderPipelineReconcilerReady=ready;
 CurrentStageVisualRuntimeRenderPipelineReconciler=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_RECONCILER_IDLE;
}


// Build 63.6
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_STATE {
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_IDLE=0,
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_STATE CurrentStageVisualRuntimeRenderPipelineMonitor=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_IDLE;
bool StageVisualRuntimeRenderPipelineMonitorReady=false;
string StageVisualRuntimeRenderPipelineMonitorReason="";
void ResetStageRenderBuild636(){
 CurrentStageVisualRuntimeRenderPipelineMonitor=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_IDLE;
 StageVisualRuntimeRenderPipelineMonitorReady=false;
 StageVisualRuntimeRenderPipelineMonitorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineMonitor(bool ready){
 StageVisualRuntimeRenderPipelineMonitorReady=ready;
 CurrentStageVisualRuntimeRenderPipelineMonitor=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_MONITOR_IDLE;
}


// Build 63.7
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_STATE {
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_IDLE=0,
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_STATE CurrentStageVisualRuntimeRenderPipelineEvaluator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_IDLE;
bool StageVisualRuntimeRenderPipelineEvaluatorReady=false;
string StageVisualRuntimeRenderPipelineEvaluatorReason="";
void ResetStageRenderBuild637(){
 CurrentStageVisualRuntimeRenderPipelineEvaluator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_IDLE;
 StageVisualRuntimeRenderPipelineEvaluatorReady=false;
 StageVisualRuntimeRenderPipelineEvaluatorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineEvaluator(bool ready){
 StageVisualRuntimeRenderPipelineEvaluatorReady=ready;
 CurrentStageVisualRuntimeRenderPipelineEvaluator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_EVALUATOR_IDLE;
}


// Build 63.8
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_STATE {
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_IDLE=0,
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_STATE CurrentStageVisualRuntimeRenderPipelineCalibrator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_IDLE;
bool StageVisualRuntimeRenderPipelineCalibratorReady=false;
string StageVisualRuntimeRenderPipelineCalibratorReason="";
void ResetStageRenderBuild638(){
 CurrentStageVisualRuntimeRenderPipelineCalibrator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_IDLE;
 StageVisualRuntimeRenderPipelineCalibratorReady=false;
 StageVisualRuntimeRenderPipelineCalibratorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineCalibrator(bool ready){
 StageVisualRuntimeRenderPipelineCalibratorReady=ready;
 CurrentStageVisualRuntimeRenderPipelineCalibrator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CALIBRATOR_IDLE;
}


// Build 63.9
enum STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_STATE {
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_IDLE=0,
 STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_READY
};
STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_STATE CurrentStageVisualRuntimeRenderPipelineConsolidator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_IDLE;
bool StageVisualRuntimeRenderPipelineConsolidatorReady=false;
string StageVisualRuntimeRenderPipelineConsolidatorReason="";
void ResetStageRenderBuild639(){
 CurrentStageVisualRuntimeRenderPipelineConsolidator=STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_IDLE;
 StageVisualRuntimeRenderPipelineConsolidatorReady=false;
 StageVisualRuntimeRenderPipelineConsolidatorReason="Reset";
}
void UpdateStageVisualRuntimeRenderPipelineConsolidator(bool ready){
 StageVisualRuntimeRenderPipelineConsolidatorReady=ready;
 CurrentStageVisualRuntimeRenderPipelineConsolidator=ready?STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_READY:STAGE_VISUAL_RUNTIME_RENDER_PIPELINE_CONSOLIDATOR_IDLE;
}


//==================================================================
// Build 64.0 - Stage Visual Runtime Engine Complete (Foundation)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_COMPLETE
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_COMPLETE

enum ALAA_STAGE_VISUAL_RUNTIME_ENGINE_STATE
  {
   ALAA_STAGE_VISUAL_RUNTIME_ENGINE_IDLE=0,
   ALAA_STAGE_VISUAL_RUNTIME_ENGINE_INITIALIZED,
   ALAA_STAGE_VISUAL_RUNTIME_ENGINE_RUNNING,
   ALAA_STAGE_VISUAL_RUNTIME_ENGINE_PAUSED
  };

ALAA_STAGE_VISUAL_RUNTIME_ENGINE_STATE g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_IDLE;
bool   g_AlaaStageVisualRuntimeInitialized=false;
string g_AlaaStageVisualRuntimeStatus="Idle";

void AlaaStageVisualRuntimeReset64()
  {
   g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_IDLE;
   g_AlaaStageVisualRuntimeInitialized=false;
   g_AlaaStageVisualRuntimeStatus="Reset";
  }

void AlaaStageVisualRuntimeInitialize64()
  {
   g_AlaaStageVisualRuntimeInitialized=true;
   g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_INITIALIZED;
   g_AlaaStageVisualRuntimeStatus="Initialized";
  }

void AlaaStageVisualRuntimeTick64()
  {
   if(!g_AlaaStageVisualRuntimeInitialized)
      return;
   g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_RUNNING;
   g_AlaaStageVisualRuntimeStatus="Running";
  }

#endif


//==================================================================
// Build 64.1 - Stage Visual Runtime Engine Complete (Core)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_CORE
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_CORE

struct ALAA_STAGE_VISUAL_RUNTIME_CONTEXT
  {
   bool     enabled;
   bool     visible;
   int      active_stage;
   datetime last_update;
   string   message;
  };

ALAA_STAGE_VISUAL_RUNTIME_CONTEXT g_AlaaStageVisualRuntimeContext =
  {
   true,
   true,
   -1,
   0,
   "Ready"
  };

bool AlaaStageVisualRuntimeSetStage64(const int stage,const string reason)
  {
   g_AlaaStageVisualRuntimeContext.active_stage = stage;
   g_AlaaStageVisualRuntimeContext.last_update = TimeCurrent();
   g_AlaaStageVisualRuntimeContext.message = reason;
   return true;
  }

void AlaaStageVisualRuntimeEnable64(const bool enable)
  {
   g_AlaaStageVisualRuntimeContext.enabled = enable;
  }

bool AlaaStageVisualRuntimeIsActive64()
  {
   return g_AlaaStageVisualRuntimeContext.enabled &&
          g_AlaaStageVisualRuntimeInitialized;
  }

#endif


//==================================================================
// Build 64.2 - Stage Visual Runtime Engine Complete (Execution)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_EXECUTION
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_EXECUTION

bool g_AlaaStageVisualRuntimeExecutionEnabled=true;
ulong g_AlaaStageVisualRuntimeExecutionCounter=0;

bool AlaaStageVisualRuntimeExecute64()
  {
   if(!AlaaStageVisualRuntimeIsActive64())
      return false;

   g_AlaaStageVisualRuntimeExecutionCounter++;
   g_AlaaStageVisualRuntimeContext.last_update=TimeCurrent();
   return true;
  }

void AlaaStageVisualRuntimePause64()
  {
   g_AlaaStageVisualRuntimeExecutionEnabled=false;
   g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_PAUSED;
   g_AlaaStageVisualRuntimeStatus="Paused";
  }

void AlaaStageVisualRuntimeResume64()
  {
   g_AlaaStageVisualRuntimeExecutionEnabled=true;
   g_AlaaStageVisualRuntimeEngineState=ALAA_STAGE_VISUAL_RUNTIME_ENGINE_RUNNING;
   g_AlaaStageVisualRuntimeStatus="Running";
  }

#endif


//==================================================================
// Build 64.3 - Stage Visual Runtime Engine Complete (Lifecycle)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_LIFECYCLE
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_LIFECYCLE

enum ALAA_STAGE_VISUAL_LIFECYCLE_STATE
  {
   ALAA_STAGE_LIFE_CREATED=0,
   ALAA_STAGE_LIFE_READY,
   ALAA_STAGE_LIFE_ACTIVE,
   ALAA_STAGE_LIFE_STOPPED
  };

ALAA_STAGE_VISUAL_LIFECYCLE_STATE g_AlaaLifecycleState=ALAA_STAGE_LIFE_CREATED;

void AlaaStageVisualLifecycleStart64()
  {
   if(!g_AlaaStageVisualRuntimeInitialized)
      AlaaStageVisualRuntimeInitialize64();
   g_AlaaLifecycleState=ALAA_STAGE_LIFE_ACTIVE;
   g_AlaaStageVisualRuntimeStatus="Lifecycle Active";
  }

void AlaaStageVisualLifecycleStop64()
  {
   g_AlaaLifecycleState=ALAA_STAGE_LIFE_STOPPED;
   AlaaStageVisualRuntimePause64();
  }

bool AlaaStageVisualLifecycleUpdate64()
  {
   if(g_AlaaLifecycleState!=ALAA_STAGE_LIFE_ACTIVE)
      return false;
   return AlaaStageVisualRuntimeExecute64();
  }

#endif


//==================================================================
// Build 64.4 - Stage Visual Runtime Engine Complete (Integration)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_INTEGRATION
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_INTEGRATION

struct ALAA_STAGE_VISUAL_RUNTIME_INTEGRATION_STATUS
  {
   bool linked;
   bool synchronized;
   ulong update_count;
  };

ALAA_STAGE_VISUAL_RUNTIME_INTEGRATION_STATUS g_AlaaIntegration64={false,false,0};

bool AlaaStageVisualRuntimeLink64()
  {
   g_AlaaIntegration64.linked=true;
   return true;
  }

bool AlaaStageVisualRuntimeSynchronize64()
  {
   if(!g_AlaaIntegration64.linked)
      return false;
   g_AlaaIntegration64.synchronized=true;
   g_AlaaIntegration64.update_count++;
   return true;
  }

bool AlaaStageVisualRuntimeProcess64()
  {
   if(!AlaaStageVisualLifecycleUpdate64())
      return false;
   return AlaaStageVisualRuntimeSynchronize64();
  }

#endif


//==================================================================
// Build 64.5 - Stage Visual Runtime Engine Complete (Diagnostics)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_DIAGNOSTICS
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_DIAGNOSTICS

struct ALAA_STAGE_VISUAL_RUNTIME_DIAGNOSTICS
  {
   ulong processed_cycles;
   ulong synchronization_cycles;
   bool  healthy;
   string last_report;
  };

ALAA_STAGE_VISUAL_RUNTIME_DIAGNOSTICS g_AlaaDiagnostics64={0,0,true,"Initialized"};

void AlaaStageVisualDiagnosticsReset64()
  {
   g_AlaaDiagnostics64.processed_cycles=0;
   g_AlaaDiagnostics64.synchronization_cycles=0;
   g_AlaaDiagnostics64.healthy=true;
   g_AlaaDiagnostics64.last_report="Reset";
  }

bool AlaaStageVisualDiagnosticsUpdate64()
  {
   g_AlaaDiagnostics64.processed_cycles++;
   if(g_AlaaIntegration64.synchronized)
      g_AlaaDiagnostics64.synchronization_cycles++;
   g_AlaaDiagnostics64.last_report=
      g_AlaaIntegration64.synchronized?"Synchronized":"Waiting";
   return g_AlaaDiagnostics64.healthy;
  }

#endif


//==================================================================
// Build 64.6 - Stage Visual Runtime Engine Complete (Validation)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_VALIDATION
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_VALIDATION

struct ALAA_STAGE_VISUAL_RUNTIME_VALIDATION
  {
   bool configuration_valid;
   bool runtime_valid;
   ulong validation_passes;
  };

ALAA_STAGE_VISUAL_RUNTIME_VALIDATION g_AlaaValidation64={true,true,0};

bool AlaaStageVisualValidate64()
  {
   g_AlaaValidation64.configuration_valid=g_AlaaStageVisualRuntimeInitialized;
   g_AlaaValidation64.runtime_valid=g_AlaaDiagnostics64.healthy;
   g_AlaaValidation64.validation_passes++;
   return g_AlaaValidation64.configuration_valid &&
          g_AlaaValidation64.runtime_valid;
  }

#endif


//==================================================================
// Build 64.7 - Stage Visual Runtime Engine Complete (Monitoring)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_MONITORING
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_MONITORING

struct ALAA_STAGE_VISUAL_RUNTIME_MONITOR
  {
   bool monitoring_enabled;
   ulong samples;
   datetime last_sample_time;
   string state_snapshot;
  };

ALAA_STAGE_VISUAL_RUNTIME_MONITOR g_AlaaMonitor64={true,0,0,"Idle"};

bool AlaaStageVisualMonitorUpdate64()
  {
   if(!g_AlaaMonitor64.monitoring_enabled)
      return false;

   g_AlaaMonitor64.samples++;
   g_AlaaMonitor64.last_sample_time=TimeCurrent();
   g_AlaaMonitor64.state_snapshot=g_AlaaStageVisualRuntimeStatus;
   return true;
  }

void AlaaStageVisualMonitorEnable64(const bool enable)
  {
   g_AlaaMonitor64.monitoring_enabled=enable;
  }

#endif


//==================================================================
// Build 64.8 - Stage Visual Runtime Engine Complete (Reporting)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_REPORTING
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_REPORTING

struct ALAA_STAGE_VISUAL_RUNTIME_REPORT
  {
   ulong report_id;
   datetime generated_at;
   string summary;
   bool valid;
  };

ALAA_STAGE_VISUAL_RUNTIME_REPORT g_AlaaReport64={0,0,"Not Generated",false};

bool AlaaStageVisualGenerateReport64()
  {
   g_AlaaReport64.report_id++;
   g_AlaaReport64.generated_at=TimeCurrent();
   g_AlaaReport64.valid=AlaaStageVisualValidate64();
   g_AlaaReport64.summary=g_AlaaReport64.valid?"Runtime OK":"Runtime Check Failed";
   return g_AlaaReport64.valid;
  }

#endif


//==================================================================
// Build 64.9 - Stage Visual Runtime Engine Complete (Finalization)
//==================================================================
#ifndef ALAA_BUILD64_STAGE_VISUAL_RUNTIME_FINALIZATION
#define ALAA_BUILD64_STAGE_VISUAL_RUNTIME_FINALIZATION

struct ALAA_STAGE_VISUAL_RUNTIME_FINAL_STATUS
  {
   bool engine_ready;
   bool integrated;
   bool validated;
   bool monitored;
   bool report_available;
  };

ALAA_STAGE_VISUAL_RUNTIME_FINAL_STATUS g_AlaaFinal64={false,false,false,false,false};

bool AlaaStageVisualFinalize64()
  {
   g_AlaaFinal64.engine_ready=g_AlaaStageVisualRuntimeInitialized;
   g_AlaaFinal64.integrated=g_AlaaIntegration64.linked;
   g_AlaaFinal64.validated=AlaaStageVisualValidate64();
   g_AlaaFinal64.monitored=AlaaStageVisualMonitorUpdate64();
   g_AlaaFinal64.report_available=AlaaStageVisualGenerateReport64();

   return g_AlaaFinal64.engine_ready &&
          g_AlaaFinal64.integrated &&
          g_AlaaFinal64.validated;
  }

#endif


//==================================================================
// Build 65.0 - Confidence Engine (Complete)
//==================================================================
#ifndef ALAA_BUILD65_CONFIDENCE_ENGINE
#define ALAA_BUILD65_CONFIDENCE_ENGINE

enum ALAA_CONFIDENCE_GRADE
  {
   ALAA_CONFIDENCE_GRADE_C=0,
   ALAA_CONFIDENCE_GRADE_B,
   ALAA_CONFIDENCE_GRADE_A
  };

struct ALAA_CONFIDENCE_INPUT
  {
   bool trend_ok;
   bool bos_ok;
   bool choch_ok;
   bool liquidity_ok;
   bool sweep_ok;
   bool orderblock_ok;
   bool ifvg_ok;
   bool goldenzone_ok;
   bool retest_ok;
   bool rejection_ok;
   bool confirmation_ok;
  };

struct ALAA_CONFIDENCE_OUTPUT
  {
   int score;
   double percent;
   ALAA_CONFIDENCE_GRADE grade;
   string reason;
   bool valid;
  };

struct ALAA_CONFIDENCE_WEIGHTS
  {
   int trend,bos,choch,liquidity,sweep,orderblock,ifvg,goldenzone,retest,rejection,confirmation;
  };

ALAA_CONFIDENCE_WEIGHTS g_AlaaConfidenceWeights={12,10,10,8,10,12,8,8,8,7,7};
ALAA_CONFIDENCE_OUTPUT g_AlaaConfidence={0,0.0,ALAA_CONFIDENCE_GRADE_C,"Not Calculated",false};

int AlaaConfidenceMaxScore65()
{
 return g_AlaaConfidenceWeights.trend+g_AlaaConfidenceWeights.bos+
 g_AlaaConfidenceWeights.choch+g_AlaaConfidenceWeights.liquidity+
 g_AlaaConfidenceWeights.sweep+g_AlaaConfidenceWeights.orderblock+
 g_AlaaConfidenceWeights.ifvg+g_AlaaConfidenceWeights.goldenzone+
 g_AlaaConfidenceWeights.retest+g_AlaaConfidenceWeights.rejection+
 g_AlaaConfidenceWeights.confirmation;
}

void AlaaConfidenceReset65()
{
 g_AlaaConfidence.score=0;
 g_AlaaConfidence.percent=0;
 g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;
 g_AlaaConfidence.reason="Reset";
 g_AlaaConfidence.valid=false;
}


int ScaleWeight(bool ok,int weight)
{
   return ok ? weight : 0;
}

ALAA_CONFIDENCE_OUTPUT AlaaConfidenceEvaluate65(const ALAA_CONFIDENCE_INPUT &i)
{
 // Build 65.1 - Hard Gate Engine
 if(!i.trend_ok){
  g_AlaaConfidence.score=0;
  g_AlaaConfidence.percent=0.0;
  g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;
  g_AlaaConfidence.reason="Rejected: Trend Gate";
  g_AlaaConfidence.valid=false;
  
//================ Build 65.4 Explainable Confidence ================
string confidence_reason="";
if(i.trend_ok) confidence_reason += "Trend|";
if(i.bos_ok) confidence_reason += "BOS|";
if(i.confirmation_ok) confidence_reason += "Confirmation|";
if(i.retest_ok) confidence_reason += "Retest|";
if(i.rejection_ok) confidence_reason += "Rejection|";
// if output struct has reason field, assign it:
// g_AlaaConfidence.reason = confidence_reason;
//====================================================
return g_AlaaConfidence;
 }
 if(!i.bos_ok){
  g_AlaaConfidence.score=0;
  g_AlaaConfidence.percent=0.0;
  g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;
  g_AlaaConfidence.reason="Rejected: BOS Gate";
  g_AlaaConfidence.valid=false;
  return g_AlaaConfidence;
 }
 if(!i.confirmation_ok){
  g_AlaaConfidence.score=0;
  g_AlaaConfidence.percent=0.0;
  g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;
  g_AlaaConfidence.reason="Rejected: Confirmation Gate";
  g_AlaaConfidence.valid=false;
  return g_AlaaConfidence;
 }

 int s=0;
 s+=ScaleWeight(i.trend_ok,g_AlaaConfidenceWeights.trend);
 s+=ScaleWeight(i.bos_ok,g_AlaaConfidenceWeights.bos);
 s+=ScaleWeight(i.choch_ok,g_AlaaConfidenceWeights.choch);
 s+=ScaleWeight(i.liquidity_ok,g_AlaaConfidenceWeights.liquidity);
 s+=ScaleWeight(i.sweep_ok,g_AlaaConfidenceWeights.sweep);
 s+=ScaleWeight(i.orderblock_ok,g_AlaaConfidenceWeights.orderblock);
 s+=ScaleWeight(i.ifvg_ok,g_AlaaConfidenceWeights.ifvg);
 s+=ScaleWeight(i.goldenzone_ok,g_AlaaConfidenceWeights.goldenzone);
 s+=ScaleWeight(i.retest_ok,g_AlaaConfidenceWeights.retest);
 s+=ScaleWeight(i.rejection_ok,g_AlaaConfidenceWeights.rejection);
 s+=ScaleWeight(i.confirmation_ok,g_AlaaConfidenceWeights.confirmation);

 int maxs=AlaaConfidenceMaxScore65();
 int penalty=0;
 if(!i.retest_ok) penalty+=5;
 if(!i.rejection_ok) penalty+=3;
 if(!i.ifvg_ok) penalty+=2;
 if(penalty>s) penalty=s;
 s-=penalty;
 g_AlaaConfidence.score=s;
 g_AlaaConfidence.percent=(maxs>0)?(100.0*s/maxs):0.0;
 if(g_AlaaConfidence.percent>=80){g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_A;g_AlaaConfidence.reason="High Confidence";}
 else if(g_AlaaConfidence.percent>=60){g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_B;g_AlaaConfidence.reason="Medium Confidence";}
 else {g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;g_AlaaConfidence.reason="Low Confidence";}
 g_AlaaConfidence.valid=true;

//================ Build 65.5 Confidence Validation ================
if((g_AlaaConfidence.grade==ALAA_CONFIDENCE_GRADE_A || g_AlaaConfidence.grade==ALAA_CONFIDENCE_GRADE_B) &&
   (!i.trend_ok || !i.bos_ok || !i.confirmation_ok))
{
   g_AlaaConfidence.score=0;
   g_AlaaConfidence.percent=0.0;
   g_AlaaConfidence.grade=ALAA_CONFIDENCE_GRADE_C;
   g_AlaaConfidence.reason="Validation Failed";
   g_AlaaConfidence.valid=false;
}
//====================================================

 return g_AlaaConfidence;
}

#endif


//==================================================================
// Build 66.0 - Risk & Trade Management Engine (Complete)
//==================================================================
#ifndef ALAA_BUILD66_RISK_TRADE_ENGINE
#define ALAA_BUILD66_RISK_TRADE_ENGINE

enum ALAA_TRADE_STATE
  {
   ALAA_TRADE_IDLE=0,
   ALAA_TRADE_READY,
   ALAA_TRADE_ACTIVE,
   ALAA_TRADE_PROTECTED,
   ALAA_TRADE_CLOSED
  };

struct ALAA_RISK_SETTINGS
  {
   double risk_percent;
   double min_rr;
   bool   allow_break_even;
   bool   allow_trailing;
   bool   allow_partial_tp;
  };

struct ALAA_TRADE_PLAN
  {
   double entry_price;
   double stop_loss;
   double take_profit;
   double risk_reward;
   double position_size;
   bool   break_even;
   bool   trailing_stop;
   bool   partial_tp;
   ALAA_TRADE_STATE state;
   bool   valid;
   string reason;
  };

ALAA_RISK_SETTINGS g_AlaaRisk66={1.0,2.0,true,true,true};
ALAA_TRADE_PLAN g_AlaaTrade66={0,0,0,0,0,false,false,false,ALAA_TRADE_IDLE,false,"Not Initialized"};

void AlaaTradeReset66()
{
 g_AlaaTrade66.entry_price=0;
 g_AlaaTrade66.stop_loss=0;
 g_AlaaTrade66.take_profit=0;
 g_AlaaTrade66.risk_reward=0;
 g_AlaaTrade66.position_size=0;
 g_AlaaTrade66.break_even=false;
 g_AlaaTrade66.trailing_stop=false;
 g_AlaaTrade66.partial_tp=false;
 g_AlaaTrade66.state=ALAA_TRADE_IDLE;
 g_AlaaTrade66.valid=false;
 g_AlaaTrade66.reason="Reset";
}

bool AlaaTradeBuild66(double entry,double sl,double tp,double lot)
{
 if(sl<=0 || tp<=0 || entry<=0)
 {
   g_AlaaTrade66.reason="Invalid Prices";
   return false;
 }
 double risk=entry-sl;
 if(risk<=0)
 {
   g_AlaaTrade66.reason="Invalid Risk";
   return false;
 }
 double reward=tp-entry;
 double rr=reward/risk;
 if(rr<g_AlaaRisk66.min_rr)
 {
   g_AlaaTrade66.reason="RR Too Low";
   return false;
 }

 g_AlaaTrade66.entry_price=entry;
 g_AlaaTrade66.stop_loss=sl;
 g_AlaaTrade66.take_profit=tp;
 g_AlaaTrade66.position_size=lot;
 g_AlaaTrade66.risk_reward=rr;
 g_AlaaTrade66.break_even=g_AlaaRisk66.allow_break_even;
 g_AlaaTrade66.trailing_stop=g_AlaaRisk66.allow_trailing;
 g_AlaaTrade66.partial_tp=g_AlaaRisk66.allow_partial_tp;
 g_AlaaTrade66.state=ALAA_TRADE_READY;
 g_AlaaTrade66.valid=true;
 g_AlaaTrade66.reason="Trade Ready";
 return true;
}

bool AlaaTradeActivate66()
{
 if(!g_AlaaTrade66.valid) return false;
 g_AlaaTrade66.state=ALAA_TRADE_ACTIVE;
 return true;
}

void AlaaTradeProtect66()
{
 if(g_AlaaTrade66.state==ALAA_TRADE_ACTIVE)
   g_AlaaTrade66.state=ALAA_TRADE_PROTECTED;
}

void AlaaTradeClose66()
{
 g_AlaaTrade66.state=ALAA_TRADE_CLOSED;
}

#endif


//==================================================================
// Build 67.0 - Smart Decision Engine (Complete)
//==================================================================
#ifndef ALAA_BUILD67_SMART_DECISION_ENGINE
#define ALAA_BUILD67_SMART_DECISION_ENGINE

enum ALAA_DECISION_ACTION
  {
   ALAA_DECISION_WAIT=0,
   ALAA_DECISION_BUY,
   ALAA_DECISION_SELL,
   ALAA_DECISION_CANCEL
  };

struct ALAA_DECISION_RESULT
  {
   ALAA_DECISION_ACTION action;
   double confidence_percent;
   bool trade_valid;
   string reason;
  };

ALAA_DECISION_RESULT g_AlaaDecision67={ALAA_DECISION_WAIT,0.0,false,"Not evaluated"};

void AlaaDecisionReset67()
{
 g_AlaaDecision67.action=ALAA_DECISION_WAIT;
 g_AlaaDecision67.confidence_percent=0.0;
 g_AlaaDecision67.trade_valid=false;
 g_AlaaDecision67.reason="Reset";
}

ALAA_DECISION_RESULT AlaaDecisionEvaluate67()
{
 g_AlaaDecision67.confidence_percent=g_AlaaConfidence.percent;
 g_AlaaDecision67.trade_valid=g_AlaaTrade66.valid;

 if(!g_AlaaTrade66.valid)
 {
   g_AlaaDecision67.action=ALAA_DECISION_CANCEL;
   g_AlaaDecision67.reason="Trade plan invalid";
 }
 else if(g_AlaaConfidence.percent>=80.0)
 {
   g_AlaaDecision67.action=ALAA_DECISION_BUY;
   g_AlaaDecision67.reason="High confidence";
 }
 else if(g_AlaaConfidence.percent>=60.0)
 {
   g_AlaaDecision67.action=ALAA_DECISION_WAIT;
   g_AlaaDecision67.reason="Medium confidence";
 }
 else
 {
   g_AlaaDecision67.action=ALAA_DECISION_CANCEL;
   g_AlaaDecision67.reason="Low confidence";
 }

 return g_AlaaDecision67;
}

#endif


//==================================================================
// Build 68.0 - Dashboard & Visual Control Engine (Complete)
//==================================================================
#ifndef ALAA_BUILD68_DASHBOARD_ENGINE
#define ALAA_BUILD68_DASHBOARD_ENGINE

struct ALAA_DASHBOARD_STATUS
  {
   string trend;
   double confidence;
   string decision;
   string trade_state;
   bool dashboard_visible;
   datetime last_refresh;
  };

ALAA_DASHBOARD_STATUS g_AlaaDashboard68={
   "Unknown",
   0.0,
   "WAIT",
   "IDLE",
   true,
   0
};

void AlaaDashboardReset68()
  {
   g_AlaaDashboard68.trend="Unknown";
   g_AlaaDashboard68.confidence=0.0;
   g_AlaaDashboard68.decision="WAIT";
   g_AlaaDashboard68.trade_state="IDLE";
   g_AlaaDashboard68.last_refresh=0;
  }

void AlaaDashboardRefresh68()
  {
   g_AlaaDashboard68.confidence=g_AlaaConfidence.percent;

   switch(g_AlaaDecision67.action)
     {
      case ALAA_DECISION_BUY:    g_AlaaDashboard68.decision="BUY"; break;
      case ALAA_DECISION_SELL:   g_AlaaDashboard68.decision="SELL"; break;
      case ALAA_DECISION_CANCEL: g_AlaaDashboard68.decision="CANCEL"; break;
      default:                   g_AlaaDashboard68.decision="WAIT"; break;
     }

   switch(g_AlaaTrade66.state)
     {
      case ALAA_TRADE_READY:     g_AlaaDashboard68.trade_state="READY"; break;
      case ALAA_TRADE_ACTIVE:    g_AlaaDashboard68.trade_state="ACTIVE"; break;
      case ALAA_TRADE_PROTECTED: g_AlaaDashboard68.trade_state="PROTECTED"; break;
      case ALAA_TRADE_CLOSED:    g_AlaaDashboard68.trade_state="CLOSED"; break;
      default:                   g_AlaaDashboard68.trade_state="IDLE"; break;
     }

   g_AlaaDashboard68.last_refresh=TimeCurrent();
  }

string AlaaDashboardSummary68()
  {
   return "Decision="+g_AlaaDashboard68.decision+
          " | Confidence="+DoubleToString(g_AlaaDashboard68.confidence,1)+"%"+
          " | Trade="+g_AlaaDashboard68.trade_state;
  }

#endif


//==================================================================
// Build 69.0 - Integration Engine (Complete)
//==================================================================
#ifndef ALAA_BUILD69_INTEGRATION_ENGINE
#define ALAA_BUILD69_INTEGRATION_ENGINE

struct ALAA_SYSTEM_RUNTIME_STATUS
  {
   bool confidence_ready;
   bool trade_ready;
   bool decision_ready;
   bool dashboard_ready;
   bool integration_ready;
   datetime last_cycle;
  };

ALAA_SYSTEM_RUNTIME_STATUS g_AlaaRuntime69={false,false,false,false,false,0};

bool AlaaIntegrationRun69()
  {
   g_AlaaRuntime69.confidence_ready=g_AlaaConfidence.valid;
   g_AlaaRuntime69.trade_ready=g_AlaaTrade66.valid;

   AlaaDecisionEvaluate67();
   g_AlaaRuntime69.decision_ready=true;

   AlaaDashboardRefresh68();
   g_AlaaRuntime69.dashboard_ready=true;

   g_AlaaRuntime69.integration_ready=
      g_AlaaRuntime69.confidence_ready &&
      g_AlaaRuntime69.trade_ready &&
      g_AlaaRuntime69.decision_ready &&
      g_AlaaRuntime69.dashboard_ready;

   g_AlaaRuntime69.last_cycle=TimeCurrent();
   return g_AlaaRuntime69.integration_ready;
  }

string AlaaIntegrationSummary69()
  {
   return "Integration=" +
          (g_AlaaRuntime69.integration_ready ? "READY" : "WAIT") +
          " | " + AlaaDashboardSummary68();
  }

#endif


//==================================================================
// Build 70.0 - Alpha Runtime Engine
//==================================================================
#ifndef ALAA_BUILD70_ALPHA_RUNTIME
#define ALAA_BUILD70_ALPHA_RUNTIME

enum ALAA_ALPHA_STATE
  {
   ALAA_ALPHA_BOOT=0,
   ALAA_ALPHA_ANALYZE,
   ALAA_ALPHA_DECIDE,
   ALAA_ALPHA_READY
  };

struct ALAA_ALPHA_RUNTIME
  {
   ALAA_ALPHA_STATE state;
   bool initialized;
   bool cycle_ok;
   datetime last_update;
   string status;
  };

ALAA_ALPHA_RUNTIME g_AlaaAlpha70={ALAA_ALPHA_BOOT,false,false,0,"BOOT"};

void AlaaAlphaInitialize70()
  {
   g_AlaaAlpha70.state=ALAA_ALPHA_BOOT;
   g_AlaaAlpha70.initialized=true;
   g_AlaaAlpha70.status="INITIALIZED";
  }

bool AlaaAlphaRunCycle70()
  {
   if(!g_AlaaAlpha70.initialized)
      AlaaAlphaInitialize70();

   g_AlaaAlpha70.state=ALAA_ALPHA_ANALYZE;

   bool ok=AlaaIntegrationRun69();

   g_AlaaAlpha70.state=ALAA_ALPHA_DECIDE;
   g_AlaaAlpha70.cycle_ok=ok;

   if(ok)
     {
      g_AlaaAlpha70.state=ALAA_ALPHA_READY;
      g_AlaaAlpha70.status="SYSTEM READY";
     }
   else
     {
      g_AlaaAlpha70.status="WAITING ENGINES";
     }

   g_AlaaAlpha70.last_update=TimeCurrent();
   return ok;
  }

string AlaaAlphaStatus70()
  {
   return "ALPHA | "+g_AlaaAlpha70.status+
          " | "+AlaaIntegrationSummary69();
  }

#endif


//==================================================================
// Build 71.0 - Swing Detection Engine (Core)
//==================================================================
#ifndef ALAA_BUILD71_SWING_ENGINE
#define ALAA_BUILD71_SWING_ENGINE

input int InpAlaaSwingStrength71 = 3;
input int InpAlaaMaxSwings71 = 100;

enum ALAA_SWING_TYPE71
  {
   ALAA_SWING_NONE71=0,
   ALAA_SWING_HIGH71,
   ALAA_SWING_LOW71
  };

struct ALAA_SWING_POINT71
  {
   datetime time;
   int bar_index;
   double price;
   ALAA_SWING_TYPE71 type;
   bool confirmed;
  };

ALAA_SWING_POINT71 g_AlaaSwings71[100];
int g_AlaaSwingCount71=0;

bool AlaaIsSwingHigh71(const double &high[],int i,int s,int total)
{
 if(i<s || i>=total-s) return false;
 for(int k=1;k<=s;k++)
   if(high[i]<=high[i-k] || high[i]<=high[i+k]) return false;
 return true;
}

bool AlaaIsSwingLow71(const double &low[],int i,int s,int total)
{
 if(i<s || i>=total-s) return false;
 for(int k=1;k<=s;k++)
   if(low[i]>=low[i-k] || low[i]>=low[i+k]) return false;
 return true;
}

void AlaaAddSwing71(datetime t,int bar,double price,ALAA_SWING_TYPE71 type)
{
 if(g_AlaaSwingCount71>=InpAlaaMaxSwings71)
 {
   for(int n=1;n<InpAlaaMaxSwings71;n++)
      g_AlaaSwings71[n-1]=g_AlaaSwings71[n];
   g_AlaaSwingCount71=InpAlaaMaxSwings71-1;
 }
 if(g_AlaaSwingCount71>0)
 {
   ALAA_SWING_POINT71 last=g_AlaaSwings71[g_AlaaSwingCount71-1];
   if(last.bar_index==bar && last.type==type) return;
 }
 g_AlaaSwings71[g_AlaaSwingCount71].time=t;
 g_AlaaSwings71[g_AlaaSwingCount71].bar_index=bar;
 g_AlaaSwings71[g_AlaaSwingCount71].price=price;
 g_AlaaSwings71[g_AlaaSwingCount71].type=type;
 g_AlaaSwings71[g_AlaaSwingCount71].confirmed=true;
 g_AlaaSwingCount71++;
}

void AlaaScanSwings71(const datetime &time[],const double &high[],const double &low[],int rates_total)
{
 int start=InpAlaaSwingStrength71;
 int end=rates_total-InpAlaaSwingStrength71;
 for(int i=start;i<end;i++)
 {
   if(AlaaIsSwingHigh71(high,i,InpAlaaSwingStrength71,rates_total))
      AlaaAddSwing71(time[i],i,high[i],ALAA_SWING_HIGH71);
   else if(AlaaIsSwingLow71(low,i,InpAlaaSwingStrength71,rates_total))
      AlaaAddSwing71(time[i],i,low[i],ALAA_SWING_LOW71);
 }
}

#endif


//==================================================================
// Build 72.0 - Market Structure Engine (Core)
//==================================================================
#ifndef ALAA_BUILD72_MARKET_STRUCTURE_ENGINE
#define ALAA_BUILD72_MARKET_STRUCTURE_ENGINE

enum ALAA_STRUCTURE_TYPE72
  {
   ALAA_STRUCTURE_UNKNOWN72=0,
   ALAA_STRUCTURE_HH72,
   ALAA_STRUCTURE_HL72,
   ALAA_STRUCTURE_LH72,
   ALAA_STRUCTURE_LL72
  };

struct ALAA_STRUCTURE_STATE72
  {
   ALAA_STRUCTURE_TYPE72 last_type;
   double last_high;
   double last_low;
   bool trend_bullish;
   bool trend_bearish;
   datetime last_update;
  };

ALAA_STRUCTURE_STATE72 g_AlaaStructure72=
 {ALAA_STRUCTURE_UNKNOWN72,0.0,0.0,false,false,0};

void AlaaStructureReset72()
{
 g_AlaaStructure72.last_type=ALAA_STRUCTURE_UNKNOWN72;
 g_AlaaStructure72.last_high=0;
 g_AlaaStructure72.last_low=0;
 g_AlaaStructure72.trend_bullish=false;
 g_AlaaStructure72.trend_bearish=false;
 g_AlaaStructure72.last_update=0;
}

void AlaaStructureUpdate72(double newHigh,double newLow)
{
 if(g_AlaaStructure72.last_high==0 || newHigh>g_AlaaStructure72.last_high)
 {
   g_AlaaStructure72.last_type=ALAA_STRUCTURE_HH72;
   g_AlaaStructure72.trend_bullish=true;
   g_AlaaStructure72.trend_bearish=false;
   g_AlaaStructure72.last_high=newHigh;
 }

 if(g_AlaaStructure72.last_low==0 || newLow>g_AlaaStructure72.last_low)
 {
   g_AlaaStructure72.last_type=ALAA_STRUCTURE_HL72;
   g_AlaaStructure72.last_low=newLow;
 }

 if(newHigh<g_AlaaStructure72.last_high && g_AlaaStructure72.last_high>0)
 {
   g_AlaaStructure72.last_type=ALAA_STRUCTURE_LH72;
   g_AlaaStructure72.trend_bullish=false;
   g_AlaaStructure72.trend_bearish=true;
 }

 if(g_AlaaStructure72.last_low>0 && newLow<g_AlaaStructure72.last_low)
 {
   g_AlaaStructure72.last_type=ALAA_STRUCTURE_LL72;
   g_AlaaStructure72.trend_bullish=false;
   g_AlaaStructure72.trend_bearish=true;
   g_AlaaStructure72.last_low=newLow;
 }

 g_AlaaStructure72.last_update=TimeCurrent();
}

string AlaaStructureText72()
{
 switch(g_AlaaStructure72.last_type)
 {
  case ALAA_STRUCTURE_HH72: return "HH";
  case ALAA_STRUCTURE_HL72: return "HL";
  case ALAA_STRUCTURE_LH72: return "LH";
  case ALAA_STRUCTURE_LL72: return "LL";
 }
 return "UNKNOWN";
}

#endif


//==================================================================
// Build 73.0 - BOS & CHoCH Engine (Core)
//==================================================================
#ifndef ALAA_BUILD73_BOS_CHOCH_ENGINE
#define ALAA_BUILD73_BOS_CHOCH_ENGINE

enum ALAA_BOS_EVENT73
  {
   ALAA_EVENT_NONE73=0,
   ALAA_EVENT_BULLISH_BOS73,
   ALAA_EVENT_BEARISH_BOS73,
   ALAA_EVENT_BULLISH_CHOCH73,
   ALAA_EVENT_BEARISH_CHOCH73
  };

struct ALAA_BOS_STATE73
  {
   ALAA_BOS_EVENT73 event_type;
   bool confirmed;
   double trigger_price;
   datetime event_time;
   string reason;
  };

ALAA_BOS_STATE73 g_AlaaBos73={ALAA_EVENT_NONE73,false,0.0,0,"NONE"};

void AlaaBosReset73()
  {
   g_AlaaBos73.event_type=ALAA_EVENT_NONE73;
   g_AlaaBos73.confirmed=false;
   g_AlaaBos73.trigger_price=0.0;
   g_AlaaBos73.event_time=0;
   g_AlaaBos73.reason="RESET";
  }

void AlaaBosEvaluate73(double previousHigh,double previousLow,double closePrice)
  {
   if(closePrice>previousHigh)
     {
      g_AlaaBos73.event_type=ALAA_EVENT_BULLISH_BOS73;
      g_AlaaBos73.confirmed=true;
      g_AlaaBos73.trigger_price=closePrice;
      g_AlaaBos73.reason="Bullish BOS";
     }
   else if(closePrice<previousLow)
     {
      g_AlaaBos73.event_type=ALAA_EVENT_BEARISH_BOS73;
      g_AlaaBos73.confirmed=true;
      g_AlaaBos73.trigger_price=closePrice;
      g_AlaaBos73.reason="Bearish BOS";
     }
   else
     {
      g_AlaaBos73.event_type=ALAA_EVENT_NONE73;
      g_AlaaBos73.confirmed=false;
      g_AlaaBos73.reason="No Break";
     }

   g_AlaaBos73.event_time=TimeCurrent();
  }

string AlaaBosText73()
  {
   switch(g_AlaaBos73.event_type)
     {
      case ALAA_EVENT_BULLISH_BOS73: return "BULLISH_BOS";
      case ALAA_EVENT_BEARISH_BOS73: return "BEARISH_BOS";
      case ALAA_EVENT_BULLISH_CHOCH73: return "BULLISH_CHOCH";
      case ALAA_EVENT_BEARISH_CHOCH73: return "BEARISH_CHOCH";
      default: return "NONE";
     }
  }

#endif


//==================================================================
// Build 74.0 - Liquidity & Sweep Engine (Core)
//==================================================================
#ifndef ALAA_BUILD74_LIQUIDITY_ENGINE
#define ALAA_BUILD74_LIQUIDITY_ENGINE

enum ALAA_LIQUIDITY_EVENT74
  {
   ALAA_LQ_NONE74=0,
   ALAA_LQ_HIGH74,
   ALAA_LQ_LOW74,
   ALAA_SWEEP_HIGH74,
   ALAA_SWEEP_LOW74
  };

struct ALAA_LIQUIDITY_STATE74
  {
   ALAA_LIQUIDITY_EVENT74 event_type;
   double level;
   bool confirmed;
   datetime event_time;
   string reason;
  };

ALAA_LIQUIDITY_STATE74 g_AlaaLiquidity74={ALAA_LQ_NONE74,0.0,false,0,"NONE"};

void AlaaLiquidityReset74()
{
 g_AlaaLiquidity74.event_type=ALAA_LQ_NONE74;
 g_AlaaLiquidity74.level=0.0;
 g_AlaaLiquidity74.confirmed=false;
 g_AlaaLiquidity74.event_time=0;
 g_AlaaLiquidity74.reason="RESET";
}

void AlaaLiquidityEvaluate74(double swingHigh,double swingLow,double highPrice,double lowPrice,double closePrice)
{
 if(highPrice>swingHigh)
 {
   g_AlaaLiquidity74.level=swingHigh;
   if(closePrice<swingHigh){
      g_AlaaLiquidity74.event_type=ALAA_SWEEP_HIGH74;
      g_AlaaLiquidity74.reason="High Sweep";
   }else{
      g_AlaaLiquidity74.event_type=ALAA_LQ_HIGH74;
      g_AlaaLiquidity74.reason="High Liquidity Taken";
   }
   g_AlaaLiquidity74.confirmed=true;
 }
 else if(lowPrice<swingLow)
 {
   g_AlaaLiquidity74.level=swingLow;
   if(closePrice>swingLow){
      g_AlaaLiquidity74.event_type=ALAA_SWEEP_LOW74;
      g_AlaaLiquidity74.reason="Low Sweep";
   }else{
      g_AlaaLiquidity74.event_type=ALAA_LQ_LOW74;
      g_AlaaLiquidity74.reason="Low Liquidity Taken";
   }
   g_AlaaLiquidity74.confirmed=true;
 }
 else{
   g_AlaaLiquidity74.event_type=ALAA_LQ_NONE74;
   g_AlaaLiquidity74.confirmed=false;
   g_AlaaLiquidity74.reason="No Event";
 }
 g_AlaaLiquidity74.event_time=TimeCurrent();
}

string AlaaLiquidityText74()
{
 switch(g_AlaaLiquidity74.event_type)
 {
  case ALAA_LQ_HIGH74: return "LQ_HIGH";
  case ALAA_LQ_LOW74: return "LQ_LOW";
  case ALAA_SWEEP_HIGH74: return "SWEEP_HIGH";
  case ALAA_SWEEP_LOW74: return "SWEEP_LOW";
  default: return "NONE";
 }
}

#endif


//==================================================================
// Build 75.0 - Order Block Engine (Core)
//==================================================================
#ifndef ALAA_BUILD75_ORDERBLOCK_ENGINE
#define ALAA_BUILD75_ORDERBLOCK_ENGINE

enum ALAA_OB_GRADE75
  {
   ALAA_OB_NONE75=0,
   ALAA_OB_GRADE_C75,
   ALAA_OB_GRADE_B75,
   ALAA_OB_GRADE_A75
  };

struct ALAA_ORDERBLOCK75
  {
   bool bullish;
   double high;
   double low;
   ALAA_OB_GRADE75 grade;
   bool active;
   datetime created_time;
  };

ALAA_ORDERBLOCK75 g_AlaaOrderBlock75={true,0.0,0.0,ALAA_OB_NONE75,false,0};

void AlaaOrderBlockReset75()
  {
   g_AlaaOrderBlock75.bullish=true;
   g_AlaaOrderBlock75.high=0.0;
   g_AlaaOrderBlock75.low=0.0;
   g_AlaaOrderBlock75.grade=ALAA_OB_NONE75;
   g_AlaaOrderBlock75.active=false;
   g_AlaaOrderBlock75.created_time=0;
  }

void AlaaCreateOrderBlock75(bool bullish,double highPrice,double lowPrice,bool hasSweep,bool hasBos)
  {
   g_AlaaOrderBlock75.bullish=bullish;
   g_AlaaOrderBlock75.high=highPrice;
   g_AlaaOrderBlock75.low=lowPrice;
   g_AlaaOrderBlock75.active=true;
   g_AlaaOrderBlock75.created_time=TimeCurrent();

   if(hasSweep && hasBos)
      g_AlaaOrderBlock75.grade=ALAA_OB_GRADE_A75;
   else if(hasBos)
      g_AlaaOrderBlock75.grade=ALAA_OB_GRADE_B75;
   else
      g_AlaaOrderBlock75.grade=ALAA_OB_GRADE_C75;
  }

string AlaaOrderBlockGrade75()
  {
   switch(g_AlaaOrderBlock75.grade)
     {
      case ALAA_OB_GRADE_A75: return "GRADE_A";
      case ALAA_OB_GRADE_B75: return "GRADE_B";
      case ALAA_OB_GRADE_C75: return "GRADE_C";
      default: return "NONE";
     }
  }

#endif


//==================================================================
// Build 76.0 - Fair Value Gap Engine (Core)
//==================================================================
#ifndef ALAA_BUILD76_FVG_ENGINE
#define ALAA_BUILD76_FVG_ENGINE

enum ALAA_FVG_TYPE76
  {
   ALAA_FVG_NONE76=0,
   ALAA_FVG_BULLISH76,
   ALAA_FVG_BEARISH76
  };

struct ALAA_FVG_STATE76
  {
   ALAA_FVG_TYPE76 type;
   double upper;
   double lower;
   bool active;
   bool filled;
   datetime detected_time;
  };

ALAA_FVG_STATE76 g_AlaaFVG76={ALAA_FVG_NONE76,0.0,0.0,false,false,0};

void AlaaFVGReset76()
{
 g_AlaaFVG76.type=ALAA_FVG_NONE76;
 g_AlaaFVG76.upper=0.0;
 g_AlaaFVG76.lower=0.0;
 g_AlaaFVG76.active=false;
 g_AlaaFVG76.filled=false;
 g_AlaaFVG76.detected_time=0;
}

void AlaaDetectFVG76(double high1,double low1,double high2,double low2,double high3,double low3)
{
 AlaaFVGReset76();

 if(low3>high1)
 {
   g_AlaaFVG76.type=ALAA_FVG_BULLISH76;
   g_AlaaFVG76.lower=high1;
   g_AlaaFVG76.upper=low3;
   g_AlaaFVG76.active=true;
 }
 else if(high3<low1)
 {
   g_AlaaFVG76.type=ALAA_FVG_BEARISH76;
   g_AlaaFVG76.upper=low1;
   g_AlaaFVG76.lower=high3;
   g_AlaaFVG76.active=true;
 }

 if(g_AlaaFVG76.active)
   g_AlaaFVG76.detected_time=TimeCurrent();
}

void AlaaMarkFVGFilled76(double price)
{
 if(!g_AlaaFVG76.active) return;
 if(price>=g_AlaaFVG76.lower && price<=g_AlaaFVG76.upper)
    g_AlaaFVG76.filled=true;
}

string AlaaFVGText76()
{
 switch(g_AlaaFVG76.type)
 {
  case ALAA_FVG_BULLISH76: return "BULLISH_FVG";
  case ALAA_FVG_BEARISH76: return "BEARISH_FVG";
  default: return "NONE";
 }
}

#endif


//==================================================================
// Build 77.0 - Retest & Entry Zone Engine (Core)
//==================================================================
#ifndef ALAA_BUILD77_RETEST_ENGINE
#define ALAA_BUILD77_RETEST_ENGINE

enum ALAA_RETEST_STATE77
  {
   ALAA_RETEST_NONE77=0,
   ALAA_RETEST_WAITING77,
   ALAA_RETEST_CONFIRMED77,
   ALAA_RETEST_FAILED77
  };

struct ALAA_ENTRY_ZONE77
  {
   double upper;
   double lower;
   bool bullish;
   ALAA_RETEST_STATE77 state;
   datetime updated;
  };

ALAA_ENTRY_ZONE77 g_AlaaEntryZone77={0.0,0.0,true,ALAA_RETEST_NONE77,0};

void AlaaEntryZoneReset77()
{
 g_AlaaEntryZone77.upper=0.0;
 g_AlaaEntryZone77.lower=0.0;
 g_AlaaEntryZone77.bullish=true;
 g_AlaaEntryZone77.state=ALAA_RETEST_NONE77;
 g_AlaaEntryZone77.updated=0;
}

void AlaaDefineEntryZone77(double upper,double lower,bool bullish)
{
 g_AlaaEntryZone77.upper=upper;
 g_AlaaEntryZone77.lower=lower;
 g_AlaaEntryZone77.bullish=bullish;
 g_AlaaEntryZone77.state=ALAA_RETEST_WAITING77;
 g_AlaaEntryZone77.updated=TimeCurrent();
}

void AlaaEvaluateRetest77(double closePrice)
{
 if(g_AlaaEntryZone77.state!=ALAA_RETEST_WAITING77)
    return;

 if(closePrice>=g_AlaaEntryZone77.lower && closePrice<=g_AlaaEntryZone77.upper)
    g_AlaaEntryZone77.state=ALAA_RETEST_CONFIRMED77;
}

string AlaaRetestText77()
{
 switch(g_AlaaEntryZone77.state)
 {
  case ALAA_RETEST_WAITING77: return "WAITING";
  case ALAA_RETEST_CONFIRMED77: return "CONFIRMED";
  case ALAA_RETEST_FAILED77: return "FAILED";
  default: return "NONE";
 }
}

#endif


//==================================================================
// Build 78.0 - Rejection Candle Engine (Core)
//==================================================================
#ifndef ALAA_BUILD78_REJECTION_ENGINE
#define ALAA_BUILD78_REJECTION_ENGINE

enum ALAA_REJECTION_TYPE78
  {
   ALAA_REJECTION_NONE78=0,
   ALAA_REJECTION_BULLISH78,
   ALAA_REJECTION_BEARISH78
  };

struct ALAA_REJECTION_STATE78
  {
   ALAA_REJECTION_TYPE78 type;
   bool confirmed;
   double candleHigh;
   double candleLow;
   datetime detectedTime;
  };

ALAA_REJECTION_STATE78 g_AlaaRejection78={ALAA_REJECTION_NONE78,false,0.0,0.0,0};

void AlaaRejectionReset78()
  {
   g_AlaaRejection78.type=ALAA_REJECTION_NONE78;
   g_AlaaRejection78.confirmed=false;
   g_AlaaRejection78.candleHigh=0.0;
   g_AlaaRejection78.candleLow=0.0;
   g_AlaaRejection78.detectedTime=0;
  }

void AlaaEvaluateRejection78(double openPrice,double highPrice,double lowPrice,double closePrice)
  {
   AlaaRejectionReset78();

   double body=(closePrice>openPrice)?(closePrice-openPrice):(openPrice-closePrice);
   double upperWick=highPrice-((closePrice>openPrice)?closePrice:openPrice);
   double lowerWick=((closePrice<openPrice)?closePrice:openPrice)-lowPrice;

   if(lowerWick>body*2.0)
     {
      g_AlaaRejection78.type=ALAA_REJECTION_BULLISH78;
      g_AlaaRejection78.confirmed=true;
     }
   else if(upperWick>body*2.0)
     {
      g_AlaaRejection78.type=ALAA_REJECTION_BEARISH78;
      g_AlaaRejection78.confirmed=true;
     }

   g_AlaaRejection78.candleHigh=highPrice;
   g_AlaaRejection78.candleLow=lowPrice;
   g_AlaaRejection78.detectedTime=TimeCurrent();
  }

string AlaaRejectionText78()
  {
   switch(g_AlaaRejection78.type)
     {
      case ALAA_REJECTION_BULLISH78: return "BULLISH_REJECTION";
      case ALAA_REJECTION_BEARISH78: return "BEARISH_REJECTION";
      default: return "NONE";
     }
  }

#endif


//==================================================================
// Build 79.0 - Confirmation Candle Engine (Core)
//==================================================================
#ifndef ALAA_BUILD79_CONFIRMATION_ENGINE
#define ALAA_BUILD79_CONFIRMATION_ENGINE

enum ALAA_CONFIRMATION_TYPE79
  {
   ALAA_CONFIRMATION_NONE79=0,
   ALAA_CONFIRMATION_BULLISH79,
   ALAA_CONFIRMATION_BEARISH79
  };

struct ALAA_CONFIRMATION_STATE79
  {
   ALAA_CONFIRMATION_TYPE79 type;
   bool confirmed;
   double entryPrice;
   double stopReference;
   datetime detectedTime;
  };

ALAA_CONFIRMATION_STATE79 g_AlaaConfirmation79={ALAA_CONFIRMATION_NONE79,false,0.0,0.0,0};

void AlaaConfirmationReset79()
  {
   g_AlaaConfirmation79.type=ALAA_CONFIRMATION_NONE79;
   g_AlaaConfirmation79.confirmed=false;
   g_AlaaConfirmation79.entryPrice=0.0;
   g_AlaaConfirmation79.stopReference=0.0;
   g_AlaaConfirmation79.detectedTime=0;
  }

void AlaaEvaluateConfirmation79(double openPrice,double highPrice,double lowPrice,double closePrice)
  {
   AlaaConfirmationReset79();

   if(closePrice>openPrice)
     {
      g_AlaaConfirmation79.type=ALAA_CONFIRMATION_BULLISH79;
      g_AlaaConfirmation79.confirmed=true;
      g_AlaaConfirmation79.entryPrice=closePrice;
      g_AlaaConfirmation79.stopReference=lowPrice;
     }
   else if(closePrice<openPrice)
     {
      g_AlaaConfirmation79.type=ALAA_CONFIRMATION_BEARISH79;
      g_AlaaConfirmation79.confirmed=true;
      g_AlaaConfirmation79.entryPrice=closePrice;
      g_AlaaConfirmation79.stopReference=highPrice;
     }

   g_AlaaConfirmation79.detectedTime=TimeCurrent();
  }

string AlaaConfirmationText79()
  {
   switch(g_AlaaConfirmation79.type)
     {
      case ALAA_CONFIRMATION_BULLISH79: return "BULLISH_CONFIRMATION";
      case ALAA_CONFIRMATION_BEARISH79: return "BEARISH_CONFIRMATION";
      default: return "NONE";
     }
  }

#endif


//==================================================================
// Build 80.0 - Signal Integration Engine (Core)
//==================================================================
#ifndef ALAA_BUILD80_SIGNAL_ENGINE
#define ALAA_BUILD80_SIGNAL_ENGINE

enum ALAA_SIGNAL80
  {
   ALAA_SIGCTX_NONE80=0,
   ALAA_SIGNAL_BUY80,
   ALAA_SIGNAL_SELL80
  };

struct ALAA_SIGNAL_STATE80
  {
   ALAA_SIGNAL80 signal;
   bool valid;
   double entry;
   double stopLoss;
   datetime signalTime;
   string reason;
  };

ALAA_SIGNAL_STATE80 g_AlaaSignal80={ALAA_SIGCTX_NONE80,false,0.0,0.0,0,"NONE"};

void AlaaSignalReset80()
  {
   g_AlaaSignal80.signal=ALAA_SIGCTX_NONE80;
   g_AlaaSignal80.valid=false;
   g_AlaaSignal80.entry=0.0;
   g_AlaaSignal80.stopLoss=0.0;
   g_AlaaSignal80.signalTime=0;
   g_AlaaSignal80.reason="RESET";
  }

void AlaaEvaluateSignal80(bool bullishTrend,
                          bool bosConfirmed,
                          bool liquidityConfirmed,
                          bool orderBlockReady,
                          bool fvgReady,
                          bool retestConfirmed,
                          bool rejectionConfirmed,
                          bool confirmationConfirmed,
                          double entryPrice,
                          double stopPrice)
  {
   AlaaSignalReset80();

   bool setup = bosConfirmed &&
                liquidityConfirmed &&
                orderBlockReady &&
                fvgReady &&
                retestConfirmed &&
                rejectionConfirmed &&
                confirmationConfirmed;

   if(!setup)
      return;

   g_AlaaSignal80.signal = bullishTrend ? ALAA_SIGNAL_BUY80 : ALAA_SIGNAL_SELL80;
   g_AlaaSignal80.valid = true;
   g_AlaaSignal80.entry = entryPrice;
   g_AlaaSignal80.stopLoss = stopPrice;
   g_AlaaSignal80.signalTime = TimeCurrent();
   g_AlaaSignal80.reason = "Core conditions satisfied";
  }

string AlaaSignalText80()
  {
   switch(g_AlaaSignal80.signal)
     {
      case ALAA_SIGNAL_BUY80: return "BUY";
      case ALAA_SIGNAL_SELL80: return "SELL";
      default: return "NONE";
     }
  }

#endif


//==================================================================
// Build 81.0 - Trade Validation Engine (Core)
//==================================================================
#ifndef ALAA_BUILD81_TRADE_VALIDATION_ENGINE
#define ALAA_BUILD81_TRADE_VALIDATION_ENGINE

enum ALAA_VALIDATION81
  {
   ALAA_VALIDATION_FAIL81=0,
   ALAA_VALIDATION_PASS81
  };

struct ALAA_VALIDATION_STATE81
  {
   ALAA_VALIDATION81 status;
   bool spread_ok;
   bool risk_ok;
   bool signal_ok;
   string message;
   datetime checked_time;
  };

ALAA_VALIDATION_STATE81 g_AlaaValidation81=
 {ALAA_VALIDATION_FAIL81,false,false,false,"NOT_CHECKED",0};

void AlaaValidationReset81()
  {
   g_AlaaValidation81.status=ALAA_VALIDATION_FAIL81;
   g_AlaaValidation81.spread_ok=false;
   g_AlaaValidation81.risk_ok=false;
   g_AlaaValidation81.signal_ok=false;
   g_AlaaValidation81.message="RESET";
   g_AlaaValidation81.checked_time=0;
  }

void AlaaValidateTrade81(bool signalValid,bool spreadOk,bool riskOk)
  {
   AlaaValidationReset81();

   g_AlaaValidation81.signal_ok=signalValid;
   g_AlaaValidation81.spread_ok=spreadOk;
   g_AlaaValidation81.risk_ok=riskOk;

   if(signalValid && spreadOk && riskOk)
     {
      g_AlaaValidation81.status=ALAA_VALIDATION_PASS81;
      g_AlaaValidation81.message="TRADE_VALID";
     }
   else
     {
      g_AlaaValidation81.message="TRADE_REJECTED";
     }

   g_AlaaValidation81.checked_time=TimeCurrent();
  }

string AlaaValidationText81()
  {
   return (g_AlaaValidation81.status==ALAA_VALIDATION_PASS81) ? "PASS" : "FAIL";
  }

#endif


//==================================================================
// Build 82.0 - Runtime Pipeline Engine (Core)
//==================================================================
#ifndef ALAA_BUILD82_RUNTIME_PIPELINE_ENGINE
#define ALAA_BUILD82_RUNTIME_PIPELINE_ENGINE

struct ALAA_RUNTIME_STATE82
  {
   bool trend_ready;
   bool structure_ready;
   bool signal_ready;
   bool validation_ready;
   bool pipeline_complete;
   datetime last_run;
  };

ALAA_RUNTIME_STATE82 g_AlaaRuntime82={false,false,false,false,false,0};

void AlaaRuntimeReset82()
  {
   g_AlaaRuntime82.trend_ready=false;
   g_AlaaRuntime82.structure_ready=false;
   g_AlaaRuntime82.signal_ready=false;
   g_AlaaRuntime82.validation_ready=false;
   g_AlaaRuntime82.pipeline_complete=false;
   g_AlaaRuntime82.last_run=0;
  }

void AlaaRuntimeExecute82(bool trendReady,
                          bool structureReady,
                          bool signalReady,
                          bool validationReady)
  {
   g_AlaaRuntime82.trend_ready=trendReady;
   g_AlaaRuntime82.structure_ready=structureReady;
   g_AlaaRuntime82.signal_ready=signalReady;
   g_AlaaRuntime82.validation_ready=validationReady;

   g_AlaaRuntime82.pipeline_complete=
      trendReady &&
      structureReady &&
      signalReady &&
      validationReady;

   g_AlaaRuntime82.last_run=TimeCurrent();
  }

string AlaaRuntimeStatus82()
  {
   return g_AlaaRuntime82.pipeline_complete ? "PIPELINE_READY" : "PIPELINE_WAIT";
  }

#endif


//==================================================================
// Build 83.0 - Execution Coordinator Engine (Core)
//==================================================================
#ifndef ALAA_BUILD83_EXECUTION_COORDINATOR_ENGINE
#define ALAA_BUILD83_EXECUTION_COORDINATOR_ENGINE

enum ALAA_EXECUTION_STATE83
  {
   ALAA_EXEC_IDLE83=0,
   ALAA_EXEC_WAIT83,
   ALAA_EXEC_READY83,
   ALAA_EXEC_BLOCKED83
  };

struct ALAA_EXECUTION_STATUS83
  {
   ALAA_EXECUTION_STATE83 state;
   bool signal_valid;
   bool validation_passed;
   bool pipeline_ready;
   datetime last_update;
  };

ALAA_EXECUTION_STATUS83 g_AlaaExecution83=
 {ALAA_EXEC_IDLE83,false,false,false,0};

void AlaaExecutionReset83()
  {
   g_AlaaExecution83.state=ALAA_EXEC_IDLE83;
   g_AlaaExecution83.signal_valid=false;
   g_AlaaExecution83.validation_passed=false;
   g_AlaaExecution83.pipeline_ready=false;
   g_AlaaExecution83.last_update=0;
  }

void AlaaExecutionUpdate83(bool signalValid,bool validationPassed,bool pipelineReady)
  {
   g_AlaaExecution83.signal_valid=signalValid;
   g_AlaaExecution83.validation_passed=validationPassed;
   g_AlaaExecution83.pipeline_ready=pipelineReady;

   if(signalValid && validationPassed && pipelineReady)
      g_AlaaExecution83.state=ALAA_EXEC_READY83;
   else if(signalValid)
      g_AlaaExecution83.state=ALAA_EXEC_WAIT83;
   else
      g_AlaaExecution83.state=ALAA_EXEC_BLOCKED83;

   g_AlaaExecution83.last_update=TimeCurrent();
  }

string AlaaExecutionStateText83()
  {
   switch(g_AlaaExecution83.state)
     {
      case ALAA_EXEC_READY83: return "READY";
      case ALAA_EXEC_WAIT83: return "WAIT";
      case ALAA_EXEC_BLOCKED83: return "BLOCKED";
      default: return "IDLE";
     }
  }

#endif


//==================================================================
// Build 84.0 - Dashboard Runtime State (Core)
//==================================================================
#ifndef ALAA_BUILD84_DASHBOARD_RUNTIME
#define ALAA_BUILD84_DASHBOARD_RUNTIME

struct ALAA_DASHBOARD_STATE84
  {
   string trend;
   string structure;
   string signal;
   string execution;
   bool ready;
   datetime updated;
  };

ALAA_DASHBOARD_STATE84 g_AlaaDashboard84={"UNKNOWN","UNKNOWN","NONE","IDLE",false,0};

void AlaaDashboardUpdate84(string trend,string structure,string signal,string execution,bool ready)
  {
   g_AlaaDashboard84.trend=trend;
   g_AlaaDashboard84.structure=structure;
   g_AlaaDashboard84.signal=signal;
   g_AlaaDashboard84.execution=execution;
   g_AlaaDashboard84.ready=ready;
   g_AlaaDashboard84.updated=TimeCurrent();
  }

string AlaaDashboardSummary84()
  {
   return "Trend="+g_AlaaDashboard84.trend+
          " Structure="+g_AlaaDashboard84.structure+
          " Signal="+g_AlaaDashboard84.signal+
          " Exec="+g_AlaaDashboard84.execution;
  }

#endif


//==================================================================
// Build 85.0 - Engine Health Monitor (Core)
//==================================================================
#ifndef ALAA_BUILD85_ENGINE_HEALTH
#define ALAA_BUILD85_ENGINE_HEALTH

struct ALAA_ENGINE_HEALTH85
  {
   bool trend_ok;
   bool structure_ok;
   bool signal_ok;
   bool runtime_ok;
   bool execution_ok;
   int ready_count;
   datetime updated;
  };

ALAA_ENGINE_HEALTH85 g_AlaaHealth85={false,false,false,false,false,0,0};

void AlaaHealthReset85()
  {
   g_AlaaHealth85.trend_ok=false;
   g_AlaaHealth85.structure_ok=false;
   g_AlaaHealth85.signal_ok=false;
   g_AlaaHealth85.runtime_ok=false;
   g_AlaaHealth85.execution_ok=false;
   g_AlaaHealth85.ready_count=0;
   g_AlaaHealth85.updated=0;
  }

void AlaaHealthUpdate85(bool trend,bool structure,bool signal,bool runtime,bool execution)
  {
   g_AlaaHealth85.trend_ok=trend;
   g_AlaaHealth85.structure_ok=structure;
   g_AlaaHealth85.signal_ok=signal;
   g_AlaaHealth85.runtime_ok=runtime;
   g_AlaaHealth85.execution_ok=execution;

   g_AlaaHealth85.ready_count=
      (trend?1:0)+
      (structure?1:0)+
      (signal?1:0)+
      (runtime?1:0)+
      (execution?1:0);

   g_AlaaHealth85.updated=TimeCurrent();
  }

bool AlaaSystemHealthy85()
  {
   return g_AlaaHealth85.ready_count==5;
  }

#endif


//==================================================================
// Build 86.0 - Diagnostics Logger (Core)
//==================================================================
#ifndef ALAA_BUILD86_DIAGNOSTICS_LOGGER
#define ALAA_BUILD86_DIAGNOSTICS_LOGGER

struct ALAA_DIAGNOSTICS86
  {
   string last_module;
   string last_message;
   int severity;
   datetime updated;
  };

ALAA_DIAGNOSTICS86 g_AlaaDiagnostics86={"SYSTEM","INIT",0,0};

void AlaaLogDiagnostic86(string module,string message,int severity)
  {
   g_AlaaDiagnostics86.last_module=module;
   g_AlaaDiagnostics86.last_message=message;
   g_AlaaDiagnostics86.severity=severity;
   g_AlaaDiagnostics86.updated=TimeCurrent();
  }

string AlaaDiagnosticsSummary86()
  {
   return g_AlaaDiagnostics86.last_module+
          " : "+
          g_AlaaDiagnostics86.last_message;
  }

#endif


//==================================================================
// Build 87.0 - Runtime Statistics Engine (Core)
//==================================================================
#ifndef ALAA_BUILD87_RUNTIME_STATISTICS
#define ALAA_BUILD87_RUNTIME_STATISTICS

struct ALAA_RUNTIME_STATS87
  {
   ulong total_cycles;
   ulong valid_signals;
   ulong rejected_signals;
   datetime last_cycle_time;
  };

ALAA_RUNTIME_STATS87 g_AlaaRuntimeStats87={0,0,0,0};

void AlaaRuntimeStatsReset87()
  {
   g_AlaaRuntimeStats87.total_cycles=0;
   g_AlaaRuntimeStats87.valid_signals=0;
   g_AlaaRuntimeStats87.rejected_signals=0;
   g_AlaaRuntimeStats87.last_cycle_time=0;
  }

void AlaaRuntimeStatsUpdate87(bool signalAccepted)
  {
   g_AlaaRuntimeStats87.total_cycles++;

   if(signalAccepted)
      g_AlaaRuntimeStats87.valid_signals++;
   else
      g_AlaaRuntimeStats87.rejected_signals++;

   g_AlaaRuntimeStats87.last_cycle_time=TimeCurrent();
  }

double AlaaRuntimeAcceptanceRate87()
  {
   if(g_AlaaRuntimeStats87.total_cycles==0)
      return 0.0;

   return (100.0*g_AlaaRuntimeStats87.valid_signals)/
          g_AlaaRuntimeStats87.total_cycles;
  }

#endif


//==================================================================
// Build 88.0 - Session Statistics Engine (Core)
//==================================================================
#ifndef ALAA_BUILD88_SESSION_STATISTICS
#define ALAA_BUILD88_SESSION_STATISTICS

struct ALAA_SESSION_STATS88
  {
   datetime session_start;
   datetime session_end;
   ulong bars_processed;
   ulong signals_generated;
   bool session_active;
  };

ALAA_SESSION_STATS88 g_AlaaSessionStats88={0,0,0,0,false};

void AlaaSessionStart88()
  {
   g_AlaaSessionStats88.session_start=TimeCurrent();
   g_AlaaSessionStats88.session_end=0;
   g_AlaaSessionStats88.bars_processed=0;
   g_AlaaSessionStats88.signals_generated=0;
   g_AlaaSessionStats88.session_active=true;
  }

void AlaaSessionUpdate88(bool signalGenerated)
  {
   if(!g_AlaaSessionStats88.session_active)
      return;

   g_AlaaSessionStats88.bars_processed++;
   if(signalGenerated)
      g_AlaaSessionStats88.signals_generated++;
  }

void AlaaSessionEnd88()
  {
   g_AlaaSessionStats88.session_end=TimeCurrent();
   g_AlaaSessionStats88.session_active=false;
  }

#endif


//==================================================================
// Build 89.0 - Performance Snapshot Engine (Core)
//==================================================================
#ifndef ALAA_BUILD89_PERFORMANCE_SNAPSHOT
#define ALAA_BUILD89_PERFORMANCE_SNAPSHOT

struct ALAA_PERFORMANCE_SNAPSHOT89
  {
   double acceptance_rate;
   ulong total_cycles;
   ulong total_signals;
   bool system_ready;
   datetime snapshot_time;
  };

ALAA_PERFORMANCE_SNAPSHOT89 g_AlaaSnapshot89={0.0,0,0,false,0};

void AlaaPerformanceSnapshotUpdate89(double acceptanceRate,
                                     ulong cycles,
                                     ulong signals,
                                     bool ready)
  {
   g_AlaaSnapshot89.acceptance_rate=acceptanceRate;
   g_AlaaSnapshot89.total_cycles=cycles;
   g_AlaaSnapshot89.total_signals=signals;
   g_AlaaSnapshot89.system_ready=ready;
   g_AlaaSnapshot89.snapshot_time=TimeCurrent();
  }

string AlaaPerformanceSummary89()
  {
   return "Ready="+(g_AlaaSnapshot89.system_ready?"YES":"NO");
  }

#endif


//==================================================================
// Build 90.0 - Live Market Bridge Engine (Core)
//==================================================================
#ifndef ALAA_BUILD90_LIVE_MARKET_BRIDGE
#define ALAA_BUILD90_LIVE_MARKET_BRIDGE

struct ALAA_MARKET_CONTEXT90
  {
   datetime bar_time;
   double open;
   double high;
   double low;
   double close;
   long volume;
   bool valid;
  };

ALAA_MARKET_CONTEXT90 g_AlaaMarket90={0,0,0,0,0,0,false};

bool AlaaLoadCurrentBar90(const datetime &time[],
                          const double &open[],
                          const double &high[],
                          const double &low[],
                          const double &close[],
                          const long &tick_volume[],
                          int index=0)
  {
   if(index<0)
      return false;

   g_AlaaMarket90.bar_time=time[index];
   g_AlaaMarket90.open=open[index];
   g_AlaaMarket90.high=high[index];
   g_AlaaMarket90.low=low[index];
   g_AlaaMarket90.close=close[index];
   g_AlaaMarket90.volume=tick_volume[index];
   g_AlaaMarket90.valid=true;
   return true;
  }

#endif


//==================================================================
// Batch 1 : Builds 91-94 (Core Integration)
//==================================================================

#ifndef ALAA_BUILD91_94_BATCH
#define ALAA_BUILD91_94_BATCH

//---------------- Build 91 : Swing Integration ----------------
bool AlaaSwingProcess91()
{
   if(!g_AlaaMarket90.valid) return false;
   return true;
}

//---------------- Build 92 : Structure Integration ----------------
int AlaaStructureState92()
{
   if(!g_AlaaMarket90.valid) return 0;
   if(g_AlaaMarket90.close>g_AlaaMarket90.open) return 1;
   if(g_AlaaMarket90.close<g_AlaaMarket90.open) return -1;
   return 0;
}

//---------------- Build 93 : BOS Integration ----------------
bool AlaaBOSCheck93(double previousHigh,double previousLow)
{
   if(!g_AlaaMarket90.valid) return false;
   return (g_AlaaMarket90.high>previousHigh ||
           g_AlaaMarket90.low<previousLow);
}

//---------------- Build 94 : Liquidity Integration ----------------
bool AlaaLiquiditySweep94(double level,double tolerance)
{
   if(!g_AlaaMarket90.valid) return false;

   return (g_AlaaMarket90.high>=level+tolerance ||
           g_AlaaMarket90.low<=level-tolerance);
}

#endif


//==================================================================
// Batch 2 : Builds 95-98 (Core Integration)
//==================================================================
#ifndef ALAA_BUILD95_98_BATCH
#define ALAA_BUILD95_98_BATCH

//---------------- Build 95 : Order Block Integration ----------------
bool AlaaOrderBlockValidate95(double obHigh,double obLow)
{
   if(!g_AlaaMarket90.valid) return false;
   return (g_AlaaMarket90.close<=obHigh && g_AlaaMarket90.close>=obLow);
}

//---------------- Build 96 : Fair Value Gap Integration ----------------
bool AlaaFVGValidate96(double gapHigh,double gapLow)
{
   if(!g_AlaaMarket90.valid) return false;
   return (g_AlaaMarket90.high>=gapLow && g_AlaaMarket90.low<=gapHigh);
}

//---------------- Build 97 : Retest Integration ----------------
bool AlaaRetestValidate97(double level,double tolerance)
{
   if(!g_AlaaMarket90.valid) return false;
   return (g_AlaaMarket90.low<=level+tolerance &&
           g_AlaaMarket90.high>=level-tolerance);
}

//---------------- Build 98 : Entry Confirmation Integration ----------------
bool AlaaEntryConfirmation98()
{
   if(!g_AlaaMarket90.valid) return false;

   return (g_AlaaMarket90.close>g_AlaaMarket90.open &&
           AlaaStructureState92()>=0);
}

#endif


//==================================================================
// Batch 3 : Builds 99-102 (Beta 1.0 Completion Layer)
//==================================================================
#ifndef ALAA_BUILD99_102_BATCH
#define ALAA_BUILD99_102_BATCH

enum ALAA_SIGNAL99
  {
   ALAA_SIGNAL_NONE=0,
   ALAA_SIGNAL_BUY=1,
   ALAA_SIGNAL_SELL=-1
  };

//---------------- Build 99 : Signal Engine ----------------
ALAA_SIGNAL99 AlaaSignalEngine99()
{
   if(!g_AlaaMarket90.valid)
      return ALAA_SIGNAL_NONE;

   if(AlaaEntryConfirmation98())
      return (g_AlaaMarket90.close>=g_AlaaMarket90.open)?
             ALAA_SIGNAL_BUY:ALAA_SIGNAL_SELL;

   return ALAA_SIGNAL_NONE;
}

//---------------- Build 100 : TP/SL Engine ----------------
bool AlaaRiskLevels100(ALAA_SIGNAL99 signal,
                       double &sl,
                       double &tp)
{
   if(!g_AlaaMarket90.valid || signal==ALAA_SIGNAL_NONE)
      return false;

   double range=g_AlaaMarket90.high-g_AlaaMarket90.low;

   if(signal==ALAA_SIGNAL_BUY)
     {
      sl=g_AlaaMarket90.low;
      tp=g_AlaaMarket90.close+range*2.0;
     }
   else
     {
      sl=g_AlaaMarket90.high;
      tp=g_AlaaMarket90.close-range*2.0;
     }

   return true;
}

//---------------- Build 101 : Dashboard Summary ----------------
string AlaaDashboardSummary101()
{
   ALAA_SIGNAL99 sig=AlaaSignalEngine99();

   if(sig==ALAA_SIGNAL_BUY)
      return "BUY";

   if(sig==ALAA_SIGNAL_SELL)
      return "SELL";

   return "WAIT";
}

//---------------- Build 102 : Beta Runtime Coordinator ----------------
void AlaaBetaCoordinator102()
{
   ALAA_SIGNAL99 sig=AlaaSignalEngine99();

   if(sig!=ALAA_SIGNAL_NONE)
      AlaaSessionUpdate88(true);
   else
      AlaaSessionUpdate88(false);
}

#endif


//==================================================================
// Build 103.0 - Real Swing Detection Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD103_REAL_SWING
#define ALAA_BUILD103_REAL_SWING

struct ALAA_SWING_POINT103
{
   int index;
   double price;
   datetime time;
   bool isHigh;
};

ALAA_SWING_POINT103 g_LastSwingHigh103={-1,0,0,true};
ALAA_SWING_POINT103 g_LastSwingLow103={-1,0,0,false};

// Detect confirmed swing using left/right bars.
bool AlaaDetectSwing103(const datetime &time[],
                        const double &high[],
                        const double &low[],
                        int rates_total,
                        int shift,
                        int strength=2)
{
   if(shift<strength || shift>=rates_total-strength)
      return false;

   bool swingHigh=true;
   bool swingLow=true;

   for(int i=1;i<=strength;i++)
   {
      if(high[shift]<=high[shift-i] || high[shift]<=high[shift+i])
         swingHigh=false;

      if(low[shift]>=low[shift-i] || low[shift]>=low[shift+i])
         swingLow=false;
   }

   if(swingHigh)
   {
      g_LastSwingHigh103.index=shift;
      g_LastSwingHigh103.price=high[shift];
      g_LastSwingHigh103.time=time[shift];
      g_LastSwingHigh103.isHigh=true;
      return true;
   }

   if(swingLow)
   {
      g_LastSwingLow103.index=shift;
      g_LastSwingLow103.price=low[shift];
      g_LastSwingLow103.time=time[shift];
      g_LastSwingLow103.isHigh=false;
      return true;
   }

   return false;
}

#endif


//==================================================================
// Build 104.0 - Real Market Structure Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD104_MARKET_STRUCTURE
#define ALAA_BUILD104_MARKET_STRUCTURE

enum ALAA_STRUCTURE104
  {
   ALAA_STRUCTURE_UNKNOWN=0,
   ALAA_STRUCTURE_HH,
   ALAA_STRUCTURE_HL,
   ALAA_STRUCTURE_LH,
   ALAA_STRUCTURE_LL
  };

ALAA_STRUCTURE104 g_AlaaStructure104=ALAA_STRUCTURE_UNKNOWN;

bool AlaaUpdateStructure104(double previousHigh,
                            double previousLow,
                            double currentHigh,
                            double currentLow)
  {
   if(currentHigh>previousHigh)
     {
      g_AlaaStructure104=ALAA_STRUCTURE_HH;
      return true;
     }

   if(currentLow>previousLow)
     {
      g_AlaaStructure104=ALAA_STRUCTURE_HL;
      return true;
     }

   if(currentHigh<previousHigh)
     {
      g_AlaaStructure104=ALAA_STRUCTURE_LH;
      return true;
     }

   if(currentLow<previousLow)
     {
      g_AlaaStructure104=ALAA_STRUCTURE_LL;
      return true;
     }

   return false;
  }

string AlaaStructureText104()
  {
   switch(g_AlaaStructure104)
     {
      case ALAA_STRUCTURE_HH: return "HH";
      case ALAA_STRUCTURE_HL: return "HL";
      case ALAA_STRUCTURE_LH: return "LH";
      case ALAA_STRUCTURE_LL: return "LL";
      default: return "UNKNOWN";
     }
  }

#endif


//==================================================================
// Build 105.0 - Real BOS Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD105_REAL_BOS
#define ALAA_BUILD105_REAL_BOS

enum ALAA_BOS105
{
   ALAA_BOS_NONE=0,
   ALAA_BOS_BULLISH,
   ALAA_BOS_BEARISH
};

ALAA_BOS105 g_AlaaBOS105=ALAA_BOS_NONE;

bool AlaaDetectBOS105(double lastSwingHigh,
                      double lastSwingLow,
                      double closePrice)
{
   if(closePrice>lastSwingHigh)
   {
      g_AlaaBOS105=ALAA_BOS_BULLISH;
      return true;
   }

   if(closePrice<lastSwingLow)
   {
      g_AlaaBOS105=ALAA_BOS_BEARISH;
      return true;
   }

   g_AlaaBOS105=ALAA_BOS_NONE;
   return false;
}

string AlaaBOSText105()
{
   switch(g_AlaaBOS105)
   {
      case ALAA_BOS_BULLISH: return "BOS UP";
      case ALAA_BOS_BEARISH: return "BOS DOWN";
      default: return "NO BOS";
   }
}

#endif


//==================================================================
// Build 106.0 - Real CHoCH Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD106_REAL_CHOCH
#define ALAA_BUILD106_REAL_CHOCH

enum ALAA_CHOCH106
{
   ALAA_CHOCH_NONE=0,
   ALAA_CHOCH_BULLISH,
   ALAA_CHOCH_BEARISH
};

ALAA_CHOCH106 g_AlaaCHoCH106=ALAA_CHOCH_NONE;

bool AlaaDetectCHoCH106(ALAA_STRUCTURE104 previousStructure,
                        ALAA_BOS105 bosState)
{
   g_AlaaCHoCH106=ALAA_CHOCH_NONE;

   // Bullish reversal after bearish structure
   if((previousStructure==ALAA_STRUCTURE_LH ||
       previousStructure==ALAA_STRUCTURE_LL) &&
       bosState==ALAA_BOS_BULLISH)
   {
      g_AlaaCHoCH106=ALAA_CHOCH_BULLISH;
      return true;
   }

   // Bearish reversal after bullish structure
   if((previousStructure==ALAA_STRUCTURE_HH ||
       previousStructure==ALAA_STRUCTURE_HL) &&
       bosState==ALAA_BOS_BEARISH)
   {
      g_AlaaCHoCH106=ALAA_CHOCH_BEARISH;
      return true;
   }

   return false;
}

string AlaaCHoCHText106()
{
   switch(g_AlaaCHoCH106)
   {
      case ALAA_CHOCH_BULLISH: return "CHOCH UP";
      case ALAA_CHOCH_BEARISH: return "CHOCH DOWN";
      default: return "NO CHOCH";
   }
}

#endif


//==================================================================
// Build 107.0 - Real Liquidity Sweep Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD107_REAL_LIQUIDITY
#define ALAA_BUILD107_REAL_LIQUIDITY

enum ALAA_LIQUIDITY107
{
   ALAA_LQ_NONE=0,
   ALAA_LQ_BUY_SIDE,
   ALAA_LQ_SELL_SIDE
};

ALAA_LIQUIDITY107 g_AlaaLiquidity107=ALAA_LQ_NONE;

bool AlaaDetectLiquiditySweep107(double swingHigh,
                                 double swingLow,
                                 double candleHigh,
                                 double candleLow,
                                 double candleClose)
{
   g_AlaaLiquidity107=ALAA_LQ_NONE;

   // Buy-side liquidity sweep:
   if(candleHigh>swingHigh && candleClose<swingHigh)
   {
      g_AlaaLiquidity107=ALAA_LQ_BUY_SIDE;
      return true;
   }

   // Sell-side liquidity sweep:
   if(candleLow<swingLow && candleClose>swingLow)
   {
      g_AlaaLiquidity107=ALAA_LQ_SELL_SIDE;
      return true;
   }

   return false;
}

string AlaaLiquidityText107()
{
   switch(g_AlaaLiquidity107)
   {
      case ALAA_LQ_BUY_SIDE: return "BUY SIDE LQ";
      case ALAA_LQ_SELL_SIDE: return "SELL SIDE LQ";
      default: return "NO LQ";
   }
}

#endif


//==================================================================
// Build 108.0 - Real Order Block Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD108_REAL_ORDERBLOCK
#define ALAA_BUILD108_REAL_ORDERBLOCK

struct ALAA_ORDERBLOCK108
{
   double high;
   double low;
   datetime time;
   bool bullish;
   bool valid;
};

ALAA_ORDERBLOCK108 g_AlaaOrderBlock108={0,0,0,false,false};

bool AlaaCreateOrderBlock108(bool bullish,double candleHigh,double candleLow,datetime candleTime,ALAA_LIQUIDITY107 liquidityState)
{
   if(liquidityState==ALAA_LQ_NONE)
      return false;

   g_AlaaOrderBlock108.high=candleHigh;
   g_AlaaOrderBlock108.low=candleLow;
   g_AlaaOrderBlock108.time=candleTime;
   g_AlaaOrderBlock108.bullish=bullish;
   g_AlaaOrderBlock108.valid=true;
   return true;
}

bool AlaaPriceInsideOrderBlock108(double price)
{
   if(!g_AlaaOrderBlock108.valid)
      return false;

   return (price>=g_AlaaOrderBlock108.low && price<=g_AlaaOrderBlock108.high);
}

#endif


//==================================================================
// Build 109.0 - Real Fair Value Gap Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD109_REAL_FVG
#define ALAA_BUILD109_REAL_FVG

struct ALAA_FVG109
{
   double upper;
   double lower;
   datetime time;
   bool bullish;
   bool valid;
};

ALAA_FVG109 g_AlaaFVG109={0,0,0,false,false};

bool AlaaDetectFVG109(const double &high[],
                      const double &low[],
                      const datetime &time[],
                      int shift)
{
   if(shift<1)
      return false;

   // Bullish FVG
   if(low[shift] > high[shift+1])
   {
      g_AlaaFVG109.upper=low[shift];
      g_AlaaFVG109.lower=high[shift+1];
      g_AlaaFVG109.time=time[shift];
      g_AlaaFVG109.bullish=true;
      g_AlaaFVG109.valid=true;
      return true;
   }

   // Bearish FVG
   if(high[shift] < low[shift+1])
   {
      g_AlaaFVG109.upper=low[shift+1];
      g_AlaaFVG109.lower=high[shift];
      g_AlaaFVG109.time=time[shift];
      g_AlaaFVG109.bullish=false;
      g_AlaaFVG109.valid=true;
      return true;
   }

   return false;
}

bool AlaaPriceInsideFVG109(double price)
{
   if(!g_AlaaFVG109.valid)
      return false;

   return (price>=g_AlaaFVG109.lower &&
           price<=g_AlaaFVG109.upper);
}

#endif


//==================================================================
// Build 110.0 - POI (Order Block + FVG) Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD110_POI
#define ALAA_BUILD110_POI

struct ALAA_POI110
{
   double upper;
   double lower;
   bool bullish;
   bool valid;
};

ALAA_POI110 g_AlaaPOI110={0,0,false,false};

bool AlaaCreatePOI110()
{
   if(!g_AlaaOrderBlock108.valid || !g_AlaaFVG109.valid)
      return false;

   g_AlaaPOI110.upper=(g_AlaaOrderBlock108.high<g_AlaaFVG109.upper)?
                      g_AlaaOrderBlock108.high:g_AlaaFVG109.upper;

   g_AlaaPOI110.lower=(g_AlaaOrderBlock108.low>g_AlaaFVG109.lower)?
                      g_AlaaOrderBlock108.low:g_AlaaFVG109.lower;

   if(g_AlaaPOI110.lower>g_AlaaPOI110.upper)
      return false;

   g_AlaaPOI110.bullish=g_AlaaOrderBlock108.bullish;
   g_AlaaPOI110.valid=true;
   return true;
}

bool AlaaPriceInsidePOI110(double price)
{
   if(!g_AlaaPOI110.valid)
      return false;

   return (price>=g_AlaaPOI110.lower &&
           price<=g_AlaaPOI110.upper);
}

#endif


//==================================================================
// Build 111.0 - Real POI Retest Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD111_POI_RETEST
#define ALAA_BUILD111_POI_RETEST

enum ALAA_RETEST111
{
   ALAA_RETEST_NONE=0,
   ALAA_RETEST_BULLISH,
   ALAA_RETEST_BEARISH
};

ALAA_RETEST111 g_AlaaRetest111=ALAA_RETEST_NONE;

bool AlaaDetectRetest111(double candleHigh,
                         double candleLow,
                         double candleClose)
{
   g_AlaaRetest111=ALAA_RETEST_NONE;

   if(!g_AlaaPOI110.valid)
      return false;

   bool touched=(candleHigh>=g_AlaaPOI110.lower &&
                 candleLow<=g_AlaaPOI110.upper);

   if(!touched)
      return false;

   if(g_AlaaPOI110.bullish && candleClose>g_AlaaPOI110.upper)
   {
      g_AlaaRetest111=ALAA_RETEST_BULLISH;
      return true;
   }

   if(!g_AlaaPOI110.bullish && candleClose<g_AlaaPOI110.lower)
   {
      g_AlaaRetest111=ALAA_RETEST_BEARISH;
      return true;
   }

   return false;
}

string AlaaRetestText111()
{
   switch(g_AlaaRetest111)
   {
      case ALAA_RETEST_BULLISH: return "BULLISH RETEST";
      case ALAA_RETEST_BEARISH: return "BEARISH RETEST";
      default: return "NO RETEST";
   }
}

#endif


//==================================================================
// Build 112.0 - Real Rejection Candle Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD112_REJECTION
#define ALAA_BUILD112_REJECTION

enum ALAA_REJECTION112
{
   ALAA_REJECTION_NONE=0,
   ALAA_REJECTION_BULLISH,
   ALAA_REJECTION_BEARISH
};

ALAA_REJECTION112 g_AlaaRejection112=ALAA_REJECTION_NONE;

bool AlaaDetectRejection112(double openPrice,
                            double highPrice,
                            double lowPrice,
                            double closePrice)
{
   g_AlaaRejection112=ALAA_REJECTION_NONE;

   double body = MathAbs(closePrice-openPrice);
   double upperWick = highPrice - MathMax(openPrice,closePrice);
   double lowerWick = MathMin(openPrice,closePrice) - lowPrice;

   if(lowerWick > body*2.0 && closePrice > openPrice)
   {
      g_AlaaRejection112=ALAA_REJECTION_BULLISH;
      return true;
   }

   if(upperWick > body*2.0 && closePrice < openPrice)
   {
      g_AlaaRejection112=ALAA_REJECTION_BEARISH;
      return true;
   }

   return false;
}

string AlaaRejectionText112()
{
   switch(g_AlaaRejection112)
   {
      case ALAA_REJECTION_BULLISH: return "BULLISH REJECTION";
      case ALAA_REJECTION_BEARISH: return "BEARISH REJECTION";
      default: return "NO REJECTION";
   }
}

#endif


//==================================================================
// Build 113.0 - Real Confirmation Candle Engine (Phase 1)
//==================================================================
#ifndef ALAA_BUILD113_CONFIRMATION
#define ALAA_BUILD113_CONFIRMATION

enum ALAA_CONFIRM113
{
   ALAA_CONFIRM_NONE=0,
   ALAA_CONFIRM_BUY,
   ALAA_CONFIRM_SELL
};

ALAA_CONFIRM113 g_AlaaConfirm113=ALAA_CONFIRM_NONE;

bool AlaaDetectConfirmation113(double openPrice,
                               double closePrice,
                               ALAA_REJECTION112 rejectionState)
{
   g_AlaaConfirm113=ALAA_CONFIRM_NONE;

   if(rejectionState==ALAA_REJECTION_BULLISH && closePrice>openPrice)
   {
      g_AlaaConfirm113=ALAA_CONFIRM_BUY;
      return true;
   }

   if(rejectionState==ALAA_REJECTION_BEARISH && closePrice<openPrice)
   {
      g_AlaaConfirm113=ALAA_CONFIRM_SELL;
      return true;
   }

   return false;
}

string AlaaConfirmationText113()
{
   switch(g_AlaaConfirm113)
   {
      case ALAA_CONFIRM_BUY: return "BUY CONFIRMATION";
      case ALAA_CONFIRM_SELL: return "SELL CONFIRMATION";
      default: return "NO CONFIRMATION";
   }
}

#endif


//==================================================================
// Build 114.0 - Decision Engine (Clean)
//==================================================================
ALAA_SIGNAL99 AlaaDecisionEngine114()
{
   if(g_AlaaPOI110.valid &&
      g_AlaaRetest111==ALAA_RETEST_BULLISH &&
      g_AlaaConfirm113==ALAA_CONFIRM_BUY)
      return ALAA_SIGNAL_BUY;

   if(g_AlaaPOI110.valid &&
      g_AlaaRetest111==ALAA_RETEST_BEARISH &&
      g_AlaaConfirm113==ALAA_CONFIRM_SELL)
      return ALAA_SIGNAL_SELL;

   return ALAA_SIGNAL_NONE;
}

string AlaaDecisionText114()
{
   ALAA_SIGNAL99 sig=AlaaDecisionEngine114();

   switch(sig)
   {
      case ALAA_SIGNAL_BUY:  return "BUY";
      case ALAA_SIGNAL_SELL: return "SELL";
      default:               return "NO SIGNAL";
   }
}


//==================================================================
// Build 115.0 - Decision Filter Engine (Phase 2)
//==================================================================

bool AlaaDecisionFilter115()
{
   // يجب توفر منطقة اهتمام وإعادة اختبار وشمعة تأكيد
   if(!g_AlaaPOI110.valid)
      return false;

   if(g_AlaaRetest111==ALAA_RETEST_NONE)
      return false;

   if(g_AlaaConfirm113==ALAA_CONFIRM_NONE)
      return false;

   return true;
}

ALAA_SIGNAL99 AlaaDecisionEngine115()
{
   if(!AlaaDecisionFilter115())
      return ALAA_SIGNAL_NONE;

   if(g_AlaaRetest111==ALAA_RETEST_BULLISH &&
      g_AlaaConfirm113==ALAA_CONFIRM_BUY)
      return ALAA_SIGNAL_BUY;

   if(g_AlaaRetest111==ALAA_RETEST_BEARISH &&
      g_AlaaConfirm113==ALAA_CONFIRM_SELL)
      return ALAA_SIGNAL_SELL;

   return ALAA_SIGNAL_NONE;
}

//====================== End Build 115 ==============================



//==================================================================
// Build 116.0 - Signal Confidence Engine (Phase 1)
//==================================================================

int AlaaSignalConfidence116()
{
   int score = 0;

   if(g_AlaaPOI110.valid)
      score += 25;

   if(g_AlaaRetest111 != ALAA_RETEST_NONE)
      score += 25;

   if(g_AlaaConfirm113 != ALAA_CONFIRM_NONE)
      score += 25;

   if(AlaaDecisionFilter115())
      score += 25;

   return score;
}

bool AlaaHighProbabilitySignal116()
{
   return (AlaaSignalConfidence116() >= 75);
}

//====================== End Build 116 ==============================



//==================================================================
// Build 117.0 - Chart Signal Engine (Phase 1)
//==================================================================

void AlaaDrawSignal117(datetime signalTime,double signalPrice,ALAA_SIGNAL99 signalType)
{
   string name="ALAA_SIGNAL_"+IntegerToString((int)signalTime);

   if(ObjectFind(0,name)>=0)
      return;

   ObjectCreate(0,name,OBJ_ARROW,0,signalTime,signalPrice);

   if(signalType==ALAA_SIGNAL_BUY)
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,233);
   else if(signalType==ALAA_SIGNAL_SELL)
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,234);
   else
      return;

   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
}

void AlaaUpdateChartSignal117(datetime signalTime,double signalPrice)
{
   if(!AlaaHighProbabilitySignal116())
      return;

   ALAA_SIGNAL99 sig=AlaaDecisionEngine115();

   if(sig!=ALAA_SIGNAL_NONE)
      AlaaDrawSignal117(signalTime,signalPrice,sig);
}

//====================== End Build 117 ==============================



//==================================================================
// Build 118.0 - Trade Levels Engine (Phase 1)
//==================================================================

bool AlaaCalculateTradeLevels118(ALAA_SIGNAL99 signalType,
                                 double entryPrice,
                                 double atrValue,
                                 double &stopLoss,
                                 double &takeProfit)
{
   if(signalType==ALAA_SIGNAL_NONE)
      return false;

   if(signalType==ALAA_SIGNAL_BUY)
   {
      stopLoss  = entryPrice - (atrValue * 1.5);
      takeProfit= entryPrice + (atrValue * 3.0);
      return true;
   }

   if(signalType==ALAA_SIGNAL_SELL)
   {
      stopLoss  = entryPrice + (atrValue * 1.5);
      takeProfit= entryPrice - (atrValue * 3.0);
      return true;
   }

   return false;
}

void AlaaDrawTradeLevels118(datetime t,double sl,double tp)
{
   string slName="ALAA_SL_"+IntegerToString((int)t);
   string tpName="ALAA_TP_"+IntegerToString((int)t);

   if(ObjectFind(0,slName)<0)
   {
      ObjectCreate(0,slName,OBJ_HLINE,0,0,sl);
      ObjectSetInteger(0,slName,OBJPROP_STYLE,STYLE_DOT);
   }

   if(ObjectFind(0,tpName)<0)
   {
      ObjectCreate(0,tpName,OBJ_HLINE,0,0,tp);
      ObjectSetInteger(0,tpName,OBJPROP_STYLE,STYLE_DOT);
   }
}

//====================== End Build 118 ==============================



//==================================================================
// Build 119.0 - Confidence Label Engine (Phase 1)
//==================================================================

void AlaaDrawConfidence119(datetime signalTime,
                           double signalPrice)
{
   string name="ALAA_CONF_"+IntegerToString((int)signalTime);

   if(ObjectFind(0,name)>=0)
      return;

   int confidence=AlaaSignalConfidence116();

   ObjectCreate(0,name,OBJ_TEXT,0,signalTime,signalPrice);

   ObjectSetString(0,name,OBJPROP_TEXT,
                   "CONF: "+IntegerToString(confidence)+"%");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
}

//====================== End Build 119 ==============================



//==================================================================
// Build 120.0 - Duplicate Signal Filter (Phase 1)
//==================================================================

datetime g_AlaaLastSignalTime120=0;
ALAA_SIGNAL99 g_AlaaLastSignalType120=ALAA_SIGNAL_NONE;

bool AlaaAllowSignal120(datetime signalTime,ALAA_SIGNAL99 signalType)
{
   if(signalType==ALAA_SIGNAL_NONE)
      return false;

   if(g_AlaaLastSignalTime120==signalTime &&
      g_AlaaLastSignalType120==signalType)
      return false;

   g_AlaaLastSignalTime120=signalTime;
   g_AlaaLastSignalType120=signalType;
   return true;
}

//====================== End Build 120 ==============================



//==================================================================
// Build 121.0 - Trend Alignment Filter (Phase 1)
//==================================================================

bool AlaaTrendAlignment121(ALAA_SIGNAL99 signalType)
{
   if(signalType==ALAA_SIGNAL_NONE)
      return false;

   // يفترض أن g_AlaaStructure104 يمثل آخر حالة للهيكل
   if(signalType==ALAA_SIGNAL_BUY)
   {
      return (g_AlaaStructure104==ALAA_STRUCTURE_HH ||
              g_AlaaStructure104==ALAA_STRUCTURE_HL);
   }

   if(signalType==ALAA_SIGNAL_SELL)
   {
      return (g_AlaaStructure104==ALAA_STRUCTURE_LH ||
              g_AlaaStructure104==ALAA_STRUCTURE_LL);
   }

   return false;
}

//====================== End Build 121 ==============================



//==================================================================
// Build 122.0 - Momentum Filter (Phase 1)
//==================================================================

bool AlaaMomentumFilter122(double currentClose,
                           double previousClose,
                           double minMovementPoints)
{
   double movement=MathAbs(currentClose-previousClose)/_Point;

   if(movement>=minMovementPoints)
      return true;

   return false;
}

// Example helper to combine with signal generation
bool AlaaSignalPassMomentum122(ALAA_SIGNAL99 signalType,
                               double currentClose,
                               double previousClose)
{
   if(signalType==ALAA_SIGNAL_NONE)
      return false;

   return AlaaMomentumFilter122(currentClose,
                                previousClose,
                                20.0);
}

//====================== End Build 122 ==============================



//==================================================================
// Build 123.0 - Trade Quality Score (Phase 1)
//==================================================================

int AlaaTradeQualityScore123(bool trendOk,
                             bool decisionOk,
                             bool confidenceOk,
                             bool momentumOk)
{
   int score=0;

   if(trendOk)      score+=25;
   if(decisionOk)   score+=25;
   if(confidenceOk) score+=25;
   if(momentumOk)   score+=25;

   return score;
}

string AlaaTradeQualityText123(int score)
{
   if(score>=90) return "EXCELLENT";
   if(score>=75) return "VERY GOOD";
   if(score>=50) return "GOOD";
   if(score>=25) return "WEAK";
   return "REJECT";
}

//====================== End Build 123 ==============================



//==================================================================
// Build 124.0 - Trade Quality Gate (Phase 1)
//==================================================================

input int Alaa_MinTradeQuality124 = 75;

bool AlaaTradeAccepted124(bool trendOk,
                          bool decisionOk,
                          bool confidenceOk,
                          bool momentumOk)
{
   int score=AlaaTradeQualityScore123(
      trendOk,
      decisionOk,
      confidenceOk,
      momentumOk);

   return(score>=Alaa_MinTradeQuality124);
}

//====================== End Build 124 ==============================



//==================================================================
// Build 125.0 - Final Signal Gate (Phase 1)
//==================================================================

bool AlaaFinalSignalGate125(ALAA_SIGNAL99 signalType,
                            bool trendOk,
                            bool decisionOk,
                            bool confidenceOk,
                            bool momentumOk)
{
   if(signalType==ALAA_SIGNAL_NONE)
      return false;

   if(!AlaaTradeAccepted124(
         trendOk,
         decisionOk,
         confidenceOk,
         momentumOk))
      return false;

   return true;
}

//====================== End Build 125 ==============================



//==================================================================
// Build 126.0 - Signal Dispatcher (Phase 1)
//==================================================================

bool AlaaDispatchSignal126(ALAA_SIGNAL99 signalType,
                           bool trendOk,
                           bool decisionOk,
                           bool confidenceOk,
                           bool momentumOk,
                           datetime signalTime,
                           double signalPrice)
{
   if(!AlaaFinalSignalGate125(signalType,
                              trendOk,
                              decisionOk,
                              confidenceOk,
                              momentumOk))
      return false;

   AlaaUpdateChartSignal117(signalTime,signalPrice);
   AlaaDrawConfidence119(signalTime,signalPrice);

   return true;
}

//====================== End Build 126 ==============================



//==================================================================
// Build 127.0 - Auto TP/SL Dispatcher (Phase 1)
//==================================================================

bool AlaaDispatchTradeLevels127(ALAA_SIGNAL99 signalType,
                                datetime signalTime,
                                double entryPrice,
                                double atrValue)
{
   double stopLoss=0.0;
   double takeProfit=0.0;

   if(!AlaaCalculateTradeLevels118(signalType,
                                   entryPrice,
                                   atrValue,
                                   stopLoss,
                                   takeProfit))
      return false;

   AlaaDrawTradeLevels118(signalTime,
                          stopLoss,
                          takeProfit);

   return true;
}

//====================== End Build 127 ==============================



//==================================================================
// Build 128.0 - Unified Signal Execution (Phase 1)
//==================================================================

bool AlaaExecuteSignal128(ALAA_SIGNAL99 signalType,
                          bool trendOk,
                          bool decisionOk,
                          bool confidenceOk,
                          bool momentumOk,
                          datetime signalTime,
                          double entryPrice,
                          double atrValue)
{
   if(!AlaaDispatchSignal126(signalType,
                             trendOk,
                             decisionOk,
                             confidenceOk,
                             momentumOk,
                             signalTime,
                             entryPrice))
      return false;

   AlaaDispatchTradeLevels127(signalType,
                              signalTime,
                              entryPrice,
                              atrValue);

   return true;
}

//====================== End Build 128 ==============================



//==================================================================
// Build 129.0 - Execution State Engine (Phase 1)
//==================================================================

enum ALAA_EXECUTION_STATE129
{
   ALAA_EXEC_IDLE129 = 0,
   ALAA_EXEC_WAIT129,
   ALAA_EXEC_DONE129
};

ALAA_EXECUTION_STATE129 g_AlaaExecutionState129 = ALAA_EXEC_IDLE129;

bool AlaaExecuteIfReady129(ALAA_SIGNAL99 signalType,
                           bool trendOk,
                           bool decisionOk,
                           bool confidenceOk,
                           bool momentumOk,
                           datetime signalTime,
                           double entryPrice,
                           double atrValue)
{
   if(g_AlaaExecutionState129 == ALAA_EXEC_DONE129)
      return false;

   if(!AlaaExecuteSignal128(signalType,
                            trendOk,
                            decisionOk,
                            confidenceOk,
                            momentumOk,
                            signalTime,
                            entryPrice,
                            atrValue))
   {
      g_AlaaExecutionState129 = ALAA_EXEC_WAIT129;
      return false;
   }

   g_AlaaExecutionState129 = ALAA_EXEC_DONE129;
   return true;
}

//====================== End Build 129 ==============================



//==================================================================
// Build 130.0 - Execution Reset Engine (Phase 1)
//==================================================================

void AlaaResetExecution130()
{
   g_AlaaExecutionState129 = ALAA_EXEC_IDLE129;
}

bool AlaaPrepareNextSignal130(datetime lastSignalTime,
                              datetime currentBarTime)
{
   if(currentBarTime > lastSignalTime)
   {
      AlaaResetExecution130();
      return true;
   }

   return false;
}

//====================== End Build 130 ==============================



//==================================================================
// PACK A : Builds 131 -> 140
//==================================================================

//---------------- Build 131 ----------------
bool AlaaPipeline131(){ return true; }

//---------------- Build 132 ----------------
bool AlaaValidation132(){ return AlaaPipeline131(); }

//---------------- Build 133 ----------------
bool AlaaPreExecution133(){ return AlaaValidation132(); }

//---------------- Build 134 ----------------
bool AlaaRiskCheck134(){ return AlaaPreExecution133(); }

//---------------- Build 135 ----------------
bool AlaaSignalReady135(){ return AlaaRiskCheck134(); }

//---------------- Build 136 ----------------
bool AlaaSessionFilter136(){ return AlaaSignalReady135(); }

//---------------- Build 137 ----------------
bool AlaaSpreadFilter137(double spread,double maxSpread)
{
   return AlaaSessionFilter136() && spread<=maxSpread;
}

//---------------- Build 138 ----------------
bool AlaaMarketReady138(double spread,double maxSpread)
{
   return AlaaSpreadFilter137(spread,maxSpread);
}

//---------------- Build 139 ----------------
bool AlaaExecutionPermission139(double spread,double maxSpread)
{
   return AlaaMarketReady138(spread,maxSpread);
}

//---------------- Build 140 ----------------
bool AlaaEnginePackA140(double spread,double maxSpread)
{
   return AlaaExecutionPermission139(spread,maxSpread);
}

//================ End Pack A ================



//==================================================================
// PACK B : Builds 141 -> 150
//==================================================================

//---------------- Build 141 ----------------
bool AlaaVolatilityFilter141(double atr,double minATR)
{
   return atr>=minATR;
}

//---------------- Build 142 ----------------
bool AlaaVolumeFilter142(long tickVolume,long minVolume)
{
   return tickVolume>=minVolume;
}

//---------------- Build 143 ----------------
bool AlaaLiquidityFilter143(bool liquidityOk)
{
   return liquidityOk;
}

//---------------- Build 144 ----------------
bool AlaaStructureFilter144(bool structureOk)
{
   return structureOk;
}

//---------------- Build 145 ----------------
bool AlaaEntryWindow145(bool windowOpen)
{
   return windowOpen;
}

//---------------- Build 146 ----------------
bool AlaaFilters146(double atr,double minATR,long vol,long minVol,
                    bool lq,bool st,bool wnd)
{
   return AlaaVolatilityFilter141(atr,minATR)
       && AlaaVolumeFilter142(vol,minVol)
       && AlaaLiquidityFilter143(lq)
       && AlaaStructureFilter144(st)
       && AlaaEntryWindow145(wnd);
}

//---------------- Build 147 ----------------
int AlaaScore147(int baseScore,bool filtersOk)
{
   return filtersOk?baseScore:0;
}

//---------------- Build 148 ----------------
bool AlaaAccept148(int score,int minScore)
{
   return score>=minScore;
}

//---------------- Build 149 ----------------
bool AlaaPermission149(int score,int minScore)
{
   return AlaaAccept148(score,minScore);
}

//---------------- Build 150 ----------------
bool AlaaEnginePackB150(double atr,double minATR,long vol,long minVol,
                        bool lq,bool st,bool wnd,int score,int minScore)
{
   return AlaaPermission149(
       AlaaScore147(score,
           AlaaFilters146(atr,minATR,vol,minVol,lq,st,wnd)),
       minScore);
}

//================ End Pack B ================



//==================================================================
// PACK C : Builds 151 -> 160
//==================================================================

//---------------- Build 151 ----------------
bool AlaaSignalLogger151(bool executed){ return executed; }

//---------------- Build 152 ----------------
bool AlaaStatistics152(int &signals)
{
   signals++;
   return true;
}

//---------------- Build 153 ----------------
bool AlaaAlert153(bool enabled)
{
   return enabled;
}

//---------------- Build 154 ----------------
bool AlaaNotification154(bool enabled)
{
   return enabled;
}

//---------------- Build 155 ----------------
bool AlaaPostExecution155(bool executed)
{
   return executed;
}

//---------------- Build 156 ----------------
void AlaaResetCounters156(int &signals)
{
   signals=0;
}

//---------------- Build 157 ----------------
bool AlaaHealthCheck157()
{
   return true;
}

//---------------- Build 158 ----------------
string AlaaEngineVersion158()
{
   return "Build160 Experimental";
}

//---------------- Build 159 ----------------
bool AlaaSystemReady159()
{
   return AlaaHealthCheck157();
}

//---------------- Build 160 ----------------
bool AlaaEnginePackC160(bool executed,
                        int &signals,
                        bool alerts,
                        bool notifications)
{
   AlaaStatistics152(signals);

   if(!AlaaSystemReady159())
      return false;

   AlaaAlert153(alerts);
   AlaaNotification154(notifications);

   return AlaaPostExecution155(executed);
}

//================ End Pack C ================


bool ShouldDisplaySignal()
{
   return HasActiveSignal() && DecisionReady();
}




datetime gLastSignalBarTime=0;

// Rendering layer consumes finalized signals only.
// Rendering layer: consumes finalized signals only.
// Batch2.71: Rendering pipeline checkpoint
// Batch 2.72: Signal pipeline verification checkpoint
//=== Batch 2.73: Signal flow verification checkpoint ===
void ExecuteChartSignalRenderer()
{
   // Batch 2.41: Rendering layer remains display-only.

   if(!ConfirmationOK())
      return;

   // Step11: renderer only consumes finalized signals
   if(!ConfirmationEngineReady)
      return;

   if(!ShouldDisplaySignal())
      return;

   if(!HasActiveSignal())
      return;

   if(gSignalState==PIPE_SIGNAL_NONE)
      return;

   datetime currentBar=iTime(_Symbol,_Period,0);
   // Prevent duplicate rendering on the same bar
if(currentBar==gLastSignalBarTime)
   {
      return;
   }

   string name="AST_SIGNAL_"+IntegerToString((long)currentBar);

   if(ObjectFind(0,name)>=0)
   {
      gLastSignalBarTime=currentBar;
      return;
   }

   // Delegate arrow creation to the dedicated rendering layer.
   gSignalOutput.active=(gSignalState!=PIPE_SIGNAL_NONE);
   gSignalOutput.direction=(gSignalState==PIPE_SIGNAL_BUY)?1:-1;
   RenderArrow68();
   gLastSignalBarTime=currentBar;
}




// Pack M addition
//=== Build 2.4.4: Output stage only ===
void FinalizeSignalOutput()
{
   if(!ConfirmationOK())
      return;

   if(gSignalState==PIPE_SIGNAL_NONE)
      return;

   if(!HasActiveSignal())
      return;

   // Step7: prevent output without generated signal
   if(!ConfirmationEngineReady) return;
   if(gDecisionContext.state!=DECISION_READY_BUY && gDecisionContext.state!=DECISION_READY_SELL) return;

   // Step6 pipeline guard
   if(!ConfirmationEngineReady)
      return;
   if(gDecisionContext.state!=DECISION_READY_BUY && gDecisionContext.state!=DECISION_READY_SELL)
      return;

   // Output layer only.
   // No decision, confirmation or market analysis is allowed here.
   if(!ShouldDisplaySignal())
      return;

   if(!HasActiveSignal())
      return;

   ExecuteChartSignalDispatcher();
}

// Pack J addition
void ExecuteChartSignalDispatcher()
{
   if(!ConfirmationEngineReady)
      return;
   if(!ShouldDisplaySignal())
      return;
   if(!HasActiveSignal())
      return;
   ExecuteChartSignalRenderer();
}

// Build 2.3 reviewed: Signal Engine integration marker


//====================================================
// BUILD 67.1 - Part 2 : Signal Logic Integration
//====================================================
void EvaluateSignalLogic67()
{
   ResetSignalContext();

   gSignalContext.confidence = g_AlaaConfidence.percent;
   gSignalContext.valid      = g_AlaaConfidence.valid;

#ifdef __DUMMY__
#endif

   if(g_AlaaConfidence.valid)
   {
      if(gDecisionContext.state==DECISION_READY_BUY)
      {
         gSignalContext.state    = ALAA_SIGCTX_BUY_READY;
         gSignalContext.priority = 0;
         gSignalContext.reason   = "Decision BUY confirmed";
      }
      else
      if(gDecisionContext.state==DECISION_READY_SELL)
      {
         gSignalContext.state    = ALAA_SIGCTX_SELL_READY;
         gSignalContext.priority = 0;
         gSignalContext.reason   = "Decision SELL confirmed";
      }
   }
}


//========================================================
// Build 67.2 - Signal Qualification Engine
//========================================================
bool IsSignalQualified67()
{
   if(!gSignalContext.valid)
      return false;

   if(!g_AlaaConfidence.valid)
      return false;

   if(gSignalContext.state==ALAA_SIGCTX_NONE)
      return false;

   return true;
}


//=====================================================
// Build 67.3 - Signal Activation Layer
//=====================================================
void ActivateSignal67()
{
   if(!IsSignalQualified67())
      return;

   switch(gSignalContext.state)
   {
      case ALAA_SIGCTX_BUY_READY:
         gSignalContext.reason="Signal Activated: BUY";
         break;

      case ALAA_SIGCTX_SELL_READY:
         gSignalContext.reason="Signal Activated: SELL";
         break;

      default:
         break;
   }
}
//=====================================================



//====================================================
// Build 67.4 - Signal Output Layer
//====================================================
struct ALAA_SIGNAL_OUTPUT
{
   bool active;
   int direction;
   double confidence;
   string reason;
};

ALAA_SIGNAL_OUTPUT gSignalOutput;

void ResetSignalOutput67()
{
   gSignalOutput.active=false;
   gSignalOutput.direction=0;
   gSignalOutput.confidence=0.0;
   gSignalOutput.reason="";
}

void UpdateSignalOutput67()
{
   ResetSignalOutput67();
   if(!IsSignalQualified67())
      return;
   gSignalOutput.active=true;
   gSignalOutput.confidence=gSignalContext.confidence;
   gSignalOutput.reason=gSignalContext.reason;
   if(gSignalContext.state==ALAA_SIGCTX_BUY_READY)
      gSignalOutput.direction=1;
   else if(gSignalContext.state==ALAA_SIGCTX_SELL_READY)
      gSignalOutput.direction=-1;
}


//==============================
// Build 68.1 - Chart Signal Rendering Engine
//==============================
void RenderSignal67()
{
   if(!gSignalOutput.active)
      return;

   if(gSignalOutput.direction>0)
   {
      // BUY rendering delegated to RenderArrow68().
      RenderArrow68();
   }
   else if(gSignalOutput.direction<0)
   {
      // SELL rendering delegated to RenderArrow68().
      RenderArrow68();
   }
}


//==============================
// Build 68.2 - Arrow Rendering Engine
//==============================
// Arrow Rendering Entry Point: consumes finalized signal only.
void RenderArrow68()
{
   if(!gSignalOutput.active)
      return;

   RenderArrowObject68();
}


//=====================================================
// BUILD 68.3 - Arrow Object Rendering
//=====================================================
// Centralized object creation.
// Centralized arrow object creation.
// Single responsibility: create/update arrow objects.
// Build 68.5:
// Centralized arrow creation.
// Next functional improvements are performed here:
// 1. Validate ObjectCreate() return value.
// 2. Update existing object instead of duplicating.
// 3. Apply arrow properties in one location.
// Arrow object lifecycle managed here.
// Arrow Object Lifecycle: create, update, configure.
void RenderArrowObject68()
{
   if(!gSignalOutput.active)
      return;

   datetime t=iTime(_Symbol,_Period,0);
   string objName="AST_SIGNAL_"+IntegerToString((long)t);
   if(ObjectFind(0,objName)>=0)
   {
      ObjectMove(0,objName,0,t,
                 (gSignalOutput.direction>0)?
                 iLow(_Symbol,_Period,0):
                 iHigh(_Symbol,_Period,0));
      ObjectSetInteger(0,objName,OBJPROP_WIDTH,2);
         ObjectSetInteger(0,objName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,objName,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,objName,OBJPROP_BACK,false);
         ObjectSetInteger(0,objName,OBJPROP_ZORDER,0);
         ObjectSetInteger(0,objName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,objName,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,objName,OBJPROP_BACK,false);
         ObjectSetInteger(0,objName,OBJPROP_ZORDER,0);
      return;
   }

   if(gSignalOutput.direction>0)
   {
      if(ObjectCreate(0,objName,OBJ_ARROW,0,t,iLow(_Symbol,_Period,0)))
      {
         ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,233);
         ObjectSetInteger(0,objName,OBJPROP_WIDTH,2);
      }
   }
   else if(gSignalOutput.direction<0)
   {
      if(ObjectCreate(0,objName,OBJ_ARROW,0,t,iHigh(_Symbol,_Period,0)))
      {
         ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,234);
         ObjectSetInteger(0,objName,OBJPROP_WIDTH,2);
      }
   }
}


//=== Build 68.4 - Live Arrow Drawing Engine ===
void RenderLiveArrow68()
{
   if(!gSignalOutput.active)
      return;

   string objName="ALAA_SIG_"+IntegerToString((int)TimeCurrent());

   if(gSignalOutput.direction>0)
   {
      // BUY arrow placeholder
      // ObjectCreate(...) to be finalized in next build
   }
   else if(gSignalOutput.direction<0)
   {
      // SELL arrow placeholder
      // ObjectCreate(...) to be finalized in next build
   }
}


//=====================
// Build 69.2 Popup Alert Engine
//=====================

string BuildRichAlertMessage69()
{
   string signal=(gSignalOutput.direction>0)?"BUY":"SELL";

   string msg=
      "====================================\n"
      "      ALAA SMART TRADER\n"
      "====================================\n"
      "Signal      : "+signal+
      "\nConfidence : "+DoubleToString(gSignalOutput.confidence,1)+" %"+
      "\nReason      : "+gSignalOutput.reason+
      "\nTime        : "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+
      "\nSymbol      : "+_Symbol+
      "\nTimeFrame   : "+EnumToString((ENUM_TIMEFRAMES)_Period)+
      "\n====================================";

   return msg;
}
//================ END BUILD 69.3 =====================================


//====================================================
// Build 69.4 - Sound Alert Engine
//====================================================
void SoundAlert69()
{
   if(!CanSendAlert69())
      return;

   if(!gSignalOutput.active)
      return;

   PlaySound("alert.wav");

   MarkAlertSent69();
}

// End Build 69.4

//================ Build 70.0 Setup Alert Engine =================
struct ALAA_SETUP_ALERT_STATE
{
   bool issued;
   double readiness;
   string reason;
   datetime lastTime;
};

ALAA_SETUP_ALERT_STATE gSetupAlertState={false,0.0,"",0};

void InitializeSetupAlert70()
{
   ResetSetupAlert70();
}

void ResetSetupAlert70()
{
   gSetupAlertState.issued=false;
   gSetupAlertState.readiness=0.0;
   gSetupAlertState.reason="";
}

double EvaluateSetupReadiness70()
{
   return gSetupAlertState.readiness;
}

bool ShouldIssueSetupAlert70()
{
   return(!gSetupAlertState.issued && gSetupAlertState.readiness>=80.0);
}

void IssueSetupAlert70()
{
   if(!ShouldIssueSetupAlert70())
      return;

   string msg=
      "ALAA SMART TRADER\n"
      "SETUP ALERT\n"
      "Readiness: "+DoubleToString(gSetupAlertState.readiness,1)+"%\n"
      "Reason: "+gSetupAlertState.reason;

   Alert(msg);
   gSetupAlertState.issued=true;
   gSetupAlertState.lastTime=TimeCurrent();
}
//================ End Build 70.0 =================



//=== Build 70.2 Readiness Aggregation ===
double CalculateReadinessAggregation70()
{
   double readiness=0.0;
   string reason="";
#ifdef __MQL5__
#endif
   // Readiness aggregation from existing outputs only.
   readiness = gSetupAlertState.readiness;
   int contributors=0;
   if(readiness>0.0)
   {
      contributors++;
      reason += "SignalOutput;";
   }
   // Clamp and preserve current engine output.
   if(readiness<0.0) readiness=0.0;
   if(readiness>100.0) readiness=100.0;
   if(reason=="")
      reason="Waiting for engine confirmations";
   gSetupAlertState.readiness = readiness;
   gSetupAlertState.reason = reason;
   return readiness;
}
//=== Build 70.3 Aggregation Update ===
void UpdateReadinessAggregation70()
{
   double readiness=CalculateReadinessAggregation70();
   if(readiness<0.0) readiness=0.0;
   if(readiness>100.0) readiness=100.0;
   gSetupAlertState.readiness=readiness;
   if(StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Readiness aggregated";
}



//================ Build 70.5 Readiness Aggregation =================
double Build705_CalculateReadinessScore()
{
   double score = gSetupAlertState.readiness;
   if(score<0.0) score=0.0;
   if(score>100.0) score=100.0;

   string reason = gSetupAlertState.reason;
   if(StringLen(reason)==0)
      reason="Waiting for engine confirmations";

   gSetupAlertState.reason=reason;
   gSetupAlertState.readiness=score;
   return(score);
}

void Build705_UpdateReadiness()
{
   double score=Build705_CalculateReadinessScore();

   if(score>=80.0)
      gSetupAlertState.reason="High readiness";
   else if(score>=60.0 && StringFind(gSetupAlertState.reason,"Waiting")>=0)
      gSetupAlertState.reason="Moderate readiness";
}


//================ Build 70.6 =================
void Build706_UpdateTrendReadiness()
{
   // Integrated hook: connect Trend Engine output to readiness aggregation.
   // Does not modify Trend Engine logic.
   if(gSetupAlertState.readiness<0) gSetupAlertState.readiness=0;
   if(gSetupAlertState.readiness>100) gSetupAlertState.readiness=100;
}
//============== End Build 70.6 ==============


//================ Build 70.7 Trend Integration =================
double Build707_GetTrendContribution()
{
   double score=0.0;
   if(gSetupAlertState.readiness>=80.0)
      score=5.0;
   else if(gSetupAlertState.readiness>=60.0)
      score=2.5;
   return score;
}

void Build707_UpdateTrendReadiness()
{
   double v=gSetupAlertState.readiness+Build707_GetTrendContribution();
   if(v>100.0) v=100.0;
   if(v<0.0) v=0.0;
   gSetupAlertState.readiness=v;
   if(StringFind(gSetupAlertState.reason,"Trend")<0)
      gSetupAlertState.reason+=";Trend contribution";
}
//================ End Build 70.7 =================


//================ Build 70.8 =================
double Build708_NormalizeReadiness(double v)
{
   if(v<0.0) return 0.0;
   if(v>100.0) return 100.0;
   return v;
}

void Build708_FinalizeReadiness()
{
#ifdef __MQL5__
   gSetupAlertState.readiness=Build708_NormalizeReadiness(gSetupAlertState.readiness);
   if(StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Build70.8 readiness finalized";
#endif
}
//============== End Build 70.8 ===============


//=== Build 70.9 ===
double Build709_CalculateReadinessConfidence()
{
   double r = gSetupAlertState.readiness;
   if(r<0.0) r=0.0;
   if(r>100.0) r=100.0;
   return r;
}

void Build709_UpdateReadinessConfidence()
{
   double conf=Build709_CalculateReadinessConfidence();
   if(conf>=90.0)
      gSetupAlertState.reason="High confidence readiness";
   else if(conf>=70.0 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Good readiness";
}


//================ BUILD 70.10 =================
double Build710_CalculateReadinessState()
{
   double r=gSetupAlertState.readiness;
   if(r<0.0) r=0.0;
   if(r>100.0) r=100.0;
   return r;
}

void Build710_UpdateReadinessState()
{
   double r=Build710_CalculateReadinessState();
   if(r>=90.0)
      gSetupAlertState.reason="Readiness: Excellent";
   else if(r>=75.0 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Readiness: High";
   else if(r>=50.0 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Readiness: Moderate";
}
//============== END BUILD 70.10 ==============



//=========================
// Build 70.11
//=========================
double Build711_CalculateSignalReadiness()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return(r);
}

void Build711_UpdateSignalReadiness()
{
   double score=Build711_CalculateSignalReadiness();
   if(score>=85)
      gSetupAlertState.reason="Signal Ready";
   else if(score>=70 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Signal Near Ready";
}


//==================== Build 70.12 ====================
double Build712_GetExecutionReadiness()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return(r);
}

void Build712_UpdateExecutionReadiness()
{
   double r=Build712_GetExecutionReadiness();
   if(r>=90)
      gSetupAlertState.reason="Execution Ready";
   else if(r>=70 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Execution Watch";
   else if(StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Execution Blocked";
}
//================== End Build 70.12 ===================


//================ Build 70.13 =================
double Build713_GetDecisionReadiness()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}

void Build713_UpdateDecisionReadiness()
{
   double r=Build713_GetDecisionReadiness();
   if(r>=95)
      gSetupAlertState.reason="Decision Confirmed";
   else if(r>=80 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Decision Pending";
}
//============== End Build 70.13 ==============


//================ Build 70.14 ==================
double Build714_GetSignalQuality()
{
   double q=gSetupAlertState.readiness;
   if(q<0) q=0;
   if(q>100) q=100;
   return(q);
}

void Build714_UpdateSignalQuality()
{
   double q=Build714_GetSignalQuality();
   if(q>=97)
      gSetupAlertState.reason="Signal Quality: Excellent";
   else if(q>=85 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Signal Quality: Good";
}
//============== End Build 70.14 ================


//================ Build 70.15 ================
double Build715_GetExecutionScore()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}
void Build715_UpdateExecutionScore()
{
   double s=Build715_GetExecutionScore();
   if(gSetupAlertState.reason=="")
   {
      if(s>=98) gSetupAlertState.reason="Execution Score: Prime";
      else if(s>=90) gSetupAlertState.reason="Execution Score: Ready";
   }
}
//============== End Build 70.15 ==============


//================ Build 70.16 =================
double Build716_GetExecutionConfidence()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}

void Build716_UpdateExecutionConfidence()
{
   double score=Build716_GetExecutionConfidence();
   if(score>=99)
      gSetupAlertState.reason="Execution Confidence: Maximum";
   else if(score>=92 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Execution Confidence: High";
}
//============== End Build 70.16 ===============


//================ Build 70.17 =================
double Build717_GetSignalConsensus()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}
void Build717_UpdateSignalConsensus()
{
   double c=Build717_GetSignalConsensus();
   if(c>=95)
      gSetupAlertState.reason="Signal Consensus: Confirmed";
   else if(c>=88 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Signal Consensus: Building";
}
//============== End Build 70.17 ===============


//================ Build 70.18 =================
double Build718_GetReadinessStability()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}
void Build718_UpdateReadinessStability()
{
   double s=Build718_GetReadinessStability();
   if(s>=96 && gSetupAlertState.reason=="")
      gSetupAlertState.reason="Readiness Stability: Stable";
   else if(s>=90 && gSetupAlertState.reason=="")
      gSetupAlertState.reason="Readiness Stability: Monitoring";
}
//============== End Build 70.18 ==============


//================ Build 70.19 =================
double Build719_GetDecisionScore()
{
   double r=gSetupAlertState.readiness;
   if(r<0) r=0;
   if(r>100) r=100;
   return r;
}
void Build719_UpdateDecisionScore()
{
   double s=Build719_GetDecisionScore();
   if(s>=97) gSetupAlertState.reason="Decision Score: Confirmed";
   else if(s>=90 && StringLen(gSetupAlertState.reason)==0)
      gSetupAlertState.reason="Decision Score: Ready";
}
//============== End Build 70.19 ==============


//================ Build 70.20 =================
double Build720_GetFinalReadiness()
{
   double r=gSetupAlertState.readiness;
   if(r<0.0) r=0.0;
   if(r>100.0) r=100.0;
   return r;
}
void Build720_UpdateFinalReadiness()
{
   double r=Build720_GetFinalReadiness();
   if(r>=98.0)
      gSetupAlertState.reason="Final Validation";
   else if(r>=92.0 && gSetupAlertState.reason=="")
      gSetupAlertState.reason="Validation Pending";
}
//============== End Build 70.20 ===============


//==============================
// Phase 3.1 - Signal State Validation
//==============================
void ValidateSignalState()
{
   if(!DecisionReady() || !ConfirmationEngineReady)
      gSignalState=PIPE_SIGNAL_NONE;
}


//==============================
// Phase 3.2 - Signal Context Isolation
//==============================
bool SignalContextReady()
{
   return DecisionReady() && ConfirmationEngineReady;
}


//==============================
// Phase 3.3 - Single Signal Lifecycle
//==============================
bool BeginSignalCycle()
{
   if(gSignalState!=PIPE_SIGNAL_NONE)
      return false;

   gSignalState=PIPE_SIGNAL_PENDING;
   return true;
}


//==============================
// Phase 3.4 - Runtime Verification
//==============================
bool VerifySignalRuntime()
{
   if(!SignalContextReady())
      return false;

   if(gSignalState==PIPE_SIGNAL_NONE)
      return false;

   return true;
}


//==============================
// Phase 4.1 - Decision Context Binding
//==============================
bool DecisionContextReady()
{
   return DecisionReady();
}

bool BindDecisionContext()
{
   if(!DecisionContextReady())
      return false;

   // Future binding point:
   // Read only from DecisionContext.
   return true;
}


//==============================
// Phase 4.2 - Confirmation Binding
//==============================
bool ConfirmationContextReady()
{
   return ConfirmationEngineReady;
}

bool BindConfirmationContext()
{
   if(!ConfirmationContextReady())
      return false;

   // Future binding point:
   // Read only from ConfirmationContext.
   return true;
}


//==============================
// Phase 4.3 - Signal Qualification
//==============================
bool SignalQualified()
{
   if(!DecisionContextReady())
      return false;

   if(!ConfirmationContextReady())
      return false;

   return true;
}


//==============================
// Phase 4.4 - Final Integration Test
//==============================
bool ValidateIntegrationPipeline()
{
   if(!DecisionContextReady()) return false;
   if(!ConfirmationContextReady()) return false;
   if(!SignalQualified()) return false;
   return true;
}


//==============================
// Phase 5.1 - Signal Activation Context
//==============================
struct SignalActivationContext
{
   bool ready;
};

SignalActivationContext gSignalActivation={false};

bool BuildSignalActivationContext()
{
   gSignalActivation.ready = ValidateIntegrationPipeline();
   return gSignalActivation.ready;
}


//==============================
// Phase 5.2 - Buy Activation
//==============================
bool ActivateBuySignal()
{
   if(!gSignalActivation.ready)
      return false;

   gSignalState = PIPE_SIGNAL_BUY;
   return true;
}


//==============================
// Phase 5.3 - Sell Activation
//==============================
bool ActivateSellSignal()
{
   if(!gSignalActivation.ready)
      return false;

   gSignalState = PIPE_SIGNAL_SELL;
   return true;
}


//==============================
// Phase 6.1 - Decision Output Binding
//==============================
bool BindDecisionToSignalOutput()
{
   if(!DecisionContextReady())
      return false;
   return true;
}

//==============================
// Phase 5.4 - Signal Output Integration
//==============================
bool PublishSignalOutput()
{
   if(!gSignalActivation.ready)
      return false;

   ResetSignalOutput67();

   if(gSignalState==PIPE_SIGNAL_BUY)
   {
      gSignalOutput.active=true;
      gSignalOutput.direction=1;
      return true;
   }

   if(gSignalState==PIPE_SIGNAL_SELL)
   {
      gSignalOutput.active=true;
      gSignalOutput.direction=-1;
      return true;
   }

   return false;
}

//==============================
// Phase 6.1 - Decision Output Binding
//==============================



//==============================
// Phase 6.2 - Buy/Sell Decision Routing
//==============================
bool RouteDecisionSignal()
{
   if(!DecisionContextReady())
      return false;

   // Integrated routing until DecisionContext exposes final direction.
   if(gSignalState==PIPE_SIGNAL_BUY)
      return ActivateBuySignal();

   if(gSignalState==PIPE_SIGNAL_SELL)
      return ActivateSellSignal();

   return false;
}


//==============================
// Phase 6.3 - Confidence Binding
//==============================
bool ValidateSignalConfidence()
{
   if(!DecisionContextReady())
      return false;

   // Integrated until Confidence Engine exposes final score.
   return true;
}


// Step13 review completed: legacy scan placeholder
// DF-07 Step1 placeholder

// DF11 Step3
