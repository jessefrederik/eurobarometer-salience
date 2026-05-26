library(dplyr)
library(lubridate)

annual_vars <- c(
  "total_permit_stock",
  "permit_stock_work",
  "permit_stock_family",
  "permit_stock_study",
  "permit_stock_refugee",
  "permit_stock_ukraine",
  "permit_stock_other",
  "total_permit_first",
  "permit_first_work",
  "permit_first_family",
  "permit_first_study",
  "permit_first_refugee_ukraine_other",
  "gdp_per_cap",
  "gdp",
  "homocide_per_100k",
  "robbery_per_100k",
  "burglary_per_100k"
)

core_macro_step <- core_macro %>%
  mutate(year = year(date)) %>%
  group_by(country_code, year) %>%
  mutate(
    across(
      any_of(annual_vars),
      ~ if (all(is.na(.x))) {
        NA_real_
      } else {
        mean(.x, na.rm = TRUE)   # same value for all months in the year
      }
    )
  ) %>%
  ungroup()

core_micro %>% 
  group_by(country_code, date, terrorism = crime) %>% 
  summarise(sum_weight = sum(weight,na.rm=T)) %>%   
  group_by(date, country_code) %>% 
  mutate(perc = sum_weight / sum(sum_weight,na.rm=T) *100) %>% 
  filter(terrorism == 1) %>% 
  ggplot(aes(date, perc, group = country_code)) +
  geom_point() +
  geom_line() +
  facet_wrap(~country_code)
  