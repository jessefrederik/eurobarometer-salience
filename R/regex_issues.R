# regex_issues.R — Pattern definitions for Eurobarometer issue classification
#
# Exports:
#   issue_ctx        Lookahead regex ensuring a label refers to "important issues
#                    facing the country" (excluding personal/future variants).
#   iss(suffix)      Helper that prepends issue_ctx to a suffix pattern.
#   canonical_levels Character vector of 27 standardized issue category names.
#   issue_patterns   Tribble (~pattern, ~label_std) mapping regex patterns to
#                    canonical issue names. First-match-wins in harmonize_issue().
#   drop_patterns    Regex for labels to discard entirely (e.g. Turkish Cypriot).
#
# Requires: dplyr, stringr, tibble (loaded by core_micro.R via tidyverse)

issue_ctx <- "(?i)(?=.*(important\\s*issues|import\\s*issues))(?!.*pers)(?!.*future)"
iss <- function(suffix) paste0(issue_ctx, suffix)

canonical_levels <- c(
  "crime","public_transport","economy","inflation_cost_of_living","taxation",
  "unemployment","terrorism","defence_foreign_affairs","housing","immigration",
  "healthcare","education","pensions","environment_climate","energy",
  "government_debt","international_situation","external_influence",
  "transport_general","inequality_rich_poor","integration","elderly_care",
  "disabled_care","globalisation", "dont_know", "other", "none"
)

issue_patterns <- tribble(
  ~pattern, ~label_std,

  # ---------- META (only for important issues country, not pers/future) ----------
  iss(".*(\\bdk\\b|don'?t\\s*know)"),
  "dont_know",

  iss(".*(\\bnone\\b|none\\s*spont|none of these)"),
  "none",

  iss(".*(\\bothers?\\b|other\\s*spont)"),
  "other",

  # ---------- REGULAR ISSUES (only important issues, no personal, no future) ----------
  iss(".*\\bcrime\\b"),
  "crime",

  iss(".*public\\s*transport"),
  "public_transport",

  iss(".*(economic\\s*situation|econom(?!y supply))"),
  "economy",

  iss(".*(rising prices|inflation|cost of living|living\\s*costs)"),
  "inflation_cost_of_living",

  iss(".*(taxation|\\btax\\b)"),
  "taxation",

  iss(".*(unemployment|jobs?)"),
  "unemployment",

  iss(".*terrorism"),
  "terrorism",

  iss(".*(defen[cs]e|foreign\\s*aff)"),
  "defence_foreign_affairs",

  iss(".*housing"),
  "housing",

  iss(".*immigration"),
  "immigration",

  iss(".*(health( care)?( and (social )?security)?|\\bhealth\\b)"),
  "healthcare",

  # education: only as an important-issues *system*, not all education variables
  iss(".*education(al)?\\s*(system|sys)\\b"),
  "education",

  iss(".*pensions?"),
  "pensions",

  iss(".*(environment|climate(\\s*change)?)"),
  "environment_climate",

  iss(".*energy(\\s*supply)?\\b"),
  "energy",

  iss(".*government\\s*debt"),
  "government_debt",

  iss(".*international\\s*situation"),
  "international_situation",

  iss(".*((country|cntry|ctry)'?s?\\s*(external|ext)?\\s*influence|\\bexternal\\s*influence\\b)"),
  "external_influence",

  # bare "transport" (but not public) only in important-issues context
  iss(".*\\btransport\\b(?!.*public)"),
  "transport_general",

  iss(".*(rich\\s*poor\\s*gap|inequal)"),
  "inequality_rich_poor",

  iss(".*integration"),
  "integration",

  iss(".*elderly\\s*care"),
  "elderly_care",

  iss(".*disabled\\s*care"),
  "disabled_care",

  iss(".*(globalisation|globalization)"),
  "globalisation",

  iss(".*helpfulness"),
  "helpfulness",

  # ---------- OTHER (unchanged; not tied to important issues) ----------
  "(?i)date of interview day",               "interview_day",
  "(?i)date of interview month",             "interview_month",
  "(?i)date of interview no data",           "interview_date_missing",
  "(?i)date of interview",                   "interview_date",
  "(?i)iso 3166",                            "country_code",
  "(?i)nation all samples",                  "nation",

  # weights
  "(?i)w1 weight",                           "weight_w1",
  "(?i)w31 hh weight",                       "weight_household",
  "(?i)w31 polit weight",                    "weight_political",
  "(?i)weight result from target eu",        "weight_eu",
  "(?i)weight result from target cc",        "weight_candidate_countries",
  "(?i)weight result from target redressment","weight_redressment",
  "(?i)redressment hh",                      "weight_redressment_household",
  "(?i)redressment germany",                 "weight_redressment_germany",
  "(?i)weight result from target",           "weight_target",
  "(?i)nation united kingdom and united germany iso3166",
  "weight_national_uk_germany",
  "(?i)weight.*united germany",              "weight_united_germany",
  "(?i)weight.*united kingdom",              "weight_united_kingdom",
  "(?i)weight.*nation",                      "weight_national",
  "(?i)weight eu27",                         "weight_eu27",

  "(?i)^unique identifier.*",                "rowid",
  "(?i)age exact",                           "age",
  "(?i)\\bgender\\b",                        "gender"
)

drop_patterns <- "tcc"
