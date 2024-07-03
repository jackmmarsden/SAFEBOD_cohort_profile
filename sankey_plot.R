library(tidyverse)
library(ggplot2)
library(alluvial)
library(ggalluvial)
library(haven)
library(naniar)

dataloc <- "//shared.sydney.edu.au/research-data/PRJ-SAFEBOD/4. Statistical Analysis/Jack M/Safebod cohort definition"
outputloc <- "/shared.sydney.edu.au/research-data/PRJ-SAFEBOD/4. Statistical Analysis/Jack M/Safebod cohort definition/Tables and figures"


sankey_data <- read_dta(file.path(dataloc,"sankey_data.dta"))

sankey_data <- 
  sankey_data %>%
  mutate(
    highlight_lode=case_when(
      organ == "Heart" ~ "firebrick",
      organ == "Lung" ~ "darkorchid",
      organ == "Liver" ~ "forestgreen",
      organ == "Pancreas" ~ "orangered",
      organ == "Kidney" ~ "royalblue",
      organ == "Gap" ~ "white"
    ),
    highlight_stratum=case_when(
      organ == "Heart" ~ "firebrick",
      organ == "Lung" ~ "darkorchid",
      organ == "Liver" ~ "forestgreen",
      organ == "Pancreas" ~ "orangered",
      organ == "Kidney" ~ "royalblue",
      organ == "Gap" ~ "white"
    )
  )

organlabels <- read_dta(file.path(dataloc,"sankey_organ_labels.dta"))

sankeyplot <- ggplot(sankey_data, 
                     aes(x=time,
                         y=freq,
                         label=lab)) + 
  geom_flow(aes(fill=highlight_lode,
                alluvium=alluvium,
                stratum=stratum,
                alpha=path,
                colour=after_scale(fill)), 
            stat="alluvium") + 
  geom_stratum(aes(fill=highlight_stratum,
                   alluvium=alluvium,
                   stratum=stratum,
                   alpha=location,
                   colour=after_scale(fill)),
               linewidth = 0) +
  geom_text(data=sankey_data %>%
              select(time, lab, freq, stratum) %>% 
              distinct(.),
            aes(stratum=stratum),
            stat="stratum",
            size=3) +
  scale_x_discrete(labels=c("Donor",
                            "Recipient"))+
  scale_fill_identity()+
  theme_minimal()+
  theme(panel.grid.major=element_blank(),
        panel.grid.minor=element_blank(),
        panel.border=element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank(),
        legend.position="none") + 
  labs(x="", 
       y="",
       size=3) +
  geom_text(data=organlabels,
            aes(x=organx,
                y=organy,
                label=lab),
            size=3.1,
            fontface = "bold") +
  scale_alpha_manual(values=c(0.4,0.4,0.8,0.4,0.8),
                     labels=c("Interstate","NSW","InterstateNSW","NSWInterstate","NSWNSW")) +
  scale_x_continuous(breaks=c(1,2),
                     labels=c("Donors","Recipients"))

ggsave("sankeyplot.png",
       bg="white",
       width = 8,
       height = 12)
sankeyplot

