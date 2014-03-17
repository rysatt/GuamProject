# Guam Renewable Integration
# Martin Chang and Ryan Satterlee
# ENERGY 291 Final Project

# Parameters to set up sets
param time_o >= 0, default 1; # Time step 1 of study period, currently using weeks as timestep
param year_o >= 0, default 2015; # Starting year of study period
param year_f >= 0, default 2035; # Ending year of study period

# ------------------------------------SETS--------------------------------------
set TIME;
set YEARS = year_o .. year_f;
set SITES;
set RENEWABLES within SITES;

#---------------------------------PARAMETERS-----------------------------------
# Transmission costs [$]
param TransCost {s in SITES};

# Capital costs [$/MW]
param CapitalCost {s in SITES, y in YEARS};          

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

# Amount of each resource that is actually dispatched [MWh]
var Dispatch {s in SITES, t in TIME} >= 0;


# -----------------------------DEFINED VARIABLES--------------------------------
# Cumulative installed capacity up until the given timestep [MW]
var CumulativeInstalled {s in SITES, t in TIME} = 
        sum{u in time_o .. t} Installed[s,u] 
        + InitialDevelopedResource[s];

# Checking the capacity factor of resources, not vital to code function, for troubleshooting
var CapacityFactor {s in SITES, t in TIME} = 
        if CumulativeInstalled[s,t] = 0
        then 0
        else Dispatch[s,t] / (CumulativeInstalled[s,t] * 168); # 168 is for hr/week

# Determines whether a transmission line installation cost needs to included for the given site s
# Only activates if generation has been constructed, implemented to bypass a binary build variable which was inhibiting code functionality
var TransInstallCost {s in SITES, t in TIME} =
		if t = time_o or sum{u in time_o .. t-1} # If at first time step OR from the beginning of study period until now-1 timestep
			Installed[s,u] <= 0.01 # Check for installations, 0.01 error factor to ignore small variations of capacity at small orders of magnitude
		then if Installed[s,t] > 0.01 # Error factor for marginally positive amounts
				then TransCost[s]
			 	else 0	# If nothing was installed in this time step, and nothing was built before, no need for transmission yet
		else 0; # If something has already been built, then transmission should already exist

# -----------------------------OBJECTIVE FUNCTION-------------------------------
# Minimize total costs, including capital and operating costs [$]
minimize TotalCosts: 
        sum{s in SITES, t in TIME} 
        (TransInstallCost[s,t] 
        + CapitalCost[s,(2015+floor((t-1)/52))] * Installed[s,t] # Calculate the applicable year for capital costs to take affect based on time t, needed for PV
        + FixedOMCost[s] * CumulativeInstalled[s,t]
        + (m[s]*(2015+t/52) + b[s]) * Dispatch[s,t]) # Calculate applicable variable costs due to fuel escalation for time t
        / (1 + DiscountRate / 52)^t; # Discount the cost for that year back into 2015$

# ---------------------------------CONSTRAINTS----------------------------------
# Must have developed enough renewbles in each year to meet the RPS target for that year
subject to Meeting_RPS_Goal {y in YEARS}: 
        sum{r in RENEWABLES, t in ((y-2015)*52+1)..((y-2014)*52)} Dispatch[r,t] # Must only look at applicable values of t for given year y
        >= RPS_Goal[y] / 100 *  sum{s in SITES, t in ((y-2015)*52+1)..((y-2014)*52)} Dispatch[s,t];

# Cannot dispatch more than has been developed
subject to DispatchLimit {s in SITES, t in TIME}: 
        Dispatch[s,t] <= CumulativeInstalled[s,t]*168; # 168 hr/week
        

# Cannot dispatch what is not available
subject to AvailabilityLimit {r in RENEWABLES, t in TIME}:
        Dispatch[r,t] <= ResourceAvailability[r,t] * CumulativeInstalled[r,t]; # If forced dispatch required, set constraint to = rather than <=
        
# Must meet load at each time step t
subject to Meeting_Load {t in TIME}:
		sum{s in SITES}Dispatch[s,t] = Load[t];

# Cannot install more than there is physical room for
subject to CapacityConstraint {r in RENEWABLES, t in TIME}: CumulativeInstalled[r,t] <= MaxCapacity[r];

# Cannot exceed an annual budget for capital investments + transmission (costs beyond typical operation/maintenenace)
subject to BudgetLimit {y in YEARS}:
		sum{s in SITES, t in ((y-2015)*52+1)..((y-2014)*52)} # Only look at applicable t values for year y
		(TransInstallCost[s,t] + CapitalCost[s,y] * Installed[s,t]) <= AnnualBudget;