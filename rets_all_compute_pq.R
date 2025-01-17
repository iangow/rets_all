#!/usr/bin/env Rscript --vanilla --quiet
suppressPackageStartupMessages(library(tidyverse))
library(DBI)
library(dbplyr, warn.conflicts = FALSE)   # For window_order()
library(farr, warn.conflicts = FALSE)

db <- dbConnect(duckdb::duckdb())

msf <- load_parquet(db, schema = "crsp", table = "msf")
msi <- load_parquet(db, schema = "crsp", table = "msi")
ccmxpf_lnkhist <- load_parquet(db, schema = "crsp", 
                               table = "ccmxpf_lnkhist")
stocknames <- load_parquet(db, schema = "crsp", 
                           table = "stocknames")

fundq <- load_parquet(db, schema = "comp", table = "fundq")

annc_events <-
  fundq |>
  filter(indfmt == "INDL", datafmt == "STD",
         consol == "C", popsrc == "D") |>
  filter(fqtr == 4, fyr == 12, !is.na(rdq)) |>
  select(gvkey, datadate, rdq) |>
  mutate(annc_month = as.Date(floor_date(rdq, unit = "month"))) |>
  compute()

crsp_dates <-
  msi |>
  select(date) |>
  window_order(date) |>
  mutate(td = row_number()) |>
  mutate(month = as.Date(floor_date(date, unit = "month"))) |>
  compute()

annc_months <-
  crsp_dates |>
  select(month, td) |> 
  rename( annc_month = month, annc_td = td) |>
  mutate(start_td = annc_td - 11L,
         end_td = annc_td + 6L) |>
  compute()

td_link <-
  crsp_dates |>
  inner_join(annc_months, join_by(between(td, start_td, end_td))) |>
  mutate(rel_td = td - annc_td) |>
  select(annc_month, rel_td, date) |>
  compute()

ccm_link <-
  ccmxpf_lnkhist |>
  filter(linktype %in% c("LC", "LU", "LS"),
         linkprim %in% c("C", "P")) |>
  rename(permno = lpermno) |>
  select(gvkey, permno, linkdt, linkenddt) |>
  compute()

rets_all <-
  annc_events |> 
  inner_join(td_link, by = "annc_month") |>
  inner_join(ccm_link, by = "gvkey") |>
  filter(annc_month >= linkdt,
         annc_month <= linkenddt | is.na(linkenddt)) |>
  inner_join(msf, by = c("permno", "date")) |>
  inner_join(stocknames, by = "permno") |>
  filter(between(date, namedt, nameenddt),
         exchcd %in% c(1, 2, 3)) |>
  select(gvkey, datadate, rel_td, permno, date, ret) |>
  filter(between(year(datadate), 1987L, 2002L))  |>
  collect()