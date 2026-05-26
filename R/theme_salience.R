library(tidyverse)
#CORRIETHEMA MET LEGENDA GEEN BREE LIGHT
corriepallet <- c("#9dceca", "#867abd", "#474747", "#febfa0", "#C1BBDD", "#df5b57", "#d2d0c3", "#C1E7E3", "#E7FFAC", "#AFCBFF") 

corriethema <- theme(legend.title=element_blank(),
                     legend.position="top",
                     legend.text = element_text(family = "Bree"),
                     legend.justification='left',
                     legend.direction='horizontal',
                     strip.text = element_text(size = 11, family = "Georgia"),
                     plot.background = element_rect(fill = "#f4f4f4", linetype = "dashed"),
                     panel.background = element_rect(fill = "#ffffff"),
                     panel.grid.major = element_line(colour = "#f4f4f4", linetype = "dashed"),
                     panel.grid.minor = element_line(colour = "#f4f4f4", linetype = "dashed"), 
                     plot.title = element_text(margin = margin(t = 0, r = 0, b = 5, l = 0), 
                                               size = 22, 
                                               family = "Bree"),
                     strip.background = element_blank(),
                     plot.title.position = "plot",
                     plot.subtitle = element_text(margin = margin(t = 0, r = 0, b = 30, l = 0), size = 16, family = "Bree", colour = "#999999"),
                     plot.caption = element_text(size = 9, family = "Georgia", face = "italic", colour = "#999999"),
                     axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0), 
                                                 size = 11, family = "Georgia", colour = "#999999"),
                     axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0), 
                                                 size = 11, family = "Georgia", colour = "#999999"),
                     legend.background = element_rect(fill = "#f4f4f4"),
                     plot.margin = unit(c(1, 1, 1, 1), "cm")) 


