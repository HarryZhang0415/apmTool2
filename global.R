library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(ggthemes)
library(plotly)
library(xts)
library(RColorBrewer)
library(tseries)
library(tibble)
library(PerformanceAnalytics)
library(DEoptim)
library(shinyjs)
library(scales)
library(stringr)
source('./func/am_helper.R')
source('./func/shiny_helper.R')


# ##### This part is used to update the database
# 
# ### update index data
# tickerText = "SPY,PRESX,EEM,DGS10,LQD,IYR,PSP,DFGBX"
# tickers = splitTicker(tickerText)
# for (i in tickers) {
#   tryCatch(getSymbols(i, from = "1999-12-31"),
#            error = function(e) {getSymbols(i, src = "FRED",
#                                            from = "1999-12-31", env = globalenv())})
# }
# Database = data.frame()
# for (i in 1:length(tickers)) {
#   tmp = getCol(get(tickers[i]), tickers[i])
#   Database <- cbind(Database, tmp)
# }
# Database = na.fill(Database, 0)
# Databaseframe = as.data.frame(Database)
# colnames(Databaseframe) = showManyTickers(tickers)
# Databaseframe["date"] = as.Date(row.names(Databaseframe))
# write.csv(Databaseframe, file = "./data/returns.csv", row.names = FALSE)
# 
# ### update risk-free rate
# getSymbols("DGS3MO",src = "FRED")
# rf = as.data.frame(getCol(DGS3MO, "rf"))
# rf["date"] = as.Date(row.names(rf))
# rf = rf[,c("date", "rf")]
# write.csv(rf, file = "./data/rf.csv", row.names = FALSE)


x <- list()
Data <- data.frame()
clo <- data.frame()
#########################################
# Part 1 for Theory descriprion
#########################################

# df = read.csv('./data/returns.csv', row.names = 'date')
df_full = read.csv('./data/returns.csv', row.names = 'date')
df = df_full[,c(1,2,3,4,5,6)]
df = df[rownames(df)<"2019-10-01",]


# Convert to zoo
returns = xts(df, order.by = as.Date(rownames(df)))

# Calculate annualized mean returns, sd of returns and covariance
mean_ret = apply(returns, 2, mean) * 250
sd_ret = apply(returns, 2, sd) * sqrt(250)
cov_matrix = cov(returns) * 250

#  Plot graph 1
df1 = data.frame(Asset = colnames(df), Return = mean_ret, Risk = sd_ret)

g1 = ggplot(df1, aes(x=Risk, y=Return, label=Asset)) + geom_point(color="steelblue3")  + 
  scale_y_continuous(limits=c(0, 0.10), labels = scales::percent_format()) +
  scale_x_continuous(limits=c(0, 0.4), labels = scales::percent_format()) +
  xlab('Risk (standard deviation of returns, annualized)') + ylab('Average Returns, annualized') + 
  theme_hc() 



g1 = ggplotly(g1, tooltip = c("x","y"), width = 600) %>%   add_annotations(x = df1$Risk,
                                                              y = df1$Return,
                                                              text = c("S&P500", "EuropeStocks", "EMStocks", "Treasury", "CorpBonds", "RealEstate" ),
                                                              xref = "x",
                                                              yref = "y",
                                                              showarrow = TRUE,
                                                              arrowhead = 4,
                                                              arrowsize = .5,
                                                              ax = 60,
                                                              ay = -30) 

g1$x$data[[1]]$text = paste("Return:", round(df1$Return, 4) * 100, "%","<br>",
                            "Risk:", round(df1$Risk, 4) * 100, "%")

g1 = g1 %>% layout(margin = list(b = 50, l = 50, t = 100), title = "Risk/Return of Assets <br> (annualized) 2000 - 3Q2019")

# Plot graph 2
risk_ret_ann = df %>% mutate(date = as.Date(rownames(df))) %>% 
  gather(key = "Asset", value="Return", -date) %>%
  mutate(year = year(date)) %>% 
  group_by(Asset, year) %>% 
  summarize(av_ret = mean(Return)*250, Risk = sd(Return)*sqrt(250) ) %>%
  rename(Return=av_ret) 


g2 = ggplot(risk_ret_ann, aes(x=Risk, y=Return, text = paste(year,"<br>","Return:", 
                                                             round(Return,4)*100,"%","<br>", "Risk:", round(Risk,4)*100,"%"))) + 
  geom_point(color="steelblue3")  + 
  xlab('Risk (standard deviation of returns, annualized)') + 
  ylab('') + 
  scale_y_continuous(labels = scales::percent_format()) +
  scale_x_continuous(labels = scales::percent_format()) +
  theme_hc() + facet_wrap(~reorder(Asset, Risk, sd)) + 
  theme(axis.title = element_text(hjust = 1, vjust=1))

