# Guam Renewable Integration
# Martin Chang and Ryan Satterlee

# Parameters to set up sets
param time_o >= 0, default 1;
param time_f >= 0, default 730; #Hour is now Day 1..365 instead of 0..8760
param year_o >= 0, default 2015;
param year_f >= 0, default 2016;

# ------------------------------------SETS--------------------------------------
set TIME = time_o .. time_f;
set YEARS = year_o .. year_f;
set SITES;
set RENEWABLES within SITES;

#---------------------------------PARAMETERS-----------------------------------
# Transmission costs [$]
param TransCost {s in SITES};

# Capital costs [$/MW]
param CapitalCost {s in SITES};          

# Fixed O&M [$/MW-yr]    
param FixedOMCost {s in SITES};  

# Variable O&M cost [$/MWh]
param VarOMCost {s in SITES};

# RPS goal as a % of annual sales       
param RPS_Goal {y in YEARS};   

# Hourly Load [MWh]             
param Load {t in TIME};    
         
# Avaiability of resource [MW/km^2]
param ResourceAvailability {s in SITES, t in TIME}; 

# Amount of resource developed prior to study [MW] 
param InitialDevelopedResource {s in SITES};

# Max Capacity of each renewable site [MW]
param MaxCapacity {r in RENEWABLES};

# -----------------------------DECISION VARIABLES-------------------------------

# Amount of resource installed in the given time period [MW]
var Installed {s in SITES, t in TIME} >= 0;

# Indicates whether that resource has been developed [binary]
var Build {s in SITES, t in TIME}, binary;

# Amount of each resource that is actually dispatched [MWh]
var Dispatch {s in SITES, t in TIME} >= 0;

var TransBuilt{s in SITES, t in TIME} >= 0, default 0;


# -----------------------------DEFINED VARIABLES--------------------------------
# Cumulative installed capacity up until the given timestep [MW]
var CumulativeInstalled {s in SITES, t in TIME} = 
        sum{u in time_o .. t} Installed[s,u] 
        + InitialDevelopedResource[s];

var CapacityFactor {s in SITES, t in TIME} = 
        if CumulativeInstalled[s,t] = 0
        then 0
        else Dispatch[s,t] / (CumulativeInstalled[s,t] * 24); # 365/12*24 for monthly, *24 for daily

# -----------------------------OBJECTIVE FUNCTION-------------------------------
# Minimize total costs, including capital and operating costs [$]
minimize TotalCosts: sum{s in SITES, t in TIME} 
        #(TransCost[s] * Build[s]
        (CapitalCost[s] * Installed[s,t]
        + FixedOMCost[s] * CumulativeInstalled[s,t]
        + VarOMCost[s] * Dispatch[s,t]);

# ---------------------------------CONSTRAINTS----------------------------------
# Must have developed enough renewbles in each year to meet the RPS target for that year
subject to Meeting_RPS_Goal {y in YEARS}: 
        sum{r in RENEWABLES, t in TIME} Dispatch[r,t] 
        >= RPS_Goal[y] / 100 *  sum{s in SITES, t in TIME} Dispatch[s,t];

# Cannot dispatch more than has been developed
subject to DispatchLimit {s in SITES, t in TIME}: 
        #Dispatch[s,t] <= CumulativeInstalled[s,t];
        Dispatch[s,t] <= CumulativeInstalled[s,t] * 24; # 365/12*24 for monthly, *24 for daily
        

# Cannot dispatch what is not available
subject to AvaiabilityLimit {r in RENEWABLES, t in TIME}:
        Dispatch[r,t] <= ResourceAvailability[r,t] * CumulativeInstalled[r,t];
        
# Must meet load
subject to Meeting_Load {t in TIME}:
		sum{s in SITES}Dispatch[s,t] = Load[t];

subject to CapacityConstraint {r in RENEWABLES, t in TIME}: CumulativeInstalled[r,t] <= MaxCapacity[r];

# Build constraint
#subject to BuildOnlyOnce {s in SITES, t in TIME}: 
#        if sum {u in 1 .. t - 1} Build[s,u] >= 1
#        then Build[s,t] <= 0;

subject to BuildOnlyOnce {s in SITES, t in TIME}:
        if sum {u in 1 .. t-1} Installed[s,u] <= 0.0000001
        then if Installed[s,t] > 0.0000001
        then TransBuilt[s,t] = TransCost[s];