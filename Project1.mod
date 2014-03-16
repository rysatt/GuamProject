# Guam Renewable Integration
# Martin Chang and Ryan Satterlee

# Parameters to set up sets
param time_o >= 0, default 1;
#param time_f >= 0, default 730; #Hour is now Month, 1.. 12 instead of 0..8760
param year_o >= 0, default 2015;
param year_f >= 0, default 2035;

# ------------------------------------SETS--------------------------------------
set TIME;# = time_o .. time_f;
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

# Slope of increasing variable costs due to forecasted fuel cost increases
param m {s in SITES};

# Intercept of increasing variable costs due to forecasted fuel cost increases
param b {s in SITES};

# Spending limit for capital investment in a given year Y
param AnnualBudget;

# Annual Discount Rate
param DiscountRate;

# -----------------------------DECISION VARIABLES-------------------------------

# Amount of resource installed in the given time period [MW]
var Installed {s in SITES, t in TIME} >= 0;

# Indicates whether that resource has been developed [binary]
#var Build {s in SITES}, binary;

# Amount of each resource that is actually dispatched [MWh]
var Dispatch {s in SITES, t in TIME} >= 0;


# -----------------------------DEFINED VARIABLES--------------------------------
# Cumulative installed capacity up until the given timestep [MW]
var CumulativeInstalled {s in SITES, t in TIME} = 
        sum{u in time_o .. t} Installed[s,u] 
        + InitialDevelopedResource[s];

var CapacityFactor {s in SITES, t in TIME} = 
        if CumulativeInstalled[s,t] = 0
        then 0
        else Dispatch[s,t] / (CumulativeInstalled[s,t] * 168); # 365/12*24 for monthly, *24 for daily

var TransInstallCost {s in SITES, t in TIME} =
		if t = time_o or sum{u in time_o .. t-1} # If at first time step, ensure it is still possible to build
			Installed[s,u] <= 0.01 # Check for installations from beginning of time until previous time step
		then if Installed[s,t] > 0.01 # Error factor for marginally positive amounts
				then TransCost[s]
			 	else 0
		else 0;

# -----------------------------OBJECTIVE FUNCTION-------------------------------
# Minimize total costs, including capital and operating costs [$]
minimize TotalCosts: #sum{s in SITES} 
        sum{s in SITES, t in TIME} 
        (TransInstallCost[s,t] 
        + CapitalCost[s] * Installed[s,t]
        + FixedOMCost[s] * CumulativeInstalled[s,t]
        + (m[s]*(2015+t/52) + b[s]) * Dispatch[s,t])
        / (1 + DiscountRate / 52)^t;

# ---------------------------------CONSTRAINTS----------------------------------
# Must have developed enough renewbles in each year to meet the RPS target for that year
subject to Meeting_RPS_Goal {y in YEARS}: 
        sum{r in RENEWABLES, t in ((y-2015)*52+1)..((y-2014)*52)} Dispatch[r,t] 
        >= RPS_Goal[y] / 100 *  sum{s in SITES, t in ((y-2015)*52+1)..((y-2014)*52)} Dispatch[s,t];

# Cannot dispatch more than has been developed
subject to DispatchLimit {s in SITES, t in TIME}: 
        #Dispatch[s,t] <= CumulativeInstalled[s,t];
        Dispatch[s,t] <= CumulativeInstalled[s,t]*168; # 365/12*24 for monthly, *24 for daily
        

# Cannot dispatch what is not available
subject to AvailabilityLimit {r in RENEWABLES, t in TIME}:
        Dispatch[r,t] <= ResourceAvailability[r,t] * CumulativeInstalled[r,t];
        
# Must meet load
subject to Meeting_Load {t in TIME}:
		sum{s in SITES}Dispatch[s,t] = Load[t];

# Cannot install more than there is physical room for
subject to CapacityConstraint {r in RENEWABLES, t in TIME}: CumulativeInstalled[r,t] <= MaxCapacity[r];

# Cannot exceed an annual budget for capital investments
subject to BudgetLimit {y in YEARS}:
		sum{s in SITES, t in ((y-2015)*52+1)..((y-2014)*52)} 
		(TransInstallCost[s,t] + CapitalCost[s] * Installed[s,t]) <= AnnualBudget/ (1 + DiscountRate)^(y-2015);
#        + FixedOMCost[s] * CumulativeInstalled[s,t]
#        + (m[s]*(2015+t/52) + b[s]) * Dispatch[s,t]) <= AnnualBudget[y];
		