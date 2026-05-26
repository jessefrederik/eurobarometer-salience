if (!exists("fetch_eurostat")) source("R/helper_macrodata.R")

macro_permit_first <- fetch_eurostat("migr_resfirst",
  filters = list(duration = "TOTAL", citizen = c("TOTAL", "UK", "CH", "NO"))
) %>%
  mutate(values = ifelse(is.na(values) & citizen %in% c("UK", "CH", "NO"), 0, values)) %>%
  pivot_wider(names_from = citizen, values_from = values) %>%
  mutate(
    permit_stock = TOTAL - UK - CH - NO,
    country_code = ifelse(country_code == "EU27_2020", "EU", country_code)
  ) %>%
  select(!NO:TOTAL) %>%
  pivot_wider(names_from = reason, values_from = permit_stock) %>%
  select(
    date,
    country_code,
    total_permit_first = TOTAL,
    permit_first_work = EMP,
    permit_first_family = FAM,
    permit_first_study = EDUC,
    permit_first_refugee_ukraine_other = OTH
  )

macro_permit_stock <- fetch_eurostat("migr_resvalid",
  filters = list(duration = "TOTAL", citizen = c("TOTAL", "UK", "CH", "NO"))
) %>%
  mutate(values = ifelse(is.na(values) & citizen %in% c("UK", "CH", "NO"), 0, values)) %>%
  pivot_wider(names_from = citizen, values_from = values) %>%
  mutate(
    permit_stock = TOTAL - UK - CH - NO,
    country_code = ifelse(country_code == "EU27_2020", "EU", country_code)
  ) %>%
  select(!NO:TOTAL) %>%
  pivot_wider(names_from = reason, values_from = permit_stock) %>%
  select(
    date,
    country_code,
    total_permit_stock = TOTAL,
    permit_stock_work = EMP,
    permit_stock_family = FAM,
    permit_stock_study = EDUC,
    permit_stock_refugee = RFG,
    permit_stock_ukraine = SPROT,
    permit_stock_other = OTH
  )