g2 = ggplotly(g2, tooltip = c("text"), width = 600) 

g2[['x']][['layout']][['annotations']][[1]][['y']] = -0.1 #Move y-label lower

g2 = g2 %>% layout(margin = list(b = 50, l = -50, t = 120), title = "Risk/Return of Assets By Years <br> (annualized) 2000 - 3Q2019",
                   yaxis=list(title="Average Return, annualized", tickprefix=" "))

# Plot graph 3
order = risk_ret_ann %>% group_by(Asset) %>% summarise(sd_SD=sd(Risk)) %>% arrange(sd_SD) %>% select(Asset)
order = order[['Asset']]


risk_ret_cum = df %>% mutate(date=rownames(df)) %>%
  gather(key="Asset", value="Return", -date) %>%
  group_by(Asset) %>% 
  arrange(date) %>% 
  mutate(cumRet = cumprod(1+Return) - 1)

# Re-arrange
risk_ret_cum$facet = factor(risk_ret_cum$Asset, levels = c(order))

g3 = ggplot(risk_ret_cum, aes(x=as.Date(date), y=cumRet, text = paste(date,"<br>", "Compound return:", round(cumRet,4)*100,"%"), group=1)) + 
    geom_line(color="steelblue3") + facet_wrap(~facet) + 
    scale_y_continuous(labels = scales::percent_format()) +
    scale_x_date(date_breaks = "5 years", date_labels =  "%y") + 
    xlab('Years') + ylab('') + theme_hc() 


g3 = ggplotly(g3, tooltip = "text", width = 600)

g3[['x']][['layout']][['annotations']][[1]][['y']] = -0.1 #Move y-label lower

g3 = g3 %>% layout(margin = list(b = 50, l = 50, t = 120), title = "Compound Return <br> 2000 - 3Q2019",
                   yaxis=list(title="Compound Return"))



# Plot graph 4
# Sim portfolios were simulated using am_helper.R (simPortfolios)
sim_port = read.csv("./data/sim_port.csv")


#Calculate the EF line
min_tret = sim_port[sim_port$Risk==min(sim_port$Risk), "Return"][[1]]  #Usually a good starting point
max_tret = max(sim_port$Return)

tret_vector = seq(min_tret, max_tret, length.out = 20)

ef_line = data.frame(Risk = rep(NA, length(tret_vector)), Return = rep(NA, length(tret_vector)), 
                     Portfolio = rep(NA, length(tret_vector))) #Place holder
i =1 #counter

for (ret in tret_vector){
  ef_w = findEfficientFrontier.Return(returns, ret)
  tmp.Ret = calcPortPerformance(ef_w, mean_ret, cov_matrix)[[1]]
  tmp.Risk = calcPortPerformance(ef_w, mean_ret, cov_matrix)[[2]]
  
  ef_line[i,'Return'] = tmp.Ret
  ef_line[i,'Risk'] = tmp.Risk
  ef_line[i, 'Portfolio'] = paste(c(colnames(df)), 
                                  paste(as.character(round(ef_w, 4)*100), "%"), sep=": ", collapse = "<br>")
  
  i = i+1
  
}


g4 = ggplot(data=sim_port, aes(x=Risk, y=Return)) + geom_point(data=sim_port, aes(x=Risk, y=Return), color='gray', alpha=0.5) + 
  geom_line(data=ef_line, aes(x=Risk, y=Return, text = Portfolio, group=1), color='steelblue3', size =2, alpha=0.5) + 
  scale_y_continuous(limits=c(0, 0.10), labels = scales::percent_format()) +
  scale_x_continuous(limits=c(0, 0.25), labels = scales::percent_format()) +
  theme_hc() + xlab('Risk (standard deviation of returns, annualized)') + ylab('') +
  theme(
    panel.background = element_rect(fill = "transparent") # bg of the panel
    , plot.background = element_rect(fill = "transparent", color = NA) # bg of the plot
    , panel.grid.major = element_blank() # get rid of major grid
    , panel.grid.minor = element_blank() # get rid of minor grid
    , legend.background = element_rect(fill = "transparent") # get rid of legend bg
    , legend.box.background = element_rect(fill = "transparent") # get rid of legend panel bg
  )

g4 = ggplotly(g4, tooltip = "text", width = 600)

g4 = g4 %>% layout(margin = list(b = 50, l = 50, t = 120), title = "Simulated Portfolios and the Optimal Line",
                   yaxis = list(title='Average Return, annualized'))




############################################################
##  BackTesting
############################################################
date()
date_choices = seq(as.Date("2000-01-01"), as.Date("2019-10-01"), by="1 month")
date_choices[length(date_choices)] = as.Date("2019-09-30")


#load risk-free rates
rf = read.csv("./data/rf.csv")
