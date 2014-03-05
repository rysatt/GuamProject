# Guam Renewable Integration
# Martin Chang and Ryan Satterlee

# Parameters to set up sets
param hour_o >= 0, default 1;
param hour_f >= 0, default 365; #Hour is now Month, 1.. 12 instead of 0..8760
param year_o >= 0, default 2015;
param year_f >= 0, default 2016;

# ------------------------------------SETS--------------------------------------
set HOURS = hour_o .. hour_f;
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
param RPS_Goal {t in YEARS};   

# Hourly Load [MWh]             
param Load {h in HOURS, t in YEARS};    
         
# Avaiability of resource [MW/km^2]
param ResourceAvailability {s in SITES, h in HOURS, t in YEARS}; 

# Amount of resource developed prior to study [MW] 
param InitialDevelopedResource {s in SITES};

# Max Capacity of each renewable site [MW]
param MaxCapacity {r in RENEWABLES};

# -----------------------------DECISION VARIABLES-------------------------------

# Amount of resource installed in the given time period [MW]
var Installed {s in SITES, h in HOURS, t in YEARS} >= 0;

# Indicates whether that resource has been developed [binary]
#var Build {s in SITES, h in HOURS, t in YEARS}, binary;

# Amount of each resource that is actually dispatched [MWh]
var Dispatch {s in SITES, h in HOURS, t in YEARS} >= 0;


# -----------------------------DEFINED VARIABLES--------------------------------
# Cumulative installed capacity up until the given timestep [MW]
var CumulativeInstalled {s in SITES, h in HOURS, t in YEARS} = 
        sum{i in hour_o .. h, u in year_o .. t} Installed[s,i,u] 
        + InitialDevelopedResource[s];

var CapacityFactor {s in SITES, h in HOURS, t in YEARS} = 
        if CumulativeInstalled[s,h,t] = 0
        then 0
        else Dispatch[s,h,t] / (CumulativeInstalled[s,h,t] * 24); # 365/12*24 for monthly, *24 for daily

# -----------------------------OBJECTIVE FUNCTION-------------------------------
# Minimize total costs, including capital and operating costs [$]
minimize TotalCosts: sum{s in SITES, h in HOURS, t in YEARS} 
        #(TransCost[s] * Build[s,h,t]
        (CapitalCost[s] * Installed[s,h,t]
        + FixedOMCost[s] * CumulativeInstalled[s,h,t]
        + VarOMCost[s] * Dispatch[s,h,t]);

# ---------------------------------CONSTRAINTS----------------------------------
# Must have developed enough renewbles in each year to meet the RPS target for that year
#subject to Meeting_RPS_Goal {t in YEARS}: 
#        sum{r in RENEWABLES, h in HOURS} Dispatch[r,h,t] 
#        >= RPS_Goal[t] / 100 *  sum{s in SITES, h in HOURS} Dispatch[s,h,t];

# Cannot dispatch more than has been developed
subject to DispatchLimit {s in SITES, h in HOURS, t in YEARS}: 
        #Dispatch[s,h,t] <= CumulativeInstalled[s,h,t];
        Dispatch[s,h,t] <= CumulativeInstalled[s,h,t] * 24; # 365/12*24 for monthly, *24 for daily
        

# Cannot dispatch what is not available
subject to AvaiabilityLimit {r in RENEWABLES, h in HOURS, t in YEARS}:
        Dispatch[r,h,t] <= ResourceAvailability[r,h,t] * CumulativeInstalled[r,h,t];
        
# Must meet load
subject to Meeting_Load {h in HOURS, t in YEARS}:
		sum{s in SITES}Dispatch[s,h,t] = Load[h,t];

subject to CapacityConstraint {r in RENEWABLES, h in HOURS, t in YEARS}: CumulativeInstalled[r,h,t] <= MaxCapacity[r];